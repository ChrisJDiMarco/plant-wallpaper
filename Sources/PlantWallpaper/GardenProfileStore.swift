import Foundation

/// The operator's local gardener profile. Stored on this Mac only — there is no
/// server or sign-in. "Logged in" simply means a profile exists, which it always
/// does (it falls back to sensible defaults).
struct GardenProfile: Equatable {
    var displayName: String
    var avatarSymbol: String

    static let defaultDisplayName = "Gardener"

    /// SF Symbol options offered in the profile avatar picker.
    static let avatarSymbols = [
        "leaf.fill",
        "cat.fill",
        "tree.fill",
        "ladybug.fill",
        "sparkles",
        "moon.stars.fill",
        "drop.fill",
        "sun.max.fill"
    ]
}

/// UserDefaults-backed persistence for the local gardener profile.
struct GardenProfileStore {
    static let displayNameKey = "PlantWallpaperProfileDisplayName"
    static let avatarSymbolKey = "PlantWallpaperProfileAvatarSymbol"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var displayName: String {
        get {
            let stored = defaults.string(forKey: Self.displayNameKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let stored, !stored.isEmpty else {
                return GardenProfile.defaultDisplayName
            }
            return stored
        }
        nonmutating set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            defaults.set(trimmed.isEmpty ? GardenProfile.defaultDisplayName : trimmed, forKey: Self.displayNameKey)
        }
    }

    var avatarSymbol: String {
        get {
            let stored = defaults.string(forKey: Self.avatarSymbolKey)
            guard let stored, GardenProfile.avatarSymbols.contains(stored) else {
                return GardenProfile.avatarSymbols[0]
            }
            return stored
        }
        nonmutating set {
            let symbol = GardenProfile.avatarSymbols.contains(newValue) ? newValue : GardenProfile.avatarSymbols[0]
            defaults.set(symbol, forKey: Self.avatarSymbolKey)
        }
    }

    var profile: GardenProfile {
        GardenProfile(displayName: displayName, avatarSymbol: avatarSymbol)
    }
}
