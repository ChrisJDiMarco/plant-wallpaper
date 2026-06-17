import Foundation
import Testing
@testable import PlantWallpaper

@Suite("Gardener profile store")
struct GardenProfileStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "test.profile.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("defaults to the fallback name and first avatar")
    func defaultsToFallbacks() {
        let store = GardenProfileStore(defaults: makeDefaults())
        #expect(store.displayName == GardenProfile.defaultDisplayName)
        #expect(store.avatarSymbol == GardenProfile.avatarSymbols[0])
    }

    @Test("persists a trimmed display name")
    func persistsTrimmedName() {
        let defaults = makeDefaults()
        GardenProfileStore(defaults: defaults).displayName = "  Chris  "
        #expect(GardenProfileStore(defaults: defaults).displayName == "Chris")
    }

    @Test("a blank name falls back to the default")
    func blankNameFallsBack() {
        let store = GardenProfileStore(defaults: makeDefaults())
        store.displayName = "   "
        #expect(store.displayName == GardenProfile.defaultDisplayName)
    }

    @Test("persists a known avatar symbol")
    func persistsKnownAvatar() {
        let defaults = makeDefaults()
        let symbol = GardenProfile.avatarSymbols[2]
        GardenProfileStore(defaults: defaults).avatarSymbol = symbol
        #expect(GardenProfileStore(defaults: defaults).avatarSymbol == symbol)
    }

    @Test("an unknown avatar symbol falls back to the first option")
    func unknownAvatarFallsBack() {
        let store = GardenProfileStore(defaults: makeDefaults())
        store.avatarSymbol = "not.a.real.symbol"
        #expect(store.avatarSymbol == GardenProfile.avatarSymbols[0])
    }
}
