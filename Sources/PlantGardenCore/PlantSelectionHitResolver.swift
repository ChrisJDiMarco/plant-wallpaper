import Foundation

public struct PlantSelectionHitCandidate: Equatable, Sendable {
    public let id: UUID
    public let distanceFromClick: Double
    public let depth: Double
    public let isSelected: Bool

    public init(id: UUID, distanceFromClick: Double, depth: Double, isSelected: Bool) {
        self.id = id
        self.distanceFromClick = max(0, distanceFromClick)
        self.depth = depth.clampedUnit
        self.isSelected = isSelected
    }
}

public enum PlantSelectionHitResolver {
    public static func preferredPlantID(from candidates: [PlantSelectionHitCandidate]) -> UUID? {
        candidates.min { lhs, rhs in
            score(for: lhs) < score(for: rhs)
        }?.id
    }

    private static func score(for candidate: PlantSelectionHitCandidate) -> Double {
        let selectedStickinessPenalty = candidate.isSelected ? 0.075 : 0
        let foregroundBias = candidate.depth * 0.012
        return candidate.distanceFromClick + selectedStickinessPenalty - foregroundBias
    }
}
