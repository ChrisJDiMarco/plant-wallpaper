import AppKit
import ScreenSaver
import WebKit

@objc(PlantWallpaperScreenSaverView)
final class PlantWallpaperScreenSaverView: ScreenSaverView, WKNavigationDelegate {
    private let renderer: ScreenSaverGardenRenderer
    private let persistence = GardenPersistence()
    private let appDefaults = UserDefaults(suiteName: ScreenSaverGardenConstants.appDefaultsSuiteName) ?? .standard
    private let saverDefaults: UserDefaults = ScreenSaverDefaults(
        forModuleWithName: ScreenSaverGardenConstants.moduleName
    ) ?? .standard
    private var gardenState = GardenState.defaultGarden()
    private var selectedSceneKey = ScreenSaverGardenScene.defaultKey
    private var currentSnapshot: GardenScreenSaverSnapshot?
    private var lastReloadAt = Date.distantPast
    private var startedAt = Date()
    private var configurationWindow: NSWindow?
    private weak var scenePopup: NSPopUpButton?
    private var catWebView: WKWebView?
    private var catWebViewLoaded = false

    override var isFlipped: Bool { true }

    override init?(frame: NSRect, isPreview: Bool) {
        renderer = ScreenSaverGardenRenderer(bundle: Bundle(for: PlantWallpaperScreenSaverView.self))
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = isPreview ? 1.0 / 18.0 : 1.0 / 30.0
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        reloadGarden(force: true)
        updateCatWebView()
    }

    required init?(coder: NSCoder) {
        renderer = ScreenSaverGardenRenderer(bundle: Bundle(for: PlantWallpaperScreenSaverView.self))
        super.init(coder: coder)
        animationTimeInterval = 1.0 / 30.0
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        reloadGarden(force: true)
        updateCatWebView()
    }

    override func startAnimation() {
        super.startAnimation()
        startedAt = Date()
        reloadGarden(force: true)
        updateCatWebView()
        setCatPaused(false)
    }

    override func stopAnimation() {
        setCatPaused(true)
        super.stopAnimation()
    }

    override func animateOneFrame() {
        reloadGardenIfNeeded()
        gardenState = GardenEngine.advance(gardenState, to: Date())
        updateCatWebView()
        setNeedsDisplay(bounds)
    }

    override func draw(_ rect: NSRect) {
        super.draw(rect)
        renderer.draw(
            state: gardenState,
            sceneKey: selectedSceneKey,
            screenIndex: resolvedScreenIndex(),
            in: bounds,
            date: Date(),
            desktopWallpaperImageURL: effectiveDesktopWallpaperImageURL(),
            gardenSnapshotImageURL: effectiveGardenSnapshotImageURL(),
            animationElapsed: Date().timeIntervalSince(startedAt),
            isPreview: isPreview
        )
    }

    override var hasConfigureSheet: Bool {
        true
    }

    override var configureSheet: NSWindow? {
        buildConfigurationWindow()
    }

    @objc private func saveConfiguration(_ sender: Any?) {
        let selectedKey = scenePopup?.selectedItem?.representedObject as? String
            ?? ScreenSaverGardenConstants.followDesktopSelection
        saverDefaults.set(selectedKey, forKey: ScreenSaverGardenConstants.screenSaverSceneSelectionKey)
        saverDefaults.synchronize()

        if let configurationWindow {
            configurationWindow.sheetParent?.endSheet(configurationWindow)
            configurationWindow.orderOut(sender)
        }

        reloadGarden(force: true)
    }

    @objc private func cancelConfiguration(_ sender: Any?) {
        if let configurationWindow {
            configurationWindow.sheetParent?.endSheet(configurationWindow)
            configurationWindow.orderOut(sender)
        }
    }

    private func reloadGardenIfNeeded() {
        let nextSceneKey = effectiveSceneKey()
        guard nextSceneKey != selectedSceneKey || Date().timeIntervalSince(lastReloadAt) > 6 else {
            return
        }

        reloadGarden(force: true)
    }

    private func reloadGarden(force: Bool) {
        let nextSceneKey = effectiveSceneKey()
        guard force || nextSceneKey != selectedSceneKey else {
            return
        }

        if let snapshot = effectiveScreenSaverSnapshot() {
            currentSnapshot = snapshot
            selectedSceneKey = snapshot.sceneKey.map(canonicalSceneKey) ?? nextSceneKey
            let screenCount = max(1, NSScreen.screens.count)
            gardenState = GardenEngine.constrainPlantsToScreenCount(snapshot.state, screenCount: screenCount)
            lastReloadAt = Date()
            return
        }

        currentSnapshot = nil
        selectedSceneKey = nextSceneKey
        let screenCount = max(1, NSScreen.screens.count)
        let loadedState = (try? persistence.load(sceneKey: nextSceneKey))
            ?? (try? persistence.load())
            ?? GardenState.defaultGarden(screenCount: screenCount)
        gardenState = GardenEngine.constrainPlantsToScreenCount(loadedState, screenCount: screenCount)
        lastReloadAt = Date()
    }

    private func effectiveSceneKey() -> String {
        let desktopSceneKeyCandidate = appDefaults.string(forKey: ScreenSaverGardenConstants.desktopSceneDefaultsKey)
            ?? UserDefaults.standard.string(forKey: ScreenSaverGardenConstants.desktopSceneDefaultsKey)

        if let desktopSceneKey = resolvedSceneKeyIfValid(desktopSceneKeyCandidate) {
            return desktopSceneKey
        }

        if effectiveDesktopWallpaperImageURL() != nil,
           let desktopSceneKeyCandidate,
           !desktopSceneKeyCandidate.isEmpty {
            return canonicalSceneKey(desktopSceneKeyCandidate)
        }

        let configuredSelection = saverDefaults.string(
            forKey: ScreenSaverGardenConstants.screenSaverSceneSelectionKey
        ) ?? ScreenSaverGardenConstants.followDesktopSelection

        if configuredSelection != ScreenSaverGardenConstants.followDesktopSelection {
            return resolvedSceneKey(configuredSelection)
        }

        return ScreenSaverGardenScene.defaultKey
    }

    private func resolvedSceneKey(_ sceneKey: String?) -> String {
        resolvedSceneKeyIfValid(sceneKey) ?? ScreenSaverGardenScene.defaultKey
    }

    private func resolvedSceneKeyIfValid(_ sceneKey: String?) -> String? {
        guard let sceneKey, !sceneKey.isEmpty else {
            return nil
        }

        let canonicalSceneKey = canonicalSceneKey(sceneKey)

        if ScreenSaverGardenScene.builtInScenes.contains(where: { $0.key == canonicalSceneKey }) {
            return canonicalSceneKey
        }

        if renderer.customWallpaperRecords().contains(where: { $0.key == canonicalSceneKey }) {
            return canonicalSceneKey
        }

        return nil
    }

    private func canonicalSceneKey(_ sceneKey: String) -> String {
        switch sceneKey {
        case "moonlit-glasshouse":
            return "moonlit-empty-glasshouse"
        default:
            return sceneKey
        }
    }

    private func effectiveDesktopWallpaperImageURL() -> URL? {
        wallpaperImageURL(
            from: appDefaults.object(forKey: ScreenSaverGardenConstants.desktopWallpaperImageDefaultsKey)
        ) ?? wallpaperImageURL(
            from: UserDefaults.standard.object(forKey: ScreenSaverGardenConstants.desktopWallpaperImageDefaultsKey)
        )
    }

    private func wallpaperImageURL(from object: Any?) -> URL? {
        let url: URL?
        if let objectURL = object as? URL {
            url = objectURL
        } else if let path = object as? String, !path.isEmpty {
            url = URL(fileURLWithPath: path)
        } else {
            url = nil
        }

        guard let url, FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return url
    }

    private func effectiveScreenSaverSnapshot() -> GardenScreenSaverSnapshot? {
        if let snapshot = try? GardenScreenSaverSnapshot.load(from: persistence.directoryURL) {
            return snapshot
        }

        return nil
    }

    private func effectiveGardenSnapshotImageURL() -> URL? {
        guard let path = currentSnapshot?.compositedImagePath, !path.isEmpty else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return url
    }

    private func effectiveCatEnabled() -> Bool {
        if let snapshotValue = currentSnapshot?.isCatCompanionEnabled {
            return snapshotValue
        }

        if let sharedValue = appDefaults.object(forKey: ScreenSaverGardenConstants.catEnabledDefaultsKey) as? Bool {
            return sharedValue
        }

        if let standardValue = UserDefaults.standard.object(forKey: ScreenSaverGardenConstants.catEnabledDefaultsKey) as? Bool {
            return standardValue
        }

        return true
    }

    private func updateCatWebView() {
        guard effectiveCatEnabled(), let indexURL = catIndexURL() else {
            catWebView?.removeFromSuperview()
            catWebView = nil
            catWebViewLoaded = false
            return
        }

        let webView: WKWebView
        if let existingWebView = catWebView {
            webView = existingWebView
        } else {
            webView = makeCatWebView()
            catWebView = webView
            addSubview(webView)
            loadCatWebView(webView, indexURL: indexURL)
        }

        webView.frame = bounds
        configureCatWebViewIfReady()
    }

    private func catIndexURL() -> URL? {
        Bundle(for: PlantWallpaperScreenSaverView.self).url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "WebAssets/cat"
        )
    }

    private func makeCatWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: bounds, configuration: configuration)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        return webView
    }

    private func loadCatWebView(_ webView: WKWebView, indexURL: URL) {
        let settings = ScreenSaverCatSettings(defaults: appDefaults)
        let variant = ScreenSaverCatSettings.webVariant(settings.variant)
        var components = URLComponents(url: indexURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "variant", value: variant),
            URLQueryItem(name: "seed", value: "20260612"),
            URLQueryItem(name: "chubbiness", value: String(settings.chubbiness)),
            URLQueryItem(name: "stripeAmount", value: String(settings.stripeAmount)),
            URLQueryItem(name: "furLength", value: String(settings.furLength)),
            URLQueryItem(name: "catSizePx", value: String(settings.sizePoints)),
            URLQueryItem(name: "groundFraction", value: String(catGroundFraction())),
            URLQueryItem(name: "screenWidthPx", value: String(Double(max(1, bounds.width)))),
            URLQueryItem(name: "screenHeightPx", value: String(Double(max(1, bounds.height)))),
            URLQueryItem(name: "mouseReactions", value: "false")
        ]
        webView.loadFileURL(components?.url ?? indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
    }

    private func configureCatWebViewIfReady() {
        guard catWebViewLoaded, let catWebView else {
            return
        }

        let settings = ScreenSaverCatSettings(defaults: appDefaults)
        let groundFraction = catGroundFraction()
        let script = """
        window.catBridge && window.catBridge.configure({
          groundFraction: \(groundFraction),
          catSizePx: \(settings.sizePoints),
          screenWidthPx: \(Double(max(1, bounds.width))),
          screenHeightPx: \(Double(max(1, bounds.height))),
          furLength: \(settings.furLength),
          activity: 0.42,
          curiosity: 0.70,
          playfulness: 0.36,
          mouseReactions: false,
          desktopEnvironment: {
            dockVisible: false,
            dockSide: "none",
            dockThicknessPx: 0,
            wallInsetsPx: { left: 0, right: 0, bottom: 0 },
            effectiveGroundFraction: \(groundFraction)
          }
        })
        """
        catWebView.evaluateJavaScript(script)
    }

    private func setCatPaused(_ isPaused: Bool) {
        catWebView?.evaluateJavaScript(
            "window.catBridge && window.catBridge.setPaused(\(isPaused ? "true" : "false"))"
        )
    }

    private func catGroundFraction() -> Double {
        isPreview ? 0.08 : 0.035
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView == catWebView else {
            return
        }

        catWebViewLoaded = true
        configureCatWebViewIfReady()
        setCatPaused(!isAnimating)
    }

    private func resolvedScreenIndex() -> Int {
        guard let windowScreen = window?.screen else {
            return 0
        }

        let windowScreenNumber = windowScreen.screenNumber
        return NSScreen.screens.firstIndex { $0.screenNumber == windowScreenNumber } ?? 0
    }

    private func buildConfigurationWindow() -> NSWindow {
        if let configurationWindow {
            populateScenePopup()
            return configurationWindow
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 190),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Plant Wallpaper"

        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = contentView

        let titleLabel = NSTextField(labelWithString: "Screen Saver Garden")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.frame = NSRect(x: 24, y: 142, width: 380, height: 24)
        contentView.addSubview(titleLabel)

        let modeLabel = NSTextField(labelWithString: "Scene")
        modeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        modeLabel.frame = NSRect(x: 24, y: 100, width: 80, height: 20)
        contentView.addSubview(modeLabel)

        let popup = NSPopUpButton(frame: NSRect(x: 96, y: 94, width: 304, height: 30), pullsDown: false)
        scenePopup = popup
        contentView.addSubview(popup)
        populateScenePopup()

        let hintLabel = NSTextField(
            wrappingLabelWithString: "Follow Desktop Garden mirrors the wallpaper scene last selected from the Plant Wallpaper menu."
        )
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.frame = NSRect(x: 24, y: 58, width: 376, height: 34)
        contentView.addSubview(hintLabel)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelConfiguration(_:)))
        cancelButton.frame = NSRect(x: 220, y: 18, width: 86, height: 30)
        contentView.addSubview(cancelButton)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveConfiguration(_:)))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: 314, y: 18, width: 86, height: 30)
        contentView.addSubview(saveButton)

        configurationWindow = window
        return window
    }

    private func populateScenePopup() {
        guard let scenePopup else {
            return
        }

        let selectedKey = saverDefaults.string(forKey: ScreenSaverGardenConstants.screenSaverSceneSelectionKey)
            ?? ScreenSaverGardenConstants.followDesktopSelection

        scenePopup.removeAllItems()
        scenePopup.addItem(withTitle: "Follow Desktop Garden")
        scenePopup.lastItem?.representedObject = ScreenSaverGardenConstants.followDesktopSelection

        for scene in ScreenSaverGardenScene.builtInScenes {
            scenePopup.addItem(withTitle: scene.displayName)
            scenePopup.lastItem?.representedObject = scene.key
        }

        let customRecords = renderer.customWallpaperRecords()
        if !customRecords.isEmpty {
            scenePopup.menu?.addItem(.separator())
            for record in customRecords {
                scenePopup.addItem(withTitle: record.displayName)
                scenePopup.lastItem?.representedObject = record.key
            }
        }

        let index = scenePopup.itemArray.firstIndex {
            ($0.representedObject as? String) == selectedKey
        } ?? 0
        scenePopup.selectItem(at: index)
    }
}

private enum ScreenSaverGardenConstants {
    static let moduleName = "PlantWallpaperScreenSaver"
    static let appDefaultsSuiteName = "com.chrisdimarco.wallpapergarden"
    static let desktopSceneDefaultsKey = "PlantWallpaper.selectedWallpaperScene"
    static let desktopWallpaperImageDefaultsKey = "PlantWallpaper.currentWallpaperImageURL"
    static let catEnabledDefaultsKey = "catCompanionEnabled"
    static let screenSaverSceneSelectionKey = "PlantWallpaperScreenSaver.sceneSelection"
    static let followDesktopSelection = "follow-desktop"
}

private struct ScreenSaverCatSettings {
    var variant: String
    var sizePoints: Double
    var chubbiness: Double
    var furLength: Double
    var stripeAmount: Double

    init(defaults: UserDefaults) {
        variant = defaults.string(forKey: "catVariant") ?? "orange"
        sizePoints = Self.readDouble(defaults, "catSizePoints", fallback: 175, range: 120 ... 260)
        chubbiness = Self.readDouble(defaults, "catChubbiness", fallback: 1.0, range: 0.8 ... 1.3)
        furLength = Self.readDouble(defaults, "catFurLength", fallback: 1.0, range: 0.6 ... 1.5)
        stripeAmount = Self.readDouble(defaults, "catStripeAmount", fallback: 1.0, range: 0 ... 1.5)
    }

    static func webVariant(_ variant: String) -> String {
        switch variant {
        case "orange", "gray", "charcoal", "cream":
            return variant
        default:
            return ""
        }
    }

    private static func readDouble(
        _ defaults: UserDefaults,
        _ key: String,
        fallback: Double,
        range: ClosedRange<Double>
    ) -> Double {
        guard defaults.object(forKey: key) != nil else {
            return fallback
        }

        return min(range.upperBound, max(range.lowerBound, defaults.double(forKey: key)))
    }
}

private struct ScreenSaverGardenScene: Equatable {
    static let defaultKey = "empty-conservatory-hall"
    static let builtInScenes: [ScreenSaverGardenScene] = [
        ScreenSaverGardenScene(key: "empty-conservatory-hall", displayName: "Empty Conservatory Hall"),
        ScreenSaverGardenScene(key: "enclosed-gravel-courtyard", displayName: "Enclosed Gravel Courtyard"),
        ScreenSaverGardenScene(key: "rooftop-seed-house", displayName: "Rooftop Seed House"),
        ScreenSaverGardenScene(key: "empty-desertarium", displayName: "Empty Desertarium"),
        ScreenSaverGardenScene(key: "moonlit-empty-glasshouse", displayName: "Moonlit Empty Glasshouse"),
        ScreenSaverGardenScene(key: "empty-water-pavilion", displayName: "Empty Water Pavilion"),
        ScreenSaverGardenScene(key: "victorian-seed-gallery", displayName: "Victorian Seed Gallery"),
        ScreenSaverGardenScene(key: "coastal-planting-terrace", displayName: "Coastal Planting Terrace"),
        ScreenSaverGardenScene(key: "cozy-apartment-studio", displayName: "Cozy Apartment Studio"),
        ScreenSaverGardenScene(key: "cottage-backyard-garden", displayName: "Cottage Backyard Garden"),
        ScreenSaverGardenScene(key: "chinese-mountain-monk-garden", displayName: "Chinese Mountain Monk Garden"),
        ScreenSaverGardenScene(key: "swedish-patio-garden", displayName: "Swedish Patio Garden"),
        ScreenSaverGardenScene(key: "brazilian-rooftop-garden", displayName: "Brazilian Rooftop Garden"),
        ScreenSaverGardenScene(key: "ancient-egyptian-estate-garden", displayName: "Ancient Egyptian Estate Garden"),
        ScreenSaverGardenScene(key: "texas-rustic-garden", displayName: "Texas Rustic Garden"),
        ScreenSaverGardenScene(key: "starship-command-bridge", displayName: "Starship Command Bridge"),
        ScreenSaverGardenScene(key: "room-modern-bedroom-canvas", displayName: "Modern Bedroom Canvas"),
        ScreenSaverGardenScene(key: "room-loft-hangout-canvas", displayName: "Loft Hangout Canvas"),
        ScreenSaverGardenScene(key: "room-media-den-canvas", displayName: "Media Den Canvas")
    ]

    let key: String
    let displayName: String
}

private enum ScreenSaverSceneDayCyclePhase: String, CaseIterable {
    case sunrise
    case morning
    case midday
    case afternoon
    case goldenHour = "golden-hour"
    case night

    init(date: Date, calendar: Calendar = .current) {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<8:
            self = .sunrise
        case 8..<11:
            self = .morning
        case 11..<15:
            self = .midday
        case 15..<18:
            self = .afternoon
        case 18..<21:
            self = .goldenHour
        default:
            self = .night
        }
    }
}

private struct ScreenSaverCustomWallpaperRecord: Codable, Equatable {
    var key: String
    var displayName: String
    var prompt: String
    var imageURL: URL
    var createdAt: Date
}

private final class ScreenSaverGardenRenderer {
    private let assetLibrary: ScreenSaverPlantAssetLibrary
    private let customAssetLibrary: ScreenSaverCustomPlantAssetLibrary
    private let sceneLibrary: ScreenSaverSceneLibrary

    init(bundle: Bundle) {
        assetLibrary = ScreenSaverPlantAssetLibrary(bundle: bundle)
        customAssetLibrary = ScreenSaverCustomPlantAssetLibrary(bundle: bundle)
        sceneLibrary = ScreenSaverSceneLibrary(bundle: bundle)
    }

    func customWallpaperRecords() -> [ScreenSaverCustomWallpaperRecord] {
        sceneLibrary.customWallpaperRecords()
    }

    func draw(
        state: GardenState,
        sceneKey: String,
        screenIndex: Int,
        in bounds: NSRect,
        date: Date,
        desktopWallpaperImageURL: URL?,
        gardenSnapshotImageURL: URL?,
        animationElapsed: TimeInterval,
        isPreview: Bool
    ) {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        if let gardenSnapshotImageURL,
           let snapshotImage = NSImage(contentsOf: gardenSnapshotImageURL),
           snapshotImage.size.width > 0,
           snapshotImage.size.height > 0 {
            drawAspectFill(snapshotImage, in: bounds)
            return
        }

        drawBackground(
            sceneKey: sceneKey,
            desktopWallpaperImageURL: desktopWallpaperImageURL,
            in: bounds,
            date: date
        )
        drawScreensaverGrade(in: bounds, isPreview: isPreview)

        let plants = state.plants
            .filter { $0.screenIndex == screenIndex && hasDisplayableAsset(for: $0) }
            .sorted { $0.position.y < $1.position.y }

        let drawablePlants = plants.isEmpty
            ? state.plants.filter { hasDisplayableAsset(for: $0) }.sorted { $0.position.y < $1.position.y }
            : plants

        for plant in drawablePlants {
            drawPlant(plant, state: state, in: bounds, animationElapsed: animationElapsed)
        }

        if state.isAmbientWildlifeEnabled {
            drawAmbientLife(in: bounds, date: date, animationElapsed: animationElapsed)
        }
    }

    private func hasDisplayableAsset(for plant: Plant) -> Bool {
        if let customAssetID = plant.customAssetID {
            return customAssetLibrary.hasDisplayableAsset(for: customAssetID)
        }

        return assetLibrary.hasDisplayableAsset(for: plant.species)
    }

    /// Lightweight parity with the desktop garden's wildlife: simple
    /// butterflies drifting by day, pulsing fireflies after dark.
    private func drawAmbientLife(in bounds: NSRect, date: Date, animationElapsed: TimeInterval) {
        let sunlight = GardenSunlightCondition(at: date)
        let time = animationElapsed

        if sunlight.mood == .night {
            for index in 0..<9 {
                let seed = Double(index) * 53.71
                let x = bounds.width * CGFloat((seed * 0.173 + time * 0.011 * (1 + seed.truncatingRemainder(dividingBy: 1))).truncatingRemainder(dividingBy: 1))
                let baseY = bounds.height * CGFloat(0.18 + 0.55 * (seed * 0.291).truncatingRemainder(dividingBy: 1))
                let y = baseY + CGFloat(sin(time * 0.5 + seed)) * 16
                let pulse = 0.5 + 0.5 * sin(time * (1.0 + (seed * 0.37).truncatingRemainder(dividingBy: 1)) + seed * 2)
                guard pulse > 0.15 else {
                    continue
                }

                let radius = CGFloat(1.4 + pulse * 2.0)
                let halo = NSBezierPath(ovalIn: NSRect(x: x - radius * 3, y: y - radius * 3, width: radius * 6, height: radius * 6))
                NSColor(calibratedRed: 0.84, green: 1.0, blue: 0.55, alpha: 0.08 * pulse).setFill()
                halo.fill()
                let body = NSBezierPath(ovalIn: NSRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                NSColor(calibratedRed: 0.89, green: 1.0, blue: 0.59, alpha: 0.8 * pulse).setFill()
                body.fill()
            }
            return
        }

        for index in 0..<4 {
            let seed = Double(index) * 91.31
            let progress = (seed * 0.137 + time * 0.022 * (0.8 + (seed * 0.41).truncatingRemainder(dividingBy: 1) * 0.5)).truncatingRemainder(dividingBy: 1.2)
            let x = bounds.width * CGFloat(progress - 0.1)
            let lane = 0.55 + 0.30 * (seed * 0.57).truncatingRemainder(dividingBy: 1)
            let y = bounds.height * CGFloat(lane) + CGFloat(sin(time * 1.4 + seed)) * 18
            let flap = abs(sin(time * 9 + seed * 3))
            let wingWidth = CGFloat(5.5 + flap * 4.5)
            let wingHeight: CGFloat = 5

            let wingColor = index.isMultiple(of: 2)
                ? NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.32, alpha: 0.85)
                : NSColor(calibratedRed: 0.62, green: 0.69, blue: 0.93, alpha: 0.85)
            for side in [-1.0, 1.0] {
                let wing = NSBezierPath(ovalIn: NSRect(
                    x: x + CGFloat(side) * 1.5 - (side < 0 ? wingWidth : 0),
                    y: y - wingHeight / 2,
                    width: wingWidth,
                    height: wingHeight
                ))
                wingColor.setFill()
                wing.fill()
            }
            let bodyPath = NSBezierPath(ovalIn: NSRect(x: x - 1.1, y: y - 3.4, width: 2.2, height: 6.8))
            NSColor(calibratedRed: 0.22, green: 0.18, blue: 0.14, alpha: 0.9).setFill()
            bodyPath.fill()
        }
    }

    private func drawCatCompanion(
        in bounds: NSRect,
        animationElapsed: TimeInterval,
        settings: ScreenSaverCatSettings,
        isPreview: Bool
    ) {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        let viewportScale = min(1.05, max(0.52, bounds.height / 900.0))
        let catHeight = min(bounds.height * (isPreview ? 0.25 : 0.20), max(70, CGFloat(settings.sizePoints) * viewportScale))
        let catWidth = catHeight * CGFloat(1.20 + (settings.chubbiness - 1.0) * 0.28)
        let travel = 0.5 + 0.5 * sin(animationElapsed * 0.055)
        let x = bounds.width * CGFloat(0.12 + travel * 0.76)
        let groundY = bounds.height * (isPreview ? 0.16 : 0.11)
        let facingLeft = cos(animationElapsed * 0.055) < 0
        let bob = CGFloat(sin(animationElapsed * 1.8)) * 2.4
        let bodyRect = NSRect(
            x: x - catWidth / 2,
            y: groundY + catHeight * 0.20 + bob,
            width: catWidth,
            height: catHeight * 0.44
        )

        let palette = catPalette(settings.variant)
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        context?.setShadow(offset: CGSize(width: 0, height: 6), blur: 12, color: NSColor.black.withAlphaComponent(0.22).cgColor)
        NSColor(calibratedWhite: 0.0, alpha: 0.18).setFill()
        NSBezierPath(ovalIn: NSRect(
            x: bodyRect.minX + bodyRect.width * 0.08,
            y: groundY - catHeight * 0.03,
            width: bodyRect.width * 0.84,
            height: bodyRect.height * 0.28
        )).fill()
        context?.restoreGState()

        let transform = NSAffineTransform()
        transform.translateX(by: x, yBy: 0)
        transform.scaleX(by: facingLeft ? -1 : 1, yBy: 1)
        transform.translateX(by: -x, yBy: 0)
        transform.concat()

        palette.body.setFill()
        NSBezierPath(ovalIn: bodyRect).fill()

        let headRect = NSRect(
            x: bodyRect.maxX - catHeight * 0.33,
            y: bodyRect.maxY - catHeight * 0.09,
            width: catHeight * 0.38,
            height: catHeight * 0.34
        )
        NSBezierPath(ovalIn: headRect).fill()

        drawCatEar(
            points: [
                NSPoint(x: headRect.minX + headRect.width * 0.16, y: headRect.maxY - headRect.height * 0.18),
                NSPoint(x: headRect.minX + headRect.width * 0.30, y: headRect.maxY + headRect.height * 0.36),
                NSPoint(x: headRect.minX + headRect.width * 0.45, y: headRect.maxY - headRect.height * 0.18)
            ],
            fill: palette.body
        )
        drawCatEar(
            points: [
                NSPoint(x: headRect.minX + headRect.width * 0.58, y: headRect.maxY - headRect.height * 0.16),
                NSPoint(x: headRect.minX + headRect.width * 0.74, y: headRect.maxY + headRect.height * 0.34),
                NSPoint(x: headRect.minX + headRect.width * 0.88, y: headRect.maxY - headRect.height * 0.18)
            ],
            fill: palette.body
        )

        let legWidth = catHeight * 0.105
        for offset in [0.18, 0.38, 0.66, 0.82] {
            let legRect = NSRect(
                x: bodyRect.minX + bodyRect.width * offset - legWidth / 2,
                y: groundY,
                width: legWidth,
                height: bodyRect.minY - groundY + catHeight * 0.08
            )
            NSBezierPath(roundedRect: legRect, xRadius: legWidth * 0.45, yRadius: legWidth * 0.45).fill()
            NSBezierPath(ovalIn: NSRect(
                x: legRect.minX - legWidth * 0.08,
                y: legRect.minY - legWidth * 0.10,
                width: legWidth * 1.16,
                height: legWidth * 0.62
            )).fill()
        }

        drawCatTail(bodyRect: bodyRect, catHeight: catHeight, color: palette.body, time: animationElapsed)
        drawCatFace(headRect: headRect, palette: palette)

        if settings.stripeAmount > 0.08 {
            drawCatStripes(bodyRect: bodyRect, headRect: headRect, intensity: CGFloat(settings.stripeAmount), color: palette.stripe)
        }

        transform.invert()
        transform.concat()
    }

    private func drawCatEar(points: [NSPoint], fill: NSColor) {
        guard let first = points.first else {
            return
        }

        let path = NSBezierPath()
        path.move(to: first)
        for point in points.dropFirst() {
            path.line(to: point)
        }
        path.close()
        fill.setFill()
        path.fill()
    }

    private func drawCatTail(bodyRect: NSRect, catHeight: CGFloat, color: NSColor, time: TimeInterval) {
        let path = NSBezierPath()
        let lift = CGFloat(sin(time * 0.8)) * catHeight * 0.025
        path.move(to: NSPoint(x: bodyRect.minX + bodyRect.width * 0.08, y: bodyRect.midY))
        path.curve(
            to: NSPoint(x: bodyRect.minX - catHeight * 0.20, y: bodyRect.maxY + catHeight * 0.18 + lift),
            controlPoint1: NSPoint(x: bodyRect.minX - catHeight * 0.20, y: bodyRect.midY + catHeight * 0.14),
            controlPoint2: NSPoint(x: bodyRect.minX - catHeight * 0.30, y: bodyRect.maxY + catHeight * 0.26 + lift)
        )
        color.setStroke()
        path.lineWidth = max(7, catHeight * 0.075)
        path.lineCapStyle = .round
        path.stroke()
    }

    private func drawCatFace(headRect: NSRect, palette: (body: NSColor, stripe: NSColor, eye: NSColor, nose: NSColor)) {
        palette.eye.setFill()
        NSBezierPath(ovalIn: NSRect(
            x: headRect.minX + headRect.width * 0.35,
            y: headRect.minY + headRect.height * 0.58,
            width: headRect.width * 0.08,
            height: headRect.height * 0.11
        )).fill()
        NSBezierPath(ovalIn: NSRect(
            x: headRect.minX + headRect.width * 0.66,
            y: headRect.minY + headRect.height * 0.58,
            width: headRect.width * 0.08,
            height: headRect.height * 0.11
        )).fill()

        palette.nose.setFill()
        NSBezierPath(ovalIn: NSRect(
            x: headRect.minX + headRect.width * 0.52,
            y: headRect.minY + headRect.height * 0.44,
            width: headRect.width * 0.08,
            height: headRect.height * 0.06
        )).fill()

        let whiskerColor = NSColor(calibratedWhite: 0.96, alpha: 0.72)
        for side in [-1.0, 1.0] {
            for lane in [-0.08, 0.02, 0.12] {
                let start = NSPoint(
                    x: headRect.minX + headRect.width * (side < 0 ? 0.48 : 0.64),
                    y: headRect.minY + headRect.height * CGFloat(0.45 + lane)
                )
                let end = NSPoint(
                    x: start.x + CGFloat(side) * headRect.width * 0.42,
                    y: start.y + CGFloat(lane) * headRect.height * 0.55
                )
                let path = NSBezierPath()
                path.move(to: start)
                path.line(to: end)
                whiskerColor.setStroke()
                path.lineWidth = 1
                path.stroke()
            }
        }
    }

    private func drawCatStripes(bodyRect: NSRect, headRect: NSRect, intensity: CGFloat, color: NSColor) {
        color.withAlphaComponent(min(0.52, 0.12 + intensity * 0.24)).setStroke()
        for offset in [0.24, 0.38, 0.52, 0.66] {
            let path = NSBezierPath()
            let x = bodyRect.minX + bodyRect.width * offset
            path.move(to: NSPoint(x: x, y: bodyRect.minY + bodyRect.height * 0.14))
            path.curve(
                to: NSPoint(x: x + bodyRect.width * 0.04, y: bodyRect.minY + bodyRect.height * 0.72),
                controlPoint1: NSPoint(x: x - bodyRect.width * 0.04, y: bodyRect.minY + bodyRect.height * 0.30),
                controlPoint2: NSPoint(x: x + bodyRect.width * 0.05, y: bodyRect.minY + bodyRect.height * 0.52)
            )
            path.lineWidth = max(2, bodyRect.height * 0.035)
            path.stroke()
        }

        for offset in [0.38, 0.52, 0.66] {
            let path = NSBezierPath()
            let x = headRect.minX + headRect.width * offset
            path.move(to: NSPoint(x: x, y: headRect.minY + headRect.height * 0.18))
            path.line(to: NSPoint(x: x - headRect.width * 0.04, y: headRect.minY + headRect.height * 0.38))
            path.lineWidth = max(1.4, headRect.height * 0.035)
            path.stroke()
        }
    }

    private func catPalette(_ variant: String) -> (body: NSColor, stripe: NSColor, eye: NSColor, nose: NSColor) {
        switch variant {
        case "gray":
            return (
                NSColor(calibratedRed: 0.48, green: 0.50, blue: 0.52, alpha: 1),
                NSColor(calibratedRed: 0.26, green: 0.28, blue: 0.30, alpha: 1),
                NSColor(calibratedRed: 0.82, green: 0.96, blue: 0.58, alpha: 1),
                NSColor(calibratedRed: 0.33, green: 0.25, blue: 0.25, alpha: 1)
            )
        case "charcoal":
            return (
                NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.17, alpha: 1),
                NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.07, alpha: 1),
                NSColor(calibratedRed: 0.84, green: 0.90, blue: 0.58, alpha: 1),
                NSColor(calibratedRed: 0.50, green: 0.37, blue: 0.38, alpha: 1)
            )
        case "cream":
            return (
                NSColor(calibratedRed: 0.82, green: 0.72, blue: 0.58, alpha: 1),
                NSColor(calibratedRed: 0.58, green: 0.43, blue: 0.30, alpha: 1),
                NSColor(calibratedRed: 0.56, green: 0.78, blue: 0.55, alpha: 1),
                NSColor(calibratedRed: 0.62, green: 0.38, blue: 0.36, alpha: 1)
            )
        default:
            return (
                NSColor(calibratedRed: 0.78, green: 0.43, blue: 0.23, alpha: 1),
                NSColor(calibratedRed: 0.49, green: 0.24, blue: 0.12, alpha: 1),
                NSColor(calibratedRed: 0.88, green: 0.93, blue: 0.54, alpha: 1),
                NSColor(calibratedRed: 0.56, green: 0.30, blue: 0.28, alpha: 1)
            )
        }
    }

    private func drawBackground(
        sceneKey: String,
        desktopWallpaperImageURL: URL?,
        in bounds: NSRect,
        date: Date
    ) {
        if let sceneImage = sceneLibrary.image(
            for: sceneKey,
            date: date,
            desktopWallpaperImageURL: desktopWallpaperImageURL
        ) {
            drawAspectFill(sceneImage, in: bounds)
        } else if let fallbackImage = sceneLibrary.image(for: ScreenSaverGardenScene.defaultKey, date: date) {
            drawAspectFill(fallbackImage, in: bounds)
        } else {
            drawFallbackBackground(in: bounds)
        }

        let sunlight = GardenSunlightCondition(at: date)
        switch sunlight.mood {
        case .night:
            NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.12, alpha: 0.30).setFill()
        case .golden:
            NSColor(calibratedRed: 0.18, green: 0.10, blue: 0.04, alpha: 0.08).setFill()
        case .morning:
            NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.72, alpha: 0.055).setFill()
        case .bright:
            NSColor(calibratedWhite: 1.0, alpha: 0.025).setFill()
        }
        bounds.fill()
    }

    private func drawScreensaverGrade(in bounds: NSRect, isPreview: Bool) {
        let alpha: CGFloat = isPreview ? 0.05 : 0.09
        NSGradient(colors: [
            NSColor(calibratedWhite: 0.0, alpha: alpha),
            NSColor(calibratedWhite: 0.0, alpha: 0.0),
            NSColor(calibratedWhite: 0.0, alpha: alpha * 1.4)
        ])?.draw(in: bounds, angle: -90)

        let inset = -bounds.width * 0.08
        let vignette = NSBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: -bounds.height * 0.18))
        let outer = NSBezierPath(rect: bounds)
        outer.append(vignette)
        outer.windingRule = .evenOdd
        NSColor(calibratedWhite: 0.0, alpha: isPreview ? 0.06 : 0.12).setFill()
        outer.fill()
    }

    private func drawPlant(_ plant: Plant, state: GardenState, in bounds: NSRect, animationElapsed: TimeInterval) {
        let assetStage = PlantAssetStage(growth: plant.growth)
        guard let image = plantImage(for: plant, stageIndex: assetStage.index),
              image.size.width > 0,
              image.size.height > 0 else {
            return
        }

        let anchor = NSPoint(
            x: CGFloat(plant.position.x) * bounds.width,
            y: CGFloat(plant.position.y) * bounds.height
        )
        let baseHeight = height(for: plant, in: bounds)
        let targetHeight = realisticHeight(for: plant, baseHeight: baseHeight, in: bounds)
        let widthFactor = youngPlantWidthFactor(for: plant)
        let targetWidth = targetHeight * image.size.width / max(1, image.size.height) * widthFactor
        let stress = stressLevel(for: plant)
        let droop = stress * targetHeight * (plant.isDead ? 0.095 : 0.055)
        let lean = stress * (plant.isDead ? 7.5 : 4.5)
        let rect = NSRect(
            x: anchor.x - targetWidth / 2,
            y: anchor.y - targetHeight + droop,
            width: targetWidth,
            height: targetHeight
        )
        let assetComposite = PlantAssetRenderComposite(plant: plant, assetStage: assetStage)
        let currentStageOpacity = CGFloat(assetComposite.currentStageOpacity)

        drawAssetTransformed(
            image,
            rect: rect,
            anchor: anchor,
            rotationDegrees: lean,
            opacity: currentStageOpacity
        )

        if plant.customAssetID == nil,
           let nextIndex = assetStage.nextIndex,
           assetStage.blendOpacity > 0,
           let nextImage = plantImage(for: plant, stageIndex: nextIndex),
           nextImage.size.width > 0,
           nextImage.size.height > 0 {
            let blendRect = realisticAssetRect(
                for: nextImage,
                anchor: anchor,
                targetHeight: targetHeight,
                widthFactor: widthFactor,
                droop: droop
            )
            drawAssetTransformed(
                nextImage,
                rect: blendRect,
                anchor: anchor,
                rotationDegrees: lean,
                opacity: CGFloat(assetComposite.nextStageOverlayOpacity)
            )
        }
    }

    private func plantImage(for plant: Plant, stageIndex: Int) -> NSImage? {
        if let customAssetID = plant.customAssetID {
            return customAssetLibrary.image(for: customAssetID)
        }

        return assetLibrary.image(for: plant.species, stageIndex: stageIndex)
    }

    private func drawAssetTransformed(
        _ image: NSImage,
        rect: NSRect,
        anchor: NSPoint,
        rotationDegrees: CGFloat,
        opacity: CGFloat
    ) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            drawAsset(image, in: rect, opacity: opacity)
            return
        }

        context.saveGState()
        context.translateBy(x: anchor.x, y: anchor.y)
        context.rotate(by: rotationDegrees * .pi / 180)
        let localRect = NSRect(
            x: rect.minX - anchor.x,
            y: rect.minY - anchor.y,
            width: rect.width,
            height: rect.height
        )
        drawAsset(image, in: localRect, opacity: opacity)
        context.restoreGState()
    }

    private func drawAsset(_ image: NSImage, in rect: NSRect, opacity: CGFloat) {
        image.draw(
            in: rect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: max(0, min(1, opacity)),
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func realisticAssetRect(
        for image: NSImage,
        anchor: NSPoint,
        targetHeight: CGFloat,
        widthFactor: CGFloat,
        droop: CGFloat
    ) -> NSRect {
        let targetWidth = targetHeight * image.size.width / max(1, image.size.height) * widthFactor
        return NSRect(
            x: anchor.x - targetWidth / 2,
            y: anchor.y - targetHeight + droop,
            width: targetWidth,
            height: targetHeight
        )
    }

    private func height(for plant: Plant, in bounds: NSRect) -> CGFloat {
        let viewportFactor = min(1.05, max(0.72, bounds.height / 900.0))
        let growthFactor = 0.16 + CGFloat(plant.growth) * 0.84
        let depthScale = CGFloat(plant.depthProfile.heightScale)
        let baseHeight = CGFloat(104 * plant.species.matureHeightMultiplier * plant.scale)
        return min(bounds.height * 0.48, max(20, baseHeight * growthFactor * viewportFactor * depthScale))
    }

    private func realisticHeight(for plant: Plant, baseHeight: CGFloat, in bounds: NSRect) -> CGFloat {
        let multiplier: CGFloat
        let minimumHeight: CGFloat
        let maxScreenFraction: CGFloat

        switch plant.species.kind {
        case .tree:
            multiplier = 1.86
            minimumHeight = 160
            maxScreenFraction = 0.62
        case .foliage:
            multiplier = 1.72
            minimumHeight = 118
            maxScreenFraction = 0.34
        case .edible:
            multiplier = 1.78
            minimumHeight = 112
            maxScreenFraction = 0.40
        case .flower:
            multiplier = plant.species == .sunflower ? 2.05 : 1.88
            minimumHeight = plant.species == .sunflower ? 156 : 116
            maxScreenFraction = 0.42
        case .meadow:
            multiplier = 2.52
            minimumHeight = 122
            maxScreenFraction = 0.36
        }

        let depthScale = CGFloat(plant.depthProfile.heightScale)
        let maturityMinimum = minimumHeight * depthScale * (0.42 + CGFloat(plant.growth) * 0.58)
        return min(bounds.height * maxScreenFraction, max(maturityMinimum, baseHeight * multiplier))
    }

    private func youngPlantWidthFactor(for plant: Plant) -> CGFloat {
        switch plant.growthStage {
        case .dead:
            return 0.82
        case .seedling:
            return 0.54
        case .sprout:
            return 0.72
        case .young:
            return 0.88
        case .mature, .blooming:
            return 1.0
        }
    }

    private func stressLevel(for plant: Plant) -> CGFloat {
        if plant.isDead {
            return 1
        }

        let vitality = min(plant.health, plant.hydration)
        return CGFloat(max(0, min(1, 1 - vitality)))
    }

    private func opacity(for plant: Plant) -> CGFloat {
        if plant.isDead {
            let depthOpacity = 0.92 + plant.depthProfile.depth * 0.08
            return CGFloat(0.34 * depthOpacity)
        }

        let vitality = min(plant.health, plant.hydration)
        let depthOpacity = 0.92 + plant.depthProfile.depth * 0.08
        return CGFloat(min(1, (0.42 + vitality * 0.58) * depthOpacity))
    }

    private func circadianAssetOpacityMultiplier(for circadianState: PlantCircadianState, plant: Plant) -> Double {
        switch circadianState.phase {
        case .nightRest:
            plant.species.kind == .flower || plant.species.kind == .meadow ? 0.86 : 0.92
        case .morningRecovery:
            0.96
        case .photosynthesizing, .goldenBloom:
            1.0
        }
    }

    private func drawAspectFill(_ image: NSImage, in rect: NSRect) {
        let sourceSize = image.size
        let sourceAspect = sourceSize.width / max(1, sourceSize.height)
        let targetAspect = rect.width / max(1, rect.height)
        let sourceRect: NSRect

        if targetAspect > sourceAspect {
            let cropHeight = sourceSize.width / targetAspect
            sourceRect = NSRect(
                x: 0,
                y: (sourceSize.height - cropHeight) / 2,
                width: sourceSize.width,
                height: cropHeight
            )
        } else {
            let cropWidth = sourceSize.height * targetAspect
            sourceRect = NSRect(
                x: (sourceSize.width - cropWidth) / 2,
                y: 0,
                width: cropWidth,
                height: sourceSize.height
            )
        }

        image.draw(
            in: rect,
            from: sourceRect,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func drawFallbackBackground(in rect: NSRect) {
        NSGradient(colors: [
            NSColor(calibratedRed: 0.77, green: 0.84, blue: 0.76, alpha: 1),
            NSColor(calibratedRed: 0.89, green: 0.87, blue: 0.76, alpha: 1)
        ])?.draw(in: rect, angle: -90)
    }
}

private struct ScreenSaverCustomPlantAssetRecord: Decodable {
    var id: String
    var imageURL: URL
}

private final class ScreenSaverCustomPlantAssetLibrary {
    private let manifestURL: URL
    private let bundle: Bundle
    private var imageCache: [String: NSImage] = [:]

    init(
        baseDirectoryURL: URL = GardenPersistence.defaultDirectoryURL(),
        bundle: Bundle
    ) {
        self.bundle = bundle
        manifestURL = baseDirectoryURL
            .appendingPathComponent("CustomPlantAssets", isDirectory: true)
            .appendingPathComponent("custom-plant-assets.json")
    }

    func hasDisplayableAsset(for id: String) -> Bool {
        if bundledAlienImageURL(for: id) != nil {
            return true
        }

        guard let record = record(for: id) else {
            return false
        }

        return FileManager.default.fileExists(atPath: record.imageURL.path)
    }

    func image(for id: String) -> NSImage? {
        if let cachedImage = imageCache[id] {
            return cachedImage
        }

        let imageURL = bundledAlienImageURL(for: id) ?? record(for: id)?.imageURL
        guard let imageURL,
              let image = NSImage(contentsOf: imageURL) else {
            return nil
        }

        image.cacheMode = .always
        imageCache[id] = image
        return image
    }

    private func record(for id: String) -> ScreenSaverCustomPlantAssetRecord? {
        records().first { $0.id == id }
    }

    private func records() -> [ScreenSaverCustomPlantAssetRecord] {
        guard FileManager.default.fileExists(atPath: manifestURL.path),
              let data = try? Data(contentsOf: manifestURL),
              let records = try? JSONDecoder().decode([ScreenSaverCustomPlantAssetRecord].self, from: data) else {
            return []
        }

        return records
    }

    private func bundledAlienImageURL(for id: String) -> URL? {
        let prefix = "alien-specimen-"
        guard id.hasPrefix(prefix) else {
            return nil
        }

        let assetName = String(id.dropFirst(prefix.count))
        return bundle.url(
            forResource: assetName,
            withExtension: "png",
            subdirectory: "AlienPlantAssets"
        )
    }
}

private final class ScreenSaverPlantAssetLibrary {
    static let stageCount = 10

    private let bundle: Bundle
    private var cache: [String: NSImage] = [:]

    init(bundle: Bundle) {
        self.bundle = bundle
    }

    func hasDisplayableAsset(for species: PlantSpecies) -> Bool {
        (0..<Self.stageCount).allSatisfy { index in
            imageURL(named: stageAssetName(for: species, index: index)) != nil
        }
    }

    func image(for species: PlantSpecies, stageIndex: Int) -> NSImage? {
        let safeIndex = min(Self.stageCount - 1, max(0, stageIndex))
        if let exactStage = image(named: stageAssetName(for: species, index: safeIndex)) {
            return exactStage
        }

        if let nearestName = nearestStageAssetName(for: species, index: safeIndex),
           let nearestStage = image(named: nearestName) {
            return nearestStage
        }

        return image(named: assetName(for: species))
    }

    private func image(named name: String) -> NSImage? {
        if let cachedImage = cache[name] {
            return cachedImage
        }

        guard let url = imageURL(named: name),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.cacheMode = .always
        cache[name] = image
        return image
    }

    private func imageURL(named name: String) -> URL? {
        bundle.url(forResource: name, withExtension: "png")
            ?? bundle.url(forResource: name, withExtension: "png", subdirectory: "PlantAssets")
    }

    private func nearestStageAssetName(for species: PlantSpecies, index: Int) -> String? {
        (0..<Self.stageCount)
            .sorted { left, right in
                abs(left - index) < abs(right - index)
            }
            .map { stageAssetName(for: species, index: $0) }
            .first { imageURL(named: $0) != nil }
    }

    private func assetName(for species: PlantSpecies) -> String {
        species.rawValue.kebabCasedPlantAssetName
    }

    private func stageAssetName(for species: PlantSpecies, index: Int) -> String {
        "\(assetName(for: species))-stage-\(String(format: "%02d", index))"
    }
}

private final class ScreenSaverSceneLibrary {
    private let bundle: Bundle
    private let fileManager: FileManager

    init(bundle: Bundle, fileManager: FileManager = .default) {
        self.bundle = bundle
        self.fileManager = fileManager
    }

    func image(for sceneKey: String, date: Date, desktopWallpaperImageURL: URL? = nil) -> NSImage? {
        if let desktopWallpaperImageURL,
           fileManager.fileExists(atPath: desktopWallpaperImageURL.path),
           let desktopImage = NSImage(contentsOf: desktopWallpaperImageURL) {
            return desktopImage
        }

        let phase = ScreenSaverSceneDayCyclePhase(date: date)
        if let phaseURL = bundledImageURL(for: "\(sceneKey)-\(phase.rawValue)") {
            return NSImage(contentsOf: phaseURL)
        }

        if let url = bundledImageURL(for: sceneKey) {
            return NSImage(contentsOf: url)
        }

        return customWallpaperRecords()
            .first { $0.key == sceneKey }
            .flatMap { NSImage(contentsOf: $0.imageURL) }
    }

    private func bundledImageURL(for resourceName: String) -> URL? {
        bundle.url(forResource: resourceName, withExtension: "png", subdirectory: "SceneAssets")
    }

    func customWallpaperRecords() -> [ScreenSaverCustomWallpaperRecord] {
        let manifestURL = GardenPersistence.defaultDirectoryURL(fileManager: fileManager)
            .appendingPathComponent("Wallpaper", isDirectory: true)
            .appendingPathComponent("custom-wallpapers.json")
        guard fileManager.fileExists(atPath: manifestURL.path),
              let data = try? Data(contentsOf: manifestURL) else {
            return []
        }

        return (try? JSONDecoder().decode([ScreenSaverCustomWallpaperRecord].self, from: data)) ?? []
    }
}

private extension NSScreen {
    var screenNumber: NSNumber? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    }
}

private extension String {
    var kebabCasedPlantAssetName: String {
        reduce(into: "") { result, character in
            if character.isUppercase {
                if !result.isEmpty {
                    result.append("-")
                }
                result.append(character.lowercased())
            } else {
                result.append(character)
            }
        }
    }
}
