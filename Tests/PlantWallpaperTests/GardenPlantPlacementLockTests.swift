import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden plant placement lock")
struct GardenPlantPlacementLockTests {
    @Test("locked plants can be selected but do not start drag gestures")
    func lockedPlantsCanBeSelectedButDoNotStartDragGestures() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let plant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.72),
            growth: 1.0,
            hydration: 0.8,
            health: 0.9,
            placementLocked: true
        )
        let store = GardenStore(
            state: GardenState(plants: [plant]),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store
        )
        let hitPoint = try #require(canvasView.plantBodyHitPoint(for: plant.id))

        #expect(canvasView.beginGardenInteraction(at: hitPoint) == .handled)
        #expect(store.selectedPlantID == plant.id)
        #expect(!canvasView.continuePlantDrag(at: NSPoint(x: hitPoint.x + 80, y: hitPoint.y + 40)))
        #expect(store.selectedPlant?.position == plant.position)
    }

    @Test("inspector lock action toggles placement lock and hides resize handles")
    func inspectorLockActionTogglesPlacementLockAndHidesResizeHandles() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let plant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.72),
            growth: 1.0,
            hydration: 0.8,
            health: 0.9
        )
        let store = GardenStore(
            state: GardenState(plants: [plant]),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store
        )
        store.setSelectedPlant(plant.id)

        let lockRect = try #require(
            canvasView.inspectorActionRects(for: plant).first { $0.0 == .lockPlacement }?.1
        )
        #expect(canvasView.resizeHandleRects(for: plant).count == 4)
        #expect(canvasView.beginGardenInteraction(at: NSPoint(x: lockRect.midX, y: lockRect.midY)) == .handled)

        let lockedPlant = try #require(store.selectedPlant)
        #expect(lockedPlant.placementLocked)
        #expect(canvasView.resizeHandleRects(for: lockedPlant).isEmpty)

        let unlockRect = try #require(
            canvasView.inspectorActionRects(for: lockedPlant).first { $0.0 == .lockPlacement }?.1
        )
        #expect(canvasView.beginGardenInteraction(at: NSPoint(x: unlockRect.midX, y: unlockRect.midY)) == .handled)
        #expect(store.selectedPlant?.placementLocked == false)
    }

    private static func temporaryDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperGardenPlacementLock-\(UUID().uuidString)", isDirectory: true)
    }
}
