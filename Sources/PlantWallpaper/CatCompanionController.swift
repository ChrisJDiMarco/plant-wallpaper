import AppKit
import PlantGardenCore
import WebKit

extension Notification.Name {
    static let gardenCatCompanionToggled = Notification.Name("gardenCatCompanionToggled")
    static let gardenCatCompanionClaimedClick = Notification.Name("gardenCatCompanionClaimedClick")
}

struct CatCompanionClickSnapshot: Equatable {
    static let freshInterval: TimeInterval = 0.65
    private static let shoulderWorld = 0.62
    private static let wallClickHalfWidthWorld = 1.55
    private static let wallClickHalfHeightWorld = 1.18

    let screenFrame: NSRect
    let stateName: String
    let worldX: Double
    let worldY: Double
    let catSizePx: Double
    let groundFraction: Double
    let updatedAt: Date

    var isWallMounted: Bool {
        stateName == "wallClimb" || stateName == "wallHang"
    }

    func consumesWallClick(at screenPoint: NSPoint, now: Date = Date()) -> Bool {
        guard isWallMounted,
              catSizePx.isFinite,
              catSizePx > 0,
              screenFrame.contains(screenPoint),
              now.timeIntervalSince(updatedAt) <= Self.freshInterval else {
            return false
        }

        let worldPoint = worldPoint(from: screenPoint)
        let bodyCenterY = worldY + 0.45
        return abs(worldPoint.x - worldX) < Self.wallClickHalfWidthWorld
            && abs(worldPoint.y - bodyCenterY) < Self.wallClickHalfHeightWorld
    }

    private func worldPoint(from screenPoint: NSPoint) -> (x: Double, y: Double) {
        let worldPerPx = Self.shoulderWorld / catSizePx
        let localX = Double(screenPoint.x - screenFrame.minX)
        let localYFromTop = Double(screenFrame.maxY - screenPoint.y)
        let screenWidthPx = Double(screenFrame.width)
        let screenHeightPx = Double(screenFrame.height)
        return (
            x: (localX - screenWidthPx / 2) * worldPerPx,
            y: ((screenHeightPx - localYFromTop) - groundFraction * screenHeightPx) * worldPerPx
        )
    }
}

private enum CatCompanionScriptEvent: Sendable {
    case bugCaught(bugID: String, screenIndex: Int?)
    case catMemoryJSON(String)
}

private final class CatCompanionScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var controller: CatCompanionController?

    init(controller: CatCompanionController) {
        self.controller = controller
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "catEvent",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String,
              let event = Self.event(from: body, type: type) else {
            return
        }

        Task { @MainActor [weak controller] in
            controller?.handleCatScriptEvent(event)
        }
    }

    private static func event(from body: [String: Any], type: String) -> CatCompanionScriptEvent? {
        switch type {
        case "bugCaught":
            guard let bugID = body["bugID"] as? String else {
                return nil
            }
            return .bugCaught(bugID: bugID, screenIndex: body["screenIndex"] as? Int)
        case "catMemory":
            guard let memory = body["memory"] as? [String: Any],
                  JSONSerialization.isValidJSONObject(memory),
                  let data = try? JSONSerialization.data(withJSONObject: memory),
                  let json = String(data: data, encoding: .utf8) else {
                return nil
            }
            return .catMemoryJSON(json)
        default:
            return nil
        }
    }
}

/// Desktop-level click-through window hosting the cat. Sits above the garden
/// canvas and transparent interaction regions so the cat walks in front of
/// plants even while the user edits the garden.
///
/// Full-screen so the cat can be carried anywhere by the cursor (mouse
/// cling). GPU cost stays low regardless: the WebGL canvas inside is a small
/// cat-sized box that follows the cat around the screen.
@MainActor
final class CatCompanionWindow: NSWindow {
    static var companionLevel: NSWindow.Level {
        GardenDesktopWindowLevels.catCompanion
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

/// Hosts one Three.js cat per screen in a transparent WKWebView. The cat
/// lives entirely in the bundled web assets (WebAssets/cat); this controller
/// only manages windows, lifecycle, and power state.
private final class CatCompanionEventRelay: @unchecked Sendable {
    weak var controller: CatCompanionController?

    init(controller: CatCompanionController) {
        self.controller = controller
    }

    func dispatch(_ body: @escaping @MainActor (CatCompanionController) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let controller = self?.controller else {
                return
            }
            MainActor.assumeIsolated {
                body(controller)
            }
        }
    }
}

@MainActor
final class CatCompanionController: NSObject {
    static let enabledDefaultsKey = "catCompanionEnabled"
    private static let appDefaultsSuiteName = "com.chrisdimarco.wallpapergarden"
    private static let catMemoryDefaultsKey = "catRuntimeMemory"

    /// Coat variants assigned per screen so multi-display setups get
    /// distinct cats. Must match CatModel.PALETTES keys in cat-model.js.
    private static let coatVariants = [
        "orange", "gray", "charcoal", "cream",
        "black", "white", "siamese", "tuxedo", "calico"
    ]

    /// Fraction of screen height the cat's ground line sits above the
    /// bottom edge before Dock geometry is applied.
    private static let groundFraction = 0.0

    private var windows: [CatCompanionWindow] = []
    private var webViews: [WKWebView] = []
    /// Screen for each window, index-aligned with windows/webViews.
    private var screens: [NSScreen] = []
    private var navigationDelegates: [MainActorWebNavigationDelegate] = []
    private let launchSeed = Int.random(in: 0 ..< 1_000_000_000)
    private var settings = CatCompanionSettings.load()
    private var loadedBuildFingerprint = ""
    private var mouseTimer: Timer?
    private var desktopEnvironmentTimer: Timer?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var clickSnapshotTimer: Timer?
    private lazy var eventRelay = CatCompanionEventRelay(controller: self)
    private var workspaceObservers: [NSObjectProtocol] = []
    private var notificationObservers: [NSObjectProtocol] = []
    private let chatWindowController: CatCompanionChatWindowController
    private let isChatOnClickEnabled: () -> Bool
    private let catChatBlockingGardenElementContains: (NSPoint) -> Bool
    private let desktopSceneCanReceiveClick: (NSPoint) -> Bool
    private let gnomeTerritoryProvider: () -> [GnomeTribeZone]
    private let plantMissionTargetProvider: () -> [Plant]
    private var lastSentMouse: NSPoint?
    private var lastMouseWebViewIndex: Int?
    private var lastEnvironmentFingerprints: [Int: String] = [:]
    private var lastGnomeTerritoryFingerprints: [Int: String] = [:]
    private var lastPlantMissionTargetFingerprints: [Int: String] = [:]
    private var clickSnapshots: [Int: CatCompanionClickSnapshot] = [:]

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) as? Bool ?? true
    }

    init(
        isChatOnClickEnabled: @escaping () -> Bool = { true },
        foregroundGardenElementContains: @escaping (NSPoint) -> Bool = { _ in false },
        catChatBlockingGardenElementContains: @escaping (NSPoint) -> Bool = { _ in false },
        desktopSceneCanReceiveClick: @escaping (NSPoint) -> Bool = { _ in true },
        gnomeTerritoryProvider: @escaping () -> [GnomeTribeZone] = { [] },
        plantMissionTargetProvider: @escaping () -> [Plant] = { [] },
        chatContextProvider: @escaping () -> GardenAssistantRuntimeContext? = { nil },
        chatCommandExecutor: @escaping (CatCompanionAppAction) -> CatCompanionCommandExecution = { _ in
            .unavailable("I can talk about that command, but I am not wired to the running garden in this context.")
        }
    ) {
        self.isChatOnClickEnabled = isChatOnClickEnabled
        self.catChatBlockingGardenElementContains = catChatBlockingGardenElementContains
        self.desktopSceneCanReceiveClick = desktopSceneCanReceiveClick
        self.gnomeTerritoryProvider = gnomeTerritoryProvider
        self.plantMissionTargetProvider = plantMissionTargetProvider
        self.chatWindowController = CatCompanionChatWindowController(
            contextProvider: chatContextProvider,
            commandExecutor: chatCommandExecutor
        )
        _ = foregroundGardenElementContains
        super.init()
        mirrorEnabledStateToSharedDefaults()
        observeWorkspaceNotification(name: NSWorkspace.screensDidSleepNotification) { controller, _ in
            controller.screensDidSleep()
        }
        observeWorkspaceNotification(name: NSWorkspace.screensDidWakeNotification) { controller, _ in
            controller.screensDidWake()
        }
        observeNotification(name: .gardenCatCompanionToggled) { controller, _ in
            controller.companionToggled()
        }
        observeNotification(name: .gardenCatCompanionSettingsChanged) { controller, _ in
            controller.settingsChanged()
        }
        observeNotification(name: NSWindow.didChangeOcclusionStateNotification) { controller, notification in
            controller.windowOcclusionChanged(notification)
        }
        observeNotification(name: NSApplication.didChangeScreenParametersNotification) { controller, _ in
            controller.screenParametersChanged()
        }
        observeNotification(name: .gardenBugPreySnapshotDidChange) { controller, notification in
            controller.bugPreySnapshotChanged(notification)
        }
        observeNotification(name: .gardenStoreDidChange) { controller, notification in
            controller.gardenStoreChanged(notification)
        }
        startMouseTimer()
        startDesktopEnvironmentTimer()
        startClickSnapshotTimer()
        startClickMonitors()
    }

    private func observeNotification(
        name: Notification.Name,
        object: Any? = nil,
        handler: @escaping @MainActor (CatCompanionController, Notification) -> Void
    ) {
        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: object,
            queue: .main
        ) { [weak self] notification in
            guard let self else {
                return
            }
            let delivery = MainActorNotificationDelivery(notification: notification)
            MainActor.assumeIsolated {
                handler(self, delivery.notification)
            }
        }
        notificationObservers.append(observer)
    }

    private func observeWorkspaceNotification(
        name: Notification.Name,
        handler: @escaping @MainActor (CatCompanionController, Notification) -> Void
    ) {
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else {
                return
            }
            let delivery = MainActorNotificationDelivery(notification: notification)
            MainActor.assumeIsolated {
                handler(self, delivery.notification)
            }
        }
        workspaceObservers.append(observer)
    }

    /// The cat windows are click-through, so clicks land on whatever sits
    /// beneath them. Watching mouse-downs (globally for other apps, locally
    /// for our own garden windows) lets a click still reach the cat — used
    /// to tap a climbing cat down off the screen edge.
    private func startClickMonitors() {
        let relay = eventRelay
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { _ in
            relay.dispatch { controller in
                let point = NSEvent.mouseLocation
                if controller.chatWindowController.dismissForOutsideClickIfNeeded(at: point)
                    || controller.chatWindowController.containsScreenPoint(point) {
                    return
                }
                controller.forwardClick(at: point)
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self else {
                return event
            }
            let point = NSEvent.mouseLocation
            if self.chatWindowController.dismissForOutsideClickIfNeeded(at: point)
                || self.chatWindowController.containsScreenPoint(point) {
                return event
            }
            if self.shouldConsumeGardenClickForWallCat(at: point) == true {
                self.forwardClick(at: point, suppressChat: true)
                return nil
            }
            self.forwardClick(at: point)
            return event
        }
    }

    private func forwardClick(at point: NSPoint, suppressChat: Bool = false) {
        let isChatBlockedByGardenElement = !suppressChat && catChatBlockingGardenElementContains(point)
        guard !isChatBlockedByGardenElement else {
            return
        }

        guard Self.shouldForwardClick(
                at: point,
                isEnabled: isEnabled,
                isDesktopSceneVisible: desktopSceneCanReceiveClick(point),
                isForegroundGardenElement: false
              ),
              let index = screens.firstIndex(where: { $0.frame.contains(point) }),
              index < webViews.count else {
            return
        }
        let frame = windows[index].frame
        let localX = point.x - frame.minX
        let localYFromTop = frame.maxY - point.y
        webViews[index].evaluateJavaScript(
            "window.catBridge && window.catBridge.click(\(localX), \(localYFromTop))"
        ) { [weak self] result, _ in
            guard let self else { return }
            let clickClaim = Self.catClickClaim(from: result)
            if clickClaim.isHit {
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: .gardenCatCompanionClaimedClick,
                        object: self,
                        userInfo: [
                            "screenPoint": NSValue(point: point),
                            "action": clickClaim.action
                        ]
                    )
                }
            }
            let shouldOpenChat = Self.shouldOpenChat(
                clickResult: result,
                isChatOnClickEnabled: !suppressChat && self.isChatOnClickEnabled(),
                isForegroundGardenElement: false,
                isChatBlockingGardenElement: isChatBlockedByGardenElement
            )
            guard shouldOpenChat else {
                return
            }
            Task { @MainActor in
                let targetScreen = index < self.screens.count ? self.screens[index] : nil
                self.chatWindowController.show(near: point, on: targetScreen)
            }
        }
    }

    func claimWallClickIfNeeded(at point: NSPoint) -> Bool {
        guard shouldConsumeGardenClickForWallCat(at: point) else {
            return false
        }

        forwardClick(at: point, suppressChat: true)
        return true
    }

    static func shouldOpenChatForTesting(
        clickResult: Any?,
        isChatOnClickEnabled: Bool,
        isForegroundGardenElement: Bool,
        isChatBlockingGardenElement: Bool = false
    ) -> Bool {
        shouldOpenChat(
            clickResult: clickResult,
            isChatOnClickEnabled: isChatOnClickEnabled,
            isForegroundGardenElement: isForegroundGardenElement,
            isChatBlockingGardenElement: isChatBlockingGardenElement
        )
    }

    static func shouldForwardClickForTesting(
        at point: NSPoint,
        isEnabled: Bool,
        isDesktopSceneVisible: Bool,
        isForegroundGardenElement: Bool
    ) -> Bool {
        shouldForwardClick(
            at: point,
            isEnabled: isEnabled,
            isDesktopSceneVisible: isDesktopSceneVisible,
            isForegroundGardenElement: isForegroundGardenElement
        )
    }

    static func shouldTrackMouseForTesting(
        at point: NSPoint,
        isEnabled: Bool,
        mouseReactions: Bool,
        isDesktopSceneVisible: Bool,
        hasWindows: Bool
    ) -> Bool {
        shouldTrackMouse(
            at: point,
            isEnabled: isEnabled,
            mouseReactions: mouseReactions,
            isDesktopSceneVisible: isDesktopSceneVisible,
            hasWindows: hasWindows
        )
    }

    private static func shouldForwardClick(
        at point: NSPoint,
        isEnabled: Bool,
        isDesktopSceneVisible: Bool,
        isForegroundGardenElement: Bool
    ) -> Bool {
        isEnabled
            && isDesktopSceneVisible
            && point.x.isFinite
            && point.y.isFinite
    }

    private static func shouldTrackMouse(
        at point: NSPoint,
        isEnabled: Bool,
        mouseReactions: Bool,
        isDesktopSceneVisible: Bool,
        hasWindows: Bool
    ) -> Bool {
        isEnabled
            && mouseReactions
            && isDesktopSceneVisible
            && hasWindows
            && point.x.isFinite
            && point.y.isFinite
    }

    private static func shouldOpenChat(
        clickResult: Any?,
        isChatOnClickEnabled: Bool,
        isForegroundGardenElement _: Bool,
        isChatBlockingGardenElement: Bool
    ) -> Bool {
        guard isChatOnClickEnabled, !isChatBlockingGardenElement else {
            return false
        }

        let claim = catClickClaim(from: clickResult)
        return claim.isHit && claim.opensChat
    }

    private static func catClickClaim(from clickResult: Any?) -> (isHit: Bool, opensChat: Bool, action: String) {
        if let result = clickResult as? [String: Any] {
            return (
                result["hit"] as? Bool ?? false,
                result["opensChat"] as? Bool ?? false,
                result["action"] as? String ?? "none"
            )
        }

        let isHit = clickResult as? Bool ?? false
        return (isHit, isHit, isHit ? "chat" : "none")
    }

    func show() {
        rebuildWindows()
    }

    func rebuildWindows() {
        NSLog("CatCompanion rebuildWindows: enabled=%d existing=%d", isEnabled ? 1 : 0, windows.count)
        windows.forEach { $0.close() }
        windows = []
        webViews = []
        screens = []
        navigationDelegates = []
        lastSentMouse = nil
        lastMouseWebViewIndex = nil
        lastEnvironmentFingerprints = [:]
        lastGnomeTerritoryFingerprints = [:]
        lastPlantMissionTargetFingerprints = [:]
        clickSnapshots = [:]

        guard isEnabled, let indexURL = Self.webAssetsIndexURL() else {
            if isEnabled {
                NSLog("Plant Wallpaper could not locate cat companion web assets")
            }
            return
        }

        for (screenIndex, screen) in NSScreen.screens.enumerated() {
            let window = CatCompanionWindow(screen: screen)
            let webView = makeWebView(frame: NSRect(origin: .zero, size: window.frame.size))
            loadCat(in: webView, indexURL: indexURL, screenIndex: screenIndex, screen: screen)
            window.contentView = webView
            window.orderFrontRegardless()
            windows.append(window)
            webViews.append(webView)
            screens.append(screen)
        }
        loadedBuildFingerprint = settings.buildFingerprint
        NSLog("CatCompanion rebuildWindows: created %d window(s)", windows.count)
    }

    func setPaused(_ paused: Bool) {
        let script = "window.catBridge && window.catBridge.setPaused(\(paused ? "true" : "false"))"
        for webView in webViews {
            webView.evaluateJavaScript(script)
        }
    }

    nonisolated static func webAssetsIndexURL() -> URL? {
        Bundle.appResources.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "WebAssets/cat"
        )
    }

    private func makeWebView(frame: NSRect) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(CatCompanionScriptMessageHandler(controller: self), name: "catEvent")
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: frame, configuration: configuration)
        // Private but long-stable WebKit API; the only way to get a fully
        // transparent web view over the desktop.
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        let navigationDelegate = MainActorWebNavigationDelegate { [weak self] event in
            self?.webViewDidFinishNavigation(event.webView)
        }
        webView.navigationDelegate = navigationDelegate
        navigationDelegates.append(navigationDelegate)
        return webView
    }

    private func loadCat(in webView: WKWebView, indexURL: URL, screenIndex: Int, screen: NSScreen) {
        // Build-time appearance goes in the URL; runtime values follow via
        // configure() once the page loads. Size and screen dims ride along
        // so the very first paint already uses the right camera framing.
        let variant = settings.variant == "random"
            ? Self.coatVariants[(screenIndex + launchSeed) % Self.coatVariants.count]
            : settings.variant
        var components = URLComponents(url: indexURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "variant", value: variant),
            URLQueryItem(name: "seed", value: String(launchSeed &+ screenIndex)),
            URLQueryItem(name: "chubbiness", value: String(settings.chubbiness)),
            URLQueryItem(name: "stripeAmount", value: String(settings.stripeAmount)),
            URLQueryItem(name: "catSizePx", value: String(settings.sizePoints)),
            URLQueryItem(name: "screenIndex", value: String(screenIndex)),
            URLQueryItem(name: "groundFraction", value: String(desktopEnvironment(for: screen).effectiveGroundFraction)),
            URLQueryItem(name: "screenWidthPx", value: String(Double(screen.frame.width))),
            URLQueryItem(name: "screenHeightPx", value: String(Double(screen.frame.height))),
            URLQueryItem(name: "purringEnabled", value: settings.purringEnabled ? "true" : "false")
        ]
        let url = components?.url ?? indexURL
        webView.loadFileURL(url, allowingReadAccessTo: indexURL.deletingLastPathComponent())
    }

    private func configureScript(for screen: NSScreen, screenIndex: Int) -> String {
        let environment = desktopEnvironment(for: screen)
        return """
        window.catBridge && window.catBridge.configure({
          groundFraction: \(environment.effectiveGroundFraction),
          screenIndex: \(screenIndex),
          catSizePx: \(settings.sizePoints),
          screenWidthPx: \(Double(screen.frame.width)),
          screenHeightPx: \(Double(screen.frame.height)),
          furLength: \(settings.furLength),
          activity: \(settings.activity),
          curiosity: \(settings.curiosity),
          playfulness: \(settings.playfulness),
          mouseReactions: \(settings.mouseReactions ? "true" : "false"),
          purringEnabled: \(settings.purringEnabled ? "true" : "false"),
          desktopEnvironment: \(environment.javaScriptLiteral()),
          gnomeTerritories: \(jsonLiteral(gnomeTerritories(for: screenIndex))),
          plantMissionTargets: \(jsonLiteral(plantMissionTargets(for: screenIndex)))
        })
        """
    }

    private func pushConfiguration() {
        for (index, webView) in webViews.enumerated() where index < screens.count {
            webView.evaluateJavaScript(configureScript(for: screens[index], screenIndex: index))
            lastEnvironmentFingerprints[index] = desktopEnvironment(for: screens[index]).fingerprint
            lastGnomeTerritoryFingerprints[index] = gnomeTerritoryFingerprint(for: index)
            lastPlantMissionTargetFingerprints[index] = plantMissionTargetFingerprint(for: index)
        }
    }

    private struct CatGnomeTerritoryPayload: Encodable {
        var id: String
        var points: [CatGnomeTerritoryPointPayload]
    }

    private struct CatGnomeTerritoryPointPayload: Encodable {
        var x: Double
        var y: Double
    }

    private struct CatPlantMissionTargetPayload: Encodable {
        var id: String
        var species: String
        var kind: String
        var x: Double
        var y: Double
        var scale: Double
        var resourceValue: Double
        var canopyHeight: Double
        var canClimb: Bool
    }

    private func gnomeTerritories(for screenIndex: Int) -> [CatGnomeTerritoryPayload] {
        gnomeTerritoryProvider()
            .filter { $0.screenIndex == screenIndex && $0.isPlayable }
            .map { zone in
                CatGnomeTerritoryPayload(
                    id: zone.id.uuidString,
                    points: zone.points.map {
                        CatGnomeTerritoryPointPayload(x: $0.x, y: $0.y)
                    }
                )
            }
    }

    private func gnomeTerritoryFingerprint(for screenIndex: Int) -> String {
        jsonLiteral(gnomeTerritories(for: screenIndex))
    }

    private func plantMissionTargets(for screenIndex: Int) -> [CatPlantMissionTargetPayload] {
        plantMissionTargetProvider()
            .filter { $0.screenIndex == screenIndex }
            .map { plant in
                CatPlantMissionTargetPayload(
                    id: plant.id.uuidString,
                    species: plant.nickname.isEmpty ? plant.species.displayName : plant.nickname,
                    kind: plant.species.kind.rawValue,
                    x: plant.position.x,
                    y: plant.position.y,
                    scale: plant.scale,
                    resourceValue: Self.catMissionResourceValue(for: plant),
                    canopyHeight: Self.catMissionCanopyHeight(for: plant),
                    canClimb: plant.species.kind == .tree || plant.species.kind == .foliage || plant.scale > 1.2
                )
            }
    }

    private func plantMissionTargetFingerprint(for screenIndex: Int) -> String {
        jsonLiteral(plantMissionTargets(for: screenIndex))
    }

    private nonisolated static func catMissionResourceValue(for plant: Plant) -> Double {
        let base: Double
        switch plant.species.kind {
        case .tree:
            base = 0.72
        case .foliage:
            base = 0.58
        case .edible:
            base = 0.64
        case .flower:
            base = 0.46
        case .meadow:
            base = 0.38
        }
        let scaleBoost = min(0.18, max(0, plant.scale - 1.0) * 0.10)
        let growthBoost = plant.growth.clampedUnit * 0.16
        let healthPenalty = (1 - plant.health.clampedUnit) * 0.20
        return min(1, max(0.05, base + scaleBoost + growthBoost - healthPenalty))
    }

    private nonisolated static func catMissionCanopyHeight(for plant: Plant) -> Double {
        let base: Double
        switch plant.species.kind {
        case .tree:
            base = 0.40
        case .foliage:
            base = 0.25
        case .edible:
            base = 0.20
        case .flower:
            base = 0.14
        case .meadow:
            base = 0.08
        }
        return min(0.5, max(0.04, base * max(0.45, plant.scale) * (0.55 + plant.growth.clampedUnit * 0.45)))
    }

    private func jsonLiteral<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8) else {
            return "null"
        }
        return json
    }

    private func desktopEnvironment(for screen: NSScreen) -> CatDesktopEnvironment {
        CatDesktopEnvironment(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            baseGroundFraction: Self.groundFraction
        )
    }

    private func startDesktopEnvironmentTimer() {
        desktopEnvironmentTimer?.invalidate()
        desktopEnvironmentTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pushDesktopEnvironmentIfNeeded()
            }
        }
        desktopEnvironmentTimer?.tolerance = 1.5
    }

    private func pushDesktopEnvironmentIfNeeded(force: Bool = false) {
        guard isEnabled, !webViews.isEmpty else {
            return
        }

        for (index, webView) in webViews.enumerated() where index < screens.count {
            let environment = desktopEnvironment(for: screens[index])
            guard force || lastEnvironmentFingerprints[index] != environment.fingerprint else {
                continue
            }
            lastEnvironmentFingerprints[index] = environment.fingerprint
            webView.evaluateJavaScript(
                """
                window.catBridge && window.catBridge.configure({
                  groundFraction: \(environment.effectiveGroundFraction),
                  screenIndex: \(index),
                  screenWidthPx: \(environment.screenWidthPx),
                  screenHeightPx: \(environment.screenHeightPx),
                  desktopEnvironment: \(environment.javaScriptLiteral())
                })
                """
            )
        }
    }

    private func pushGnomeTerritoriesIfNeeded(force: Bool = false) {
        guard isEnabled, !webViews.isEmpty else {
            lastGnomeTerritoryFingerprints = [:]
            return
        }

        for (index, webView) in webViews.enumerated() where index < screens.count {
            let payload = gnomeTerritories(for: index)
            let fingerprint = jsonLiteral(payload)
            guard force || lastGnomeTerritoryFingerprints[index] != fingerprint else {
                continue
            }
            lastGnomeTerritoryFingerprints[index] = fingerprint
            webView.evaluateJavaScript(
                "window.catBridge && window.catBridge.gnomeTerritories(\(fingerprint))"
            )
        }
    }

    private func pushPlantMissionTargetsIfNeeded(force: Bool = false) {
        guard isEnabled, !webViews.isEmpty else {
            lastPlantMissionTargetFingerprints = [:]
            return
        }

        for (index, webView) in webViews.enumerated() where index < screens.count {
            let payload = plantMissionTargets(for: index)
            let fingerprint = jsonLiteral(payload)
            guard force || lastPlantMissionTargetFingerprints[index] != fingerprint else {
                continue
            }
            lastPlantMissionTargetFingerprints[index] = fingerprint
            webView.evaluateJavaScript(
                "window.catBridge && window.catBridge.plantMissionTargets(\(fingerprint))"
            )
        }
    }

    // MARK: - Mouse tracking

    /// Streams the global cursor position into each cat's web view so the
    /// behavior layer can watch, stalk, and swat it. Read-only observation;
    /// the cat windows stay click-through.
    private func startMouseTimer() {
        mouseTimer?.invalidate()
        mouseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.mouseTimerFired()
            }
        }
        mouseTimer?.tolerance = 0.03
    }

    private func startClickSnapshotTimer() {
        clickSnapshotTimer?.invalidate()
        clickSnapshotTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshClickSnapshots()
            }
        }
        clickSnapshotTimer?.tolerance = 0.08
    }

    private func mouseTimerFired() {
        let mouse = NSEvent.mouseLocation
        guard Self.shouldTrackMouse(
            at: mouse,
            isEnabled: isEnabled,
            mouseReactions: settings.mouseReactions,
            isDesktopSceneVisible: desktopSceneCanReceiveClick(mouse),
            hasWindows: !windows.isEmpty
        ) else {
            clearMouseTracking()
            return
        }

        if let lastSentMouse, abs(lastSentMouse.x - mouse.x) < 2, abs(lastSentMouse.y - mouse.y) < 2 {
            return
        }
        lastSentMouse = mouse

        // Containment is tested against the full screen, not the band
        // window: the cat should watch a cursor anywhere on its display.
        let containingIndex = screens.firstIndex { $0.frame.contains(mouse) }

        // Only the screen that just lost the cursor needs the goodbye —
        // repeating mouseGone to every other screen 10x/sec is wasted IPC,
        // and the JS side already treats a stale mouse as gone.
        if let previous = lastMouseWebViewIndex,
           previous != containingIndex,
           previous < webViews.count {
            webViews[previous].evaluateJavaScript(
                "window.catBridge && window.catBridge.mouseGone()"
            )
        }
        lastMouseWebViewIndex = containingIndex

        if let index = containingIndex, index < windows.count {
            // Window-local coordinates; y goes negative above the band and
            // the JS mapping stays continuous.
            let frame = windows[index].frame
            let localX = mouse.x - frame.minX
            let localYFromTop = frame.maxY - mouse.y
            webViews[index].evaluateJavaScript(
                "window.catBridge && window.catBridge.mouse(\(localX), \(localYFromTop))"
            )
            refreshClickSnapshot(for: index)
        }
    }

    private func clearMouseTracking() {
        if let previous = lastMouseWebViewIndex,
           previous < webViews.count {
            webViews[previous].evaluateJavaScript(
                "window.catBridge && window.catBridge.mouseGone()"
            )
        }
        lastMouseWebViewIndex = nil
        lastSentMouse = nil
    }

    private func refreshClickSnapshots() {
        guard isEnabled, !webViews.isEmpty else {
            clickSnapshots = [:]
            return
        }

        for index in webViews.indices {
            refreshClickSnapshot(for: index)
        }
    }

    private func refreshClickSnapshot(for index: Int) {
        guard index < webViews.count, index < windows.count, index < screens.count else {
            return
        }

        let screenFrame = screens[index].frame
        let groundFraction = desktopEnvironment(for: screens[index]).effectiveGroundFraction
        let catSizePx = Double(settings.sizePoints)
        webViews[index].evaluateJavaScript("window.catBridge && window.catBridge.status()") { [weak self] result, _ in
            guard let self,
                  let snapshot = Self.clickSnapshot(
                    from: result,
                    screenFrame: screenFrame,
                    catSizePx: catSizePx,
                    groundFraction: groundFraction
                  ) else {
                return
            }
            Task { @MainActor in
                self.clickSnapshots[index] = snapshot
            }
        }
    }

    private func shouldConsumeGardenClickForWallCat(at point: NSPoint) -> Bool {
        guard isEnabled,
              desktopSceneCanReceiveClick(point),
              let index = screens.firstIndex(where: { $0.frame.contains(point) }),
              let snapshot = clickSnapshots[index] else {
            return false
        }
        return snapshot.consumesWallClick(at: point)
    }

    static func shouldConsumeGardenClickForTesting(
        snapshot: CatCompanionClickSnapshot?,
        at point: NSPoint,
        now: Date
    ) -> Bool {
        snapshot?.consumesWallClick(at: point, now: now) ?? false
    }

    private static func clickSnapshot(
        from result: Any?,
        screenFrame: NSRect,
        catSizePx: Double,
        groundFraction: Double
    ) -> CatCompanionClickSnapshot? {
        let payload: [String: Any]?
        if let string = result as? String,
           let data = string.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            payload = decoded
        } else {
            payload = result as? [String: Any]
        }

        guard let payload,
              let stateName = payload["state"] as? String,
              let worldX = Self.doubleValue(payload["worldX"]),
              let worldY = Self.doubleValue(payload["worldY"]) else {
            return nil
        }

        return CatCompanionClickSnapshot(
            screenFrame: screenFrame,
            stateName: stateName,
            worldX: worldX,
            worldY: worldY,
            catSizePx: catSizePx,
            groundFraction: groundFraction,
            updatedAt: Date()
        )
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as String:
            return Double(value)
        default:
            return nil
        }
    }

    private func screensDidSleep() {
        setPaused(true)
    }

    private func screensDidWake() {
        applyVisibilityPauseState()
        pushDesktopEnvironmentIfNeeded(force: true)
    }

    /// A cat nobody can see shouldn't burn GPU: pause each web view whose
    /// window is fully covered (fullscreen app, presentation) and resume
    /// the ones with any visible pixels.
    private func windowOcclusionChanged(_ notification: Notification) {
        guard notification.object is CatCompanionWindow else {
            return
        }
        applyVisibilityPauseState()
    }

    private func applyVisibilityPauseState() {
        for (window, webView) in zip(windows, webViews) {
            let isVisible = window.occlusionState.contains(.visible)
            webView.evaluateJavaScript(
                "window.catBridge && window.catBridge.setPaused(\(isVisible ? "false" : "true"))"
            )
        }
    }

    private func companionToggled() {
        mirrorEnabledStateToSharedDefaults()
        rebuildWindows()
    }

    private func screenParametersChanged() {
        rebuildWindows()
    }

    private func gardenStoreChanged(_ notification: Notification) {
        pushGnomeTerritoriesIfNeeded()
        pushPlantMissionTargetsIfNeeded()
        _ = notification
    }

    private func settingsChanged() {
        let previousFingerprint = loadedBuildFingerprint
        settings = CatCompanionSettings.load()
        if settings.buildFingerprint != previousFingerprint {
            // Coat/body changes need fresh geometry: reload the web views.
            rebuildWindows()
        } else {
            pushConfiguration()
        }
    }

    private func bugPreySnapshotChanged(_ notification: Notification) {
        guard isEnabled,
              let screenIndex = notification.userInfo?["screenIndex"] as? Int,
              screenIndex < webViews.count,
              screenIndex < windows.count,
              let snapshots = notification.userInfo?["bugs"] as? [GardenBugSystem.PreySnapshot] else {
            return
        }

        let windowFrame = windows[screenIndex].frame
        let payload = snapshots.map { snapshot -> [String: Any] in
            [
                "id": snapshot.id,
                "species": snapshot.species,
                "x": Double(snapshot.screenX - windowFrame.minX),
                "y": Double(windowFrame.maxY - snapshot.screenY),
                "plantFocused": snapshot.isPlantFocused
            ]
        }
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }
        webViews[screenIndex].evaluateJavaScript(
            "window.catBridge && window.catBridge.bugs(\(json))"
        )
    }

    private func mirrorEnabledStateToSharedDefaults() {
        let sharedDefaults = UserDefaults(suiteName: Self.appDefaultsSuiteName)
        sharedDefaults?.set(isEnabled, forKey: Self.enabledDefaultsKey)
        sharedDefaults?.synchronize()
    }
}

extension CatCompanionController {
    /// The cat's saved inner state (drives/mood), as a JSON string ready to inject
    /// into `restoreCatMemory(...)`. nil if nothing has been saved yet.
    private func savedCatMemoryJSON() -> String? {
        let defaults = UserDefaults(suiteName: Self.appDefaultsSuiteName) ?? .standard
        guard let value = defaults.string(forKey: Self.catMemoryDefaultsKey), !value.isEmpty else {
            return nil
        }
        return value
    }

    /// Persists the cat's inner state so it resumes its emotional life next launch.
    private func storeCatMemoryJSON(_ json: String) {
        let defaults = UserDefaults(suiteName: Self.appDefaultsSuiteName) ?? .standard
        defaults.set(json, forKey: Self.catMemoryDefaultsKey)
    }

    fileprivate func handleCatScriptEvent(_ event: CatCompanionScriptEvent) {
        switch event {
        case let .bugCaught(bugID, screenIndex):
            var userInfo: [String: Any] = ["bugID": bugID]
            if let screenIndex {
                userInfo["screenIndex"] = screenIndex
            }
            NotificationCenter.default.post(
                name: .gardenCatCaughtBug,
                object: self,
                userInfo: userInfo
            )
        case let .catMemoryJSON(json):
            storeCatMemoryJSON(json)
        }
    }
    private func webViewDidFinishNavigation(_ webView: WKWebView) {
        guard let index = webViews.firstIndex(of: webView), index < screens.count else {
            return
        }
        lastEnvironmentFingerprints[index] = desktopEnvironment(for: screens[index]).fingerprint
        lastGnomeTerritoryFingerprints[index] = gnomeTerritoryFingerprint(for: index)
        webView.evaluateJavaScript(configureScript(for: screens[index], screenIndex: index))
        // Replay the cat's saved drives/mood so it picks up where it left off.
        if let memoryJSON = savedCatMemoryJSON() {
            webView.evaluateJavaScript("window.catBridge && window.catBridge.restoreCatMemory(\(memoryJSON))")
        }
    }
}
