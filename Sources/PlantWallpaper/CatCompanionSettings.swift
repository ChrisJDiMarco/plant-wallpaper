import AppKit
import WebKit

extension Notification.Name {
    static let gardenCatCompanionSettingsChanged = Notification.Name("gardenCatCompanionSettingsChanged")
}

/// Operator-tunable cat companion settings, persisted in UserDefaults.
/// Appearance values feed the procedural model; personality values shape
/// the behavior state machine in cat-behavior.js.
struct CatCompanionSettings {
    private static let appDefaultsSuiteName = "com.chrisdimarco.wallpapergarden"

    static let variantOptions: [(key: String, label: String)] = [
        ("random", "Surprise Me"),
        ("orange", "Orange Tabby"),
        ("redtabby", "Flame Red Tabby"),
        ("gray", "Gray Tabby"),
        ("silver", "Silver Tabby"),
        ("brown", "Brown Classic Tabby"),
        ("cream", "Cream"),
        ("charcoal", "Charcoal"),
        ("blue", "Russian Blue"),
        ("black", "Black"),
        ("white", "White"),
        ("siamese", "Siamese"),
        ("bluepoint", "Blue-Point Siamese"),
        ("tuxedo", "Tuxedo"),
        ("calico", "Calico")
    ]

    var variant = "random"
    var sizePoints = 175.0       // shoulder height on screen
    var chubbiness = 1.0         // 0.8 slender ... 1.3 chonky
    var furLength = 1.5          // 1.23 floor (old 70%) ... 1.8 fluffy (model cap)
    var stripeAmount = 1.0       // 0 solid coat ... 1.5 bold tabby
    var activity = 0.5           // 0 couch potato ... 1 busybody
    var curiosity = 0.5          // 0 aloof ... 1 watches everything
    var playfulness = 0.6        // 0 dignified ... 1 menace
    var mouseReactions = true
    var purringEnabled = true

    /// Changing these requires rebuilding the cat's geometry (web reload);
    /// everything else applies live.
    var buildFingerprint: String {
        "\(variant)|\(chubbiness)|\(stripeAmount)"
    }

    static func load() -> CatCompanionSettings {
        let defaults = UserDefaults.standard
        var settings = CatCompanionSettings()
        if let variant = defaults.string(forKey: "catVariant") { settings.variant = variant }
        settings.sizePoints = readDouble(defaults, "catSizePoints", fallback: settings.sizePoints, range: 120 ... 260)
        settings.chubbiness = readDouble(defaults, "catChubbiness", fallback: settings.chubbiness, range: 0.8 ... 1.3)
        settings.furLength = readDouble(defaults, "catFurLength", fallback: settings.furLength, range: 1.23 ... 1.8)
        settings.stripeAmount = readDouble(defaults, "catStripeAmount", fallback: settings.stripeAmount, range: 0 ... 1.5)
        settings.activity = readDouble(defaults, "catActivity", fallback: settings.activity, range: 0 ... 1)
        settings.curiosity = readDouble(defaults, "catCuriosity", fallback: settings.curiosity, range: 0 ... 1)
        settings.playfulness = readDouble(defaults, "catPlayfulness", fallback: settings.playfulness, range: 0 ... 1)
        if defaults.object(forKey: "catMouseReactions") != nil {
            settings.mouseReactions = defaults.bool(forKey: "catMouseReactions")
        }
        if defaults.object(forKey: "catPurringEnabled") != nil {
            settings.purringEnabled = defaults.bool(forKey: "catPurringEnabled")
        }
        return settings
    }

    func save() {
        let defaults = UserDefaults.standard
        let sharedDefaults = UserDefaults(suiteName: Self.appDefaultsSuiteName)
        defaults.set(variant, forKey: "catVariant")
        defaults.set(sizePoints, forKey: "catSizePoints")
        defaults.set(chubbiness, forKey: "catChubbiness")
        defaults.set(furLength, forKey: "catFurLength")
        defaults.set(stripeAmount, forKey: "catStripeAmount")
        defaults.set(activity, forKey: "catActivity")
        defaults.set(curiosity, forKey: "catCuriosity")
        defaults.set(playfulness, forKey: "catPlayfulness")
        defaults.set(mouseReactions, forKey: "catMouseReactions")
        defaults.set(purringEnabled, forKey: "catPurringEnabled")

        sharedDefaults?.set(variant, forKey: "catVariant")
        sharedDefaults?.set(sizePoints, forKey: "catSizePoints")
        sharedDefaults?.set(chubbiness, forKey: "catChubbiness")
        sharedDefaults?.set(furLength, forKey: "catFurLength")
        sharedDefaults?.set(stripeAmount, forKey: "catStripeAmount")
        sharedDefaults?.set(activity, forKey: "catActivity")
        sharedDefaults?.set(curiosity, forKey: "catCuriosity")
        sharedDefaults?.set(playfulness, forKey: "catPlayfulness")
        sharedDefaults?.set(mouseReactions, forKey: "catMouseReactions")
        sharedDefaults?.set(purringEnabled, forKey: "catPurringEnabled")
        sharedDefaults?.synchronize()
        NotificationCenter.default.post(name: .gardenCatCompanionSettingsChanged, object: nil)
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

enum CatCompanionSettingsCopy {
    static let windowTitle = "Cat Companion Neural Lab"
    static let visualizerTitle = "Neural temperament map"
    static let visualizerSubtitle = "Your sliders illuminate the circuits that shape how the cat watches, wanders, plays, and reacts."
    static let personalitySliders = ["Activity", "Curiosity", "Playfulness"]
    static let sensoryToggles = ["Cursor hunting intelligence", "Purr when petted"]
}

/// Shared visual tokens for the Cat Companion settings lab. Tuned to read as a
/// light, System Settings–grade panel rather than a dark HUD.
///
/// The surface colors are EXPLICIT light values, not semantic colors like
/// `controlBackgroundColor`. Those resolve to the system's dark variant when
/// baked into a CALayer (`.cgColor`) on a Mac running Dark Mode, which left the
/// cards/pills dark while the live-rendered text stayed light. Hard-coding the
/// light values keeps the whole panel light regardless of system appearance.
private enum CatLabUI {
    static let hInset: CGFloat = 28
    static let rowInsetH: CGFloat = 16
    static let cardRadius: CGFloat = 11
    static let mediaRadius: CGFloat = 20

    static var pageFill: NSColor { NSColor(calibratedWhite: 0.925, alpha: 1) }
    static var cardFill: NSColor { NSColor(calibratedWhite: 1.0, alpha: 1) }
    static var hairline: NSColor { NSColor(calibratedWhite: 0.0, alpha: 0.10) }
    static var divider: NSColor { NSColor(calibratedWhite: 0.0, alpha: 0.12) }
    static var accent: NSColor { NSColor.systemIndigo }
}

/// Large cat companion settings lab. The left side hosts a bundled Three.js
/// neural visualizer; the right side edits the same persisted settings that
/// drive the desktop cat's procedural model and behavior state machine.
@MainActor
final class CatCompanionSettingsWindowController: NSWindowController {
    private var settings = CatCompanionSettings.load()
    private let variantPopup = NSPopUpButton()
    private var sliders: [String: NSSlider] = [:]
    private var valueLabels: [String: NSTextField] = [:]
    private let mouseSwitch = NSSwitch()
    private let purrSwitch = NSSwitch()
    private weak var visualizerWebView: WKWebView?
    private weak var controlsScrollView: NSScrollView?
    private var visualizerNavigationDelegate: MainActorWebNavigationDelegate?

    nonisolated static func neuralVisualizerIndexURL() -> URL? {
        Bundle.appResources.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "WebAssets/cat-brain"
        )
    }

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = CatCompanionSettingsCopy.windowTitle
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 860, height: 580)
        // The cat lives in its own dark media well; the surrounding chrome is a
        // light, refined panel — pin the appearance so it reads that way even on
        // a system set to Dark.
        panel.appearance = NSAppearance(named: .aqua)
        self.init(window: panel)
        buildContent()
    }

    func show() {
        settings = CatCompanionSettings.load()
        syncControls()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            self?.resetControlsScrollPosition()
        }
    }

    private func buildContent() {
        // A plain opaque light surface — NOT an NSVisualEffectView. The effect
        // view's vibrancy forces live AppKit controls (sliders, switches,
        // buttons) into a dark vibrant appearance even when the window is
        // pinned to .aqua, which left the controls dark while the chrome went
        // light. A solid background keeps every control in standard light aqua.
        let root = NSView()
        root.wantsLayer = true
        root.appearance = NSAppearance(named: .aqua)
        root.layer?.backgroundColor = CatLabUI.pageFill.cgColor

        let split = NSStackView()
        split.orientation = .horizontal
        split.alignment = .top
        split.distribution = .fill
        split.spacing = 0
        split.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(split)
        NSLayoutConstraint.activate([
            split.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            split.topAnchor.constraint(equalTo: root.topAnchor),
            split.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        split.addArrangedSubview(makeVisualizerPane())
        split.addArrangedSubview(makePaneDivider())
        split.addArrangedSubview(makeControlsPane())

        window?.contentView = root
        syncControls()
        loadVisualizer()
    }

    private func makePaneDivider() -> NSView {
        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = CatLabUI.divider.cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        return divider
    }

    private func makeVisualizerPane() -> NSView {
        let pane = NSView()
        pane.translatesAutoresizingMaskIntoConstraints = false
        pane.widthAnchor.constraint(greaterThanOrEqualToConstant: 372).isActive = true
        pane.widthAnchor.constraint(lessThanOrEqualToConstant: 452).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 36, left: CatLabUI.hInset, bottom: 28, right: CatLabUI.hInset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        pane.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: pane.trailingAnchor),
            stack.topAnchor.constraint(equalTo: pane.topAnchor),
            stack.bottomAnchor.constraint(equalTo: pane.bottomAnchor)
        ])
        let eyebrow = trackedLabel("CAT COMPANION", size: 11, weight: .semibold, color: CatLabUI.accent, kern: 1.4)
        stack.addArrangedSubview(eyebrow)

        let title = label(CatCompanionSettingsCopy.visualizerTitle, size: 26, weight: .bold, color: .labelColor)
        title.lineBreakMode = .byWordWrapping
        title.maximumNumberOfLines = 2
        stack.addArrangedSubview(title)

        let subtitle = label(CatCompanionSettingsCopy.visualizerSubtitle, size: 12.5, weight: .regular, color: .secondaryLabelColor)
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.maximumNumberOfLines = 3
        stack.addArrangedSubview(subtitle)
        stack.setCustomSpacing(20, after: subtitle)

        let stage = makeMediaStage()
        stack.addArrangedSubview(stage)
        stack.setCustomSpacing(18, after: stage)

        let badges = NSStackView()
        badges.orientation = .horizontal
        badges.alignment = .centerY
        badges.spacing = 8
        badges.distribution = .fillEqually
        badges.addArrangedSubview(statusPill("Motor", color: .systemGreen))
        badges.addArrangedSubview(statusPill("Attention", color: .systemBlue))
        badges.addArrangedSubview(statusPill("Pounce", color: .systemOrange))
        stack.addArrangedSubview(badges)

        // Activate cross-view constraints only after every view is in the
        // hierarchy, otherwise referencing `pane` raises a no-common-ancestor
        // exception that AppKit swallows (window silently fails to open).
        NSLayoutConstraint.activate([
            title.widthAnchor.constraint(lessThanOrEqualTo: pane.widthAnchor, constant: -CatLabUI.hInset * 2),
            subtitle.widthAnchor.constraint(lessThanOrEqualTo: pane.widthAnchor, constant: -CatLabUI.hInset * 2),
            stage.heightAnchor.constraint(greaterThanOrEqualToConstant: 348),
            stage.heightAnchor.constraint(lessThanOrEqualToConstant: 470),
            stage.widthAnchor.constraint(equalTo: pane.widthAnchor, constant: -CatLabUI.hInset * 2),
            badges.widthAnchor.constraint(equalTo: pane.widthAnchor, constant: -CatLabUI.hInset * 2)
        ])
        return pane
    }

    /// The cat photo + 3D brain webview is left untouched; it sits inside a
    /// deliberate dark "viewport" so the neural map keeps its contrast while the
    /// rest of the window stays light.
    private func makeMediaStage() -> NSView {
        let stage = NSView()
        stage.wantsLayer = true
        let gradient = CAGradientLayer()
        gradient.colors = [
            NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.22, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.18, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.12, alpha: 1).cgColor
        ]
        gradient.locations = [0, 0.55, 1]
        gradient.startPoint = CGPoint(x: 0.15, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.85, y: 1.0)
        gradient.cornerRadius = CatLabUI.mediaRadius
        gradient.cornerCurve = .continuous
        gradient.borderWidth = 1
        gradient.borderColor = NSColor.white.withAlphaComponent(0.09).cgColor
        gradient.masksToBounds = false
        gradient.shadowColor = NSColor.black.cgColor
        gradient.shadowOpacity = 0.22
        gradient.shadowRadius = 22
        gradient.shadowOffset = CGSize(width: 0, height: -10)
        stage.layer = gradient
        stage.translatesAutoresizingMaskIntoConstraints = false

        let webView = makeVisualizerWebView()
        stage.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: stage.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: stage.trailingAnchor),
            webView.topAnchor.constraint(equalTo: stage.topAnchor),
            webView.bottomAnchor.constraint(equalTo: stage.bottomAnchor)
        ])
        visualizerWebView = webView
        return stage
    }

    private func makeControlsPane() -> NSView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        controlsScrollView = scrollView

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.edgeInsets = NSEdgeInsets(top: 34, left: CatLabUI.hInset, bottom: 30, right: CatLabUI.hInset)
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = stack
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])

        let header = NSStackView()
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 5
        header.addArrangedSubview(label("Behavior & Appearance", size: 24, weight: .bold, color: .labelColor))
        let subtitle = label("Shape the cat's body, coat, curiosity, and play systems — the brain map responds live.", size: 12.5, weight: .regular, color: .secondaryLabelColor)
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.maximumNumberOfLines = 0
        subtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(subtitle)
        stack.addArrangedSubview(header)
        constrainWidth(header, to: stack)

        let coat = settingsGroup(title: "Coat Identity", caption: "Visual genes that rebuild the procedural cat.", rows: [
            coatRow(),
            sliderControl(key: "stripeAmount", title: "Stripes", min: 0, max: 1.5, lowHint: "Solid", highHint: "Bold tabby"),
            sliderControl(key: "furLength", title: "Fur length", min: 1.23, max: 1.8, lowHint: "Sleek", highHint: "Fluffy")
        ])
        stack.addArrangedSubview(coat)
        constrainWidth(coat, to: stack)

        let body = settingsGroup(title: "Body Geometry", caption: "Screen presence and silhouette.", rows: [
            sliderControl(key: "chubbiness", title: "Chubbiness", min: 0.8, max: 1.3, lowHint: "Slender", highHint: "Round"),
            sliderControl(key: "sizePoints", title: "Size", min: 120, max: 260, lowHint: "Kitten", highHint: "Large")
        ])
        stack.addArrangedSubview(body)
        constrainWidth(body, to: stack)

        let temperament = settingsGroup(title: "Neural Temperament", caption: "These circuits feed the behavior state machine live.", rows: [
            sliderControl(key: "activity", title: "Activity", min: 0, max: 1, lowHint: "Loaf", highHint: "Explorer"),
            sliderControl(key: "curiosity", title: "Curiosity", min: 0, max: 1, lowHint: "Aloof", highHint: "Investigative"),
            sliderControl(key: "playfulness", title: "Playfulness", min: 0, max: 1, lowHint: "Dignified", highHint: "Pounce mode"),
            switchRow(mouseSwitch, title: "Cursor hunting", subtitle: "Watch, stalk, swipe, cling, and hunt cursor movement."),
            switchRow(purrSwitch, title: "Purr when petted", subtitle: "Play a soft synthesized purr when the cat leans into strokes.")
        ])
        stack.addArrangedSubview(temperament)
        constrainWidth(temperament, to: stack)

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 12
        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults))
        resetButton.bezelStyle = .rounded
        resetButton.controlSize = .large
        resetButton.setContentHuggingPriority(.required, for: .horizontal)
        footer.addArrangedSubview(resetButton)
        let note = label("Changes save instantly and update the live desktop cat.", size: 11.5, weight: .regular, color: .tertiaryLabelColor)
        note.lineBreakMode = .byWordWrapping
        note.maximumNumberOfLines = 2
        note.setContentHuggingPriority(.defaultLow, for: .horizontal)
        footer.addArrangedSubview(note)
        stack.addArrangedSubview(footer)
        constrainWidth(footer, to: stack)

        return scrollView
    }

    private func resetControlsScrollPosition() {
        guard let scrollView = controlsScrollView, let documentView = scrollView.documentView else { return }
        scrollView.layoutSubtreeIfNeeded()
        let y = documentView.isFlipped ? 0 : max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func makeVisualizerWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        let navigationDelegate = MainActorWebNavigationDelegate { [weak self] _ in
            self?.pushVisualizerConfiguration()
        }
        webView.navigationDelegate = navigationDelegate
        visualizerNavigationDelegate = navigationDelegate
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        return webView
    }

    private func loadVisualizer() {
        guard let indexURL = Self.neuralVisualizerIndexURL() else {
            return
        }
        let webAssetsRoot = indexURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        visualizerWebView?.loadFileURL(indexURL, allowingReadAccessTo: webAssetsRoot)
    }

    // MARK: - Rows

    private func coatRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let title = titledText("Coat", subtitle: "Choose the cat's rendered variant.")
        row.addArrangedSubview(title)
        if variantPopup.numberOfItems == 0 {
            for option in CatCompanionSettings.variantOptions {
                variantPopup.addItem(withTitle: option.label)
            }
        }
        variantPopup.target = self
        variantPopup.action = #selector(controlChanged)
        variantPopup.controlSize = .regular
        variantPopup.setContentHuggingPriority(.required, for: .horizontal)
        variantPopup.widthAnchor.constraint(equalToConstant: 188).isActive = true
        row.addArrangedSubview(variantPopup)
        return paddedRow(row)
    }

    private func switchRow(_ toggle: NSSwitch, title: String, subtitle: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.addArrangedSubview(titledText(title, subtitle: subtitle))
        toggle.target = self
        toggle.action = #selector(controlChanged)
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(toggle)
        return paddedRow(row)
    }

    private func sliderControl(
        key: String,
        title: String,
        min: Double,
        max: Double,
        lowHint: String,
        highHint: String
    ) -> NSView {
        let wrapper = NSStackView()
        wrapper.orientation = .vertical
        wrapper.alignment = .leading
        wrapper.spacing = 9
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let head = NSStackView()
        head.orientation = .horizontal
        head.alignment = .firstBaseline
        head.spacing = 8
        head.translatesAutoresizingMaskIntoConstraints = false
        head.addArrangedSubview(titledText(title, subtitle: "\(lowHint) to \(highHint)"))

        let value = NSTextField(labelWithString: "")
        value.font = .monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold)
        value.textColor = CatLabUI.accent
        value.alignment = .right
        value.isSelectable = false
        value.setContentHuggingPriority(.required, for: .horizontal)
        value.widthAnchor.constraint(greaterThanOrEqualToConstant: 58).isActive = true
        valueLabels[key] = value
        head.addArrangedSubview(value)
        wrapper.addArrangedSubview(head)

        let slider = NSSlider(value: 0, minValue: min, maxValue: max, target: self, action: #selector(controlChanged))
        slider.isContinuous = true
        slider.controlSize = .regular
        // Tint the filled track to the indigo accent so it matches the value
        // readouts instead of inheriting the user's system accent (which was
        // showing up red).
        slider.trackFillColor = CatLabUI.accent
        slider.translatesAutoresizingMaskIntoConstraints = false
        sliders[key] = slider
        wrapper.addArrangedSubview(slider)

        head.widthAnchor.constraint(equalTo: wrapper.widthAnchor).isActive = true
        slider.widthAnchor.constraint(equalTo: wrapper.widthAnchor).isActive = true
        return paddedRow(wrapper, top: 14, bottom: 16)
    }

    // MARK: - Group + card scaffolding

    /// A System Settings–style group: a small uppercase header, a rounded card
    /// of hairline-separated rows, and an optional explanatory caption beneath.
    private func settingsGroup(title: String, caption: String, rows: [NSView]) -> NSView {
        let group = NSStackView()
        group.orientation = .vertical
        group.alignment = .leading
        group.spacing = 8
        group.translatesAutoresizingMaskIntoConstraints = false

        let heading = trackedLabel(title.uppercased(), size: 11, weight: .semibold, color: .tertiaryLabelColor, kern: 0.9)
        let headingWrap = NSView()
        headingWrap.translatesAutoresizingMaskIntoConstraints = false
        heading.translatesAutoresizingMaskIntoConstraints = false
        headingWrap.addSubview(heading)
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: headingWrap.leadingAnchor, constant: 4),
            heading.trailingAnchor.constraint(lessThanOrEqualTo: headingWrap.trailingAnchor),
            heading.topAnchor.constraint(equalTo: headingWrap.topAnchor),
            heading.bottomAnchor.constraint(equalTo: headingWrap.bottomAnchor)
        ])
        group.addArrangedSubview(headingWrap)

        let card = roundedContainer(radius: CatLabUI.cardRadius, fill: CatLabUI.cardFill, border: CatLabUI.hairline)
        card.translatesAutoresizingMaskIntoConstraints = false

        let rowsStack = NSStackView()
        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.distribution = .fill
        rowsStack.spacing = 0
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(rowsStack)
        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            rowsStack.topAnchor.constraint(equalTo: card.topAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])

        for (index, row) in rows.enumerated() {
            if index > 0 {
                let separator = hairline()
                rowsStack.addArrangedSubview(separator)
                separator.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
            }
            rowsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
        }

        group.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: group.widthAnchor).isActive = true

        if !caption.isEmpty {
            let captionLabel = label(caption, size: 11.5, weight: .regular, color: .tertiaryLabelColor)
            captionLabel.lineBreakMode = .byWordWrapping
            captionLabel.maximumNumberOfLines = 0
            let captionWrap = NSView()
            captionWrap.translatesAutoresizingMaskIntoConstraints = false
            captionLabel.translatesAutoresizingMaskIntoConstraints = false
            captionWrap.addSubview(captionLabel)
            NSLayoutConstraint.activate([
                captionLabel.leadingAnchor.constraint(equalTo: captionWrap.leadingAnchor, constant: 4),
                captionLabel.trailingAnchor.constraint(equalTo: captionWrap.trailingAnchor, constant: -4),
                captionLabel.topAnchor.constraint(equalTo: captionWrap.topAnchor),
                captionLabel.bottomAnchor.constraint(equalTo: captionWrap.bottomAnchor)
            ])
            group.addArrangedSubview(captionWrap)
            captionWrap.widthAnchor.constraint(equalTo: group.widthAnchor).isActive = true
        }

        return group
    }

    private func paddedRow(_ content: NSView, top: CGFloat = 13, bottom: CGFloat = 13) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: CatLabUI.rowInsetH),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -CatLabUI.rowInsetH),
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: top),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -bottom)
        ])
        return container
    }

    /// A hairline separator inset from the leading edge, the way grouped rows
    /// are divided in System Settings.
    private func hairline() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = CatLabUI.hairline.cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: CatLabUI.rowInsetH),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func roundedContainer(radius: CGFloat, fill: NSColor, border: NSColor) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.cornerCurve = .continuous
        view.layer?.backgroundColor = fill.cgColor
        view.layer?.borderColor = border.cgColor
        view.layer?.borderWidth = 1
        return view
    }

    private func statusPill(_ title: String, color: NSColor) -> NSView {
        let pill = roundedContainer(radius: 9, fill: CatLabUI.cardFill, border: CatLabUI.hairline)
        pill.translatesAutoresizingMaskIntoConstraints = false

        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 3.5
        dot.layer?.backgroundColor = color.cgColor
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 7).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 7).isActive = true

        let text = label(title, size: 11, weight: .semibold, color: .secondaryLabelColor)
        text.translatesAutoresizingMaskIntoConstraints = false

        let content = NSStackView(views: [dot, text])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 6
        content.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 11),
            content.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -11),
            content.topAnchor.constraint(equalTo: pill.topAnchor, constant: 8),
            content.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -8)
        ])
        return pill
    }

    private func titledText(_ title: String, subtitle: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        let titleLabel = label(title, size: 13, weight: .medium, color: .labelColor)
        let subtitleLabel = label(subtitle, size: 11, weight: .regular, color: .secondaryLabelColor)
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 2
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }

    private func label(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.isSelectable = false
        return label
    }

    private func trackedLabel(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, kern: CGFloat) -> NSTextField {
        let field = NSTextField(labelWithString: string)
        field.isSelectable = false
        field.attributedStringValue = NSAttributedString(string: string, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .kern: kern
        ])
        return field
    }

    private func constrainWidth(_ view: NSView, to stack: NSStackView) {
        view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -CatLabUI.hInset * 2).isActive = true
    }

    // MARK: - State

    private func syncControls() {
        let variantIndex = CatCompanionSettings.variantOptions.firstIndex { $0.key == settings.variant } ?? 0
        variantPopup.selectItem(at: variantIndex)
        sliders["stripeAmount"]?.doubleValue = settings.stripeAmount
        sliders["furLength"]?.doubleValue = settings.furLength
        sliders["chubbiness"]?.doubleValue = settings.chubbiness
        sliders["sizePoints"]?.doubleValue = settings.sizePoints
        sliders["activity"]?.doubleValue = settings.activity
        sliders["curiosity"]?.doubleValue = settings.curiosity
        sliders["playfulness"]?.doubleValue = settings.playfulness
        mouseSwitch.state = settings.mouseReactions ? .on : .off
        purrSwitch.state = settings.purringEnabled ? .on : .off
        updateValueLabels()
        pushVisualizerConfiguration()
    }

    @objc private func controlChanged() {
        settings.variant = CatCompanionSettings.variantOptions[variantPopup.indexOfSelectedItem].key
        settings.stripeAmount = sliders["stripeAmount"]?.doubleValue ?? settings.stripeAmount
        settings.furLength = sliders["furLength"]?.doubleValue ?? settings.furLength
        settings.chubbiness = sliders["chubbiness"]?.doubleValue ?? settings.chubbiness
        settings.sizePoints = sliders["sizePoints"]?.doubleValue ?? settings.sizePoints
        settings.activity = sliders["activity"]?.doubleValue ?? settings.activity
        settings.curiosity = sliders["curiosity"]?.doubleValue ?? settings.curiosity
        settings.playfulness = sliders["playfulness"]?.doubleValue ?? settings.playfulness
        settings.mouseReactions = mouseSwitch.state == .on
        settings.purringEnabled = purrSwitch.state == .on
        settings.save()
        updateValueLabels()
        pushVisualizerConfiguration()
    }

    @objc private func resetDefaults() {
        settings = CatCompanionSettings()
        settings.save()
        syncControls()
    }

    private func updateValueLabels() {
        valueLabels["stripeAmount"]?.stringValue = String(format: "%.0f%%", settings.stripeAmount / 1.5 * 100)
        valueLabels["furLength"]?.stringValue = String(format: "%.0f%%", (settings.furLength - 1.23) / 0.57 * 100)
        valueLabels["chubbiness"]?.stringValue = String(format: "%.0f%%", (settings.chubbiness - 0.8) / 0.5 * 100)
        valueLabels["sizePoints"]?.stringValue = String(format: "%.0f pt", settings.sizePoints)
        valueLabels["activity"]?.stringValue = String(format: "%.0f%%", settings.activity * 100)
        valueLabels["curiosity"]?.stringValue = String(format: "%.0f%%", settings.curiosity * 100)
        valueLabels["playfulness"]?.stringValue = String(format: "%.0f%%", settings.playfulness * 100)
    }

    private func pushVisualizerConfiguration() {
        guard let data = try? JSONSerialization.data(withJSONObject: [
            "activity": settings.activity,
            "curiosity": settings.curiosity,
            "playfulness": settings.playfulness,
            "mouseReactions": settings.mouseReactions,
            "purringEnabled": settings.purringEnabled,
            "furLength": settings.furLength,
            "chubbiness": settings.chubbiness,
            "stripeAmount": settings.stripeAmount
        ]),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }
        visualizerWebView?.evaluateJavaScript("window.catBrainBridge && window.catBrainBridge.configure(\(json))")
    }

}
