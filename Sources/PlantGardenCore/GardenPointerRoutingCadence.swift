import Foundation

public enum GardenPointerRoutingCadence {
    public static let refreshInterval: TimeInterval = 0.04
    public static let movementThreshold: Double = 1.0

    public static func shouldUpdateMouseRouting(
        previousX: Double?,
        previousY: Double?,
        currentX: Double,
        currentY: Double,
        isMouseButtonDown: Bool,
        hasActiveDrag: Bool,
        hasActivePress: Bool,
        isPollingDragActive: Bool
    ) -> Bool {
        if isMouseButtonDown || hasActiveDrag || hasActivePress || isPollingDragActive {
            return true
        }

        guard let previousX, let previousY else {
            return true
        }

        return hypot(currentX - previousX, currentY - previousY) >= movementThreshold
    }
}
