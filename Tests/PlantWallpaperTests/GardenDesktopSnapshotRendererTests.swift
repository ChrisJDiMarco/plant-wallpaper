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
        let appDelegateSource = try String(contentsOf: projectRoot
            .appendingPathComponent("Sources/PlantWallpaper/AppDelegate.swift"))

        #expect(source.contains("GardenDesktopSnapshotRenderer.snapshotPNGData"))
        #expect(!source.contains("CGWindowListCreateImage"))
        #expect(!source.contains("screenCapturePNGData"))
        #expect(appDelegateSource.contains("screen: targetScreens.first"))
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

    @Test("scene transitions freeze the current composited scene")
    func sceneTransitionsFreezeTheCurrentCompositedScene() throws {
        let testURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(contentsOf: projectRoot
            .appendingPathComponent("Sources/PlantWallpaper/GardenOverlayController.swift"))

        #expect(source.contains("GardenDesktopSnapshotRenderer.makeSnapshotBitmap"))
        #expect(!source.contains("NSGradient(colors: ["))
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

    @Test("desktop snapshot includes placed plants over the wallpaper")
    func desktopSnapshotIncludesPlacedPlantsOverWallpaper() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first,
              NSWorkspace.shared.desktopImageURL(for: screen) != nil else {
            return
        }

        let screenIndex = NSScreen.screens.firstIndex(of: screen) ?? 0
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("garden-desktop-snapshot-plants-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let plant = Plant(
            species: .japaneseMaple,
            screenIndex: screenIndex,
            position: GardenPoint(x: 0.50, y: 0.78),
            growth: 1,
            hydration: 0.9,
            health: 0.9,
            scale: 1.5
        )
        let persistence = GardenPersistence(directoryURL: directoryURL)
        let emptyStore = GardenStore(
            state: GardenState(isAmbientWildlifeEnabled: false),
            persistence: persistence,
            activeSceneKey: GardenWallpaperScene.emptyConservatoryHall.rawValue
        )
        let plantedStore = GardenStore(
            state: GardenState(plants: [plant], isAmbientWildlifeEnabled: false),
            persistence: persistence,
            activeSceneKey: GardenWallpaperScene.emptyConservatoryHall.rawValue
        )

        let emptyBitmap = try GardenDesktopSnapshotRenderer.makeSnapshotBitmap(
            store: emptyStore,
            screen: screen,
            screenIndex: screenIndex
        )
        let plantedBitmap = try GardenDesktopSnapshotRenderer.makeSnapshotBitmap(
            store: plantedStore,
            screen: screen,
            screenIndex: screenIndex
        )

        #expect(hasPixelDifferences(plantedBitmap, emptyBitmap, minimum: 500))
    }

    private func hasPixelDifferences(_ lhs: NSBitmapImageRep, _ rhs: NSBitmapImageRep, minimum: Int) -> Bool {
        let width = min(lhs.pixelsWide, rhs.pixelsWide)
        let height = min(lhs.pixelsHigh, rhs.pixelsHigh)
        var count = 0

        for y in 0..<height {
            for x in 0..<width {
                if lhs.colorAt(x: x, y: y) != rhs.colorAt(x: x, y: y) {
                    count += 1
                    if count > minimum {
                        return true
                    }
                }
            }
        }
        return false
    }
}
