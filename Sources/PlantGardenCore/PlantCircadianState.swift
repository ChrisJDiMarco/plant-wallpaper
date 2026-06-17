import Foundation

public enum PlantCircadianPhase: String, Codable, Sendable {
    case morningRecovery
    case photosynthesizing
    case goldenBloom
    case nightRest
}

public struct PlantCircadianState: Equatable, Sendable {
    public let phase: PlantCircadianPhase
    public let growthMultiplier: Double
    public let waterUseMultiplier: Double
    public let bloomMultiplier: Double
    public let bloomVisibilityMultiplier: Double
    public let healthAdjustmentPerHour: Double
    public let summary: String
    public let shortSummary: String

    public init(plant: Plant, sunlight: GardenSunlightCondition) {
        switch sunlight.mood {
        case .morning:
            phase = .morningRecovery
            growthMultiplier = 1.04
            waterUseMultiplier = 0.96
            bloomMultiplier = plant.species.kind == .flower ? 1.02 : 0.96
            bloomVisibilityMultiplier = plant.species.kind == .flower ? 0.92 : 1.0
            healthAdjustmentPerHour = 0.004
            summary = "Morning recovery"
            shortSummary = "Morning recovery"
        case .bright:
            phase = .photosynthesizing
            growthMultiplier = plant.species.kind == .flower || plant.species.kind == .meadow ? 1.12 : 1.08
            waterUseMultiplier = plant.species.kind == .foliage ? 1.04 : 1.09
            bloomMultiplier = plant.species.kind == .flower || plant.species.kind == .meadow ? 1.06 : 1.0
            bloomVisibilityMultiplier = 1.0
            healthAdjustmentPerHour = 0.001
            summary = "Active photosynthesis"
            shortSummary = "Photosynthesis"
        case .golden:
            phase = .goldenBloom
            growthMultiplier = 0.92
            waterUseMultiplier = 0.94
            bloomMultiplier = plant.species.kind == .flower || plant.species.kind == .meadow ? 1.18 : 1.04
            bloomVisibilityMultiplier = plant.species.kind == .flower || plant.species.kind == .meadow ? 1.12 : 1.02
            healthAdjustmentPerHour = 0.002
            summary = "Golden bloom"
            shortSummary = "Golden bloom"
        case .night:
            phase = .nightRest
            growthMultiplier = plant.species.kind == .tree ? 0.52 : 0.44
            waterUseMultiplier = plant.species.kind == .foliage ? 0.72 : 0.78
            bloomMultiplier = plant.species.kind == .flower || plant.species.kind == .meadow ? 0.36 : 0.58
            bloomVisibilityMultiplier = plant.species.kind == .flower || plant.species.kind == .meadow ? 0.62 : 0.88
            healthAdjustmentPerHour = 0.003
            summary = "Night rest"
            shortSummary = "Night rest"
        }
    }
}

public extension Plant {
    func circadianState(for sunlight: GardenSunlightCondition) -> PlantCircadianState {
        PlantCircadianState(plant: self, sunlight: sunlight)
    }
}
