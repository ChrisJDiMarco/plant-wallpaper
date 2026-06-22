import AppKit
import IOKit.ps
import PlantGardenCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: GardenStore?
    private var overlayController: GardenOverlayController?
    private var rainbowMoment: RainbowMomentController?
    private var gnomeTribes: GnomeTribeController?
    private var birdFlocks: BirdFlockController?
    private var catCompanion: CatCompanionController?
    private var statusMenu: GardenStatusMenu?
    private var wallpaperManager: WallpaperManager?
    private var weatherService: GardenWeatherService?
    private var momentNotifier: GardenMomentNotifier?
    private var timeLapseRecorder: GardenTimeLapseRecorder?
    private let ambienceEngine = GardenAmbienceEngine()
    private var welcomeController: GardenWelcomeController?
    private var simulationTimer: Timer?
    private var displayTimer: Timer?
    private var autosaveTimer: Timer?
    private var screenSaverSnapshotTimer: Timer?
    private var smartLockWallpaperTask: Task<Void, Never>?
    private var screenParametersObserver: NSObjectProtocol?
    private var storeChangeObserver: NSObjectProtocol?
    private var displayRefreshInterval: TimeInterval?
    private var lastTimeLapseCheckDay: String?
    private var lastGardenInteractionLocked = false
    private var lastUseAIGeneratedLockSnapshot = GardenSettings.default.useAIGeneratedLockSnapshot
    private var isSmartLockWallpaperActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateDuplicateInstances()
        installMainMenu()
        let persistence = GardenPersistence()
        let wallpaperManager = WallpaperManager(baseDirectoryURL: persistence.directoryURL)
        let screens = NSScreen.screens
        let screenCount = max(1, screens.count)
        let activeSceneKey = wallpaperManager.selectedWallpaperSceneKey
        let initialState = loadInitialState(
            persistence: persistence,
            activeSceneKey: activeSceneKey,
            screenCount: screenCount
        )
        let gardenStore = GardenStore(state: initialState, persistence: persistence, activeSceneKey: activeSceneKey)
        gardenStore.journal = GardenJournalStore(directoryURL: persistence.directoryURL)
        GardenRadioPlayer.shared.setVolume(gardenStore.state.settings.musicVolume)
        gardenStore.applyCompositionUpgradeIfNeeded(screenCount: screenCount)
        gardenStore.handleScreenConfigurationChange(screenCount: screenCount)
        gardenStore.removePlantsWithoutDisplayableAssets()
        gardenStore.save()
        lastGardenInteractionLocked = gardenStore.state.settings.isGardenInteractionLocked
        lastUseAIGeneratedLockSnapshot = gardenStore.state.settings.useAIGeneratedLockSnapshot
        wallpaperManager.applyLivingSceneWallpaper(to: targetScreens(from: screens, settings: gardenStore.state.settings))
        let overlayController = GardenOverlayController(store: gardenStore)

        let timeLapseRecorder = GardenTimeLapseRecorder(baseDirectoryURL: persistence.directoryURL)
        GardenTimeLapseExporter.shared.recorder = timeLapseRecorder
        self.timeLapseRecorder = timeLapseRecorder

        self.store = gardenStore
        self.overlayController = overlayController
        self.wallpaperManager = wallpaperManager
        let statusMenu = GardenStatusMenu(store: gardenStore, wallpaperManager: wallpaperManager)
        self.statusMenu = statusMenu
        overlayController.desktopPlantingMenuRequestHandler = { [weak statusMenu] screenPoint in
            statusMenu?.openPlantingMenu(at: screenPoint)
        }
        overlayController.gnomePerspectiveDoneHandler = { [weak statusMenu] in
            statusMenu?.endGnomePerspectiveAdjustmentMode()
        }
        self.weatherService = GardenWeatherService(store: gardenStore)
        let momentNotifier = GardenMomentNotifier(store: gardenStore)
        self.momentNotifier = momentNotifier
        statusMenu.progressionLevelCelebrationHandler = { [weak momentNotifier] level, title, isFinalLevel in
            momentNotifier?.celebrateProgressionLevel(level: level, title: title, isFinalLevel: isFinalLevel)
        }
        statusMenu.regenerateSmartLockWallpaperHandler = { [weak self] in
            self?.regenerateSmartLockWallpaper()
        }

        overlayController.show()
        scheduleScreenSaverSnapshotPublish(delay: 0.15)

        let rainbowMoment = RainbowMomentController(store: gardenStore)
        self.rainbowMoment = rainbowMoment
        rainbowMoment.show()

        let gnomeTribes = GnomeTribeController(store: gardenStore)
        self.gnomeTribes = gnomeTribes
        gnomeTribes.show()

        let birdFlocks = BirdFlockController(store: gardenStore)
        self.birdFlocks = birdFlocks
        birdFlocks.show()

        // Cat windows are created after the garden so they stack above it.
        let catCompanion = CatCompanionController(
            isChatOnClickEnabled: { [weak gardenStore] in
                gardenStore?.state.settings.isCatChatOnClickEnabled ?? true
            },
            foregroundGardenElementContains: { [weak overlayController] point in
                overlayController?.containsForegroundGardenElement(at: point) ?? false
            },
            catChatBlockingGardenElementContains: { [weak overlayController] point in
                overlayController?.containsCatChatBlockingGardenElement(at: point) ?? false
            },
            desktopSceneCanReceiveClick: { [weak overlayController] point in
                overlayController?.canReceiveDesktopSceneClick(at: point) ?? false
            },
            gnomeTerritoryProvider: { [weak gardenStore] in
                guard let gardenStore,
                      GnomeTribeController.shouldShow(for: gardenStore.state) else {
                    return []
                }
                return gardenStore.state.gnomeTribeZones
            },
            plantMissionTargetProvider: { [weak gardenStore] in
                guard let gardenStore,
                      GnomeTribeController.shouldShow(for: gardenStore.state) else {
                    return []
                }
                return gardenStore.state.plants
            },
            chatContextProvider: { [weak gardenStore, weak wallpaperManager] in
                guard let gardenStore, let wallpaperManager else {
                    return nil
                }
                let key = wallpaperManager.selectedWallpaperSceneKey
                let sceneName = GardenWallpaperScene(rawValue: key)?.displayName
                    ?? wallpaperManager.customWallpapers.first { $0.key == key }?.displayName
                    ?? "Custom Scene"
                return GardenAssistantRuntimeContext(
                    state: gardenStore.state,
                    activeSceneDisplayName: sceneName,
                    activeSceneKey: key,
                    selectedPlant: gardenStore.selectedPlant
                )
            },
            chatCommandExecutor: { [weak statusMenu] action in
                statusMenu?.performCatCompanionCommand(action)
                    ?? .unavailable("I understood that app command, but the garden menu is not ready yet. Try again in a moment.")
            }
        )
        self.catCompanion = catCompanion
        overlayController.wallCatClickClaimHandler = { [weak catCompanion] point in
            catCompanion?.claimWallClickIfNeeded(at: point) ?? false
        }
        catCompanion.show()

        startTimers()

        let welcomeController = GardenWelcomeController(store: gardenStore)
        self.welcomeController = welcomeController
        welcomeController.showIfFirstRun()

        if CommandLine.arguments.contains("--open-settings") {
            statusMenu.openSettingsWindow()
        }
        if CommandLine.arguments.contains("--play-radio") {
            // Same code path as the settings window's radio playback button.
            GardenRadioPlayer.shared.toggleChillHopRadio()
        }

        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.screensDidChange()
            }
        }
        storeChangeObserver = NotificationCenter.default.addObserver(
            forName: .gardenStoreDidChange,
            object: gardenStore,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.gardenStoreDidChangeForDisplay()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.save()
        overlayController?.shutdown()
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
            self.screenParametersObserver = nil
        }
        if let storeChangeObserver {
            NotificationCenter.default.removeObserver(storeChangeObserver)
            self.storeChangeObserver = nil
        }
        simulationTimer?.invalidate()
        displayTimer?.invalidate()
        autosaveTimer?.invalidate()
        screenSaverSnapshotTimer?.invalidate()
        smartLockWallpaperTask?.cancel()
        publishScreenSaverSnapshot()
        ambienceEngine.setMix(.silent)
    }

    private func loadInitialState(
        persistence: GardenPersistence,
        activeSceneKey: String?,
        screenCount: Int
    ) -> GardenState {
        if let activeSceneKey {
            do {
                if let sceneState = try persistence.load(sceneKey: activeSceneKey) {
                    return sceneState
                }
            } catch {
                quarantineCorruptGardenFile(persistence: persistence, sceneKey: activeSceneKey, error: error)
            }
        }

        do {
            if let defaultState = try persistence.load() {
                return defaultState
            }
        } catch {
            quarantineCorruptGardenFile(persistence: persistence, sceneKey: nil, error: error)
        }

        return GardenState.defaultGarden(screenCount: screenCount)
    }

    private func quarantineCorruptGardenFile(
        persistence: GardenPersistence,
        sceneKey: String?,
        error: Error
    ) {
        do {
            if let quarantineURL = try persistence.quarantineGardenFile(sceneKey: sceneKey) {
                NSLog(
                    "Plant Wallpaper moved unreadable garden data to %@ after load failed: %@",
                    quarantineURL.path,
                    error.localizedDescription
                )
            }
        } catch {
            NSLog("Plant Wallpaper could not quarantine unreadable garden data: \(error.localizedDescription)")
        }
    }

    /// Two live instances (e.g. a debug binary next to the packaged app)
    /// each draw their own garden and cat on the desktop. Newest instance
    /// wins; older ones are asked to quit, forcefully if they ignore it.
    private func terminateDuplicateInstances() {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let duplicates = NSWorkspace.shared.runningApplications.filter { app in
            app.processIdentifier != myPID
                && app.executableURL?.lastPathComponent == "PlantWallpaper"
        }
        guard !duplicates.isEmpty else {
            return
        }

        for app in duplicates {
            NSLog("Plant Wallpaper terminating duplicate instance pid %d", app.processIdentifier)
            app.terminate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            for app in duplicates where !app.isTerminated {
                app.forceTerminate()
            }
        }
    }

    /// Accessory (menu bar) apps have no main menu by default, which silently
    /// disables Cmd+C/V/X/A/Z in every text field (Spotify link, API key,
    /// AI prompts). Install a minimal menu so standard editing shortcuts work.
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Plant Wallpaper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApplication.shared.mainMenu = mainMenu
    }

    private func startTimers() {
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.simulationTimerFired()
            }
        }

        updateDisplayCadence()

        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.autosaveTimerFired()
            }
        }
    }

    private func scheduleDisplayTimer(interval: TimeInterval) {
        let safeInterval = max(0.25, interval)
        if let displayRefreshInterval,
           abs(displayRefreshInterval - safeInterval) < 0.001,
           displayTimer?.isValid == true {
            return
        }

        displayTimer?.invalidate()
        displayRefreshInterval = safeInterval
        displayTimer = Timer.scheduledTimer(withTimeInterval: safeInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.displayTimerFired()
            }
        }
        displayTimer?.tolerance = min(safeInterval * 0.2, 0.25)
    }

    private func updateDisplayCadence(at date: Date = Date()) {
        let interval: TimeInterval
        if store?.hasPendingCustomPlantAssets == true {
            interval = GardenDisplayCadence.activeRefreshInterval
        } else if let settings = store?.state.settings {
            let baseInterval = store?.state.displayCadence(at: date).refreshInterval
                ?? GardenDisplayCadence.calmRefreshInterval
            let effectivePerformanceMode: GardenPerformanceMode = shouldUseAutomaticLowPowerCadence(settings: settings)
                ? .still
                : settings.performanceMode
            switch effectivePerformanceMode {
            case .still:
                interval = max(baseInterval, 4.0)
            case .balanced:
                interval = baseInterval
            case .lively:
                interval = min(baseInterval, GardenDisplayCadence.activeRefreshInterval)
            }
        } else {
            interval = GardenDisplayCadence.calmRefreshInterval
        }
        scheduleDisplayTimer(interval: interval)
    }

    private func shouldUseAutomaticLowPowerCadence(settings: GardenSettings) -> Bool {
        guard settings.autoLowPowerOnBattery else {
            return false
        }

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return true
        }

        return IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() == nil
    }

    private func screensDidChange() {
        let screens = NSScreen.screens
        let settings = store?.state.settings ?? .default
        let targetScreens = targetScreens(from: screens, settings: settings)
        store?.handleScreenConfigurationChange(screenCount: targetScreens.count)
        wallpaperManager?.applyLivingSceneWallpaper(to: targetScreens)
        overlayController?.rebuildWindows()
        rainbowMoment?.rebuildWindows()
        gnomeTribes?.rebuildWindows()
        birdFlocks?.rebuildWindows()
        catCompanion?.rebuildWindows()
        scheduleScreenSaverSnapshotPublish(delay: 0.4)
        updateDisplayCadence()
    }

    private func simulationTimerFired() {
        let now = Date()
        store?.advance(to: now)
        if let store {
            if !isSmartLockWallpaperActive {
                wallpaperManager?.refreshLivingSceneWallpaperIfStale(
                    to: targetScreens(from: NSScreen.screens, settings: store.state.settings),
                    at: now
                )
            }
        }
        updateDisplayCadence(at: now)
        captureDailyTimeLapseFrameIfNeeded(at: now)
        if let store {
            ambienceEngine.setMix(GardenAmbienceEngine.mix(
                for: store.state,
                sceneKey: store.activeSceneKey,
                at: now
            ))
        }
        momentNotifier?.tick()
        rainbowMoment?.refresh()
    }

    private func targetScreens(from screens: [NSScreen], settings: GardenSettings) -> [NSScreen] {
        let allScreens = screens.isEmpty ? NSScreen.screens : screens
        switch settings.displayBehavior {
        case .mirrorAllDisplays:
            return allScreens
        case .mainDisplayOnly:
            return [NSScreen.main ?? allScreens.first].compactMap { $0 }
        }
    }

    private func captureDailyTimeLapseFrameIfNeeded(at date: Date) {
        guard let store else {
            return
        }
        guard store.state.settings.timeLapseCadence != .off else {
            lastTimeLapseCheckDay = nil
            return
        }

        let dayStamp = GardenTimeLapseRecorder.dayStamp(for: date)
        guard dayStamp != lastTimeLapseCheckDay else {
            return
        }

        lastTimeLapseCheckDay = dayStamp
        timeLapseRecorder?.captureFrameIfNeeded(store: store, at: date)
    }

    private func displayTimerFired() {
        overlayController?.repaint()
        updateDisplayCadence()
    }

    private func gardenStoreDidChangeForDisplay() {
        if let store {
            GardenRadioPlayer.shared.setVolume(store.state.settings.musicVolume)
            ambienceEngine.setMix(GardenAmbienceEngine.mix(
                for: store.state,
                sceneKey: store.activeSceneKey
            ))
        }
        updateDisplayCadence()
        handleSmartLockTransitionIfNeeded()
        handleSmartLockSettingWhileLocked()
        scheduleScreenSaverSnapshotPublish()
    }

    private func handleSmartLockTransitionIfNeeded() {
        guard let store else {
            return
        }

        let isLocked = store.state.settings.isGardenInteractionLocked
        guard isLocked != lastGardenInteractionLocked else {
            return
        }

        lastGardenInteractionLocked = isLocked
        if isLocked {
            startSmartLockWallpaperGenerationIfNeeded()
            return
        }

        smartLockWallpaperTask?.cancel()
        smartLockWallpaperTask = nil
        if isSmartLockWallpaperActive {
            isSmartLockWallpaperActive = false
            overlayController?.arePlantsHiddenForAILockView = false
            wallpaperManager?.restoreSelectedWallpaperAfterSmartLock(
                to: targetScreens(from: NSScreen.screens, settings: store.state.settings)
            )
        }
    }

    private func handleSmartLockSettingWhileLocked() {
        guard let store else {
            return
        }

        let settings = store.state.settings
        let didToggleAILockView = settings.useAIGeneratedLockSnapshot != lastUseAIGeneratedLockSnapshot
        lastUseAIGeneratedLockSnapshot = settings.useAIGeneratedLockSnapshot

        guard settings.isGardenInteractionLocked else {
            return
        }

        if settings.useAIGeneratedLockSnapshot {
            if didToggleAILockView, !isSmartLockWallpaperActive, smartLockWallpaperTask == nil {
                startSmartLockWallpaperGenerationIfNeeded()
            }
            return
        }

        smartLockWallpaperTask?.cancel()
        smartLockWallpaperTask = nil
        if isSmartLockWallpaperActive {
            isSmartLockWallpaperActive = false
            overlayController?.arePlantsHiddenForAILockView = false
            wallpaperManager?.restoreSelectedWallpaperAfterSmartLock(
                to: targetScreens(from: NSScreen.screens, settings: store.state.settings)
            )
        }
    }

    private func regenerateSmartLockWallpaper() {
        guard store?.state.settings.isGardenInteractionLocked == true else {
            return
        }
        startSmartLockWallpaperGenerationIfNeeded(reuseCachedWallpaper: false)
    }

    private func startSmartLockWallpaperGenerationIfNeeded(reuseCachedWallpaper: Bool = true) {
        guard let store,
              let wallpaperManager,
              store.state.settings.useAIGeneratedLockSnapshot,
              GardenEntitlements.shared.isUnlocked(.aiLockView) else {
            return
        }

        smartLockWallpaperTask?.cancel()
        smartLockWallpaperTask = nil
        let targetScreens = targetScreens(from: NSScreen.screens, settings: store.state.settings)
        let smartLockSceneKey = wallpaperManager.selectedWallpaperSceneKey
        if reuseCachedWallpaper {
            do {
                if try wallpaperManager.applyLatestSmartLockWallpaper(to: targetScreens, sceneKey: smartLockSceneKey) != nil {
                    isSmartLockWallpaperActive = true
                    overlayController?.arePlantsHiddenForAILockView = true
                    scheduleScreenSaverSnapshotPublish(delay: 0.2)
                    return
                }
            } catch {
                NSLog("Plant Wallpaper could not reuse cached AI lock view: \(error.localizedDescription)")
            }
        } else if isSmartLockWallpaperActive {
            isSmartLockWallpaperActive = false
            overlayController?.arePlantsHiddenForAILockView = false
            wallpaperManager.restoreSelectedWallpaperAfterSmartLock(to: targetScreens)
        }

        guard let apiKey = OpenAIAPIKeyStore.load() else {
            NSLog("Plant Wallpaper AI lock view skipped: OpenAI API key is not configured.")
            return
        }

        let sourceImageData: Data
        do {
            sourceImageData = try GardenSmartLockSnapshotRenderer.sourceImageData(
                store: store,
                screen: targetScreens.first,
                wallpaperImageURL: wallpaperManager.currentWallpaperImageURL
            )
        } catch {
            NSLog("Plant Wallpaper could not capture AI lock source image: \(error.localizedDescription)")
            return
        }

        let date = Date()
        smartLockWallpaperTask = Task { [weak self, weak store, weak wallpaperManager] in
            do {
                guard let wallpaperManager else {
                    return
                }
                _ = try await wallpaperManager.createAndApplySmartLockWallpaper(
                    sourceImageData: sourceImageData,
                    apiKey: apiKey,
                    to: targetScreens,
                    at: date,
                    quality: store?.state.settings.wallpaperGenerationQuality ?? .twoK,
                    sceneKey: smartLockSceneKey
                )
                let wasCancelled = Task.isCancelled
                await MainActor.run {
                    guard let self, let store else {
                        return
                    }
                    self.isSmartLockWallpaperActive = true
                    self.smartLockWallpaperTask = nil
                    guard !wasCancelled,
                          store.state.settings.isGardenInteractionLocked,
                          store.state.settings.useAIGeneratedLockSnapshot else {
                        self.isSmartLockWallpaperActive = false
                        self.overlayController?.arePlantsHiddenForAILockView = false
                        wallpaperManager.restoreSelectedWallpaperAfterSmartLock(
                            to: self.targetScreens(from: NSScreen.screens, settings: store.state.settings)
                        )
                        return
                    }
                    // The generated wallpaper now has the garden baked in, so hide
                    // the live placed plants/trees until AI Lock View is turned off.
                    self.overlayController?.arePlantsHiddenForAILockView = true
                    self.scheduleScreenSaverSnapshotPublish(delay: 0.2)
                }
            } catch {
                await MainActor.run {
                    self?.smartLockWallpaperTask = nil
                    self?.overlayController?.arePlantsHiddenForAILockView = false
                }
                guard !Task.isCancelled else {
                    return
                }
                NSLog("Plant Wallpaper AI lock view failed: \(error.localizedDescription)")
            }
        }
    }

    private func autosaveTimerFired() {
        store?.save()
        scheduleScreenSaverSnapshotPublish(delay: 0.2)
        statusMenu?.checkProgressionAutoAdvanceIfDue()
    }

    private func scheduleScreenSaverSnapshotPublish(delay: TimeInterval = 0.8) {
        screenSaverSnapshotTimer?.invalidate()
        screenSaverSnapshotTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.publishScreenSaverSnapshot()
            }
        }
        screenSaverSnapshotTimer?.tolerance = min(0.35, delay * 0.5)
    }

    private func publishScreenSaverSnapshot() {
        guard let store else {
            return
        }

        let directoryURL = store.persistence.directoryURL
        let imageURL = GardenScreenSaverSnapshot.primaryImageURL(directoryURL: directoryURL)
        do {
            try GardenDesktopSnapshotRenderer.writeSnapshotPNG(
                store: store,
                to: imageURL,
                wallpaperImageURL: wallpaperManager?.currentWallpaperImageURL
            )
        } catch {
            NSLog("Plant Wallpaper could not render screen saver garden snapshot: \(error.localizedDescription)")
        }

        let snapshot = GardenScreenSaverSnapshot(
            sceneKey: store.activeSceneKey,
            state: store.state,
            wallpaperImagePath: wallpaperManager?.currentWallpaperImageURL?.path,
            compositedImagePath: FileManager.default.fileExists(atPath: imageURL.path) ? imageURL.path : nil,
            isCatCompanionEnabled: catCompanion?.isEnabled
                ?? (UserDefaults.standard.object(forKey: CatCompanionController.enabledDefaultsKey) as? Bool ?? true)
        )
        let snapshotURL = GardenScreenSaverSnapshot.fileURL(directoryURL: directoryURL)

        do {
            try snapshot.save(to: directoryURL)
            UserDefaults.standard.set(snapshotURL.path, forKey: "PlantWallpaper.screenSaverSnapshotURL")
            let sharedDefaults = UserDefaults(suiteName: "com.chrisdimarco.wallpapergarden")
            sharedDefaults?.set(snapshotURL.path, forKey: "PlantWallpaper.screenSaverSnapshotURL")
            sharedDefaults?.synchronize()
        } catch {
            NSLog("Plant Wallpaper could not save screen saver garden snapshot: \(error.localizedDescription)")
        }
    }
}
