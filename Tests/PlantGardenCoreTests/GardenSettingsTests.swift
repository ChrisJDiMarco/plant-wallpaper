import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden settings")
struct GardenSettingsTests {
    @Test("settings clamp customization ranges")
    func settingsClampCustomizationRanges() {
        let settings = GardenSettings(
            growthSpeedMultiplier: 12,
            waterUseMultiplier: -2,
            defaultPlantScale: 8,
            wildlifeDensityMultiplier: 0,
            wildlifeSpeedMultiplier: 7,
            bugSizeMultiplier: 12,
            birdCountMultiplier: 12,
            gnomeSimulation: GardenGnomeSimulationSettings(
                populationMultiplier: 12,
                tribeScaleMultiplier: 9,
                behaviorLiveliness: -4,
                buildingSpeedMultiplier: 12,
                cooperationMultiplier: -3,
                plantInteractionMultiplier: 9,
                villageDetailMultiplier: 8,
                settlementExpansionDays: 500
            ),
            musicVolume: 2,
            radioCompanionScale: 9,
            musicSource: .spotify,
            spotifyLaunchURLString: "file:///tmp/not-spotify"
        )

        #expect(settings.growthSpeedMultiplier == 4.0)
        #expect(settings.waterUseMultiplier == 0.25)
        #expect(settings.defaultPlantScale == 2.25)
        #expect(settings.wildlifeDensityMultiplier == 0.25)
        #expect(settings.wildlifeSpeedMultiplier == 3.0)
        #expect(settings.bugSizeMultiplier == 2.0)
        #expect(settings.birdCountMultiplier == 2.0)
        #expect(settings.musicVolume == 1.0)
        #expect(settings.radioCompanionScale == 1.70)
        #expect(settings.gnomeSimulation.populationMultiplier == 2.5)
        #expect(settings.gnomeSimulation.tribeScaleMultiplier == 2.25)
        #expect(settings.gnomeSimulation.behaviorLiveliness == 0.25)
        #expect(settings.gnomeSimulation.buildingSpeedMultiplier == 4.0)
        #expect(settings.gnomeSimulation.cooperationMultiplier == 0.0)
        #expect(settings.gnomeSimulation.plantInteractionMultiplier == 2.5)
        #expect(settings.gnomeSimulation.villageDetailMultiplier == 2.0)
        #expect(settings.gnomeSimulation.settlementExpansionDays == GnomeTribeSettlementPlan.maximumExpansionDurationDays)
        #expect(settings.musicSource == .spotify)
        #expect(settings.spotifyLaunchURLString == GardenSettings.defaultSpotifyLaunchURLString)

        let tinyCompanionSettings = GardenSettings(radioCompanionScale: 0.1)
        #expect(tinyCompanionSettings.radioCompanionScale == 0.55)

        let tinyBugSettings = GardenSettings(bugSizeMultiplier: 0.1)
        #expect(tinyBugSettings.bugSizeMultiplier == 0.50)

        let tinyBirdSettings = GardenSettings(birdCountMultiplier: 0.1)
        #expect(tinyBirdSettings.birdCountMultiplier == 0.25)
    }

    @Test("ambient sound is opt-in by default")
    func ambientSoundIsOptInByDefault() {
        let settings = GardenSettings.default

        #expect(settings.isAmbientSoundEnabled == false)
        #expect(settings.ambientSoundVolume == 0.35)
        #expect(settings.isWindSoundEnabled)
        #expect(settings.isRainSoundEnabled)
        #expect(settings.isBirdsongEnabled)
        #expect(settings.isCricketSoundEnabled)
        #expect(settings.isWaterSoundEnabled)
        #expect(settings.isUrbanMurmurSoundEnabled)
        #expect(settings.isRoomToneSoundEnabled)
        #expect(settings.isCicadaSoundEnabled)
        #expect(settings.isChimeSoundEnabled)
        #expect(settings.isSmallWildlifeSoundEnabled)
        #expect(settings.isRoomLifeSoundEnabled)
        #expect(settings.isElectronicsSoundEnabled)
        #expect(settings.isAlienFaunaSoundEnabled)
        #expect(settings.isHabitatHumSoundEnabled)
        #expect(settings.isCrystallineShimmerSoundEnabled)
        #expect(settings.isLowRumbleSoundEnabled)
        #expect(settings.isGardenInteractionLocked == false)
        #expect(settings.useAIGeneratedLockSnapshot == false)
        #expect(settings.isCatChatOnClickEnabled)
        #expect(settings.isRoomStudioWildlifeEnabled == false)
        #expect(settings.experienceMode == .garden)
        #expect(settings.timeLapseCadence == .daily)
        #expect(settings.cozyModeEnabled == false)
        #expect(settings.performanceMode == .balanced)
        #expect(settings.autoLowPowerOnBattery)
        #expect(settings.radioActivationMode == .singleClick)
        #expect(settings.radioCompanionScale == 1.0)
        #expect(settings.bugSizeMultiplier == 1.0)
        #expect(settings.birdCountMultiplier == 1.0)
        #expect(settings.gnomeSimulation.isEnabled)
        #expect(settings.gnomeSimulation.populationMultiplier == 1.0)
        #expect(settings.gnomeSimulation.behaviorLiveliness == 1.0)
        #expect(settings.gnomeSimulation.buildingSpeedMultiplier == 1.0)
        #expect(settings.gnomeSimulation.cooperationMultiplier == 1.0)
        #expect(settings.gnomeSimulation.plantInteractionMultiplier == 1.0)
        #expect(settings.gnomeSimulation.villageDetailMultiplier == 1.0)
        #expect(settings.gnomeSimulation.settlementExpansionDays == 7.0)
        #expect(settings.wallpaperGenerationQuality == .twoK)
        #expect(settings.aiEditStrength == .subtle)
        #expect(settings.isTimeOfDayPlantDarkeningEnabled)
        #expect(settings.rareMomentsMode == .full)
        #expect(settings.displayBehavior == .mirrorAllDisplays)
        #expect(settings.notifyCare)
        #expect(settings.notifyWeather)
        #expect(settings.notifyRareMoments)
        #expect(settings.notifyFocus)
        #expect(settings.notifyHarvest)
    }

    @Test("ambient layer switches round-trip through settings updates")
    func ambientLayerSwitchesRoundTripThroughSettingsUpdates() {
        let settings = GardenSettings.default.updating(
            isAmbientSoundEnabled: true,
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
        )

        #expect(settings.isAmbientSoundEnabled)
        #expect(!settings.isWindSoundEnabled)
        #expect(!settings.isRainSoundEnabled)
        #expect(!settings.isBirdsongEnabled)
        #expect(!settings.isCricketSoundEnabled)
        #expect(!settings.isWaterSoundEnabled)
        #expect(!settings.isUrbanMurmurSoundEnabled)
        #expect(!settings.isRoomToneSoundEnabled)
        #expect(!settings.isCicadaSoundEnabled)
        #expect(!settings.isChimeSoundEnabled)
        #expect(!settings.isSmallWildlifeSoundEnabled)
        #expect(!settings.isRoomLifeSoundEnabled)
        #expect(!settings.isElectronicsSoundEnabled)
        #expect(!settings.isAlienFaunaSoundEnabled)
        #expect(!settings.isHabitatHumSoundEnabled)
        #expect(!settings.isCrystallineShimmerSoundEnabled)
        #expect(!settings.isLowRumbleSoundEnabled)
    }

    @Test("garden interaction lock round-trips through settings updates")
    func gardenInteractionLockRoundTripsThroughSettingsUpdates() {
        let locked = GardenSettings.default.updating(
            isGardenInteractionLocked: true,
            useAIGeneratedLockSnapshot: true,
            isCatChatOnClickEnabled: false
        )
        let unlocked = locked.updating(
            isGardenInteractionLocked: false,
            useAIGeneratedLockSnapshot: false,
            isCatChatOnClickEnabled: true
        )

        #expect(locked.isGardenInteractionLocked)
        #expect(locked.useAIGeneratedLockSnapshot)
        #expect(!locked.isCatChatOnClickEnabled)
        #expect(!unlocked.isGardenInteractionLocked)
        #expect(!unlocked.useAIGeneratedLockSnapshot)
        #expect(unlocked.isCatChatOnClickEnabled)
    }

    @Test("comfort privacy and cost controls round-trip through settings updates")
    func comfortPrivacyAndCostControlsRoundTripThroughSettingsUpdates() {
        let settings = GardenSettings.default.updating(
            bugSizeMultiplier: 1.45,
            birdCountMultiplier: 1.8,
            gnomeSimulation: GardenGnomeSimulationSettings(
                isEnabled: false,
                populationMultiplier: 1.7,
                tribeScaleMultiplier: 1.85,
                behaviorLiveliness: 1.45,
                buildingSpeedMultiplier: 2.25,
                cooperationMultiplier: 1.6,
                plantInteractionMultiplier: 2.1,
                villageDetailMultiplier: 1.4,
                settlementExpansionDays: 14
            ),
            radioCompanionScale: 1.35,
            isRoomStudioWildlifeEnabled: true,
            experienceMode: .roomStudio,
            timeLapseCadence: .weekly,
            cozyModeEnabled: true,
            performanceMode: .still,
            autoLowPowerOnBattery: false,
            radioActivationMode: .doubleClick,
            wallpaperGenerationQuality: .fourK,
            aiEditStrength: .bigChange,
            rareMomentsMode: .quiet,
            displayBehavior: .mainDisplayOnly,
            notifyCare: false,
            notifyWeather: false,
            notifyRareMoments: false,
            notifyFocus: false,
            notifyHarvest: false
        )

        #expect(settings.timeLapseCadence == .weekly)
        #expect(settings.experienceMode == .roomStudio)
        #expect(settings.cozyModeEnabled)
        #expect(settings.performanceMode == .still)
        #expect(!settings.autoLowPowerOnBattery)
        #expect(settings.radioActivationMode == .doubleClick)
        #expect(settings.radioCompanionScale == 1.35)
        #expect(settings.bugSizeMultiplier == 1.45)
        #expect(settings.birdCountMultiplier == 1.8)
        #expect(!settings.gnomeSimulation.isEnabled)
        #expect(settings.gnomeSimulation.populationMultiplier == 1.7)
        #expect(settings.gnomeSimulation.tribeScaleMultiplier == 1.85)
        #expect(settings.gnomeSimulation.behaviorLiveliness == 1.45)
        #expect(settings.gnomeSimulation.buildingSpeedMultiplier == 2.25)
        #expect(settings.gnomeSimulation.cooperationMultiplier == 1.6)
        #expect(settings.gnomeSimulation.plantInteractionMultiplier == 2.1)
        #expect(settings.gnomeSimulation.villageDetailMultiplier == 1.4)
        #expect(settings.gnomeSimulation.settlementExpansionDays == 14)
        #expect(settings.isRoomStudioWildlifeEnabled)
        #expect(settings.wallpaperGenerationQuality == .fourK)
        #expect(settings.aiEditStrength == .bigChange)
        #expect(settings.rareMomentsMode == .quiet)
        #expect(settings.displayBehavior == .mainDisplayOnly)
        #expect(!settings.notifyCare)
        #expect(!settings.notifyWeather)
        #expect(!settings.notifyRareMoments)
        #expect(!settings.notifyFocus)
        #expect(!settings.notifyHarvest)
    }

    @Test("comfort privacy and cost controls encode and decode")
    func comfortPrivacyAndCostControlsEncodeAndDecode() throws {
        let settings = GardenSettings.default.updating(
            bugSizeMultiplier: 1.55,
            birdCountMultiplier: 0.65,
            gnomeSimulation: GardenGnomeSimulationSettings(
                isEnabled: false,
                populationMultiplier: 0.7,
                tribeScaleMultiplier: 0.58,
                behaviorLiveliness: 1.8,
                buildingSpeedMultiplier: 3.2,
                cooperationMultiplier: 0.4,
                plantInteractionMultiplier: 1.9,
                villageDetailMultiplier: 1.7,
                settlementExpansionDays: 3.5
            ),
            radioCompanionScale: 0.65,
            useAIGeneratedLockSnapshot: true,
            isRoomStudioWildlifeEnabled: true,
            experienceMode: .roomStudio,
            timeLapseCadence: .off,
            cozyModeEnabled: true,
            performanceMode: .lively,
            autoLowPowerOnBattery: false,
            radioActivationMode: .disabled,
            wallpaperGenerationQuality: .fourK,
            aiEditStrength: .medium,
            rareMomentsMode: .off,
            displayBehavior: .mainDisplayOnly,
            notifyCare: false,
            notifyWeather: false,
            notifyRareMoments: false,
            notifyFocus: false,
            notifyHarvest: false
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(GardenSettings.self, from: data)

        #expect(decoded == settings)
        #expect(decoded.bugSizeMultiplier == 1.55)
        #expect(decoded.birdCountMultiplier == 0.65)
        #expect(decoded.gnomeSimulation.populationMultiplier == 0.7)
        #expect(decoded.gnomeSimulation.tribeScaleMultiplier == 0.58)
        #expect(decoded.gnomeSimulation.buildingSpeedMultiplier == 3.2)
        #expect(decoded.gnomeSimulation.settlementExpansionDays == 3.5)
        #expect(!decoded.gnomeSimulation.isEnabled)
        #expect(decoded.useAIGeneratedLockSnapshot)
        #expect(decoded.isRoomStudioWildlifeEnabled)
        #expect(decoded.wallpaperGenerationQuality == .fourK)
    }

    @Test("room studio does not allow ambient wildlife by default")
    func roomStudioDoesNotAllowAmbientWildlifeByDefault() {
        let roomSettings = GardenSettings.default.updating(experienceMode: .roomStudio)
        let enabledRoomSettings = roomSettings.updating(isRoomStudioWildlifeEnabled: true)

        #expect(GardenSettings.default.allowsAmbientWildlifeInExperienceMode)
        #expect(!roomSettings.allowsAmbientWildlifeInExperienceMode)
        #expect(enabledRoomSettings.allowsAmbientWildlifeInExperienceMode)
    }

    @Test("radio companion station assignments reject duplicate streams")
    func radioCompanionStationAssignmentsRejectDuplicateStreams() {
        let customStream = GardenRadioStream(
            id: "filtermusic:test-station",
            displayName: "Test Station",
            streamURLStrings: ["https://example.com/live.mp3"],
            filtermusicPageURLString: "https://filtermusic.net/test-station",
            shortDescription: "A test station."
        )

        let assigned = GardenSettings.default.assigningRadioStream(customStream, to: .gardenCat)
        #expect(assigned?.radioStream(for: .gardenCat).id == customStream.id)
        #expect(assigned?.assigningRadioStream(customStream, to: .moonMoth) == nil)
        #expect(assigned?.companionAlreadyAssigned(to: customStream, excluding: .moonMoth) == .gardenCat)
    }

    @Test("spotify launch links allow Spotify URLs and URI schemes")
    func spotifyLaunchLinksAllowSpotifyURLsAndURISchemes() {
        let webURL = GardenSettings(
            spotifyLaunchURLString: "  https://open.spotify.com/playlist/example?si=123  "
        )
        let spotifyURI = GardenSettings(spotifyLaunchURLString: "spotify:playlist:example")
        let shortLink = GardenSettings(spotifyLaunchURLString: "https://spotify.link/example")

        #expect(webURL.spotifyLaunchURLString == "https://open.spotify.com/playlist/example?si=123")
        #expect(webURL.spotifyLaunchURL.absoluteString == "https://open.spotify.com/playlist/example?si=123")
        #expect(spotifyURI.spotifyLaunchURLString == "spotify:playlist:example")
        #expect(spotifyURI.spotifyLaunchURL.absoluteString == "spotify:playlist:example")
        #expect(shortLink.spotifyLaunchURLString == "https://spotify.link/example")
    }

    @Test("legacy state files load default settings")
    func legacyStateFilesLoadDefaultSettings() throws {
        let json = """
        {
          "ambientMoisture": 0.38,
          "compositionVersion": 5,
          "createdAt": "1970-01-01T00:00:10Z",
          "isPaused": false,
          "lastUpdatedAt": "1970-01-01T00:00:20Z",
          "plants": [],
          "version": 2,
          "windStrength": 0.24
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let state = try decoder.decode(GardenState.self, from: Data(json.utf8))

        #expect(state.settings == .default)
    }
}
