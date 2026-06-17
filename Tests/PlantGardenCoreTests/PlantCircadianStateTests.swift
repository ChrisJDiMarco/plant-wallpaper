import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant circadian state")
struct PlantCircadianStateTests {
    @Test("flowers rest and close at night")
    func flowersRestAndCloseAtNight() {
        let plant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.76),
            growth: 0.82,
            hydration: 0.76,
            health: 0.86,
            bloomProgress: 0.72
        )
        let sunlight = GardenSunlightCondition(at: date(hour: 1), calendar: calendar)

        let state = PlantCircadianState(plant: plant, sunlight: sunlight)

        #expect(state.phase == .nightRest)
        #expect(state.growthMultiplier < 0.60)
        #expect(state.waterUseMultiplier < 0.85)
        #expect(state.bloomVisibilityMultiplier < 0.75)
        #expect(state.shortSummary == "Night rest")
    }

    @Test("bright daylight drives photosynthesis")
    func brightDaylightDrivesPhotosynthesis() {
        let plant = Plant(
            species: .monstera,
            screenIndex: 0,
            position: GardenPoint(x: 0.38, y: 0.74),
            growth: 0.58,
            hydration: 0.76,
            health: 0.86
        )
        let sunlight = GardenSunlightCondition(at: date(hour: 13), calendar: calendar)

        let state = PlantCircadianState(plant: plant, sunlight: sunlight)

        #expect(state.phase == .photosynthesizing)
        #expect(state.growthMultiplier > 1.05)
        #expect(state.waterUseMultiplier > 1.0)
        #expect(state.shortSummary == "Photosynthesis")
    }

    @Test("golden light favors visible flower bloom")
    func goldenLightFavorsVisibleFlowerBloom() {
        let plant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.76),
            growth: 0.82,
            hydration: 0.76,
            health: 0.86,
            bloomProgress: 0.72
        )
        let bright = PlantCircadianState(
            plant: plant,
            sunlight: GardenSunlightCondition(at: date(hour: 13), calendar: calendar)
        )
        let golden = PlantCircadianState(
            plant: plant,
            sunlight: GardenSunlightCondition(at: date(hour: 18), calendar: calendar)
        )

        #expect(golden.phase == .goldenBloom)
        #expect(golden.bloomMultiplier > bright.bloomMultiplier)
        #expect(golden.bloomVisibilityMultiplier > bright.bloomVisibilityMultiplier)
        #expect(golden.shortSummary == "Golden bloom")
    }

    @Test("morning gives gentle recovery")
    func morningGivesGentleRecovery() {
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.28, y: 0.78),
            hydration: 0.76,
            health: 0.62
        )
        let sunlight = GardenSunlightCondition(at: date(hour: 7), calendar: calendar)

        let state = PlantCircadianState(plant: plant, sunlight: sunlight)

        #expect(state.phase == .morningRecovery)
        #expect(state.healthAdjustmentPerHour > 0)
        #expect(state.shortSummary == "Morning recovery")
    }

    private func date(hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 6
        components.day = 6
        components.hour = hour
        return components.date!
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
