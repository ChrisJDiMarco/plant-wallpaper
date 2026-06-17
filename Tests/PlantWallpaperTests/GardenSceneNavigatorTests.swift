import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@Suite("Garden scene navigator")
struct GardenSceneNavigatorTests {
    @Test("next and previous wrap through built in scenes")
    func nextAndPreviousWrapThroughBuiltInScenes() {
        let first = GardenWallpaperScene.allCases[0]
        let second = GardenWallpaperScene.allCases[1]
        let last = GardenWallpaperScene.allCases[GardenWallpaperScene.allCases.count - 1]

        #expect(GardenSceneNavigator.adjacentSceneKey(
            from: first.rawValue,
            customWallpapers: [],
            direction: .next
        ) == second.rawValue)
        #expect(GardenSceneNavigator.adjacentSceneKey(
            from: first.rawValue,
            customWallpapers: [],
            direction: .previous
        ) == last.rawValue)
        #expect(GardenSceneNavigator.adjacentSceneKey(
            from: last.rawValue,
            customWallpapers: [],
            direction: .next
        ) == first.rawValue)
    }

    @Test("custom scenes are included after built in scenes")
    func customScenesAreIncludedAfterBuiltInScenes() {
        let custom = CustomWallpaperRecord(
            key: "custom-moon-gate",
            displayName: "Custom: Moon Gate",
            prompt: "moon gate",
            imageURL: URL(fileURLWithPath: "/tmp/custom-moon-gate.png"),
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let lastBuiltIn = GardenWallpaperScene.allCases[GardenWallpaperScene.allCases.count - 1]

        #expect(GardenSceneNavigator.adjacentSceneKey(
            from: lastBuiltIn.rawValue,
            customWallpapers: [custom],
            direction: .next
        ) == custom.key)
        #expect(GardenSceneNavigator.adjacentSceneKey(
            from: custom.key,
            customWallpapers: [custom],
            direction: .next
        ) == GardenWallpaperScene.allCases[0].rawValue)
    }

    @Test("mode-specific navigation includes only matching custom scene roots")
    func modeSpecificNavigationIncludesOnlyMatchingCustomSceneRoots() {
        let gardenCustom = CustomWallpaperRecord(
            key: "custom-garden-courtyard",
            displayName: "Custom: Garden Courtyard",
            prompt: "garden courtyard",
            imageURL: URL(fileURLWithPath: "/tmp/custom-garden-courtyard.png"),
            createdAt: Date(timeIntervalSince1970: 1),
            experienceMode: .garden
        )
        let roomCustom = CustomWallpaperRecord(
            key: "custom-room-loft",
            displayName: "Custom: Room Loft",
            prompt: "room loft",
            imageURL: URL(fileURLWithPath: "/tmp/custom-room-loft.png"),
            createdAt: Date(timeIntervalSince1970: 2),
            experienceMode: .roomStudio
        )
        let alienCustom = CustomWallpaperRecord(
            key: "custom-alien-dome",
            displayName: "Custom: Alien Dome",
            prompt: "alien dome",
            imageURL: URL(fileURLWithPath: "/tmp/custom-alien-dome.png"),
            createdAt: Date(timeIntervalSince1970: 3),
            experienceMode: .alienUFO
        )
        let update = CustomWallpaperRecord(
            key: "edit-room-loft",
            displayName: "Update 1: room loft",
            prompt: "updated room loft",
            imageURL: URL(fileURLWithPath: "/tmp/edit-room-loft.png"),
            createdAt: Date(timeIntervalSince1970: 4),
            parentSceneKey: roomCustom.key,
            editedFromKey: roomCustom.key,
            editPrompt: "warmer",
            versionIndex: 1,
            experienceMode: .roomStudio
        )
        let records = [gardenCustom, roomCustom, alienCustom, update]

        let gardenKeys = GardenSceneNavigator.orderedSceneKeys(customWallpapers: records, experienceMode: .garden)
        let roomKeys = GardenSceneNavigator.orderedSceneKeys(customWallpapers: records, experienceMode: .roomStudio)
        let alienKeys = GardenSceneNavigator.orderedSceneKeys(customWallpapers: records, experienceMode: .alienUFO)

        #expect(gardenKeys.contains(gardenCustom.key))
        #expect(!gardenKeys.contains(roomCustom.key))
        #expect(!gardenKeys.contains(alienCustom.key))
        #expect(roomKeys.contains(roomCustom.key))
        #expect(!roomKeys.contains(gardenCustom.key))
        #expect(!roomKeys.contains(update.key))
        #expect(alienKeys.contains(alienCustom.key))
        #expect(!alienKeys.contains(gardenCustom.key))
        #expect(!alienKeys.contains(roomCustom.key))
    }

    @Test("room studio navigation cycles only room scenes")
    func roomStudioNavigationCyclesOnlyRoomScenes() {
        let roomScenes = GardenWallpaperScene.scenes(for: .roomStudio)

        #expect(roomScenes == [
            .roomModernBedroomCanvas,
            .roomLoftHangoutCanvas,
            .roomMediaDenCanvas
        ])
        #expect(GardenSceneNavigator.orderedSceneKeys(
            customWallpapers: [],
            experienceMode: .roomStudio
        ) == roomScenes.map(\.rawValue))
        #expect(GardenSceneNavigator.adjacentSceneKey(
            from: GardenWallpaperScene.defaultScene.rawValue,
            customWallpapers: [],
            direction: .next,
            experienceMode: .roomStudio
        ) == GardenWallpaperScene.roomLoftHangoutCanvas.rawValue)
        #expect(GardenSceneNavigator.adjacentSceneKey(
            from: GardenWallpaperScene.roomMediaDenCanvas.rawValue,
            customWallpapers: [],
            direction: .next,
            experienceMode: .roomStudio
        ) == GardenWallpaperScene.roomModernBedroomCanvas.rawValue)
    }

    @Test("alien UFO navigation cycles only alien scenes")
    func alienUFONavigationCyclesOnlyAlienScenes() {
        let alienScenes = GardenWallpaperScene.scenes(for: .alienUFO)
        let selectableAlienScenes = GardenWallpaperScene.selectableScenes(for: .alienUFO)

        #expect(alienScenes == [
            .alienCraterGreenhouse,
            .orbitalUfoTerrarium,
            .bioluminescentExoplanetOasis,
            .martianHydroponicDome,
            .alienCraterDome,
            .alienCliffsideHomeGarden,
            .alienCivicParkPlaza,
            .alienStarshipBotanyBay,
            .alienFloatingIslandSanctuary
        ])
        #expect(selectableAlienScenes == [
            .alienCraterDome,
            .alienCliffsideHomeGarden,
            .alienCivicParkPlaza,
            .alienStarshipBotanyBay,
            .alienFloatingIslandSanctuary
        ])
        #expect(GardenSceneNavigator.orderedSceneKeys(
            customWallpapers: [],
            experienceMode: .alienUFO
        ) == selectableAlienScenes.map(\.rawValue))
        #expect(GardenSceneNavigator.adjacentSceneKey(
            from: GardenWallpaperScene.defaultScene.rawValue,
            customWallpapers: [],
            direction: .next,
            experienceMode: .alienUFO
        ) == GardenWallpaperScene.alienCliffsideHomeGarden.rawValue)
        #expect(GardenSceneNavigator.adjacentSceneKey(
            from: GardenWallpaperScene.alienFloatingIslandSanctuary.rawValue,
            customWallpapers: [],
            direction: .next,
            experienceMode: .alienUFO
        ) == GardenWallpaperScene.alienCraterDome.rawValue)
    }

    @Test("experience mode switching hands off to a matching default scene")
    func experienceModeSwitchingHandsOffToMatchingDefaultScene() {
        #expect(GardenExperienceModeScenePolicy.sceneHandoffKey(
            currentSceneKey: GardenWallpaperScene.emptyConservatoryHall.rawValue,
            targetMode: .roomStudio
        ) == GardenWallpaperScene.roomModernBedroomCanvas.rawValue)

        #expect(GardenExperienceModeScenePolicy.sceneHandoffKey(
            currentSceneKey: GardenWallpaperScene.roomMediaDenCanvas.rawValue,
            targetMode: .garden
        ) == GardenWallpaperScene.emptyConservatoryHall.rawValue)

        #expect(GardenExperienceModeScenePolicy.sceneHandoffKey(
            currentSceneKey: GardenWallpaperScene.roomLoftHangoutCanvas.rawValue,
            targetMode: .roomStudio
        ) == nil)

        #expect(GardenExperienceModeScenePolicy.sceneHandoffKey(
            currentSceneKey: "custom-imported-bedroom",
            targetMode: .roomStudio
        ) == GardenWallpaperScene.roomModernBedroomCanvas.rawValue)

        #expect(GardenExperienceModeScenePolicy.sceneHandoffKey(
            currentSceneKey: GardenWallpaperScene.roomMediaDenCanvas.rawValue,
            targetMode: .alienUFO
        ) == GardenWallpaperScene.alienCraterDome.rawValue)

        #expect(GardenExperienceModeScenePolicy.sceneHandoffKey(
            currentSceneKey: GardenWallpaperScene.orbitalUfoTerrarium.rawValue,
            targetMode: .alienUFO
        ) == GardenWallpaperScene.alienCraterDome.rawValue)

        #expect(GardenExperienceModeScenePolicy.sceneHandoffKey(
            currentSceneKey: GardenWallpaperScene.alienCivicParkPlaza.rawValue,
            targetMode: .alienUFO
        ) == nil)
    }

    @Test("wallpaper updates are excluded from scene navigation")
    func wallpaperUpdatesAreExcludedFromSceneNavigation() {
        let custom = CustomWallpaperRecord(
            key: "custom-moon-gate",
            displayName: "Custom: Moon Gate",
            prompt: "moon gate",
            imageURL: URL(fileURLWithPath: "/tmp/custom-moon-gate.png"),
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let update = CustomWallpaperRecord(
            key: "edit-warmer-moon-gate",
            displayName: "Update 1: warmer moon gate",
            prompt: "warmer moon gate",
            imageURL: URL(fileURLWithPath: "/tmp/edit-warmer-moon-gate.png"),
            createdAt: Date(timeIntervalSince1970: 2),
            parentSceneKey: custom.key,
            editedFromKey: custom.key,
            editPrompt: "make it warmer",
            versionIndex: 1
        )

        #expect(GardenSceneNavigator.orderedSceneKeys(customWallpapers: [update, custom]).contains(custom.key))
        #expect(!GardenSceneNavigator.orderedSceneKeys(customWallpapers: [update, custom]).contains(update.key))
    }

    @Test("navigation from an edited wallpaper steps from its root scene")
    func navigationFromEditedWallpaperStepsFromItsRootScene() {
        let parent = GardenWallpaperScene.swedishPatioGarden.rawValue
        let update = CustomWallpaperRecord(
            key: "edit-warmer-patio",
            displayName: "Update 1: warmer patio",
            prompt: "warmer patio",
            imageURL: URL(fileURLWithPath: "/tmp/edit-warmer-patio.png"),
            createdAt: Date(timeIntervalSince1970: 2),
            parentSceneKey: parent,
            editedFromKey: parent,
            editPrompt: "make it warmer",
            versionIndex: 1
        )

        #expect(GardenSceneNavigator.adjacentSceneKey(
            from: update.key,
            customWallpapers: [update],
            direction: .next
        ) == nextBuiltIn(after: .swedishPatioGarden).rawValue)
    }

    @Test("legacy scene keys are canonicalized before stepping")
    func legacySceneKeysAreCanonicalizedBeforeStepping() {
        #expect(GardenSceneNavigator.adjacentSceneKey(
            from: "moonlit-glasshouse",
            customWallpapers: [],
            direction: .next
        ) == nextBuiltIn(after: .moonlitEmptyGlasshouse).rawValue)
    }

    private func nextBuiltIn(after scene: GardenWallpaperScene) -> GardenWallpaperScene {
        let scenes = GardenWallpaperScene.allCases
        let index = scenes.firstIndex(of: scene) ?? 0
        return scenes[(index + 1) % scenes.count]
    }
}
