import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden light projection")
struct GardenLightProjectionTests {
    @Test("bright midday casts compact strong shadows")
    func brightMiddayCastsCompactStrongShadows() {
        let projection = GardenLightProjection(
            sunlight: GardenSunlightCondition(at: date(hour: 13), calendar: utcCalendar)
        )

        #expect(abs(projection.shadowOffsetX) < 0.04)
        #expect(projection.shadowLengthMultiplier < 1.05)
        #expect(projection.shadowOpacityMultiplier > 1.0)
        #expect(projection.rimLightAlpha > 0.06)
    }

    @Test("morning light casts longer shadows to the right")
    func morningLightCastsLongerShadowsToTheRight() {
        let projection = GardenLightProjection(
            sunlight: GardenSunlightCondition(at: date(hour: 7), calendar: utcCalendar)
        )

        #expect(projection.shadowOffsetX > 0.10)
        #expect(projection.shadowLengthMultiplier > 1.15)
        #expect(projection.rimLightAlpha > 0.03)
    }

    @Test("golden evening casts longer shadows to the left")
    func goldenEveningCastsLongerShadowsToTheLeft() {
        let projection = GardenLightProjection(
            sunlight: GardenSunlightCondition(at: date(hour: 18), calendar: utcCalendar)
        )

        #expect(projection.shadowOffsetX < -0.10)
        #expect(projection.shadowLengthMultiplier > 1.15)
        #expect(projection.rimLightAlpha > 0.04)
    }

    @Test("night light keeps shadows soft")
    func nightLightKeepsShadowsSoft() {
        let projection = GardenLightProjection(
            sunlight: GardenSunlightCondition(at: date(hour: 23), calendar: utcCalendar)
        )

        #expect(projection.shadowOpacityMultiplier < 0.65)
        #expect(projection.rimLightAlpha < 0.02)
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
