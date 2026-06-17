import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden plant explorer")
struct GardenPlantExplorerTests {
    @Test("plant inspector explore action opens and closes the plant explorer")
    func plantInspectorExploreActionOpensAndClosesPlantExplorer() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("garden-plant-explorer-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let plant = Plant(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.48, y: 0.72),
            growth: 0.82,
            hydration: 0.74,
            health: 0.91,
            bloomProgress: 0.55,
            swaySeed: 11
        )
        let store = GardenStore(
            state: GardenState(plants: [plant]),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        store.setSelectedPlant(plant.id)

        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 960, height: 640),
            screenIndex: 0,
            store: store
        )
        let exploreRect = try #require(canvasView.inspectorActionRects(for: plant).first { $0.0 == .explore }?.1)
        let explorePoint = NSPoint(x: exploreRect.midX, y: exploreRect.midY)

        #expect(canvasView.beginGardenInteraction(at: explorePoint) == .handled)
        #expect(canvasView.isPlantExplorerVisibleForSelfTest())
        #expect(canvasView.plantExplorerRectIfVisible()?.width ?? 0 > 500)

        let closePoint = try #require(canvasView.plantExplorerCloseHitPointForSelfTest())
        #expect(canvasView.beginGardenInteraction(at: closePoint) == .handled)
        #expect(!canvasView.isPlantExplorerVisibleForSelfTest())
    }
}
