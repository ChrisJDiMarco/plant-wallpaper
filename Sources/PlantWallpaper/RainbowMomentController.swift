import AppKit
import PlantGardenCore
import WebKit

@MainActor
final class RainbowMomentWindow: NSWindow {
    static var rainbowLevel: NSWindow.Level {
        GardenDesktopWindowLevels.rainbowMoment
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
        level = Self.rainbowLevel
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

/// Hosts the rain-after-weather rainbow as a transparent Three.js shader
/// layer. The canvas rare-moment renderer keeps the bug/butterfly moments;
/// this renderer is only for light, mist, and rainbow shimmer.
@MainActor
final class RainbowMomentController: NSObject {
    private struct Payload: Codable {
        var active: Bool
        var progress: Double
        var screenWidthPx: Double
        var screenHeightPx: Double
        var reduceMotion: Bool
    }

    private let store: GardenStore
    private var windows: [RainbowMomentWindow] = []
    private var webViews: [WKWebView] = []
    private var screens: [NSScreen] = []
    private var lastPayloadFingerprints: [Int: String] = [:]
    private var refreshTimer: Timer?
    private var storeObserver: NSObjectProtocol?

    init(store: GardenStore) {
        self.store = store
        super.init()
        storeObserver = NotificationCenter.default.addObserver(
            forName: .gardenStoreDidChange,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.storeDidChange()
            }
        }
        startRefreshTimer()
    }

    func show() {
        _ = ensureWindowsIfNeeded()
        refresh(force: true)
    }

    func rebuildWindows() {
        teardownWindows()

        guard Self.shouldShow(for: store.state) else {
            return
        }

        guard let indexURL = Self.webAssetsIndexURL() else {
            NSLog("Plant Wallpaper could not locate rainbow web assets")
            return
        }

        for screen in NSScreen.screens {
            let window = RainbowMomentWindow(screen: screen)
            let webView = makeWebView(frame: NSRect(origin: .zero, size: window.frame.size))
            loadRainbow(in: webView, indexURL: indexURL)
            window.contentView = webView
            window.orderFrontRegardless()
            windows.append(window)
            webViews.append(webView)
            screens.append(screen)
        }
    }

    func refresh(force: Bool = false) {
        guard ensureWindowsIfNeeded() else {
            return
        }

        for (index, webView) in webViews.enumerated() where index < screens.count {
            let payload = payload(for: screens[index])
            let fingerprint = payloadFingerprint(payload)
            guard force || lastPayloadFingerprints[index] != fingerprint else {
                continue
            }
            lastPayloadFingerprints[index] = fingerprint
            webView.evaluateJavaScript("window.rainbowBridge && window.rainbowBridge.configure(\(jsonLiteral(payload)))")
        }
    }

    nonisolated static func webAssetsIndexURL() -> URL? {
        Bundle.appResources.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "WebAssets/rainbow"
        )
    }

    nonisolated static func shouldShow(for state: GardenState, at date: Date = Date()) -> Bool {
        guard state.settings.rareMomentsMode != .off,
              let moment = GardenRareMoment.activeMoment(at: date, weather: state.weather) else {
            return false
        }
        return moment.kind == .rainbow
    }

    private func makeWebView(frame: NSRect) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: frame, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        webView.navigationDelegate = self
        return webView
    }

    private func loadRainbow(in webView: WKWebView, indexURL: URL) {
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
        lastPayloadFingerprints = [:]
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        refreshTimer?.tolerance = 0.4
    }

    private func payload(for screen: NSScreen) -> Payload {
        let moment = store.state.settings.rareMomentsMode == .off
            ? nil
            : GardenRareMoment.activeMoment(at: Date(), weather: store.state.weather)
        let rainbow = moment?.kind == .rainbow ? moment : nil
        return Payload(
            active: rainbow != nil,
            progress: rainbow?.progress ?? 0,
            screenWidthPx: Double(screen.frame.width),
            screenHeightPx: Double(screen.frame.height),
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
    }

    private func payloadFingerprint(_ payload: Payload) -> String {
        let progressBucket = payload.active ? Int((payload.progress * 1_000).rounded()) : 0
        return [
            payload.active ? "1" : "0",
            String(progressBucket),
            String(Int(payload.screenWidthPx.rounded())),
            String(Int(payload.screenHeightPx.rounded())),
            payload.reduceMotion ? "1" : "0"
        ].joined(separator: ":")
    }

    private func jsonLiteral<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private func storeDidChange() {
        refresh()
    }
}

extension RainbowMomentController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refresh(force: true)
    }
}
