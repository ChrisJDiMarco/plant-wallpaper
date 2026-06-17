import Foundation
import PlantGardenCore
import Testing

@Suite("Garden plant light overlay")
struct GardenPlantLightOverlayTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("plant overlay darkens as daylight fades")
    func plantOverlayDarkensAsDaylightFades() throws {
        let noon = GardenPlantLightOverlay(sunlight: try sunlight(atHour: 12))
        let golden = GardenPlantLightOverlay(sunlight: try sunlight(atHour: 18))
        let night = GardenPlantLightOverlay(sunlight: try sunlight(atHour: 23))

        #expect(noon.opacity == 0)
        #expect(golden.opacity > noon.opacity)
        #expect(night.opacity > golden.opacity)
        #expect(night.opacity <= 0.55)
    }

    @Test("morning stays softer than dusk")
    func morningStaysSofterThanDusk() throws {
        let morning = GardenPlantLightOverlay(sunlight: try sunlight(atHour: 7))
        let golden = GardenPlantLightOverlay(sunlight: try sunlight(atHour: 18))

        #expect(morning.opacity > 0)
        #expect(morning.opacity < golden.opacity)
    }

    @Test("manual plant darkening adds scene shade and clamps")
    func manualPlantDarkeningAddsSceneShadeAndClamps() throws {
        let noon = try sunlight(atHour: 12)
        let night = try sunlight(atHour: 23)

        let manuallyDarkenedNoon = GardenPlantLightOverlay(sunlight: noon, manualDarkening: 0.35)
        let overDarkenedNight = GardenPlantLightOverlay(sunlight: night, manualDarkening: 0.60)

        #expect(manuallyDarkenedNoon.opacity == 0.35)
        #expect(overDarkenedNight.opacity == 0.75)
    }

    @Test("garden state plant overlay includes manual scene darkening")
    func gardenStatePlantOverlayIncludesManualSceneDarkening() throws {
        var state = GardenState(manualPlantDarkening: 0.22)
        let noon = try date(atHour: 12)

        #expect(state.plantLightOverlay(at: noon, calendar: utcCalendar).opacity == 0.22)

        state.manualPlantDarkening = 1.0
        #expect(state.plantLightOverlay(at: noon, calendar: utcCalendar).opacity == 0.60)
    }

    private func sunlight(atHour hour: Int) throws -> GardenSunlightCondition {
        GardenSunlightCondition(at: try date(atHour: hour), calendar: utcCalendar)
    }

    private func date(atHour hour: Int) throws -> Date {
        let calendar = utcCalendar
        return try #require(DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 11,
            hour: hour
        ).date)
    }
}
