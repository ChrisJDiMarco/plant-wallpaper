import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden persistence")
struct GardenPersistenceTests {
    @Test("state can round-trip through disk")
    func gardenStateRoundTrips() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperGardenTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let persistence = GardenPersistence(directoryURL: tempURL)
        var state = GardenState.defaultGarden(screenCount: 1, now: Date(timeIntervalSince1970: 10_000))
        state.musicButton = GardenMusicButton(
            screenIndex: 0,
            position: GardenPoint(x: 0.76, y: 0.64)
        )
        state.progression = GardenSceneProgression(
            level: 7,
            profile: GardenProgressionProfile(
                lifestyleFantasy: "eccentric founder estate",
                placeInWorld: "coastal Brazil",
                ageBracket: "30s",
                vibe: "warm cinematic retro-futurist",
                avoidList: "cold corporate minimalism"
            ),
            startedAt: Date(timeIntervalSince1970: 12_000),
            lastAdvancedAt: Date(timeIntervalSince1970: 13_000)
        )

        try persistence.save(state)
        let loadedState = try #require(try persistence.load())

        #expect(loadedState == state)
        #expect(loadedState.progression?.level == 7)
        #expect(loadedState.progression?.profile.placeInWorld == "coastal Brazil")
    }

    @Test("loading a missing garden returns nil")
    func missingGardenReturnsNil() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperGardenMissing-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let persistence = GardenPersistence(directoryURL: tempURL)

        #expect(try persistence.load() == nil)
    }

    @Test("scene gardens save and load independently")
    func sceneGardensSaveAndLoadIndependently() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperGardenSceneTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let persistence = GardenPersistence(directoryURL: tempURL)
        var conservatoryState = GardenState.defaultGarden(screenCount: 1, now: Date(timeIntervalSince1970: 20_000))
        conservatoryState.ambientMoisture = 0.22
        conservatoryState.manualPlantDarkening = 0.18
        conservatoryState.plants[0].position = GardenPoint(x: 0.12, y: 0.34)
        var rooftopState = GardenState.defaultGarden(screenCount: 1, now: Date(timeIntervalSince1970: 30_000))
        rooftopState.ambientMoisture = 0.74
        rooftopState.manualPlantDarkening = 0.42
        rooftopState.plants[0].position = GardenPoint(x: 0.82, y: 0.67)

        try persistence.save(conservatoryState, sceneKey: "empty-conservatory-hall")
        try persistence.save(rooftopState, sceneKey: "rooftop-seed-house")

        let loadedConservatory = try #require(try persistence.load(sceneKey: "empty-conservatory-hall"))
        let loadedRooftop = try #require(try persistence.load(sceneKey: "rooftop-seed-house"))

        #expect(loadedConservatory == conservatoryState)
        #expect(loadedRooftop == rooftopState)
        #expect(loadedConservatory.manualPlantDarkening == 0.18)
        #expect(loadedRooftop.manualPlantDarkening == 0.42)
        #expect(loadedConservatory.plants[0].position != loadedRooftop.plants[0].position)
    }

    @Test("each wallpaper version keeps its own progression level on revert")
    func progressionLevelTravelsWithEachSceneVersion() throws {
        // Locks in the per-scene-key model: every generated wallpaper version
        // persists its own progression, so reverting to an older version
        // restores that version's level rather than desyncing the counter.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperGardenProgressionVersions-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let persistence = GardenPersistence(directoryURL: tempURL)
        let profile = GardenProgressionProfile(
            lifestyleFantasy: "founder estate",
            placeInWorld: "coastal Brazil",
            ageBracket: "30s",
            vibe: "warm cinematic",
            avoidList: ""
        )

        var levelThreeState = GardenState.defaultGarden(screenCount: 1, now: Date(timeIntervalSince1970: 40_000))
        levelThreeState.progression = GardenSceneProgression(level: 3, profile: profile)
        var levelFiveState = GardenState.defaultGarden(screenCount: 1, now: Date(timeIntervalSince1970: 50_000))
        levelFiveState.progression = GardenSceneProgression(level: 5, profile: profile)

        try persistence.save(levelThreeState, sceneKey: "edit-progression-level-3")
        try persistence.save(levelFiveState, sceneKey: "edit-progression-level-5")

        let revertedToThree = try #require(try persistence.load(sceneKey: "edit-progression-level-3"))
        let stillAtFive = try #require(try persistence.load(sceneKey: "edit-progression-level-5"))

        #expect(revertedToThree.progression?.level == 3)
        #expect(stillAtFive.progression?.level == 5)
    }

    @Test("scene keys are sanitized for garden filenames")
    func sceneKeysAreSanitizedForGardenFilenames() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperGardenSceneFilename-\(UUID().uuidString)", isDirectory: true)
        let persistence = GardenPersistence(directoryURL: tempURL)

        let fileURL = persistence.fileURL(forSceneKey: "Custom Wallpaper / Morning.png")

        #expect(fileURL.lastPathComponent == "garden-Custom-Wallpaper---Morning-png.json")
    }

    @Test("screen saver snapshot round-trips exact garden state")
    func screenSaverSnapshotRoundTripsExactGardenState() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperGardenScreenSaverSnapshot-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        var state = GardenState.defaultGarden(screenCount: 1, now: Date(timeIntervalSince1970: 40_000))
        state.plants[0].position = GardenPoint(x: 0.21, y: 0.83)
        state.musicButtons = [
            GardenMusicButton(
                screenIndex: 0,
                position: GardenPoint(x: 0.15, y: 0.72),
                companion: .moonMoth
            ),
            GardenMusicButton(
                screenIndex: 0,
                position: GardenPoint(x: 0.83, y: 0.64),
                companion: .miniUfoTerrarium
            )
        ]
        let snapshot = GardenScreenSaverSnapshot(
            sceneKey: "cottage-backyard-garden",
            state: state,
            wallpaperImagePath: "/tmp/current-wallpaper.png",
            compositedImagePath: "/tmp/current-garden.png",
            isCatCompanionEnabled: false,
            savedAt: Date(timeIntervalSince1970: 50_000)
        )

        try snapshot.save(to: tempURL)

        let loadedSnapshot = try #require(try GardenScreenSaverSnapshot.load(from: tempURL))
        #expect(loadedSnapshot == snapshot)
        #expect(loadedSnapshot.state.musicButtons.map(\.companion) == [.moonMoth, .miniUfoTerrarium])
        #expect(loadedSnapshot.isCatCompanionEnabled == false)
        #expect(GardenScreenSaverSnapshot.fileURL(directoryURL: tempURL).lastPathComponent == "screen-saver-current-garden.json")
        #expect(GardenScreenSaverSnapshot.primaryImageURL(directoryURL: tempURL).lastPathComponent == "screen-saver-current-garden.png")
    }

    @Test("corrupt garden files can be quarantined before recovery save")
    func corruptGardenFilesCanBeQuarantinedBeforeRecoverySave() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperGardenCorrupt-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let persistence = GardenPersistence(directoryURL: tempURL)
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        try Data("{not valid json".utf8).write(to: persistence.fileURL)

        let maybeQuarantineURL = try persistence.quarantineGardenFile(
            at: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let quarantineURL = try #require(maybeQuarantineURL)

        #expect(!FileManager.default.fileExists(atPath: persistence.fileURL.path))
        #expect(FileManager.default.fileExists(atPath: quarantineURL.path))
        #expect(quarantineURL.lastPathComponent == "garden.json.corrupt-20231114-221320")
    }

    @Test("older garden files without stage milestone dates still load")
    func olderGardenFilesWithoutStageMilestonesStillLoad() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperGardenLegacy-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        let fileURL = tempURL.appendingPathComponent("garden.json")
        let legacyJSON = """
        {
          "ambientMoisture": 0.38,
          "compositionVersion": 5,
          "createdAt": "1970-01-01T00:00:10Z",
          "isPaused": false,
          "lastUpdatedAt": "1970-01-01T00:00:20Z",
          "plants": [
            {
              "ageSeconds": 0,
              "bloomProgress": 0.1,
              "growth": 0.28,
              "health": 0.82,
              "hydration": 0.74,
              "id": "00000000-0000-0000-0000-000000000001",
              "lastTendedAt": "1970-01-01T00:00:20Z",
              "nickname": "Legacy Tulip",
              "plantedAt": "1970-01-01T00:00:10Z",
              "position": { "x": 0.5, "y": 0.82 },
              "scale": 1.0,
              "screenIndex": 0,
              "species": "tulip",
              "swaySeed": 12.0
            }
          ],
          "version": 2,
          "windStrength": 0.24
        }
        """
        try legacyJSON.data(using: .utf8)?.write(to: fileURL)

        let persistence = GardenPersistence(directoryURL: tempURL)
        let loadedState = try #require(try persistence.load())
        let loadedPlant = try #require(loadedState.plants.first)

        #expect(loadedPlant.nickname == "Legacy Tulip")
        #expect(loadedPlant.lastStageChangedAt == nil)
        #expect(loadedPlant.lastWateredAt == nil)
        #expect(loadedPlant.lastNourishedAt == nil)
        #expect(loadedState.isAmbientWildlifeEnabled)
        #expect(loadedState.musicButton == nil)
    }
}
