import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden scene detail editor")
struct GardenSceneDetailWindowControllerTests {
    private func makeController() throws -> (GardenSceneDetailWindowController, URL) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenSceneDetailTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let wallpaperManager = WallpaperManager(baseDirectoryURL: directoryURL)

        let rootKey = GardenWallpaperScene.brazilianRooftopGarden.rawValue
        _ = try wallpaperManager.storeEditedWallpaperForSelfTest(
            updatePrompt: "warmer light",
            parentSceneKey: rootKey,
            editedFromKey: rootKey,
            imageData: pngData(),
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let second = try wallpaperManager.storeEditedWallpaperForSelfTest(
            updatePrompt: "add a fountain",
            parentSceneKey: rootKey,
            editedFromKey: rootKey,
            imageData: pngData(),
            createdAt: Date(timeIntervalSince1970: 20)
        )
        _ = wallpaperManager.applyWallpaperSceneKey(second.key, to: [])

        let controller = GardenSceneDetailWindowController(
            wallpaperManager: wallpaperManager,
            sceneRootKey: rootKey,
            sceneName: "Brazilian Rooftop Garden",
            callbacks: GardenSceneDetailWindowController.Callbacks(
                applyVersion: { _ in },
                generateEdit: { _, completion in completion(.success(())) },
                onClose: {}
            )
        )
        return (controller, directoryURL)
    }

    @Test("editor loads every version of the scene, newest first")
    func loadsAllVersions() throws {
        let (controller, directoryURL) = try makeController()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        // Two edits plus the original entry.
        #expect(controller.versionCountForSelfTest() == 3)
    }

    @Test("version navigation walks the list and clamps at both ends")
    func navigationClamps() throws {
        let (controller, directoryURL) = try makeController()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let newest = controller.viewedVersionKeyForSelfTest()

        // Already at the newest applied version — next is a no-op.
        controller.showNextVersionForSelfTest()
        #expect(controller.viewedVersionKeyForSelfTest() == newest)

        // Walk back to the oldest, then clamp.
        controller.showPreviousVersionForSelfTest()
        controller.showPreviousVersionForSelfTest()
        let oldest = controller.viewedVersionKeyForSelfTest()
        controller.showPreviousVersionForSelfTest()
        #expect(controller.viewedVersionKeyForSelfTest() == oldest)

        // And forward again returns to the newest.
        controller.showNextVersionForSelfTest()
        controller.showNextVersionForSelfTest()
        #expect(controller.viewedVersionKeyForSelfTest() == newest)
    }

    private func pngData() throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 32,
            pixelsHigh: 20,
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
        NSColor.systemTeal.setFill()
        NSRect(x: 0, y: 0, width: 32, height: 20).fill()
        NSGraphicsContext.restoreGraphicsState()
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }
}
