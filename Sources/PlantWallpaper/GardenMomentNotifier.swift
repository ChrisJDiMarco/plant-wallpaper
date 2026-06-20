import AppKit
import PlantGardenCore
import UserNotifications

/// Watches the garden for moments worth celebrating - a plant reaching a new
/// growth stage, a completed focus session - and surfaces them as gentle
/// user notifications. Silently disabled when running outside an app bundle
/// (bare debug binary, interaction self-test).
@MainActor
final class GardenMomentNotifier {
    typealias NotificationAuthorizationCompletion = @Sendable (Bool) -> Void
    typealias NotificationAuthorizer = (@escaping NotificationAuthorizationCompletion) -> Void
    typealias NotificationDeliverer = @Sendable (String, String) -> Void

    /// Global minimum spacing between growth notifications.
    private static let minimumNotificationSpacing: TimeInterval = 20 * 60
    private static let lastRainCelebrationDayDefaultsKey = "PlantWallpaper.lastRainCelebrationDay"

    private let store: GardenStore
    private let defaults: UserDefaults
    private let isAvailable: Bool
    private let notificationAuthorizer: NotificationAuthorizer
    private let notificationDeliverer: NotificationDeliverer
    private var didRequestAuthorization = false
    private var previousStageIndices: [UUID: Int] = [:]
    private var previousCompletedFocusSessions = 0
    private var previousFocusTotalMinutes = 0
    private var lastGrowthNotificationAt: Date?
    private var wasPrecipitating = false
    private var lastRainCelebrationDay: String?
    private var lastCelebratedMomentKind: GardenRareMomentKind?
    private var storeObserver: NSObjectProtocol?

    init(
        store: GardenStore,
        defaults: UserDefaults = .standard,
        isAvailable: Bool = Bundle.main.bundleIdentifier != nil,
        notificationAuthorizer: @escaping NotificationAuthorizer = GardenMomentNotifier.requestAuthorization,
        notificationDeliverer: @escaping NotificationDeliverer = GardenMomentNotifier.deliver
    ) {
        self.store = store
        self.defaults = defaults
        self.isAvailable = isAvailable
        self.notificationAuthorizer = notificationAuthorizer
        self.notificationDeliverer = notificationDeliverer
        self.lastRainCelebrationDay = defaults.string(forKey: Self.lastRainCelebrationDayDefaultsKey)
        captureBaseline()
        storeObserver = NotificationCenter.default.addObserver(
            forName: .gardenStoreDidChange,
            object: store,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }
            MainActor.assumeIsolated {
                self.storeDidChange()
            }
        }
    }

    private func captureBaseline() {
        previousStageIndices = Dictionary(
            uniqueKeysWithValues: store.state.plants.map { plant in
                (plant.id, PlantAssetStage(growth: plant.growth).index)
            }
        )
        previousCompletedFocusSessions = store.state.focusStats?.completedSessions ?? 0
        previousFocusTotalMinutes = store.state.focusStats?.totalFocusMinutes ?? 0
    }

    private func storeDidChange() {
        guard isAvailable else {
            return
        }

        if store.state.settings.notifyFocus {
            detectFocusCompletion()
        }
        if store.state.settings.notifyCare {
            detectGrowthMilestones()
        }
        if store.state.settings.notifyWeather {
            detectFirstRain()
        }
        detectRareMoment()
    }

    /// Celebrates reaching a new progression level. Level-ups coincide with a
    /// scene switch, so the menu calls this explicitly rather than relying on
    /// the store-diff detectors above. Always journals; notifies when available.
    func celebrateProgressionLevel(level: Int, title: String, isFinalLevel: Bool) {
        let body = isFinalLevel
            ? "Level \(level) — \(title). The ladder is maxed out; this scene is as lavish as it gets."
            : "Level \(level) — \(title). Your scene leveled up."
        store.journal?.append(
            .milestone,
            isFinalLevel
                ? "Progression maxed out at Level \(level): \(title)"
                : "Progression reached Level \(level): \(title)"
        )
        guard isAvailable else {
            return
        }
        post(title: isFinalLevel ? "Progression complete!" : "Level \(level) reached", body: body)
    }

    /// Called by the app's clock tick: rare moments are time-based and can
    /// begin without any garden state change to piggyback on.
    func tick() {
        guard isAvailable else {
            return
        }

        detectRareMoment()
    }

    /// The first time real-world rain reaches the garden each day, say so -
    /// rain literally watering your plants is the app's best-kept secret.
    private func detectFirstRain() {
        let isPrecipitating = store.state.weather.map { $0.isPrecipitating && !$0.isStale() } ?? false
        defer {
            wasPrecipitating = isPrecipitating
        }
        guard isPrecipitating, !wasPrecipitating else {
            return
        }

        let dayStamp = GardenTimeLapseRecorder.dayStamp(for: Date())
        guard dayStamp != lastRainCelebrationDay else {
            return
        }

        lastRainCelebrationDay = dayStamp
        defaults.set(dayStamp, forKey: Self.lastRainCelebrationDayDefaultsKey)
        post(
            title: "It's raining outside",
            body: "Your garden is drinking - real rain waters every plant while it lasts."
        )
        store.journal?.append(.weather, "Rain reached the garden - every plant got watered by the sky")
    }

    private func detectRareMoment() {
        guard store.state.settings.rareMomentsMode != .off else {
            lastCelebratedMomentKind = nil
            return
        }

        let moment = GardenRareMoment.activeMoment(at: Date(), weather: store.state.weather)
        defer {
            lastCelebratedMomentKind = moment?.kind
        }
        guard let moment, moment.kind != lastCelebratedMomentKind else {
            return
        }

        if store.state.settings.rareMomentsMode == .full, store.state.settings.notifyRareMoments {
            post(title: moment.kind.title, body: moment.kind.celebrationText)
        }
        store.journal?.append(.moment, moment.kind.celebrationText)
    }

    private func detectFocusCompletion() {
        let completedSessions = store.state.focusStats?.completedSessions ?? 0
        let focusTotalMinutes = store.state.focusStats?.totalFocusMinutes ?? 0
        defer {
            previousCompletedFocusSessions = completedSessions
            previousFocusTotalMinutes = focusTotalMinutes
        }
        guard completedSessions > previousCompletedFocusSessions else {
            return
        }

        let stagesGrown = store.state.focusStats?.lastSessionStagesGrown ?? 0
        let milestone = GardenFocusMilestone.reached(
            previousMinutes: previousFocusTotalMinutes,
            currentMinutes: focusTotalMinutes
        )
        let payoff = stagesGrown > 0
            ? "This session grew your garden \(stagesGrown) visible stage\(stagesGrown == 1 ? "" : "s")."
            : "Every plant got a bloom boost."
        let milestoneText = milestone.map { " Focus milestone reached: \($0) minutes." } ?? ""
        post(
            title: "Focus session complete",
            body: "\(payoff) \(focusTotalMinutes) focused minutes total.\(milestoneText)"
        )
        store.journal?.append(
            .focus,
            stagesGrown > 0
                ? "Completed a focus session - the garden grew \(stagesGrown) stage\(stagesGrown == 1 ? "" : "s")\(milestone.map { ", \($0)m focus milestone reached" } ?? "")"
                : "Completed a focus session - every plant got a bloom boost\(milestone.map { ", \($0)m focus milestone reached" } ?? "")"
        )
    }

    private func detectGrowthMilestones() {
        var currentStages: [UUID: Int] = [:]
        var advancedPlant: Plant?

        for plant in store.state.plants {
            let stageIndex = PlantAssetStage(growth: plant.growth).index
            currentStages[plant.id] = stageIndex
            if let previousIndex = previousStageIndices[plant.id],
               stageIndex > previousIndex,
               !plant.isDead,
               advancedPlant == nil {
                advancedPlant = plant
            }
        }
        previousStageIndices = currentStages

        guard let advancedPlant else {
            return
        }

        // Growth is slow; one gentle notification at a time is plenty.
        if let lastGrowthNotificationAt,
           Date().timeIntervalSince(lastGrowthNotificationAt) < Self.minimumNotificationSpacing {
            return
        }

        lastGrowthNotificationAt = Date()
        let stage = PlantLifeStage(
            species: advancedPlant.species,
            assetStage: PlantAssetStage(growth: advancedPlant.growth)
        )
        post(
            title: "\(advancedPlant.nickname) reached a new phase",
            body: "Your \(advancedPlant.species.displayName.lowercased()) is now \(stage.label.lowercased())."
        )
        store.journal?.append(
            .milestone,
            "\(advancedPlant.species.displayName) reached a new phase - now \(stage.label.lowercased())"
        )
    }

    private func post(title: String, body: String) {
        if didRequestAuthorization {
            notificationDeliverer(title, body)
            return
        }

        didRequestAuthorization = true
        notificationAuthorizer { [notificationDeliverer] granted in
            guard granted else {
                return
            }

            notificationDeliverer(title, body)
        }
    }

    private nonisolated static func requestAuthorization(completion: @escaping NotificationAuthorizationCompletion) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge]) { granted, _ in
            completion(granted)
        }
    }

    /// UNUserNotificationCenter is thread-safe; delivering from a nonisolated
    /// helper with value-type inputs keeps the authorization callback free of
    /// main-actor captures.
    private nonisolated static func deliver(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
