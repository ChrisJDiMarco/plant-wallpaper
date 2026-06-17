import Foundation

public extension Plant {
    func growthMilestoneIntensity(at date: Date = Date(), duration: TimeInterval = 90) -> Double {
        guard duration > 0, let lastStageChangedAt else {
            return 0
        }

        let elapsed = date.timeIntervalSince(lastStageChangedAt)
        guard elapsed >= 0, elapsed < duration else {
            return 0
        }

        return (1 - elapsed / duration).clampedUnit
    }
}
