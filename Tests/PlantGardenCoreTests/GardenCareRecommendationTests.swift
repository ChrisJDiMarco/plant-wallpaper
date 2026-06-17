import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden care recommendation")
struct GardenCareRecommendationTests {
    @Test("empty gardens recommend planting first")
    func emptyGardensRecommendPlantingFirst() {
        let state = GardenState(plants: [])
        let recommendation = GardenCareRecommendation(state: state)

        #expect(recommendation.kind == .plantFirst)
        #expect(recommendation.targetPlantID == nil)
        #expect(recommendation.summary == "Plant something")
        #expect(recommendation.isActionable)
    }

    @Test("dead plants are recommended for cleanup before watering")
    func deadPlantsAreRecommendedForCleanupBeforeWatering() {
        let deadRose = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.8),
            hydration: 0,
            health: 0,
            diedAt: Date(timeIntervalSince1970: 100)
        )
        let dryFern = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.82),
            hydration: 0.12,
            health: 0.86
        )
        let state = GardenState(plants: [dryFern, deadRose])
        let recommendation = GardenCareRecommendation(state: state)

        #expect(recommendation.kind == .removeDead)
        #expect(recommendation.targetPlantID == deadRose.id)
        #expect(recommendation.summary == "Remove \(deadRose.nickname)")
        #expect(recommendation.detail == "Clear dead plant")
    }

    @Test("thirsty plants are the top recommendation")
    func thirstyPlantsAreTopRecommendation() {
        let dryFern = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.8),
            hydration: 0.12,
            health: 0.86
        )
        let dryTulip = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.82),
            hydration: 0.28,
            health: 0.84
        )
        let state = GardenState(plants: [dryFern, dryTulip])
        let recommendation = GardenCareRecommendation(state: state)

        #expect(recommendation.kind == .waterThirsty)
        #expect(recommendation.targetPlantID == nil)
        #expect(recommendation.summary == "Water 2 thirsty plants")
    }

    @Test("recovering plants are recommended before feeding")
    func recoveringPlantsAreRecommendedBeforeFeeding() throws {
        let recoveringMaple = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.3, y: 0.62),
            hydration: 0.72,
            health: 0.18
        )
        let feedReadyTulip = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.82),
            growth: 0.54,
            hydration: 0.72,
            health: 0.84
        )
        let state = GardenState(plants: [feedReadyTulip, recoveringMaple])
        let recommendation = GardenCareRecommendation(state: state)

        #expect(recommendation.kind == .prune)
        #expect(recommendation.targetPlantID == recoveringMaple.id)
        #expect(recommendation.summary == "Prune \(recoveringMaple.nickname)")
        #expect(recommendation.detail == "Help it recover")
    }

    @Test("trained ivy clusters are not recommended for destructive cleanup")
    func trainedIvyClustersAreNotRecommendedForDestructiveCleanup() {
        let deadIvy = Plant(
            species: .ivy,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.36),
            growth: 0.82,
            hydration: 0,
            health: 0,
            diedAt: Date(timeIntervalSince1970: 100)
        )
        let neighborA = Plant(
            species: .ivy,
            screenIndex: 0,
            position: GardenPoint(x: 0.56, y: 0.41),
            growth: 0.84,
            hydration: 0.72,
            health: 0.82
        )
        let neighborB = Plant(
            species: .ivy,
            screenIndex: 0,
            position: GardenPoint(x: 0.44, y: 0.43),
            growth: 0.84,
            hydration: 0.72,
            health: 0.82
        )
        let state = GardenState(plants: [deadIvy, neighborA, neighborB])

        let recommendation = GardenCareRecommendation(state: state)

        #expect(recommendation.kind != .removeDead)
        #expect(recommendation.targetPlantID != deadIvy.id)
    }

    @Test("recovering ivy trained on a structure is not treated like accidental overgrowth")
    func recoveringIvyTrainedOnStructureIsNotTreatedLikeAccidentalOvergrowth() {
        let recoveringIvy = Plant(
            species: .ivy,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.36),
            growth: 0.82,
            hydration: 0.72,
            health: 0.18
        )
        let neighborA = Plant(
            species: .ivy,
            screenIndex: 0,
            position: GardenPoint(x: 0.56, y: 0.41),
            growth: 0.84,
            hydration: 0.72,
            health: 0.82
        )
        let neighborB = Plant(
            species: .ivy,
            screenIndex: 0,
            position: GardenPoint(x: 0.44, y: 0.43),
            growth: 0.84,
            hydration: 0.72,
            health: 0.82
        )
        let state = GardenState(plants: [recoveringIvy, neighborA, neighborB])

        let recommendation = GardenCareRecommendation(state: state)

        #expect(recommendation.kind != .prune)
        #expect(recommendation.targetPlantID != recoveringIvy.id)
    }

    @Test("healthy growing plants recommend nourishing")
    func healthyGrowingPlantsRecommendNourishing() {
        let tulip = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.82),
            growth: 0.54,
            hydration: 0.72,
            health: 0.84
        )
        let state = GardenState(plants: [tulip])
        let recommendation = GardenCareRecommendation(state: state)

        #expect(recommendation.kind == .nourish)
        #expect(recommendation.targetPlantID == tulip.id)
        #expect(recommendation.summary == "Nourish \(tulip.nickname)")
        #expect(recommendation.detail == "Push toward next stage")
    }

    @Test("thriving gardens recommend enjoying")
    func thrivingGardensRecommendEnjoying() {
        let sunflower = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.82),
            growth: 0.98,
            hydration: 0.82,
            health: 0.90,
            bloomProgress: 0.82
        )
        let state = GardenState(plants: [sunflower])
        let recommendation = GardenCareRecommendation(state: state)

        #expect(recommendation.kind == .enjoy)
        #expect(recommendation.summary == "Enjoy the garden")
        #expect(!recommendation.isActionable)
    }
}
