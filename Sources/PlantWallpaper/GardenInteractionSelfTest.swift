import AppKit
import PlantGardenCore

@MainActor
enum GardenInteractionSelfTest {
    private enum Failure: Error, CustomStringConvertible {
        case message(String)

        var description: String {
            switch self {
            case .message(let message):
                message
            }
        }
    }

    static func run() -> Bool {
        do {
            try verifyEverySpeciesCanSelectAndDrag()
            try verifyClicksBesidePlantsSelectNothingAndDeselect()
            try verifyEverySpeciesHasInteractionRegionOverBody()
            try verifyInspectorButtonsHandleClicks()
            try verifyInspectorBodyBlocksPlantBehindIt()
            try verifyHeartAndWaterButtonsChangePlantState()
            try verifyGrowthAndPruneButtonsStayPinned()
            try verifyEmptyClickRoutesAndDeselectsPlant()
            try verifySelectedPlantResizeHandlesScaleProportionally()
            try verifyMusicButtonCanClickAndDrag()
            try verifyTinyEdgeSeedlingCanSelectAndDrag()
            try verifyWallpaperSceneSwitchingKeepsSeparateGardenStates()
            return true
        } catch {
            fputs("Interaction self-test failed: \(error)\n", stderr)
            return false
        }
    }

    private static func verifyInspectorBodyBlocksPlantBehindIt() throws {
        let selectedPlant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.54, y: 0.74),
            growth: 0.72,
            hydration: 0.64,
            health: 0.86,
            bloomProgress: 0.68,
            swaySeed: 184,
            scale: 1.0
        )
        let store = makeStore(plants: [selectedPlant])
        let canvasView = makeCanvasView(store: store)
        store.setSelectedPlant(selectedPlant.id)

        guard let bodyPoint = canvasView.inspectorBodyHitPointForSelfTest() else {
            throw Failure.message("selected inspector did not expose a body hit point")
        }

        let obscuredPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(
                x: Double(bodyPoint.x / canvasView.bounds.width),
                y: Double(bodyPoint.y / canvasView.bounds.height)
            ),
            growth: 0.74,
            hydration: 0.62,
            health: 0.82,
            bloomProgress: 0.70,
            swaySeed: 185,
            scale: 1.0
        )
        let shieldStore = makeStore(plants: [selectedPlant, obscuredPlant])
        let shieldCanvasView = makeCanvasView(store: shieldStore)
        shieldStore.setSelectedPlant(selectedPlant.id)

        guard shieldCanvasView.shouldReceiveMouseEvents(at: bodyPoint) else {
            throw Failure.message("inspector body did not route mouse events")
        }
        guard shieldCanvasView.hitTest(bodyPoint) === shieldCanvasView else {
            throw Failure.message("inspector body did not hit-test to the canvas")
        }
        let result = shieldCanvasView.beginGardenInteraction(at: bodyPoint, clickCount: 1)
        guard result == .handled else {
            throw Failure.message("inspector body click was not handled")
        }
        guard shieldStore.selectedPlantID == selectedPlant.id else {
            throw Failure.message("inspector body click selected the plant behind the modal")
        }
    }

    private static func verifyHeartAndWaterButtonsChangePlantState() throws {
        let thrivingPlant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.54, y: 0.74),
            lastTendedAt: Date(timeIntervalSince1970: 1_000),
            growth: 0.98,
            hydration: 0.66,
            health: 0.82,
            bloomProgress: 0.40,
            swaySeed: 286,
            scale: 1.0
        )
        let heartStore = makeStore(plants: [thrivingPlant])
        let heartCanvasView = makeCanvasView(store: heartStore)
        heartStore.setSelectedPlant(thrivingPlant.id)
        guard let heartPoint = heartCanvasView.inspectorActionHitPointsForSelfTest().first else {
            throw Failure.message("heart action point was unavailable")
        }
        guard heartCanvasView.beginGardenInteraction(at: heartPoint, clickCount: 1) == .handled else {
            throw Failure.message("heart action did not handle click")
        }
        guard let heartPlant = heartStore.state.plants.first,
              heartPlant.lastTendedAt != thrivingPlant.lastTendedAt,
              heartPlant.health >= thrivingPlant.health else {
            throw Failure.message("heart action did not tend a thriving selected plant")
        }

        let dryPlant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.54, y: 0.74),
            growth: 0.68,
            hydration: 0.12,
            health: 0.74,
            bloomProgress: 0.52,
            swaySeed: 287,
            scale: 1.0
        )
        let waterStore = makeStore(plants: [dryPlant])
        let waterCanvasView = makeCanvasView(store: waterStore)
        waterStore.setSelectedPlant(dryPlant.id)
        let waterPoints = waterCanvasView.inspectorActionHitPointsForSelfTest()
        guard waterPoints.count >= 2 else {
            throw Failure.message("water action point was unavailable")
        }
        guard waterCanvasView.beginGardenInteraction(at: waterPoints[1], clickCount: 1) == .handled else {
            throw Failure.message("water action did not handle click")
        }
        guard let wateredPlant = waterStore.state.plants.first,
              wateredPlant.hydration > dryPlant.hydration else {
            throw Failure.message("water action did not increase selected plant hydration")
        }
    }

    private static func verifyGrowthAndPruneButtonsStayPinned() throws {
        let growingPlant = Plant(
            species: .succulent,
            screenIndex: 0,
            position: GardenPoint(x: 0.54, y: 0.74),
            growth: 0.42,
            hydration: 0.72,
            health: 0.84,
            bloomProgress: 0.36,
            swaySeed: 388,
            scale: 1.0
        )
        let growStore = makeStore(plants: [growingPlant])
        let growCanvasView = makeCanvasView(store: growStore)
        growStore.setSelectedPlant(growingPlant.id)
        let growPoints = growCanvasView.inspectorActionHitPointsForSelfTest()
        guard growPoints.count >= 3 else {
            throw Failure.message("nourish action point was unavailable")
        }
        let growPoint = growPoints[2]
        guard growCanvasView.beginGardenInteraction(at: growPoint, clickCount: 1) == .handled,
              growCanvasView.beginGardenInteraction(at: growPoint, clickCount: 1) == .handled else {
            throw Failure.message("nourish action did not remain clickable at its original point")
        }
        guard let grownPlant = growStore.state.plants.first,
              grownPlant.growth > growingPlant.growth else {
            throw Failure.message("nourish action did not grow selected plant")
        }

        let prunePlant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.54, y: 0.74),
            growth: 0.78,
            hydration: 0.68,
            health: 0.62,
            bloomProgress: 0.50,
            swaySeed: 389,
            scale: 1.0
        )
        let pruneStore = makeStore(plants: [prunePlant])
        let pruneCanvasView = makeCanvasView(store: pruneStore)
        pruneStore.setSelectedPlant(prunePlant.id)
        let prunePoints = pruneCanvasView.inspectorActionHitPointsForSelfTest()
        guard prunePoints.count >= 4 else {
            throw Failure.message("prune action point was unavailable")
        }
        let prunePoint = prunePoints[3]
        guard pruneCanvasView.beginGardenInteraction(at: prunePoint, clickCount: 1) == .handled,
              pruneCanvasView.beginGardenInteraction(at: prunePoint, clickCount: 1) == .handled else {
            throw Failure.message("prune action did not remain clickable at its original point")
        }
        guard let prunedPlant = pruneStore.state.plants.first,
              prunedPlant.health > prunePlant.health,
              prunedPlant.growth < prunePlant.growth else {
            throw Failure.message("prune action did not trim selected plant")
        }
    }

    private static func verifyEverySpeciesCanSelectAndDrag() throws {
        for species in PlantAssetLibrary.shared.displayableSpecies() {
            let plant = Plant(
                species: species,
                screenIndex: 0,
                position: GardenPoint(x: 0.50, y: 0.74),
                growth: species.kind == .tree ? 0.34 : 0.28,
                hydration: 0.72,
                health: 0.84,
                bloomProgress: species.kind == .tree ? 0.20 : 0.42,
                swaySeed: 42,
                scale: 1.0
            )
            let store = makeStore(plants: [plant])
            let canvasView = makeCanvasView(store: store)
            guard let pressPoint = canvasView.plantBodyHitPoint(for: plant.id) else {
                throw Failure.message("\(species.displayName) did not expose a visible body point")
            }

            let result = canvasView.beginGardenInteraction(at: pressPoint, clickCount: 1)
            guard result == .drag else {
                throw Failure.message("\(species.displayName) did not begin drag from visible body point")
            }

            let dragPoint = NSPoint(x: pressPoint.x + 96, y: pressPoint.y)
            guard canvasView.continuePlantDrag(at: dragPoint) else {
                throw Failure.message("\(species.displayName) drag did not continue")
            }
            guard canvasView.endPlantDrag() else {
                throw Failure.message("\(species.displayName) drag did not end")
            }

            guard let movedPlant = store.state.plants.first,
                  movedPlant.id == plant.id,
                  movedPlant.position.x > plant.position.x else {
                throw Failure.message("\(species.displayName) did not move after drag")
            }
        }

    }

    /// Regression guard: clicking beside a plant (inside the old padded hit
    /// box but outside the visible artwork) must select nothing, and when a
    /// plant is selected the same click must clear the selection.
    private static func verifyClicksBesidePlantsSelectNothingAndDeselect() throws {
        let plant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.74),
            growth: 0.72,
            hydration: 0.64,
            health: 0.86,
            bloomProgress: 0.52,
            swaySeed: 777,
            scale: 1.0
        )
        let store = makeStore(plants: [plant])
        let canvasView = makeCanvasView(store: store)
        guard let artworkRect = canvasView.plantArtworkRectForSelfTest(for: plant.id) else {
            throw Failure.message("plant did not expose an artwork rect")
        }

        let besidePoint = NSPoint(x: artworkRect.minX - 30, y: artworkRect.maxY + 30)
        let result = canvasView.beginGardenInteraction(at: besidePoint, clickCount: 1)
        guard result == .none else {
            throw Failure.message("clicking beside a plant began an interaction")
        }
        guard store.selectedPlantID == nil else {
            throw Failure.message("clicking beside a plant selected it")
        }

        store.setSelectedPlant(plant.id)
        guard canvasView.beginGardenInteraction(at: besidePoint, clickCount: 1) == .none else {
            throw Failure.message("clicking beside a selected plant began an interaction")
        }
        guard canvasView.clearSelectionIfEmptyInteraction(at: besidePoint) else {
            throw Failure.message("clicking beside a selected plant did not clear selection")
        }
        guard store.selectedPlantID == nil else {
            throw Failure.message("selection survived an empty click beside the plant")
        }
    }

    private static func verifyEverySpeciesHasInteractionRegionOverBody() throws {
        for species in PlantAssetLibrary.shared.displayableSpecies() {
            let plant = Plant(
                species: species,
                screenIndex: 0,
                position: GardenPoint(x: 0.50, y: 0.74),
                growth: species.kind == .tree ? 0.34 : 0.28,
                hydration: 0.72,
                health: 0.84,
                bloomProgress: species.kind == .tree ? 0.20 : 0.42,
                swaySeed: 44,
                scale: 1.0
            )
            let store = makeStore(plants: [plant])
            let canvasView = makeCanvasView(store: store)
            guard let pressPoint = canvasView.plantBodyHitPoint(for: plant.id) else {
                throw Failure.message("\(species.displayName) did not expose a visible body point")
            }

            guard canvasView.interactionRegionRects().contains(where: { $0.contains(pressPoint) }) else {
                throw Failure.message("\(species.displayName) did not expose an interaction region over its visible body")
            }
        }
    }

    private static func verifyInspectorButtonsHandleClicks() throws {
        let plant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.54, y: 0.74),
            growth: 0.72,
            hydration: 0.18,
            health: 0.72,
            bloomProgress: 0.68,
            swaySeed: 84,
            scale: 1.0
        )
        let store = makeStore(plants: [plant])
        let canvasView = makeCanvasView(store: store)
        store.setSelectedPlant(plant.id)

        let inspectorActions = canvasView.inspectorActions(for: plant)
        let actionPoints = canvasView.inspectorActionHitPointsForSelfTest()
        guard actionPoints.count == inspectorActions.count else {
            throw Failure.message("selected inspector did not expose all action hit points")
        }
        let edgeActionPoints = canvasView.inspectorActionEdgeHitPointsForSelfTest()
        guard edgeActionPoints.count == inspectorActions.count else {
            throw Failure.message("selected inspector did not expose all edge action hit points")
        }

        for (index, actionPoint) in (actionPoints + edgeActionPoints).enumerated() {
            guard canvasView.shouldReceiveMouseEvents(at: actionPoint) else {
                throw Failure.message("inspector action point \(index) did not route mouse events")
            }
            guard canvasView.hitTest(actionPoint) === canvasView else {
                throw Failure.message("inspector action point \(index) did not hit-test to the canvas")
            }
        }

        for (index, actionPoint) in actionPoints.enumerated() {
            let inspectorAction = inspectorActions[index]
            let usesIsolatedStore = inspectorAction == .clone || inspectorAction == .explore || inspectorAction == .remove
            let actionStore: GardenStore
            let actionCanvasView: GardenCanvasView
            let point: NSPoint

            if usesIsolatedStore {
                let removePlant = Plant(
                    species: .rose,
                    screenIndex: 0,
                    position: GardenPoint(x: 0.54, y: 0.74),
                    growth: 0.72,
                    hydration: 0.44,
                    health: 0.72,
                    bloomProgress: 0.62,
                    swaySeed: 126,
                    scale: 1.0
                )
                actionStore = makeStore(plants: [removePlant])
                actionCanvasView = makeCanvasView(store: actionStore)
                actionStore.setSelectedPlant(removePlant.id)
                let actionPoints = actionCanvasView.inspectorActionHitPointsForSelfTest()
                guard actionPoints.indices.contains(index) else {
                    throw Failure.message("isolated inspector action point \(index) was unavailable")
                }
                point = actionPoints[index]
            } else {
                actionStore = store
                actionCanvasView = canvasView
                point = actionPoint
            }

            let result = actionCanvasView.beginGardenInteraction(at: point, clickCount: 1)
            guard result == .handled else {
                throw Failure.message("inspector action \(index) did not handle click")
            }

            if inspectorAction == .explore, !actionCanvasView.isPlantExplorerVisibleForSelfTest() {
                throw Failure.message("explore inspector action did not open plant explorer")
            }
            if inspectorAction == .remove, !actionStore.state.plants.isEmpty {
                throw Failure.message("remove inspector action did not remove selected plant")
            }
            if inspectorAction == .clone {
                guard actionStore.state.plants.count == 2,
                      let selectedPlant = actionStore.selectedPlant,
                      selectedPlant.id != actionStore.state.plants[0].id,
                      selectedPlant.species == actionStore.state.plants[0].species,
                      selectedPlant.position != actionStore.state.plants[0].position else {
                    throw Failure.message("clone inspector action did not create and select a nearby copy")
                }
            }
        }
    }

    private static func verifyEmptyClickRoutesAndDeselectsPlant() throws {
        let plant = Plant(
            species: .bonsai,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.74),
            growth: 0.78,
            hydration: 0.62,
            health: 0.86,
            bloomProgress: 0.24,
            swaySeed: 168,
            scale: 1.0
        )
        let store = makeStore(plants: [plant])
        let canvasView = makeCanvasView(store: store)
        store.setSelectedPlant(plant.id)

        guard let plantBodyPoint = canvasView.plantBodyHitPoint(for: plant.id) else {
            throw Failure.message("selected plant did not expose a visible body point")
        }
        if canvasView.clearSelectionIfEmptyInteraction(at: plantBodyPoint) {
            throw Failure.message("clicking the selected plant body cleared selection")
        }
        guard store.selectedPlantID == plant.id else {
            throw Failure.message("selected plant was lost before empty click")
        }

        let emptyPoint = NSPoint(x: 24, y: 24)
        guard canvasView.shouldReceiveMouseEvents(at: emptyPoint) else {
            throw Failure.message("selected empty desktop point did not route mouse events to the canvas")
        }
        guard canvasView.hitTest(emptyPoint) === canvasView else {
            throw Failure.message("selected empty desktop point did not hit-test to the canvas")
        }
        guard canvasView.clearSelectionIfEmptyInteraction(at: emptyPoint) else {
            throw Failure.message("empty desktop point did not clear selection")
        }
        guard store.selectedPlantID == nil else {
            throw Failure.message("empty desktop point left selected plant active")
        }
        if canvasView.shouldReceiveMouseEvents(at: emptyPoint) {
            throw Failure.message("unselected empty desktop point still routed mouse events to the canvas")
        }
        if canvasView.hitTest(emptyPoint) != nil {
            throw Failure.message("unselected empty desktop point stopped passing through")
        }
    }

    private static func verifySelectedPlantResizeHandlesScaleProportionally() throws {
        let plant = Plant(
            species: .bonsai,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.74),
            growth: 0.78,
            hydration: 0.62,
            health: 0.86,
            bloomProgress: 0.24,
            swaySeed: 169,
            scale: 1.0
        )
        let store = makeStore(plants: [plant])
        let canvasView = makeCanvasView(store: store)
        store.setSelectedPlant(plant.id)

        let handlePoints = canvasView.resizeHandleHitPointsForSelfTest()
        guard handlePoints.count == 4 else {
            throw Failure.message("selected plant did not expose four resize handles")
        }

        for (index, handlePoint) in handlePoints.enumerated() {
            guard canvasView.shouldReceiveMouseEvents(at: handlePoint) else {
                throw Failure.message("resize handle \(index) did not route mouse events")
            }
            guard canvasView.hitTest(handlePoint) === canvasView else {
                throw Failure.message("resize handle \(index) did not hit-test to the canvas")
            }
        }

        let growPoint = handlePoints[0]
        guard canvasView.beginGardenInteraction(at: growPoint, clickCount: 1) == .drag else {
            throw Failure.message("resize handle did not start a drag interaction")
        }
        guard canvasView.continuePlantDrag(at: NSPoint(x: growPoint.x - 120, y: growPoint.y - 120)) else {
            throw Failure.message("resize handle drag did not continue")
        }
        guard canvasView.endPlantDrag() else {
            throw Failure.message("resize handle drag did not end")
        }
        guard let enlargedPlant = store.state.plants.first,
              enlargedPlant.scale > plant.scale,
              enlargedPlant.position == plant.position else {
            throw Failure.message("resize handle did not enlarge selected plant without moving it")
        }

        let shrinkStore = makeStore(plants: [plant])
        let shrinkCanvasView = makeCanvasView(store: shrinkStore)
        shrinkStore.setSelectedPlant(plant.id)
        guard let shrinkPoint = shrinkCanvasView.resizeHandleHitPointsForSelfTest().first else {
            throw Failure.message("selected plant did not expose a shrink resize handle")
        }
        guard shrinkCanvasView.beginGardenInteraction(at: shrinkPoint, clickCount: 1) == .drag,
              shrinkCanvasView.continuePlantDrag(at: NSPoint(x: shrinkPoint.x + 80, y: shrinkPoint.y + 80)),
              shrinkCanvasView.endPlantDrag() else {
            throw Failure.message("resize handle shrink drag was not handled")
        }
        guard let shrunkenPlant = shrinkStore.state.plants.first,
              shrunkenPlant.scale < plant.scale,
              shrunkenPlant.position == plant.position else {
            throw Failure.message("resize handle did not shrink selected plant without moving it")
        }
    }

    private static func verifyTinyEdgeSeedlingCanSelectAndDrag() throws {
        let plant = Plant(
            species: .succulent,
            screenIndex: 0,
            position: GardenPoint(x: 0.94, y: 0.52),
            growth: 0.08,
            hydration: 0.82,
            health: 0.88,
            bloomProgress: 0,
            swaySeed: 6554,
            scale: 0.75
        )
        let store = makeStore(plants: [plant])
        let canvasView = makeCanvasView(store: store)
        guard let pressPoint = canvasView.plantBodyHitPoint(for: plant.id) else {
            throw Failure.message("tiny edge seedling did not expose a visible body point")
        }

        guard canvasView.shouldReceiveMouseEvents(at: pressPoint) else {
            throw Failure.message("tiny edge seedling did not route mouse events")
        }
        guard canvasView.beginGardenInteraction(at: pressPoint, clickCount: 1) == .drag else {
            throw Failure.message("tiny edge seedling did not begin drag")
        }
        guard canvasView.continuePlantDrag(at: NSPoint(x: pressPoint.x - 120, y: pressPoint.y + 30)) else {
            throw Failure.message("tiny edge seedling drag did not continue")
        }
        guard canvasView.endPlantDrag() else {
            throw Failure.message("tiny edge seedling drag did not end")
        }
        guard let movedPlant = store.state.plants.first,
              movedPlant.position.x < plant.position.x else {
            throw Failure.message("tiny edge seedling did not move after drag")
        }
    }

    private static func verifyMusicButtonCanClickAndDrag() throws {
        let store = makeStore(plants: [])
        store.toggleMusicButton(screenIndex: 0, position: GardenPoint(x: 0.44, y: 0.62), companion: .tinyRocket)
        let musicPlayer = SelfTestMusicPlayer()
        let canvasView = makeCanvasView(store: store, musicPlayer: musicPlayer)

        guard let clickPoint = canvasView.musicButtonHitPointForSelfTest() else {
            throw Failure.message("radio companion did not expose a hit point")
        }
        guard canvasView.shouldReceiveMouseEvents(at: clickPoint) else {
            throw Failure.message("radio companion did not route mouse events")
        }
        guard canvasView.beginGardenInteraction(at: clickPoint, clickCount: 1) == .drag,
              canvasView.endPlantDrag(),
              musicPlayer.playCount == 1,
              musicPlayer.playedStations == [.spaceDogs],
              musicPlayer.isPlaying else {
            throw Failure.message("radio companion click did not start its station")
        }

        guard canvasView.beginGardenInteraction(at: clickPoint, clickCount: 1) == .drag,
              canvasView.continuePlantDrag(at: NSPoint(x: clickPoint.x + 90, y: clickPoint.y - 40)),
              canvasView.endPlantDrag(),
              musicPlayer.playCount == 1,
              let movedButton = store.state.musicButton,
              movedButton.position.x > 0.48,
              movedButton.position.y < 0.62 else {
            throw Failure.message("radio companion drag did not move without toggling playback")
        }
    }

    private static func verifyWallpaperSceneSwitchingKeepsSeparateGardenStates() throws {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("WallpaperGardenSceneSwitchSelfTest-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let persistence = GardenPersistence(directoryURL: directoryURL)
        let originalPlantID = UUID(uuidString: "00000000-0000-0000-0000-000000000101") ?? UUID()
        let originalPlant = Plant(
            id: originalPlantID,
            species: .bonsai,
            screenIndex: 0,
            position: GardenPoint(x: 0.16, y: 0.32),
            growth: 0.42,
            hydration: 0.70,
            health: 0.88,
            bloomProgress: 0.12,
            swaySeed: 501,
            scale: 1.0
        )
        let store = GardenStore(
            state: GardenState(plants: [originalPlant], ambientMoisture: 0.31, windStrength: 0.0),
            persistence: persistence,
            activeSceneKey: "empty-conservatory-hall"
        )
        store.setSelectedPlant(originalPlantID)
        store.moveSelectedPlant(to: GardenPoint(x: 0.24, y: 0.68), screenIndex: 0)
        store.save()

        store.switchGardenScene(to: "rooftop-seed-house", screenCount: 1)
        guard store.state.plants.first(where: { $0.id == originalPlantID }) == nil else {
            throw Failure.message("new wallpaper scene reused the previous scene's plant placement")
        }

        store.addPlant(species: .succulent, screenIndex: 0, position: GardenPoint(x: 0.82, y: 0.71))
        guard let rooftopPlantID = store.selectedPlantID else {
            throw Failure.message("new scene plant was not selected after adding")
        }

        store.switchGardenScene(to: "empty-conservatory-hall", screenCount: 1)
        guard store.state.plants.count == 1,
              let restoredPlant = store.state.plants.first,
              restoredPlant.id == originalPlantID,
              restoredPlant.position == GardenPoint(x: 0.24, y: 0.68) else {
            throw Failure.message("switching back did not restore the first scene's saved plant placement")
        }

        store.switchGardenScene(to: "rooftop-seed-house", screenCount: 1)
        guard store.state.plants.contains(where: { $0.id == rooftopPlantID }) else {
            throw Failure.message("switching scenes did not restore the second scene's saved plant placement")
        }

        store.removeAllPlantsInCurrentScene()
        guard store.state.plants.isEmpty else {
            throw Failure.message("deleting all plants in the active scene did not clear the scene")
        }

        store.switchGardenScene(to: "empty-conservatory-hall", screenCount: 1)
        guard store.state.plants.contains(where: { $0.id == originalPlantID }) else {
            throw Failure.message("deleting all plants in one scene cleared another scene")
        }
    }

    private static func makeStore(plants: [Plant]) -> GardenStore {
        let state = GardenState(plants: plants, ambientMoisture: 0.38, windStrength: 0.0)
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("WallpaperGardenInteractionSelfTest-\(UUID().uuidString)", isDirectory: true)
        return GardenStore(
            state: state,
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
    }

    private static func makeCanvasView(
        store: GardenStore,
        musicPlayer: GardenMusicPlaybackControlling = GardenRadioPlayer.shared
    ) -> GardenCanvasView {
        GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 1728, height: 1117),
            screenIndex: 0,
            store: store,
            musicPlayer: musicPlayer
        )
    }

    private final class SelfTestMusicPlayer: GardenMusicPlaybackControlling {
        var toggleCount = 0
        private(set) var toggledStations: [GardenRadioStation] = []
        private(set) var playCount = 0
        private(set) var playedStations: [GardenRadioStation] = []
        private(set) var isPlaying = false
        private(set) var playingRadioStation: GardenRadioStation?
        private(set) var playingRadioStream: GardenRadioStream?

        func playChillHopRadio() {
            playRadioStation(.chillHopByFluxFM)
        }

        func playRadioStation(_ station: GardenRadioStation) {
            playRadioStream(station.stream)
        }

        func playRadioStream(_ stream: GardenRadioStream) {
            playCount += 1
            if let station = stream.matchesBuiltInStation {
                playedStations.append(station)
            }
            isPlaying = true
            playingRadioStation = stream.matchesBuiltInStation
            playingRadioStream = stream
        }

        func playSpotify(using settings: GardenSettings) {
            isPlaying = true
            playingRadioStation = nil
            playingRadioStream = nil
        }

        func stop() {
            isPlaying = false
            playingRadioStation = nil
            playingRadioStream = nil
        }

        func toggleChillHopRadio() {
            toggleRadioStation(.chillHopByFluxFM)
        }

        func toggleRadioStation(_ station: GardenRadioStation) {
            toggleRadioStream(station.stream)
        }

        func toggleRadioStream(_ stream: GardenRadioStream) {
            toggleCount += 1
            if let station = stream.matchesBuiltInStation {
                toggledStations.append(station)
            }
            if isPlaying, playingRadioStream?.id == stream.id {
                stop()
            } else {
                playRadioStream(stream)
            }
        }

        func toggleMusic(using settings: GardenSettings) {
            toggleCount += 1
            isPlaying ? stop() : playChillHopRadio()
        }
    }
}
