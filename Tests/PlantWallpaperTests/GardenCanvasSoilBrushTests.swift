import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden canvas soil brush")
struct GardenCanvasSoilBrushTests {
    @Test("soil brush renders dimensional granular material")
    func soilBrushRendersDimensionalGranularMaterial() throws {
        let patch = SoilPatch(
            id: UUID(uuidString: "11111111-7777-4444-9999-111111111111")!,
            screenIndex: 0,
            points: [
                GardenPoint(x: 0.24, y: 0.68),
                GardenPoint(x: 0.36, y: 0.61),
                GardenPoint(x: 0.55, y: 0.64),
                GardenPoint(x: 0.70, y: 0.71),
                GardenPoint(x: 0.62, y: 0.81),
                GardenPoint(x: 0.40, y: 0.78)
            ],
            soilSeed: 24_681
        )
        let canvasView = canvas(soilPatches: [patch])

        let stats = try #require(canvasView.soilPatchMaterialStatsForSelfTest(patch, backingScale: 1))

        #expect(stats.alphaPixelCount > 8_000)
        #expect(stats.colorBucketCount > 24)
        #expect(stats.alphaBucketCount > 8)
        #expect(stats.alphaBounds.width > 180)
        #expect(stats.alphaBounds.height > 90)
    }

    @Test("plant sinking follows the sprayed soil footprint")
    func plantSinkingFollowsTheSprayedSoilFootprint() {
        let patch = SoilPatch(
            id: UUID(uuidString: "22222222-7777-4444-9999-222222222222")!,
            screenIndex: 0,
            points: [
                GardenPoint(x: 0.26, y: 0.72),
                GardenPoint(x: 0.42, y: 0.72),
                GardenPoint(x: 0.58, y: 0.72),
                GardenPoint(x: 0.74, y: 0.72)
            ],
            soilSeed: 13_579
        )
        let rootedPlant = Plant(
            id: UUID(uuidString: "33333333-7777-4444-9999-333333333333")!,
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.78),
            growth: 1,
            hydration: 0.82,
            health: 0.9,
            bloomProgress: 0,
            swaySeed: 7,
            scale: 1.0
        )
        let offPatchPlant = Plant(
            id: UUID(uuidString: "44444444-7777-4444-9999-444444444444")!,
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.46),
            growth: 1,
            hydration: 0.82,
            health: 0.9,
            bloomProgress: 0,
            swaySeed: 8,
            scale: 1.0
        )
        let canvasView = canvas(plants: [rootedPlant, offPatchPlant], soilPatches: [patch])

        #expect(canvasView.soilSinkDepth(for: rootedPlant) > 0)
        #expect(canvasView.soilSinkDepth(for: offPatchPlant) == 0)
    }

    private func canvas(
        plants: [Plant] = [],
        soilPatches: [SoilPatch]
    ) -> GardenCanvasView {
        GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 480, height: 300),
            screenIndex: 0,
            store: GardenStore(
                state: GardenState(plants: plants, soilPatches: soilPatches),
                persistence: GardenPersistence(
                    directoryURL: FileManager.default.temporaryDirectory
                        .appendingPathComponent("garden-soil-brush-test-\(UUID().uuidString)", isDirectory: true)
                ),
                activeSceneKey: "brazilian-rooftop-garden"
            )
        )
    }
}
