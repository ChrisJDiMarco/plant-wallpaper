import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Bird flock integration")
struct BirdFlockIntegrationTests {
    @Test("store adds hides and clears scene bird sky zones")
    func storeAddsHidesAndClearsSceneBirdSkyZones() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bird-zone-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = GardenStore(
            state: GardenState(),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )

        store.addBirdSkyZone(screenIndex: 1, points: [
            GardenPoint(x: 0.1, y: 0.08),
            GardenPoint(x: 0.82, y: 0.10),
            GardenPoint(x: 0.70, y: 0.36)
        ])

        #expect(store.state.birdSkyZones.count == 1)
        #expect(store.state.birdSkyZones[0].screenIndex == 1)
        #expect(!store.state.areBirdFlocksHidden)

        store.setBirdFlocksHidden(true)

        #expect(store.state.areBirdFlocksHidden)
        #expect(store.state.birdSkyZones.count == 1)

        store.setBirdFlocksHidden(false)

        #expect(!store.state.areBirdFlocksHidden)

        store.clearBirdSkyZones()

        #expect(store.state.birdSkyZones.isEmpty)
        #expect(!store.state.areBirdFlocksHidden)
    }

    @Test("bird sky drawing mode lets the canvas receive desktop drags anywhere")
    func birdSkyDrawingModeReceivesDesktopDragsAnywhere() {
        let store = GardenStore(
            state: GardenState(),
            persistence: GardenPersistence(
                directoryURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("bird-zone-canvas-\(UUID().uuidString)", isDirectory: true)
            )
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 800, height: 500),
            screenIndex: 0,
            store: store
        )

        #expect(canvasView.shouldReceiveMouseEvents(at: NSPoint(x: 16, y: 16)) == false)

        canvasView.isBirdSkyZoneDrawingMode = true

        #expect(canvasView.shouldReceiveMouseEvents(at: NSPoint(x: 16, y: 16)))
        #expect(canvasView.interactionRegionRects() == [canvasView.bounds])
    }

    @Test("bird sky marker drag saves a normalized zone")
    func birdSkyMarkerDragSavesNormalizedZone() {
        let store = GardenStore(
            state: GardenState(),
            persistence: GardenPersistence(
                directoryURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("bird-zone-drag-\(UUID().uuidString)", isDirectory: true)
            )
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 1000, height: 500),
            screenIndex: 0,
            store: store
        )

        #expect(canvasView.beginBirdSkyZoneDraft(at: NSPoint(x: 100, y: 50)))
        #expect(canvasView.continueBirdSkyZoneDraft(at: NSPoint(x: 820, y: 54)))
        #expect(canvasView.continueBirdSkyZoneDraft(at: NSPoint(x: 700, y: 180)))
        #expect(canvasView.endBirdSkyZoneDraft())

        #expect(store.state.birdSkyZones.count == 1)
        #expect(store.state.birdSkyZones[0].points.first == GardenPoint(x: 0.1, y: 0.1))
        #expect(!canvasView.birdSkyZoneGuideVisibleForSelfTest())
    }

    @Test("bird flock controller only shows for visible garden sky zones")
    func birdFlockControllerOnlyShowsForVisibleGardenSkyZones() {
        var state = GardenState()

        #expect(!BirdFlockController.shouldShow(for: state))

        state.birdSkyZones = [
            BirdSkyZone(screenIndex: 0, points: [
                GardenPoint(x: 0.1, y: 0.1),
                GardenPoint(x: 0.8, y: 0.1),
                GardenPoint(x: 0.7, y: 0.32)
            ])
        ]

        #expect(BirdFlockController.shouldShow(for: state))

        state.areBirdFlocksHidden = true

        #expect(!BirdFlockController.shouldShow(for: state))

        state.areBirdFlocksHidden = false
        state.settings = state.settings.updating(experienceMode: .roomStudio)

        #expect(!BirdFlockController.shouldShow(for: state))
    }

    @Test("bird web assets are bundled and expose ten flock species")
    func birdWebAssetsAreBundledAndExposeTenFlockSpecies() throws {
        let indexURL = try #require(
            BirdFlockController.webAssetsIndexURL(),
            "WebAssets/birds/index.html missing from bundle"
        )
        let directoryURL = indexURL.deletingLastPathComponent()
        let html = try String(contentsOf: indexURL, encoding: .utf8)
        let main = try String(contentsOf: directoryURL.appendingPathComponent("main.js"), encoding: .utf8)
        let flock = try String(contentsOf: directoryURL.appendingPathComponent("flock.js"), encoding: .utf8)

        for fileName in [
            "../cat/three.min.js",
            "flock.js",
            "main.js"
        ] {
            #expect(html.contains(fileName))
        }
        for species in [
            "American Robin",
            "Northern Cardinal",
            "Blue Jay",
            "American Goldfinch",
            "Barn Swallow",
            "Mourning Dove",
            "Ruby-throated Hummingbird",
            "Red-tailed Hawk",
            "American Crow",
            "House Sparrow"
        ] {
            #expect(flock.contains(species))
        }
        #expect(main.contains("new THREE.WebGLRenderer"))
        #expect(main.contains("window.birdBridge"))
        #expect(main.contains("three-js-volumetric-intelligent-bird-flock"))
        #expect(main.contains("makeFeatherGeometry"))
        #expect(main.contains("makeWingSurfaceGeometry"))
        #expect(main.contains("volumetricBackHighlight"))
        #expect(main.contains("dorsalWingSheen"))
        #expect(main.contains("primaryFeatherShaft"))
        #expect(main.contains("cameraFillLight"))
        #expect(main.contains("rimLight"))
        #expect(main.contains("minimumLift"))
        #expect(main.contains("wingBlur"))
        #expect(main.contains("primaryFeather"))
        #expect(main.contains("catchlight"))
        #expect(main.contains("function applyLightingToFlock"))
        #expect(main.contains("lightingSignature"))
        #expect(main.contains("birdCountMultiplier"))
        #expect(main.contains("requestPixelStats"))
        #expect(main.contains("captureCanvasPixelStats"))
        #expect(!main.contains("applyLighting(group, species);"))
        #expect(flock.contains("stepFlock"))
        #expect(flock.contains("pointInPolygon"))
        #expect(flock.contains("rebuildBirdsForZones"))
        #expect(flock.contains("turnRate"))
        #expect(flock.contains("wingSpan"))
        #expect(flock.contains("flapHz"))
        #expect(flock.contains("wingAspect"))
        #expect(flock.contains("gravity"))
        #expect(flock.contains("liftForce"))
        #expect(flock.contains("targetHeading"))
        #expect(flock.contains("planNextWaypoint"))
        #expect(flock.contains("decisionCooldown"))
        #expect(flock.contains("personalSpace"))
        #expect(flock.contains("planHorizon"))
        #expect(flock.contains("pathCurvature"))
    }
}
