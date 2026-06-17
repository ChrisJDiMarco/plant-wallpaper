import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden scene visual profile")
struct GardenSceneVisualProfileTests {
    @Test("moonlit scenes are mistier softer and more nocturnal than desert scenes")
    func moonlitScenesAreMistierSofterAndMoreNocturnalThanDesertScenes() {
        let moonlit = GardenSceneVisualProfile(sceneKey: "moonlit-empty-glasshouse")
        let desert = GardenSceneVisualProfile(sceneKey: "empty-desertarium")

        #expect(moonlit.mistOpacity > desert.mistOpacity)
        #expect(moonlit.contactSoftness > desert.contactSoftness)
        #expect(moonlit.wildlifeDensity > desert.wildlifeDensity)
        #expect(desert.dustMoteOpacity > moonlit.dustMoteOpacity)
    }

    @Test("scene profile adjusts light projection without leaving bounded ranges")
    func sceneProfileAdjustsLightProjectionWithoutLeavingBoundedRanges() {
        let profile = GardenSceneVisualProfile(sceneKey: "moonlit-empty-glasshouse")
        let base = GardenLightProjection(
            sunlight: GardenSunlightCondition(at: date(hour: 23), calendar: utcCalendar)
        )

        let adjusted = profile.lightProjection(from: base)

        #expect(adjusted.shadowLengthMultiplier >= 0.64)
        #expect(adjusted.shadowLengthMultiplier <= 1.86)
        #expect(adjusted.shadowOpacityMultiplier >= 0.30)
        #expect(adjusted.shadowOpacityMultiplier <= 1.36)
        #expect(adjusted.rimLightAlpha >= 0.004)
    }

    @Test("foreground occlusion bands identify planted bed rims")
    func foregroundOcclusionBandsIdentifyPlantedBedRims() {
        let profile = GardenSceneVisualProfile(sceneKey: "empty-conservatory-hall")
        let foregroundPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.16, y: 0.90)
        )
        let openPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.62)
        )

        #expect(profile.occlusionOpacity(for: foregroundPlant) > 0)
        #expect(profile.occlusionOpacity(for: openPlant) == 0)
    }

    @Test("apartment studio is warm indoor and low wildlife")
    func apartmentStudioIsWarmIndoorAndLowWildlife() {
        let apartment = GardenSceneVisualProfile(sceneKey: "cozy-apartment-studio")
        let moonlit = GardenSceneVisualProfile(sceneKey: "moonlit-empty-glasshouse")

        #expect(apartment.warmth > 0.60)
        #expect(apartment.humidity < 0.50)
        #expect(apartment.wildlifeDensity < moonlit.wildlifeDensity)
        #expect(apartment.mistOpacity < moonlit.mistOpacity)
    }

    @Test("cottage backyard garden is warm outdoor with raised bed occlusion")
    func cottageBackyardGardenIsWarmOutdoorWithRaisedBedOcclusion() {
        let profile = GardenSceneVisualProfile(sceneKey: "cottage-backyard-garden")
        let foregroundPlant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.78, y: 0.86)
        )
        let openPlant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.58)
        )

        #expect(profile.warmth > 0.65)
        #expect(profile.humidity < 0.55)
        #expect(profile.mistOpacity < 0.05)
        #expect(profile.occlusionOpacity(for: foregroundPlant) > 0)
        #expect(profile.occlusionOpacity(for: openPlant) == 0)
    }

    @Test("global garden scenes expose tuned atmosphere profiles")
    func globalGardenScenesExposeTunedAtmosphereProfiles() {
        let monkGarden = GardenSceneVisualProfile(sceneKey: "chinese-mountain-monk-garden")
        let swedishPatio = GardenSceneVisualProfile(sceneKey: "swedish-patio-garden")
        let brazilianRooftop = GardenSceneVisualProfile(sceneKey: "brazilian-rooftop-garden")
        let egyptianEstate = GardenSceneVisualProfile(sceneKey: "ancient-egyptian-estate-garden")
        let texasGarden = GardenSceneVisualProfile(sceneKey: "texas-rustic-garden")

        #expect(monkGarden.mistOpacity > swedishPatio.mistOpacity)
        #expect(monkGarden.contactSoftness > texasGarden.contactSoftness)
        #expect(brazilianRooftop.humidity > swedishPatio.humidity)
        #expect(egyptianEstate.warmth > swedishPatio.warmth)
        #expect(texasGarden.dustMoteOpacity > brazilianRooftop.dustMoteOpacity)
        #expect(egyptianEstate.wildlifeDensity < brazilianRooftop.wildlifeDensity)
    }

    private func date(hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = utcCalendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 6
        components.day = 8
        components.hour = hour
        return components.date!
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
