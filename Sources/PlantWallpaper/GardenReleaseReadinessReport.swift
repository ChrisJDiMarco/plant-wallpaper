import AppKit
import Foundation
import PlantGardenCore
import Security

enum GardenReleaseReadinessStatus: String {
    case ready
    case needsAttention = "needs_attention"

    var displayName: String {
        switch self {
        case .ready:
            "Ready"
        case .needsAttention:
            "Needs attention"
        }
    }
}

enum GardenReleaseReadinessSeverity: String {
    case blocker
    case warning
    case note
}

struct GardenReleaseReadinessIssue: Equatable {
    let id: String
    let severity: GardenReleaseReadinessSeverity
    let title: String
    let detail: String
    let action: String

    var jsonObject: [String: Any] {
        [
            "id": id,
            "severity": severity.rawValue,
            "title": title,
            "detail": detail,
            "action": action
        ]
    }
}

struct GardenReleaseReadinessEnvironment: Equatable {
    var isRunningFromAppBundle: Bool
    var isInputMonitoringLimited: Bool
    var isScreenSaverInstalled: Bool
    var isOpenAIKeyConfigured: Bool
    var isProDevelopmentUnlocked: Bool
    var isPaidEntitlementValidationConfigured: Bool = false
    var paidValidationProvider: GardenPaidValidationProvider = .none
    var distributionChannel: GardenDistributionChannel = .directDownload
    var isAppSandboxed: Bool = false
    var screenCount: Int

    @MainActor
    static func current() -> GardenReleaseReadinessEnvironment {
        let entitlementSnapshot = GardenEntitlements.shared.snapshot
        let infoDictionary = Bundle.main.infoDictionary ?? [:]

        return GardenReleaseReadinessEnvironment(
            isRunningFromAppBundle: Bundle.main.bundleIdentifier != nil,
            isInputMonitoringLimited: GardenDesktopEventTapStatus.isUnavailable,
            isScreenSaverInstalled: defaultScreenSaverInstalled(),
            isOpenAIKeyConfigured: OpenAIAPIKeyStore.load() != nil,
            isProDevelopmentUnlocked: entitlementSnapshot.isDevelopmentUnlocked,
            isPaidEntitlementValidationConfigured: entitlementSnapshot.isPaidValidationConfigured,
            paidValidationProvider: entitlementSnapshot.paidValidationProvider,
            distributionChannel: GardenEntitlementResolver.distributionChannel(
                from: infoDictionary[GardenEntitlementResolver.distributionChannelInfoKey]
            ),
            isAppSandboxed: appSandboxEnabled(),
            screenCount: max(0, NSScreen.screens.count)
        )
    }

    private static func defaultScreenSaverInstalled() -> Bool {
        let screenSaverURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers/Plant Wallpaper.saver")
        return FileManager.default.fileExists(atPath: screenSaverURL.path)
    }

    private static func appSandboxEnabled() -> Bool {
        currentCodeEntitlementBool(for: "com.apple.security.app-sandbox")
    }

    private static func currentCodeEntitlementBool(for key: String) -> Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(
            Bundle.main.bundleURL as CFURL,
            SecCSFlags(),
            &staticCode
        ) == errSecSuccess, let staticCode else {
            return false
        }

        var signingInfo: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &signingInfo) == errSecSuccess,
              let dictionary = signingInfo as? [String: Any],
              let entitlements = dictionary[kSecCodeInfoEntitlementsDict as String] as? [String: Any] else {
            return false
        }

        switch entitlements[key] {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            return ["1", "true", "yes", "on"].contains(
                string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            )
        default:
            return false
        }
    }
}

struct GardenReleaseReadinessSummary: Equatable {
    let status: GardenReleaseReadinessStatus
    let score: Int
    let issues: [GardenReleaseReadinessIssue]

    var headline: String {
        if issues.isEmpty {
            return "Ready for normal use"
        }

        let blockers = issues.filter { $0.severity == .blocker }.count
        let warnings = issues.filter { $0.severity == .warning }.count
        if blockers > 0 {
            return "\(blockers) blocker\(blockers == 1 ? "" : "s"), \(warnings) warning\(warnings == 1 ? "" : "s")"
        }
        return "\(warnings) warning\(warnings == 1 ? "" : "s")"
    }

    var primaryIssueSummary: String {
        guard let issue = issues.first else {
            return "No issues found"
        }

        return "\(issue.title): \(issue.action)"
    }

    var issueBreakdownSummary: String {
        guard !issues.isEmpty else {
            return "No blockers, warnings, or notes"
        }

        let blockers = issues.filter { $0.severity == .blocker }.count
        let warnings = issues.filter { $0.severity == .warning }.count
        let notes = issues.filter { $0.severity == .note }.count
        return [
            countSummary(blockers, singular: "blocker", plural: "blockers"),
            countSummary(warnings, singular: "warning", plural: "warnings"),
            countSummary(notes, singular: "note", plural: "notes")
        ].joined(separator: ", ")
    }

    var nextActionSummary: String {
        guard let issue = issues.first else {
            return "No action needed"
        }

        return issue.action
    }

    var jsonObject: [String: Any] {
        [
            "status": status.rawValue,
            "score": score,
            "headline": headline,
            "primaryIssue": primaryIssueSummary,
            "issues": issues.map(\.jsonObject)
        ]
    }

    private func countSummary(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }
}

@MainActor
enum GardenReleaseReadinessReport {
    static func makeSummary(
        store: GardenStore,
        wallpaperManager: WallpaperManager,
        timeLapseRecorder: GardenTimeLapseRecorder?,
        environment: GardenReleaseReadinessEnvironment = .current()
    ) -> GardenReleaseReadinessSummary {
        var issues: [GardenReleaseReadinessIssue] = []
        let state = store.state
        let activeSceneKey = GardenWallpaperScene.canonicalKey(
            for: store.activeSceneKey ?? wallpaperManager.selectedWallpaperSceneKey
        )

        if !environment.isRunningFromAppBundle {
            issues.append(.init(
                id: "not-app-bundle",
                severity: .blocker,
                title: "Not running from the app bundle",
                detail: "Weather, login item, permissions, and some resource lookups expect Plant Wallpaper.app.",
                action: "Build, install, and launch /Applications/Plant Wallpaper.app."
            ))
        }

        if environment.screenCount <= 0 {
            issues.append(.init(
                id: "no-screens",
                severity: .blocker,
                title: "No displays detected",
                detail: "The wallpaper renderer needs at least one macOS display.",
                action: "Reconnect a display or relaunch after macOS reports an active screen."
            ))
        }

        if let scene = GardenWallpaperScene.scene(forKey: activeSceneKey), !scene.isSelectableScene {
            issues.append(.init(
                id: "scene-unavailable",
                severity: .warning,
                title: "Active scene is not public-ready",
                detail: "\(scene.displayName) is marked unavailable: \(scene.unavailableSceneReason ?? "no reason provided").",
                action: "Switch to a selectable scene from the Wallpaper & Scenes menu."
            ))
        } else if GardenWallpaperScene.scene(forKey: activeSceneKey) == nil,
                  !wallpaperManager.customWallpapers.contains(where: { $0.key == activeSceneKey }) {
            issues.append(.init(
                id: "scene-missing",
                severity: .warning,
                title: "Active scene cannot be found",
                detail: "The saved scene key does not match a bundled or custom wallpaper scene.",
                action: "Switch to a bundled scene so the saved selection repairs itself."
            ))
        }

        if environment.isInputMonitoringLimited {
            issues.append(.init(
                id: "input-monitoring-limited",
                severity: .warning,
                title: "Desktop click permission is limited",
                detail: "macOS blocked the event tap, so direct desktop interactions may fall back or miss clicks.",
                action: "Open Privacy & Security > Input Monitoring and allow Plant Wallpaper."
            ))
        }

        if !environment.isScreenSaverInstalled {
            issues.append(.init(
                id: "screensaver-not-installed",
                severity: .note,
                title: "Screen saver is not installed",
                detail: "The app can still run, but macOS screen saver mode will not show Plant Wallpaper.",
                action: "Install Plant Wallpaper.saver into ~/Library/Screen Savers."
            ))
        }

        if !environment.isOpenAIKeyConfigured {
            issues.append(.init(
                id: "openai-key-missing",
                severity: .warning,
                title: "OpenAI API key is missing",
                detail: "Wallpaper edits, generated scenes, custom plants, and room objects need an API key unless app-hosted credits are later enabled.",
                action: "Add a key in OpenAI API Key Settings before using AI generation."
            ))
        }

        if environment.isProDevelopmentUnlocked {
            issues.append(.init(
                id: "development-entitlements",
                severity: .blocker,
                title: "Paid features are development-unlocked",
                detail: "Pro-only surfaces are accessible without receipt, subscription, or license validation.",
                action: "Connect Stripe or StoreKit validation, or disable Pro-only public claims before a paid public release."
            ))
        }

        if !environment.isPaidEntitlementValidationConfigured {
            issues.append(.init(
                id: "paid-validation-missing",
                severity: .blocker,
                title: "Paid validation is not connected",
                detail: "Pricing and Pro surfaces mention paid features, but no receipt, subscription, or license validation is configured.",
                action: environment.distributionChannel == .macAppStore
                    ? "Connect StoreKit receipt/subscription validation before submitting the Mac App Store build."
                    : "Connect Stripe or custom license validation before selling the direct-download build."
            ))
        }

        if environment.isPaidEntitlementValidationConfigured,
           environment.paidValidationProvider == .none {
            issues.append(.init(
                id: "paid-validation-provider-unspecified",
                severity: .warning,
                title: "Paid validation provider is not stamped",
                detail: "The build says paid validation is configured, but does not say whether it uses Stripe, StoreKit, or a custom license service.",
                action: "Stamp PlantWallpaperPaidValidationProvider in Info.plist during packaging."
            ))
        }

        switch environment.distributionChannel {
        case .directDownload:
            if environment.paidValidationProvider == .storeKit {
                issues.append(.init(
                    id: "direct-download-storekit-provider",
                    severity: .blocker,
                    title: "Direct-download build uses StoreKit",
                    detail: "A website-distributed app should validate paid access through Stripe or a license backend, not App Store-only purchase state.",
                    action: "Switch the paid validation provider to Stripe/custom license, or build this as a Mac App Store channel."
                ))
            }
        case .macAppStore:
            if !environment.isAppSandboxed {
                issues.append(.init(
                    id: "app-store-sandbox-missing",
                    severity: .blocker,
                    title: "Mac App Store build is not sandboxed",
                    detail: "Mac App Store submissions are expected to run with App Sandbox entitlements and sandbox-compatible file/network behavior.",
                    action: "Create a sandboxed App Store archive with com.apple.security.app-sandbox enabled."
                ))
            }

            if environment.paidValidationProvider != .storeKit {
                issues.append(.init(
                    id: "app-store-storekit-missing",
                    severity: .blocker,
                    title: "Mac App Store build is not using StoreKit",
                    detail: "Digital Pro features in a Mac App Store build need StoreKit/In-App Purchase entitlement validation, not an external Stripe checkout path.",
                    action: "Use StoreKit for the Mac App Store build and keep Stripe only in the direct-download build."
                ))
            }
        }

        if state.settings.timeLapseCadence != .off,
           let storage = timeLapseRecorder?.inventorySummary().byteCount,
           storage > 500 * 1_024 * 1_024 {
            issues.append(.init(
                id: "timelapse-storage-large",
                severity: .note,
                title: "Time-lapse storage is getting large",
                detail: "Captured frames currently use \(ByteCountFormatter.string(fromByteCount: storage, countStyle: .file)).",
                action: "Use Privacy & Storage to switch cadence to Weekly/Off or delete old frames."
            ))
        }

        let score = max(0, 100 - issues.reduce(0) { total, issue in
            switch issue.severity {
            case .blocker:
                total + 28
            case .warning:
                total + 12
            case .note:
                total + 4
            }
        })

        return GardenReleaseReadinessSummary(
            status: issues.contains { $0.severity == .blocker || $0.severity == .warning } ? .needsAttention : .ready,
            score: score,
            issues: issues
        )
    }
}
