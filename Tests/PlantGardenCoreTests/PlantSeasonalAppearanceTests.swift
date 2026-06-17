import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant seasonal appearance")
struct PlantSeasonalAppearanceTests {
    @Test("spring gives healthy plants fresh growth lift")
    func springGivesHealthyPlantsFreshGrowthLift() {
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.32, y: 0.82),
            growth: 0.58,
            hydration: 0.80,
            health: 0.88
        )

        let spring = PlantSeasonalAppearance(plant: plant, season: GardenSeasonCondition(at: date(month: 4), calendar: utcCalendar))
        let winter = PlantSeasonalAppearance(plant: plant, season: GardenSeasonCondition(at: date(month: 1), calendar: utcCalendar))

        #expect(spring.mood == .springFlush)
        #expect(spring.freshGrowthTintAlpha > winter.freshGrowthTintAlpha)
        #expect(spring.summary == "Spring flush")
    }

    @Test("autumn warms broadleaf trees more than summer")
    func autumnWarmsBroadleafTreesMoreThanSummer() {
        let plant = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.42, y: 0.66),
            growth: 0.86,
            hydration: 0.72,
            health: 0.84,
            bloomProgress: 0.22
        )

        let autumn = PlantSeasonalAppearance(plant: plant, season: GardenSeasonCondition(at: date(month: 10), calendar: utcCalendar))
        let summer = PlantSeasonalAppearance(plant: plant, season: GardenSeasonCondition(at: date(month: 7), calendar: utcCalendar))

        #expect(autumn.mood == .autumnColor)
        #expect(autumn.warmTintAlpha > summer.warmTintAlpha)
        #expect(autumn.assetOpacityMultiplier < summer.assetOpacityMultiplier)
        #expect(autumn.summary == "Autumn color")
    }

    @Test("evergreens resist autumn color")
    func evergreensResistAutumnColor() {
        let maple = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.42, y: 0.66),
            growth: 0.86,
            hydration: 0.72,
            health: 0.84
        )
        let pine = Plant(
            species: .pineTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.62, y: 0.66),
            growth: 0.86,
            hydration: 0.72,
            health: 0.84
        )
        let autumn = GardenSeasonCondition(at: date(month: 10), calendar: utcCalendar)

        let mapleAppearance = PlantSeasonalAppearance(plant: maple, season: autumn)
        let pineAppearance = PlantSeasonalAppearance(plant: pine, season: autumn)

        #expect(mapleAppearance.warmTintAlpha > pineAppearance.warmTintAlpha)
        #expect(pineAppearance.assetOpacityMultiplier >= mapleAppearance.assetOpacityMultiplier)
    }

    @Test("winter rests plants with cool tint and lower opacity")
    func winterRestsPlantsWithCoolTintAndLowerOpacity() {
        let plant = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.84),
            growth: 0.72,
            hydration: 0.70,
            health: 0.82
        )

        let winter = PlantSeasonalAppearance(plant: plant, season: GardenSeasonCondition(at: date(month: 1), calendar: utcCalendar))
        let summer = PlantSeasonalAppearance(plant: plant, season: GardenSeasonCondition(at: date(month: 7), calendar: utcCalendar))

        #expect(winter.mood == .winterRest)
        #expect(winter.coolTintAlpha > summer.coolTintAlpha)
        #expect(winter.assetOpacityMultiplier < summer.assetOpacityMultiplier)
        #expect(winter.summary == "Winter rest")
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
