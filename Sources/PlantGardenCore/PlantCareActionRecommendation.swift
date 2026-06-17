import Foundation

public enum PlantCareActionKind: String, Codable, Sendable {
    case water
    case prune
    case nourish
    case enjoy
}

public struct PlantCareActionRecommendation: Equatable, Sendable {
    public let kind: PlantCareActionKind
    public let summary: String
    public let detail: String

    public init(plant: Plant) {
        switch plant.careNeed {
        case .dead:
            kind = .enjoy
            summary = "Dead"
            detail = "Remove or replant"
        case .urgentWater:
            kind = .water
            summary = "Water now"
            detail = "Restore hydration"
        case .waterSoon:
            kind = .water
            summary = "Water soon"
            detail = "Keep growth steady"
        case .recovering:
            kind = .prune
            summary = "Prune to recover"
            detail = "Reduce stress"
        case .nourish:
            kind = .nourish
            summary = "Nourish growth"
            detail = "Push toward next stage"
        case .thriving:
            kind = .enjoy
            summary = "Enjoy"
            detail = "This plant is steady"
        }
    }

    public var isActionable: Bool {
        kind != .enjoy
    }
}

public extension Plant {
    var careActionRecommendation: PlantCareActionRecommendation {
        PlantCareActionRecommendation(plant: self)
    }
}
