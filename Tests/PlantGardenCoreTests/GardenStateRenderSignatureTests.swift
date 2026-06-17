import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden state render signature")
struct GardenStateRenderSignatureTests {
    @Test("one-second simulation tick produces an identical signature")
    func oneSecondTickProducesIdenticalSignature() {
        let now = Date()
        // The first advance snaps wind/moisture from their stored defaults
        // onto the live environment waves, so settle once before comparing
        // consecutive ticks the way the 1 Hz simulation timer produces them.
        let settledState = GardenEngine.advance(
            GardenState.defaultGarden(screenCount: 1, now: now),
            to: now.addingTimeInterval(1)
        )

        let tickedState = GardenEngine.advance(settledState, to: now.addingTimeInterval(2))

        #expect(tickedState != settledState, "advance should still record the tick")
        #expect(
            GardenStateRenderSignature(of: tickedState) == GardenStateRenderSignature(of: settledState),
            "a one-second tick changes nothing a viewer can see"
        )
    }

    @Test("watering a plant changes the signature")
    func wateringChangesSignature() {
        let state = GardenState.defaultGarden(screenCount: 1)

        let wateredState = GardenEngine.waterAll(state)

        #expect(GardenStateRenderSignature(of: wateredState) != GardenStateRenderSignature(of: state))
    }

    @Test("hours of growth change the signature")
    func hoursOfGrowthChangeSignature() {
        let now = Date()
        let state = GardenState.defaultGarden(screenCount: 1, now: now)

        let grownState = GardenEngine.advance(state, to: now.addingTimeInterval(4 * 3_600))

        #expect(GardenStateRenderSignature(of: grownState) != GardenStateRenderSignature(of: state))
    }

    @Test("moving a plant changes the signature")
    func movingPlantChangesSignature() {
        let state = GardenState.defaultGarden(screenCount: 1)
        let plantID = state.plants[0].id

        let movedState = GardenEngine.movePlant(state, id: plantID, to: GardenPoint(x: 0.5, y: 0.7))

        #expect(GardenStateRenderSignature(of: movedState) != GardenStateRenderSignature(of: state))
    }
}
