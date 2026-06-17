import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant growth milestone cue")
struct PlantGrowthMilestoneTests {
    @Test("recent stage changes expose a fading milestone intensity")
    func recentStageChangesExposeFadingIntensity() {
        let milestoneDate = Date(timeIntervalSince1970: 10_000)
        let plant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.82),
            lastStageChangedAt: milestoneDate
        )

        #expect(plant.growthMilestoneIntensity(at: milestoneDate, duration: 60) == 1)
        #expect(abs(plant.growthMilestoneIntensity(at: milestoneDate.addingTimeInterval(30), duration: 60) - 0.5) < 0.001)
        #expect(plant.growthMilestoneIntensity(at: milestoneDate.addingTimeInterval(90), duration: 60) == 0)
    }

    @Test("plants without stage changes have no milestone cue")
    func plantsWithoutStageChangesHaveNoMilestoneCue() {
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.8)
        )

        #expect(plant.growthMilestoneIntensity(at: Date(timeIntervalSince1970: 12_000)) == 0)
    }
}
