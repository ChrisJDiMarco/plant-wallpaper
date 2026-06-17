import Foundation

public enum PlantRootZoneStage: String, Codable, Sendable {
    case newPlanting
    case rooting
    case established
}

public struct PlantRootZone: Equatable, Sendable {
    public let stage: PlantRootZoneStage
    public let radiusMultiplier: Double
    public let soilDarkness: Double
    public let moistureSheen: Double
    public let surfaceDetailCount: Int
    public let summary: String

    public init(plant: Plant) {
        let growth = plant.growth.clampedUnit
        let ageDays = max(0, plant.ageSeconds / 86_400)
        let maturity = max(growth, min(1, ageDays / 6.0) * 0.64)

        if growth < 0.18 || ageDays < 0.5 {
            stage = .newPlanting
        } else if growth < 0.62 || ageDays < 4 {
            stage = .rooting
        } else {
            stage = .established
        }

        let speciesSpread = Self.speciesSpread(for: plant.species)
        radiusMultiplier = Self.bounded(
            (0.48 + maturity * 0.78) * speciesSpread * plant.depthProfile.shadowScale,
            lower: 0.42,
            upper: 1.72
        )
        soilDarkness = Self.bounded(0.32 + plant.hydration.clampedUnit * 0.36 + growth * 0.10, lower: 0.26, upper: 0.82)
        moistureSheen = Self.bounded((plant.hydration.clampedUnit - 0.58) / 0.42, lower: 0, upper: 1)
        surfaceDetailCount = max(3, Int((4 + maturity * 10) * speciesSpread))

        summary = switch stage {
        case .newPlanting:
            "New planting"
        case .rooting:
            "Rooting in"
        case .established:
            "Established roots"
        }
    }

    private static func speciesSpread(for species: PlantSpecies) -> Double {
        switch species.kind {
        case .tree:
            1.24
        case .meadow:
            1.18
        case .foliage:
            0.96
        case .edible:
            0.92
        case .flower:
            species == .sunflower ? 1.04 : 0.84
        }
    }

    private static func bounded(_ value: Double, lower: Double, upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}

public extension Plant {
    var rootZone: PlantRootZone {
        PlantRootZone(plant: self)
    }
}
