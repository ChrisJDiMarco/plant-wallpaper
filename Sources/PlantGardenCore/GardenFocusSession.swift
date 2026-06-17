import Foundation

/// A running focus (pomodoro-style) session. While active, garden growth is
/// accelerated; completing the session grants a small bloom-and-health bonus.
public struct GardenFocusSession: Codable, Equatable, Sendable {
    public static let defaultDurations: [TimeInterval] = [25 * 60, 50 * 60]

    /// Growth speed multiplier applied while a session is active.
    public static let growthBoost = 1.6

    public let startedAt: Date
    public let duration: TimeInterval
    /// Sum of every living plant's asset-stage index when the session began.
    /// Lets completion report how many visible growth stages the session grew.
    public let startStageTotal: Int?

    public init(startedAt: Date, duration: TimeInterval, startStageTotal: Int? = nil) {
        self.startedAt = startedAt
        self.duration = max(60, duration)
        self.startStageTotal = startStageTotal
    }

    public var endsAt: Date {
        startedAt.addingTimeInterval(duration)
    }

    public func isActive(at date: Date = Date()) -> Bool {
        date >= startedAt && date < endsAt
    }

    public func isCompleted(at date: Date = Date()) -> Bool {
        date >= endsAt
    }

    public func remainingSeconds(at date: Date = Date()) -> TimeInterval {
        max(0, endsAt.timeIntervalSince(date))
    }

    public func remainingSummary(at date: Date = Date()) -> String {
        let remaining = Int(remainingSeconds(at: date).rounded())
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Lifetime focus statistics for a garden.
public struct GardenFocusStats: Codable, Equatable, Sendable {
    public var completedSessions: Int
    public var totalFocusSeconds: TimeInterval
    public var lastCompletedAt: Date?
    /// Visible growth stages gained across the garden during the most
    /// recently completed session - the payoff line in the notification.
    public var lastSessionStagesGrown: Int?

    public init(
        completedSessions: Int = 0,
        totalFocusSeconds: TimeInterval = 0,
        lastCompletedAt: Date? = nil,
        lastSessionStagesGrown: Int? = nil
    ) {
        self.completedSessions = max(0, completedSessions)
        self.totalFocusSeconds = max(0, totalFocusSeconds)
        self.lastCompletedAt = lastCompletedAt
        self.lastSessionStagesGrown = lastSessionStagesGrown
    }

    public var totalFocusMinutes: Int {
        Int((totalFocusSeconds / 60).rounded())
    }
}
