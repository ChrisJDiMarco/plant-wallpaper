import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant cast shadow")
struct PlantCastShadowTests {
    @Test("mature trees cast broader stronger canopy shadows than seedlings")
    func matureTreesCastBroaderStrongerCanopyShadowsThanSeedlings() {
        let seedling = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.42, y: 0.58),
            ageSeconds: 900,
            growth: 0.08,
            hydration: 0.74,
            health: 0.88
        )
        let tree = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.42, y: 0.90),
            ageSeconds: 9 * 24 * 3_600,
            growth: 0.94,
            hydration: 0.76,
            health: 0.90
        )
        let projection = GardenLightProjection(
            sunlight: GardenSunlightCondition(at: date(hour: 13), calendar: utcCalendar)
        )

        let seedlingShadow = PlantCastShadow(plant: seedling, projection: projection)
        let treeShadow = PlantCastShadow(plant: tree, projection: projection)

        #expect(seedlingShadow.isVisible == false)
        #expect(treeShadow.isVisible == true)
        #expect(treeShadow.widthMultiplier > seedlingShadow.widthMultiplier)
        #expect(treeShadow.lengthMultiplier > seedlingShadow.lengthMultiplier)
        #expect(treeShadow.opacity > seedlingShadow.opacity)
        #expect(treeShadow.canopyLobeCount > seedlingShadow.canopyLobeCount)
    }

    @Test("morning and golden light cast shadows in opposite directions")
    func morningAndGoldenLightCastShadowsInOppositeDirections() {
        let plant = Plant(
            species: .cherryTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.84),
            ageSeconds: 7 * 24 * 3_600,
            growth: 0.84,
            hydration: 0.70,
            health: 0.86
        )
        let morning = PlantCastShadow(
            plant: plant,
            projection: GardenLightProjection(
                sunlight: GardenSunlightCondition(at: date(hour: 7), calendar: utcCalendar)
            )
        )
        let golden = PlantCastShadow(
            plant: plant,
            projection: GardenLightProjection(
                sunlight: GardenSunlightCondition(at: date(hour: 18), calendar: utcCalendar)
            )
        )
        let bright = PlantCastShadow(
            plant: plant,
            projection: GardenLightProjection(
                sunlight: GardenSunlightCondition(at: date(hour: 13), calendar: utcCalendar)
            )
        )

        #expect(morning.offsetXMultiplier > 0)
        #expect(golden.offsetXMultiplier < 0)
        #expect(abs(morning.offsetXMultiplier) > abs(bright.offsetXMultiplier))
        #expect(abs(golden.offsetXMultiplier) > abs(bright.offsetXMultiplier))
        #expect(morning.lengthMultiplier > bright.lengthMultiplier)
        #expect(golden.lengthMultiplier > bright.lengthMultiplier)
    }

    @Test("night canopy shadows stay soft and subdued")
    func nightCanopyShadowsStaySoftAndSubdued() {
        let plant = Plant(
            species: .monstera,
            screenIndex: 0,
            position: GardenPoint(x: 0.36, y: 0.86),
            ageSeconds: 5 * 24 * 3_600,
            growth: 0.78,
            hydration: 0.82,
            health: 0.88
        )
        let bright = PlantCastShadow(
            plant: plant,
            projection: GardenLightProjection(
                sunlight: GardenSunlightCondition(at: date(hour: 13), calendar: utcCalendar)
            )
        )
        let night = PlantCastShadow(
            plant: plant,
            projection: GardenLightProjection(
                sunlight: GardenSunlightCondition(at: date(hour: 1), calendar: utcCalendar)
            )
        )

        #expect(night.isVisible == true)
        #expect(night.opacity < bright.opacity)
        #expect(night.softness > bright.softness)
        #expect(night.canopyLobeCount <= bright.canopyLobeCount)
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
