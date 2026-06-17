import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant phenology")
struct PlantPhenologyTests {
    @Test("cherry trees prefer spring blossom")
    func cherryTreesPreferSpringBlossom() {
        let plant = Plant(
            species: .cherryTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.35, y: 0.64),
            growth: 0.84,
            hydration: 0.76,
            health: 0.88
        )

        let spring = PlantPhenology(plant: plant, season: GardenSeasonCondition(at: date(month: 4), calendar: utcCalendar))
        let winter = PlantPhenology(plant: plant, season: GardenSeasonCondition(at: date(month: 1), calendar: utcCalendar))

        #expect(spring.phase == .springBloom)
        #expect(spring.bloomMultiplier > winter.bloomMultiplier)
        #expect(spring.summary == "Spring blossom")
    }

    @Test("sunflowers prefer summer bloom")
    func sunflowersPreferSummerBloom() {
        let plant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.58, y: 0.82),
            growth: 0.82,
            hydration: 0.78,
            health: 0.90
        )

        let summer = PlantPhenology(plant: plant, season: GardenSeasonCondition(at: date(month: 7), calendar: utcCalendar))
        let winter = PlantPhenology(plant: plant, season: GardenSeasonCondition(at: date(month: 1), calendar: utcCalendar))

        #expect(summer.phase == .summerBloom)
        #expect(summer.bloomMultiplier > 1)
        #expect(winter.bloomFadePerHour > summer.bloomFadePerHour)
        #expect(summer.summary == "Summer bloom")
    }

    @Test("maples show autumn color instead of flower bloom")
    func maplesShowAutumnColorInsteadOfFlowerBloom() {
        let plant = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.42, y: 0.66),
            growth: 0.86,
            hydration: 0.72,
            health: 0.86
        )

        let autumn = PlantPhenology(plant: plant, season: GardenSeasonCondition(at: date(month: 10), calendar: utcCalendar))

        #expect(autumn.phase == .autumnColor)
        #expect(autumn.bloomMultiplier < 0.5)
        #expect(autumn.summary == "Autumn color")
    }

    @Test("pine trees stay evergreen in winter")
    func pineTreesStayEvergreenInWinter() {
        let pine = Plant(
            species: .pineTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.58, y: 0.66),
            growth: 0.86,
            hydration: 0.74,
            health: 0.86
        )
        let maple = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.42, y: 0.66),
            growth: 0.86,
            hydration: 0.74,
            health: 0.86
        )
        let winter = GardenSeasonCondition(at: date(month: 1), calendar: utcCalendar)

        let pinePhenology = PlantPhenology(plant: pine, season: winter)
        let maplePhenology = PlantPhenology(plant: maple, season: winter)

        #expect(pinePhenology.phase == .evergreen)
        #expect(pinePhenology.bloomFadePerHour < maplePhenology.bloomFadePerHour)
        #expect(pinePhenology.summary == "Evergreen steady")
    }

    private func date(month: Int) -> Date {
        var components = DateComponents()
        components.calendar = utcCalendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = month
        components.day = 15
        components.hour = 12
        return components.date!
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
