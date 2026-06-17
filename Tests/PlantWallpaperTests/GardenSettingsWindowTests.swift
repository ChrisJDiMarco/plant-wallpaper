import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden settings window")
struct GardenSettingsWindowTests {
    @Test("settings window exposes the main configuration sections")
    func settingsWindowExposesMainConfigurationSections() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenSettingsWindowTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let persistence = GardenPersistence(directoryURL: directoryURL)
        let store = GardenStore(state: GardenState(), persistence: persistence, activeSceneKey: "empty-conservatory-hall")
        let wallpaperManager = WallpaperManager(baseDirectoryURL: directoryURL)
        let controller = GardenSettingsWindowController(
            store: store,
            wallpaperManager: wallpaperManager,
            actions: GardenSettingsWindowController.Actions(
                applyScene: { _ in },
                applySceneWithSettings: { _, _ in },
                chooseWallpaper: {},
                createAIWallpaper: {},
                generateSceneEdit: { _, completion in completion(.success(())) },
                openAPIKeySettings: {},
                reapplyScene: {},
                restorePreviousWallpaper: {},
                resetGarden: {},
                deleteAllPlantsInScene: {},
                arrangeGarden: {},
                showWelcomeTour: {},
                saveHealthCheck: {}
            )
        )

        #expect(controller.window?.title == "Plant Wallpaper Settings")
        #expect(controller.window?.styleMask.contains(.resizable) == true)
        #expect(controller.sectionTitlesForSelfTest() == [
            "My Garden",
            "General",
            "Scene",
            "Wildlife",
            "Gnomes",
            "Audio",
            "Privacy & Storage",
            "Assets",
            "Advanced",
            "About"
        ])

        let dynamicControlCounts = controller.renderAllSectionsForSelfTest()
        for title in controller.sectionTitlesForSelfTest() {
            #expect((dynamicControlCounts[title] ?? 0) > 0, "Section \(title) should render live-updating controls")
        }

        #expect(controller.wildlifeControlTitlesForSelfTest().contains("Bug count"))
        #expect(controller.wildlifeControlTitlesForSelfTest().contains("Bug size"))
        #expect(controller.wildlifeControlTitlesForSelfTest().contains("Open cat chat on click"))
        #expect(controller.gnomeControlTitlesForSelfTest() == [
            "Gnome societies",
            "Population",
            "Tribe size",
            "Life-like behavior",
            "Building speed",
            "Settlement timeframe",
            "Cooperation",
            "Plant curiosity",
            "Village detail",
            "Active zones"
        ])
        #expect(controller.generalControlTitlesForSelfTest().contains("Show Jarvis in main menu"))
        #expect(controller.privacyStorageControlTitlesForSelfTest().contains("Issues"))
        #expect(controller.privacyStorageControlTitlesForSelfTest().contains("Next action"))
        #expect(controller.privacyStorageControlTitlesForSelfTest().contains("Wallpaper generation quality"))
    }

    @Test("settings sidebar uses compact modern navigation metrics")
    func settingsSidebarUsesCompactModernNavigationMetrics() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenSettingsSidebarTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let persistence = GardenPersistence(directoryURL: directoryURL)
        let store = GardenStore(state: GardenState(), persistence: persistence, activeSceneKey: "empty-conservatory-hall")
        let wallpaperManager = WallpaperManager(baseDirectoryURL: directoryURL)
        let controller = GardenSettingsWindowController(
            store: store,
            wallpaperManager: wallpaperManager,
            actions: GardenSettingsWindowController.Actions(
                applyScene: { _ in },
                applySceneWithSettings: { _, _ in },
                chooseWallpaper: {},
                createAIWallpaper: {},
                generateSceneEdit: { _, completion in completion(.success(())) },
                openAPIKeySettings: {},
                reapplyScene: {},
                restorePreviousWallpaper: {},
                resetGarden: {},
                deleteAllPlantsInScene: {},
                arrangeGarden: {},
                showWelcomeTour: {},
                saveHealthCheck: {}
            )
        )

        let style = controller.sidebarStyleSnapshotForSelfTest()

        #expect(style.sidebarWidth >= 220)
        #expect(style.rowHeight <= 38)
        #expect(style.rowCornerRadius >= 8)
        #expect(style.iconWellSize <= 28)
        #expect(style.iconWellCornerRadius < style.iconWellSize / 2)
        #expect(style.selectedBackgroundAlpha < 0.20)
        #expect(style.selectedAccentWidth <= 4)
    }
}
