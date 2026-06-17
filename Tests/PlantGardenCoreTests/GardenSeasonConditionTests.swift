import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden season condition")
struct GardenSeasonConditionTests {
    @Test("spring months report renewal")
    func springMonthsReportRenewal() {
        let season = GardenSeasonCondition(at: date(month: 4), calendar: utcCalendar)

        #expect(season.mood == .spring)
        #expect(season.growthEnergy > 0.70)
        #expect(season.summary == "Spring renewal")
    }

    @Test("summer months report canopy")
    func summerMonthsReportCanopy() {
        let season = GardenSeasonCondition(at: date(month: 7), calendar: utcCalendar)

        #expect(season.mood == .summer)
        #expect(season.growthEnergy > 0.85)
        #expect(season.summary == "Summer canopy")
    }

    @Test("autumn months report color")
    func autumnMonthsReportColor() {
        let season = GardenSeasonCondition(at: date(month: 10), calendar: utcCalendar)

        #expect(season.mood == .autumn)
        #expect(season.growthEnergy < 0.60)
        #expect(season.summary == "Autumn color")
    }

    @Test("winter months report rest")
    func winterMonthsReportRest() {
        let season = GardenSeasonCondition(at: date(month: 1), calendar: utcCalendar)

        #expect(season.mood == .winter)
        #expect(season.growthEnergy < 0.30)
        #expect(season.summary == "Winter rest")
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
