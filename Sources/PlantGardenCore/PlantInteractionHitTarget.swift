import Foundation

public struct PlantInteractionHitTarget: Equatable, Sendable {
    public let minimumWidth: Double
    public let minimumHeight: Double
    public let horizontalPaddingRatio: Double
    public let topPaddingRatio: Double
    public let bottomPaddingRatio: Double

    public init(plant: Plant) {
        let growth = plant.growth.clampedUnit
        let youngBoost = max(0, 1 - growth) * 0.34

        switch plant.species.kind {
        case .tree:
            minimumWidth = 150 + youngBoost * 46
            minimumHeight = 180 + youngBoost * 38
            horizontalPaddingRatio = 0.28
            topPaddingRatio = 0.10
            bottomPaddingRatio = 0.28
        case .foliage:
            minimumWidth = 132 + youngBoost * 38
            minimumHeight = 150 + youngBoost * 34
            horizontalPaddingRatio = 0.34
            topPaddingRatio = 0.12
            bottomPaddingRatio = 0.30
        case .edible:
            minimumWidth = 132 + youngBoost * 40
            minimumHeight = 158 + youngBoost * 34
            horizontalPaddingRatio = 0.36
            topPaddingRatio = 0.13
            bottomPaddingRatio = 0.30
        case .flower:
            let sunflowerBoost = plant.species == .sunflower ? 12.0 : 0
            minimumWidth = 124 + sunflowerBoost + youngBoost * 42
            minimumHeight = 164 + youngBoost * 36
            horizontalPaddingRatio = 0.42
            topPaddingRatio = 0.16
            bottomPaddingRatio = 0.32
        case .meadow:
            minimumWidth = 162 + youngBoost * 42
            minimumHeight = 136 + youngBoost * 30
            horizontalPaddingRatio = 0.34
            topPaddingRatio = 0.12
            bottomPaddingRatio = 0.30
        }
    }
}

public extension Plant {
    var interactionHitTarget: PlantInteractionHitTarget {
        PlantInteractionHitTarget(plant: self)
    }
}
