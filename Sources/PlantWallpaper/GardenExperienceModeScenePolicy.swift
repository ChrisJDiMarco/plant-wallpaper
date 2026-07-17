import Foundation
import PlantGardenCore

enum GardenExperienceModeScenePolicy {
    static let rainforestCanvasSceneKey = "rainforest-canvas"

    static func isRainforestCanvasKey(_ sceneKey: String) -> Bool {
        sceneKey == rainforestCanvasSceneKey
    }

    static func defaultSceneKey(for mode: GardenExperienceMode) -> String {
        switch mode {
        case .rainforest:
            rainforestCanvasSceneKey
        case .garden, .roomStudio, .alienUFO:
            defaultScene(for: mode).rawValue
        }
    }

    static func defaultScene(for mode: GardenExperienceMode) -> GardenWallpaperScene {
        if let selectableScene = GardenWallpaperScene.selectableScenes(for: mode).first {
            return selectableScene
        }

        switch mode {
        case .garden:
            return GardenWallpaperScene.defaultScene
        case .rainforest:
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
        if targetMode == .rainforest {
            return isRainforestCanvasKey(currentSceneKey) ? nil : rainforestCanvasSceneKey
        }

        if isRainforestCanvasKey(currentSceneKey) {
            return defaultScene(for: targetMode).rawValue
        }

        guard let currentScene = GardenWallpaperScene.scene(forKey: currentSceneKey),
              currentScene.experienceMode == targetMode,
              currentScene.isSelectableScene else {
            return defaultScene(for: targetMode).rawValue
        }

        return nil
    }
}
