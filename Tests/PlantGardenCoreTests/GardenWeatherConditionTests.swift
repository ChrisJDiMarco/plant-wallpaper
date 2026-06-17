import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden weather conditions")
struct GardenWeatherConditionTests {
    @Test("WMO codes map to sensible weather kinds")
    func wmoCodesMapToSensibleKinds() {
        #expect(GardenWeatherKind.fromWMOCode(0) == .clear)
        #expect(GardenWeatherKind.fromWMOCode(2) == .partlyCloudy)
        #expect(GardenWeatherKind.fromWMOCode(3) == .overcast)
        #expect(GardenWeatherKind.fromWMOCode(45) == .fog)
        #expect(GardenWeatherKind.fromWMOCode(53) == .drizzle)
        #expect(GardenWeatherKind.fromWMOCode(63) == .rain)
        #expect(GardenWeatherKind.fromWMOCode(81) == .rain)
        #expect(GardenWeatherKind.fromWMOCode(73) == .snow)
        #expect(GardenWeatherKind.fromWMOCode(96) == .storm)
        #expect(GardenWeatherKind.fromWMOCode(9_999) == .partlyCloudy)
    }

    @Test("precipitation hydrates while clear skies do not")
    func precipitationHydratesWhileClearDoesNot() {
        let date = Date(timeIntervalSince1970: 2_000_000)
        let rain = GardenWeatherCondition(kind: .rain, temperatureCelsius: 14, fetchedAt: date)
        let clear = GardenWeatherCondition(kind: .clear, temperatureCelsius: 22, fetchedAt: date)

        #expect(rain.isPrecipitating)
        #expect(rain.hydrationPerHour > 0)
        #expect(!clear.isPrecipitating)
        #expect(clear.hydrationPerHour == 0)
        #expect(rain.ambientMoistureTarget > clear.ambientMoistureTarget)
    }

    @Test("conditions go stale after three hours")
    func conditionsGoStaleAfterThreeHours() {
        let fetchedAt = Date(timeIntervalSince1970: 2_000_000)
        let condition = GardenWeatherCondition(kind: .rain, temperatureCelsius: 12, fetchedAt: fetchedAt)

        #expect(!condition.isStale(at: fetchedAt.addingTimeInterval(60 * 60)))
        #expect(condition.isStale(at: fetchedAt.addingTimeInterval(4 * 60 * 60)))
    }

    @Test("rain raises ambient moisture and plant hydration versus clear weather")
    func rainRaisesMoistureAndHydration() {
        let start = Date(timeIntervalSince1970: 2_000_000)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.7),
            plantedAt: start.addingTimeInterval(-3_600),
            lastTendedAt: start.addingTimeInterval(-3_600),
            growth: 0.4,
            hydration: 0.5,
            health: 0.8,
            bloomProgress: 0.3,
            swaySeed: 7,
            scale: 1.0
        )
        let baseState = GardenState(lastUpdatedAt: start, plants: [plant], ambientMoisture: 0.4)
        let rainCondition = GardenWeatherCondition(kind: .rain, temperatureCelsius: 13, fetchedAt: start)
        let clearCondition = GardenWeatherCondition(kind: .clear, temperatureCelsius: 23, fetchedAt: start)
        let later = start.addingTimeInterval(2 * 60 * 60)

        let rainyState = GardenEngine.advance(
            GardenEngine.setWeather(baseState, weather: rainCondition),
            to: later
        )
        let clearState = GardenEngine.advance(
            GardenEngine.setWeather(baseState, weather: clearCondition),
            to: later
        )

        #expect(rainyState.ambientMoisture > clearState.ambientMoisture)
        #expect(rainyState.plants[0].hydration > clearState.plants[0].hydration)
    }

    @Test("stale weather has no effect on the simulation")
    func staleWeatherHasNoEffect() {
        let start = Date(timeIntervalSince1970: 2_000_000)
        let staleCondition = GardenWeatherCondition(
            kind: .storm,
            temperatureCelsius: 10,
            fetchedAt: start.addingTimeInterval(-5 * 60 * 60)
        )
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.7),
            plantedAt: start.addingTimeInterval(-3_600),
            lastTendedAt: start.addingTimeInterval(-3_600),
            growth: 0.4,
            hydration: 0.5,
            health: 0.8,
            bloomProgress: 0.3,
            swaySeed: 7,
            scale: 1.0
        )
        let baseState = GardenState(lastUpdatedAt: start, plants: [plant], ambientMoisture: 0.4)
        let later = start.addingTimeInterval(60 * 60)

        let withStaleWeather = GardenEngine.advance(
            GardenEngine.setWeather(baseState, weather: staleCondition),
            to: later
        )
        let withoutWeather = GardenEngine.advance(baseState, to: later)

        #expect(withStaleWeather.ambientMoisture == withoutWeather.ambientMoisture)
        #expect(withStaleWeather.plants[0].hydration == withoutWeather.plants[0].hydration)
    }

    @Test("legacy settings decode weather and audio as opt-in")
    func legacySettingsDecodeWeatherAndAudioAsOptIn() throws {
        let legacyJSON = Data("""
        {
            "growthSpeedMultiplier": 2.0,
            "musicSource": "spotify"
        }
        """.utf8)

        let settings = try JSONDecoder().decode(GardenSettings.self, from: legacyJSON)

        #expect(settings.growthSpeedMultiplier == 2.0)
        #expect(settings.musicSource == .spotify)
        #expect(settings.isWeatherSyncEnabled == false)
        #expect(settings.isAmbientSoundEnabled == false)
        #expect(settings.waterUseMultiplier == 1.0)
    }
}
