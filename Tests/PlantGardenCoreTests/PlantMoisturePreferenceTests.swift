import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant moisture preference")
struct PlantMoisturePreferenceTests {
    @Test("wet-loving foliage asks for water earlier than lavender")
    func wetLovingFoliageAsksForWaterEarlierThanLavender() {
        let fern = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.24, y: 0.76),
            hydration: 0.36
        )
        let lavender = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.76),
            hydration: 0.36
        )

        let fernMoisture = PlantMoisturePreference(plant: fern)
        let lavenderMoisture = PlantMoisturePreference(plant: lavender)

        #expect(fernMoisture.fit == .dry)
        #expect(lavenderMoisture.fit == .ideal)
        #expect(fernMoisture.healthAdjustmentPerHour < lavenderMoisture.healthAdjustmentPerHour)
        #expect(fernMoisture.shortSummary == "Wants moisture")
        #expect(lavenderMoisture.shortSummary == "Moisture steady")
    }

    @Test("dry-tolerant species dislike saturated soil earlier")
    func dryTolerantSpeciesDislikeSaturatedSoilEarlier() {
        let pine = Plant(
            species: .pineTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.72, y: 0.66),
            hydration: 0.90
        )
        let fern = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.24, y: 0.76),
            hydration: 0.90
        )

        let pineMoisture = PlantMoisturePreference(plant: pine)
        let fernMoisture = PlantMoisturePreference(plant: fern)

        #expect(pineMoisture.fit == .saturated)
        #expect(fernMoisture.fit == .damp)
        #expect(pineMoisture.waterUseMultiplier > fernMoisture.waterUseMultiplier)
        #expect(pineMoisture.shortSummary == "Too wet")
    }

    @Test("species thresholds drive care need")
    func speciesThresholdsDriveCareNeed() {
        let dryFern = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.24, y: 0.76),
            hydration: 0.36,
            health: 0.80
        )
        let dryLavender = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.76),
            hydration: 0.36,
            health: 0.80
        )

        #expect(dryFern.careNeed == .waterSoon)
        #expect(dryLavender.careNeed == .nourish)
    }

    @Test("moisture preference exposes bounded multipliers")
    func moisturePreferenceExposesBoundedMultipliers() {
        for species in PlantSpecies.allCases {
            for hydration in stride(from: 0.0, through: 1.0, by: 0.1) {
                let plant = Plant(
                    species: species,
                    screenIndex: 0,
                    position: GardenPoint(x: 0.5, y: 0.76),
                    hydration: hydration
                )
                let moisture = PlantMoisturePreference(plant: plant)

                #expect(moisture.growthMultiplier >= 0.18)
                #expect(moisture.growthMultiplier <= 1.10)
                #expect(moisture.waterUseMultiplier >= 0.88)
                #expect(moisture.waterUseMultiplier <= 1.18)
            }
        }
    }
}
