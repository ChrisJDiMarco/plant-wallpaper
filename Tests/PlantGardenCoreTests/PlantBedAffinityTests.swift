import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant bed affinity")
struct PlantBedAffinityTests {
    @Test("plants rooted in a bed get a small stability benefit")
    func plantsRootedInBedGetBenefit() {
        let plant = Plant(
            species: .cherryTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.22, y: 0.62)
        )

        let affinity = PlantBedAffinity(plant: plant)

        #expect(affinity.fit == .rooted)
        #expect(affinity.growthMultiplier > 1)
        #expect(affinity.waterUseMultiplier < 1)
        #expect(affinity.healthAdjustmentPerHour > 0)
        #expect(affinity.shortSummary == "Rooted bed")
    }

    @Test("plants near a bed edge stay mostly neutral")
    func plantsNearBedEdgeStayMostlyNeutral() {
        let plant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.67)
        )

        let affinity = PlantBedAffinity(plant: plant)

        #expect(affinity.fit == .edge)
        #expect(affinity.growthMultiplier < 1)
        #expect(affinity.growthMultiplier > 0.90)
        #expect(affinity.shortSummary == "Bed edge")
    }

    @Test("off-bed plants are exposed")
    func offBedPlantsAreExposed() {
        let plant = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.36)
        )

        let affinity = PlantBedAffinity(plant: plant)

        #expect(affinity.fit == .exposed)
        #expect(affinity.growthMultiplier < 0.90)
        #expect(affinity.waterUseMultiplier > 1.08)
        #expect(affinity.healthAdjustmentPerHour < 0)
        #expect(affinity.shortSummary == "Off bed")
    }

    @Test("climbers placed above beds are treated as support-trained")
    func climbersPlacedAboveBedsAreTreatedAsSupportTrained() {
        let plant = Plant(
            species: .ivy,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.36)
        )

        let affinity = PlantBedAffinity(plant: plant)

        #expect(affinity.fit == .support)
        #expect(affinity.growthMultiplier > 1)
        #expect(affinity.waterUseMultiplier < 1)
        #expect(affinity.healthAdjustmentPerHour > 0)
        #expect(affinity.shortSummary == "On support")
    }

    @Test("ordinary off-bed plants remain exposed even where climbers can use structure")
    func ordinaryOffBedPlantsRemainExposedEvenWhereClimbersCanUseStructure() {
        let plant = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.36)
        )

        let affinity = PlantBedAffinity(plant: plant)

        #expect(affinity.fit == .exposed)
        #expect(affinity.shortSummary == "Off bed")
    }

    @Test("composition slots land on bed or edge zones")
    func compositionSlotsLandOnBedOrEdgeZones() {
        let garden = GardenState.defaultGarden(screenCount: 1)
        let affinities = garden.plants.map { PlantBedAffinity(plant: $0) }

        #expect(!affinities.contains { $0.fit == .exposed })
        #expect(affinities.contains { $0.fit == .rooted })
    }
}
