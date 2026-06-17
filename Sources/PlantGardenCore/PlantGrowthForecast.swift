import Foundation

public enum PlantGrowthForecastStatus: String, Codable, Sendable {
    case dead
    case growing
    case needsWater
    case recovering
    case complete
}

public struct PlantGrowthForecast: Equatable, Sendable {
    public let stage: PlantAssetStage
    public let status: PlantGrowthForecastStatus
    public let projectedGrowthPerHour: Double
    public let growthRemainingToNextStage: Double
    public let estimatedHoursToNextStage: Double?

    public init(
        plant: Plant,
        microclimateGrowthFactor: Double = 1,
        circadianGrowthFactor: Double = 1,
        stageCount: Int = PlantAssetStage.defaultStageCount
    ) {
        let safeStageCount = max(1, stageCount)
        let safeGrowth = plant.growth.clampedUnit
        let stage = PlantAssetStage(growth: safeGrowth, stageCount: safeStageCount)
        let nextStageGrowth = stage.nextIndex.map { Double($0) / Double(safeStageCount) }
        let remainingGrowth = max(0, (nextStageGrowth ?? safeGrowth) - safeGrowth)

        self.stage = stage
        self.growthRemainingToNextStage = remainingGrowth

        guard !plant.isDead else {
            status = .dead
            projectedGrowthPerHour = 0
            estimatedHoursToNextStage = nil
            return
        }

        guard stage.nextIndex != nil else {
            status = .complete
            projectedGrowthPerHour = 0
            estimatedHoursToNextStage = nil
            return
        }

        let moisture = plant.moisturePreference
        guard moisture.fit != .parched else {
            status = .needsWater
            projectedGrowthPerHour = 0
            estimatedHoursToNextStage = nil
            return
        }

        guard plant.health > 0.22 else {
            status = .recovering
            projectedGrowthPerHour = 0
            estimatedHoursToNextStage = nil
            return
        }

        let growthRate = Self.projectedGrowthPerHour(for: plant) * Self.bounded(
            microclimateGrowthFactor,
            lower: 0.56,
            upper: 1.24
        ) * Self.bounded(
            circadianGrowthFactor,
            lower: 0.36,
            upper: 1.16
        )
        projectedGrowthPerHour = growthRate

        guard growthRate > 0, remainingGrowth > 0 else {
            status = .recovering
            estimatedHoursToNextStage = nil
            return
        }

        status = .growing
        estimatedHoursToNextStage = remainingGrowth / growthRate
    }

    public var shortSummary: String {
        switch status {
        case .dead:
            return "Dead"
        case .complete:
            return "Fully grown"
        case .needsWater:
            return "Water to grow"
        case .recovering:
            return "Recovering"
        case .growing:
            guard let estimatedHoursToNextStage else {
                return "Growing"
            }

            if estimatedHoursToNextStage < 0.25 {
                return "Next stage soon"
            }

            if estimatedHoursToNextStage < 1 {
                return "Next stage <1h"
            }

            if estimatedHoursToNextStage < 24 {
                return "Next stage ~\(Int(estimatedHoursToNextStage.rounded()))h"
            }

            let days = max(1, Int((estimatedHoursToNextStage / 24).rounded()))
            return "Next stage ~\(days)d"
        }
    }

    private static func projectedGrowthPerHour(for plant: Plant) -> Double {
        let hydrationQuality = plant.moisturePreference.growthMultiplier
        let nutrientQuality = plant.nutrientProfile.growthMultiplier
        let healthFactor = 0.45 + plant.health * 0.65
        return plant.species.growthPerHour * hydrationQuality * nutrientQuality * healthFactor
    }

    private static func bounded(_ value: Double, lower: Double, upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}
