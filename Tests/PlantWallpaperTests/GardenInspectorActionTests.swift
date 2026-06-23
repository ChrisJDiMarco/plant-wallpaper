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

    @Test("heart action toggles the selected plant favorite state")
    func heartActionTogglesSelectedPlantFavoriteState() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("garden-inspector-favorite-\(UUID().uuidString)", isDirectory: true)
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

        #expect(canvasView.tooltip(for: .care, plant: plant) == "Add to favorites")

        canvasView.performInspectorAction(.care)

        let favoritePlant = try #require(store.selectedPlant)
        #expect(favoritePlant.isFavorite)
        #expect(canvasView.tooltip(for: .care, plant: favoritePlant) == "Remove from favorites")

        canvasView.performInspectorAction(.care)

        #expect(store.selectedPlant?.isFavorite == false)
    }

    @Test("water action records a watered timestamp for button feedback")
    func waterActionRecordsWateredTimestampForButtonFeedback() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("garden-inspector-water-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.42, y: 0.66),
            growth: 0.72,
            hydration: 0.12,
            health: 0.88,
            bloomProgress: 0.20,
            swaySeed: 12
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

        canvasView.performInspectorAction(.water)

        #expect(store.selectedPlant?.lastWateredAt != nil)
        #expect((store.selectedPlant?.hydration ?? 0) > plant.hydration)
    }
}
