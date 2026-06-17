import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden dew condition")
struct GardenDewConditionTests {
    @Test("moist morning gardens show morning dew")
    func moistMorningGardensShowMorningDew() {
        let state = GardenState(ambientMoisture: 0.70)
        let calendar = utcCalendar
        let date = date(hour: 7)
        let dew = GardenDewCondition(state: state, at: date, calendar: calendar)

        #expect(dew.mood == .morningDew)
        #expect(dew.isVisible)
        #expect(dew.intensity > 0.45)
        #expect(dew.summary == "Morning dew")
    }

    @Test("dry midday gardens have no dew")
    func dryMiddayGardensHaveNoDew() {
        let state = GardenState(ambientMoisture: 0.22)
        let calendar = utcCalendar
        let date = date(hour: 13)
        let dew = GardenDewCondition(state: state, at: date, calendar: calendar)

        #expect(dew.mood == .none)
        #expect(!dew.isVisible)
        #expect(dew.intensity == 0)
        #expect(dew.summary == "No dew")
    }

    @Test("very moist gardens show fresh watering outside morning")
    func veryMoistGardensShowFreshWateringOutsideMorning() {
        let state = GardenState(ambientMoisture: 0.92)
        let calendar = utcCalendar
        let date = date(hour: 14)
        let dew = GardenDewCondition(state: state, at: date, calendar: calendar)

        #expect(dew.mood == .freshlyWatered)
        #expect(dew.isVisible)
        #expect(dew.intensity > 0.50)
        #expect(dew.summary == "Fresh moisture")
    }

    private func date(hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = utcCalendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 6
        components.day = 6
        components.hour = hour
        return components.date!
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
