import Foundation
import Testing
@testable import PlantWallpaper

@Suite("Local entitlement store")
struct GardenLocalEntitlementStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "test.local-entitlement.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("defaults to no local tier")
    func defaultsToNoLocalTier() {
        let store = GardenLocalEntitlementStore(defaults: makeDefaults())
        #expect(store.selectedTier == nil)
    }

    @Test("persists a selected pro tier across reads")
    func persistsProTier() {
        let defaults = makeDefaults()
        GardenLocalEntitlementStore(defaults: defaults).selectedTier = .pro
        #expect(GardenLocalEntitlementStore(defaults: defaults).selectedTier == .pro)
    }

    @Test("clearing the local tier removes it")
    func clearingRemovesLocalTier() {
        let store = GardenLocalEntitlementStore(defaults: makeDefaults())
        store.selectedTier = .pro
        store.selectedTier = nil
        #expect(store.selectedTier == nil)
    }

    @Test("beta full access overrides a local pro selection")
    func betaFullAccessOverridesLocalPro() {
        let snapshot = GardenEntitlementResolver.resolve(
            environment: [:],
            infoDictionary: [:],
            isDebugBuild: false,
            localTier: .pro
        )

        #expect(snapshot.isPro)
        #expect(snapshot.tier == .pro)
        #expect(!snapshot.isDevelopmentUnlocked)
        #expect(!snapshot.isPaidValidationConfigured)
        #expect(snapshot.sourceDescription == "Beta Full Access")
    }

    @Test("no local tier still resolves to beta full access")
    func noLocalTierResolvesToBetaFullAccess() {
        let snapshot = GardenEntitlementResolver.resolve(
            environment: [:],
            infoDictionary: [:],
            isDebugBuild: false,
            localTier: nil
        )

        #expect(snapshot.isPro)
        #expect(snapshot.tier == .pro)
        #expect(snapshot.sourceDescription == "Beta Full Access")
    }

    @Test("beta full access overrides an old local free selection")
    func betaFullAccessOverridesLocalFree() {
        let snapshot = GardenEntitlementResolver.resolve(
            environment: [:],
            infoDictionary: [:],
            isDebugBuild: false,
            localTier: .free
        )

        #expect(snapshot.isPro)
        #expect(snapshot.tier == .pro)
        #expect(snapshot.sourceDescription == "Beta Full Access")
    }

    @Test("development unlock outranks a local free selection")
    func developmentUnlockOutranksLocalFree() {
        let snapshot = GardenEntitlementResolver.resolve(
            environment: [GardenEntitlementResolver.developmentUnlockEnvironmentKey: "1"],
            infoDictionary: [:],
            isDebugBuild: true,
            localTier: .free
        )

        #expect(snapshot.isPro)
        #expect(snapshot.isDevelopmentUnlocked)
        #expect(snapshot.sourceDescription == "Development unlock")
    }
}
