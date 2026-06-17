import Foundation

public enum GardenDesktopOcclusionSnapshotCadence {
    public static let minimumRefreshInterval: TimeInterval = 0.25

    public static func shouldRefresh(
        lastRefreshUptime: TimeInterval?,
        now: TimeInterval,
        minimumInterval: TimeInterval = minimumRefreshInterval
    ) -> Bool {
        guard let lastRefreshUptime else {
            return true
        }

        return now - lastRefreshUptime >= minimumInterval
    }
}
