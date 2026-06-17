import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden sunlight condition")
struct GardenSunlightConditionTests {
    @Test("morning light is soft and warm")
    func morningLightIsSoftAndWarm() {
        let sunlight = GardenSunlightCondition(at: date(hour: 7), calendar: utcCalendar)

        #expect(sunlight.mood == .morning)
        #expect(sunlight.intensity > 0.40)
        #expect(sunlight.intensity < 0.70)
        #expect(sunlight.summary == "Morning light")
    }

    @Test("midday light is bright")
    func middayLightIsBright() {
        let sunlight = GardenSunlightCondition(at: date(hour: 13), calendar: utcCalendar)

        #expect(sunlight.mood == .bright)
        #expect(sunlight.intensity > 0.80)
        #expect(sunlight.summary == "Bright light")
    }

    @Test("evening light is golden")
    func eveningLightIsGolden() {
        let sunlight = GardenSunlightCondition(at: date(hour: 18), calendar: utcCalendar)

        #expect(sunlight.mood == .golden)
        #expect(sunlight.intensity > 0.50)
        #expect(sunlight.summary == "Golden light")
    }

    @Test("night light is dim")
    func nightLightIsDim() {
        let sunlight = GardenSunlightCondition(at: date(hour: 23), calendar: utcCalendar)

        #expect(sunlight.mood == .night)
        #expect(sunlight.intensity < 0.20)
        #expect(sunlight.summary == "Night rest")
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
