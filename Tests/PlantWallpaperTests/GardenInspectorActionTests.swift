import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden inspector actions")
struct GardenInspectorActionTests {
    @Test("inspector hover tracks action tooltips")
    func inspectorHoverTracksActionTooltips() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("garden-inspector-actions-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let plant = Plant(
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
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 960, height: 640),
            screenIndex: 0,
            store: store
        )
        store.setSelectedPlant(plant.id)

        let waterRect = try #require(canvasView.inspectorActionRects(for: plant).first { $0.0 == .water }?.1)
        canvasView.updateInspectorActionHover(at: NSPoint(x: waterRect.midX, y: waterRect.midY))

        #expect(canvasView.inspectorHoverAction == .water)
        #expect(canvasView.tooltip(for: .water, plant: plant) == "Water this plant")

        canvasView.updateInspectorActionHover(at: NSPoint(x: 5, y: 5))

        #expect(canvasView.inspectorHoverAction == nil)
    }
}
