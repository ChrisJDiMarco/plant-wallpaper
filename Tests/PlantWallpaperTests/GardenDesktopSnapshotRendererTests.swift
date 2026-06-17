import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden desktop snapshot renderer")
struct GardenDesktopSnapshotRendererTests {
    @Test("AI lock view uses the same PNG renderer as Save Garden Snapshot")
    func aiLockViewUsesSamePNGRendererAsSaveGardenSnapshot() throws {
        let testURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("Sources/PlantWallpaper/GardenSmartLockSnapshotRenderer.swift")
        let source = try String(contentsOf: sourceURL)

        #expect(source.contains("GardenDesktopSnapshotRenderer.snapshotPNGData"))
        #expect(!source.contains("CGWindowListCreateImage"))
        #expect(!source.contains("screenCapturePNGData"))
    }

    @Test("screen saver snapshot renderer keeps placed radio companions")
    func screenSaverSnapshotRendererKeepsPlacedRadioCompanions() throws {
        let testURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let rendererSource = try String(contentsOf: projectRoot
            .appendingPathComponent("Sources/PlantWallpaper/GardenDesktopSnapshotRenderer.swift"))
        let canvasSource = try String(contentsOf: projectRoot
            .appendingPathComponent("Sources/PlantWallpaper/GardenCanvasView.swift"))

        #expect(rendererSource.contains("drawsInteractiveChrome = false"))
        #expect(rendererSource.contains("drawsSceneObjectsWhenChromeHidden = true"))
        #expect(canvasSource.contains("drawMusicButtonIfNeeded()"))
        #expect(canvasSource.contains("drawsInteractiveChrome || drawsSceneObjectsWhenChromeHidden"))
    }

    @Test("desktop snapshot composites wallpaper and plants and exports PNG data")
    func desktopSnapshotCompositesAndExports() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first,
              NSWorkspace.shared.desktopImageURL(for: screen) != nil else {
            // Headless runners have no screen or wallpaper to snapshot.
            return
        }

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("garden-desktop-snapshot-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let store = GardenStore(
            state: GardenState.defaultGarden(screenCount: 1),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let outputURL = directoryURL.appendingPathComponent("snapshot.png")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        try GardenDesktopSnapshotRenderer.writeSnapshotPNG(store: store, to: outputURL)

        let data = try Data(contentsOf: outputURL)
        #expect(data.count > 10_000, "PNG export should contain real image data")

        let image = try #require(NSImage(data: data))
        let scale = max(1, screen.backingScaleFactor)
        #expect(Int(image.size.width.rounded()) == Int((screen.frame.width * scale).rounded()))
        #expect(Int(image.size.height.rounded()) == Int((screen.frame.height * scale).rounded()))
    }
}
