import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant water forecast")
struct PlantWaterForecastTests {
    @Test("dead plants do not ask for water")
    func deadPlantsDoNotAskForWater() {
        let plant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.8),
            hydration: 0,
            health: 0,
            diedAt: Date(timeIntervalSince1970: 100)
        )

        let forecast = PlantWaterForecast(plant: plant, ambientMoisture: 0.38)

        #expect(forecast.status == .dead)
        #expect(forecast.projectedWaterUsePerHour == 0)
        #expect(forecast.estimatedHoursUntilWaterSoon == nil)
        #expect(forecast.estimatedHoursUntilUrgent == nil)
        #expect(forecast.shortSummary == "Dead")
    }

    @Test("hydrated plants estimate hours until water is needed")
    func hydratedPlantsEstimateHoursUntilWaterNeeded() throws {
        let plant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.82),
            growth: 0.50,
            hydration: 0.72,
            health: 0.84
        )

        let forecast = PlantWaterForecast(plant: plant, ambientMoisture: 0.38)

        #expect(forecast.status == .comfortable)
        let hours = try #require(forecast.estimatedHoursUntilWaterSoon)
        #expect(hours > 15)
        #expect(hours < 17)
        #expect(forecast.shortSummary == "Water ~16h")
    }

    @Test("dry plants ask for water now")
    func dryPlantsAskForWaterNow() {
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.8),
            hydration: 0.12,
            health: 0.76
        )

        let forecast = PlantWaterForecast(plant: plant, ambientMoisture: 0.38)

        #expect(forecast.status == .urgent)
        #expect(forecast.estimatedHoursUntilWaterSoon == nil)
        #expect(forecast.shortSummary == "Water now")
    }

    @Test("saturated plants report wet soil")
    func saturatedPlantsReportWetSoil() {
        let plant = Plant(
            species: .pineTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.7, y: 0.65),
            hydration: 1,
            health: 0.82
        )

        let forecast = PlantWaterForecast(plant: plant, ambientMoisture: 0.90)

        #expect(forecast.status == .saturated)
        #expect(forecast.shortSummary == "Soil wet")
    }

    @Test("species preferences change water timing")
    func speciesPreferencesChangeWaterTiming() throws {
        let fern = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.8),
            hydration: 0.36,
            health: 0.76
        )
        let lavender = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.8),
            hydration: 0.36,
            health: 0.76
        )

        let fernForecast = PlantWaterForecast(plant: fern, ambientMoisture: 0.38)
        let lavenderForecast = PlantWaterForecast(plant: lavender, ambientMoisture: 0.38)

        #expect(fernForecast.status == .soon)
        #expect(lavenderForecast.status == .comfortable)
        let lavenderHours = try #require(lavenderForecast.estimatedHoursUntilWaterSoon)
        #expect(lavenderHours > 5)
    }
}
