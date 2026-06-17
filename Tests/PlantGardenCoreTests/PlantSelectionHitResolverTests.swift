import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant selection hit resolver")
struct PlantSelectionHitResolverTests {
    @Test("nearby unselected plant can take focus from the selected plant")
    func nearbyUnselectedPlantCanTakeFocusFromSelectedPlant() throws {
        let selectedID = UUID()
        let nextID = UUID()
        let resolvedID = PlantSelectionHitResolver.preferredPlantID(from: [
            PlantSelectionHitCandidate(id: selectedID, distanceFromClick: 0.28, depth: 0.82, isSelected: true),
            PlantSelectionHitCandidate(id: nextID, distanceFromClick: 0.04, depth: 0.68, isSelected: false)
        ])

        #expect(resolvedID == nextID)
    }

    @Test("selected plant does not monopolize overlapping plant clicks")
    func selectedPlantDoesNotMonopolizeOverlappingPlantClicks() throws {
        let selectedID = UUID()
        let nextID = UUID()
        let resolvedID = PlantSelectionHitResolver.preferredPlantID(from: [
            PlantSelectionHitCandidate(id: selectedID, distanceFromClick: 0.018, depth: 0.90, isSelected: true),
            PlantSelectionHitCandidate(id: nextID, distanceFromClick: 0.062, depth: 0.62, isSelected: false)
        ])

        #expect(resolvedID == nextID)
    }

    @Test("foreground plant wins when click distances are similar")
    func foregroundPlantWinsWhenClickDistancesAreSimilar() throws {
        let backID = UUID()
        let frontID = UUID()
        let resolvedID = PlantSelectionHitResolver.preferredPlantID(from: [
            PlantSelectionHitCandidate(id: backID, distanceFromClick: 0.052, depth: 0.46, isSelected: false),
            PlantSelectionHitCandidate(id: frontID, distanceFromClick: 0.050, depth: 0.88, isSelected: false)
        ])

        #expect(resolvedID == frontID)
    }

    @Test("single selected candidate remains selectable")
    func singleSelectedCandidateRemainsSelectable() throws {
        let selectedID = UUID()
        let resolvedID = PlantSelectionHitResolver.preferredPlantID(from: [
            PlantSelectionHitCandidate(id: selectedID, distanceFromClick: 0.18, depth: 0.74, isSelected: true)
        ])

        #expect(resolvedID == selectedID)
    }

    @Test("selected plant can keep focus when the click is clearly closest to it")
    func selectedPlantCanKeepFocusWhenClickIsClearlyClosestToIt() throws {
        let selectedID = UUID()
        let nextID = UUID()
        let resolvedID = PlantSelectionHitResolver.preferredPlantID(from: [
            PlantSelectionHitCandidate(id: selectedID, distanceFromClick: 0.005, depth: 0.74, isSelected: true),
            PlantSelectionHitCandidate(id: nextID, distanceFromClick: 0.18, depth: 0.76, isSelected: false)
        ])

        #expect(resolvedID == selectedID)
    }
}
