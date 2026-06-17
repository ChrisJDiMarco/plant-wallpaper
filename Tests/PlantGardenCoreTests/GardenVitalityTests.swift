import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden vitality")
struct GardenVitalityTests {
    @Test("empty gardens are dormant")
    func emptyGardensAreDormant() {
        let state = GardenState(plants: [])
        let vitality = GardenVitality(state: state, at: Date(timeIntervalSince1970: 1_000))

        #expect(vitality.mood == .dormant)
        #expect(vitality.score == 0)
        #expect(vitality.summary == "No plants yet")
    }

    @Test("thirsty gardens surface water need")
    func thirstyGardensSurfaceWaterNeed() {
        let plants = [
            Plant(species: .fern, screenIndex: 0, position: GardenPoint(x: 0.2, y: 0.8), hydration: 0.12, health: 0.86),
            Plant(species: .sunflower, screenIndex: 0, position: GardenPoint(x: 0.6, y: 0.82), growth: 0.72, hydration: 0.72, health: 0.84)
        ]
        let state = GardenState(plants: plants)
        let vitality = GardenVitality(state: state, at: Date(timeIntervalSince1970: 1_200))

        #expect(vitality.mood == .thirsty)
        #expect(vitality.thirstyCount == 1)
        #expect(vitality.needsCareCount == 1)
        #expect(vitality.summary == "1 thirsty")
        #expect(vitality.score < 0.80)
    }

    @Test("dead plants surface dead vitality")
    func deadPlantsSurfaceDeadVitality() {
        let plants = [
            Plant(
                species: .rose,
                screenIndex: 0,
                position: GardenPoint(x: 0.2, y: 0.8),
                hydration: 0,
                health: 0,
                diedAt: Date(timeIntervalSince1970: 100)
            ),
            Plant(species: .sunflower, screenIndex: 0, position: GardenPoint(x: 0.6, y: 0.82), growth: 0.72, hydration: 0.72, health: 0.84)
        ]
        let state = GardenState(plants: plants)
        let vitality = GardenVitality(state: state, at: Date(timeIntervalSince1970: 1_260))

        #expect(vitality.mood == .dead)
        #expect(vitality.deadCount == 1)
        #expect(vitality.needsCareCount == 1)
        #expect(vitality.summary == "1 dead")
    }

    @Test("healthy gardens with recent growth milestones flourish")
    func healthyGardensWithRecentGrowthMilestonesFlourish() {
        let now = Date(timeIntervalSince1970: 1_400)
        let plants = [
            Plant(
                species: .tulip,
                screenIndex: 0,
                position: GardenPoint(x: 0.48, y: 0.82),
                growth: 0.82,
                hydration: 0.84,
                health: 0.90,
                bloomProgress: 0.72,
                lastStageChangedAt: now
            ),
            Plant(
                species: .mapleTree,
                screenIndex: 0,
                position: GardenPoint(x: 0.28, y: 0.62),
                growth: 0.88,
                hydration: 0.78,
                health: 0.92,
                bloomProgress: 0.38
            )
        ]
        let state = GardenState(plants: plants)
        let vitality = GardenVitality(state: state, at: now)

        #expect(vitality.mood == .flourishing)
        #expect(vitality.recentMilestoneCount == 1)
        #expect(vitality.score > 0.85)
        #expect(vitality.summary == "Garden flourishing")
    }
}
