import Foundation
import PlantGardenCore

enum GardenExperienceModeScenePolicy {
    static func defaultScene(for mode: GardenExperienceMode) -> GardenWallpaperScene {
        if let selectableScene = GardenWallpaperScene.selectableScenes(for: mode).first {
            return selectableScene
        }

        switch mode {
        case .garden:
            return GardenWallpaperScene.defaultScene
        case .roomStudio:
            return GardenWallpaperScene.defaultRoomStudioScene
        case .alienUFO:
            return GardenWallpaperScene.defaultAlienUFOScene
        }
    }

    static func sceneHandoffKey(
        currentSceneKey: String,
        targetMode: GardenExperienceMode
    ) -> String? {
        guard let currentScene = GardenWallpaperScene.scene(forKey: currentSceneKey),
              currentScene.experienceMode == targetMode,
              currentScene.isSelectableScene else {
            return defaultScene(for: targetMode).rawValue
        }

        return nil
    }
}
