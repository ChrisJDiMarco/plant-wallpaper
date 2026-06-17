import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden desktop occlusion snapshot cadence")
struct GardenDesktopOcclusionSnapshotCadenceTests {
    @Test("missing cache refreshes immediately")
    func missingCacheRefreshesImmediately() {
        #expect(GardenDesktopOcclusionSnapshotCadence.shouldRefresh(lastRefreshUptime: nil, now: 10))
    }

    @Test("recent cache is reused")
    func recentCacheIsReused() {
        #expect(!GardenDesktopOcclusionSnapshotCadence.shouldRefresh(lastRefreshUptime: 10, now: 10.12))
    }

    @Test("expired cache refreshes")
    func expiredCacheRefreshes() {
        #expect(GardenDesktopOcclusionSnapshotCadence.shouldRefresh(lastRefreshUptime: 10, now: 10.40))
    }
}
