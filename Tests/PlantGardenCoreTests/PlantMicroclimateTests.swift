import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant microclimate")
struct PlantMicroclimateTests {
    @Test("plants near the center window get bright exposure")
    func plantsNearCenterWindowGetBrightExposure() {
        let state = GardenState(ambientMoisture: 0.38)
        let plant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.58),
            hydration: 0.74,
            health: 0.82
        )

        let microclimate = PlantMicroclimate(
            plant: plant,
            state: state,
            at: date(month: 7, hour: 13),
            calendar: utcCalendar
        )

        #expect(microclimate.exposure == .brightWindow)
        #expect(microclimate.lightFactor > 1.0)
        #expect(microclimate.growthFactor > 1.0)
        #expect(microclimate.shortSummary == "Bright window")
    }

    @Test("front edge plantings get cool shade and retain moisture")
    func frontEdgePlantingsGetCoolShadeAndRetainMoisture() {
        let state = GardenState(ambientMoisture: 0.44)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.08, y: 0.90),
            hydration: 0.74,
            health: 0.82
        )

        let microclimate = PlantMicroclimate(
            plant: plant,
            state: state,
            at: date(month: 7, hour: 13),
            calendar: utcCalendar
        )

        #expect(microclimate.exposure == .coolShade)
        #expect(microclimate.moistureRetention > 1.0)
        #expect(microclimate.waterUseFactor < 1.0)
        #expect(microclimate.shortSummary == "Cool shade")
    }

    @Test("winter reduces growth energy for the same placement")
    func winterReducesGrowthEnergyForSamePlacement() {
        let state = GardenState(ambientMoisture: 0.38)
        let plant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.62),
            hydration: 0.74,
            health: 0.82
        )

        let summer = PlantMicroclimate(
            plant: plant,
            state: state,
            at: date(month: 7, hour: 13),
            calendar: utcCalendar
        )
        let winter = PlantMicroclimate(
            plant: plant,
            state: state,
            at: date(month: 1, hour: 13),
            calendar: utcCalendar
        )

        #expect(winter.growthFactor < summer.growthFactor)
        #expect(winter.summary == "Bright window light, ideal light, winter rest")
    }

    @Test("sun lovers prefer bright window light")
    func sunLoversPreferBrightWindowLight() {
        let state = GardenState(ambientMoisture: 0.38)
        let plant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.58),
            hydration: 0.74,
            health: 0.82
        )

        let microclimate = PlantMicroclimate(
            plant: plant,
            state: state,
            at: date(month: 7, hour: 13),
            calendar: utcCalendar
        )

        #expect(microclimate.lightFit == .ideal)
        #expect(microclimate.healthAdjustmentPerHour > 0)
        #expect(microclimate.fitSummary == "Ideal light")
    }

    @Test("sun lovers are strained in cool shade")
    func sunLoversAreStrainedInCoolShade() {
        let state = GardenState(ambientMoisture: 0.38)
        let plant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.08, y: 0.90),
            hydration: 0.74,
            health: 0.82
        )

        let microclimate = PlantMicroclimate(
            plant: plant,
            state: state,
            at: date(month: 7, hour: 13),
            calendar: utcCalendar
        )

        #expect(microclimate.lightFit == .strained)
        #expect(microclimate.healthAdjustmentPerHour < 0)
        #expect(microclimate.fitSummary == "Wants brighter light")
    }

    @Test("shade lovers are strained in bright window light")
    func shadeLoversAreStrainedInBrightWindowLight() {
        let state = GardenState(ambientMoisture: 0.38)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.58),
            hydration: 0.74,
            health: 0.82
        )

        let microclimate = PlantMicroclimate(
            plant: plant,
            state: state,
            at: date(month: 7, hour: 13),
            calendar: utcCalendar
        )

        #expect(microclimate.lightFit == .strained)
        #expect(microclimate.healthAdjustmentPerHour < 0)
        #expect(microclimate.fitSummary == "Wants gentler light")
    }

    private func date(month: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = utcCalendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = month
        components.day = 15
        components.hour = hour
        return components.date!
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
