import Foundation

public struct PlantAssetRenderComposite: Equatable, Sendable {
    public let currentStageOpacity: Double
    public let nextStageOverlayOpacity: Double

    public init(plant: Plant, assetStage: PlantAssetStage) {
        currentStageOpacity = 1.0
        nextStageOverlayOpacity = plant.isDead ? 0 : assetStage.blendOpacity.clampedUnit
    }
}
