import Foundation

public enum GardenEngine {
    public static let maxCatchUpSeconds: TimeInterval = 12 * 60 * 60
    public static let minimumPlantScale = 0.30
    public static let maximumPlantScale = 3.00

    public static func advance(_ state: GardenState, to now: Date = Date()) -> GardenState {
        guard now >= state.lastUpdatedAt else {
            var correctedState = state
            correctedState.lastUpdatedAt = now
            return correctedState
        }

        var nextState = state
        let elapsedSeconds = min(now.timeIntervalSince(state.lastUpdatedAt), maxCatchUpSeconds)
        let elapsedHours = elapsedSeconds / 3_600

        guard elapsedHours > 0 else {
            return nextState
        }

        nextState.lastUpdatedAt = now

        if state.isPaused {
            return resolveCompletedFocusSession(nextState, at: now)
        }

        let activeWeather = nextState.weather.flatMap { $0.isStale(at: now) ? nil : $0 }
        let focusBoost = nextState.focusSession?.isActive(at: now) == true
            ? GardenFocusSession.growthBoost
            : 1.0
        let weatherGrowthFactor = activeWeather?.growthFactor ?? 1.0
        let rainHydrationGain = (activeWeather?.hydrationPerHour ?? 0) * elapsedHours
        let moistureTarget = activeWeather?.ambientMoistureTarget ?? 0.38

        let dailyWave = sin(now.timeIntervalSince1970 / 7_200)
        nextState.windStrength = (0.22 + dailyWave * 0.12).clampedUnit
        nextState.ambientMoisture = (state.ambientMoisture * 0.985 + moistureTarget * 0.015).clampedUnit
        let season = GardenSeasonCondition(at: now)
        let sunlight = GardenSunlightCondition(at: now)
        nextState.plants = state.plants.map { plant in
            let microclimate = PlantMicroclimate(plant: plant, state: nextState, at: now)
            let phenology = PlantPhenology(plant: plant, season: season)
            let companionEffect = PlantCompanionEffect(plant: plant, state: state)
            let bedAffinity = PlantBedAffinity(plant: plant)
            let moisturePreference = PlantMoisturePreference(plant: plant)
            let nutrientProfile = PlantNutrientProfile(plant: plant, at: now)
            let circadianState = PlantCircadianState(plant: plant, sunlight: sunlight)
            var advancedPlant = advancePlant(
                plant,
                elapsedHours: elapsedHours,
                ambientMoisture: nextState.ambientMoisture,
                growthSpeedMultiplier: state.settings.growthSpeedMultiplier * focusBoost * weatherGrowthFactor,
                waterUseMultiplier: state.settings.cozyModeEnabled ? min(state.settings.waterUseMultiplier, 0.45) : state.settings.waterUseMultiplier,
                microclimate: microclimate,
                phenology: phenology,
                companionEffect: companionEffect,
                bedAffinity: bedAffinity,
                moisturePreference: moisturePreference,
                nutrientProfile: nutrientProfile,
                circadianState: circadianState,
                milestoneDate: now
            )
            if state.settings.cozyModeEnabled {
                advancedPlant.diedAt = nil
                advancedPlant.health = max(0.42, advancedPlant.health)
                advancedPlant.hydration = max(0.24, advancedPlant.hydration)
            }
            if rainHydrationGain > 0, !advancedPlant.isDead {
                advancedPlant.hydration = (advancedPlant.hydration + rainHydrationGain).clampedUnit
            }
            return advancedPlant
        }

        // Resolved last so the completion reward lands on the advanced
        // plants instead of being overwritten by the advancement pass.
        return resolveCompletedFocusSession(nextState, at: now)
    }

    // MARK: - Weather

    public static func setWeather(
        _ state: GardenState,
        weather: GardenWeatherCondition?
    ) -> GardenState {
        guard state.weather != weather else {
            return state
        }

        var nextState = state
        nextState.weather = weather
        return nextState
    }

    // MARK: - Focus sessions

    public static func startFocusSession(
        _ state: GardenState,
        duration: TimeInterval,
        at date: Date = Date()
    ) -> GardenState {
        var nextState = state
        nextState.focusSession = GardenFocusSession(
            startedAt: date,
            duration: duration,
            startStageTotal: livingStageTotal(of: state)
        )
        return nextState
    }

    /// Sum of asset-stage indices across living plants - the coarse "visible
    /// growth" metric used for the focus-session payoff line.
    private static func livingStageTotal(of state: GardenState) -> Int {
        state.plants
            .filter { !$0.isDead }
            .reduce(0) { $0 + PlantAssetStage(growth: $1.growth).index }
    }

    public static func cancelFocusSession(_ state: GardenState) -> GardenState {
        guard state.focusSession != nil else {
            return state
        }

        var nextState = state
        nextState.focusSession = nil
        return nextState
    }

    /// When a focus session has run to completion, clears it, records stats,
    /// and grants every living plant a small bloom-and-health bonus.
    private static func resolveCompletedFocusSession(_ state: GardenState, at now: Date) -> GardenState {
        guard let session = state.focusSession, session.isCompleted(at: now) else {
            return state
        }

        var nextState = state
        nextState.focusSession = nil

        var stats = state.focusStats ?? GardenFocusStats()
        stats.completedSessions += 1
        stats.totalFocusSeconds += session.duration
        stats.lastCompletedAt = session.endsAt
        if let startStageTotal = session.startStageTotal {
            stats.lastSessionStagesGrown = max(0, livingStageTotal(of: state) - startStageTotal)
        } else {
            stats.lastSessionStagesGrown = nil
        }
        nextState.focusStats = stats

        nextState.plants = state.plants.map { plant in
            guard !plant.isDead else {
                return plant
            }

            var rewardedPlant = plant
            rewardedPlant.bloomProgress = (plant.bloomProgress + 0.06).clampedUnit
            rewardedPlant.health = (plant.health + 0.04).clampedUnit
            return rewardedPlant
        }
        return nextState
    }

    public static func waterAll(_ state: GardenState, amount: Double = 0.36, at date: Date = Date()) -> GardenState {
        var nextState = state
        nextState.plants = nextState.plants.map { waterPlant($0, amount: amount, at: date) }
        nextState.ambientMoisture = (nextState.ambientMoisture + 0.06).clampedUnit
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func waterPlant(_ state: GardenState, id: UUID, amount: Double = 0.42, at date: Date = Date()) -> GardenState {
        var didWaterPlant = false
        var nextState = state
        nextState.plants = nextState.plants.map { plant in
            guard plant.id == id else {
                return plant
            }

            let wateredPlant = waterPlant(plant, amount: amount, at: date)
            didWaterPlant = wateredPlant != plant
            return wateredPlant
        }
        if didWaterPlant {
            nextState.lastUpdatedAt = date
        }
        return nextState
    }

    public static func waterThirstyPlants(_ state: GardenState, amount: Double = 0.42, at date: Date = Date()) -> GardenState {
        let thirstyPlantIDs = Set(state.thirstyPlants.map(\.id))
        guard !thirstyPlantIDs.isEmpty else {
            return state
        }

        var nextState = state
        nextState.plants = nextState.plants.map { plant in
            thirstyPlantIDs.contains(plant.id) ? waterPlant(plant, amount: amount, at: date) : plant
        }
        nextState.ambientMoisture = (nextState.ambientMoisture + 0.035).clampedUnit
        nextState.lastUpdatedAt = date
        return nextState
    }

    /// Growth at or above this level counts as mature enough to yield seeds
    /// when pruned, and (for edibles) ready to harvest.
    public static let seedYieldGrowthThreshold = 0.70
    public static let harvestReadyGrowthThreshold = 0.85
    /// Inventory cap per species so decades of pruning can't overflow the UI.
    public static let maximumSeedsPerSpecies = 99

    public static func prunePlant(_ state: GardenState, id: UUID, at date: Date = Date()) -> GardenState {
        var didPrunePlant = false
        var seedSpecies: PlantSpecies?
        var nextState = state
        nextState.plants = nextState.plants.map { plant in
            guard plant.id == id else {
                return plant
            }

            guard !plant.isDead else {
                return plant
            }

            var tendedPlant = plant
            tendedPlant.health = (plant.health + 0.16).clampedUnit
            tendedPlant.bloomProgress = (plant.bloomProgress + 0.08).clampedUnit
            tendedPlant.growth = max(0.08, plant.growth - 0.015)
            tendedPlant.lastTendedAt = date
            didPrunePlant = tendedPlant != plant
            if didPrunePlant, plant.growth >= seedYieldGrowthThreshold {
                seedSpecies = plant.species
            }
            return tendedPlant
        }
        if didPrunePlant {
            if let seedSpecies {
                nextState = addingSeeds(nextState, species: seedSpecies, count: 1)
            }
            nextState.lastUpdatedAt = date
        }
        return nextState
    }

    /// Harvests a ready edible plant: counts the crop, yields seeds, and
    /// cycles the plant back to regrowth instead of removing it.
    public static func harvestPlant(_ state: GardenState, id: UUID, at date: Date = Date()) -> GardenState {
        var harvestedSpecies: PlantSpecies?
        var nextState = state
        nextState.plants = nextState.plants.map { plant in
            guard plant.id == id, plant.isHarvestReady else {
                return plant
            }

            harvestedSpecies = plant.species
            var harvestedPlant = plant
            harvestedPlant.growth = 0.30
            harvestedPlant.bloomProgress = 0.08
            harvestedPlant.health = (plant.health + 0.05).clampedUnit
            harvestedPlant.lastTendedAt = date
            return harvestedPlant
        }

        guard let harvestedSpecies else {
            return state
        }

        nextState.harvestTally[harvestedSpecies.rawValue, default: 0] += 1
        nextState = addingSeeds(nextState, species: harvestedSpecies, count: 2)
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func harvestReadyCrops(_ state: GardenState, at date: Date = Date()) -> GardenState {
        let readyPlants = state.plants.filter(\.isHarvestReady)
        guard !readyPlants.isEmpty else {
            return state
        }

        let readyPlantIDs = Set(readyPlants.map(\.id))
        var nextState = state
        nextState.plants = state.plants.map { plant in
            guard readyPlantIDs.contains(plant.id) else {
                return plant
            }

            var harvestedPlant = plant
            harvestedPlant.growth = 0.30
            harvestedPlant.bloomProgress = 0.08
            harvestedPlant.health = (plant.health + 0.05).clampedUnit
            harvestedPlant.lastTendedAt = date
            return harvestedPlant
        }

        for plant in readyPlants {
            nextState.harvestTally[plant.species.rawValue, default: 0] += 1
            nextState = addingSeeds(nextState, species: plant.species, count: 2)
        }
        nextState.lastUpdatedAt = date
        return nextState
    }

    /// Plants a seed from the inventory: a slow stage-zero seedling, in
    /// exchange for one seed of that species.
    public static func plantSeed(
        _ state: GardenState,
        species: PlantSpecies,
        screenIndex: Int,
        position: GardenPoint,
        at date: Date = Date()
    ) -> GardenState {
        guard state.seedInventory[species.rawValue, default: 0] > 0 else {
            return state
        }

        var nextState = addPlant(
            state,
            species: species,
            screenIndex: screenIndex,
            position: position,
            initialGrowth: 0.04,
            initialScale: state.settings.defaultPlantScale,
            at: date
        )
        guard nextState != state else {
            return state
        }

        nextState.seedInventory[species.rawValue] = max(0, state.seedInventory[species.rawValue, default: 0] - 1)
        if nextState.seedInventory[species.rawValue] == 0 {
            nextState.seedInventory.removeValue(forKey: species.rawValue)
        }
        return nextState
    }

    private static func addingSeeds(_ state: GardenState, species: PlantSpecies, count: Int) -> GardenState {
        var nextState = state
        let currentCount = state.seedInventory[species.rawValue, default: 0]
        nextState.seedInventory[species.rawValue] = min(maximumSeedsPerSpecies, currentCount + count)
        return nextState
    }

    public static func enjoyPlant(_ state: GardenState, id: UUID, at date: Date = Date()) -> GardenState {
        var didEnjoyPlant = false
        var nextState = state
        nextState.plants = nextState.plants.map { plant in
            guard plant.id == id else {
                return plant
            }

            guard !plant.isDead else {
                return plant
            }

            var tendedPlant = plant
            tendedPlant.health = (plant.health + 0.035).clampedUnit
            tendedPlant.bloomProgress = (plant.bloomProgress + 0.018).clampedUnit
            tendedPlant.lastTendedAt = date
            didEnjoyPlant = tendedPlant != plant
            return tendedPlant
        }
        if didEnjoyPlant {
            nextState.lastUpdatedAt = date
        }
        return nextState
    }

    public static func nourishPlant(_ state: GardenState, id: UUID, at date: Date = Date()) -> GardenState {
        var didNourishPlant = false
        var nextState = state
        nextState.plants = nextState.plants.map { plant in
            guard plant.id == id else {
                return plant
            }

            guard !plant.isDead else {
                return plant
            }

            var nourishedPlant = plant
            let vitalityFactor = 0.58 + min(plant.health, plant.hydration) * 0.42
            let growthBoost = plant.species.growthPerHour * 2.4 * vitalityFactor
            nourishedPlant.growth = (plant.growth + growthBoost).clampedUnit
            nourishedPlant.health = (plant.health + 0.075).clampedUnit
            if nourishedPlant.growth > 0.55 {
                nourishedPlant.bloomProgress = (plant.bloomProgress + 0.045).clampedUnit
            }
            markStageChangeIfNeeded(on: &nourishedPlant, previousGrowth: plant.growth, at: date)
            nourishedPlant.lastTendedAt = date
            nourishedPlant.lastNourishedAt = date
            didNourishPlant = nourishedPlant != plant
            return nourishedPlant
        }
        if didNourishPlant {
            nextState.lastUpdatedAt = date
        }
        return nextState
    }

    public static func addPlant(
        _ state: GardenState,
        species: PlantSpecies,
        screenIndex: Int,
        position: GardenPoint,
        initialGrowth: Double = 0.08,
        initialScale: Double = 1.0,
        at date: Date = Date()
    ) -> GardenState {
        var nextState = state
        let newPlant = Plant(
            species: species,
            screenIndex: max(0, screenIndex),
            position: position,
            plantedAt: date,
            lastTendedAt: date,
            growth: min(1, max(0, initialGrowth)),
            hydration: 0.82,
            health: 0.88,
            scale: min(maximumPlantScale, max(minimumPlantScale, initialScale))
        )
        nextState.plants.append(newPlant)
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func clonePlant(
        _ state: GardenState,
        id: UUID,
        clonedID: UUID = UUID(),
        at date: Date = Date()
    ) -> GardenState {
        guard !state.plants.contains(where: { $0.id == clonedID }),
              var clonedPlant = state.plants.first(where: { $0.id == id }) else {
            return state
        }

        let preferredPosition = GardenPoint(
            x: clonedPlant.position.x + 0.075,
            y: clonedPlant.position.y + 0.018
        )
        clonedPlant.id = clonedID
        clonedPlant.position = GardenComposition.resolvedPlantingPosition(
            for: clonedPlant.species,
            preferredPosition: preferredPosition,
            existingPlants: state.plants,
            screenIndex: clonedPlant.screenIndex
        )

        var nextState = state
        nextState.plants.append(clonedPlant)
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func arrangeGarden(
        _ state: GardenState,
        screenCount: Int,
        sceneKey: String? = nil,
        at date: Date = Date()
    ) -> GardenState {
        var nextState = state
        nextState.version = GardenState.schemaVersion
        nextState.compositionVersion = GardenComposition.currentVersion
        nextState.plants = GardenComposition.arrangedPlants(
            state.plants,
            screenCount: screenCount,
            sceneKey: sceneKey
        )
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func constrainPlantsToScreenCount(
        _ state: GardenState,
        screenCount: Int,
        at date: Date = Date()
    ) -> GardenState {
        let safeScreenCount = max(1, screenCount)
        var didMovePlant = false
        var nextState = state
        nextState.plants = state.plants.map { plant in
            let normalizedScreenIndex = plant.screenIndex < 0
                ? 0
                : plant.screenIndex % safeScreenCount
            guard normalizedScreenIndex != plant.screenIndex else {
                return plant
            }

            var movedPlant = plant
            movedPlant.screenIndex = normalizedScreenIndex
            didMovePlant = true
            return movedPlant
        }

        let constrainedMusicButtons = state.musicButtons.map { musicButton in
            let normalizedScreenIndex = musicButton.screenIndex < 0
                ? 0
                : musicButton.screenIndex % safeScreenCount
            guard normalizedScreenIndex != musicButton.screenIndex else {
                return musicButton
            }

            didMovePlant = true
            return GardenMusicButton(
                screenIndex: normalizedScreenIndex,
                position: musicButton.position,
                companion: musicButton.companion
            )
        }
        if constrainedMusicButtons != state.musicButtons {
            nextState.musicButtons = constrainedMusicButtons
        }

        let constrainedGnomeZones = state.gnomeTribeZones.map { zone in
            let normalizedScreenIndex = zone.screenIndex < 0
                ? 0
                : zone.screenIndex % safeScreenCount
            guard normalizedScreenIndex != zone.screenIndex else {
                return zone
            }

            didMovePlant = true
            return GnomeTribeZone(
                id: zone.id,
                screenIndex: normalizedScreenIndex,
                points: zone.points,
                createdAt: zone.createdAt,
                cultureSeed: zone.cultureSeed
            )
        }
        if constrainedGnomeZones != state.gnomeTribeZones {
            nextState.gnomeTribeZones = constrainedGnomeZones
            nextState.gnomeSettlementPlan = state.gnomeSettlementPlan.normalized(for: constrainedGnomeZones)
        }

        let constrainedBirdSkyZones = state.birdSkyZones.map { zone in
            let normalizedScreenIndex = zone.screenIndex < 0
                ? 0
                : zone.screenIndex % safeScreenCount
            guard normalizedScreenIndex != zone.screenIndex else {
                return zone
            }

            didMovePlant = true
            return BirdSkyZone(
                id: zone.id,
                screenIndex: normalizedScreenIndex,
                points: zone.points,
                createdAt: zone.createdAt,
                skySeed: zone.skySeed
            )
        }
        if constrainedBirdSkyZones != state.birdSkyZones {
            nextState.birdSkyZones = constrainedBirdSkyZones
        }

        if didMovePlant {
            nextState.lastUpdatedAt = date
        }
        return nextState
    }

    public static func removePlant(_ state: GardenState, id: UUID, at date: Date = Date()) -> GardenState {
        var nextState = state
        let originalCount = nextState.plants.count
        nextState.plants.removeAll { $0.id == id }
        guard nextState.plants.count != originalCount else {
            return state
        }

        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func removeAllPlants(_ state: GardenState, at date: Date = Date()) -> GardenState {
        guard !state.plants.isEmpty else {
            return state
        }

        var nextState = state
        nextState.plants.removeAll()
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func resetPlantsToNascentGrowth(
        _ state: GardenState,
        at date: Date = Date(),
        initialGrowthForPlant: (Plant) -> Double = { _ in 0.08 }
    ) -> GardenState {
        guard !state.plants.isEmpty else {
            return state
        }

        var didResetPlant = false
        var nextState = state
        nextState.plants = state.plants.map { plant in
            var resetPlant = plant
            resetPlant.plantedAt = date
            resetPlant.lastTendedAt = date
            resetPlant.ageSeconds = 0
            resetPlant.growth = initialGrowthForPlant(plant).clampedUnit
            resetPlant.hydration = max(0.82, plant.hydration).clampedUnit
            resetPlant.health = max(0.88, plant.health).clampedUnit
            resetPlant.bloomProgress = 0
            resetPlant.lastStageChangedAt = date
            resetPlant.lastWateredAt = nil
            resetPlant.lastNourishedAt = nil
            resetPlant.diedAt = nil
            didResetPlant = didResetPlant || resetPlant != plant
            return resetPlant
        }

        guard didResetPlant else {
            return state
        }

        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func movePlant(
        _ state: GardenState,
        id: UUID,
        to position: GardenPoint,
        screenIndex: Int? = nil,
        at date: Date = Date()
    ) -> GardenState {
        var didMovePlant = false
        var nextState = state
        nextState.plants = state.plants.map { plant in
            guard plant.id == id else {
                return plant
            }

            let resolvedPosition = position.clamped
            let resolvedScreenIndex = screenIndex.map { max(0, $0) } ?? plant.screenIndex
            guard resolvedPosition != plant.position || resolvedScreenIndex != plant.screenIndex else {
                return plant
            }

            var movedPlant = plant
            movedPlant.position = resolvedPosition
            movedPlant.screenIndex = resolvedScreenIndex
            didMovePlant = true
            return movedPlant
        }
        if didMovePlant {
            nextState.lastUpdatedAt = date
        }
        return nextState
    }

    public static func resizePlant(
        _ state: GardenState,
        id: UUID,
        toScale scale: Double,
        maximumScale: Double = maximumPlantScale,
        at date: Date = Date()
    ) -> GardenState {
        guard scale.isFinite else {
            return state
        }

        let safeMaximumScale = max(minimumPlantScale, maximumScale)
        let resolvedScale = min(safeMaximumScale, max(minimumPlantScale, scale))
        var didResizePlant = false
        var nextState = state
        nextState.plants = state.plants.map { plant in
            guard plant.id == id else {
                return plant
            }

            guard plant.scale != resolvedScale else {
                return plant
            }

            var resizedPlant = plant
            resizedPlant.scale = resolvedScale
            didResizePlant = true
            return resizedPlant
        }
        if didResizePlant {
            nextState.lastUpdatedAt = date
        }
        return nextState
    }

    public static func setPlantPlacementLocked(
        _ state: GardenState,
        id: UUID,
        isLocked: Bool,
        at date: Date = Date()
    ) -> GardenState {
        var didChangePlant = false
        var nextState = state
        nextState.plants = state.plants.map { plant in
            guard plant.id == id, plant.placementLocked != isLocked else {
                return plant
            }

            var lockedPlant = plant
            lockedPlant.placementLocked = isLocked
            didChangePlant = true
            return lockedPlant
        }
        if didChangePlant {
            nextState.lastUpdatedAt = date
        }
        return nextState
    }

    public static func setPaused(_ state: GardenState, isPaused: Bool, at date: Date = Date()) -> GardenState {
        var nextState = state
        nextState.isPaused = isPaused
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func setAmbientWildlifeEnabled(
        _ state: GardenState,
        isEnabled: Bool,
        at date: Date = Date()
    ) -> GardenState {
        var nextState = state
        nextState.isAmbientWildlifeEnabled = isEnabled
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func setManualPlantDarkening(
        _ state: GardenState,
        value: Double,
        at date: Date = Date()
    ) -> GardenState {
        let boundedValue = value.clamped(to: 0...0.60)
        guard abs(state.manualPlantDarkening - boundedValue) > 0.0001 else {
            return state
        }

        var nextState = state
        nextState.manualPlantDarkening = boundedValue
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func setSettings(
        _ state: GardenState,
        settings: GardenSettings,
        at date: Date = Date()
    ) -> GardenState {
        guard state.settings != settings else {
            return state
        }

        var nextState = state
        nextState.settings = settings
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func showMusicButton(
        _ state: GardenState,
        screenIndex: Int,
        position: GardenPoint,
        companion: GardenRadioCompanion = .gardenCat,
        at date: Date = Date()
    ) -> GardenState {
        var nextState = state
        nextState.musicButtons = [GardenMusicButton(
            screenIndex: screenIndex,
            position: position,
            companion: companion
        )]
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func addMusicButton(
        _ state: GardenState,
        screenIndex: Int,
        position: GardenPoint,
        companion: GardenRadioCompanion = .gardenCat,
        at date: Date = Date()
    ) -> GardenState {
        var nextState = state
        nextState.musicButtons.append(GardenMusicButton(
            screenIndex: screenIndex,
            position: position,
            companion: companion
        ))
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func hideMusicButton(_ state: GardenState, at date: Date = Date()) -> GardenState {
        guard !state.musicButtons.isEmpty else {
            return state
        }

        var nextState = state
        nextState.musicButtons.removeAll()
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func moveMusicButton(
        _ state: GardenState,
        to position: GardenPoint,
        screenIndex: Int,
        at date: Date = Date()
    ) -> GardenState {
        moveMusicButton(state, at: 0, to: position, screenIndex: screenIndex, at: date)
    }

    public static func moveMusicButton(
        _ state: GardenState,
        at index: Int,
        to position: GardenPoint,
        screenIndex: Int,
        at date: Date = Date()
    ) -> GardenState {
        guard state.musicButtons.indices.contains(index) else {
            return state
        }

        let musicButton = state.musicButtons[index]
        let nextButton = GardenMusicButton(
            screenIndex: screenIndex,
            position: position,
            companion: musicButton.companion
        )
        guard musicButton != nextButton else {
            return state
        }

        var nextState = state
        nextState.musicButtons[index] = nextButton
        nextState.lastUpdatedAt = date
        return nextState
    }

    public static func updateMusicButtonCompanion(
        _ state: GardenState,
        companion: GardenRadioCompanion,
        at date: Date = Date()
    ) -> GardenState {
        guard let musicButton = state.musicButton,
              musicButton.companion != companion else {
            return state
        }

        var nextState = state
        nextState.musicButtons[0] = GardenMusicButton(
            screenIndex: musicButton.screenIndex,
            position: musicButton.position,
            companion: companion
        )
        nextState.lastUpdatedAt = date
        return nextState
    }

    private static func advancePlant(
        _ plant: Plant,
        elapsedHours: Double,
        ambientMoisture: Double,
        growthSpeedMultiplier: Double,
        waterUseMultiplier: Double,
        microclimate: PlantMicroclimate,
        phenology: PlantPhenology,
        companionEffect: PlantCompanionEffect,
        bedAffinity: PlantBedAffinity,
        moisturePreference: PlantMoisturePreference,
        nutrientProfile: PlantNutrientProfile,
        circadianState: PlantCircadianState,
        milestoneDate: Date
    ) -> Plant {
        var nextPlant = plant
        let species = plant.species
        let isProtectedStructurePlanting = isProtectedStructurePlanting(
            plant: plant,
            companionEffect: companionEffect,
            bedAffinity: bedAffinity
        )

        if plant.isDead && isProtectedStructurePlanting {
            nextPlant.diedAt = nil
            nextPlant.health = max(0.34, plant.health)
            nextPlant.hydration = max(0.34, plant.hydration)
        }

        if nextPlant.isDead {
            nextPlant.ageSeconds += elapsedHours * 3_600
            nextPlant.health = 0
            nextPlant.hydration = max(0, nextPlant.hydration - species.waterUsePerHour * 0.10 * elapsedHours * waterUseMultiplier)
            nextPlant.bloomProgress = max(0, nextPlant.bloomProgress - 0.04 * elapsedHours)
            nextPlant.diedAt = nextPlant.diedAt ?? milestoneDate
            return nextPlant
        }

        let waterUse = species.waterUsePerHour * (1.0 + nextPlant.growth * 0.28) * (1.0 - ambientMoisture * 0.22)
            * microclimate.waterUseFactor
            * companionEffect.waterUseMultiplier
            * bedAffinity.waterUseMultiplier
            * moisturePreference.waterUseMultiplier
            * circadianState.waterUseMultiplier
            * waterUseMultiplier

        nextPlant.ageSeconds += elapsedHours * 3_600
        nextPlant.hydration = (nextPlant.hydration - waterUse * elapsedHours).clampedUnit
        let nextMoisturePreference = PlantMoisturePreference(species: species, hydration: nextPlant.hydration)

        if nextMoisturePreference.fit != .parched && nextPlant.health > 0.22 {
            let healthFactor = 0.45 + nextPlant.health * 0.65
            nextPlant.growth = (
                nextPlant.growth
                    + species.growthPerHour * elapsedHours * nextMoisturePreference.growthMultiplier
                    * healthFactor * microclimate.growthFactor
                    * companionEffect.growthMultiplier
                    * bedAffinity.growthMultiplier
                    * nutrientProfile.growthMultiplier
                    * circadianState.growthMultiplier
                    * growthSpeedMultiplier
            ).clampedUnit
        }

        nextPlant.health = (nextPlant.health + nextMoisturePreference.healthAdjustmentPerHour * elapsedHours).clampedUnit
        nextPlant.health = (
            nextPlant.health
                + (microclimate.healthAdjustmentPerHour + companionEffect.healthAdjustmentPerHour) * elapsedHours
                + bedAffinity.healthAdjustmentPerHour * elapsedHours
                + nutrientProfile.healthAdjustmentPerHour * elapsedHours
                + circadianState.healthAdjustmentPerHour * elapsedHours
        ).clampedUnit

        if nextMoisturePreference.fit == .parched {
            let drynessSeverity = (
                1 - nextPlant.hydration / max(0.001, nextMoisturePreference.urgentHydrationThreshold)
            ).clampedUnit
            let neglectDamagePerHour = 0.018 + drynessSeverity * 0.032
            nextPlant.health = max(0, nextPlant.health - neglectDamagePerHour * elapsedHours)
        }

        if isProtectedStructurePlanting {
            nextPlant.health = max(0.32, nextPlant.health)
        }

        if nextPlant.growth > 0.62 && nextPlant.health > 0.42 && nextPlant.hydration > 0.24 {
            let bloomBoost = species.bloomPerHour * elapsedHours * (0.5 + nextPlant.health * 0.5)
                * (0.88 + microclimate.growthFactor * 0.12)
                * phenology.bloomMultiplier
                * companionEffect.bloomMultiplier
                * bedAffinity.bloomMultiplier
                * nutrientProfile.bloomMultiplier
                * circadianState.bloomMultiplier
            nextPlant.bloomProgress = (plant.bloomProgress + bloomBoost).clampedUnit
        }

        if nextPlant.hydration < 0.16 {
            nextPlant.bloomProgress = max(0, nextPlant.bloomProgress - 0.018 * elapsedHours)
        } else if phenology.bloomFadePerHour > 0 {
            nextPlant.bloomProgress = max(0, nextPlant.bloomProgress - phenology.bloomFadePerHour * elapsedHours)
        }

        if nextPlant.health < 0.16 {
            let wiltSeverity = ((0.16 - nextPlant.health) / 0.16).clampedUnit
            nextPlant.bloomProgress = max(0, nextPlant.bloomProgress - (0.018 + wiltSeverity * 0.035) * elapsedHours)
        }

        if nextPlant.health <= Plant.deathHealthThreshold {
            nextPlant.health = 0
            nextPlant.hydration = 0
            nextPlant.bloomProgress = 0
            nextPlant.diedAt = milestoneDate
        }

        markStageChangeIfNeeded(on: &nextPlant, previousGrowth: plant.growth, at: milestoneDate)
        return nextPlant
    }

    private static func isProtectedStructurePlanting(
        plant: Plant,
        companionEffect: PlantCompanionEffect,
        bedAffinity: PlantBedAffinity
    ) -> Bool {
        plant.species.isSupportTrainedClimber
            && (bedAffinity.fit == .support || companionEffect.relationship == .trainedClimber)
    }

    private static func waterPlant(_ plant: Plant, amount: Double, at date: Date) -> Plant {
        guard !plant.isDead else {
            return plant
        }

        var wateredPlant = plant
        wateredPlant.hydration = (plant.hydration + amount).clampedUnit
        wateredPlant.health = (plant.health + 0.055).clampedUnit
        wateredPlant.lastTendedAt = date
        wateredPlant.lastWateredAt = date
        return wateredPlant
    }

    private static func markStageChangeIfNeeded(on plant: inout Plant, previousGrowth: Double, at date: Date) {
        let previousStage = PlantAssetStage(growth: previousGrowth).index
        let currentStage = PlantAssetStage(growth: plant.growth).index
        guard currentStage > previousStage else {
            return
        }

        plant.lastStageChangedAt = date
    }
}
