import AppKit
import Foundation
import PlantGardenCore

@MainActor
enum GardenHealthCheckReport {
    static func makeJSONData(
        store: GardenStore,
        activeSceneName: String,
        weatherStatus: String,
        timeLapseRecorder: GardenTimeLapseRecorder?,
        at date: Date = Date(),
        readinessEnvironment: GardenReleaseReadinessEnvironment = .current(),
        wallpaperManager: WallpaperManager? = nil
    ) throws -> Data {
        let state = store.state
        let vitality = state.vitality(at: date)
        let inventory = timeLapseRecorder?.inventorySummary()
        let ambientMix = GardenAmbienceEngine.mix(for: state, sceneKey: store.activeSceneKey, at: date)
        let soundscape = GardenSceneSoundscape(sceneKey: store.activeSceneKey)
        let readinessWallpaperManager = wallpaperManager ?? WallpaperManager(baseDirectoryURL: store.persistence.directoryURL)
        let releaseReadiness = GardenReleaseReadinessReport.makeSummary(
            store: store,
            wallpaperManager: readinessWallpaperManager,
            timeLapseRecorder: timeLapseRecorder,
            environment: readinessEnvironment
        )

        let payload: [String: Any] = [
            "app": "Plant Wallpaper",
            "createdAt": iso8601.string(from: date),
            "activeScene": activeSceneName,
            "weatherStatus": weatherStatus,
            "releaseReadiness": releaseReadiness.jsonObject,
            "garden": [
                "plants": state.plants.count,
                "livingPlants": state.plants.filter { !$0.isDead }.count,
                "careNeeded": state.plantsNeedingCare.count,
                "thirstyPlants": state.thirstyPlants.count,
                "readyCrops": state.plants.filter(\.isHarvestReady).count,
                "vitalityScore": vitality.percentScore,
                "vitalitySummary": vitality.summary,
                "isPaused": state.isPaused,
                "isUserArranged": state.isUserArranged,
                "manualPlantDarkening": state.manualPlantDarkening,
                "createdAt": iso8601.string(from: state.createdAt),
                "lastUpdatedAt": iso8601.string(from: state.lastUpdatedAt)
            ],
            "settings": [
                "weatherSync": state.settings.isWeatherSyncEnabled,
                "ambientSound": state.settings.isAmbientSoundEnabled,
                "ambientVolume": state.settings.ambientSoundVolume,
                "windSound": state.settings.isWindSoundEnabled,
                "rainSound": state.settings.isRainSoundEnabled,
                "birdsong": state.settings.isBirdsongEnabled,
                "crickets": state.settings.isCricketSoundEnabled,
                "wildlife": state.isAmbientWildlifeEnabled,
                "musicSource": state.settings.musicSource.rawValue,
                "musicButton": state.musicButton != nil
            ],
            "audioMixNow": [
                "master": ambientMix.masterVolume,
                "wind": ambientMix.wind,
                "rain": ambientMix.rain,
                "birds": ambientMix.birds,
                "crickets": ambientMix.crickets,
                "water": ambientMix.water,
                "urbanMurmur": ambientMix.urbanMurmur,
                "roomTone": ambientMix.roomTone,
                "cicadas": ambientMix.cicadas,
                "chimes": ambientMix.chimes
            ],
            "soundscape": [
                "sceneKey": soundscape.sceneKey,
                "birds": soundscape.birds.description,
                "insects": soundscape.insects.description,
                "place": soundscape.place.description
            ],
            "timeLapse": [
                "frames": inventory?.frameCount ?? 0,
                "bytes": inventory?.byteCount ?? 0,
                "storage": inventory?.storageSummary ?? "0 frames - Zero KB"
            ],
            "seeds": [
                "species": state.seedInventory.count,
                "total": state.seedInventory.values.reduce(0, +)
            ],
            "harvests": [
                "species": state.harvestTally.count,
                "total": state.harvestTally.values.reduce(0, +)
            ],
            "recentDiary": (store.journal?.recentEntries(limit: 6) ?? []).map { entry in
                [
                    "date": iso8601.string(from: entry.date),
                    "kind": entry.kind.rawValue,
                    "message": entry.text
                ]
            }
        ]

        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

@MainActor
enum GardenHealthCheckExporter {
    static func exportInteractively(
        store: GardenStore,
        activeSceneName: String,
        weatherStatus: String,
        timeLapseRecorder: GardenTimeLapseRecorder?
    ) {
        let panel = NSSavePanel()
        panel.title = "Save Garden Health Check"
        panel.nameFieldStringValue = "Plant Wallpaper Health Check.json"
        panel.allowedContentTypes = [.json]
        NSApplication.shared.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK, let outputURL = panel.url else {
            return
        }

        do {
            let data = try GardenHealthCheckReport.makeJSONData(
                store: store,
                activeSceneName: activeSceneName,
                weatherStatus: weatherStatus,
                timeLapseRecorder: timeLapseRecorder
            )
            try data.write(to: outputURL, options: [.atomic])
            NSWorkspace.shared.activateFileViewerSelecting([outputURL])
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not save health check"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
