import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden status menu mode switching")
struct GardenStatusMenuModeSwitchTests {
    @Test("switching to Room Studio rebuilds menu around indoor plants and room tools")
    func switchingToRoomStudioRebuildsMenuAroundIndoorPlantsAndRoomTools() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        fixture.menu.selectExperienceModeForSelfTest(.roomStudio)

        let titles = fixture.menu.visibleMenuTitlesForSelfTest()
        #expect(fixture.store.state.settings.experienceMode == .roomStudio)
        #expect(fixture.store.activeSceneKey == GardenWallpaperScene.roomModernBedroomCanvas.rawValue)
        #expect(titles.contains("Mode: Room Studio"))
        #expect(titles.contains("Lock Room Studio Interactions"))
        // Placement categories are consolidated under one "Place Items Here" row.
        #expect(titles.contains("Place Items Here"))
        let placeItems = fixture.menu.submenuTitlesForSelfTest(named: "Place Items Here")
        #expect(placeItems.contains("Add Indoor Plant Here"))
        #expect(placeItems.contains("Add Wall Decor Here"))
        #expect(placeItems.contains("Add Clothes & Soft Stuff Here"))
        #expect(placeItems.contains("Add Wardrobe Here"))
        #expect(placeItems.contains("Add Games & Tech Here"))
        #expect(placeItems.contains("Add Collectibles & Toys Here"))
        #expect(placeItems.contains("Add Lounge Gear Here"))
        #expect(titles.contains("Room Studio Tools"))
        #expect(!titles.contains("Plant Flower Here"))
        #expect(!titles.contains("Plant Tree Here"))
        #expect(!titles.contains("Plant Foliage Here"))
        #expect(!titles.contains("Water All"))
        #expect(!titles.contains("Garden steady"))
        #expect(!titles.contains("Garden Tools"))
        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Add Indoor Plant Here").contains("Add New Indoor Plant..."))
        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Add Indoor Plant Here").contains("Random Indoor Plant Here"))
        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Add Indoor Plant Here").contains("Monstera"))
        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Add Indoor Plant Here").contains("Bonsai"))
        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Add Wall Decor Here").contains("Add New Wall Decor..."))
        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Add Wall Decor Here").contains("Gig Poster Wall Frame"))
        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Add Games & Tech Here").contains("Add New Games & Tech..."))
        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Add Games & Tech Here").contains("Retro Console Stack"))
        #expect(!fixture.menu.submenuTitlesForSelfTest(named: "Room Studio Tools").contains("Add Wall Decor Here"))
        #expect(!fixture.menu.submenuTitlesForSelfTest(named: "Room Studio Tools").contains("Smart Arrange Room"))
        #expect(fixture.menu.primaryWallpaperSceneTitlesForSelfTest().contains("Modern Bedroom Canvas"))
        #expect(!fixture.menu.primaryWallpaperSceneTitlesForSelfTest().contains("Empty Conservatory Hall"))
    }

    @Test("switching to Room Studio while the dropdown is open rebuilds after the close callback")
    func switchingToRoomStudioWhileDropdownIsOpenRebuildsAfterCloseCallback() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }
        let initialMenu = try #require(fixture.menu.menuObjectIdentifierForSelfTest())

        fixture.menu.markMenuOpenForSelfTest()
        fixture.menu.selectExperienceModeForSelfTest(.roomStudio)

        #expect(fixture.store.state.settings.experienceMode == .roomStudio)
        #expect(fixture.menu.menuObjectIdentifierForSelfTest() == initialMenu)

        fixture.menu.markMenuClosedForSelfTest()

        #expect(fixture.menu.menuObjectIdentifierForSelfTest() == initialMenu)

        fixture.menu.flushDeferredMenuRebuildForSelfTest()

        #expect(fixture.menu.menuObjectIdentifierForSelfTest() != initialMenu)
        #expect(fixture.menu.visibleMenuTitlesForSelfTest().contains("Mode: Room Studio"))
    }

    @Test("scene switches run through the visual transition handler")
    func sceneSwitchesRunThroughTheVisualTransitionHandler() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }
        var didTransition = false
        var modeBeforeTransition: GardenExperienceMode?
        var modeAfterTransition: GardenExperienceMode?
        fixture.menu.sceneTransitionHandler = { updateScene in
            didTransition = true
            modeBeforeTransition = fixture.store.state.settings.experienceMode
            updateScene()
            modeAfterTransition = fixture.store.state.settings.experienceMode
        }

        fixture.menu.selectExperienceModeForSelfTest(.roomStudio)

        #expect(didTransition)
        #expect(modeBeforeTransition == .garden)
        #expect(modeAfterTransition == .roomStudio)
        #expect(fixture.store.activeSceneKey == GardenWallpaperScene.roomModernBedroomCanvas.rawValue)
    }

    @Test("switching to Alien UFO rebuilds menu around alien planting actions")
    func switchingToAlienUFORebuildsMenuAroundAlienPlantingActions() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        fixture.menu.selectExperienceModeForSelfTest(.alienUFO)

        let titles = fixture.menu.visibleMenuTitlesForSelfTest()
        #expect(fixture.store.state.settings.experienceMode == .alienUFO)
        #expect(fixture.store.activeSceneKey == GardenWallpaperScene.alienCraterDome.rawValue)
        #expect(titles.contains("Mode: Alien/UFO Garden"))
        #expect(titles.contains("Lock Alien Garden Interactions"))
        // Alien planting categories are consolidated under one "Plant Here" row.
        #expect(titles.contains("Plant Here"))
        let alienPlants = fixture.menu.submenuTitlesForSelfTest(named: "Plant Here")
        #expect(alienPlants.contains("Plant Alien Flower Here"))
        #expect(alienPlants.contains("Plant Alien Tree Here"))
        #expect(titles.contains("Alien Garden Tools"))
        #expect(!titles.contains("Plant Flower Here"))
        #expect(!titles.contains("Water All"))
        #expect(!titles.contains("Garden steady"))
        #expect(!titles.contains("Garden Tools"))
        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Plant Alien Flower Here").contains("Nebula Orchid"))
        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Plant Alien Flower Here").contains("Random Alien Flower Here"))
        #expect(fixture.menu.submenuAvailabilityForSelfTest(named: "Plant Alien Flower Here")["Nebula Orchid"] == true)
        #expect(fixture.menu.submenuAvailabilityForSelfTest(named: "Plant Alien Edible Here")["Glowberry Cane"] == true)
        #expect(!fixture.menu.submenuTitlesForSelfTest(named: "Plant Alien Flower Here").contains("Alien Specimen Pack - needs PNG assets"))
        #expect(fixture.menu.primaryWallpaperSceneTitlesForSelfTest().contains("Alien Crater Greenhouse"))
        #expect(fixture.menu.primaryWallpaperSceneAvailabilityForSelfTest()["Alien Crater Greenhouse"] == false)
        #expect(fixture.menu.primaryWallpaperSceneAvailabilityForSelfTest()["Alien Crater Dome"] == true)
        #expect(!fixture.menu.primaryWallpaperSceneTitlesForSelfTest().contains("Empty Conservatory Hall"))
    }

    @Test("wallpaper scene dropdown shows only scenes for the active mode")
    func wallpaperSceneDropdownShowsOnlyScenesForTheActiveMode() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        let gardenRecord = try fixture.createChosenWallpaper(named: "garden stone nook", mode: .garden)
        let roomRecord = try fixture.createChosenWallpaper(named: "room neon corner", mode: .roomStudio)
        let alienRecord = try fixture.createChosenWallpaper(named: "alien glass crater", mode: .alienUFO)

        fixture.menu.refreshWallpaperScenesMenuForSelfTest()
        var titles = fixture.menu.primaryWallpaperSceneTitlesForSelfTest()
        #expect(titles.contains(gardenRecord.displayName))
        #expect(!titles.contains(roomRecord.displayName))
        #expect(!titles.contains(alienRecord.displayName))
        #expect(titles.contains("Empty Conservatory Hall"))
        #expect(!titles.contains("Modern Bedroom Canvas"))
        #expect(!titles.contains("Alien Crater Greenhouse"))

        fixture.menu.selectExperienceModeForSelfTest(.roomStudio)
        titles = fixture.menu.primaryWallpaperSceneTitlesForSelfTest()
        #expect(titles.contains(roomRecord.displayName))
        #expect(!titles.contains(gardenRecord.displayName))
        #expect(!titles.contains(alienRecord.displayName))
        #expect(titles.contains("Modern Bedroom Canvas"))
        #expect(!titles.contains("Empty Conservatory Hall"))
        #expect(!titles.contains("Alien Crater Greenhouse"))

        fixture.menu.selectExperienceModeForSelfTest(.alienUFO)
        titles = fixture.menu.primaryWallpaperSceneTitlesForSelfTest()
        #expect(titles.contains(alienRecord.displayName))
        #expect(!titles.contains(gardenRecord.displayName))
        #expect(!titles.contains(roomRecord.displayName))
        #expect(titles.contains("Alien Crater Greenhouse"))
        #expect(!titles.contains("Empty Conservatory Hall"))
        #expect(!titles.contains("Modern Bedroom Canvas"))
    }

    @Test("Room Studio generated scene selection opens the latest version")
    func roomStudioGeneratedSceneSelectionOpensLatestVersion() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        fixture.menu.selectExperienceModeForSelfTest(.roomStudio)
        let rootRecord = try fixture.createChosenWallpaper(named: "room neon corner", mode: .roomStudio)
        let firstRecord = try fixture.createEditedWallpaper(
            updatePrompt: "add soft window light",
            parentSceneKey: rootRecord.key,
            editedFromKey: rootRecord.key,
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let secondRecord = try fixture.createEditedWallpaper(
            updatePrompt: "move the shelf plants higher",
            parentSceneKey: rootRecord.key,
            editedFromKey: firstRecord.key,
            createdAt: Date(timeIntervalSince1970: 20)
        )

        fixture.menu.refreshWallpaperScenesMenuForSelfTest()
        #expect(fixture.menu.primaryWallpaperSceneTitlesForSelfTest().contains(rootRecord.displayName))

        fixture.menu.applyWallpaperSceneRootForSelfTest(rootRecord.key)

        #expect(fixture.wallpaperManager.selectedWallpaperSceneKey == secondRecord.key)
        #expect(fixture.store.activeSceneKey == secondRecord.key)
        #expect(fixture.wallpaperManager.wallpaperSceneRootKey() == rootRecord.key)
        #expect(fixture.wallpaperManager.latestWallpaperKey(forSceneRootKey: rootRecord.key) == secondRecord.key)
    }

    @Test("progression menu lists generated progression scenes")
    func progressionMenuListsGeneratedProgressionScenes() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }
        fixture.menu.selectExperienceModeForSelfTest(.roomStudio)
        let rootKey = GardenWallpaperScene.roomModernBedroomCanvas.rawValue
        let progressionRecord = try fixture.createEditedWallpaper(
            updatePrompt: "Progression Level 1: Bare First Room",
            parentSceneKey: rootKey,
            editedFromKey: rootKey,
            createdAt: Date(timeIntervalSince1970: 10)
        )
        _ = try fixture.createEditedWallpaper(
            updatePrompt: "add a warmer lamp",
            parentSceneKey: rootKey,
            editedFromKey: rootKey,
            createdAt: Date(timeIntervalSince1970: 20)
        )

        fixture.menu.refreshWallpaperScenesMenuForSelfTest()
        let titles = fixture.menu.submenuTitlesForSelfTest(named: "Progression Scenes")

        #expect(titles.contains("Progression Level 1: Bare First Room"))
        #expect(!titles.contains("add a warmer lamp"))

        fixture.menu.applyWallpaperVersionForSelfTest(progressionRecord.key)

        #expect(fixture.store.activeSceneKey == progressionRecord.key)
    }

    @Test("garden wallpaper tools include plant growth shortcuts only in garden mode")
    func gardenWallpaperToolsIncludePlantGrowthShortcutsOnlyInGardenMode() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        let gardenTitles = fixture.menu.wallpaperToolsTitlesForSelfTest()
        #expect(gardenTitles.contains("Start Plants from Seedlings"))
        #expect(gardenTitles.contains("Bring All Plants to Full Maturation"))

        fixture.menu.selectExperienceModeForSelfTest(.roomStudio)

        let studioTitles = fixture.menu.wallpaperToolsTitlesForSelfTest()
        #expect(!studioTitles.contains("Start Plants from Seedlings"))
        #expect(!studioTitles.contains("Bring All Plants to Full Maturation"))
    }

    @Test("wallpaper tools toggle time of day plant darkening")
    func wallpaperToolsToggleTimeOfDayPlantDarkening() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        #expect(fixture.menu.wallpaperToolsTitlesForSelfTest().contains("Darken Plants by Time of Day"))
        #expect(fixture.menu.menuItemStateForSelfTest(named: "Darken Plants by Time of Day") == .on)

        fixture.menu.toggleTimeOfDayPlantDarkeningForSelfTest()

        #expect(!fixture.store.state.settings.isTimeOfDayPlantDarkeningEnabled)
        #expect(fixture.menu.menuItemStateForSelfTest(named: "Darken Plants by Time of Day") == .off)
    }

    @Test("garden tools expose hide and remove gnome actions")
    func gardenToolsExposeHideAndRemoveGnomeActions() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        fixture.store.addGnomeTribeZone(screenIndex: 0, points: [
            GardenPoint(x: 0.2, y: 0.4),
            GardenPoint(x: 0.6, y: 0.4),
            GardenPoint(x: 0.5, y: 0.8)
        ])

        var titles = fixture.menu.submenuTitlesForSelfTest(named: "Garden Tools")
        #expect(titles.contains("Hide Gnomes"))
        #expect(titles.contains("Remove All Gnomes from Scene"))
        #expect(titles.contains("Adjust Gnome Perspective (0deg, 24deg)"))
        #expect(!titles.contains("Clear Gnome Tribe Zones"))

        fixture.store.setGnomeTribePerspective(GnomeTribePerspective(yawDegrees: 16, elevationDegrees: 34))
        titles = fixture.menu.submenuTitlesForSelfTest(named: "Garden Tools")
        #expect(titles.contains("Adjust Gnome Perspective (16deg, 34deg)"))

        fixture.store.setGnomeTribesHidden(true)

        titles = fixture.menu.submenuTitlesForSelfTest(named: "Garden Tools")
        #expect(titles.contains("Show Gnomes"))
        #expect(titles.contains("Remove All Gnomes from Scene"))
    }

    @Test("garden tools expose bird sky area actions")
    func gardenToolsExposeBirdSkyAreaActions() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        fixture.store.addBirdSkyZone(screenIndex: 0, points: [
            GardenPoint(x: 0.08, y: 0.08),
            GardenPoint(x: 0.82, y: 0.10),
            GardenPoint(x: 0.66, y: 0.30)
        ])

        var titles = fixture.menu.submenuTitlesForSelfTest(named: "Garden Tools")
        #expect(titles.contains("Draw Bird Sky Areas"))
        #expect(titles.contains("Hide Birds"))
        #expect(titles.contains("Remove All Bird Sky Areas"))

        fixture.store.setBirdFlocksHidden(true)

        titles = fixture.menu.submenuTitlesForSelfTest(named: "Garden Tools")
        #expect(titles.contains("Show Birds"))
        #expect(titles.contains("Remove All Bird Sky Areas"))
    }

    @Test("status menu hover tooltips are off by default except the AI lock view explainer")
    func statusMenuHoverTooltipsAreOffByDefault() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        #expect(!GardenStatusMenu.statusMenuTooltipsEnabledByDefaultForSelfTest)
        // Every menu tooltip is suppressed except the AI Image Lock View
        // toggle, which keeps an explanation so people can learn what it does
        // on hover.
        let tooltips = fixture.menu.menuTooltipsForSelfTest()
        #expect(tooltips.count == 1)
        #expect(tooltips.allSatisfy { $0.contains("AI Image Lock View Toggle") })
    }

    @Test("keepsakes menu exposes looping flythrough generation")
    func keepsakesMenuExposesLoopingFlythroughGeneration() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        let keepsakes = fixture.menu.submenuTitlesForSelfTest(named: "Keepsakes & Exports")

        #expect(keepsakes.contains("Save Garden Snapshot..."))
        #expect(keepsakes.contains("Generate Flythrough Video..."))
        #expect(keepsakes.contains("Go Back to Scene"))
        #expect(keepsakes.contains("Loop Flythrough Video"))
        #expect(keepsakes.contains("Flythrough Video Settings..."))
        #expect(fixture.menu.menuItemStateForSelfTest(named: "Loop Flythrough Video") == .on)

        fixture.menu.isFlythroughVideoLoopingProvider = { false }

        #expect(fixture.menu.menuItemStateForSelfTest(named: "Loop Flythrough Video") == .off)
    }

    @Test("AI lock view is a separate visible lock mode switch")
    func aiLockViewIsASeparateVisibleLockModeSwitch() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        let visibleTitles = fixture.menu.visibleMenuTitlesForSelfTest()
        let lockIndex = try #require(visibleTitles.firstIndex(of: "Lock Garden Interactions"))
        let aiLockIndex = try #require(visibleTitles.firstIndex(of: "AI Image Lock View Toggle"))
        #expect(aiLockIndex == lockIndex + 1)
        #expect(fixture.menu.menuItemStateForSelfTest(named: "Lock Garden Interactions") == .off)
        #expect(fixture.menu.menuItemStateForSelfTest(named: "AI Image Lock View Toggle") == .off)

        fixture.store.updateSettings(
            fixture.store.state.settings.updating(useAIGeneratedLockSnapshot: true)
        )

        #expect(fixture.menu.menuItemStateForSelfTest(named: "Lock Garden Interactions") == .off)
        #expect(fixture.menu.menuItemStateForSelfTest(named: "AI Image Lock View Toggle") == .on)
    }

    @Test("AI lock view warns before replacing active video wallpaper")
    func aiLockViewWarnsBeforeReplacingActiveVideoWallpaper() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }
        let entitlementStore = GardenLocalEntitlementStore()
        let previousTier = entitlementStore.selectedTier
        GardenEntitlements.shared.setLocalTier(.pro)
        defer { GardenEntitlements.shared.setLocalTier(previousTier) }

        fixture.menu.isFlythroughVideoWallpaperActiveProvider = { true }
        var confirmationCount = 0
        fixture.menu.aiLockVideoReplacementConfirmationHandler = {
            confirmationCount += 1
            return false
        }

        fixture.menu.toggleAILockViewForSelfTest()

        #expect(confirmationCount == 1)
        #expect(!fixture.store.state.settings.useAIGeneratedLockSnapshot)

        fixture.menu.aiLockVideoReplacementConfirmationHandler = {
            confirmationCount += 1
            return true
        }

        fixture.menu.toggleAILockViewForSelfTest()

        #expect(confirmationCount == 2)
        #expect(fixture.store.state.settings.useAIGeneratedLockSnapshot)
    }

    @Test("Jarvis assistant menu item can be hidden by settings")
    func jarvisAssistantMenuItemCanBeHiddenBySettings() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        #expect(fixture.menu.visibleMenuTitlesForSelfTest().contains("Jarvis Assistant..."))

        fixture.store.updateSettings(
            fixture.store.state.settings.updating(isAssistantMenuItemEnabled: false)
        )

        #expect(!fixture.menu.visibleMenuTitlesForSelfTest().contains("Jarvis Assistant..."))
        #expect(fixture.menu.visibleMenuTitlesForSelfTest().contains("Settings & Dashboard..."))
    }

    @Test("saved generated assets reappear in the submenu that created them")
    func savedGeneratedAssetsReappearInTheSubmenuThatCreatedThem() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        let gardenTree = try fixture.createSavedCustomAsset(
            displayName: "Crystal Bonsai",
            userDescription: "a crystal-veined bonsai with mossy roots",
            kind: .tree,
            mode: .garden
        )
        fixture.menu.refreshPlantingMenusForSelfTest()

        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Plant Tree Here").contains(gardenTree.displayName))
        #expect(fixture.menu.submenuAvailabilityForSelfTest(named: "Plant Tree Here")[gardenTree.displayName] == true)

        fixture.menu.selectExperienceModeForSelfTest(.roomStudio)
        let indoorPlant = try fixture.createSavedCustomAsset(
            displayName: "Disco Palm",
            userDescription: "a small indoor palm in a mirrored chrome pot",
            kind: .foliage,
            mode: .roomStudio
        )
        let roomObject = try fixture.createSavedCustomAsset(
            displayName: "Laser CRT Stack",
            userDescription: "stacked CRT televisions with tiny neon laser glow",
            kind: .foliage,
            mode: .roomStudio,
            category: .mediaTech
        )
        fixture.menu.refreshPlantingMenusForSelfTest()

        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Add Indoor Plant Here").contains(indoorPlant.displayName))
        #expect(fixture.menu.submenuAvailabilityForSelfTest(named: "Add Indoor Plant Here")[indoorPlant.displayName] == true)
        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Add Games & Tech Here").contains(roomObject.displayName))
        #expect(fixture.menu.submenuAvailabilityForSelfTest(named: "Add Games & Tech Here")[roomObject.displayName] == true)

        fixture.menu.selectExperienceModeForSelfTest(.alienUFO)
        let alienFlower = try fixture.createSavedCustomAsset(
            displayName: "Meteor Lily",
            userDescription: "an alien lily with meteor-glass petals and blue pollen nodes",
            kind: .flower,
            mode: .alienUFO
        )
        fixture.menu.refreshPlantingMenusForSelfTest()

        #expect(fixture.menu.submenuTitlesForSelfTest(named: "Plant Alien Flower Here").contains(alienFlower.displayName))
        #expect(fixture.menu.submenuAvailabilityForSelfTest(named: "Plant Alien Flower Here")[alienFlower.displayName] == true)
    }

    @Test("wallpaper version menu applies the exact selected version instead of the latest root")
    func wallpaperVersionMenuAppliesExactSelectedVersionInsteadOfLatestRoot() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        let rootKey = GardenWallpaperScene.brazilianRooftopGarden.rawValue
        let firstRecord = try fixture.createEditedWallpaper(
            updatePrompt: "use a subtle edit style",
            parentSceneKey: rootKey,
            editedFromKey: rootKey,
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let secondRecord = try fixture.createEditedWallpaper(
            updatePrompt: "progression level one",
            parentSceneKey: rootKey,
            editedFromKey: firstRecord.key,
            createdAt: Date(timeIntervalSince1970: 20)
        )

        _ = fixture.wallpaperManager.applyWallpaperSceneKey(secondRecord.key, to: [])
        fixture.menu.refreshWallpaperScenesMenuForSelfTest()

        let versionActions = fixture.menu.wallpaperVersionActionsForSelfTest()
        #expect(versionActions["Original: Brazilian Rooftop Garden"] == "applyWallpaperVersion:")
        #expect(versionActions["Original: Brazilian Rooftop Garden"] != "applyWallpaperSceneRoot:")
        let deleteAvailability = fixture.menu.wallpaperVersionDeleteAvailabilityForSelfTest()
        #expect(deleteAvailability["Original: Brazilian Rooftop Garden"] == false)
        #expect(deleteAvailability.values.contains(true))

        fixture.menu.applyWallpaperVersionForSelfTest(rootKey)

        #expect(fixture.wallpaperManager.selectedWallpaperSceneKey == rootKey)
        #expect(fixture.store.activeSceneKey == rootKey)
        #expect(fixture.wallpaperManager.wallpaperSceneRootKey() == rootKey)
        #expect(fixture.wallpaperManager.latestWallpaperKey(forSceneRootKey: rootKey) == secondRecord.key)
    }

    @Test("favorite plants menu lists plants hearted from the inspector")
    func favoritePlantsMenuListsPlantsHeartedFromTheInspector() throws {
        let fixture = try StatusMenuModeFixture()
        defer { fixture.cleanup() }

        fixture.store.addPlant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.35, y: 0.62)
        )
        let favoriteID = try #require(fixture.store.selectedPlantID)
        fixture.store.toggleSelectedPlantFavorite()
        fixture.store.addPlant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.55, y: 0.62)
        )

        let titles = fixture.menu.submenuTitlesForSelfTest(named: "Favorite Plants")

        #expect(titles.contains("Rose"))
        #expect(!titles.contains("Fern"))

        fixture.store.selectPlant(id: favoriteID)
        #expect(fixture.menu.submenuAvailabilityForSelfTest(named: "Favorite Plants")["Rose"] == true)
    }
}

@MainActor
private struct StatusMenuModeFixture {
    let directoryURL: URL
    let store: GardenStore
    let wallpaperManager: WallpaperManager
    let menu: GardenStatusMenu

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenStatusMenuModeSwitchTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let persistence = GardenPersistence(directoryURL: directoryURL)
        store = GardenStore(
            state: GardenState(settings: .default),
            persistence: persistence,
            activeSceneKey: GardenWallpaperScene.emptyConservatoryHall.rawValue
        )
        wallpaperManager = WallpaperManager(baseDirectoryURL: directoryURL)
        menu = GardenStatusMenu(store: store, wallpaperManager: wallpaperManager)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    func createChosenWallpaper(named name: String, mode: GardenExperienceMode) throws -> CustomWallpaperRecord {
        let sourceURL = try writePNG(named: name)
        return try wallpaperManager.createChosenWallpaperScene(
            from: sourceURL,
            to: [],
            experienceMode: mode
        )
    }

    func createEditedWallpaper(
        updatePrompt: String,
        parentSceneKey: String,
        editedFromKey: String,
        createdAt: Date
    ) throws -> CustomWallpaperRecord {
        try wallpaperManager.storeEditedWallpaperForSelfTest(
            updatePrompt: updatePrompt,
            parentSceneKey: parentSceneKey,
            editedFromKey: editedFromKey,
            imageData: pngData(),
            createdAt: createdAt
        )
    }

    func createSavedCustomAsset(
        displayName: String,
        userDescription: String,
        kind: PlantKind,
        mode: GardenExperienceMode,
        category: RoomObjectCategory? = nil
    ) throws -> CustomPlantAssetRecord {
        try store.customPlantAssets.storeAssetForSelfTest(
            request: CustomPlantAssetRequest(
                kind: kind,
                displayName: displayName,
                userDescription: userDescription,
                roomObjectCategory: category,
                roomPerspectiveContext: category == nil ? nil : .inferred(from: GardenPoint(x: 0.45, y: 0.58)),
                experienceMode: mode
            ),
            imageData: pngData()
        )
    }

    private func writePNG(named name: String) throws -> URL {
        let url = directoryURL.appendingPathComponent("\(name).png")
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 8,
            pixelsHigh: 8,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            Issue.record("Could not create bitmap fixture")
            return url
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.systemGreen.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        NSGraphicsContext.restoreGraphicsState()
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func pngData() throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 40,
            pixelsHigh: 40,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw CocoaError(.fileWriteUnknown)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 40, height: 40)).fill()
        NSColor(calibratedRed: 0.25, green: 0.68, blue: 0.38, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 8, y: 6, width: 24, height: 28)).fill()
        NSGraphicsContext.restoreGraphicsState()

        return try #require(bitmap.representation(using: .png, properties: [:]))
    }
}
