import AppKit
import PlantGardenCore

extension Notification.Name {
    static let gardenStoreDidChange = Notification.Name("gardenStoreDidChange")
    static let gardenGnomeZoneDrawingModeDidChange = Notification.Name("gardenGnomeZoneDrawingModeDidChange")
    static let gardenGnomePerspectiveAdjustmentModeDidChange = Notification.Name("gardenGnomePerspectiveAdjustmentModeDidChange")
    static let gardenBirdSkyZoneDrawingModeDidChange = Notification.Name("gardenBirdSkyZoneDrawingModeDidChange")
    static let gardenAutoGardenerDrawingModeDidChange = Notification.Name("gardenAutoGardenerDrawingModeDidChange")
    static let gardenSoilBrushModeDidChange = Notification.Name("gardenSoilBrushModeDidChange")
}

@MainActor
final class GardenStore: NSObject {
    static let maximumRoomObjectScale = 8.0

    struct PendingCustomPlantAsset: Equatable, Identifiable {
        var id: UUID
        var displayName: String
        var kind: PlantKind
        var screenIndex: Int
        var position: GardenPoint
        var startedAt: Date
    }

    private(set) var state: GardenState
    let persistence: GardenPersistence
    let customPlantAssets: CustomPlantAssetStore
    private(set) var activeSceneKey: String?
    private let globalDefaults: UserDefaults
    /// Set by the app delegate; actions log notable events here.
    var journal: GardenJournalStore?
    private var suppressSelectionChangePost = false
    var selectedPlantID: UUID? {
        didSet {
            guard oldValue != selectedPlantID else {
                return
            }
            guard !suppressSelectionChangePost else {
                return
            }

            postChange()
        }
    }
    private(set) var lastError: String?
    private(set) var pendingCustomPlantAssets: [PendingCustomPlantAsset] = []
    private static let appDefaultsSuiteName = "com.chrisdimarco.wallpapergarden"
    private static let globalPauseDefaultsKey = "globalPauseGrowth"

    var hasPendingCustomPlantAssets: Bool {
        !pendingCustomPlantAssets.isEmpty
    }

    init(
        state: GardenState,
        persistence: GardenPersistence,
        activeSceneKey: String? = nil,
        customPlantAssets: CustomPlantAssetStore? = nil,
        globalDefaults: UserDefaults? = nil
    ) {
        let resolvedDefaults = globalDefaults
            ?? UserDefaults(suiteName: Self.appDefaultsSuiteName)
            ?? .standard
        self.globalDefaults = resolvedDefaults
        self.state = Self.state(state, applyingGlobalPauseFrom: resolvedDefaults)
        self.persistence = persistence
        self.activeSceneKey = activeSceneKey
        self.customPlantAssets = customPlantAssets ?? CustomPlantAssetStore(baseDirectoryURL: persistence.directoryURL)
    }

    var selectedPlant: Plant? {
        guard let selectedPlantID else {
            return nil
        }

        return state.plants.first { $0.id == selectedPlantID }
    }

    func advance(to date: Date) {
        let nextState = GardenEngine.advance(state, to: date)
        guard nextState != state else {
            return
        }

        // The 1 Hz simulation tick always touches timestamps and sub-pixel
        // growth, so plain state inequality would notify (and repaint) every
        // second. Only tell observers when something perceptible changed;
        // the display-cadence timer keeps ambient animation running.
        let didChangeVisibly = GardenStateRenderSignature(of: nextState) != GardenStateRenderSignature(of: state)
        state = nextState
        if didChangeVisibly {
            postChange()
        }
    }

    func waterAll() {
        replaceState(GardenEngine.waterAll(state), shouldSave: true)
    }

    func waterThirstyPlants() {
        replaceState(GardenEngine.waterThirstyPlants(state), shouldSave: true)
    }

    func waterSelectedPlant() {
        guard let selectedPlantID else {
            waterAll()
            return
        }

        replaceState(GardenEngine.waterPlant(state, id: selectedPlantID), shouldSave: true)
    }

    func waterPlant(id: UUID) {
        replaceState(GardenEngine.waterPlant(state, id: id), shouldSave: true)
    }

    func toggleSelectedPlantFavorite() {
        guard let selectedPlantID else {
            return
        }

        var nextState = state
        guard let index = nextState.plants.firstIndex(where: { $0.id == selectedPlantID }) else {
            return
        }

        nextState.plants[index].isFavorite.toggle()
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
    }

    func selectPlant(id: UUID) {
        guard state.plants.contains(where: { $0.id == id }) else {
            return
        }

        setSelectedPlant(id)
    }

    func pruneSelectedPlant() {
        guard let selectedPlantID else {
            return
        }

        prunePlant(id: selectedPlantID)
    }

    func prunePlant(id: UUID) {
        let nextState = GardenEngine.prunePlant(state, id: id)
        guard nextState != state else {
            return
        }

        setSelectedPlant(id)
        replaceState(nextState, shouldSave: true)
    }

    func performRecommendedCareForSelectedPlant() {
        guard let selectedPlantID else {
            return
        }

        performRecommendedCare(for: selectedPlantID)
    }

    func performRecommendedCare(for id: UUID) {
        guard let plant = state.plants.first(where: { $0.id == id }) else {
            return
        }

        setSelectedPlant(id)
        switch plant.careActionRecommendation.kind {
        case .water:
            waterPlant(id: id)
        case .prune:
            prunePlant(id: id)
        case .nourish:
            nourishPlant(id: id)
        case .enjoy:
            setSelectedPlant(id)
            replaceState(GardenEngine.enjoyPlant(state, id: id), shouldSave: true)
        }
    }

    func nourishPlant(id: UUID) {
        let selectedPlant = state.plants.first { $0.id == id }
        var nextState = GardenEngine.nourishPlant(state, id: id)
        if let selectedPlant,
           selectedPlant.customAssetID == nil,
           !selectedPlant.isDead,
           let nextGrowth = PlantAssetLibrary.shared.nextGrowthMilestone(
            for: selectedPlant.species,
            growth: selectedPlant.growth
           ),
           nextGrowth > selectedPlant.growth {
            let now = Date()
            nextState.plants = nextState.plants.map { plant in
                guard plant.id == id else {
                    return plant
                }

                var plant = plant
                plant.growth = nextGrowth
                plant.lastStageChangedAt = now
                plant.lastTendedAt = now
                plant.lastNourishedAt = now
                return plant
            }
            nextState.lastUpdatedAt = now
        }
        guard nextState != state else {
            return
        }

        setSelectedPlant(id)
        replaceState(nextState, shouldSave: true)
    }

    func harvestSelectedPlant() {
        guard let selectedPlantID else {
            return
        }

        harvestPlant(id: selectedPlantID)
    }

    func harvestPlant(id: UUID) {
        guard let plant = state.plants.first(where: { $0.id == id }) else {
            return
        }

        let nextState = GardenEngine.harvestPlant(state, id: id)
        guard nextState != state else {
            return
        }

        setSelectedPlant(id)
        replaceState(nextState, shouldSave: true)
        let harvestCount = nextState.harvestTally[plant.species.rawValue, default: 0]
        journal?.append(.harvest, "Harvested \(plant.species.displayName) - harvest #\(harvestCount), +2 seeds")
    }

    func harvestAllReadyCrops() {
        let readyPlants = state.plants.filter(\.isHarvestReady)
        guard !readyPlants.isEmpty else {
            return
        }

        let nextState = GardenEngine.harvestReadyCrops(state)
        guard nextState != state else {
            return
        }

        replaceState(nextState, shouldSave: true)
        let varietyCount = Set(readyPlants.map(\.species)).count
        let cropCount = readyPlants.count
        journal?.append(
            .harvest,
            "Harvested \(cropCount) crop\(cropCount == 1 ? "" : "s") across \(varietyCount) variet\(varietyCount == 1 ? "y" : "ies") - +\(cropCount * 2) seeds"
        )
    }

    func plantSeed(species: PlantSpecies, screenIndex: Int, position: GardenPoint? = nil) {
        let safeScreenIndex = max(0, screenIndex)
        let resolvedPosition: GardenPoint
        if let position {
            resolvedPosition = GardenComposition.resolvedPlantingPosition(
                for: species,
                preferredPosition: position,
                existingPlants: state.plants,
                screenIndex: safeScreenIndex
            )
        } else {
            resolvedPosition = GardenComposition.nextPosition(
                for: species,
                existingPlants: state.plants,
                screenIndex: safeScreenIndex,
                sceneKey: activeSceneKey
            )
        }

        let nextState = userAuthoredCompositionState(
            GardenEngine.plantSeed(
                state,
                species: species,
                screenIndex: safeScreenIndex,
                position: resolvedPosition
            )
        )
        guard nextState != state else {
            return
        }

        setSelectedPlantSilently(nextState.plants.last?.id)
        replaceState(nextState, shouldSave: true)
        journal?.append(.planted, "Planted a \(species.displayName) from seed")
    }

    func performRecommendedCare(screenIndex: Int = 0) {
        let recommendation = state.careRecommendation
        switch recommendation.kind {
        case .plantFirst:
            addRandomFlower(screenIndex: screenIndex)
        case .removeDead:
            guard let targetPlantID = recommendation.targetPlantID else {
                return
            }
            let nextState = GardenEngine.removePlant(state, id: targetPlantID)
            guard nextState != state else {
                return
            }
            if selectedPlantID == targetPlantID {
                setSelectedPlantSilently(nil)
            }
            replaceState(nextState, shouldSave: true)
        case .waterThirsty:
            waterThirstyPlants()
        case .prune:
            guard let targetPlantID = recommendation.targetPlantID else {
                return
            }
            prunePlant(id: targetPlantID)
        case .nourish:
            guard let targetPlantID = recommendation.targetPlantID else {
                return
            }
            nourishPlant(id: targetPlantID)
        case .enjoy:
            return
        }
    }

    func nourishSelectedPlant() {
        guard let selectedPlantID else {
            return
        }

        nourishPlant(id: selectedPlantID)
    }

    func removeSelectedPlant() {
        guard let selectedPlantID else {
            return
        }

        let nextState = GardenEngine.removePlant(state, id: selectedPlantID)
        guard nextState != state else {
            setSelectedPlant(nil)
            return
        }

        setSelectedPlantSilently(nil)
        replaceState(nextState, shouldSave: true)
    }

    func removeAllPlantsInCurrentScene() {
        let nextState = GardenEngine.removeAllPlants(state)
        guard nextState != state else {
            setSelectedPlant(nil)
            return
        }

        setSelectedPlantSilently(nil)
        replaceState(nextState, shouldSave: true)
    }

    func resetPlantsToNascentGrowthInCurrentScene() {
        let nextState = GardenEngine.resetPlantsToNascentGrowth(
            state,
            initialGrowthForPlant: { plant in
                PlantAssetLibrary.shared.initialGrowth(for: plant.species)
            }
        )
        guard nextState != state else {
            return
        }

        let nextSelectedPlantID = selectedPlantID.flatMap { selectedID in
            nextState.plants.contains(where: { $0.id == selectedID }) ? selectedID : nil
        }
        replaceState(nextState, shouldSave: true, selectedPlantID: nextSelectedPlantID)
        journal?.append(.milestone, "Started the scene's plants from their beginning forms")
    }

    func bringAllPlantsToFullMaturationInCurrentScene() {
        let nextState = GardenEngine.bringPlantsToFullMaturation(state)
        guard nextState != state else {
            return
        }

        let nextSelectedPlantID = selectedPlantID.flatMap { selectedID in
            nextState.plants.contains(where: { $0.id == selectedID }) ? selectedID : nil
        }
        replaceState(nextState, shouldSave: true, selectedPlantID: nextSelectedPlantID)
        journal?.append(.milestone, "Brought the scene's plants to full maturation")
    }

    func removePlantsWithoutDisplayableAssets() {
        // Positions are intentionally left untouched: this runs after every
        // scene switch, and snapping kept moving plants away from where the
        // operator placed them.
        let displayablePlants = state.plants.filter { plant in
            PlantDisplayAssetResolver.hasDisplayableAsset(for: plant, customAssets: customPlantAssets)
        }
        guard displayablePlants != state.plants else {
            return
        }

        var nextState = state
        nextState.plants = displayablePlants
        let nextSelectedPlantID = selectedPlantID.flatMap { selectedID in
            displayablePlants.contains { $0.id == selectedID } ? selectedID : nil
        }
        replaceState(nextState, shouldSave: true, selectedPlantID: nextSelectedPlantID)
    }

    func addRandomFlower(screenIndex: Int = 0) {
        let species = PlantSpecies.flowers.randomElement() ?? .tulip
        addPlant(species: species, screenIndex: screenIndex)
    }

    func addRandomTree(screenIndex: Int = 0) {
        let species = PlantSpecies.trees.randomElement() ?? .cherryTree
        addPlant(species: species, screenIndex: screenIndex)
    }

    func addRandomFoliage(screenIndex: Int = 0) {
        let species = PlantSpecies.foliage.randomElement() ?? .fern
        addPlant(species: species, screenIndex: screenIndex)
    }

    func addRandomMeadow(screenIndex: Int = 0) {
        let species = PlantSpecies.meadows.randomElement() ?? .wildflowerMeadow
        addPlant(species: species, screenIndex: screenIndex)
    }

    func addPlant(species: PlantSpecies, screenIndex: Int, position: GardenPoint? = nil) {
        let safeScreenIndex = max(0, screenIndex)
        let point: GardenPoint
        if let position {
            point = state.settings.experienceMode == .rainforest
                ? position.clamped
                : GardenComposition.resolvedPlantingPosition(
                    for: species,
                    preferredPosition: position,
                    existingPlants: state.plants,
                    screenIndex: safeScreenIndex
                )
        } else {
            point = GardenComposition.nextPosition(
                for: species,
                existingPlants: state.plants,
                screenIndex: safeScreenIndex,
                sceneKey: activeSceneKey
            )
        }
        let initialGrowth = state.settings.plantNewPlantsAtMaturity
            ? 1.0
            : PlantAssetLibrary.shared.initialGrowth(for: species)
        let nextState = userAuthoredCompositionState(
            GardenEngine.addPlant(
                state,
                species: species,
                screenIndex: safeScreenIndex,
                position: point,
                initialGrowth: initialGrowth,
                initialScale: defaultScaleForNewAsset(species: species)
            )
        )
        setSelectedPlantSilently(nextState.plants.last?.id)
        replaceState(nextState, shouldSave: true)
        journal?.append(.planted, "Planted a \(species.displayName)")
    }

    func addCustomPlant(
        _ record: CustomPlantAssetRecord,
        screenIndex: Int,
        position: GardenPoint? = nil
    ) {
        let safeScreenIndex = max(0, screenIndex)
        let species = record.baseSpecies
        let point: GardenPoint
        if let position {
            point = state.settings.experienceMode == .rainforest
                ? position.clamped
                : GardenComposition.resolvedPlantingPosition(
                    for: species,
                    preferredPosition: position,
                    existingPlants: state.plants,
                    screenIndex: safeScreenIndex
                )
        } else {
            point = GardenComposition.nextPosition(
                for: species,
                existingPlants: state.plants,
                screenIndex: safeScreenIndex,
                sceneKey: activeSceneKey
            )
        }

        var nextState = state
        nextState.compositionVersion = GardenComposition.currentVersion
        nextState.isUserArranged = true
        let plant = Plant(
            species: species,
            screenIndex: safeScreenIndex,
            position: point,
            growth: 1.0,
            hydration: 0.82,
            health: 0.88,
            nickname: record.displayName,
            scale: defaultScaleForNewAsset(species: species),
            customAssetID: record.id
        )
        nextState.plants.append(plant)
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true, selectedPlantID: plant.id)
        journal?.append(.planted, "Created and planted \(record.displayName)")
    }

    private func defaultScaleForNewAsset(species: PlantSpecies) -> Double {
        guard state.settings.experienceMode == .rainforest else {
            return state.settings.defaultPlantScale
        }

        let multiplier: Double = switch species.kind {
        case .tree:
            1.72
        case .foliage:
            1.88
        case .flower:
            1.52
        case .meadow:
            2.05
        case .edible:
            1.55
        }
        return min(GardenEngine.maximumPlantScale, state.settings.defaultPlantScale * multiplier)
    }

    @discardableResult
    func beginPendingCustomPlantAsset(
        displayName: String,
        kind: PlantKind,
        screenIndex: Int,
        position: GardenPoint,
        startedAt: Date = Date()
    ) -> UUID {
        let id = UUID()
        pendingCustomPlantAssets.append(PendingCustomPlantAsset(
            id: id,
            displayName: displayName,
            kind: kind,
            screenIndex: max(0, screenIndex),
            position: position.clamped,
            startedAt: startedAt
        ))
        postChange()
        return id
    }

    func pendingCustomPlantAsset(id: UUID) -> PendingCustomPlantAsset? {
        pendingCustomPlantAssets.first { $0.id == id }
    }

    func movePendingCustomPlantAsset(
        id: UUID,
        to position: GardenPoint,
        screenIndex: Int,
        notify: Bool = true
    ) {
        guard let index = pendingCustomPlantAssets.firstIndex(where: { $0.id == id }) else {
            return
        }

        let clampedPosition = position.clamped
        let safeScreenIndex = max(0, screenIndex)
        guard pendingCustomPlantAssets[index].position != clampedPosition
            || pendingCustomPlantAssets[index].screenIndex != safeScreenIndex else {
            return
        }

        pendingCustomPlantAssets[index].position = clampedPosition
        pendingCustomPlantAssets[index].screenIndex = safeScreenIndex
        if notify {
            postChange()
        }
    }

    func settlePendingCustomPlantAsset(id: UUID) {
        guard pendingCustomPlantAssets.contains(where: { $0.id == id }) else {
            return
        }

        postChange()
    }

    func finishPendingCustomPlantAsset(id: UUID) {
        let oldValue = pendingCustomPlantAssets
        pendingCustomPlantAssets.removeAll { $0.id == id }
        guard oldValue != pendingCustomPlantAssets else {
            return
        }

        postChange()
    }

    func moveSelectedPlant(to position: GardenPoint, screenIndex: Int) {
        guard let selectedPlantID,
              selectedPlant?.placementLocked != true else {
            return
        }

        let nextState = userAuthoredCompositionState(
            GardenEngine.movePlant(state, id: selectedPlantID, to: position, screenIndex: screenIndex)
        )
        replaceState(nextState, shouldSave: false)
    }

    func resizeSelectedPlant(toScale scale: Double) {
        guard let selectedPlantID,
              let selectedPlant,
              selectedPlant.placementLocked != true else {
            return
        }

        let maximumScale = selectedPlant.customAssetID
            .map { customPlantAssets.isRoomObjectAsset(forCustomAssetID: $0) } == true
            ? Self.maximumRoomObjectScale
            : GardenEngine.maximumPlantScale
        let nextState = userAuthoredCompositionState(
            GardenEngine.resizePlant(
                state,
                id: selectedPlantID,
                toScale: scale,
                maximumScale: maximumScale
            )
        )
        replaceState(nextState, shouldSave: false)
    }

    func setSelectedPlantPlacementLocked(_ isLocked: Bool) {
        guard let selectedPlantID else {
            return
        }

        let nextState = GardenEngine.setPlantPlacementLocked(
            state,
            id: selectedPlantID,
            isLocked: isLocked
        )
        replaceState(nextState, shouldSave: true)
    }

    func toggleSelectedPlantPlacementLock() {
        guard let selectedPlant else {
            return
        }

        setSelectedPlantPlacementLocked(!selectedPlant.placementLocked)
    }

    func cloneSelectedPlant() {
        guard let selectedPlantID else {
            return
        }

        let clonedID = UUID()
        let nextState = userAuthoredCompositionState(
            GardenEngine.clonePlant(state, id: selectedPlantID, clonedID: clonedID)
        )
        let nextSelectedPlantID = nextState.plants.contains { $0.id == clonedID }
            ? clonedID
            : selectedPlantID
        replaceState(nextState, shouldSave: true, selectedPlantID: nextSelectedPlantID)
    }

    func setSelectedPlant(_ id: UUID?) {
        guard let id else {
            selectedPlantID = nil
            return
        }

        selectedPlantID = state.plants.contains { $0.id == id } ? id : nil
    }

    private func setSelectedPlantSilently(_ id: UUID?) {
        suppressSelectionChangePost = true
        selectedPlantID = id
        suppressSelectionChangePost = false
    }

    var activeGardenFileURL: URL {
        guard let activeSceneKey else {
            return persistence.fileURL
        }

        return persistence.fileURL(forSceneKey: activeSceneKey)
    }

    func switchGardenScene(
        to sceneKey: String,
        screenCount: Int,
        playingRadioStation: GardenRadioStation? = nil,
        playingRadioStream: GardenRadioStream? = nil,
        settingsOverride: GardenSettings? = nil
    ) {
        let carriedSettings = settingsOverride ?? state.settings
        save()
        setSelectedPlantSilently(nil)
        activeSceneKey = sceneKey
        let safeScreenCount = max(1, screenCount)

        do {
            let loadedState = try persistence.load(sceneKey: sceneKey)
                ?? Self.defaultState(
                    forSceneKey: sceneKey,
                    screenCount: safeScreenCount,
                    experienceMode: carriedSettings.experienceMode
                )
            let constrainedState = GardenEngine.constrainPlantsToScreenCount(
                loadedState,
                screenCount: safeScreenCount
            )
            let modeCleanedState = stateByRemovingAccidentalGardenBackfillIfNeeded(
                from: constrainedState,
                sceneKey: sceneKey,
                experienceMode: carriedSettings.experienceMode
            )
            var nextState = upgradedCompositionStateIfNeeded(
                from: modeCleanedState,
                screenCount: safeScreenCount,
                sceneKey: sceneKey
            ) ?? modeCleanedState
            nextState = GardenEngine.setSettings(nextState, settings: carriedSettings)
            nextState = Self.state(nextState, applyingGlobalPauseFrom: globalDefaults)
            if let playingRadioStream,
               let companion = GardenRadioCompanion.allCases.first(where: {
                   nextState.settings.radioStream(for: $0).id == playingRadioStream.id
               }) {
                nextState = GardenEngine.updateMusicButtonCompanion(nextState, companion: companion)
            } else if let playingRadioStation {
                nextState = GardenEngine.updateMusicButtonCompanion(
                    nextState,
                    companion: GardenRadioCompanion.companion(for: playingRadioStation)
                )
            }
            state = nextState
            lastError = nil
            save()
            postChange()
        } catch {
            lastError = error.localizedDescription
            let fallbackState = GardenEngine.setSettings(
                Self.defaultState(
                    forSceneKey: sceneKey,
                    screenCount: safeScreenCount,
                    experienceMode: carriedSettings.experienceMode
                ),
                settings: carriedSettings
            )
            state = Self.state(fallbackState, applyingGlobalPauseFrom: globalDefaults)
            save()
            postChange()
        }
    }

    func togglePaused() {
        setPaused(!state.isPaused)
    }

    func setPaused(_ isPaused: Bool) {
        globalDefaults.set(isPaused, forKey: Self.globalPauseDefaultsKey)
        replaceState(GardenEngine.setPaused(state, isPaused: isPaused), shouldSave: true)
    }

    func toggleAmbientWildlife() {
        replaceState(
            GardenEngine.setAmbientWildlifeEnabled(
                state,
                isEnabled: !state.isAmbientWildlifeEnabled
            ),
            shouldSave: true
        )
    }

    func setAmbientWildlifeEnabled(_ isEnabled: Bool) {
        replaceState(
            GardenEngine.setAmbientWildlifeEnabled(
                state,
                isEnabled: isEnabled
            ),
            shouldSave: true
        )
    }

    func setAmbientWildlifeEnabledForCurrentMode(_ isEnabled: Bool) {
        if state.settings.experienceMode == .roomStudio {
            var nextState = state
            nextState.settings = state.settings.updating(isRoomStudioWildlifeEnabled: isEnabled)
            if isEnabled {
                nextState.isAmbientWildlifeEnabled = true
            }
            nextState.lastUpdatedAt = Date()
            replaceState(nextState, shouldSave: true)
            return
        }
        setAmbientWildlifeEnabled(isEnabled)
    }

    func toggleAmbientWildlifeForCurrentMode() {
        setAmbientWildlifeEnabledForCurrentMode(!state.isEffectiveAmbientWildlifeEnabled)
    }

    /// Scene-scoped visual art direction. Each wallpaper scene has its own
    /// saved GardenState, so this naturally persists per scene.
    func setManualPlantDarkening(_ value: Double, persist: Bool = true) {
        replaceState(
            GardenEngine.setManualPlantDarkening(state, value: value),
            shouldSave: persist
        )
    }

    /// Updates settings. Pass `persist: false` for high-frequency updates
    /// (e.g. live slider drags) and call `save()` once the gesture settles.
    func updateSettings(_ settings: GardenSettings, persist: Bool = true) {
        replaceState(
            GardenEngine.setSettings(state, settings: settings),
            shouldSave: persist
        )
    }

    func updateProgression(_ progression: GardenSceneProgression?) {
        var nextState = state
        nextState.progression = progression
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
    }

    /// Pauses or resumes progression for the current scene without touching the
    /// earned level or fantasy profile. No-op when there is no profile or the
    /// flag is already in the requested state.
    func setProgressionEnabled(_ isEnabled: Bool) {
        guard let progression = state.progression,
              progression.isEnabled != isEnabled else {
            return
        }
        updateProgression(progression.settingEnabled(isEnabled))
    }

    /// Sets how often the current scene's ladder advances on its own. No-op when
    /// there is no profile or the cadence is unchanged.
    func setProgressionAutoAdvanceCadence(_ cadence: GardenSceneProgression.AutoAdvanceCadence) {
        guard let progression = state.progression,
              progression.autoAdvanceCadence != cadence else {
            return
        }
        updateProgression(progression.settingAutoAdvanceCadence(cadence))
    }

    /// Applies a fresh real-world weather snapshot. Not persisted eagerly;
    /// the autosave cycle covers it.
    func setWeather(_ weather: GardenWeatherCondition?) {
        replaceState(GardenEngine.setWeather(state, weather: weather), shouldSave: false)
    }

    func startFocusSession(duration: TimeInterval) {
        replaceState(GardenEngine.startFocusSession(state, duration: duration), shouldSave: true)
    }

    func cancelFocusSession() {
        replaceState(GardenEngine.cancelFocusSession(state), shouldSave: true)
    }

    func toggleMusicButton(
        screenIndex: Int,
        position: GardenPoint,
        companion: GardenRadioCompanion? = nil
    ) {
        if state.musicButtons.isEmpty {
            replaceState(
                GardenEngine.showMusicButton(
                    state,
                    screenIndex: screenIndex,
                    position: position,
                    companion: companion ?? .gardenCat
                ),
                shouldSave: true
            )
        } else {
            replaceState(GardenEngine.hideMusicButton(state), shouldSave: true)
        }
    }

    func addMusicButton(
        screenIndex: Int,
        position: GardenPoint,
        companion: GardenRadioCompanion
    ) {
        replaceState(
            GardenEngine.addMusicButton(
                state,
                screenIndex: screenIndex,
                position: position,
                companion: companion
            ),
            shouldSave: true
        )
    }

    func addGnomeTribeZone(screenIndex: Int, points: [GardenPoint]) {
        let zone = GnomeTribeZone(screenIndex: screenIndex, points: points)
        guard zone.isPlayable else {
            return
        }

        var nextState = state
        nextState.gnomeTribeZones.append(zone)
        nextState.gnomeSettlementPlan = GnomeTribeSettlementPlan(
            startedAt: nil,
            startingZoneID: nextState.gnomeSettlementPlan.startingZoneID ?? zone.id,
            expansionDurationDays: state.settings.gnomeSimulation.settlementExpansionDays
        )
        .normalized(for: nextState.gnomeTribeZones)
        nextState.areGnomeTribesHidden = false
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
        journal?.append(.moment, "A gnome settlement area was outlined")
    }

    func commitGnomeTribeSettlement(startingZoneID: UUID? = nil) {
        guard !state.gnomeTribeZones.isEmpty else {
            return
        }

        var nextState = state
        nextState.gnomeSettlementPlan = state.gnomeSettlementPlan.committed(
            at: Date(),
            startingZoneID: startingZoneID,
            zones: state.gnomeTribeZones,
            expansionDurationDays: state.settings.gnomeSimulation.settlementExpansionDays
        )
        nextState.areGnomeTribesHidden = false
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
        journal?.append(.moment, "A tiny gnome tribe began settling the outlined garden areas")
    }

    func setGnomeSettlementStartingZone(_ zoneID: UUID?) {
        guard state.gnomeSettlementPlan.startingZoneID != zoneID else {
            return
        }

        var nextState = state
        nextState.gnomeSettlementPlan = GnomeTribeSettlementPlan(
            startedAt: state.gnomeSettlementPlan.startedAt,
            startingZoneID: zoneID,
            expansionDurationDays: state.gnomeSettlementPlan.expansionDurationDays
        )
        .normalized(for: state.gnomeTribeZones)
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
    }

    func setGnomeTribesHidden(_ isHidden: Bool) {
        guard state.areGnomeTribesHidden != isHidden else {
            return
        }

        var nextState = state
        nextState.areGnomeTribesHidden = isHidden
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
    }

    func toggleGnomeTribesHidden() {
        setGnomeTribesHidden(!state.areGnomeTribesHidden)
    }

    func setGnomeTribePerspective(
        _ perspective: GnomeTribePerspective,
        shouldSave: Bool = true
    ) {
        guard state.gnomeTribePerspective != perspective else {
            return
        }

        var nextState = state
        nextState.gnomeTribePerspective = perspective
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: shouldSave)
    }

    func clearGnomeTribeZones() {
        guard !state.gnomeTribeZones.isEmpty else {
            return
        }

        var nextState = state
        nextState.gnomeTribeZones.removeAll()
        nextState.gnomeSettlementPlan = GnomeTribeSettlementPlan(startedAt: nil)
        nextState.areGnomeTribesHidden = false
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
        journal?.append(.moment, "The gnome tribes packed up their little camps")
    }

    func addBirdSkyZone(screenIndex: Int, points: [GardenPoint]) {
        let zone = BirdSkyZone(screenIndex: screenIndex, points: points)
        guard zone.isPlayable else {
            return
        }

        var nextState = state
        nextState.birdSkyZones.append(zone)
        nextState.areBirdFlocksHidden = false
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
        journal?.append(.moment, "A bird sky area was outlined")
    }

    func setBirdFlocksHidden(_ isHidden: Bool) {
        guard state.areBirdFlocksHidden != isHidden else {
            return
        }

        var nextState = state
        nextState.areBirdFlocksHidden = isHidden
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
    }

    func toggleBirdFlocksHidden() {
        setBirdFlocksHidden(!state.areBirdFlocksHidden)
    }

    func clearBirdSkyZones() {
        guard !state.birdSkyZones.isEmpty else {
            return
        }

        var nextState = state
        nextState.birdSkyZones.removeAll()
        nextState.areBirdFlocksHidden = false
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
        journal?.append(.moment, "The bird sky areas were cleared")
    }

    func addAutoGardenerZone(screenIndex: Int, points: [GardenPoint]) {
        let zone = AutoGardenerZone(screenIndex: screenIndex, points: points)
        guard zone.isPlayable else {
            return
        }

        var nextState = state
        nextState.autoGardenerZones.append(zone)
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
        journal?.append(.moment, "An Auto Gardener planting area was highlighted")
    }

    func updateAutoGardenerZone(
        id: UUID,
        placementType: AutoGardenerPlacementType? = nil,
        size: AutoGardenerSize? = nil
    ) {
        guard let index = state.autoGardenerZones.firstIndex(where: { $0.id == id }) else {
            return
        }

        var zone = state.autoGardenerZones[index]
        zone.placementType = placementType ?? zone.placementType
        zone.size = size ?? zone.size
        guard zone != state.autoGardenerZones[index] else {
            return
        }

        var nextState = state
        nextState.autoGardenerZones[index] = zone
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
    }

    @discardableResult
    func autoPlantGardenerZones() -> Int {
        let zones = state.autoGardenerZones.filter(\.isPlayable)
        guard !zones.isEmpty else {
            return 0
        }

        var nextState = state
        let initialGrowth: (PlantSpecies) -> Double = { species in
            self.state.settings.plantNewPlantsAtMaturity
                ? 1.0
                : PlantAssetLibrary.shared.initialGrowth(for: species)
        }
        var plantedCount = 0

        for zone in zones {
            let points = zone.plantingPoints()
            let species = zone.recommendedSpecies(sceneKey: activeSceneKey)
            for index in points.indices {
                let plantSpecies = species[index]
                nextState = GardenEngine.addPlant(
                    nextState,
                    species: plantSpecies,
                    screenIndex: zone.screenIndex,
                    position: points[index],
                    initialGrowth: initialGrowth(plantSpecies),
                    initialScale: zone.size.scale(for: plantSpecies) * state.settings.defaultPlantScale
                )
                plantedCount += 1
            }
        }

        guard plantedCount > 0 else {
            return 0
        }

        replaceState(
            userAuthoredCompositionState(nextState),
            shouldSave: true,
            selectedPlantID: nextState.plants.last?.id
        )
        journal?.append(.planted, "Auto Gardener planted \(plantedCount) plant\(plantedCount == 1 ? "" : "s")")
        return plantedCount
    }

    func clearAutoGardenerZones() {
        guard !state.autoGardenerZones.isEmpty else {
            return
        }

        var nextState = state
        nextState.autoGardenerZones.removeAll()
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
        journal?.append(.moment, "The Auto Gardener planting areas were cleared")
    }

    func addSoilPatch(screenIndex: Int, points: [GardenPoint], seed: Int? = nil) {
        let patch = SoilPatch(screenIndex: screenIndex, points: points, soilSeed: seed)
        guard patch.isPlayable else {
            return
        }

        var nextState = state
        nextState.soilPatches.append(patch)
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
        journal?.append(.moment, "A patch of fresh soil was laid down")
    }

    func clearAllSoilPatches() {
        guard !state.soilPatches.isEmpty else {
            return
        }

        var nextState = state
        nextState.soilPatches.removeAll()
        nextState.lastUpdatedAt = Date()
        replaceState(nextState, shouldSave: true)
        journal?.append(.moment, "The fresh soil patches were cleared")
    }

    func updateMusicButtonCompanion(_ companion: GardenRadioCompanion) {
        replaceState(
            GardenEngine.updateMusicButtonCompanion(state, companion: companion),
            shouldSave: true
        )
    }

    func moveMusicButton(to position: GardenPoint, screenIndex: Int) {
        replaceState(
            GardenEngine.moveMusicButton(state, to: position, screenIndex: screenIndex),
            shouldSave: false
        )
    }

    func moveMusicButton(at index: Int, to position: GardenPoint, screenIndex: Int) {
        replaceState(
            GardenEngine.moveMusicButton(state, at: index, to: position, screenIndex: screenIndex),
            shouldSave: false
        )
    }

    func resetGarden(screenCount: Int) {
        let resetState = state.settings.experienceMode == .roomStudio
            || state.settings.experienceMode == .rainforest
            ? GardenState(settings: state.settings)
            : GardenState.defaultGarden(screenCount: max(1, screenCount))
        replaceState(
            resetState,
            shouldSave: true,
            selectedPlantID: nil
        )
    }

    func arrangeGarden(screenCount: Int) {
        // Menu-invoked arrangement counts as the operator's layout choice.
        replaceState(
            userAuthoredCompositionState(GardenEngine.arrangeGarden(
                state,
                screenCount: max(1, screenCount),
                sceneKey: activeSceneKey
            )),
            shouldSave: true,
            selectedPlantID: nil
        )
    }

    func handleScreenConfigurationChange(screenCount: Int) {
        let nextState = GardenEngine.constrainPlantsToScreenCount(state, screenCount: max(1, screenCount))
        guard nextState != state else {
            return
        }

        replaceState(nextState, shouldSave: true)
    }

    func applyCompositionUpgradeIfNeeded(screenCount: Int) {
        guard let upgradedState = upgradedCompositionStateIfNeeded(
            from: state,
            screenCount: screenCount,
            sceneKey: activeSceneKey
        ) else {
            return
        }

        replaceState(upgradedState, shouldSave: true)
    }

    private func upgradedCompositionStateIfNeeded(
        from sourceState: GardenState,
        screenCount: Int,
        sceneKey: String?
    ) -> GardenState? {
        if let sceneKey,
           GardenWallpaperScene.scene(forKey: sceneKey)?.experienceMode != .garden {
            return nil
        }
        guard sourceState.settings.experienceMode == .garden else {
            return nil
        }

        // A garden the operator arranged by hand is theirs forever - no
        // composition-version bump may rearrange it.
        guard !sourceState.isUserArranged else {
            return nil
        }

        guard sourceState.compositionVersion != GardenComposition.currentVersion else {
            return nil
        }

        let screenCount = max(1, screenCount)
        var upgradedState = sourceState
        let existingSpecies = Set(upgradedState.plants.map(\.species))
        let missingSpecies = PlantSpecies.defaultGardenSpecies.filter { !existingSpecies.contains($0) }
        let upgradeDate = Date()

        for (offset, species) in missingSpecies.enumerated() {
            let index = upgradedState.plants.count + offset
            let plant = Plant(
                species: species,
                screenIndex: index % screenCount,
                position: GardenComposition.nextPosition(
                    for: species,
                    existingPlants: upgradedState.plants,
                    screenIndex: index % screenCount,
                    sceneKey: sceneKey
                ),
                plantedAt: upgradeDate.addingTimeInterval(-TimeInterval(offset + 1) * 2_400),
                lastTendedAt: upgradeDate,
                ageSeconds: TimeInterval(offset + 1) * 2_400,
                growth: min(0.92, 0.34 + Double(offset % 5) * 0.12),
                hydration: 0.70 + Double(offset % 3) * 0.06,
                health: 0.80 + Double(offset % 4) * 0.04,
                bloomProgress: species.kind == .tree ? 0.18 : min(0.84, 0.28 + Double(offset % 4) * 0.12),
                swaySeed: Double(index) * 149.0 + 29.0,
                scale: GardenComposition.scale(for: species, ordinal: offset)
            )
            upgradedState.plants.append(plant)
        }

        return GardenEngine.arrangeGarden(upgradedState, screenCount: screenCount, sceneKey: sceneKey)
    }

    private func stateByRemovingAccidentalGardenBackfillIfNeeded(
        from sourceState: GardenState,
        sceneKey: String?,
        experienceMode: GardenExperienceMode
    ) -> GardenState {
        let targetMode = sceneKey.flatMap { GardenWallpaperScene.scene(forKey: $0)?.experienceMode }
            ?? experienceMode
        guard targetMode != .garden,
              !sourceState.isUserArranged,
              !sourceState.plants.isEmpty else {
            return sourceState
        }

        let defaultGardenSpecies = Set(PlantSpecies.defaultGardenSpecies)
        let looksLikeDefaultGardenBackfill = sourceState.plants.allSatisfy { plant in
            plant.customAssetID == nil && defaultGardenSpecies.contains(plant.species)
        }
        guard looksLikeDefaultGardenBackfill else {
            return sourceState
        }

        var cleanedState = sourceState
        cleanedState.plants = []
        cleanedState.compositionVersion = GardenComposition.currentVersion
        cleanedState.lastUpdatedAt = Date()
        return cleanedState
    }

    private func userAuthoredCompositionState(_ nextState: GardenState) -> GardenState {
        guard nextState != state else {
            return nextState
        }

        var authoredState = nextState
        authoredState.compositionVersion = GardenComposition.currentVersion
        authoredState.isUserArranged = true
        return authoredState
    }

    func save() {
        save(shouldPostErrorChange: true)
    }

    private func save(shouldPostErrorChange: Bool) {
        let previousError = lastError
        do {
            if let activeSceneKey {
                try persistence.save(state, sceneKey: activeSceneKey)
            } else {
                try persistence.save(state)
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        if shouldPostErrorChange, previousError != lastError {
            postChange()
        }
    }

    private func replaceState(_ nextState: GardenState, shouldSave: Bool) {
        guard nextState != state else {
            return
        }

        state = nextState
        if shouldSave {
            save(shouldPostErrorChange: false)
        }
        postChange()
    }

    private static func state(
        _ state: GardenState,
        applyingGlobalPauseFrom defaults: UserDefaults
    ) -> GardenState {
        guard defaults.object(forKey: globalPauseDefaultsKey) != nil else {
            return state
        }
        let globalPause = defaults.bool(forKey: globalPauseDefaultsKey)
        guard state.isPaused != globalPause else {
            return state
        }
        return GardenEngine.setPaused(state, isPaused: globalPause)
    }

    private static func defaultState(
        forSceneKey sceneKey: String?,
        screenCount: Int,
        experienceMode: GardenExperienceMode = .garden
    ) -> GardenState {
        // A scene the operator opens for the first time always starts as a
        // blank canvas - in every mode - so switching scenes never dumps the
        // starter garden into the new one. The day-one starter garden is seeded
        // separately in AppDelegate.loadInitialState, so a brand-new install
        // still opens onto a planted desktop. A fresh GardenState already carries
        // the current compositionVersion, which keeps the composition-upgrade
        // backfill from repopulating it.
        let resolvedMode = sceneKey
            .flatMap { GardenWallpaperScene.scene(forKey: $0)?.experienceMode }
            ?? experienceMode
        return GardenState(settings: .default.updating(experienceMode: resolvedMode))
    }

    private func replaceState(_ nextState: GardenState, shouldSave: Bool, selectedPlantID nextSelectedPlantID: UUID?) {
        let selectionChanged = selectedPlantID != nextSelectedPlantID
        let stateChanged = nextState != state
        guard selectionChanged || stateChanged else {
            return
        }

        setSelectedPlantSilently(nextSelectedPlantID)
        if stateChanged {
            state = nextState
            if shouldSave {
                save(shouldPostErrorChange: false)
            }
        }
        postChange()
    }

    private func postChange() {
        NotificationCenter.default.post(name: .gardenStoreDidChange, object: self)
    }
}
