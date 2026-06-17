import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant nutrient profile")
struct PlantNutrientProfileTests {
    @Test("heavy feeders become nutrient hungry while growing")
    func heavyFeedersBecomeNutrientHungryWhileGrowing() {
        let sunflower = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.76),
            growth: 0.62,
            hydration: 0.72,
            health: 0.84,
            bloomProgress: 0.30
        )

        let nutrients = PlantNutrientProfile(plant: sunflower, at: date(days: 30))

        #expect(nutrients.fit == .hungry)
        #expect(nutrients.growthMultiplier < 1)
        #expect(nutrients.bloomMultiplier < 1)
        #expect(nutrients.shortSummary == "Hungry")
    }

    @Test("light feeders stay balanced longer")
    func lightFeedersStayBalancedLonger() {
        let lavender = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.76),
            growth: 0.62,
            hydration: 0.72,
            health: 0.84,
            bloomProgress: 0.30
        )

        let nutrients = PlantNutrientProfile(plant: lavender, at: date(days: 30))

        #expect(nutrients.fit == .balanced)
        #expect(nutrients.growthMultiplier >= 1)
        #expect(nutrients.shortSummary == "Fed")
    }

    @Test("recent nourishment enriches soil and suppresses feeding care")
    func recentNourishmentEnrichesSoilAndSuppressesFeedingCare() {
        let now = Date()
        let plant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.76),
            growth: 0.62,
            hydration: 0.72,
            health: 0.84,
            lastNourishedAt: now.addingTimeInterval(-6 * 3_600)
        )

        let nutrients = PlantNutrientProfile(plant: plant, at: now)

        #expect(nutrients.fit == .rich)
        #expect(nutrients.growthMultiplier > 1)
        #expect(plant.careNeed == .thriving)
    }

    @Test("nourishing records last nourished date")
    func nourishingRecordsLastNourishedDate() throws {
        let now = date(days: 30)
        let plant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.76),
            growth: 0.58,
            hydration: 0.72,
            health: 0.84
        )
        let state = GardenState(lastUpdatedAt: now, plants: [plant])

        let nourished = GardenEngine.nourishPlant(state, id: plant.id, at: now)
        let nourishedPlant = try #require(nourished.plants.first)

        #expect(nourishedPlant.lastNourishedAt == now)
        #expect(nourishedPlant.lastTendedAt == now)
    }

    private func date(days: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(days * 86_400))
    }
}
