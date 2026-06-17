import Foundation
import PlantGardenCore

enum GardenSceneNavigationDirection {
    case previous
    case next
}

enum GardenSceneNavigator {
    static func orderedSceneKeys(
        customWallpapers: [CustomWallpaperRecord],
        experienceMode: GardenExperienceMode? = nil
    ) -> [String] {
        let builtInScenes = experienceMode.map { GardenWallpaperScene.selectableScenes(for: $0) } ?? GardenWallpaperScene.allCases
        let visibleCustomWallpapers = customWallpapers.filter { record in
            guard !record.isWallpaperUpdate else {
                return false
            }

            guard let experienceMode else {
                return true
            }

            return record.isAssociated(with: experienceMode)
        }
        return builtInScenes.map(\.rawValue) + visibleCustomWallpapers.map(\.key)
    }

    static func adjacentSceneKey(
        from currentKey: String,
        customWallpapers: [CustomWallpaperRecord],
        direction: GardenSceneNavigationDirection,
        experienceMode: GardenExperienceMode? = nil
    ) -> String {
        let keys = orderedSceneKeys(customWallpapers: customWallpapers, experienceMode: experienceMode)
        guard !keys.isEmpty else {
            return defaultSceneKey(for: experienceMode)
        }

        let canonicalCurrentKey = sceneRootKey(for: currentKey, customWallpapers: customWallpapers)
        let currentIndex = keys.firstIndex(of: canonicalCurrentKey)
            ?? keys.firstIndex(of: defaultSceneKey(for: experienceMode))
            ?? 0
        let offset = direction == .next ? 1 : -1
        let nextIndex = (currentIndex + offset + keys.count) % keys.count
        return keys[nextIndex]
    }

    private static func sceneRootKey(for currentKey: String, customWallpapers: [CustomWallpaperRecord]) -> String {
        let canonicalCurrentKey = GardenWallpaperScene.canonicalKey(for: currentKey)
        guard let record = customWallpapers.first(where: { $0.key == canonicalCurrentKey }),
              let parentSceneKey = record.parentSceneKey,
              !parentSceneKey.isEmpty else {
            return canonicalCurrentKey
        }

        return GardenWallpaperScene.canonicalKey(for: parentSceneKey)
    }

    private static func defaultSceneKey(for mode: GardenExperienceMode?) -> String {
        switch mode {
        case .roomStudio:
            GardenWallpaperScene.defaultRoomStudioScene.rawValue
        case .alienUFO:
            GardenWallpaperScene.defaultAlienUFOScene.rawValue
        case .garden, .none:
            GardenWallpaperScene.defaultScene.rawValue
        }
    }
}
