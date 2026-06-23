import AppKit
import PlantGardenCore
import WebKit

struct GnomeDailyRoutinePayload: Codable, Equatable {
    var phase: String
    var localHour: Double
    var homeLightIntensity: Double
    var lanternIntensity: Double
    var bonfireIntensity: Double
    var fireflyIntensity: Double
    var smokeIntensity: Double
    var sleepBias: Double
    var buildBias: Double
    var socialBias: Double
    var forageBias: Double
}

@MainActor
final class GnomeTribeWindow: NSWindow {
    static var companionLevel: NSWindow.Level {
        GardenDesktopWindowLevels.gnomeTribe
    }

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: true)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        level = Self.companionLevel
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

@MainActor
final class GnomeTribeController: NSObject {
    private struct Payload: Codable {
        var screenWidthPx: Double
        var screenHeightPx: Double
        var lightLevel: Double
        var lightMood: String
        var sceneDarkening: Double
        var dailyRoutine: GnomeDailyRoutinePayload
        var perspective: PerspectivePayload
        var simulation: SimulationPayload
        var zones: [ZonePayload]
        var plants: [PlantPayload]
    }

    private struct ZonePayload: Codable {
        var id: String
        var points: [PointPayload]
        var centroid: PointPayload
        var bounds: BoundsPayload
        var cultureSeed: Int
        var settlementIndex: Int
        var settlementProgress: Double
        var isStartingZone: Bool
    }

    private struct PlantPayload: Codable {
        var id: String
        var species: String
        var kind: String
        var x: Double
        var y: Double
        var scale: Double
        var maturity: Double
        var canClimb: Bool
        var resourceValue: Double
        var canopyHeight: Double
    }

    private struct PointPayload: Codable {
        var x: Double
        var y: Double
    }

    private struct BoundsPayload: Codable {
        var minX: Double
        var minY: Double
        var maxX: Double
        var maxY: Double
    }

    private struct PerspectivePayload: Codable {
        var yawDegrees: Double
        var elevationDegrees: Double
    }

    private struct SimulationPayload: Codable {
        var populationMultiplier: Double
        var tribeScaleMultiplier: Double
        var behaviorLiveliness: Double
        var buildingSpeedMultiplier: Double
        var cooperationMultiplier: Double
        var plantInteractionMultiplier: Double
        var villageDetailMultiplier: Double
        var settlementExpansionDays: Double
    }

    private let store: GardenStore
    private var windows: [GnomeTribeWindow] = []
    private var webViews: [WKWebView] = []
    private var screens: [NSScreen] = []
    private var lastPayloadFingerprints: [Int: String] = [:]
    private var routineRefreshTimer: Timer?
    private var storeObserver: NSObjectProtocol?
    private var navigationDelegates: [MainActorWebNavigationDelegate] = []
    private var pointerRoutingTimer: Timer?

    init(store: GardenStore) {
        self.store = store
        super.init()
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

    func show() {
        _ = ensureWindowsIfNeeded()
        refresh(force: true)
    }

    func rebuildWindows() {
        teardownWindows()

        guard Self.shouldShow(for: store.state) else {
            stopRoutineRefreshTimer()
            return
        }

        guard let indexURL = Self.webAssetsIndexURL() else {
            NSLog("Plant Wallpaper could not locate gnome tribe web assets")
            return
        }

        for screen in NSScreen.screens {
            let window = GnomeTribeWindow(screen: screen)
            let webView = makeWebView(frame: NSRect(origin: .zero, size: window.frame.size))
            loadGnomes(in: webView, indexURL: indexURL)
            window.contentView = webView
            window.orderFrontRegardless()
            windows.append(window)
            webViews.append(webView)
            screens.append(screen)
        }
        startRoutineRefreshTimer()
        startPointerRoutingTimer()
    }

    func refresh(force: Bool = false) {
        guard ensureWindowsIfNeeded() else {
            return
        }

        for (index, webView) in webViews.enumerated() where index < screens.count {
            let payload = payload(forScreenIndex: index, screen: screens[index])
            let fingerprint = payloadFingerprint(payload)
            guard force || lastPayloadFingerprints[index] != fingerprint else {
                continue
            }
            lastPayloadFingerprints[index] = fingerprint
            webView.evaluateJavaScript("window.gnomeBridge && window.gnomeBridge.configure(\(jsonLiteral(payload)))")
        }
    }

    nonisolated static func webAssetsIndexURL() -> URL? {
        Bundle.appResources.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "WebAssets/gnomes"
        )
    }

    nonisolated static func shouldShow(for state: GardenState) -> Bool {
        state.settings.experienceMode == .garden
            && state.settings.gnomeSimulation.isEnabled
            && !state.areGnomeTribesHidden
            && !state.gnomeTribeZones.isEmpty
            && state.gnomeSettlementPlan.isCommitted
    }

    nonisolated static func lightLevelForTesting(
        state: GardenState,
        date: Date,
        calendar: Calendar
    ) -> Double {
        lightLevel(
            for: state,
            sunlight: state.sunlightCondition(at: date, calendar: calendar)
        )
    }

    nonisolated static func dailyRoutineForTesting(
        date: Date,
        calendar: Calendar
    ) -> GnomeDailyRoutinePayload {
        dailyRoutinePayload(date: date, calendar: calendar)
    }

    nonisolated static func resourceValueForTesting(plant: Plant) -> Double {
        resourceValue(for: plant)
    }

    nonisolated static func orderedSettlementZoneIDsForTesting(
        zones: [GnomeTribeZone],
        plan: GnomeTribeSettlementPlan
    ) -> [UUID] {
        orderedSettlementZones(zones: zones, plan: plan).map(\.id)
    }

    nonisolated static func settlementProgressForTesting(
        zone: GnomeTribeZone,
        zones: [GnomeTribeZone],
        plan: GnomeTribeSettlementPlan,
        date: Date
    ) -> Double {
        settlementProgress(for: zone, zones: zones, plan: plan, date: date)
    }

    private func makeWebView(frame: NSRect) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: frame, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        let navigationDelegate = MainActorWebNavigationDelegate { [weak self] _ in
            self?.webViewDidFinishNavigation()
        }
        webView.navigationDelegate = navigationDelegate
        navigationDelegates.append(navigationDelegate)
        return webView
    }

    private func loadGnomes(in webView: WKWebView, indexURL: URL) {
        let readAccessURL = indexURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        webView.loadFileURL(indexURL, allowingReadAccessTo: readAccessURL)
    }

    @discardableResult
    private func ensureWindowsIfNeeded() -> Bool {
        guard Self.shouldShow(for: store.state) else {
            teardownWindows()
            return false
        }

        if webViews.isEmpty || windows.isEmpty {
            rebuildWindows()
        }

        return !webViews.isEmpty
    }

    private func teardownWindows() {
        windows.forEach { $0.close() }
        windows = []
        webViews = []
        screens = []
        navigationDelegates = []
        lastPayloadFingerprints = [:]
        stopRoutineRefreshTimer()
        stopPointerRoutingTimer()
    }

    private func startPointerRoutingTimer() {
        pointerRoutingTimer?.invalidate()
        pointerRoutingTimer = Timer.scheduledTimer(
            withTimeInterval: 0.08,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updatePointerRouting()
            }
        }
        pointerRoutingTimer?.tolerance = 0.03
    }

    private func stopPointerRoutingTimer() {
        pointerRoutingTimer?.invalidate()
        pointerRoutingTimer = nil
    }

    private func updatePointerRouting() {
        let screenPoint = NSEvent.mouseLocation
        for (index, window) in windows.enumerated() {
            guard index < webViews.count, window.frame.contains(screenPoint) else {
                window.ignoresMouseEvents = true
                continue
            }
            let local = window.convertPoint(fromScreen: screenPoint)
            let cssX = max(0, min(window.frame.width, local.x))
            let cssY = max(0, min(window.frame.height, window.frame.height - local.y))
            let script = "Boolean(window.gnomeBridge && window.gnomeBridge.hitTest(\(cssX), \(cssY)))"
            webViews[index].evaluateJavaScript(script) { [weak window] result, _ in
                DispatchQueue.main.async {
                    window?.ignoresMouseEvents = !((result as? Bool) ?? false)
                }
            }
        }
    }

    private func payload(forScreenIndex screenIndex: Int, screen: NSScreen) -> Payload {
        let sunlight = store.state.sunlightCondition()
        let now = Date()
        let visibleScreenZones = store.state.gnomeTribeZones
            .filter { $0.screenIndex == screenIndex }
        return Payload(
            screenWidthPx: Double(screen.frame.width),
            screenHeightPx: Double(screen.frame.height),
            lightLevel: Self.lightLevel(for: store.state, sunlight: sunlight),
            lightMood: sunlight.mood.rawValue,
            sceneDarkening: store.state.manualPlantDarkening,
            dailyRoutine: Self.dailyRoutinePayload(date: Date(), calendar: .autoupdatingCurrent),
            perspective: perspectivePayload(store.state.gnomeTribePerspective),
            simulation: simulationPayload(store.state.settings.gnomeSimulation),
            zones: store.state.areGnomeTribesHidden ? [] : visibleScreenZones
                .compactMap { zonePayload($0, zones: visibleScreenZones, date: now) },
            plants: store.state.plants
                .filter { $0.screenIndex == screenIndex }
                .map(plantPayload)
        )
    }

    private func zonePayload(_ zone: GnomeTribeZone, zones: [GnomeTribeZone], date: Date) -> ZonePayload? {
        let bounds = zone.boundingBox
        let orderedZones = Self.orderedSettlementZones(zones: zones, plan: store.state.gnomeSettlementPlan)
        guard let settlementIndex = orderedZones.firstIndex(where: { $0.id == zone.id }) else {
            return nil
        }
        let progress = Self.settlementProgress(
            for: zone,
            zones: zones,
            plan: store.state.gnomeSettlementPlan,
            date: date
        )
        guard progress > 0 else {
            return nil
        }
        let bucketedProgress = min(1, max(0.05, (progress * 20).rounded() / 20))
        return ZonePayload(
            id: zone.id.uuidString,
            points: zone.points.map(pointPayload),
            centroid: pointPayload(zone.centroid),
            bounds: BoundsPayload(
                minX: bounds.minX,
                minY: bounds.minY,
                maxX: bounds.maxX,
                maxY: bounds.maxY
            ),
            cultureSeed: zone.cultureSeed,
            settlementIndex: settlementIndex,
            settlementProgress: bucketedProgress,
            isStartingZone: zone.id == store.state.gnomeSettlementPlan.startingZoneID
        )
    }

    private func plantPayload(_ plant: Plant) -> PlantPayload {
        PlantPayload(
            id: plant.id.uuidString,
            species: plant.nickname.isEmpty ? plant.species.displayName : plant.nickname,
            kind: plant.species.kind.rawValue,
            x: plant.position.x,
            y: plant.position.y,
            scale: plant.scale,
            maturity: plant.growth.clampedUnit,
            canClimb: plant.species.kind == .tree || plant.species.kind == .foliage || plant.scale > 1.2,
            resourceValue: Self.resourceValue(for: plant),
            canopyHeight: Self.canopyHeight(for: plant)
        )
    }

    private nonisolated static func lightLevel(
        for state: GardenState,
        sunlight: GardenSunlightCondition
    ) -> Double {
        let manualShade = state.manualPlantDarkening.clamped(to: 0...0.60)
        return (sunlight.intensity * (1 - manualShade * 0.82)).clamped(to: 0.16...1.0)
    }

    private nonisolated static func dailyRoutinePayload(
        date: Date,
        calendar: Calendar
    ) -> GnomeDailyRoutinePayload {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 12)
        let minute = Double(components.minute ?? 0)
        let localHour = hour + minute / 60

        switch localHour {
        case 5..<8:
            return GnomeDailyRoutinePayload(
                phase: "dawn",
                localHour: localHour,
                homeLightIntensity: 0.42,
                lanternIntensity: 0.22,
                bonfireIntensity: 0.26,
                fireflyIntensity: 0.32,
                smokeIntensity: 0.78,
                sleepBias: 0.34,
                buildBias: 0.42,
                socialBias: 0.24,
                forageBias: 0.72
            )
        case 8..<12:
            return GnomeDailyRoutinePayload(
                phase: "morning",
                localHour: localHour,
                homeLightIntensity: 0.08,
                lanternIntensity: 0.03,
                bonfireIntensity: 0.10,
                fireflyIntensity: 0.02,
                smokeIntensity: 0.44,
                sleepBias: 0.06,
                buildBias: 0.94,
                socialBias: 0.30,
                forageBias: 0.76
            )
        case 12..<16:
            return GnomeDailyRoutinePayload(
                phase: "midday",
                localHour: localHour,
                homeLightIntensity: 0.02,
                lanternIntensity: 0.01,
                bonfireIntensity: 0.05,
                fireflyIntensity: 0.00,
                smokeIntensity: 0.20,
                sleepBias: 0.16,
                buildBias: 0.62,
                socialBias: 0.54,
                forageBias: 0.46
            )
        case 16..<19:
            return GnomeDailyRoutinePayload(
                phase: "golden-hour",
                localHour: localHour,
                homeLightIntensity: 0.18,
                lanternIntensity: 0.18,
                bonfireIntensity: 0.22,
                fireflyIntensity: 0.22,
                smokeIntensity: 0.34,
                sleepBias: 0.10,
                buildBias: 0.44,
                socialBias: 0.66,
                forageBias: 0.70
            )
        case 19..<22:
            return GnomeDailyRoutinePayload(
                phase: "evening",
                localHour: localHour,
                homeLightIntensity: 0.88,
                lanternIntensity: 0.82,
                bonfireIntensity: 0.86,
                fireflyIntensity: 0.88,
                smokeIntensity: 0.66,
                sleepBias: 0.28,
                buildBias: 0.12,
                socialBias: 0.96,
                forageBias: 0.18
            )
        case 22..<24:
            return GnomeDailyRoutinePayload(
                phase: "night",
                localHour: localHour,
                homeLightIntensity: 0.72,
                lanternIntensity: 0.52,
                bonfireIntensity: 0.42,
                fireflyIntensity: 1.00,
                smokeIntensity: 0.26,
                sleepBias: 0.88,
                buildBias: 0.03,
                socialBias: 0.12,
                forageBias: 0.04
            )
        default:
            return GnomeDailyRoutinePayload(
                phase: "pre-dawn",
                localHour: localHour,
                homeLightIntensity: 0.56,
                lanternIntensity: 0.36,
                bonfireIntensity: 0.30,
                fireflyIntensity: 0.92,
                smokeIntensity: 0.18,
                sleepBias: 0.96,
                buildBias: 0.02,
                socialBias: 0.06,
                forageBias: 0.03
            )
        }
    }

    private nonisolated static func resourceValue(for plant: Plant) -> Double {
        let kindBase: Double
        switch plant.species.kind {
        case .tree:
            kindBase = 0.82
        case .foliage:
            kindBase = 0.72
        case .edible:
            kindBase = 0.64
        case .meadow:
            kindBase = 0.58
        case .flower:
            kindBase = 0.46
        }

        let scaleBoost = min(0.22, max(0, plant.scale - 1.0) * 0.12)
        let growthBoost = plant.growth.clampedUnit * 0.18
        let healthPenalty = (1 - plant.health.clampedUnit) * 0.24
        return (kindBase + scaleBoost + growthBoost - healthPenalty).clamped(to: 0.05...1.0)
    }

    private nonisolated static func canopyHeight(for plant: Plant) -> Double {
        let kindHeight: Double
        switch plant.species.kind {
        case .tree:
            kindHeight = 0.28
        case .foliage:
            kindHeight = 0.18
        case .edible:
            kindHeight = 0.14
        case .meadow:
            kindHeight = 0.09
        case .flower:
            kindHeight = 0.12
        }

        return (kindHeight * max(0.45, plant.scale) * (0.55 + plant.growth.clampedUnit * 0.45))
            .clamped(to: 0.05...0.35)
    }

    private func pointPayload(_ point: GardenPoint) -> PointPayload {
        PointPayload(x: point.x, y: point.y)
    }

    private func perspectivePayload(_ perspective: GnomeTribePerspective) -> PerspectivePayload {
        PerspectivePayload(
            yawDegrees: perspective.yawDegrees,
            elevationDegrees: perspective.elevationDegrees
        )
    }

    private func simulationPayload(_ settings: GardenGnomeSimulationSettings) -> SimulationPayload {
        SimulationPayload(
            populationMultiplier: settings.populationMultiplier,
            tribeScaleMultiplier: settings.tribeScaleMultiplier,
            behaviorLiveliness: settings.behaviorLiveliness,
            buildingSpeedMultiplier: settings.buildingSpeedMultiplier,
            cooperationMultiplier: settings.cooperationMultiplier,
            plantInteractionMultiplier: settings.plantInteractionMultiplier,
            villageDetailMultiplier: settings.villageDetailMultiplier,
            settlementExpansionDays: settings.settlementExpansionDays
        )
    }

    private nonisolated static func orderedSettlementZones(
        zones: [GnomeTribeZone],
        plan: GnomeTribeSettlementPlan
    ) -> [GnomeTribeZone] {
        guard !zones.isEmpty else {
            return []
        }

        let startZone = plan.startingZoneID.flatMap { startID in
            zones.first { $0.id == startID }
        } ?? zones.first
        guard let startZone else {
            return zones
        }

        let remainingZones = zones
            .filter { $0.id != startZone.id }
            .sorted { lhs, rhs in
                let lhsDistance = squaredDistance(lhs.centroid, startZone.centroid)
                let rhsDistance = squaredDistance(rhs.centroid, startZone.centroid)
                if lhsDistance == rhsDistance {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhsDistance < rhsDistance
            }

        return [startZone] + remainingZones
    }

    private nonisolated static func settlementProgress(
        for zone: GnomeTribeZone,
        zones: [GnomeTribeZone],
        plan: GnomeTribeSettlementPlan,
        date: Date
    ) -> Double {
        guard let startedAt = plan.startedAt else {
            return 0
        }

        let orderedZones = orderedSettlementZones(zones: zones, plan: plan)
        guard let index = orderedZones.firstIndex(where: { $0.id == zone.id }) else {
            return 0
        }

        let totalDuration = max(
            GnomeTribeSettlementPlan.minimumExpansionDurationDays,
            plan.expansionDurationDays
        ) * 24 * 60 * 60
        let zoneDuration = max(60 * 60, totalDuration / Double(max(1, orderedZones.count)))
        let elapsed = max(0, date.timeIntervalSince(startedAt))
        let zoneStart = Double(index) * zoneDuration
        let rawProgress = (elapsed - zoneStart) / zoneDuration
        let progress = rawProgress.clamped(to: 0...1)
        let eased = progress * progress * (3 - 2 * progress)

        if index == 0 {
            return max(0.12, eased)
        }

        return eased
    }

    private nonisolated static func squaredDistance(_ lhs: GardenPoint, _ rhs: GardenPoint) -> Double {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    private func payloadFingerprint(_ payload: Payload) -> String {
        guard let data = try? JSONEncoder().encode(payload) else {
            return UUID().uuidString
        }
        return String(data: data, encoding: .utf8) ?? UUID().uuidString
    }

    private func jsonLiteral<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func startRoutineRefreshTimer() {
        guard routineRefreshTimer == nil else {
            return
        }

        routineRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    private func stopRoutineRefreshTimer() {
        routineRefreshTimer?.invalidate()
        routineRefreshTimer = nil
    }

    private func storeDidChange() {
        refresh()
    }

    private func webViewDidFinishNavigation() {
        refresh(force: true)
    }
}
