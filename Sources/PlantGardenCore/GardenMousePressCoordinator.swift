import Foundation

public struct GardenMousePressCoordinator: Equatable, Sendable {
    public static let duplicateSuppressionInterval: TimeInterval = 0.10

    private var handledAt: Date?

    public var isPressActive: Bool {
        handledAt != nil
    }

    public init(isPressActive: Bool = false, handledAt: Date? = nil) {
        self.handledAt = isPressActive ? (handledAt ?? Date()) : handledAt
    }

    public mutating func markHandled(at date: Date = Date()) {
        handledAt = date
    }

    public mutating func shouldSuppressMouseDown(at date: Date = Date()) -> Bool {
        guard let handledAt else {
            return false
        }

        if date.timeIntervalSince(handledAt) <= Self.duplicateSuppressionInterval {
            return true
        }

        self.handledAt = nil
        return false
    }

    public mutating func endPress() {
        handledAt = nil
    }
}
