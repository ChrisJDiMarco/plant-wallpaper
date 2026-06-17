import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant companion effect")
struct PlantCompanionEffectTests {
    @Test("foliage near trees gets sheltered")
    func foliageNearTreesGetsSheltered() {
        let fern = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.25, y: 0.76)
        )
        let tree = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.22, y: 0.64)
        )
        let state = GardenState(plants: [fern, tree])

        let effect = PlantCompanionEffect(plant: fern, state: state)

        #expect(effect.relationship == .shelteredUnderstory)
        #expect(effect.waterUseMultiplier < 1)
        #expect(effect.healthAdjustmentPerHour > 0)
        #expect(effect.shortSummary == "Sheltered")
    }

    @Test("flowers and meadows create bloom support")
    func flowersAndMeadowsCreateBloomSupport() {
        let sunflower = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.77)
        )
        let meadow = Plant(
            species: .wildflowerMeadow,
            screenIndex: 0,
            position: GardenPoint(x: 0.49, y: 0.80)
        )
        let lavender = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.56, y: 0.78)
        )
        let state = GardenState(plants: [sunflower, meadow, lavender])

        let effect = PlantCompanionEffect(plant: sunflower, state: state)

        #expect(effect.relationship == .companionBloom)
        #expect(effect.bloomMultiplier > 1.10)
        #expect(effect.growthMultiplier > 1)
        #expect(effect.shortSummary == "Companion bloom")
    }

    @Test("crowded same-kind plants get a gentle penalty")
    func crowdedSameKindPlantsGetPenalty() {
        let pine = Plant(
            species: .pineTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.72, y: 0.66)
        )
        let neighborA = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.76, y: 0.66)
        )
        let neighborB = Plant(
            species: .cherryTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.69, y: 0.67)
        )
        let state = GardenState(plants: [pine, neighborA, neighborB])

        let effect = PlantCompanionEffect(plant: pine, state: state)

        #expect(effect.relationship == .crowded)
        #expect(effect.growthMultiplier < 1)
        #expect(effect.healthAdjustmentPerHour < 0)
        #expect(effect.shortSummary == "Crowded")
    }

    @Test("dense climbers trained on a support are not treated as crowded")
    func denseClimbersTrainedOnSupportAreNotCrowded() {
        let ivy = Plant(
            species: .ivy,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.45)
        )
        let neighborA = Plant(
            species: .ivy,
            screenIndex: 0,
            position: GardenPoint(x: 0.55, y: 0.40)
        )
        let neighborB = Plant(
            species: .ivy,
            screenIndex: 0,
            position: GardenPoint(x: 0.45, y: 0.50)
        )
        let state = GardenState(plants: [ivy, neighborA, neighborB])

        let effect = PlantCompanionEffect(plant: ivy, state: state)

        #expect(effect.relationship == .trainedClimber)
        #expect(effect.healthAdjustmentPerHour > 0)
        #expect(effect.growthMultiplier > 1)
        #expect(effect.shortSummary == "On support")
    }

    @Test("naturalized groundcovers can form dense patches")
    func naturalizedGroundcoversCanFormDensePatches() {
        let moss = Plant(
            species: .mossCarpet,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.79)
        )
        let neighborA = Plant(
            species: .mossCarpet,
            screenIndex: 0,
            position: GardenPoint(x: 0.54, y: 0.80)
        )
        let neighborB = Plant(
            species: .mossCarpet,
            screenIndex: 0,
            position: GardenPoint(x: 0.46, y: 0.80)
        )
        let state = GardenState(plants: [moss, neighborA, neighborB])

        let effect = PlantCompanionEffect(plant: moss, state: state)

        #expect(effect.relationship == .naturalizedPatch)
        #expect(effect.healthAdjustmentPerHour > 0)
        #expect(effect.shortSummary == "Naturalized")
    }

    @Test("isolated plants stay neutral")
    func isolatedPlantsStayNeutral() {
        let plant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.18, y: 0.84)
        )
        let distantTree = Plant(
            species: .pineTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.82, y: 0.62)
        )
        let state = GardenState(plants: [plant, distantTree])

        let effect = PlantCompanionEffect(plant: plant, state: state)

        #expect(effect.relationship == .neutral)
        #expect(effect.growthMultiplier == 1)
        #expect(effect.waterUseMultiplier == 1)
        #expect(effect.bloomMultiplier == 1)
        #expect(effect.healthAdjustmentPerHour == 0)
        #expect(effect.shortSummary == "Room to grow")
    }
}
