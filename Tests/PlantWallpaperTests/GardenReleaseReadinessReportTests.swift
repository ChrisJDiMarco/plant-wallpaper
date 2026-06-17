import Foundation
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden release readiness report")
struct GardenReleaseReadinessReportTests {
    @Test("entitlements do not development unlock pro surfaces by default")
    func entitlementsDoNotDevelopmentUnlockProSurfacesByDefault() {
        let snapshot = GardenEntitlementResolver.resolve(
            environment: [:],
            infoDictionary: [:],
            isDebugBuild: true
        )

        #expect(!snapshot.isPro)
        #expect(snapshot.tier == .free)
        #expect(!snapshot.isDevelopmentUnlocked)
        #expect(!snapshot.isPaidValidationConfigured)
        #expect(snapshot.paidValidationProvider == .none)
        #expect(snapshot.sourceDescription == "Free")
    }

    @Test("debug entitlement unlock is explicit and never counts as paid validation")
    func debugEntitlementUnlockIsExplicitAndNeverCountsAsPaidValidation() {
        let snapshot = GardenEntitlementResolver.resolve(
            environment: [
                GardenEntitlementResolver.developmentUnlockEnvironmentKey: "1"
            ],
            infoDictionary: [:],
            isDebugBuild: true
        )

        #expect(snapshot.isPro)
        #expect(snapshot.tier == .pro)
        #expect(snapshot.isDevelopmentUnlocked)
        #expect(!snapshot.isPaidValidationConfigured)
        #expect(snapshot.paidValidationProvider == .none)
        #expect(snapshot.sourceDescription == "Development unlock")
    }

    @Test("release entitlements ignore development unlock flags")
    func releaseEntitlementsIgnoreDevelopmentUnlockFlags() {
        let snapshot = GardenEntitlementResolver.resolve(
            environment: [
                GardenEntitlementResolver.developmentUnlockEnvironmentKey: "true"
            ],
            infoDictionary: [:],
            isDebugBuild: false
        )

        #expect(!snapshot.isPro)
        #expect(snapshot.tier == .free)
        #expect(!snapshot.isDevelopmentUnlocked)
        #expect(!snapshot.isPaidValidationConfigured)
        #expect(snapshot.paidValidationProvider == .none)
    }

    @Test("validated pro tier unlocks paid features only when validation is configured")
    func validatedProTierUnlocksPaidFeaturesOnlyWhenValidationIsConfigured() {
        let configured = GardenEntitlementResolver.resolve(
            environment: [:],
            infoDictionary: [
                GardenEntitlementResolver.paidValidationProviderInfoKey: "stripe",
                GardenEntitlementResolver.validatedTierInfoKey: "pro"
            ],
            isDebugBuild: false
        )
        let unconfigured = GardenEntitlementResolver.resolve(
            environment: [:],
            infoDictionary: [
                GardenEntitlementResolver.validatedTierInfoKey: "pro"
            ],
            isDebugBuild: false
        )

        #expect(configured.isPro)
        #expect(configured.tier == .pro)
        #expect(configured.isPaidValidationConfigured)
        #expect(configured.paidValidationProvider == .stripe)
        #expect(configured.sourceDescription == "Validated Pro")
        #expect(!unconfigured.isPro)
        #expect(unconfigured.tier == .free)
    }

    @Test("paid validation provider stamps configuration even without legacy boolean")
    func paidValidationProviderStampsConfigurationEvenWithoutLegacyBoolean() {
        let snapshot = GardenEntitlementResolver.resolve(
            environment: [:],
            infoDictionary: [
                GardenEntitlementResolver.paidValidationProviderInfoKey: "store-kit"
            ],
            isDebugBuild: false
        )

        #expect(!snapshot.isPro)
        #expect(snapshot.isPaidValidationConfigured)
        #expect(snapshot.paidValidationProvider == .storeKit)
        #expect(snapshot.sourceDescription == "StoreKit validation configured")
    }

    @Test("clean install readiness can pass without dumping private state")
    func cleanInstallReadinessCanPass() throws {
        let fixture = try ReadinessFixture()
        defer { fixture.cleanup() }

        let summary = GardenReleaseReadinessReport.makeSummary(
            store: fixture.store,
            wallpaperManager: fixture.wallpaperManager,
            timeLapseRecorder: fixture.timeLapseRecorder,
            environment: .init(
                isRunningFromAppBundle: true,
                isInputMonitoringLimited: false,
                isScreenSaverInstalled: true,
                isOpenAIKeyConfigured: true,
                isProDevelopmentUnlocked: false,
                isPaidEntitlementValidationConfigured: true,
                paidValidationProvider: .stripe,
                screenCount: 1
            )
        )

        #expect(summary.status == .ready)
        #expect(summary.score == 100)
        #expect(summary.issues.isEmpty)
        #expect(summary.primaryIssueSummary == "No issues found")
        #expect(!summary.jsonObject.keys.contains("rawGardenState"))
    }

    @Test("readiness report exposes public launch blockers and warnings")
    func readinessReportExposesPublicLaunchIssues() throws {
        let fixture = try ReadinessFixture(activeSceneKey: GardenWallpaperScene.alienCraterGreenhouse.rawValue)
        defer { fixture.cleanup() }

        let summary = GardenReleaseReadinessReport.makeSummary(
            store: fixture.store,
            wallpaperManager: fixture.wallpaperManager,
            timeLapseRecorder: fixture.timeLapseRecorder,
            environment: .init(
                isRunningFromAppBundle: false,
                isInputMonitoringLimited: true,
                isScreenSaverInstalled: false,
                isOpenAIKeyConfigured: false,
                isProDevelopmentUnlocked: true,
                isPaidEntitlementValidationConfigured: false,
                screenCount: 0
            )
        )

        let issueIDs = summary.issues.map(\.id)
        #expect(summary.status == .needsAttention)
        #expect(summary.score < 80)
        #expect(issueIDs.contains("not-app-bundle"))
        #expect(issueIDs.contains("input-monitoring-limited"))
        #expect(issueIDs.contains("screensaver-not-installed"))
        #expect(issueIDs.contains("openai-key-missing"))
        #expect(issueIDs.contains("development-entitlements"))
        #expect(issueIDs.contains("paid-validation-missing"))
        #expect(issueIDs.contains("scene-unavailable"))
        #expect(issueIDs.contains("no-screens"))
        #expect(summary.issues.contains { $0.title.contains("OpenAI") })
        #expect(summary.issueBreakdownSummary == "4 blockers, 3 warnings, 1 note")
        #expect(summary.nextActionSummary.contains("Build, install, and launch"))
    }

    @Test("development unlocked paid features block public sale readiness")
    func developmentUnlockedPaidFeaturesBlockPublicSaleReadiness() throws {
        let fixture = try ReadinessFixture()
        defer { fixture.cleanup() }

        let summary = GardenReleaseReadinessReport.makeSummary(
            store: fixture.store,
            wallpaperManager: fixture.wallpaperManager,
            timeLapseRecorder: fixture.timeLapseRecorder,
            environment: .init(
                isRunningFromAppBundle: true,
                isInputMonitoringLimited: false,
                isScreenSaverInstalled: true,
                isOpenAIKeyConfigured: true,
                isProDevelopmentUnlocked: true,
                isPaidEntitlementValidationConfigured: true,
                paidValidationProvider: .stripe,
                screenCount: 1
            )
        )
        let entitlementIssue = try #require(summary.issues.first { $0.id == "development-entitlements" })

        #expect(summary.status == .needsAttention)
        #expect(entitlementIssue.severity == .blocker)
        #expect(summary.headline == "1 blocker, 0 warnings")
        #expect(entitlementIssue.action.localizedCaseInsensitiveContains("paid public release"))
    }

    @Test("missing paid entitlement validation blocks public sale readiness")
    func missingPaidEntitlementValidationBlocksPublicSaleReadiness() throws {
        let fixture = try ReadinessFixture()
        defer { fixture.cleanup() }

        let summary = GardenReleaseReadinessReport.makeSummary(
            store: fixture.store,
            wallpaperManager: fixture.wallpaperManager,
            timeLapseRecorder: fixture.timeLapseRecorder,
            environment: .init(
                isRunningFromAppBundle: true,
                isInputMonitoringLimited: false,
                isScreenSaverInstalled: true,
                isOpenAIKeyConfigured: true,
                isProDevelopmentUnlocked: false,
                isPaidEntitlementValidationConfigured: false,
                screenCount: 1
            )
        )
        let validationIssue = try #require(summary.issues.first { $0.id == "paid-validation-missing" })

        #expect(summary.status == .needsAttention)
        #expect(validationIssue.severity == .blocker)
        #expect(validationIssue.detail.localizedCaseInsensitiveContains("receipt"))
        #expect(validationIssue.action.localizedCaseInsensitiveContains("Stripe"))
    }

    @Test("direct download build cannot be launch ready with StoreKit provider")
    func directDownloadBuildCannotBeLaunchReadyWithStoreKitProvider() throws {
        let fixture = try ReadinessFixture()
        defer { fixture.cleanup() }

        let summary = GardenReleaseReadinessReport.makeSummary(
            store: fixture.store,
            wallpaperManager: fixture.wallpaperManager,
            timeLapseRecorder: fixture.timeLapseRecorder,
            environment: .init(
                isRunningFromAppBundle: true,
                isInputMonitoringLimited: false,
                isScreenSaverInstalled: true,
                isOpenAIKeyConfigured: true,
                isProDevelopmentUnlocked: false,
                isPaidEntitlementValidationConfigured: true,
                paidValidationProvider: .storeKit,
                distributionChannel: .directDownload,
                screenCount: 1
            )
        )

        let issue = try #require(summary.issues.first { $0.id == "direct-download-storekit-provider" })

        #expect(summary.status == .needsAttention)
        #expect(issue.severity == .blocker)
        #expect(issue.action.localizedCaseInsensitiveContains("Stripe"))
    }

    @Test("Mac App Store build requires sandbox and StoreKit")
    func macAppStoreBuildRequiresSandboxAndStoreKit() throws {
        let fixture = try ReadinessFixture()
        defer { fixture.cleanup() }

        let summary = GardenReleaseReadinessReport.makeSummary(
            store: fixture.store,
            wallpaperManager: fixture.wallpaperManager,
            timeLapseRecorder: fixture.timeLapseRecorder,
            environment: .init(
                isRunningFromAppBundle: true,
                isInputMonitoringLimited: false,
                isScreenSaverInstalled: true,
                isOpenAIKeyConfigured: true,
                isProDevelopmentUnlocked: false,
                isPaidEntitlementValidationConfigured: true,
                paidValidationProvider: .stripe,
                distributionChannel: .macAppStore,
                isAppSandboxed: false,
                screenCount: 1
            )
        )

        let issueIDs = summary.issues.map(\.id)

        #expect(summary.status == .needsAttention)
        #expect(issueIDs.contains("app-store-sandbox-missing"))
        #expect(issueIDs.contains("app-store-storekit-missing"))
    }

    @Test("sandboxed StoreKit Mac App Store build can pass readiness")
    func sandboxedStoreKitMacAppStoreBuildCanPassReadiness() throws {
        let fixture = try ReadinessFixture()
        defer { fixture.cleanup() }

        let summary = GardenReleaseReadinessReport.makeSummary(
            store: fixture.store,
            wallpaperManager: fixture.wallpaperManager,
            timeLapseRecorder: fixture.timeLapseRecorder,
            environment: .init(
                isRunningFromAppBundle: true,
                isInputMonitoringLimited: false,
                isScreenSaverInstalled: true,
                isOpenAIKeyConfigured: true,
                isProDevelopmentUnlocked: false,
                isPaidEntitlementValidationConfigured: true,
                paidValidationProvider: .storeKit,
                distributionChannel: .macAppStore,
                isAppSandboxed: true,
                screenCount: 1
            )
        )

        #expect(summary.status == .ready)
        #expect(summary.issues.isEmpty)
    }

    @Test("health check JSON embeds release readiness summary")
    func healthCheckEmbedsReleaseReadiness() throws {
        let fixture = try ReadinessFixture()
        defer { fixture.cleanup() }

        let data = try GardenHealthCheckReport.makeJSONData(
            store: fixture.store,
            activeSceneName: "Conservatory Hall",
            weatherStatus: "Weather sync off",
            timeLapseRecorder: fixture.timeLapseRecorder,
            at: Date(timeIntervalSince1970: 1_200),
            readinessEnvironment: .init(
                isRunningFromAppBundle: true,
                isInputMonitoringLimited: false,
                isScreenSaverInstalled: true,
                isOpenAIKeyConfigured: true,
                isProDevelopmentUnlocked: false,
                isPaidEntitlementValidationConfigured: true,
                paidValidationProvider: .stripe,
                screenCount: 1
            )
        )
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let readiness = try #require(object["releaseReadiness"] as? [String: Any])

        #expect(readiness["status"] as? String == "ready")
        #expect(readiness["score"] as? Int == 100)
        #expect(readiness["rawGardenState"] == nil)
    }
}

@MainActor
private struct ReadinessFixture {
    let directoryURL: URL
    let store: GardenStore
    let wallpaperManager: WallpaperManager
    let timeLapseRecorder: GardenTimeLapseRecorder

    init(activeSceneKey: String = GardenWallpaperScene.emptyConservatoryHall.rawValue) throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenReleaseReadiness-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let persistence = GardenPersistence(directoryURL: directoryURL)
        store = GardenStore(
            state: GardenState.defaultGarden(screenCount: 1, now: Date(timeIntervalSince1970: 1_000)),
            persistence: persistence,
            activeSceneKey: activeSceneKey
        )
        wallpaperManager = WallpaperManager(baseDirectoryURL: directoryURL)
        timeLapseRecorder = GardenTimeLapseRecorder(baseDirectoryURL: directoryURL)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
