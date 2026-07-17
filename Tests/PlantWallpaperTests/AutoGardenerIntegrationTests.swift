import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Auto Gardener integration")
struct AutoGardenerIntegrationTests {
    @Test("store auto-plants highlighted zones")
    func storeAutoPlantsHighlightedZones() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("auto-gardener-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = GardenStore(
            state: GardenState(),
            persistence: GardenPersistence(directoryURL: directoryURL),
            activeSceneKey: "sunny-apartment-loft"
        )
        store.addAutoGardenerZone(screenIndex: 0, points: [
            GardenPoint(x: 0.2, y: 0.3),
            GardenPoint(x: 0.6, y: 0.3),
            GardenPoint(x: 0.5, y: 0.7)
        ])
        let zoneID = try #require(store.state.autoGardenerZones.first?.id)
        store.updateAutoGardenerZone(id: zoneID, placementType: .smallPot, size: .small)

        let plantedCount = store.autoPlantGardenerZones()

        #expect(plantedCount == 2)
        #expect(store.state.plants.count == 2)
        #expect(store.state.isUserArranged)
        #expect(store.state.plants.allSatisfy { $0.screenIndex == 0 })
        #expect(store.selectedPlantID == store.state.plants.last?.id)
    }

    @Test("canvas drag saves a normalized Auto Gardener zone")
    func canvasDragSavesNormalizedZone() {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("auto-gardener-canvas-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = GardenStore(
            state: GardenState(),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 1000, height: 500),
            screenIndex: 0,
            store: store
        )

        canvasView.isAutoGardenerDrawingMode = true

        #expect(GardenCanvasView.autoGardenerMarkerWidth < GardenCanvasView.gnomeZoneMarkerWidth)
        #expect(canvasView.shouldReceiveMouseEvents(at: NSPoint(x: 16, y: 16)))
        #expect(canvasView.beginAutoGardenerDraft(at: NSPoint(x: 100, y: 200)))
        #expect(canvasView.continueAutoGardenerDraft(at: NSPoint(x: 500, y: 200)))
        #expect(canvasView.continueAutoGardenerDraft(at: NSPoint(x: 420, y: 360)))
        #expect(canvasView.endAutoGardenerDraft())

        #expect(store.state.autoGardenerZones.count == 1)
        #expect(store.state.autoGardenerZones[0].points.first == GardenPoint(x: 0.1, y: 0.4))
        canvasView.isAutoGardenerDrawingMode = false
        #expect(!canvasView.autoGardenerGuideVisibleForSelfTest())
    }
}
