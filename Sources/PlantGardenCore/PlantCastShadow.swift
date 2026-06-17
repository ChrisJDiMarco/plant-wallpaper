import Foundation

public struct PlantCastShadow: Equatable, Sendable {
    public let isVisible: Bool
    public let offsetXMultiplier: Double
    public let offsetYMultiplier: Double
    public let lengthMultiplier: Double
    public let widthMultiplier: Double
    public let opacity: Double
    public let softness: Double
    public let canopyLobeCount: Int

    public init(plant: Plant, projection: GardenLightProjection) {
        let growth = plant.growth.clampedUnit
        let health = plant.isDead ? 0 : plant.health.clampedUnit
        let depth = plant.depthProfile
        let speciesShape = Self.speciesShape(for: plant.species)
        let maturity = max(0, (growth - 0.10) / 0.90)
        let vitality = 0.62 + health * 0.38
        let depthLift = 0.82 + depth.depth * 0.28
        let projectedLength = projection.shadowLengthMultiplier * (0.46 + maturity * 0.82)

        widthMultiplier = Self.bounded(
            speciesShape.width * (0.28 + maturity * 0.96) * depthLift,
            lower: 0.08,
            upper: 1.56
        )
        lengthMultiplier = Self.bounded(
            speciesShape.length * projectedLength,
            lower: 0.12,
            upper: 1.92
        )
        offsetXMultiplier = projection.shadowOffsetX
            * lengthMultiplier
            * (0.92 + depth.depth * 0.18)
        offsetYMultiplier = projection.shadowOffsetY
            * lengthMultiplier
            * (0.70 + depth.depth * 0.20)

        let rawOpacity = (0.018 + maturity * 0.092)
            * speciesShape.density
            * vitality
            * (0.84 + depth.depth * 0.22)
            * projection.shadowOpacityMultiplier
        opacity = growth < 0.12 || health < 0.20
            ? 0
            : Self.bounded(rawOpacity, lower: 0.010, upper: 0.26)

        let nightSoftness = projection.shadowOpacityMultiplier < 0.70 ? 0.16 : 0
        softness = Self.bounded(
            0.50 + lengthMultiplier * 0.10 + (1 - health) * 0.12 + nightSoftness,
            lower: 0.48,
            upper: 0.90
        )

        let lobeBase = Int((Double(speciesShape.lobeCount) * (0.55 + maturity * 0.62)).rounded())
        canopyLobeCount = max(speciesShape.minimumLobes, lobeBase)
        isVisible = opacity > 0.012
    }

    private static func speciesShape(for species: PlantSpecies) -> SpeciesShape {
        switch species.kind {
        case .tree:
            SpeciesShape(width: 1.00, length: 1.20, density: 1.00, lobeCount: 10, minimumLobes: 5)
        case .foliage:
            SpeciesShape(width: 0.74, length: 0.86, density: 0.72, lobeCount: 7, minimumLobes: 4)
        case .edible:
            SpeciesShape(width: 0.66, length: 0.76, density: 0.64, lobeCount: 7, minimumLobes: 4)
        case .meadow:
            SpeciesShape(width: 0.86, length: 0.70, density: 0.58, lobeCount: 8, minimumLobes: 4)
        case .flower:
            species == .sunflower
                ? SpeciesShape(width: 0.54, length: 0.58, density: 0.48, lobeCount: 5, minimumLobes: 3)
                : SpeciesShape(width: 0.42, length: 0.48, density: 0.40, lobeCount: 4, minimumLobes: 3)
        }
    }

    private static func bounded(_ value: Double, lower: Double, upper: Double) -> Double {
        min(upper, max(lower, value))
    }

    private struct SpeciesShape {
        let width: Double
        let length: Double
        let density: Double
        let lobeCount: Int
        let minimumLobes: Int
    }
}

public extension Plant {
    func castShadow(projection: GardenLightProjection) -> PlantCastShadow {
        PlantCastShadow(plant: self, projection: projection)
    }
}
