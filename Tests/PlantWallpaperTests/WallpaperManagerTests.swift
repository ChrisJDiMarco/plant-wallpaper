import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Wallpaper manager")
struct WallpaperManagerTests {
    @Test("chosen wallpapers become custom scenes without touching desktop screens")
    func chosenWallpapersBecomeCustomScenes() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let sourceURL = fixture.directoryURL.appendingPathComponent("quiet stone room.png")
        try fixture.writePNG(to: sourceURL)

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )
        let record = try manager.createChosenWallpaperScene(from: sourceURL, to: [])

        #expect(record.key.hasPrefix("custom-quiet-stone-room-"))
        #expect(record.displayName == "Custom: quiet stone room")
        #expect(record.prompt == "Local wallpaper image: quiet stone room.png")
        #expect(manager.selectedWallpaperSceneKey == record.key)
        #expect(manager.customWallpapers == [record])
        #expect(FileManager.default.fileExists(atPath: record.imageURL.path))
    }

    @Test("repeated chosen wallpapers get distinct scene keys")
    func repeatedChosenWallpapersGetDistinctSceneKeys() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let sourceURL = fixture.directoryURL.appendingPathComponent("quiet stone room.png")
        try fixture.writePNG(to: sourceURL)

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )
        let firstRecord = try manager.createChosenWallpaperScene(from: sourceURL, to: [])
        let secondRecord = try manager.createChosenWallpaperScene(from: sourceURL, to: [])

        #expect(firstRecord.key != secondRecord.key)
        #expect(manager.customWallpapers.count == 2)
        #expect(manager.customWallpapers.map(\.key) == [secondRecord.key, firstRecord.key])
    }

    @Test("missing remembered custom scene falls back to default scene key")
    func missingRememberedCustomSceneFallsBackToDefaultSceneKey() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        fixture.defaults.set("custom-missing-scene", forKey: "PlantWallpaper.selectedWallpaperScene")

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )

        #expect(manager.selectedWallpaperSceneKey == GardenWallpaperScene.defaultScene.rawValue)
    }

    @Test("applying missing custom scene reports default applied scene")
    func applyingMissingCustomSceneReportsDefaultAppliedScene() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )

        let appliedSceneKey = manager.applyWallpaperSceneKey("custom-missing-scene", to: [])

        #expect(appliedSceneKey == GardenWallpaperScene.defaultScene.rawValue)
        #expect(manager.selectedWallpaperSceneKey == GardenWallpaperScene.defaultScene.rawValue)
    }

    @Test("applying unavailable alien scene falls back to ready alien artwork")
    func applyingUnavailableAlienSceneFallsBackToReadyAlienArtwork() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )

        let appliedSceneKey = manager.applyWallpaperSceneKey(
            GardenWallpaperScene.alienCraterGreenhouse.rawValue,
            to: []
        )

        #expect(appliedSceneKey == GardenWallpaperScene.alienCraterDome.rawValue)
        #expect(manager.selectedWallpaperSceneKey == GardenWallpaperScene.alienCraterDome.rawValue)
    }

    @Test("legacy moonlit scene key resolves to bundled moonlit glasshouse")
    func legacyMoonlitSceneKeyResolvesToBundledMoonlitGlasshouse() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        fixture.defaults.set("moonlit-glasshouse", forKey: "PlantWallpaper.selectedWallpaperScene")
        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )

        #expect(manager.selectedWallpaperSceneKey == GardenWallpaperScene.moonlitEmptyGlasshouse.rawValue)
        #expect(manager.thumbnailImage(forSceneKey: "moonlit-glasshouse") != nil)
    }

    @Test("selected wallpaper scene is mirrored for the screen saver")
    func selectedWallpaperSceneIsMirroredForScreenSaver() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let sharedSuiteName = "WallpaperManagerSharedDefaults-\(UUID().uuidString)"
        let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuiteName))
        defer {
            sharedDefaults.removePersistentDomain(forName: sharedSuiteName)
        }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults,
            sharedDefaults: sharedDefaults
        )
        let sceneKey = GardenWallpaperScene.brazilianRooftopGarden.rawValue

        let appliedSceneKey = manager.applyWallpaperSceneKey(sceneKey, to: [])

        #expect(appliedSceneKey == sceneKey)
        #expect(fixture.defaults.string(forKey: "PlantWallpaper.selectedWallpaperScene") == sceneKey)
        #expect(sharedDefaults.string(forKey: "PlantWallpaper.selectedWallpaperScene") == sceneKey)
    }

    @Test("custom wallpaper image path is mirrored for the screen saver")
    func customWallpaperImagePathIsMirroredForScreenSaver() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let sharedSuiteName = "WallpaperManagerSharedDefaults-\(UUID().uuidString)"
        let sharedDefaults = try #require(UserDefaults(suiteName: sharedSuiteName))
        defer {
            sharedDefaults.removePersistentDomain(forName: sharedSuiteName)
        }

        let sourceURL = fixture.directoryURL.appendingPathComponent("quiet stone room.png")
        try fixture.writePNG(to: sourceURL)

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults,
            sharedDefaults: sharedDefaults
        )

        let record = try manager.createChosenWallpaperScene(from: sourceURL, to: [])

        #expect(sharedDefaults.string(forKey: "PlantWallpaper.selectedWallpaperScene") == record.key)
        #expect(sharedDefaults.string(forKey: "PlantWallpaper.currentWallpaperImageURL") == record.imageURL.path)
        #expect(FileManager.default.fileExists(atPath: record.imageURL.path))
    }

    @Test("every bundled wallpaper scene has loadable artwork")
    func everyBundledWallpaperSceneHasLoadableArtwork() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )

        for scene in GardenWallpaperScene.allCases {
            #expect(manager.thumbnailImage(forSceneKey: scene.rawValue) != nil)
        }
    }

    @Test("built-in wallpaper renders use distinct scene artwork")
    func builtInWallpaperRendersUseDistinctSceneArtwork() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )
        let date = try #require(DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 11,
            hour: 14
        ).date)

        let renderedImages = try GardenWallpaperScene.allCases.map { scene in
            try manager.renderedLivingSceneWallpaperDataForSelfTest(
                scene: scene,
                size: NSSize(width: 360, height: 226),
                date: date
            )
        }

        #expect(Set(renderedImages).count == GardenWallpaperScene.allCases.count)
    }

    @Test("Brazilian rooftop scene loads six time-of-day artwork variants")
    func brazilianRooftopSceneLoadsSixTimeOfDayArtworkVariants() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )
        let calendar = Calendar.current
        let cases: [(hour: Int, suffix: String)] = [
            (6, "sunrise"),
            (9, "morning"),
            (12, "midday"),
            (16, "afternoon"),
            (19, "golden-hour"),
            (23, "night")
        ]

        for testCase in cases {
            let date = try #require(DateComponents(
                calendar: calendar,
                timeZone: TimeZone.current,
                year: 2026,
                month: 6,
                day: 11,
                hour: testCase.hour
            ).date)
            let expectedName = "brazilian-rooftop-garden-\(testCase.suffix)"

            #expect(manager.bundledSceneImageExistsForSelfTest(named: expectedName))
            #expect(manager.sceneImageNameForSelfTest(scene: .brazilianRooftopGarden, date: date) == expectedName)
            #expect(manager.sceneImageNameForSelfTest(scene: .swedishPatioGarden, date: date) == "swedish-patio-garden")
        }
    }

    @Test("deleting the selected custom wallpaper removes its record and files and reports selection loss")
    func deletingSelectedCustomWallpaperRemovesRecordAndFiles() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let sourceURL = fixture.directoryURL.appendingPathComponent("quiet stone room.png")
        try fixture.writePNG(to: sourceURL)

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )
        let record = try manager.createChosenWallpaperScene(from: sourceURL, to: [])
        #expect(manager.customWallpapers == [record])

        let wasSelected = try manager.deleteCustomWallpaper(key: record.key)

        #expect(wasSelected)
        #expect(manager.customWallpapers.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: record.imageURL.path))
        #expect(manager.selectedWallpaperSceneKey == GardenWallpaperScene.defaultScene.rawValue)
    }

    @Test("deleting an unselected custom wallpaper keeps the current selection")
    func deletingUnselectedCustomWallpaperKeepsSelection() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let sourceURL = fixture.directoryURL.appendingPathComponent("quiet stone room.png")
        try fixture.writePNG(to: sourceURL)

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )
        let firstRecord = try manager.createChosenWallpaperScene(from: sourceURL, to: [])
        let secondRecord = try manager.createChosenWallpaperScene(from: sourceURL, to: [])

        let wasSelected = try manager.deleteCustomWallpaper(key: firstRecord.key)

        #expect(!wasSelected)
        #expect(manager.customWallpapers == [secondRecord])
        #expect(manager.selectedWallpaperSceneKey == secondRecord.key)
        #expect(!FileManager.default.fileExists(atPath: firstRecord.imageURL.path))
        #expect(FileManager.default.fileExists(atPath: secondRecord.imageURL.path))
    }

    @Test("deleting an unknown custom wallpaper key is a safe no-op")
    func deletingUnknownCustomWallpaperKeyIsNoOp() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )

        let wasSelected = try manager.deleteCustomWallpaper(key: "custom-never-existed")

        #expect(!wasSelected)
        #expect(manager.customWallpapers.isEmpty)
    }

    @Test("wallpaper edit prompt preserves the current image and injects the requested change")
    func wallpaperEditPromptPreservesCurrentImageAndInjectsRequestedChange() {
        let prompt = WallpaperEditPrompt.masterPrompt(from: "make the marble floor warmer and add soft sunset light")

        #expect(prompt.contains("attached current WallpaperGarden desktop wallpaper"))
        #expect(prompt.contains("The attached image is the source of truth"))
        #expect(prompt.contains("Apply only these requested updates:"))
        #expect(prompt.contains("make the marble floor warmer and add soft sunset light"))
        #expect(prompt.contains("Preserve the prepared blank planting areas"))

        let fields = WallpaperImageEditOpenAIConfiguration.multipartFields(prompt: prompt)
        #expect(fields["model"] == WallpaperImageEditOpenAIConfiguration.model)
        #expect(fields["model"] == "gpt-image-2")
        #expect(fields["prompt"] == prompt)
        #expect(fields["size"] == GardenWallpaperGenerationQuality.twoK.openAISize)
        #expect(fields["quality"] == GardenWallpaperGenerationQuality.twoK.openAIQuality)
        #expect(fields["output_format"] == "png")
        #expect(fields["n"] == "1")

        let highResolutionFields = WallpaperImageEditOpenAIConfiguration.multipartFields(
            prompt: prompt,
            quality: .fourK
        )
        #expect(highResolutionFields["size"] == "3840x2160")
        #expect(highResolutionFields["quality"] == "high")

        let generationBody = WallpaperImageEditOpenAIConfiguration.requestBody(
            prompt: prompt,
            quality: .fourK
        )
        #expect(generationBody["model"] as? String == "gpt-image-2")
        #expect(generationBody["size"] as? String == "3840x2160")
        #expect(generationBody["quality"] as? String == "high")
        #expect(generationBody["output_format"] as? String == "png")
        #expect(generationBody["n"] as? Int == 1)
    }

    @Test("progression prompt uses profile and level ladder")
    func progressionPromptUsesProfileAndLevelLadder() {
        let progression = GardenSceneProgression(
            level: 19,
            profile: GardenProgressionProfile(
                lifestyleFantasy: "surreal founder estate",
                placeInWorld: "coastal Brazil",
                ageBracket: "30s",
                vibe: "warm retro futurist",
                avoidList: "cold corporate minimalism"
            )
        )

        let gardenPrompt = WallpaperProgressionPrompt.masterPrompt(
            progression: progression,
            targetLevel: 20,
            experienceMode: .garden
        )
        let roomPrompt = WallpaperProgressionPrompt.masterPrompt(
            progression: progression,
            targetLevel: 1,
            experienceMode: .roomStudio
        )

        #expect(gardenPrompt.contains("Level 20 of 20"))
        #expect(gardenPrompt.contains("brand-new garden lifestyle scene"))
        #expect(gardenPrompt.contains("surreal founder estate"))
        #expect(gardenPrompt.contains("coastal Brazil"))
        #expect(gardenPrompt.contains("sultan/lord fantasy scale"))
        #expect(gardenPrompt.contains("Preserve clean, believable planting zones"))
        #expect(!gardenPrompt.contains("Recreate the attached"))
        #expect(!gardenPrompt.contains("source of truth"))
        #expect(roomPrompt.contains("Level 1 of 20"))
        #expect(roomPrompt.contains("cardboard-box crash space"))
        #expect(roomPrompt.contains("Preserve open walls"))
    }

    @Test("progression prompt forces theme reinterpretation and a per-generation creative direction")
    func progressionPromptIsThemedAndCreative() {
        let progression = GardenSceneProgression(
            level: 5,
            profile: GardenProgressionProfile(
                lifestyleFantasy: "intergalactic warlord war garden",
                placeInWorld: "deep space mothership",
                ageBracket: "ageless conqueror",
                vibe: "dark chrome and bioluminescent alien flora",
                avoidList: "earth plants"
            )
        )

        let prompt = WallpaperProgressionPrompt.masterPrompt(
            progression: progression,
            targetLevel: 6,
            experienceMode: .garden,
            seed: 42
        )

        // Theme must drive every detail, not just sit in a profile block.
        #expect(prompt.contains("Theme is everything"))
        #expect(prompt.contains("intergalactic warlord war garden"))
        #expect(prompt.contains("the level only sets how grand")
            || prompt.contains("level only sets how grand"))
        // Each generation carries a distinct, labelled creative direction.
        #expect(prompt.contains("Creative direction for THIS generation"))
        #expect(prompt.contains("Signature move for Level 6"))
    }

    @Test("regenerating a level produces a different prompt each time but is seed-reproducible")
    func progressionPromptVariesPerGeneration() {
        let progression = GardenSceneProgression(
            level: 9,
            profile: GardenProgressionProfile(
                lifestyleFantasy: "1920s gangster speakeasy garden",
                placeInWorld: "Chicago",
                ageBracket: "mid 40s",
                vibe: "art deco noir",
                avoidList: "modern items"
            )
        )

        func prompt(seed: UInt64) -> String {
            WallpaperProgressionPrompt.masterPrompt(
                progression: progression,
                targetLevel: 10,
                experienceMode: .roomStudio,
                seed: seed
            )
        }

        // Same seed reproduces the prompt; different seeds re-roll the creative
        // direction so a re-generate is never "the same ol prompt".
        #expect(prompt(seed: 7) == prompt(seed: 7))
        let distinct = Set([1, 2, 3, 4, 5, 6, 7, 8].map { prompt(seed: UInt64($0)) })
        #expect(distinct.count >= 5)
    }

    @Test("level 1 progression starts from a shoddy origin instead of the current wallpaper")
    func progressionPromptStartsFromOriginStory() {
        let progression = GardenSceneProgression(
            level: 0,
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Tokyo cyberpunk netrunner lifestyle",
                placeInWorld: "rain-slick Neo-Tokyo",
                ageBracket: "mid 20s",
                vibe: "neon, broke, ambitious",
                avoidList: "polished penthouse at the start"
            )
        )

        let prompt = WallpaperProgressionPrompt.masterPrompt(
            progression: progression,
            targetLevel: 1,
            experienceMode: .roomStudio,
            seed: 42
        )

        #expect(prompt.contains("Do not recreate, reskin"))
        #expect(prompt.contains("bare-bones origin story"))
        #expect(prompt.contains("cardboard-box/tarp/mattress-on-floor energy"))
        #expect(!prompt.contains("natural next stage from the current image"))
    }

    @Test("smart lock wallpaper prompt preserves layout and excludes baked bugs")
    func smartLockWallpaperPromptPreservesLayoutAndExcludesBakedBugs() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 6, day: 13, hour: 21)
            .date!

        let prompt = SmartLockWallpaperPrompt.masterPrompt(at: date, calendar: calendar)

        #expect(prompt.contains("screenshot exported from the WallpaperGarden desktop wallpaper app"))
        #expect(prompt.contains("drag plants, room objects, radio companions, and other decorative PNG assets"))
        #expect(prompt.contains("generic composited app assets"))
        #expect(prompt.contains("as if it were a real scene photographed with a great camera and lens"))
        #expect(prompt.contains("physically integrated"))
        #expect(prompt.contains("Preserve the exact camera angle"))
        #expect(prompt.contains("cat if visible"))
        #expect(prompt.contains("nightfall"))
        #expect(prompt.contains("hyper-realistic natural Mac desktop wallpaper"))
        #expect(prompt.contains("do not bake extra flying insects"))
        #expect(prompt.contains("live animated bugs above this generated lock view"))
    }

    @Test("smart lock wallpaper reuses newest cached render for current scene")
    func smartLockWallpaperReusesNewestCachedRenderForCurrentScene() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )
        let directoryURL = manager.smartLockWallpaperDataDirectoryURL
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let currentSceneKey = GardenWallpaperScene.emptyConservatoryHall.rawValue
        let otherSceneKey = GardenWallpaperScene.swedishPatioGarden.rawValue
        let oldURL = directoryURL.appendingPathComponent("smart-lock-\(currentSceneKey)-old.png")
        let sceneURL = directoryURL.appendingPathComponent("smart-lock-\(currentSceneKey)-new.png")
        let otherSceneURL = directoryURL.appendingPathComponent("smart-lock-\(otherSceneKey)-newest.png")
        try fixture.writePNG(to: oldURL)
        try fixture.writePNG(to: sceneURL)
        try fixture.writePNG(to: otherSceneURL)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: oldURL.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 2)], ofItemAtPath: sceneURL.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 3)], ofItemAtPath: otherSceneURL.path)

        let reusedURL = try manager.applyLatestSmartLockWallpaper(to: [], sceneKey: currentSceneKey)

        #expect(reusedURL?.standardizedFileURL == sceneURL.standardizedFileURL)
        #expect(manager.currentWallpaperImageURL?.standardizedFileURL == sceneURL.standardizedFileURL)
        #expect(try manager.applyLatestSmartLockWallpaper(to: [], sceneKey: "missing-scene") == nil)
    }

    @Test("edited wallpapers create a newest-first version history with the original scene")
    func editedWallpapersCreateVersionHistoryWithOriginalScene() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )
        let sceneKey = GardenWallpaperScene.swedishPatioGarden.rawValue
        let firstRecord = try manager.storeEditedWallpaperForSelfTest(
            updatePrompt: "add warmer evening light",
            parentSceneKey: sceneKey,
            editedFromKey: sceneKey,
            imageData: try fixture.pngData(),
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let secondRecord = try manager.storeEditedWallpaperForSelfTest(
            updatePrompt: "turn the paving dark slate",
            parentSceneKey: sceneKey,
            editedFromKey: firstRecord.key,
            imageData: try fixture.pngData(),
            createdAt: Date(timeIntervalSince1970: 20)
        )

        let versions = manager.wallpaperVersions(forSceneKey: secondRecord.key)

        #expect(versions.map(\.key) == [
            secondRecord.key,
            firstRecord.key,
            GardenWallpaperScene.swedishPatioGarden.rawValue
        ])
        #expect(versions[0].title.hasPrefix("Version 2: Update 2:"))
        #expect(versions[0].tooltip == "turn the paving dark slate")
        #expect(versions[1].title.hasPrefix("Version 1: Update 1:"))
        #expect(versions[2].title == "Original: Swedish Patio Garden")
        #expect(versions[2].isOriginal)
        #expect(!versions[0].isOriginal)
    }

    @Test("normal version history hides progression generated scenes")
    func normalVersionHistoryHidesProgressionGeneratedScenes() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )
        let sceneKey = GardenWallpaperScene.swedishPatioGarden.rawValue
        let normalRecord = try manager.storeEditedWallpaperForSelfTest(
            updatePrompt: "add warmer evening light",
            parentSceneKey: sceneKey,
            editedFromKey: sceneKey,
            imageData: try fixture.pngData(),
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let progressionRecord = try manager.storeEditedWallpaperForSelfTest(
            updatePrompt: "Progression Level 1: Bare First Garden",
            parentSceneKey: sceneKey,
            editedFromKey: normalRecord.key,
            imageData: try fixture.pngData(),
            createdAt: Date(timeIntervalSince1970: 20)
        )

        #expect(manager.wallpaperVersions(forSceneKey: sceneKey).map(\.key) == [
            normalRecord.key,
            sceneKey
        ])
        #expect(manager.latestWallpaperKey(forSceneRootKey: sceneKey) == normalRecord.key)
        #expect(manager.wallpaperVersions(forSceneKey: sceneKey, includingProgression: true).map(\.key) == [
            progressionRecord.key,
            normalRecord.key,
            sceneKey
        ])
        #expect(manager.latestWallpaperKey(forSceneRootKey: sceneKey, includingProgression: true) == progressionRecord.key)
    }

    @Test("deleting wallpaper version removes history entry and files")
    func deletingWallpaperVersionRemovesHistoryEntryAndFiles() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )
        let sceneKey = GardenWallpaperScene.swedishPatioGarden.rawValue
        let firstRecord = try manager.storeEditedWallpaperForSelfTest(
            updatePrompt: "add warmer evening light",
            parentSceneKey: sceneKey,
            editedFromKey: sceneKey,
            imageData: try fixture.pngData(),
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let secondRecord = try manager.storeEditedWallpaperForSelfTest(
            updatePrompt: "turn the paving dark slate",
            parentSceneKey: sceneKey,
            editedFromKey: firstRecord.key,
            imageData: try fixture.pngData(),
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let sourceURL = secondRecord.imageURL
        let derivedURL = manager.wallpaperDataDirectoryURL
            .appendingPathComponent("custom-\(secondRecord.key)-cached.png")
        try fixture.writePNG(to: derivedURL)
        _ = manager.applyWallpaperSceneKey(secondRecord.key, to: [])

        let fallbackKey = try manager.deleteWallpaperVersion(key: secondRecord.key, moveToTrash: false)

        #expect(fallbackKey == firstRecord.key)
        #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(!FileManager.default.fileExists(atPath: derivedURL.path))
        #expect(manager.wallpaperVersions(forSceneKey: sceneKey).map(\.key) == [
            firstRecord.key,
            sceneKey
        ])
        #expect(manager.customWallpapers.contains { $0.key == firstRecord.key })
        #expect(!manager.customWallpapers.contains { $0.key == secondRecord.key })
    }

    @Test("deleting normal wallpaper version does not fall forward to progression")
    func deletingNormalWallpaperVersionDoesNotFallForwardToProgression() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )
        let sceneKey = GardenWallpaperScene.swedishPatioGarden.rawValue
        let normalRecord = try manager.storeEditedWallpaperForSelfTest(
            updatePrompt: "add warmer evening light",
            parentSceneKey: sceneKey,
            editedFromKey: sceneKey,
            imageData: try fixture.pngData(),
            createdAt: Date(timeIntervalSince1970: 10)
        )
        _ = try manager.storeEditedWallpaperForSelfTest(
            updatePrompt: "Progression Level 2: Designed Garden",
            parentSceneKey: sceneKey,
            editedFromKey: normalRecord.key,
            imageData: try fixture.pngData(),
            createdAt: Date(timeIntervalSince1970: 20)
        )
        _ = manager.applyWallpaperSceneKey(normalRecord.key, to: [])

        let fallbackKey = try manager.deleteWallpaperVersion(key: normalRecord.key, moveToTrash: false)

        #expect(fallbackKey == sceneKey)
    }

    @Test("scene roots resolve to the latest edited wallpaper")
    func sceneRootsResolveToLatestEditedWallpaper() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )
        let sceneKey = GardenWallpaperScene.swedishPatioGarden.rawValue
        let firstRecord = try manager.storeEditedWallpaperForSelfTest(
            updatePrompt: "add warmer evening light",
            parentSceneKey: sceneKey,
            editedFromKey: sceneKey,
            imageData: try fixture.pngData(),
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let secondRecord = try manager.storeEditedWallpaperForSelfTest(
            updatePrompt: "turn the paving dark slate",
            parentSceneKey: sceneKey,
            editedFromKey: firstRecord.key,
            imageData: try fixture.pngData(),
            createdAt: Date(timeIntervalSince1970: 20)
        )

        #expect(manager.wallpaperSceneRootKey(for: secondRecord.key) == sceneKey)
        #expect(manager.latestWallpaperKey(forSceneRootKey: sceneKey) == secondRecord.key)
        #expect(manager.customWallpaperSceneRoots.isEmpty)
    }
}

@Suite("Garden status menu title formatting")
struct GardenStatusMenuTitleFormattingTests {
    @Test("long selected plant status titles stay bounded")
    func longSelectedPlantStatusTitlesStayBounded() {
        let title = "Selected: Dogwood - Full canopy 9/10 - Photosynthesis - Summer growth - Moisture balanced - Next stage ~3h - Water ~19h - Balanced light - Ideal light - New planting"
        let compactTitle = GardenMenuTitleFormatter.compactStatusTitle(
            title,
            maxLength: GardenMenuTitleFormatter.selectedPlantTitleMaxLength
        )

        #expect(compactTitle.count <= GardenMenuTitleFormatter.selectedPlantTitleMaxLength)
        #expect(compactTitle.hasPrefix("Selected: Dogwood"))
        #expect(compactTitle.hasSuffix("..."))
        #expect(!compactTitle.hasSuffix("-..."))
    }

    @Test("short status titles are unchanged")
    func shortStatusTitlesAreUnchanged() {
        let title = "Wallpaper Scene"

        #expect(GardenMenuTitleFormatter.compactStatusTitle(title) == title)
    }

    @Test("live care header hides while growth is paused")
    func liveCareHeaderHidesWhileGrowthIsPaused() {
        #expect(!GardenStatusHeaderVisibility.hidesLiveCareHeader(isPaused: false))
        #expect(GardenStatusHeaderVisibility.hidesLiveCareHeader(isPaused: true))
        #expect(GardenStatusHeaderVisibility.hidesLiveCareHeader(isPaused: false, experienceMode: .roomStudio))
        #expect(GardenStatusHeaderVisibility.hidesLiveCareHeader(isPaused: false, experienceMode: .alienUFO))
    }
}

@Suite("Garden plant render posture")
struct GardenPlantRenderPostureTests {
    @Test("stressed and dead plants stay upright")
    func stressedAndDeadPlantsStayUpright() {
        let wiltedPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.45, y: 0.80),
            hydration: 0.02,
            health: 0.08
        )
        let deadPlant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.55, y: 0.80),
            hydration: 0,
            health: 0
        )

        #expect(PlantRenderPosture.rotationDegrees(for: wiltedPlant) == 0)
        #expect(PlantRenderPosture.rotationDegrees(for: deadPlant) == 0)
    }
}

@MainActor
@Suite("Garden status menu plant catalog")
struct GardenStatusMenuPlantCatalogTests {
    @Test("wallpaper scene catalog includes cozy apartment studio")
    func wallpaperSceneCatalogIncludesCozyApartmentStudio() {
        #expect(GardenWallpaperScene.allCases.contains(.cozyApartmentStudio))
        #expect(GardenWallpaperScene.cozyApartmentStudio.displayName == "Cozy Apartment Studio")
    }

    @Test("wallpaper scene catalog includes cottage backyard garden")
    func wallpaperSceneCatalogIncludesCottageBackyardGarden() {
        #expect(GardenWallpaperScene.allCases.contains(.cottageBackyardGarden))
        #expect(GardenWallpaperScene.cottageBackyardGarden.displayName == "Cottage Backyard Garden")
    }

    @Test("wallpaper scene catalog includes global garden set")
    func wallpaperSceneCatalogIncludesGlobalGardenSet() {
        let expectedScenes: [(GardenWallpaperScene, String)] = [
            (.chineseMountainMonkGarden, "Chinese Mountain Monk Garden"),
            (.swedishPatioGarden, "Swedish Patio Garden"),
            (.brazilianRooftopGarden, "Brazilian Rooftop Garden"),
            (.ancientEgyptianEstateGarden, "Ancient Egyptian Estate Garden"),
            (.texasRusticGarden, "Texas Rustic Garden"),
            (.starshipCommandBridge, "Starship Command Bridge")
        ]

        for (scene, displayName) in expectedScenes {
            #expect(GardenWallpaperScene.allCases.contains(scene))
            #expect(scene.displayName == displayName)
        }
    }

    @Test("wallpaper scene catalog includes room studio canvases")
    func wallpaperSceneCatalogIncludesRoomStudioCanvases() {
        let expectedScenes: [(GardenWallpaperScene, String)] = [
            (.roomModernBedroomCanvas, "Modern Bedroom Canvas"),
            (.roomLoftHangoutCanvas, "Loft Hangout Canvas"),
            (.roomMediaDenCanvas, "Media Den Canvas")
        ]

        #expect(GardenWallpaperScene.defaultRoomStudioScene == .roomModernBedroomCanvas)
        #expect(GardenWallpaperScene.scenes(for: .roomStudio) == expectedScenes.map(\.0))
        for (scene, displayName) in expectedScenes {
            #expect(GardenWallpaperScene.allCases.contains(scene))
            #expect(scene.displayName == displayName)
            #expect(scene.experienceMode == .roomStudio)
        }
    }

    @Test("wallpaper scene catalog includes alien UFO scene pack")
    func wallpaperSceneCatalogIncludesAlienUFOScenePack() {
        let expectedScenes: [(GardenWallpaperScene, String)] = [
            (.alienCraterGreenhouse, "Alien Crater Greenhouse"),
            (.orbitalUfoTerrarium, "Orbital UFO Terrarium"),
            (.bioluminescentExoplanetOasis, "Bioluminescent Exoplanet Oasis"),
            (.martianHydroponicDome, "Martian Hydroponic Dome"),
            (.alienCraterDome, "Alien Crater Dome"),
            (.alienCliffsideHomeGarden, "Alien Cliffside Home Garden"),
            (.alienCivicParkPlaza, "Alien Civic Park Plaza"),
            (.alienStarshipBotanyBay, "Alien Starship Botany Bay"),
            (.alienFloatingIslandSanctuary, "Alien Floating Island Sanctuary")
        ]

        #expect(GardenWallpaperScene.defaultAlienUFOScene == .alienCraterDome)
        #expect(GardenWallpaperScene.scenes(for: .alienUFO) == expectedScenes.map(\.0))
        #expect(GardenWallpaperScene.selectableScenes(for: .alienUFO) == [
            .alienCraterDome,
            .alienCliffsideHomeGarden,
            .alienCivicParkPlaza,
            .alienStarshipBotanyBay,
            .alienFloatingIslandSanctuary
        ])
        #expect(!GardenWallpaperScene.alienCraterGreenhouse.isSelectableScene)
        #expect(GardenWallpaperScene.alienCraterGreenhouse.unavailableSceneReason?.contains("coming soon") == true)
        for (scene, displayName) in expectedScenes {
            #expect(GardenWallpaperScene.allCases.contains(scene))
            #expect(scene.displayName == displayName)
            #expect(scene.experienceMode == .alienUFO)
            #expect(!scene.symbolName.isEmpty)
        }
    }

    @Test("specific plant menu shows full catalog with generated species asset-ready")
    func specificPlantMenuShowsFullCatalogWithGeneratedSpeciesAssetReady() {
        let library = PlantAssetLibrary()
        let entries = GardenPlantSpecificMenuCatalog.entries(
            sceneKey: "rooftop-seed-house",
            assetLibrary: library
        )

        #expect(entries.map(\.species) == PlantSpecies.allCases)
        let unavailableSpecies = Set(entries.filter { !$0.isAssetAvailable }.map(\.species))
        #expect(unavailableSpecies.isEmpty)
        #expect(PlantSpecies.artworkPlaceholderSpecies.isEmpty)
        #expect(entries.first { $0.species == .bonsai }?.isEnabled == true)
        #expect(entries.first { $0.species == .rose }?.isEnabled == true)
        #expect(entries.first { $0.species == .ivy }?.isAssetAvailable == true)
        #expect(entries.first { $0.species == .lavender }?.isAssetAvailable == true)
        #expect(entries.first { $0.species == .pineTree }?.isAssetAvailable == true)
        #expect(entries.first { $0.species == .pitcherPlant }?.isAssetAvailable == true)
        #expect(entries.first { $0.species == .ghostOrchid }?.isAssetAvailable == true)
        #expect(entries.first { $0.species == .ghostOrchid }?.disabledReason?.contains("needs high quality PNG growth assets") != true)
        #expect(entries.first { $0.species == .cucamelon }?.isAssetAvailable == true)
        #expect(entries.first { $0.species == .cucamelon }?.disabledReason?.contains("needs high quality PNG growth assets") != true)
    }

    @Test("specific plant menu disables displayable species that do not fit selected scene")
    func specificPlantMenuDisablesDisplayableSpeciesThatDoNotFitSelectedScene() {
        let entries = GardenPlantSpecificMenuCatalog.entries(
            sceneKey: "empty-desertarium",
            assetLibrary: PlantAssetLibrary()
        )

        #expect(entries.first { $0.species == .bonsai }?.isEnabled == true)
        #expect(entries.first { $0.species == .fern }?.isEnabled == false)
        #expect(entries.first { $0.species == .fern }?.disabledReason?.contains("Desertarium") == true)
    }

    @Test("category plant menus expose only species from that category")
    func categoryPlantMenusExposeOnlySpeciesFromThatCategory() {
        let treeEntries = GardenPlantSpecificMenuCatalog.entries(
            sceneKey: "cottage-backyard-garden",
            in: .tree,
            assetLibrary: PlantAssetLibrary()
        )
        let edibleEntries = GardenPlantSpecificMenuCatalog.entries(
            sceneKey: "cottage-backyard-garden",
            in: .edible,
            assetLibrary: PlantAssetLibrary()
        )

        #expect(!treeEntries.isEmpty)
        #expect(treeEntries.allSatisfy { $0.species.kind == .tree })
        #expect(treeEntries.map(\.species.displayName) == treeEntries.map(\.species.displayName).sorted())
        #expect(!edibleEntries.isEmpty)
        #expect(edibleEntries.allSatisfy { $0.species.kind == .edible })
    }

    @Test("category plant menus expose generated species as asset-ready rows")
    func categoryPlantMenusExposeGeneratedSpeciesAsAssetReadyRows() {
        let expectedGeneratedSpeciesByKind: [PlantKind: [PlantSpecies]] = [
            .flower: [
                .chocolateCosmos,
                .corpseFlower,
                .ghostOrchid,
                .jadeVine,
                .queenOfTheNight
            ],
            .tree: [
                .baobab,
                .dragonBloodTree,
                .monkeyPuzzleTree,
                .rainbowEucalyptus,
                .silkFlossTree
            ],
            .foliage: [
                .alocasiaDragonScale,
                .blackCoralColocasia,
                .prayerPlant,
                .ravenZZPlant,
                .staghornFern
            ],
            .meadow: [
                .alpineEdelweissMat,
                .blueStarCreeper,
                .corsicanMint,
                .redVeinSorrelPatch,
                .silverFallsDichondra
            ],
            .edible: [
                .alpineStrawberry,
                .cucamelon,
                .dragonFruitCactus,
                .glassGemCorn,
                .purpleBasil,
                .saffronCrocus,
                .shiso,
                .wasabi
            ]
        ]

        for (kind, expectedSpecies) in expectedGeneratedSpeciesByKind {
            let entries = GardenPlantSpecificMenuCatalog.entries(
                sceneKey: "cottage-backyard-garden",
                in: kind,
                assetLibrary: PlantAssetLibrary()
            )
            let generatedEntries = entries.filter { expectedSpecies.contains($0.species) }

            #expect(generatedEntries.map(\.species) == expectedSpecies)
            #expect(generatedEntries.allSatisfy { $0.isAssetAvailable })
            #expect(generatedEntries.allSatisfy {
                $0.disabledReason?.contains("needs high quality PNG growth assets") != true
            })
        }
    }

    @Test("category plant menus keep the simplified top-level planting order")
    func categoryPlantMenusKeepTheSimplifiedTopLevelPlantingOrder() {
        #expect(GardenPlantSpecificMenuCatalog.categoryOrder == [
            .flower,
            .tree,
            .foliage,
            .meadow,
            .edible
        ])
    }

    @Test("ambient sound menu keeps playback and layer controls above planting")
    func ambientSoundMenuKeepsPlaybackAndLayerControlsAbovePlanting() {
        #expect(GardenAmbientSoundMenuCatalog.entries.map(\.id) == [
            .master,
            .birdsong,
            .crickets,
            .wind,
            .rain,
            .water,
            .urbanMurmur,
            .roomTone,
            .cicadas,
            .chimes,
            .smallWildlife,
            .roomLife,
            .electronics,
            .alienFauna,
            .habitatHum,
            .crystallineShimmer,
            .lowRumble
        ])
        #expect(GardenAmbientSoundMenuCatalog.entries.first?.title == "Environmental Sounds")
        #expect(GardenAmbientSoundMenuCatalog.entries[1].title == "Birdsong")
        #expect(GardenAmbientSoundMenuCatalog.entries[2].title == "Crickets")
        #expect(GardenAmbientSoundMenuCatalog.entries.map(\.title).contains("Alien Fauna"))
        #expect(GardenAmbientSoundMenuCatalog.entries.map(\.title).contains("Room Life"))
    }

    @Test("radio companion menu exposes every station object")
    func radioCompanionMenuExposesEveryStationObject() {
        let entries = GardenRadioCompanionMenuCatalog.entries

        #expect(entries.map(\.companion) == GardenRadioCompanion.allCases)
        #expect(entries.map(\.title).contains("Toy DeLorean - 80s Forever"))
        #expect(entries.map(\.title).contains("Bigfoot Field Radio - Planet Pootwaddle"))
        #expect(entries.map(\.title).contains("Mini UFO Terrarium - 1 Radio Space"))
        #expect(entries.map(\.title).contains("Chill Garden Gnome - Roots Legacy"))
        #expect(entries.map(\.title).contains("Grey Alien Gardener - Intergalactic"))
        #expect(entries.allSatisfy { !$0.toolTip.isEmpty })
    }

    @Test("category random planting availability honors the current scene")
    func categoryRandomPlantingAvailabilityHonorsCurrentScene() {
        let library = PlantAssetLibrary()

        #expect(GardenPlantSpecificMenuCatalog.hasEnabledSpecies(
            sceneKey: "empty-desertarium",
            in: .edible,
            assetLibrary: library
        ))
        let moonlitEdibles = GardenPlantSpecificMenuCatalog.entries(
            sceneKey: "moonlit-glasshouse",
            in: .edible,
            assetLibrary: library
        )
        #expect(moonlitEdibles.first { $0.species == .wasabi }?.isEnabled == true)
        #expect(moonlitEdibles.first { $0.species == .determinateTomato }?.isEnabled == false)
    }
}

@MainActor
@Suite("Garden radio companion assets")
struct GardenRadioCompanionAssetTests {
    @Test("every radio companion has a high fidelity alpha PNG asset")
    func everyRadioCompanionHasHighFidelityAlphaPNGAsset() throws {
        let library = GardenRadioCompanionAssetLibrary()

        for companion in GardenRadioCompanion.allCases {
            let image = try #require(library.image(for: companion))
            let mask = try #require(PlantArtworkAlphaMask(image: image))

            #expect(image.size.width >= 512)
            #expect(image.size.height >= 512)
            #expect(mask.hasVisiblePixel(nearU: mask.opaqueCentroid.u, v: mask.opaqueCentroid.v, slopU: 0.02, slopV: 0.02))
        }
    }
}

@MainActor
@Suite("Plant asset library")
struct PlantAssetLibraryTests {
    @Test("bundled staged growth assets are readable")
    func bundledStagedGrowthAssetsAreReadable() throws {
        let stagedAssetURLs = bundledPlantAssetURLs()
            .filter { $0.deletingPathExtension().lastPathComponent.contains("-stage-") }
        let stagedAssetNames = Set(stagedAssetURLs.map(\.lastPathComponent))
        let expectedAssetNames = try sourceBackedStageAssetNames()

        #expect(!stagedAssetURLs.isEmpty)
        #expect(stagedAssetNames == expectedAssetNames)

        for assetURL in stagedAssetURLs {
            #expect(NSImage(contentsOf: assetURL) != nil, "\(assetURL.lastPathComponent) should load")
        }
    }

    @Test("any staged artwork is displayable while complete growth sets remain tracked")
    func anyStagedArtworkIsDisplayableWhileCompleteGrowthSetsRemainTracked() {
        let library = PlantAssetLibrary()

        #expect(library.hasDisplayableAsset(for: .fern))
        #expect(library.hasDisplayableAsset(for: .bonsai))
        #expect(library.hasDisplayableAsset(for: .rose))
        #expect(library.hasDisplayableAsset(for: .ivy))
        #expect(library.hasDisplayableAsset(for: .lavender))
        #expect(library.hasDisplayableAsset(for: .pineTree))
        #expect(library.hasDisplayableAsset(for: .pitcherPlant))
        #expect(library.hasDisplayableAsset(for: .determinateTomato))
        #expect(library.hasDisplayableAsset(for: .sweetPepper))
        #expect(library.hasDisplayableAsset(for: .cucumberVine))
        #expect(library.hasDisplayableAsset(for: .rosemary))
        #expect(library.hasDisplayableAsset(for: .sage))
        #expect(library.hasCompleteGrowthAssetSet(for: .fern))
        #expect(library.hasCompleteGrowthAssetSet(for: .bonsai))
        #expect(library.hasCompleteGrowthAssetSet(for: .rose))
        #expect(!library.hasCompleteGrowthAssetSet(for: .ivy))
        #expect(!library.hasCompleteGrowthAssetSet(for: .lavender))
        #expect(!library.hasCompleteGrowthAssetSet(for: .pineTree))
        #expect(!library.hasCompleteGrowthAssetSet(for: .pitcherPlant))
        #expect(!library.hasCompleteGrowthAssetSet(for: .determinateTomato))
        #expect(!library.hasCompleteGrowthAssetSet(for: .sweetPepper))
        #expect(!library.hasCompleteGrowthAssetSet(for: .cucumberVine))
        #expect(!library.hasCompleteGrowthAssetSet(for: .rosemary))
        #expect(!library.hasCompleteGrowthAssetSet(for: .sage))
        #expect(library.image(for: .pitcherPlant, stageIndex: 9) != nil)
        #expect(library.image(for: .determinateTomato, stageIndex: 9) != nil)
    }

    @Test("every artwork-ready species has mature final stage artwork")
    func everyArtworkReadySpeciesHasMatureFinalStageArtwork() {
        let library = PlantAssetLibrary()

        for species in PlantSpecies.defaultGardenSpecies {
            #expect(
                library.image(for: species, stageIndex: 9) != nil,
                "\(species.displayName) should have stage-09 mature artwork"
            )
        }
    }

    @Test("partial staged species start at beginning and advance through available artwork")
    func partialStagedSpeciesStartAtBeginningAndAdvanceThroughAvailableArtwork() {
        let library = PlantAssetLibrary()

        #expect(library.image(for: .ivy, stageIndex: 5) != nil)
        #expect(library.image(for: .lavender, stageIndex: 6) != nil)
        #expect(library.image(for: .pitcherPlant, stageIndex: 0) != nil)
        #expect(library.hasDisplayableAsset(for: .ivy))
        #expect(library.hasDisplayableAsset(for: .lavender))
        #expect(library.hasDisplayableAsset(for: .pitcherPlant))
        #expect(library.hasDisplayableAsset(for: .determinateTomato))
        #expect(library.hasDisplayableAsset(for: .rosemary))
        #expect(library.initialGrowth(for: .fern) == 0.08)
        #expect(library.initialGrowth(for: .ivy) == 0.08)
        #expect(library.initialGrowth(for: .pitcherPlant) == 0.08)
        #expect(library.initialGrowth(for: .determinateTomato) == 0.08)
        #expect(library.nextGrowthMilestone(for: .pitcherPlant, growth: 0.08) == 0.2)
        #expect(library.nextGrowthMilestone(for: .pitcherPlant, growth: 0.2) == 0.5)
        #expect(library.nextGrowthMilestone(for: .pitcherPlant, growth: 0.5) == 1.0)
        #expect(library.nextGrowthMilestone(for: .pitcherPlant, growth: 1.0) == nil)
        #expect(library.displayableSpecies(in: .tree).contains(.bonsai))
        #expect(library.displayableSpecies(in: .flower).contains(.rose))
        #expect(library.displayableSpecies(in: .foliage).contains(.pitcherPlant))
        #expect(library.displayableSpecies(in: .edible).contains(.determinateTomato))
        #expect(library.displayableSpecies(in: .edible).contains(.sage))
    }

    private func bundledPlantAssetURLs() -> [URL] {
        let rootURLs = Bundle.module.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []
        let nestedURLs = Bundle.module.urls(forResourcesWithExtension: "png", subdirectory: "PlantAssets") ?? []
        return Array(Set(rootURLs + nestedURLs))
    }

    private func sourceBackedStageAssetNames() throws -> Set<String> {
        let repositoryRootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceDirectoryURL = repositoryRootURL.appendingPathComponent("Generated/AIStageSources")
        let sourceURLs = try FileManager.default.contentsOfDirectory(
            at: sourceDirectoryURL,
            includingPropertiesForKeys: nil
        )

        return Set(sourceURLs.compactMap { sourceURL in
            let name = sourceURL.deletingPathExtension().lastPathComponent
            guard name.hasSuffix("-source"), name.contains("-stage-") else {
                return nil
            }
            return String(name.dropLast("-source".count)) + ".png"
        })
    }
}

@MainActor
@Suite("Garden store scene switching")
struct GardenStoreSceneSwitchingTests {
    @Test("partial PNG assets are retained in scenes")
    func partialPNGAssetsAreRetainedInScenes() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let partialAssetPlant = Plant(
            species: .pitcherPlant,
            screenIndex: 0,
            position: GardenPoint(x: 0.40, y: 0.72)
        )
        let supportedPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.58, y: 0.78)
        )
        let store = GardenStore(
            state: GardenState(plants: [partialAssetPlant, supportedPlant]),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL)
        )
        store.setSelectedPlant(partialAssetPlant.id)
        let counter = GardenStoreNotificationCounter(store: store)

        store.removePlantsWithoutDisplayableAssets()

        #expect(store.state.plants.map(\.species) == [.pitcherPlant, .fern])
        #expect(store.selectedPlantID == partialAssetPlant.id)
        #expect(counter.snapshots.isEmpty)
    }

    @Test("nourishing a partial staged plant jumps through available artwork stages")
    func nourishingPartialStagedPlantJumpsThroughAvailableArtworkStages() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let store = GardenStore(
            state: GardenState(plants: []),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL)
        )

        store.addPlant(species: .pitcherPlant, screenIndex: 0, position: GardenPoint(x: 0.45, y: 0.72))
        #expect(store.selectedPlant?.growth == 0.08)

        store.nourishSelectedPlant()
        #expect(store.selectedPlant?.growth == 0.2)

        store.nourishSelectedPlant()
        #expect(store.selectedPlant?.growth == 0.5)

        store.nourishSelectedPlant()
        #expect(store.selectedPlant?.growth == 1.0)
    }

    @Test("displayable plant positions survive scene-switch cleanup exactly")
    func displayablePlantPositionsSurviveSceneSwitchCleanupExactly() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        // This cleanup runs after every scene switch; it must never move
        // plants from where the operator placed them.
        let edgePlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.94, y: 0.52)
        )
        let store = GardenStore(
            state: GardenState(plants: [edgePlant]),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL)
        )

        store.removePlantsWithoutDisplayableAssets()

        let keptPlant = try #require(store.state.plants.first)
        #expect(keptPlant.id == edgePlant.id)
        #expect(keptPlant.position == GardenPoint(x: 0.94, y: 0.52))
    }

    @Test("pruning the render cache keeps the newest PNGs and spares manifests")
    func pruningRenderCacheKeepsNewestPNGsAndSparesManifests() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let manager = WallpaperManager(
            baseDirectoryURL: fixture.directoryURL,
            defaults: fixture.defaults
        )
        let wallpaperDirectory = manager.wallpaperDataDirectoryURL
        try FileManager.default.createDirectory(at: wallpaperDirectory, withIntermediateDirectories: true)

        for index in 0..<6 {
            let renderURL = wallpaperDirectory.appendingPathComponent("render-\(index).png")
            try fixture.writePNG(to: renderURL)
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSinceNow: TimeInterval(index - 10) * 60)],
                ofItemAtPath: renderURL.path
            )
        }
        let manifestURL = wallpaperDirectory.appendingPathComponent("previous-wallpapers.json")
        try Data("[]".utf8).write(to: manifestURL)

        manager.pruneRenderedWallpaperCache(keepingNewest: 2)

        let remainingNames = try Set(
            FileManager.default.contentsOfDirectory(at: wallpaperDirectory, includingPropertiesForKeys: nil)
                .map(\.lastPathComponent)
        )
        #expect(remainingNames.contains("render-5.png"))
        #expect(remainingNames.contains("render-4.png"))
        #expect(remainingNames.contains("previous-wallpapers.json"))
        #expect(!remainingNames.contains("render-0.png"))
        #expect(remainingNames.count == 3)
    }

    @Test("user-arranged scenes survive composition-version bumps untouched")
    func userArrangedScenesSurviveCompositionVersionBumps() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let placedPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.31, y: 0.64)
        )
        // An outdated composition version simulates a future bump of
        // GardenComposition.currentVersion over a hand-arranged save.
        let savedState = GardenState(
            compositionVersion: 1,
            isUserArranged: true,
            plants: [placedPlant]
        )
        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        try persistence.save(savedState, sceneKey: "empty-conservatory-hall")

        let store = GardenStore(
            state: GardenState.defaultGarden(screenCount: 1),
            persistence: persistence,
            activeSceneKey: "rooftop-seed-house"
        )
        store.switchGardenScene(to: "empty-conservatory-hall", screenCount: 1)

        #expect(store.state.plants.count == 1)
        let restoredPlant = try #require(store.state.plants.first)
        #expect(restoredPlant.id == placedPlant.id)
        #expect(restoredPlant.position == GardenPoint(x: 0.31, y: 0.64))
    }

    @Test("untouched scenes still receive composition upgrades")
    func untouchedScenesStillReceiveCompositionUpgrades() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let savedState = GardenState(
            compositionVersion: 1,
            isUserArranged: false,
            plants: [Plant(species: .fern, screenIndex: 0, position: GardenPoint(x: 0.31, y: 0.64))]
        )
        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        try persistence.save(savedState, sceneKey: "empty-conservatory-hall")

        let store = GardenStore(
            state: GardenState.defaultGarden(screenCount: 1),
            persistence: persistence,
            activeSceneKey: "rooftop-seed-house"
        )
        store.switchGardenScene(to: "empty-conservatory-hall", screenCount: 1)

        #expect(store.state.plants.count == PlantSpecies.defaultGardenSpecies.count)
        #expect(store.state.compositionVersion == GardenComposition.currentVersion)
    }

    @Test("switching to a brand-new garden scene starts empty, not pre-planted")
    func switchingToBrandNewGardenSceneStartsEmpty() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        // No save file exists for the destination scene, so it opens fresh.
        // Opening a scene the operator has never set up must not dump the
        // starter garden into it - it is a blank canvas to compose by hand.
        let store = GardenStore(
            state: GardenState.defaultGarden(screenCount: 1),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL),
            activeSceneKey: "empty-conservatory-hall"
        )
        store.switchGardenScene(to: "rooftop-seed-house", screenCount: 1)

        #expect(store.state.plants.isEmpty)
        // Already at the current composition version, so the upgrade backfill
        // never repopulates the empty scene.
        #expect(store.state.compositionVersion == GardenComposition.currentVersion)
    }

    @Test("setting the same selected plant does not repost changes")
    func settingSameSelectedPlantDoesNotRepostChanges() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.26, y: 0.80),
            growth: 0.42,
            hydration: 0.76,
            health: 0.82
        )
        let store = GardenStore(
            state: GardenState(plants: [plant]),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL)
        )
        store.setSelectedPlant(plant.id)
        let counter = GardenStoreNotificationCounter(store: store)

        store.setSelectedPlant(plant.id)
        #expect(counter.count == 0)

        store.setSelectedPlant(nil)
        #expect(counter.count == 1)

        store.setSelectedPlant(nil)
        #expect(counter.count == 1)
    }

    @Test("no-op store state replacements do not repost changes")
    func noOpStoreStateReplacementsDoNotRepostChanges() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let plant = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.42, y: 0.78),
            growth: 0.50,
            hydration: 0.90,
            health: 0.80
        )
        let state = GardenState(lastUpdatedAt: Date(timeIntervalSince1970: 2_000), plants: [plant])
        let store = GardenStore(
            state: state,
            persistence: GardenPersistence(directoryURL: fixture.directoryURL),
            globalDefaults: fixture.defaults
        )
        let counter = GardenStoreNotificationCounter(store: store)

        store.waterThirstyPlants()

        #expect(store.state == state)
        #expect(counter.count == 0)
    }

    @Test("stale direct care commands do not replace valid selection with missing ids")
    func staleDirectCareCommandsDoNotReplaceValidSelectionWithMissingIDs() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let plant = Plant(
            species: .jasmine,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.78),
            growth: 0.62,
            hydration: 0.70,
            health: 0.80
        )
        let state = GardenState(lastUpdatedAt: Date(timeIntervalSince1970: 2_060), plants: [plant])
        let store = GardenStore(
            state: state,
            persistence: GardenPersistence(directoryURL: fixture.directoryURL),
            globalDefaults: fixture.defaults
        )
        store.setSelectedPlant(plant.id)
        let counter = GardenStoreNotificationCounter(store: store)
        let missingID = UUID()

        store.prunePlant(id: missingID)
        #expect(store.selectedPlantID == plant.id)
        #expect(store.selectedPlant?.id == plant.id)
        #expect(store.state == state)
        #expect(counter.count == 0)

        store.nourishPlant(id: missingID)
        #expect(store.selectedPlantID == plant.id)
        #expect(store.selectedPlant?.id == plant.id)
        #expect(store.state == state)
        #expect(counter.count == 0)
    }

    @Test("setting a missing selected plant clears selection")
    func settingMissingSelectedPlantClearsSelection() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.25, y: 0.82),
            growth: 0.50,
            hydration: 0.75,
            health: 0.84
        )
        let store = GardenStore(
            state: GardenState(plants: [plant]),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL)
        )
        store.setSelectedPlant(plant.id)
        let counter = GardenStoreNotificationCounter(store: store)

        store.setSelectedPlant(UUID())

        #expect(store.selectedPlantID == nil)
        #expect(store.selectedPlant == nil)
        #expect(counter.count == 1)

        store.setSelectedPlant(UUID())
        #expect(counter.count == 1)
    }

    @Test("removing the selected plant publishes one coherent deselected snapshot")
    func removingSelectedPlantPublishesOneCoherentDeselectedSnapshot() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let plant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.46, y: 0.78),
            growth: 0.62,
            hydration: 0.65,
            health: 0.80
        )
        let store = GardenStore(
            state: GardenState(plants: [plant]),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL)
        )
        store.setSelectedPlant(plant.id)
        let counter = GardenStoreNotificationCounter(store: store)

        store.removeSelectedPlant()

        #expect(store.selectedPlantID == nil)
        #expect(store.selectedPlant == nil)
        #expect(store.state.plants.isEmpty)
        #expect(counter.snapshots == [
            GardenStoreNotificationSnapshot(selectedPlantID: nil, selectedPlantExists: false, plantCount: 0)
        ])
    }

    @Test("recommended cleanup of selected dead plant publishes one coherent deselected snapshot")
    func recommendedCleanupOfSelectedDeadPlantPublishesOneCoherentDeselectedSnapshot() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let deadPlant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.46, y: 0.78),
            growth: 0.62,
            hydration: 0,
            health: 0,
            bloomProgress: 0,
            diedAt: Date(timeIntervalSince1970: 2_100)
        )
        let store = GardenStore(
            state: GardenState(plants: [deadPlant]),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL)
        )
        store.setSelectedPlant(deadPlant.id)
        let counter = GardenStoreNotificationCounter(store: store)

        store.performRecommendedCare(screenIndex: 0)

        #expect(store.selectedPlantID == nil)
        #expect(store.selectedPlant == nil)
        #expect(store.state.plants.isEmpty)
        #expect(counter.snapshots == [
            GardenStoreNotificationSnapshot(selectedPlantID: nil, selectedPlantExists: false, plantCount: 0)
        ])
    }

    @Test("adding a plant publishes one coherent selected snapshot")
    func addingPlantPublishesOneCoherentSelectedSnapshot() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let store = GardenStore(
            state: GardenState(plants: []),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL)
        )
        let counter = GardenStoreNotificationCounter(store: store)

        store.addPlant(
            species: .jasmine,
            screenIndex: 0,
            position: GardenPoint(x: 0.62, y: 0.78)
        )

        let selectedPlant = try #require(store.selectedPlant)
        #expect(selectedPlant.species == .jasmine)
        #expect(selectedPlant.growth == PlantAssetLibrary.shared.initialGrowth(for: .jasmine))
        #expect(store.state.plants.count == 1)
        #expect(counter.snapshots == [
            GardenStoreNotificationSnapshot(
                selectedPlantID: selectedPlant.id,
                selectedPlantExists: true,
                plantCount: 1,
                firstPlantID: selectedPlant.id
            )
        ])
    }

    @Test("cloning selected plant publishes one coherent selected copy snapshot")
    func cloningSelectedPlantPublishesOneCoherentSelectedCopySnapshot() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }
        let plant = Plant(
            species: .ornamentalGrass,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.78),
            growth: 0.82,
            hydration: 0.74,
            health: 0.80,
            bloomProgress: 0.36,
            swaySeed: 12,
            scale: 1.42
        )
        let store = GardenStore(
            state: GardenState(plants: [plant]),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL)
        )
        store.setSelectedPlant(plant.id)
        let counter = GardenStoreNotificationCounter(store: store)

        store.cloneSelectedPlant()

        let selectedPlant = try #require(store.selectedPlant)
        #expect(store.state.plants.count == 2)
        #expect(selectedPlant.id != plant.id)
        #expect(selectedPlant.species == plant.species)
        #expect(selectedPlant.scale == plant.scale)
        #expect(selectedPlant.position != plant.position)
        #expect(counter.snapshots == [
            GardenStoreNotificationSnapshot(
                selectedPlantID: selectedPlant.id,
                selectedPlantExists: true,
                plantCount: 2,
                firstPlantID: plant.id
            )
        ])
    }

    @Test("save failure posts error state changes")
    func saveFailurePostsErrorStateChanges() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let blockedURL = fixture.directoryURL.appendingPathComponent("blocked-garden-store")
        try Data("not a directory".utf8).write(to: blockedURL)
        let store = GardenStore(
            state: GardenState(plants: []),
            persistence: GardenPersistence(directoryURL: blockedURL)
        )
        let counter = GardenStoreNotificationCounter(store: store)

        store.save()

        #expect(store.lastError != nil)
        #expect(counter.count == 1)
        #expect(counter.snapshots.last?.lastError == store.lastError)
    }

    @Test("save recovery posts cleared error state")
    func saveRecoveryPostsClearedErrorState() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let blockedURL = fixture.directoryURL.appendingPathComponent("recovering-garden-store")
        try Data("not a directory".utf8).write(to: blockedURL)
        let store = GardenStore(
            state: GardenState(plants: []),
            persistence: GardenPersistence(directoryURL: blockedURL)
        )
        let counter = GardenStoreNotificationCounter(store: store)

        store.save()
        let failureSnapshot = try #require(counter.snapshots.last)
        #expect(failureSnapshot.lastError != nil)

        try FileManager.default.removeItem(at: blockedURL)
        try FileManager.default.createDirectory(at: blockedURL, withIntermediateDirectories: true)
        store.save()

        #expect(store.lastError == nil)
        #expect(counter.count == 2)
        #expect(counter.snapshots.last?.lastError == nil)
    }

    @Test("screen configuration changes repair and persist the active scene")
    func screenConfigurationChangesRepairAndPersistActiveScene() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let scenePlant = Plant(
            species: .fern,
            screenIndex: 3,
            position: GardenPoint(x: 0.28, y: 0.80),
            growth: 0.46,
            hydration: 0.70,
            health: 0.82
        )
        let store = GardenStore(
            state: GardenState(plants: [scenePlant]),
            persistence: persistence,
            activeSceneKey: "empty-conservatory-hall"
        )

        store.handleScreenConfigurationChange(screenCount: 1)

        let visiblePlant = try #require(store.state.plants.first)
        #expect(visiblePlant.id == scenePlant.id)
        #expect(visiblePlant.screenIndex == 0)
        #expect(visiblePlant.position == scenePlant.position)

        let persistedScene = try #require(try persistence.load(sceneKey: "empty-conservatory-hall"))
        #expect(persistedScene.plants.first?.screenIndex == 0)
    }

    @Test("switching scenes keeps loaded plants on visible screens")
    func switchingScenesKeepsLoadedPlantsOnVisibleScreens() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let scenePlant = Plant(
            species: .pineTree,
            screenIndex: 2,
            position: GardenPoint(x: 0.62, y: 0.70),
            growth: 0.58,
            hydration: 0.72,
            health: 0.80
        )
        let savedScene = GardenState(plants: [scenePlant])
        try persistence.save(savedScene, sceneKey: "rooftop-seed-house")

        let store = GardenStore(
            state: GardenState(plants: []),
            persistence: persistence,
            activeSceneKey: "empty-conservatory-hall"
        )

        store.switchGardenScene(to: "rooftop-seed-house", screenCount: 1)

        let loadedPlant = try #require(store.state.plants.first)
        #expect(loadedPlant.id == scenePlant.id)
        #expect(loadedPlant.screenIndex == 0)
        #expect(loadedPlant.position == scenePlant.position)

        let persistedScene = try #require(try persistence.load(sceneKey: "rooftop-seed-house"))
        #expect(persistedScene.plants.first?.screenIndex == 0)
    }

    @Test("switching scenes publishes one coherent loaded scene snapshot")
    func switchingScenesPublishesOneCoherentLoadedSceneSnapshot() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let currentPlant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.25, y: 0.78),
            growth: 0.54,
            hydration: 0.62,
            health: 0.78
        )
        let nextScenePlant = Plant(
            species: .pineTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.68, y: 0.64),
            growth: 0.72,
            hydration: 0.80,
            health: 0.86
        )
        try persistence.save(GardenState(plants: [nextScenePlant]), sceneKey: "rooftop-seed-house")
        let store = GardenStore(
            state: GardenState(plants: [currentPlant]),
            persistence: persistence,
            activeSceneKey: "empty-conservatory-hall"
        )
        store.setSelectedPlant(currentPlant.id)
        let counter = GardenStoreNotificationCounter(store: store)

        store.switchGardenScene(to: "rooftop-seed-house", screenCount: 1)

        #expect(store.activeSceneKey == "rooftop-seed-house")
        #expect(store.selectedPlantID == nil)
        #expect(store.state.plants.map(\.id) == [nextScenePlant.id])
        #expect(counter.snapshots == [
            GardenStoreNotificationSnapshot(
                activeSceneKey: "rooftop-seed-house",
                selectedPlantID: nil,
                selectedPlantExists: false,
                plantCount: 1,
                firstPlantID: nextScenePlant.id
            )
        ])
    }

    @Test("switching to legacy scene publishes one upgraded scene snapshot")
    func switchingToLegacyScenePublishesOneUpgradedSceneSnapshot() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let legacyPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.20, y: 0.80),
            growth: 0.46,
            hydration: 0.68,
            health: 0.82
        )
        let legacyScene = GardenState(
            compositionVersion: GardenComposition.currentVersion - 1,
            plants: [legacyPlant]
        )
        try persistence.save(legacyScene, sceneKey: "empty-conservatory-hall")
        let store = GardenStore(
            state: GardenState(plants: []),
            persistence: persistence,
            activeSceneKey: "rooftop-seed-house"
        )
        let counter = GardenStoreNotificationCounter(store: store)

        store.switchGardenScene(to: "empty-conservatory-hall", screenCount: 1)

        #expect(counter.count == 1)
        #expect(store.activeSceneKey == "empty-conservatory-hall")
        #expect(store.state.compositionVersion == GardenComposition.currentVersion)
        #expect(store.state.plants.contains { $0.id == legacyPlant.id })
        #expect(counter.snapshots.last?.activeSceneKey == "empty-conservatory-hall")
        #expect(counter.snapshots.last?.plantCount == store.state.plants.count)
    }

    @Test("manual placement in legacy scene persists exactly after switching away and back")
    func manualPlacementInLegacyScenePersistsExactlyAfterSwitchingAwayAndBack() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let originalPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.20, y: 0.80),
            growth: 0.46,
            hydration: 0.68,
            health: 0.82
        )
        let legacyScene = GardenState(
            compositionVersion: GardenComposition.currentVersion - 1,
            plants: [originalPlant]
        )
        try persistence.save(GardenState(plants: []), sceneKey: "empty-conservatory-hall")
        let store = GardenStore(
            state: legacyScene,
            persistence: persistence,
            activeSceneKey: "rooftop-seed-house"
        )
        store.setSelectedPlant(originalPlant.id)
        let placedPosition = GardenPoint(x: 0.91, y: 0.23)

        store.moveSelectedPlant(to: placedPosition, screenIndex: 0)
        store.save()
        store.switchGardenScene(to: "empty-conservatory-hall", screenCount: 1)
        store.switchGardenScene(to: "rooftop-seed-house", screenCount: 1)

        let restoredPlant = try #require(store.state.plants.first { $0.id == originalPlant.id })
        #expect(restoredPlant.position == placedPosition)
        #expect(restoredPlant.screenIndex == 0)
        #expect(store.state.compositionVersion == GardenComposition.currentVersion)

        let persistedScene = try #require(try persistence.load(sceneKey: "rooftop-seed-house"))
        #expect(persistedScene.plants.first { $0.id == originalPlant.id }?.position == placedPosition)
        #expect(persistedScene.compositionVersion == GardenComposition.currentVersion)
    }

    @Test("scene switching carries current app settings over stale scene settings")
    func sceneSwitchingCarriesCurrentAppSettingsOverStaleSceneSettings() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        try persistence.save(
            GardenState(settings: .default),
            sceneKey: GardenWallpaperScene.roomModernBedroomCanvas.rawValue
        )
        let currentSettings = GardenSettings.default.updating(
            radioCompanionScale: 1.45,
            experienceMode: .roomStudio,
            timeLapseCadence: .weekly
        )
        let store = GardenStore(
            state: GardenState(settings: currentSettings),
            persistence: persistence,
            activeSceneKey: GardenWallpaperScene.emptyConservatoryHall.rawValue
        )

        store.switchGardenScene(
            to: GardenWallpaperScene.roomModernBedroomCanvas.rawValue,
            screenCount: 1
        )

        #expect(store.state.settings.experienceMode == GardenExperienceMode.roomStudio)
        #expect(store.state.settings.radioCompanionScale == 1.45)
        #expect(store.state.settings.timeLapseCadence == GardenTimeLapseCadence.weekly)
        let persistedScene = try #require(try persistence.load(sceneKey: GardenWallpaperScene.roomModernBedroomCanvas.rawValue))
        #expect(persistedScene.settings.experienceMode == GardenExperienceMode.roomStudio)
    }

    @Test("new Room Studio scenes start empty instead of seeding garden plants")
    func newRoomStudioScenesStartEmptyInsteadOfSeedingGardenPlants() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let store = GardenStore(
            state: GardenState(settings: .default.updating(experienceMode: .roomStudio)),
            persistence: persistence,
            activeSceneKey: GardenWallpaperScene.emptyConservatoryHall.rawValue
        )

        store.switchGardenScene(
            to: GardenWallpaperScene.roomModernBedroomCanvas.rawValue,
            screenCount: 1
        )

        #expect(store.state.settings.experienceMode == .roomStudio)
        #expect(store.state.plants.isEmpty)
        let persistedScene = try #require(try persistence.load(sceneKey: GardenWallpaperScene.roomModernBedroomCanvas.rawValue))
        #expect(persistedScene.plants.isEmpty)
    }

    @Test("new Alien UFO scenes start empty instead of seeding garden plants")
    func newAlienUFOScenesStartEmptyInsteadOfSeedingGardenPlants() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let store = GardenStore(
            state: GardenState(settings: .default.updating(experienceMode: .alienUFO)),
            persistence: persistence,
            activeSceneKey: GardenWallpaperScene.emptyConservatoryHall.rawValue
        )

        store.switchGardenScene(
            to: GardenWallpaperScene.alienCraterDome.rawValue,
            screenCount: 1
        )

        #expect(store.state.settings.experienceMode == .alienUFO)
        #expect(store.state.plants.isEmpty)
        let persistedScene = try #require(try persistence.load(sceneKey: GardenWallpaperScene.alienCraterDome.rawValue))
        #expect(persistedScene.plants.isEmpty)
    }

    @Test("mode handoff settings do not contaminate the previous scene")
    func modeHandoffSettingsDoNotContaminatePreviousScene() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let previousSceneKey = GardenWallpaperScene.emptyConservatoryHall.rawValue
        let nextSettings = GardenSettings.default.updating(experienceMode: .roomStudio)
        let store = GardenStore(
            state: GardenState(settings: .default),
            persistence: persistence,
            activeSceneKey: previousSceneKey
        )

        store.switchGardenScene(
            to: GardenWallpaperScene.roomModernBedroomCanvas.rawValue,
            screenCount: 1,
            settingsOverride: nextSettings
        )

        let previousScene = try #require(try persistence.load(sceneKey: previousSceneKey))
        let roomScene = try #require(try persistence.load(sceneKey: GardenWallpaperScene.roomModernBedroomCanvas.rawValue))
        #expect(previousScene.settings.experienceMode == .garden)
        #expect(roomScene.settings.experienceMode == .roomStudio)
        #expect(store.state.settings.experienceMode == .roomStudio)
    }

    @Test("custom non-garden scenes start empty when no saved state exists")
    func customNonGardenScenesStartEmptyWhenNoSavedStateExists() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let store = GardenStore(
            state: GardenState(settings: .default.updating(experienceMode: .alienUFO)),
            persistence: persistence,
            activeSceneKey: GardenWallpaperScene.emptyConservatoryHall.rawValue
        )

        store.switchGardenScene(
            to: "custom-alien-glass-crater",
            screenCount: 1
        )

        #expect(store.state.settings.experienceMode == .alienUFO)
        #expect(store.state.plants.isEmpty)
        let persistedScene = try #require(try persistence.load(sceneKey: "custom-alien-glass-crater"))
        #expect(persistedScene.plants.isEmpty)
    }

    @Test("non-garden scenes remove accidental default garden backfill")
    func nonGardenScenesRemoveAccidentalDefaultGardenBackfill() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let alienSceneKey = GardenWallpaperScene.alienCraterDome.rawValue
        try persistence.save(GardenState.defaultGarden(screenCount: 1), sceneKey: alienSceneKey)
        let store = GardenStore(
            state: GardenState(settings: .default.updating(experienceMode: .alienUFO)),
            persistence: persistence,
            activeSceneKey: GardenWallpaperScene.emptyConservatoryHall.rawValue
        )

        store.switchGardenScene(to: alienSceneKey, screenCount: 1)

        #expect(store.state.plants.isEmpty)
        let persistedScene = try #require(try persistence.load(sceneKey: alienSceneKey))
        #expect(persistedScene.plants.isEmpty)
    }

    @Test("non-garden cleanup preserves user arranged scenes")
    func nonGardenCleanupPreservesUserArrangedScenes() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let alienSceneKey = GardenWallpaperScene.alienCraterDome.rawValue
        var arrangedState = GardenState.defaultGarden(screenCount: 1)
        arrangedState.isUserArranged = true
        try persistence.save(arrangedState, sceneKey: alienSceneKey)
        let store = GardenStore(
            state: GardenState(settings: .default.updating(experienceMode: .alienUFO)),
            persistence: persistence,
            activeSceneKey: GardenWallpaperScene.emptyConservatoryHall.rawValue
        )

        store.switchGardenScene(to: alienSceneKey, screenCount: 1)

        #expect(!store.state.plants.isEmpty)
        let persistedScene = try #require(try persistence.load(sceneKey: alienSceneKey))
        #expect(!persistedScene.plants.isEmpty)
    }

    @Test("switching scenes syncs visible radio companion to playing station")
    func switchingScenesSyncsVisibleRadioCompanionToPlayingStation() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let savedPosition = GardenPoint(x: 0.28, y: 0.71)
        try persistence.save(
            GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: savedPosition,
                    companion: .brassFrog
                )
            ),
            sceneKey: "rooftop-seed-house"
        )
        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.82, y: 0.72),
                    companion: .moonMoth
                )
            ),
            persistence: persistence,
            activeSceneKey: "empty-conservatory-hall"
        )

        store.switchGardenScene(
            to: "rooftop-seed-house",
            screenCount: 1,
            playingRadioStation: .ambientRadio
        )

        let musicButton = try #require(store.state.musicButton)
        #expect(musicButton.position == savedPosition)
        #expect(musicButton.companion == .moonMoth)

        let persistedScene = try #require(try persistence.load(sceneKey: "rooftop-seed-house"))
        #expect(persistedScene.musicButton?.position == savedPosition)
        #expect(persistedScene.musicButton?.companion == .moonMoth)
    }

    @Test("toggling ambient wildlife publishes and persists")
    func togglingAmbientWildlifePublishesAndPersists() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let store = GardenStore(
            state: GardenState(),
            persistence: persistence,
            activeSceneKey: "empty-conservatory-hall"
        )
        let counter = GardenStoreNotificationCounter(store: store)

        store.toggleAmbientWildlife()

        #expect(store.state.isAmbientWildlifeEnabled == false)
        #expect(counter.snapshots == [
            GardenStoreNotificationSnapshot(
                activeSceneKey: "empty-conservatory-hall",
                selectedPlantID: nil,
                selectedPlantExists: false,
                plantCount: 0,
                isAmbientWildlifeEnabled: false
            )
        ])

        let persistedScene = try #require(try persistence.load(sceneKey: "empty-conservatory-hall"))
        #expect(persistedScene.isAmbientWildlifeEnabled == false)
    }

    @Test("room studio wildlife is off by default but can be enabled for room mode")
    func roomStudioWildlifeIsOffByDefaultButCanBeEnabledForRoomMode() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let store = GardenStore(
            state: GardenState(settings: GardenSettings.default.updating(experienceMode: .roomStudio)),
            persistence: persistence,
            activeSceneKey: "minimal-dorm-room"
        )

        #expect(store.state.isAmbientWildlifeEnabled)
        #expect(!store.state.settings.isRoomStudioWildlifeEnabled)
        #expect(!store.state.isEffectiveAmbientWildlifeEnabled)

        store.toggleAmbientWildlifeForCurrentMode()

        #expect(store.state.isAmbientWildlifeEnabled)
        #expect(store.state.settings.isRoomStudioWildlifeEnabled)
        #expect(store.state.isEffectiveAmbientWildlifeEnabled)

        let persistedScene = try #require(try persistence.load(sceneKey: "minimal-dorm-room"))
        #expect(persistedScene.settings.isRoomStudioWildlifeEnabled)
        #expect(persistedScene.isEffectiveAmbientWildlifeEnabled)
    }

    @Test("pausing growth applies globally across scene switches")
    func pausingGrowthAppliesGloballyAcrossSceneSwitches() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        try persistence.save(GardenState(isPaused: false), sceneKey: "empty-conservatory-hall")
        try persistence.save(GardenState(isPaused: false), sceneKey: "rooftop-seed-house")
        let store = GardenStore(
            state: GardenState(isPaused: false),
            persistence: persistence,
            activeSceneKey: "empty-conservatory-hall",
            globalDefaults: fixture.defaults
        )

        store.setPaused(true)
        store.switchGardenScene(to: "rooftop-seed-house", screenCount: 1)

        #expect(store.state.isPaused)
        let persistedSecondScene = try #require(try persistence.load(sceneKey: "rooftop-seed-house"))
        #expect(persistedSecondScene.isPaused)

        store.setPaused(false)
        store.switchGardenScene(to: "empty-conservatory-hall", screenCount: 1)

        #expect(!store.state.isPaused)
        let persistedFirstScene = try #require(try persistence.load(sceneKey: "empty-conservatory-hall"))
        #expect(!persistedFirstScene.isPaused)
    }

    @Test("toggling music button publishes and persists")
    func togglingMusicButtonPublishesAndPersists() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let store = GardenStore(
            state: GardenState(),
            persistence: persistence,
            activeSceneKey: "empty-conservatory-hall"
        )
        let counter = GardenStoreNotificationCounter(store: store)
        let position = GardenPoint(x: 0.38, y: 0.69)

        store.toggleMusicButton(screenIndex: 0, position: position)

        #expect(store.state.musicButton == GardenMusicButton(screenIndex: 0, position: position))
        #expect(counter.snapshots == [
            GardenStoreNotificationSnapshot(
                activeSceneKey: "empty-conservatory-hall",
                selectedPlantID: nil,
                selectedPlantExists: false,
                plantCount: 0,
                hasMusicButton: true
            )
        ])

        let shownScene = try #require(try persistence.load(sceneKey: "empty-conservatory-hall"))
        #expect(shownScene.musicButton == GardenMusicButton(screenIndex: 0, position: position))

        store.toggleMusicButton(screenIndex: 0, position: GardenPoint(x: 0.50, y: 0.50))

        #expect(store.state.musicButton == nil)
        let hiddenScene = try #require(try persistence.load(sceneKey: "empty-conservatory-hall"))
        #expect(hiddenScene.musicButton == nil)
    }

    @Test("updating garden settings publishes and persists")
    func updatingGardenSettingsPublishesAndPersists() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let store = GardenStore(
            state: GardenState(),
            persistence: persistence,
            activeSceneKey: "empty-conservatory-hall"
        )
        let counter = GardenStoreNotificationCounter(store: store)
        let settings = GardenSettings(
            growthSpeedMultiplier: 2.0,
            waterUseMultiplier: 0.7,
            defaultPlantScale: 1.4,
            plantNewPlantsAtMaturity: true,
            wildlifeDensityMultiplier: 1.6,
            wildlifeSpeedMultiplier: 1.8,
            musicVolume: 0.35,
            musicSource: .spotify,
            spotifyLaunchURLString: "https://open.spotify.com/playlist/wallpaper-garden"
        )

        store.updateSettings(settings)

        #expect(store.state.settings == settings)
        #expect(counter.count == 1)

        let persistedScene = try #require(try persistence.load(sceneKey: "empty-conservatory-hall"))
        #expect(persistedScene.settings == settings)
    }

    @Test("transient settings updates publish without persisting until an explicit save")
    func transientSettingsUpdatesPublishWithoutPersisting() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let store = GardenStore(
            state: GardenState(),
            persistence: persistence,
            activeSceneKey: "empty-conservatory-hall"
        )
        let counter = GardenStoreNotificationCounter(store: store)
        let settings = store.state.settings.updating(growthSpeedMultiplier: 3.0)

        store.updateSettings(settings, persist: false)

        #expect(store.state.settings == settings)
        #expect(counter.count == 1)
        #expect(try persistence.load(sceneKey: "empty-conservatory-hall") == nil)

        store.save()

        let persistedScene = try #require(try persistence.load(sceneKey: "empty-conservatory-hall"))
        #expect(persistedScene.settings == settings)
    }

    @Test("default plant scale setting applies to new plants")
    func defaultPlantScaleSettingAppliesToNewPlants() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let store = GardenStore(
            state: GardenState(settings: GardenSettings(defaultPlantScale: 1.6)),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL),
            activeSceneKey: "empty-conservatory-hall"
        )

        store.addPlant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.80)
        )

        let plant = try #require(store.state.plants.first)
        #expect(plant.scale == 1.6)
    }

    @Test("mature planting setting applies full growth to new plants")
    func maturePlantingSettingAppliesFullGrowthToNewPlants() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let store = GardenStore(
            state: GardenState(settings: GardenSettings(plantNewPlantsAtMaturity: true)),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL),
            activeSceneKey: "empty-conservatory-hall"
        )

        store.addPlant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.80)
        )

        let plant = try #require(store.state.plants.first)
        #expect(plant.growth == 1.0)
    }

    @Test("mature preview plants can restart from their beginning growth")
    func maturePreviewPlantsCanRestartFromTheirBeginningGrowth() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let plantedAt = Date(timeIntervalSince1970: 1_000)
        let previewPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.80),
            plantedAt: plantedAt,
            lastTendedAt: plantedAt,
            ageSeconds: 86_400,
            growth: 1.0,
            hydration: 0.12,
            health: 0.01,
            bloomProgress: 0.92,
            lastStageChangedAt: plantedAt,
            lastWateredAt: plantedAt,
            lastNourishedAt: plantedAt,
            diedAt: plantedAt,
            nickname: "Preview fern",
            swaySeed: 123,
            scale: 1.4,
            placementLocked: true
        )
        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let store = GardenStore(
            state: GardenState(
                plants: [previewPlant],
                settings: GardenSettings(plantNewPlantsAtMaturity: true)
            ),
            persistence: persistence,
            activeSceneKey: "empty-conservatory-hall"
        )
        store.setSelectedPlant(previewPlant.id)
        let counter = GardenStoreNotificationCounter(store: store)

        store.resetPlantsToNascentGrowthInCurrentScene()

        let resetPlant = try #require(store.state.plants.first)
        #expect(resetPlant.id == previewPlant.id)
        #expect(resetPlant.species == previewPlant.species)
        #expect(resetPlant.position == previewPlant.position)
        #expect(resetPlant.scale == previewPlant.scale)
        #expect(resetPlant.nickname == previewPlant.nickname)
        #expect(resetPlant.swaySeed == previewPlant.swaySeed)
        #expect(resetPlant.placementLocked)
        #expect(resetPlant.growthStage == .seedling)
        #expect(resetPlant.growth == PlantAssetLibrary.shared.initialGrowth(for: .fern))
        #expect(resetPlant.ageSeconds == 0)
        #expect(resetPlant.bloomProgress == 0)
        #expect(resetPlant.diedAt == nil)
        #expect(resetPlant.lastWateredAt == nil)
        #expect(resetPlant.lastNourishedAt == nil)
        #expect(resetPlant.health >= 0.88)
        #expect(resetPlant.hydration >= 0.82)
        #expect(store.selectedPlantID == previewPlant.id)
        #expect(counter.count == 1)

        let persistedScene = try #require(try persistence.load(sceneKey: "empty-conservatory-hall"))
        #expect(persistedScene.plants.first?.growth == resetPlant.growth)
        #expect(persistedScene.plants.first?.placementLocked == true)
    }

    @Test("scene plants can be brought to full maturation")
    func scenePlantsCanBeBroughtToFullMaturation() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let plantedAt = Date(timeIntervalSince1970: 2_000)
        let youngPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.80),
            plantedAt: plantedAt,
            lastTendedAt: plantedAt,
            ageSeconds: 600,
            growth: 0.32,
            hydration: 0.12,
            health: 0.01,
            bloomProgress: 0.92,
            lastStageChangedAt: plantedAt,
            lastWateredAt: plantedAt,
            lastNourishedAt: plantedAt,
            diedAt: plantedAt,
            nickname: "Young fern",
            swaySeed: 456,
            scale: 1.2,
            placementLocked: true
        )
        let persistence = GardenPersistence(directoryURL: fixture.directoryURL)
        let store = GardenStore(
            state: GardenState(plants: [youngPlant]),
            persistence: persistence,
            activeSceneKey: "empty-conservatory-hall"
        )
        store.setSelectedPlant(youngPlant.id)
        let counter = GardenStoreNotificationCounter(store: store)

        store.bringAllPlantsToFullMaturationInCurrentScene()

        let maturePlant = try #require(store.state.plants.first)
        #expect(maturePlant.id == youngPlant.id)
        #expect(maturePlant.species == youngPlant.species)
        #expect(maturePlant.position == youngPlant.position)
        #expect(maturePlant.scale == youngPlant.scale)
        #expect(maturePlant.nickname == youngPlant.nickname)
        #expect(maturePlant.swaySeed == youngPlant.swaySeed)
        #expect(maturePlant.placementLocked)
        #expect(maturePlant.growth == 1.0)
        #expect(maturePlant.growthStage == .mature)
        #expect(maturePlant.bloomProgress == 0)
        #expect(maturePlant.diedAt == nil)
        #expect(maturePlant.health >= 0.88)
        #expect(maturePlant.hydration >= 0.82)
        #expect(store.selectedPlantID == youngPlant.id)
        #expect(counter.count == 1)

        let persistedScene = try #require(try persistence.load(sceneKey: "empty-conservatory-hall"))
        #expect(persistedScene.plants.first?.growth == 1.0)
        #expect(persistedScene.plants.first?.placementLocked == true)
    }

    @Test("reset garden publishes one coherent deselected replacement snapshot")
    func resetGardenPublishesOneCoherentDeselectedReplacementSnapshot() throws {
        let fixture = try TemporaryWallpaperFixture()
        defer { fixture.cleanup() }

        let plant = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.42, y: 0.78),
            growth: 0.44,
            hydration: 0.62,
            health: 0.76
        )
        let store = GardenStore(
            state: GardenState(plants: [plant]),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL),
            activeSceneKey: "empty-conservatory-hall"
        )
        store.setSelectedPlant(plant.id)
        let counter = GardenStoreNotificationCounter(store: store)

        store.resetGarden(screenCount: 1)

        #expect(store.selectedPlantID == nil)
        #expect(counter.count == 1)
        #expect(counter.snapshots.last?.activeSceneKey == "empty-conservatory-hall")
        #expect(counter.snapshots.last?.selectedPlantID == nil)
        #expect(counter.snapshots.last?.selectedPlantExists == false)
        #expect(counter.snapshots.last?.plantCount == store.state.plants.count)
    }
}

@MainActor
private struct GardenStoreNotificationSnapshot: Equatable {
    let activeSceneKey: String?
    let selectedPlantID: UUID?
    let selectedPlantExists: Bool
    let plantCount: Int
    let firstPlantID: UUID?
    let lastError: String?
    let isAmbientWildlifeEnabled: Bool
    let hasMusicButton: Bool

    init(
        activeSceneKey: String? = nil,
        selectedPlantID: UUID?,
        selectedPlantExists: Bool,
        plantCount: Int,
        firstPlantID: UUID? = nil,
        lastError: String? = nil,
        isAmbientWildlifeEnabled: Bool = true,
        hasMusicButton: Bool = false
    ) {
        self.activeSceneKey = activeSceneKey
        self.selectedPlantID = selectedPlantID
        self.selectedPlantExists = selectedPlantExists
        self.plantCount = plantCount
        self.firstPlantID = firstPlantID
        self.lastError = lastError
        self.isAmbientWildlifeEnabled = isAmbientWildlifeEnabled
        self.hasMusicButton = hasMusicButton
    }
}

@MainActor
private final class GardenStoreNotificationCounter: NSObject {
    private(set) var count = 0
    private(set) var snapshots: [GardenStoreNotificationSnapshot] = []
    private let store: GardenStore

    init(store: GardenStore) {
        self.store = store
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: .gardenStoreDidChange,
            object: store
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func storeDidChange() {
        count += 1
        snapshots.append(
            GardenStoreNotificationSnapshot(
                activeSceneKey: store.activeSceneKey,
                selectedPlantID: store.selectedPlantID,
                selectedPlantExists: store.selectedPlant != nil,
                plantCount: store.state.plants.count,
                firstPlantID: store.state.plants.first?.id,
                lastError: store.lastError,
                isAmbientWildlifeEnabled: store.state.isAmbientWildlifeEnabled,
                hasMusicButton: store.state.musicButton != nil
            )
        )
    }
}

private final class TemporaryWallpaperFixture {
    let directoryURL: URL
    let defaults: UserDefaults
    private let defaultsSuiteName: String

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        defaultsSuiteName = "WallpaperManagerTests-\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: defaultsSuiteName))
    }

    func writePNG(to url: URL) throws {
        let size = NSSize(width: 32, height: 24)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            Issue.record("Could not create test image context")
            return
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor(calibratedRed: 0.62, green: 0.70, blue: 0.64, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSGraphicsContext.restoreGraphicsState()

        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: url, options: [.atomic])
    }

    func pngData() throws -> Data {
        let url = directoryURL.appendingPathComponent("fixture-\(UUID().uuidString).png")
        try writePNG(to: url)
        return try Data(contentsOf: url)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }
}
