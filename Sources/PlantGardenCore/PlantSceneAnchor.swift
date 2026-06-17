import Foundation

public struct PlantSceneAnchor: Equatable, Sendable {
    public let contactShadowWidthMultiplier: Double
    public let contactShadowHeightRatio: Double
    public let contactShadowOpacity: Double
    public let groundOcclusionOpacity: Double
    public let reflectionOpacity: Double
    public let groundTintOpacity: Double

    public init(plant: Plant) {
        let growth = plant.growth.clampedUnit
        let hydration = plant.hydration.clampedUnit
        let health = plant.health.clampedUnit
        let vitality = min(hydration, health)
        let depth = plant.depthProfile
        let rootZone = plant.rootZone
        let speciesFootprint = Self.speciesFootprint(for: plant.species)
        let growthSpread = 0.50 + growth * 0.58
        let rootSpread = 0.76 + rootZone.radiusMultiplier * 0.22

        contactShadowWidthMultiplier = Self.bounded(
            speciesFootprint * growthSpread * rootSpread * depth.shadowScale,
            lower: 0.22,
            upper: 1.38
        )
        contactShadowHeightRatio = Self.bounded(
            0.095 + depth.depth * 0.042 + rootZone.moistureSheen * 0.015,
            lower: 0.08,
            upper: 0.17
        )
        contactShadowOpacity = Self.bounded(
            0.105
                + rootZone.soilDarkness * 0.14
                + depth.depth * 0.075
                + growth * 0.045,
            lower: 0.10,
            upper: 0.42
        )
        groundOcclusionOpacity = Self.bounded(
            0.030
                + rootZone.soilDarkness * 0.055
                + growth * 0.050
                + depth.depth * 0.030,
            lower: 0.025,
            upper: 0.17
        )
        reflectionOpacity = Self.bounded(
            (0.018 + health * 0.050 + hydration * 0.030)
                * (0.92 + depth.depth * 0.12),
            lower: 0.012,
            upper: 0.11
        )
        groundTintOpacity = Self.bounded(
            (0.012 + vitality * 0.052 + growth * 0.020)
                * (0.88 + depth.depth * 0.12),
            lower: 0.010,
            upper: 0.10
        )
    }

    private static func speciesFootprint(for species: PlantSpecies) -> Double {
        switch species.kind {
        case .tree:
            0.48
        case .foliage:
            0.66
        case .edible:
            0.62
        case .flower:
            species == .sunflower ? 0.62 : 0.54
        case .meadow:
            0.92
        }
    }

    private static func bounded(_ value: Double, lower: Double, upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}

public extension Plant {
    var sceneAnchor: PlantSceneAnchor {
        PlantSceneAnchor(plant: self)
    }
}
