import Foundation
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@Suite("Garden ambience engine")
struct GardenAmbienceEngineTests {
    @Test("every built-in scene has soundscape metadata")
    func everyBuiltInSceneHasSoundscapeMetadata() {
        for scene in GardenWallpaperScene.allCases {
            let soundscape = GardenSceneSoundscape(sceneKey: scene.rawValue)

            #expect(soundscape.sceneKey == scene.rawValue)
            #expect(!soundscape.birds.description.isEmpty)
            #expect(!soundscape.insects.description.isEmpty)
            #expect(!soundscape.place.description.isEmpty)
            #expect(soundscape.birds.presence >= 0)
            #expect(soundscape.insects.nightPresence >= 0)
            #expect(soundscape.place.windExposure >= 0)
            #expect(soundscape.place.smallWildlife >= 0)
            #expect(soundscape.place.roomLife >= 0)
            #expect(soundscape.place.electronics >= 0)
            #expect(soundscape.place.alienFauna >= 0)
            #expect(soundscape.place.habitatHum >= 0)
            #expect(soundscape.place.crystallineShimmer >= 0)
            #expect(soundscape.place.lowRumble >= 0)
        }
    }

    @Test("disabled ambience produces a silent mix")
    func disabledAmbienceProducesSilentMix() {
        let date = Date(timeIntervalSince1970: 2_000_000)
        let state = GardenState(
            windStrength: 1.0,
            settings: GardenSettings.default.updating(
                isAmbientSoundEnabled: false,
                ambientSoundVolume: 0.35
            ),
            weather: GardenWeatherCondition(
                kind: .rain,
                temperatureCelsius: 14,
                fetchedAt: date
            )
        )

        let mix = GardenAmbienceEngine.mix(for: state, at: date)

        #expect(mix == .silent)
    }

    @Test("layer switches silence individual ambience layers")
    func layerSwitchesSilenceIndividualAmbienceLayers() {
        let date = Date(timeIntervalSince1970: 2_001_600)
        let state = GardenState(
            windStrength: 1.0,
            settings: GardenSettings.default.updating(
                isAmbientSoundEnabled: true,
                ambientSoundVolume: 0.35,
                isWindSoundEnabled: false,
                isRainSoundEnabled: false,
                isBirdsongEnabled: false,
                isCricketSoundEnabled: false,
                isWaterSoundEnabled: false,
                isUrbanMurmurSoundEnabled: false,
                isRoomToneSoundEnabled: false,
                isCicadaSoundEnabled: false,
                isChimeSoundEnabled: false,
                isSmallWildlifeSoundEnabled: false,
                isRoomLifeSoundEnabled: false,
                isElectronicsSoundEnabled: false,
                isAlienFaunaSoundEnabled: false,
                isHabitatHumSoundEnabled: false,
                isCrystallineShimmerSoundEnabled: false,
                isLowRumbleSoundEnabled: false
            ),
            weather: GardenWeatherCondition(kind: .rain, temperatureCelsius: 14, fetchedAt: date)
        )

        let mix = GardenAmbienceEngine.mix(
            for: state,
            sceneKey: GardenWallpaperScene.starshipCommandBridge.rawValue,
            at: date
        )

        #expect(mix.masterVolume == 0.35)
        #expect(mix.wind == 0)
        #expect(mix.rain == 0)
        #expect(mix.birds == 0)
        #expect(mix.crickets == 0)
        #expect(mix.water == 0)
        #expect(mix.urbanMurmur == 0)
        #expect(mix.roomTone == 0)
        #expect(mix.cicadas == 0)
        #expect(mix.chimes == 0)
        #expect(mix.smallWildlife == 0)
        #expect(mix.roomLife == 0)
        #expect(mix.electronics == 0)
        #expect(mix.alienFauna == 0)
        #expect(mix.habitatHum == 0)
        #expect(mix.crystallineShimmer == 0)
        #expect(mix.lowRumble == 0)
    }

    @Test("scene soundscape changes city rooftop ambience")
    func sceneSoundscapeChangesCityRooftopAmbience() throws {
        let date = try middayDate()
        let state = GardenState(
            windStrength: 0.5,
            settings: GardenSettings.default.updating(
                isAmbientSoundEnabled: true,
                ambientSoundVolume: 0.35
            )
        )

        let rooftop = GardenAmbienceEngine.mix(
            for: state,
            sceneKey: GardenWallpaperScene.brazilianRooftopGarden.rawValue,
            at: date
        )
        let glasshouse = GardenAmbienceEngine.mix(
            for: state,
            sceneKey: GardenWallpaperScene.emptyConservatoryHall.rawValue,
            at: date
        )

        #expect(rooftop.urbanMurmur > glasshouse.urbanMurmur)
        #expect(rooftop.cicadas > glasshouse.cicadas)
        #expect(rooftop.birdPitch > glasshouse.birdPitch)
        #expect(rooftop.birds > glasshouse.birds)
    }

    @Test("water pavilion ambience includes water and stronger night insects")
    func waterPavilionAmbienceIncludesWaterAndNightInsects() throws {
        let date = try nightDate()
        let state = GardenState(
            windStrength: 0.35,
            settings: GardenSettings.default.updating(
                isAmbientSoundEnabled: true,
                ambientSoundVolume: 0.35
            )
        )

        let waterPavilion = GardenAmbienceEngine.mix(
            for: state,
            sceneKey: GardenWallpaperScene.emptyWaterPavilion.rawValue,
            at: date
        )
        let apartment = GardenAmbienceEngine.mix(
            for: state,
            sceneKey: GardenWallpaperScene.cozyApartmentStudio.rawValue,
            at: date
        )

        #expect(waterPavilion.water > 0.5)
        #expect(apartment.water == 0)
        #expect(waterPavilion.crickets > apartment.crickets)
        #expect(apartment.roomTone > waterPavilion.roomTone)
    }

    @Test("room studio scenes favor indoor texture over garden wildlife")
    func roomStudioScenesFavorIndoorTextureOverGardenWildlife() throws {
        let date = try middayDate()
        let state = GardenState(
            windStrength: 0.6,
            settings: GardenSettings.default.updating(
                isAmbientSoundEnabled: true,
                ambientSoundVolume: 0.35
            )
        )

        for scene in GardenWallpaperScene.scenes(for: .roomStudio) {
            let soundscape = GardenSceneSoundscape(sceneKey: scene.rawValue)
            let mix = GardenAmbienceEngine.mix(for: state, sceneKey: scene.rawValue, at: date)

            #expect(soundscape.place.roomLife > 0.20)
            #expect(mix.roomLife > 0.20)
            #expect(mix.roomTone > 0.30)
            #expect(mix.birds < 0.25)
            #expect(mix.crickets < 0.08)
        }
    }

    @Test("alien scenes use alien fauna and habitat machinery instead of Earth birds")
    func alienScenesUseAlienFaunaAndHabitatMachinery() throws {
        let date = try nightDate()
        let state = GardenState(
            windStrength: 0.4,
            settings: GardenSettings.default.updating(
                isAmbientSoundEnabled: true,
                ambientSoundVolume: 0.35
            )
        )

        for scene in GardenWallpaperScene.selectableScenes(for: .alienUFO) {
            let soundscape = GardenSceneSoundscape(sceneKey: scene.rawValue)
            let mix = GardenAmbienceEngine.mix(for: state, sceneKey: scene.rawValue, at: date)

            #expect(soundscape.place.alienFauna > 0.25)
            #expect(soundscape.place.habitatHum > 0.25)
            #expect(mix.alienFauna > 0.20)
            #expect(mix.habitatHum > 0.20)
            #expect(mix.birds < mix.alienFauna)
        }
    }

    @Test("specific scenes expose distinctive extra ambience layers")
    func specificScenesExposeDistinctiveExtraAmbienceLayers() throws {
        let date = try middayDate()
        let state = GardenState(
            windStrength: 0.45,
            settings: GardenSettings.default.updating(
                isAmbientSoundEnabled: true,
                ambientSoundVolume: 0.35
            )
        )

        let texas = GardenAmbienceEngine.mix(
            for: state,
            sceneKey: GardenWallpaperScene.texasRusticGarden.rawValue,
            at: date
        )
        let mediaDen = GardenAmbienceEngine.mix(
            for: state,
            sceneKey: GardenWallpaperScene.roomMediaDenCanvas.rawValue,
            at: date
        )
        let starship = GardenAmbienceEngine.mix(
            for: state,
            sceneKey: GardenWallpaperScene.starshipCommandBridge.rawValue,
            at: date
        )

        #expect(texas.smallWildlife > 0.20)
        #expect(mediaDen.electronics > 0.35)
        #expect(starship.lowRumble > 0.15)
        #expect(starship.habitatHum > mediaDen.habitatHum)
    }

    private func middayDate() throws -> Date {
        try date(hour: 13)
    }

    private func nightDate() throws -> Date {
        try date(hour: 22)
    }

    private func date(hour: Int) throws -> Date {
        let calendar = Calendar.current
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 12,
            hour: hour
        )
        return try #require(calendar.date(from: components))
    }
}
