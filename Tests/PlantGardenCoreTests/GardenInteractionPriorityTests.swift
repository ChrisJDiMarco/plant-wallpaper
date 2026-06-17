import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden interaction priority")
struct GardenInteractionPriorityTests {
    @Test("selected plant controls win over plant drag hit areas")
    func selectedPlantControlsWinOverPlantDragHitAreas() {
        let target = GardenInteractionPriority.target(
            hasInspectorAction: true,
            hasPlant: true
        )

        #expect(target == .inspectorAction)
    }

    @Test("plant drag wins when no selected control is hit")
    func plantDragWinsWhenNoSelectedControlIsHit() {
        let target = GardenInteractionPriority.target(
            hasInspectorAction: false,
            hasPlant: true
        )

        #expect(target == .plant)
    }

    @Test("empty desktop remains pass through")
    func emptyDesktopRemainsPassThrough() {
        let target = GardenInteractionPriority.target(
            hasInspectorAction: false,
            hasPlant: false
        )

        #expect(target == .none)
    }

    @Test("empty click clears only when every coordinate candidate is empty")
    func emptyClickClearsOnlyWhenEveryCoordinateCandidateIsEmpty() {
        #expect(GardenInteractionPriority.shouldClearSelection(
            hasSelectedPlant: true,
            candidateContainsSelectionSurface: [false, false]
        ))
    }

    @Test("modal or plant candidate prevents empty click clearing")
    func modalOrPlantCandidatePreventsEmptyClickClearing() {
        #expect(!GardenInteractionPriority.shouldClearSelection(
            hasSelectedPlant: true,
            candidateContainsSelectionSurface: [false, true]
        ))
    }

    @Test("nothing clears when no plant is selected")
    func nothingClearsWhenNoPlantIsSelected() {
        #expect(!GardenInteractionPriority.shouldClearSelection(
            hasSelectedPlant: false,
            candidateContainsSelectionSurface: [false, false]
        ))
    }
}
