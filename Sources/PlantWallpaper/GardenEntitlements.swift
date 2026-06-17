import Foundation

extension Notification.Name {
    /// Posted whenever the resolved entitlement changes at runtime (for
    /// example, the user unlocks Pro locally from the pricing page). Menus and
    /// open windows observe this to refresh their locked/unlocked surfaces.
    static let gardenEntitlementsDidChange = Notification.Name("gardenEntitlementsDidChange")
}

enum GardenProductTier: String, Equatable {
    case free
    case pro

    var displayName: String {
        switch self {
        case .free:
            "Free"
        case .pro:
            "Pro"
        }
    }
}

enum GardenDistributionChannel: String, Equatable {
    case directDownload = "direct-download"
    case macAppStore = "mac-app-store"

    var displayName: String {
        switch self {
        case .directDownload:
            "Direct Download"
        case .macAppStore:
            "Mac App Store"
        }
    }
}

enum GardenPaidValidationProvider: String, Equatable {
    case none
    case stripe
    case storeKit = "storekit"
    case customLicense = "custom-license"

    var displayName: String {
        switch self {
        case .none:
            "None"
        case .stripe:
            "Stripe"
        case .storeKit:
            "StoreKit"
        case .customLicense:
            "Custom License"
        }
    }
}

/// Features reserved for the paid tier. This keeps call sites stable while the
/// real Stripe/StoreKit/license validation layer is still being connected.
enum GardenProFeature: String, CaseIterable {
    case weatherSync
    case focusSessions
    case aiSceneGeneration
    case fullSpeciesCatalog
    case sceneLibrary
    case roomStudio
    case alienUFOGarden
    case aiLockView
    case progressionMode
    case timeLapseExport
    case gnomeSocieties
    case birdSkyZones
    case advancedScreensaverSync
    case jarvisAssistant
    case misoVoice
    case premiumRadioCompanions

    var displayName: String {
        switch self {
        case .weatherSync:
            "Weather Sync"
        case .focusSessions:
            "Focus Sessions"
        case .aiSceneGeneration:
            "AI Scene Generation"
        case .fullSpeciesCatalog:
            "Full Species Catalog"
        case .sceneLibrary:
            "Premium Scene Library"
        case .roomStudio:
            "Room Studio"
        case .alienUFOGarden:
            "Alien/UFO Garden"
        case .aiLockView:
            "AI Lock View"
        case .progressionMode:
            "Progression Mode"
        case .timeLapseExport:
            "Time-Lapse Export"
        case .gnomeSocieties:
            "Gnome Societies"
        case .birdSkyZones:
            "Bird Sky Areas"
        case .advancedScreensaverSync:
            "Advanced Screensaver Sync"
        case .jarvisAssistant:
            "Jarvis Assistant"
        case .misoVoice:
            "Miso Voice Mode"
        case .premiumRadioCompanions:
            "Premium Radio Companions"
        }
    }

    var paywallMessage: String {
        "\(displayName) is part of Plant Wallpaper Pro."
    }
}

struct GardenEntitlementSnapshot: Equatable {
    var tier: GardenProductTier
    var isPro: Bool
    var isDevelopmentUnlocked: Bool
    var isPaidValidationConfigured: Bool
    var paidValidationProvider: GardenPaidValidationProvider
    var sourceDescription: String

    static let free = GardenEntitlementSnapshot(
        tier: .free,
        isPro: false,
        isDevelopmentUnlocked: false,
        isPaidValidationConfigured: false,
        paidValidationProvider: .none,
        sourceDescription: "Free"
    )
}

/// Persists the tier the operator selected on this Mac from the pricing page.
/// This is a local, user-controlled override that unlocks Pro immediately while
/// the real Stripe/StoreKit/license validation layer is still being connected.
/// It is intentionally separate from `isPaidValidationConfigured`, which keeps
/// reporting whether a real payment backend exists.
struct GardenLocalEntitlementStore {
    static let defaultsKey = "PlantWallpaperLocalEntitlementTier"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedTier: GardenProductTier? {
        get {
            guard let raw = defaults.string(forKey: Self.defaultsKey) else {
                return nil
            }
            return GardenProductTier(rawValue: raw)
        }
        nonmutating set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Self.defaultsKey)
            } else {
                defaults.removeObject(forKey: Self.defaultsKey)
            }
        }
    }
}

enum GardenEntitlementResolver {
    static let developmentUnlockEnvironmentKey = "PLANT_WALLPAPER_DEV_UNLOCK_PRO"
    static let distributionChannelInfoKey = "PlantWallpaperDistributionChannel"
    static let paidValidationConfiguredInfoKey = "PlantWallpaperPaidValidationConfigured"
    static let paidValidationProviderInfoKey = "PlantWallpaperPaidValidationProvider"
    static let validatedTierInfoKey = "PlantWallpaperValidatedTier"

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:],
        isDebugBuild: Bool = isCurrentBuildDebug,
        localTier: GardenProductTier? = GardenLocalEntitlementStore().selectedTier
    ) -> GardenEntitlementSnapshot {
        let paidValidationProvider = validationProvider(from: infoDictionary[paidValidationProviderInfoKey])
        let paidValidationConfigured = truthy(infoDictionary[paidValidationConfiguredInfoKey])
            || paidValidationProvider != .none
        let developmentUnlockRequested = truthy(environment[developmentUnlockEnvironmentKey])
        let developmentUnlocked = isDebugBuild && developmentUnlockRequested

        if developmentUnlocked {
            return GardenEntitlementSnapshot(
                tier: .pro,
                isPro: true,
                isDevelopmentUnlocked: true,
                isPaidValidationConfigured: paidValidationConfigured,
                paidValidationProvider: paidValidationProvider,
                sourceDescription: "Development unlock"
            )
        }

        if localTier == .pro {
            return GardenEntitlementSnapshot(
                tier: .pro,
                isPro: true,
                isDevelopmentUnlocked: false,
                isPaidValidationConfigured: paidValidationConfigured,
                paidValidationProvider: paidValidationProvider,
                sourceDescription: "Local Pro (this Mac)"
            )
        }

        let validatedTier = tier(from: infoDictionary[validatedTierInfoKey])
        if paidValidationConfigured, validatedTier == .pro {
            return GardenEntitlementSnapshot(
                tier: .pro,
                isPro: true,
                isDevelopmentUnlocked: false,
                isPaidValidationConfigured: true,
                paidValidationProvider: paidValidationProvider,
                sourceDescription: "Validated Pro"
            )
        }

        return GardenEntitlementSnapshot(
            tier: .free,
            isPro: false,
            isDevelopmentUnlocked: false,
            isPaidValidationConfigured: paidValidationConfigured,
            paidValidationProvider: paidValidationProvider,
            sourceDescription: paidValidationConfigured
                ? validationConfiguredDescription(for: paidValidationProvider)
                : "Free"
        )
    }

    private static var isCurrentBuildDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private static func tier(from value: Any?) -> GardenProductTier {
        guard let string = value as? String else {
            return .free
        }

        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == GardenProductTier.pro.rawValue ? .pro : .free
    }

    static func distributionChannel(from value: Any?) -> GardenDistributionChannel {
        guard let string = value as? String else {
            return .directDownload
        }

        switch normalizedToken(string) {
        case "mac-app-store", "app-store", "mas", "storekit":
            return .macAppStore
        default:
            return .directDownload
        }
    }

    private static func validationProvider(from value: Any?) -> GardenPaidValidationProvider {
        guard let string = value as? String else {
            return .none
        }

        switch normalizedToken(string) {
        case "stripe":
            return .stripe
        case "storekit", "store-kit", "iap", "in-app-purchase":
            return .storeKit
        case "custom-license", "license", "custom":
            return .customLicense
        default:
            return .none
        }
    }

    private static func validationConfiguredDescription(
        for provider: GardenPaidValidationProvider
    ) -> String {
        provider == .none
            ? "Paid validation configured"
            : "\(provider.displayName) validation configured"
    }

    private static func truthy(_ value: Any?) -> Bool {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return ["1", "true", "yes", "y", "on", "enabled"].contains(normalized)
        default:
            return false
        }
    }

    private static func normalizedToken(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

@MainActor
final class GardenEntitlements {
    static let shared = GardenEntitlements()

    private(set) var snapshot: GardenEntitlementSnapshot

    init(snapshot: GardenEntitlementSnapshot = GardenEntitlementResolver.resolve()) {
        self.snapshot = snapshot
    }

    var isPro: Bool {
        snapshot.isPro
    }

    var tier: GardenProductTier {
        snapshot.tier
    }

    var isPaidValidationConfigured: Bool {
        snapshot.isPaidValidationConfigured
    }

    var paidValidationProvider: GardenPaidValidationProvider {
        snapshot.paidValidationProvider
    }

    var isDevelopmentUnlocked: Bool {
        snapshot.isDevelopmentUnlocked
    }

    var sourceDescription: String {
        snapshot.sourceDescription
    }

    /// True when the current Pro access comes from the local pricing-page
    /// unlock on this Mac rather than a development or validated source.
    var hasLocalProUnlock: Bool {
        GardenLocalEntitlementStore().selectedTier == .pro
    }

    func refresh() {
        snapshot = GardenEntitlementResolver.resolve()
    }

    /// Records the operator's tier choice locally and re-resolves the snapshot.
    /// Posts `.gardenEntitlementsDidChange` so menus and open windows refresh.
    func setLocalTier(_ tier: GardenProductTier?) {
        GardenLocalEntitlementStore().selectedTier = tier
        refresh()
        NotificationCenter.default.post(name: .gardenEntitlementsDidChange, object: self)
    }

    /// Grants full Pro access on this Mac immediately. Replace the call site
    /// with a real checkout once payment validation is connected.
    func unlockProLocally() {
        setLocalTier(.pro)
    }

    /// Returns to the Free tier, clearing the local Pro unlock.
    func selectFreeLocally() {
        setLocalTier(.free)
    }

    func isUnlocked(_ feature: GardenProFeature) -> Bool {
        snapshot.isPro
    }

    func message(for feature: GardenProFeature) -> String {
        feature.paywallMessage
    }
}
