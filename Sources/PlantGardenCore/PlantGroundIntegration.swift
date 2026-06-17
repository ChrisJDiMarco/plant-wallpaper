import Foundation

public struct PlantGroundIntegration: Equatable, Sendable {
    public let occlusionHeightRatio: Double
    public let widthMultiplier: Double
    public let occlusionOpacity: Double
    public let surfaceTintOpacity: Double
    public let surfaceDetailCount: Int
    public let shortSummary: String

    public init(plant: Plant) {
        let growth = plant.growth.clampedUnit
        let hydration = plant.hydration.clampedUnit
        let depth = plant.depthProfile
        let rootZone = plant.rootZone
        let bedAffinity = plant.bedAffinity
        let speciesFootprint = Self.speciesFootprint(for: plant.species)
        let bedTuck = Self.bedTuckFactor(for: bedAffinity.fit)
        let maturity = max(growth, min(1, plant.ageSeconds / (6 * 86_400)) * 0.64)
        let depthPresence = 0.82 + depth.depth * 0.28

        occlusionHeightRatio = Self.bounded(
            (0.030 + maturity * 0.035 + rootZone.radiusMultiplier * 0.010)
                * bedTuck
                * (0.92 + depth.depth * 0.18),
            lower: 0.012,
            upper: 0.092
        )
        widthMultiplier = Self.bounded(
            speciesFootprint
                * (0.70 + rootZone.radiusMultiplier * 0.22)
                * bedTuck
                * depthPresence,
            lower: 0.28,
            upper: 1.34
        )
        occlusionOpacity = Self.bounded(
            (0.040 + rootZone.soilDarkness * 0.060 + maturity * 0.040)
                * bedTuck
                * (0.88 + depth.depth * 0.18),
            lower: 0.020,
            upper: 0.20
        )
        surfaceTintOpacity = Self.bounded(
            (0.020 + hydration * 0.050 + maturity * 0.018)
                * (bedAffinity.fit == .exposed ? 0.58 : 1)
                * (0.92 + depth.depth * 0.12),
            lower: 0.010,
            upper: 0.12
        )

        surfaceDetailCount = max(
            2,
            Int((2 + maturity * 8 + hydration * 3) * speciesFootprint * (bedAffinity.fit == .exposed ? 0.62 : 1))
        )
        shortSummary = switch bedAffinity.fit {
        case .rooted:
            maturity > 0.45 ? "Tucked in" : "Settling in"
        case .edge:
            "Bed edge"
        case .support:
            "On support"
        case .exposed:
            "Exposed base"
        }
    }

    private static func speciesFootprint(for species: PlantSpecies) -> Double {
        switch species.kind {
        case .tree:
            1.04
        case .foliage:
            0.82
        case .edible:
            0.84
        case .meadow:
            1.12
        case .flower:
            species == .sunflower ? 0.74 : 0.62
        }
    }

    private static func bedTuckFactor(for fit: PlantBedFit) -> Double {
        switch fit {
        case .rooted:
            1.0
        case .edge:
            0.78
        case .support:
            0.66
        case .exposed:
            0.46
        }
    }

    private static func bounded(_ value: Double, lower: Double, upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}

public extension Plant {
    var groundIntegration: PlantGroundIntegration {
        PlantGroundIntegration(plant: self)
    }
}
