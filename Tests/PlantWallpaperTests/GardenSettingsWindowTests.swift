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
            "Flythrough Videos",
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
        #expect(controller.wildlifeControlTitlesForSelfTest().contains("Bird count"))
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

    @Test("settings custom scenes hide edited and progression versions")
    func settingsCustomScenesHideEditedAndProgressionVersions() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenSettingsCustomScenesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
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
        let sourceURL = try writeSettingsTestPNG(in: directoryURL, named: "root")
        let rootRecord = try wallpaperManager.createChosenWallpaperScene(from: sourceURL, to: [])
        let normalRecord = try wallpaperManager.storeEditedWallpaperForSelfTest(
            updatePrompt: "add warmer evening light",
            parentSceneKey: rootRecord.key,
            editedFromKey: rootRecord.key,
            imageData: try Data(contentsOf: sourceURL),
            createdAt: Date(timeIntervalSince1970: 10)
        )
        _ = try wallpaperManager.storeEditedWallpaperForSelfTest(
            updatePrompt: "Progression Level 1: Bare First Garden",
            parentSceneKey: rootRecord.key,
            editedFromKey: normalRecord.key,
            imageData: try Data(contentsOf: sourceURL),
            createdAt: Date(timeIntervalSince1970: 20)
        )

        let titles = controller.customSceneTitlesForSelfTest()

        #expect(titles == [rootRecord.displayName])
    }

    private func writeSettingsTestPNG(in directoryURL: URL, named name: String) throws -> URL {
        let url = directoryURL.appendingPathComponent("\(name).png")
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 16,
            pixelsHigh: 16,
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
        NSColor.systemGreen.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 16, height: 16)).fill()
        NSGraphicsContext.restoreGraphicsState()

        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: url, options: [.atomic])
        return url
    }
}
