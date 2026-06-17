import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden game loop insights")
struct GardenGameLoopInsightsTests {
    @Test("harvest insight summarizes ready crops and expected seed yield")
    func harvestInsightSummarizesReadyCrops() {
        let state = GardenState(
            plants: [
                Plant(species: .determinateTomato, screenIndex: 0, position: GardenPoint(x: 0.30, y: 0.72), growth: 0.92),
                Plant(species: .sweetPepper, screenIndex: 0, position: GardenPoint(x: 0.44, y: 0.73), growth: 0.90),
                Plant(species: .rose, screenIndex: 0, position: GardenPoint(x: 0.60, y: 0.74), growth: 0.96)
            ],
            harvestTally: [PlantSpecies.rosemary.rawValue: 3]
        )

        let insight = GardenGameLoopInsights(state: state, sceneKey: "cottage-backyard-garden")

        #expect(insight.harvest.readyCropCount == 2)
        #expect(insight.harvest.readyVarietyCount == 2)
        #expect(insight.harvest.expectedSeedYield == 4)
        #expect(insight.harvest.menuTitle == "Harvest 2 Ready Crops")
        #expect(insight.harvest.summary.contains("2 crops ready"))
    }

    @Test("seed insight recommends suitable new varieties before duplicates")
    func seedInsightRecommendsSuitableNewVarieties() throws {
        var state = GardenState(plants: [
            Plant(species: .rose, screenIndex: 0, position: GardenPoint(x: 0.52, y: 0.74))
        ])
        state.seedInventory = [
            PlantSpecies.rose.rawValue: 5,
            PlantSpecies.sunflower.rawValue: 1,
            PlantSpecies.waterLily.rawValue: 9
        ]

        let insight = GardenGameLoopInsights(state: state, sceneKey: "cottage-backyard-garden")
        let suggestion = try #require(insight.seeds.suggestion)

        #expect(suggestion.species == .sunflower)
        #expect(suggestion.reason.contains("new variety"))
        #expect(insight.seeds.totalSeeds == 15)
        #expect(insight.seeds.plantableSpeciesCount == 2)
    }

    @Test("focus insight reports active sessions and next lifetime milestone")
    func focusInsightReportsActiveSessionsAndNextMilestone() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        var state = GardenState(
            lastUpdatedAt: start,
            plants: [
                Plant(species: .fern, screenIndex: 0, position: GardenPoint(x: 0.5, y: 0.76))
            ],
            focusStats: GardenFocusStats(completedSessions: 2, totalFocusSeconds: 75 * 60)
        )
        state = GardenEngine.startFocusSession(state, duration: 25 * 60, at: start)

        let insight = GardenGameLoopInsights(
            state: state,
            sceneKey: "rooftop-seed-house",
            date: start.addingTimeInterval(5 * 60)
        )

        #expect(insight.focus.isActive)
        #expect(insight.focus.statusSummary.contains("20:00"))
        #expect(insight.focus.nextMilestoneMinutes == 100)
        #expect(insight.focus.minutesUntilNextMilestone == 25)
    }

    @Test("arrangement strategy describes scene-aware placement")
    func arrangementStrategyDescribesSceneAwarePlacement() {
        let cottage = GardenGameLoopInsights(
            state: GardenState(plants: []),
            sceneKey: "cottage-backyard-garden"
        )
        let water = GardenGameLoopInsights(
            state: GardenState(plants: []),
            sceneKey: "empty-water-pavilion"
        )
        let monk = GardenGameLoopInsights(
            state: GardenState(plants: []),
            sceneKey: "chinese-mountain-monk-garden"
        )
        let egyptian = GardenGameLoopInsights(
            state: GardenState(plants: []),
            sceneKey: "ancient-egyptian-estate-garden"
        )
        let texas = GardenGameLoopInsights(
            state: GardenState(plants: []),
            sceneKey: "texas-rustic-garden"
        )

        #expect(cottage.arrangement.strategyTitle == "Raised-bed rows")
        #expect(cottage.arrangement.summary.lowercased().contains("edibles"))
        #expect(water.arrangement.strategyTitle == "Waterline planting")
        #expect(monk.arrangement.strategyTitle == "Mountain courtyard")
        #expect(egyptian.arrangement.strategyTitle == "Estate pool beds")
        #expect(texas.arrangement.strategyTitle == "Rustic homestead rows")
    }
}
