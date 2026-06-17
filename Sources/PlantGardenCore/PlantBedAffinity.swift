import Foundation

public enum PlantBedFit: String, Codable, Sendable {
    case rooted
    case edge
    case support
    case exposed
}

public struct PlantBedAffinity: Equatable, Sendable {
    public let fit: PlantBedFit
    public let bedScore: Double
    public let growthMultiplier: Double
    public let waterUseMultiplier: Double
    public let healthAdjustmentPerHour: Double
    public let bloomMultiplier: Double
    public let summary: String
    public let shortSummary: String

    public init(plant: Plant) {
        bedScore = Self.nearestBedScore(for: plant.position)

        if bedScore <= 1 {
            fit = .rooted
            growthMultiplier = 1.045
            waterUseMultiplier = 0.94
            healthAdjustmentPerHour = 0.004
            bloomMultiplier = 1.04
            summary = "Stable soil bed"
            shortSummary = "Rooted bed"
        } else if plant.species.isSupportTrainedClimber && Self.isLikelyOnSupport(plant.position) {
            fit = .support
            growthMultiplier = 1.02
            waterUseMultiplier = 0.97
            healthAdjustmentPerHour = 0.002
            bloomMultiplier = 1.04
            summary = "Trained onto structure"
            shortSummary = "On support"
        } else if bedScore <= 1.42 {
            fit = .edge
            growthMultiplier = 0.96
            waterUseMultiplier = 1.02
            healthAdjustmentPerHour = -0.002
            bloomMultiplier = 0.98
            summary = "Bed edge"
            shortSummary = "Bed edge"
        } else {
            fit = .exposed
            growthMultiplier = 0.78
            waterUseMultiplier = 1.15
            healthAdjustmentPerHour = -0.020
            bloomMultiplier = 0.82
            summary = "Off-bed exposure"
            shortSummary = "Off bed"
        }
    }

    private static func nearestBedScore(for point: GardenPoint) -> Double {
        bedZones.map { zone in
            let dx = (point.x - zone.center.x) / zone.radiusX
            let dy = (point.y - zone.center.y) / zone.radiusY
            return hypot(dx, dy)
        }.min() ?? Double.greatestFiniteMagnitude
    }

    private static func isLikelyOnSupport(_ point: GardenPoint) -> Bool {
        point.y >= 0.10 && point.y <= 0.74
    }

    private static let bedZones = [
        BedZone(center: GardenPoint(x: 0.22, y: 0.66), radiusX: 0.24, radiusY: 0.14),
        BedZone(center: GardenPoint(x: 0.50, y: 0.78), radiusX: 0.32, radiusY: 0.10),
        BedZone(center: GardenPoint(x: 0.76, y: 0.66), radiusX: 0.24, radiusY: 0.14)
    ]
}

private struct BedZone: Equatable, Sendable {
    let center: GardenPoint
    let radiusX: Double
    let radiusY: Double
}

public extension Plant {
    var bedAffinity: PlantBedAffinity {
        PlantBedAffinity(plant: self)
    }
}
