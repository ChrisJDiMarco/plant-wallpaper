import Foundation

public enum PlantWaterForecastStatus: String, Codable, Sendable {
    case dead
    case urgent
    case soon
    case comfortable
    case saturated
}

public struct PlantWaterForecast: Equatable, Sendable {
    public let status: PlantWaterForecastStatus
    public let projectedWaterUsePerHour: Double
    public let estimatedHoursUntilWaterSoon: Double?
    public let estimatedHoursUntilUrgent: Double?

    public init(
        plant: Plant,
        ambientMoisture: Double,
        microclimateWaterUseFactor: Double = 1
    ) {
        let hydration = plant.hydration.clampedUnit
        let moisture = plant.moisturePreference

        if plant.isDead {
            status = .dead
            projectedWaterUsePerHour = 0
            estimatedHoursUntilWaterSoon = nil
            estimatedHoursUntilUrgent = nil
            return
        }

        let waterUse = Self.projectedWaterUsePerHour(
            for: plant,
            ambientMoisture: ambientMoisture,
            microclimateWaterUseFactor: microclimateWaterUseFactor
        )
        projectedWaterUsePerHour = waterUse

        if moisture.fit == .parched {
            status = .urgent
            estimatedHoursUntilWaterSoon = nil
            estimatedHoursUntilUrgent = nil
            return
        }

        if moisture.fit == .dry {
            status = .soon
            estimatedHoursUntilWaterSoon = 0
            estimatedHoursUntilUrgent = Self.hoursToThreshold(
                currentHydration: hydration,
                threshold: moisture.urgentHydrationThreshold,
                waterUsePerHour: waterUse
            )
            return
        }

        if moisture.fit == .saturated {
            status = .saturated
        } else {
            status = .comfortable
        }

        estimatedHoursUntilWaterSoon = Self.hoursToThreshold(
            currentHydration: hydration,
            threshold: moisture.waterSoonHydrationThreshold,
            waterUsePerHour: waterUse
        )
        estimatedHoursUntilUrgent = Self.hoursToThreshold(
            currentHydration: hydration,
            threshold: moisture.urgentHydrationThreshold,
            waterUsePerHour: waterUse
        )
    }

    public var shortSummary: String {
        switch status {
        case .dead:
            return "Dead"
        case .urgent:
            return "Water now"
        case .soon:
            return "Water soon"
        case .saturated:
            return "Soil wet"
        case .comfortable:
            guard let estimatedHoursUntilWaterSoon else {
                return "Water later"
            }

            if estimatedHoursUntilWaterSoon < 1 {
                return "Water <1h"
            }

            if estimatedHoursUntilWaterSoon < 24 {
                return "Water ~\(Int(estimatedHoursUntilWaterSoon.rounded()))h"
            }

            let days = max(1, Int((estimatedHoursUntilWaterSoon / 24).rounded()))
            return "Water ~\(days)d"
        }
    }

    public static func projectedWaterUsePerHour(
        for plant: Plant,
        ambientMoisture: Double,
        microclimateWaterUseFactor: Double = 1
    ) -> Double {
        plant.species.waterUsePerHour
            * (1.0 + plant.growth.clampedUnit * 0.28)
            * (1.0 - ambientMoisture.clampedUnit * 0.22)
            * min(1.28, max(0.72, microclimateWaterUseFactor))
            * plant.moisturePreference.waterUseMultiplier
    }

    private static func hoursToThreshold(
        currentHydration: Double,
        threshold: Double,
        waterUsePerHour: Double
    ) -> Double? {
        guard currentHydration > threshold, waterUsePerHour > 0 else {
            return nil
        }

        return (currentHydration - threshold) / waterUsePerHour
    }
}
