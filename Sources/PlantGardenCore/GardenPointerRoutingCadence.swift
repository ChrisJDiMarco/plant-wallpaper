import Foundation

public enum GardenPointerRoutingCadence {
    public static let refreshInterval: TimeInterval = 0.04
    public static let idleRefreshInterval: TimeInterval = 0.25
    /// Consecutive still ticks at the active rate before slowing down (~1 s).
    public static let idleTickThreshold = 25
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
