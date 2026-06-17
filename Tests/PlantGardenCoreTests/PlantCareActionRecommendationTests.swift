import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant care action recommendation")
struct PlantCareActionRecommendationTests {
    @Test("dead selected plants do not recommend care")
    func deadSelectedPlantsDoNotRecommendCare() {
        let plant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.28, y: 0.82),
            hydration: 0,
            health: 0,
            diedAt: Date(timeIntervalSince1970: 100)
        )

        let recommendation = PlantCareActionRecommendation(plant: plant)

        #expect(recommendation.kind == .enjoy)
        #expect(!recommendation.isActionable)
        #expect(recommendation.summary == "Dead")
        #expect(recommendation.detail == "Remove or replant")
    }

    @Test("dry selected plants recommend water")
    func drySelectedPlantsRecommendWater() {
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.28, y: 0.82),
            hydration: 0.12,
            health: 0.82
        )

        let recommendation = PlantCareActionRecommendation(plant: plant)

        #expect(recommendation.kind == .water)
        #expect(recommendation.isActionable)
        #expect(recommendation.summary == "Water now")
    }

    @Test("recovering selected plants recommend pruning")
    func recoveringSelectedPlantsRecommendPruning() {
        let plant = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.36, y: 0.64),
            growth: 0.58,
            hydration: 0.72,
            health: 0.22
        )

        let recommendation = PlantCareActionRecommendation(plant: plant)

        #expect(recommendation.kind == .prune)
        #expect(recommendation.isActionable)
        #expect(recommendation.summary == "Prune to recover")
    }

    @Test("feed ready selected plants recommend nourishing")
    func feedReadySelectedPlantsRecommendNourishing() {
        let plant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.82),
            growth: 0.62,
            hydration: 0.72,
            health: 0.86
        )

        let recommendation = PlantCareActionRecommendation(plant: plant)

        #expect(recommendation.kind == .nourish)
        #expect(recommendation.isActionable)
        #expect(recommendation.summary == "Nourish growth")
    }

    @Test("thriving selected plants recommend enjoying")
    func thrivingSelectedPlantsRecommendEnjoying() {
        let plant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.58, y: 0.82),
            growth: 0.98,
            hydration: 0.82,
            health: 0.92,
            bloomProgress: 0.86
        )

        let recommendation = PlantCareActionRecommendation(plant: plant)

        #expect(recommendation.kind == .enjoy)
        #expect(!recommendation.isActionable)
        #expect(recommendation.summary == "Enjoy")
    }
}
