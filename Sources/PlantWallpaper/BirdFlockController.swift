import AppKit
import PlantGardenCore
import WebKit

@MainActor
final class BirdFlockWindow: NSWindow {
    static var companionLevel: NSWindow.Level {
        GardenDesktopWindowLevels.birdFlock
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
final class BirdFlockController: NSObject {
    private struct Payload: Codable {
        var screenWidthPx: Double
        var screenHeightPx: Double
        var lightLevel: Double
        var lightMood: String
        var windStrength: Double
        var birdCountMultiplier: Double
        var zones: [ZonePayload]
        var plants: [PlantPayload]
    }

    private struct ZonePayload: Codable {
        var id: String
        var points: [PointPayload]
        var centroid: PointPayload
        var bounds: BoundsPayload
        var skySeed: Int
    }

    private struct PlantPayload: Codable {
        var id: String
        var kind: String
        var x: Double
        var y: Double
        var scale: Double
        var maturity: Double
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

    private let store: GardenStore
    private var windows: [BirdFlockWindow] = []
    private var webViews: [WKWebView] = []
    private var screens: [NSScreen] = []
    private var lastPayloadFingerprints: [Int: String] = [:]
    private var lightRefreshTimer: Timer?
    private var storeObserver: NSObjectProtocol?
    private var navigationDelegates: [MainActorWebNavigationDelegate] = []

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

    deinit {
        MainActor.assumeIsolated {
            shutdown()
        }
    }

    func shutdown() {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
            self.storeObserver = nil
        }
        teardownWindows()
    }

    func show() {
        _ = ensureWindowsIfNeeded()
        refresh(force: true)
    }

    func rebuildWindows() {
        teardownWindows()

        guard Self.shouldShow(for: store.state) else {
            stopLightRefreshTimer()
            return
        }

        guard let indexURL = Self.webAssetsIndexURL() else {
            NSLog("Plant Wallpaper could not locate bird flock web assets")
            return
        }

        for screen in NSScreen.screens {
            let window = BirdFlockWindow(screen: screen)
            let webView = makeWebView(frame: NSRect(origin: .zero, size: window.frame.size))
            loadBirds(in: webView, indexURL: indexURL)
            window.contentView = webView
            window.orderFrontRegardless()
            windows.append(window)
            webViews.append(webView)
            screens.append(screen)
        }
        startLightRefreshTimer()
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
            webView.evaluateJavaScript("window.birdBridge && window.birdBridge.configure(\(jsonLiteral(payload)))")
        }
    }

    nonisolated static func webAssetsIndexURL() -> URL? {
        Bundle.appResources.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "WebAssets/birds"
        )
    }

    nonisolated static func shouldShow(for state: GardenState) -> Bool {
        state.settings.experienceMode == .garden
            && !state.areBirdFlocksHidden
            && !state.birdSkyZones.isEmpty
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

    private func loadBirds(in webView: WKWebView, indexURL: URL) {
        let readAccessURL = indexURL
            .deletingLastPathComponent()
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
        webViews.forEach {
            $0.stopLoading()
            $0.navigationDelegate = nil
        }
        windows.forEach { $0.close() }
        windows = []
        webViews = []
        screens = []
        navigationDelegates = []
        lastPayloadFingerprints = [:]
        stopLightRefreshTimer()
    }

    private func payload(forScreenIndex screenIndex: Int, screen: NSScreen) -> Payload {
        let sunlight = store.state.sunlightCondition()
        let visibleZones = store.state.birdSkyZones
            .filter { $0.screenIndex == screenIndex }
        return Payload(
            screenWidthPx: Double(screen.frame.width),
            screenHeightPx: Double(screen.frame.height),
            lightLevel: Self.lightLevel(for: store.state, sunlight: sunlight),
            lightMood: sunlight.mood.rawValue,
            windStrength: store.state.windStrength,
            birdCountMultiplier: store.state.settings.birdCountMultiplier,
            zones: store.state.areBirdFlocksHidden ? [] : visibleZones.map(zonePayload),
            plants: store.state.plants
                .filter { $0.screenIndex == screenIndex }
                .map(plantPayload)
        )
    }

    private func zonePayload(_ zone: BirdSkyZone) -> ZonePayload {
        let bounds = zone.boundingBox
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
            skySeed: zone.skySeed
        )
    }

    private func plantPayload(_ plant: Plant) -> PlantPayload {
        PlantPayload(
            id: plant.id.uuidString,
            kind: plant.species.kind.rawValue,
            x: plant.position.x,
            y: plant.position.y,
            scale: plant.scale,
            maturity: plant.growth.clampedUnit,
            canopyHeight: Self.canopyHeight(for: plant)
        )
    }

    private func pointPayload(_ point: GardenPoint) -> PointPayload {
        PointPayload(x: point.x, y: point.y)
    }

    private nonisolated static func lightLevel(
        for state: GardenState,
        sunlight: GardenSunlightCondition
    ) -> Double {
        let manualShade = state.manualPlantDarkening.clamped(to: 0...0.60)
        return (sunlight.intensity * (1 - manualShade * 0.72)).clamped(to: 0.20...1.0)
    }

    private nonisolated static func canopyHeight(for plant: Plant) -> Double {
        let kindHeight: Double
        switch plant.species.kind {
        case .tree:
            kindHeight = 0.30
        case .foliage:
            kindHeight = 0.18
        case .edible:
            kindHeight = 0.13
        case .meadow:
            kindHeight = 0.08
        case .flower:
            kindHeight = 0.11
        }

        return (kindHeight * max(0.45, plant.scale) * (0.55 + plant.growth.clampedUnit * 0.45))
            .clamped(to: 0.04...0.36)
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

    private func startLightRefreshTimer() {
        guard lightRefreshTimer == nil else {
            return
        }

        lightRefreshTimer = Timer.scheduledTimer(withTimeInterval: 90, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    private func stopLightRefreshTimer() {
        lightRefreshTimer?.invalidate()
        lightRefreshTimer = nil
    }

    private func storeDidChange() {
        refresh()
    }

    private func webViewDidFinishNavigation() {
        refresh(force: true)
    }
}
