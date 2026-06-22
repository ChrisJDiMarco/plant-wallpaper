import AppKit
import PlantGardenCore
import ServiceManagement

@MainActor
final class GardenSettingsWindowController: NSWindowController {
    struct Actions {
        var applyScene: (String) -> Void
        var applySceneWithSettings: (String, GardenSettings?) -> Void
        var chooseWallpaper: () -> Void
        var createAIWallpaper: () -> Void
        var generateSceneEdit: (String, @escaping (Result<Void, Error>) -> Void) -> Void
        var openAPIKeySettings: () -> Void
        var reapplyScene: () -> Void
        var restorePreviousWallpaper: () -> Void
        var resetGarden: () -> Void
        var deleteAllPlantsInScene: () -> Void
        var arrangeGarden: () -> Void
        var showWelcomeTour: () -> Void
        var saveHealthCheck: () -> Void
    }

    struct SidebarStyleSnapshot: Equatable {
        let sidebarWidth: CGFloat
        let rowHeight: CGFloat
        let rowCornerRadius: CGFloat
        let iconWellSize: CGFloat
        let iconWellCornerRadius: CGFloat
        let selectedBackgroundAlpha: CGFloat
        let selectedAccentWidth: CGFloat
    }

    private enum Section: CaseIterable {
        case garden
        case general
        case scene
        case wildlife
        case gnomes
        case audio
        case privacyStorage
        case assets
        case advanced
        case about

        var title: String {
            switch self {
            case .garden:
                "My Garden"
            case .general:
                "General"
            case .scene:
                "Scene"
            case .wildlife:
                "Wildlife"
            case .gnomes:
                "Gnomes"
            case .audio:
                "Audio"
            case .privacyStorage:
                "Privacy & Storage"
            case .assets:
                "Assets"
            case .advanced:
                "Advanced"
            case .about:
                "About"
            }
        }

        var subtitle: String {
            switch self {
            case .garden:
                "Today's garden at a glance - vitality, care, pantry, and diary"
            case .general:
                "Simulation, care, and startup defaults"
            case .scene:
                "Wallpaper scenes and generated environments"
            case .wildlife:
                "Butterflies, flies, and ambient motion"
            case .gnomes:
                "Tiny society controls, building pace, plant curiosity, and village density"
            case .audio:
                "Garden ambience, radio companions, and playback"
            case .privacyStorage:
                "AI usage, time-lapse capture, disk space, and local data"
            case .assets:
                "Plant artwork, generated wallpapers, and API keys"
            case .advanced:
                "Data, reset, and maintenance actions"
            case .about:
                "Version, credits, and the story so far"
            }
        }

        var symbolName: String {
            switch self {
            case .garden:
                "leaf.fill"
            case .general:
                "slider.horizontal.3"
            case .scene:
                "photo.stack.fill"
            case .wildlife:
                "ladybug.fill"
            case .gnomes:
                "figure.2.and.child.holdinghands"
            case .audio:
                "radio.fill"
            case .privacyStorage:
                "lock.shield.fill"
            case .assets:
                "shippingbox.fill"
            case .advanced:
                "wrench.and.screwdriver.fill"
            case .about:
                "info.circle.fill"
            }
        }
    }

    private enum SliderID: String {
        case growthSpeed
        case waterUse
        case defaultScale
        case wildlifeDensity
        case wildlifeSpeed
        case bugSize
        case birdCount
        case gnomePopulation
        case gnomeTribeSize
        case gnomeLiveliness
        case gnomeBuildingSpeed
        case gnomeCooperation
        case gnomePlantInteraction
        case gnomeVillageDetail
        case gnomeSettlementPace
        case musicVolume
        case radioCompanionScale
        case ambientVolume
        case plantDarkening

        var defaultValue: Double {
            switch self {
            case .growthSpeed, .waterUse, .defaultScale, .wildlifeDensity, .wildlifeSpeed, .bugSize, .birdCount,
                 .radioCompanionScale, .gnomePopulation, .gnomeTribeSize, .gnomeLiveliness, .gnomeBuildingSpeed,
                 .gnomeCooperation, .gnomePlantInteraction, .gnomeVillageDetail:
                1.0
            case .gnomeSettlementPace:
                GnomeTribeSettlementPlan.defaultExpansionDurationDays
            case .musicVolume:
                1.0
            case .ambientVolume:
                0.35
            case .plantDarkening:
                0
            }
        }
    }

    private enum Layout {
        static let sidebarWidth: CGFloat = 224
        static let sidebarTopInset: CGFloat = 66
        static let sidebarHorizontalInset: CGFloat = 14
        static let sidebarRowHeight: CGFloat = 36
        static let sidebarRowCornerRadius: CGFloat = 10
        static let sidebarIconWellSize: CGFloat = 26
        static let sidebarIconWellCornerRadius: CGFloat = 7
        static let sidebarSelectedBackgroundAlpha: CGFloat = 0.14
        static let sidebarSelectedAccentWidth: CGFloat = 3
        static let contentMaxWidth: CGFloat = 660
        static let contentInset: CGFloat = 30
        static let rowHorizontalPadding: CGFloat = 14
        static let rowVerticalPadding: CGFloat = 11
    }

    /// Content container that closes the window on Escape.
    private final class EscapeClosingView: NSView {
        override func cancelOperation(_ sender: Any?) {
            window?.close()
        }
    }

    /// Top-anchored stack so scroll offsets behave intuitively.
    private final class FlippedStackView: NSStackView {
        override var isFlipped: Bool {
            true
        }
    }

    private final class SidebarNavigationButton: NSButton {
        private let itemTitle: String
        private let symbolName: String
        private var isHovered = false {
            didSet {
                needsDisplay = true
            }
        }

        var isSelectedRow = false {
            didSet {
                needsDisplay = true
            }
        }

        init(section: Section, target: AnyObject?, action: Selector?) {
            itemTitle = section.title
            symbolName = section.symbolName
            super.init(frame: .zero)
            self.target = target
            self.action = action
            identifier = NSUserInterfaceItemIdentifier(section.title)
            toolTip = section.subtitle
            isBordered = false
            setButtonType(.momentaryChange)
            focusRingType = .none
            translatesAutoresizingMaskIntoConstraints = false
            heightAnchor.constraint(equalToConstant: Layout.sidebarRowHeight).isActive = true
            setAccessibilityLabel(section.title)
        }

        required init?(coder: NSCoder) {
            nil
        }

        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: Layout.sidebarRowHeight)
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(
                rect: bounds,
                options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
                owner: self
            ))
        }

        override func mouseEntered(with event: NSEvent) {
            isHovered = true
        }

        override func mouseExited(with event: NSEvent) {
            isHovered = false
        }

        override func draw(_ dirtyRect: NSRect) {
            let rowRect = bounds.insetBy(dx: 0, dy: 1)
            drawSelection(in: rowRect)
            drawIconWell(in: rowRect)
            drawTitle(in: rowRect)
        }

        private func drawSelection(in rowRect: NSRect) {
            let rowPath = NSBezierPath(
                roundedRect: rowRect,
                xRadius: Layout.sidebarRowCornerRadius,
                yRadius: Layout.sidebarRowCornerRadius
            )

            if isSelectedRow {
                let alpha = window?.isKeyWindow == false
                    ? Layout.sidebarSelectedBackgroundAlpha * 0.72
                    : Layout.sidebarSelectedBackgroundAlpha
                NSColor.controlAccentColor.withAlphaComponent(alpha).setFill()
                rowPath.fill()

                let accentRect = NSRect(
                    x: rowRect.minX,
                    y: rowRect.midY - 10,
                    width: Layout.sidebarSelectedAccentWidth,
                    height: 20
                )
                NSColor.controlAccentColor.withAlphaComponent(0.82).setFill()
                NSBezierPath(
                    roundedRect: accentRect,
                    xRadius: Layout.sidebarSelectedAccentWidth / 2,
                    yRadius: Layout.sidebarSelectedAccentWidth / 2
                ).fill()
                return
            }

            if isHovered || isHighlighted {
                NSColor.labelColor.withAlphaComponent(isHighlighted ? 0.10 : 0.055).setFill()
                rowPath.fill()
            }
        }

        private func drawIconWell(in rowRect: NSRect) {
            let iconWellRect = NSRect(
                x: rowRect.minX + 12,
                y: rowRect.midY - Layout.sidebarIconWellSize / 2,
                width: Layout.sidebarIconWellSize,
                height: Layout.sidebarIconWellSize
            )
            let wellPath = NSBezierPath(
                roundedRect: iconWellRect,
                xRadius: Layout.sidebarIconWellCornerRadius,
                yRadius: Layout.sidebarIconWellCornerRadius
            )
            if isSelectedRow {
                NSColor.controlAccentColor.withAlphaComponent(0.16).setFill()
            } else {
                NSColor.controlBackgroundColor.withAlphaComponent(0.72).setFill()
            }
            wellPath.fill()

            NSColor.separatorColor.withAlphaComponent(isSelectedRow ? 0.28 : 0.18).setStroke()
            wellPath.lineWidth = 0.75
            wellPath.stroke()

            guard let symbol = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: itemTitle
            )?.withSymbolConfiguration(NSImage.SymbolConfiguration(
                pointSize: 13,
                weight: isSelectedRow ? .semibold : .medium
            )) else {
                return
            }

            let symbolRect = NSRect(
                x: iconWellRect.midX - symbol.size.width / 2,
                y: iconWellRect.midY - symbol.size.height / 2,
                width: symbol.size.width,
                height: symbol.size.height
            )
            draw(symbol: symbol, in: symbolRect, tint: isSelectedRow ? .controlAccentColor : .secondaryLabelColor)
        }

        private func drawTitle(in rowRect: NSRect) {
            let font = NSFont.systemFont(ofSize: 13, weight: isSelectedRow ? .semibold : .regular)
            let titleColor: NSColor = isSelectedRow ? .labelColor : .secondaryLabelColor
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: titleColor
            ]
            let titleSize = itemTitle.size(withAttributes: attributes)
            let titleRect = NSRect(
                x: rowRect.minX + 48,
                y: rowRect.midY - titleSize.height / 2,
                width: max(0, rowRect.width - 58),
                height: titleSize.height
            )
            itemTitle.draw(in: titleRect, withAttributes: attributes)
        }

        private func draw(symbol: NSImage, in rect: NSRect, tint: NSColor) {
            NSGraphicsContext.saveGraphicsState()
            symbol.draw(in: rect)
            tint.setFill()
            rect.fill(using: .sourceAtop)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private let store: GardenStore
    private let wallpaperManager: WallpaperManager
    private let actions: Actions

    private let sidebarStack = NSStackView()
    private let contentScrollView = NSScrollView()
    private var selectedSection: Section = .garden
    private var sectionButtons: [Section: SidebarNavigationButton] = [:]

    /// Closures that push current model values into already-built controls.
    /// Re-run on every store change; rebuilt when a section is rendered.
    private var dynamicUpdates: [() -> Void] = []
    private var saveDebounceTimer: Timer?
    private var uiRefreshTimer: Timer?
    private var storeObserver: NSObjectProtocol?
    private var windowLifecycleDelegate: MainActorWindowDelegate?
    private var spotifyTextFieldDelegate: MainActorTextFieldDelegate?
    private var renderedMusicSource: GardenMusicSource?
    private var renderedCustomSceneKeys: [String] = []
    private var sceneDetailController: GardenSceneDetailWindowController?
    private weak var spotifyURLTextField: NSTextField?
    private weak var radioAssignmentCompanionPopup: NSPopUpButton?
    private weak var radioAssignmentSearchField: NSSearchField?
    private weak var radioAssignmentResultsPopup: NSPopUpButton?
    private weak var radioAssignmentCustomNameField: NSTextField?
    private weak var radioAssignmentCustomURLField: NSTextField?
    private weak var radioAssignmentStatusLabel: NSTextField?
    private var radioAssignmentSearchResults: [GardenRadioStream] = []
    private var didShowOnce = false

    private var currentRadioCompanion: GardenRadioCompanion {
        store.state.musicButton?.companion ?? .gardenCat
    }

    private var currentRadioStream: GardenRadioStream {
        currentRadioCompanion.stationStream(in: store.state.settings)
    }

    init(store: GardenStore, wallpaperManager: WallpaperManager, actions: Actions) {
        self.store = store
        self.wallpaperManager = wallpaperManager
        self.actions = actions

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Plant Wallpaper Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 800, height: 560)
        window.setFrameAutosaveName("GardenSettingsWindow")

        super.init(window: window)
        let windowLifecycleDelegate = MainActorWindowDelegate { [weak self] _ in
            self?.windowWillClose()
        }
        self.windowLifecycleDelegate = windowLifecycleDelegate
        window.delegate = windowLifecycleDelegate
        buildWindow()
        renderSelectedSection()

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

    required init?(coder: NSCoder) {
        nil
    }

    func showCentered() {
        guard let window else {
            return
        }

        renderSelectedSection()
        if !didShowOnce {
            didShowOnce = true
            if !window.setFrameUsingName("GardenSettingsWindow") {
                window.center()
            }
        }
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        startUIRefreshTimer()
    }

    func showPrivacyStorageSection() {
        selectedSection = .privacyStorage
        showCentered()
    }

    func sectionTitlesForSelfTest() -> [String] {
        Section.allCases.map(\.title)
    }

    func sidebarStyleSnapshotForSelfTest() -> SidebarStyleSnapshot {
        SidebarStyleSnapshot(
            sidebarWidth: Layout.sidebarWidth,
            rowHeight: Layout.sidebarRowHeight,
            rowCornerRadius: Layout.sidebarRowCornerRadius,
            iconWellSize: Layout.sidebarIconWellSize,
            iconWellCornerRadius: Layout.sidebarIconWellCornerRadius,
            selectedBackgroundAlpha: Layout.sidebarSelectedBackgroundAlpha,
            selectedAccentWidth: Layout.sidebarSelectedAccentWidth
        )
    }

    func wildlifeControlTitlesForSelfTest() -> [String] {
        ["Show Animated Bugs", "Bug count", "Bug size", "Flight speed", "Bird count", "Open cat chat on click"]
    }

    func gnomeControlTitlesForSelfTest() -> [String] {
        [
            "Gnome societies",
            "Population",
            "Tribe size",
            "Life-like behavior",
            "Building speed",
            "Settlement timeframe",
            "Cooperation",
            "Plant curiosity",
            "Village detail",
            "Active zones"
        ]
    }

    func generalControlTitlesForSelfTest() -> [String] {
        [
            "Launch at login",
            "Show Jarvis in main menu",
            "AI lock view",
            "Screensaver",
            "Pause growth",
            "Cozy mode",
            "Growth speed",
            "Water use",
            "New plant size",
            "Plant mature versions",
            "Auto low-power on battery",
            "Decorative garden preset",
            "Sync with local weather",
            "Current conditions"
        ]
    }

    func privacyStorageControlTitlesForSelfTest() -> [String] {
        [
            "Status",
            "Issues",
            "Next action",
            "Desktop click behavior",
            "Wallpaper generation quality",
            "Wallpaper edit strength",
            "Cost and credits",
            "OpenAI API key",
            "ElevenLabs API key"
        ]
    }

    /// Renders every section and reports how many live-updating controls each
    /// one registered. Exercises the full view-building path for all panes.
    func renderAllSectionsForSelfTest() -> [String: Int] {
        let originalSection = selectedSection
        defer {
            selectedSection = originalSection
            renderSelectedSection()
        }

        var dynamicControlCounts: [String: Int] = [:]
        for section in Section.allCases {
            selectedSection = section
            renderSelectedSection()
            dynamicControlCounts[section.title] = dynamicUpdates.count
        }
        return dynamicControlCounts
    }

    // MARK: - Window lifecycle

    private func windowWillClose() {
        stopUIRefreshTimer()
        flushPendingSettingsSave()
    }

    private func startUIRefreshTimer() {
        guard uiRefreshTimer == nil else {
            return
        }

        // Keeps non-store-driven status fresh (radio playback, keychain, login item).
        uiRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshDynamicContent()
            }
        }
        uiRefreshTimer?.tolerance = 0.5
    }

    private func stopUIRefreshTimer() {
        uiRefreshTimer?.invalidate()
        uiRefreshTimer = nil
    }

    private func storeDidChange() {
        guard window?.isVisible == true else {
            return
        }

        refreshDynamicContent()
    }

    // MARK: - Window structure

    private func buildWindow() {
        guard let window else {
            return
        }

        let rootView = EscapeClosingView()
        window.contentView = rootView

        let sidebarBackground = NSVisualEffectView()
        sidebarBackground.material = .sidebar
        sidebarBackground.blendingMode = .behindWindow
        sidebarBackground.state = .followsWindowActiveState
        sidebarBackground.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(sidebarBackground)

        sidebarStack.orientation = .vertical
        sidebarStack.alignment = .leading
        sidebarStack.spacing = 4
        sidebarStack.edgeInsets = NSEdgeInsets(
            top: Layout.sidebarTopInset,
            left: Layout.sidebarHorizontalInset,
            bottom: 44,
            right: Layout.sidebarHorizontalInset
        )
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        sidebarBackground.addSubview(sidebarStack)

        for section in Section.allCases {
            let button = sidebarButton(for: section)
            sectionButtons[section] = button
            sidebarStack.addArrangedSubview(button)
            button.leadingAnchor.constraint(equalTo: sidebarStack.leadingAnchor).isActive = true
            button.trailingAnchor.constraint(equalTo: sidebarStack.trailingAnchor).isActive = true
        }

        let versionLabel = NSTextField(labelWithString: Self.appVersionDescription)
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .tertiaryLabelColor
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        sidebarBackground.addSubview(versionLabel)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(divider)

        contentScrollView.drawsBackground = false
        contentScrollView.hasVerticalScroller = true
        contentScrollView.autohidesScrollers = true
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(contentScrollView)

        NSLayoutConstraint.activate([
            sidebarBackground.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            sidebarBackground.topAnchor.constraint(equalTo: rootView.topAnchor),
            sidebarBackground.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            sidebarBackground.widthAnchor.constraint(equalToConstant: Layout.sidebarWidth),

            sidebarStack.leadingAnchor.constraint(equalTo: sidebarBackground.leadingAnchor),
            sidebarStack.trailingAnchor.constraint(equalTo: sidebarBackground.trailingAnchor),
            sidebarStack.topAnchor.constraint(equalTo: sidebarBackground.topAnchor),
            sidebarStack.bottomAnchor.constraint(lessThanOrEqualTo: sidebarBackground.bottomAnchor),

            versionLabel.leadingAnchor.constraint(
                equalTo: sidebarBackground.leadingAnchor,
                constant: Layout.sidebarHorizontalInset + 12
            ),
            versionLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: sidebarBackground.trailingAnchor,
                constant: -(Layout.sidebarHorizontalInset + 12)
            ),
            versionLabel.bottomAnchor.constraint(equalTo: sidebarBackground.bottomAnchor, constant: -12),

            divider.leadingAnchor.constraint(equalTo: sidebarBackground.trailingAnchor),
            divider.topAnchor.constraint(equalTo: rootView.topAnchor),
            divider.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            contentScrollView.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            contentScrollView.topAnchor.constraint(equalTo: rootView.topAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])
    }

    private static var appVersionDescription: String {
        let name = "Plant Wallpaper"
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return name
        }

        return "\(name) \(version)"
    }

    // MARK: - Sidebar

    private func sidebarButton(for section: Section) -> SidebarNavigationButton {
        SidebarNavigationButton(section: section, target: self, action: #selector(selectSection(_:)))
    }

    private func updateSidebarSelection() {
        for (section, button) in sectionButtons {
            button.isSelectedRow = section == selectedSection
        }
    }

    @objc private func selectSection(_ sender: NSButton) {
        guard let section = Section.allCases.first(where: { $0.title == sender.identifier?.rawValue }),
              section != selectedSection else {
            updateSidebarSelection()
            return
        }

        selectedSection = section
        renderSelectedSection()
    }

    // MARK: - Section rendering

    private func renderSelectedSection(preservingScroll: Bool = false) {
        let savedScrollOrigin = contentScrollView.contentView.bounds.origin

        updateSidebarSelection()
        dynamicUpdates.removeAll()
        spotifyURLTextField = nil
        renderedMusicSource = nil
        renderedCustomSceneKeys = []

        let stack = FlippedStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.edgeInsets = NSEdgeInsets(
            top: 52,
            left: Layout.contentInset,
            bottom: Layout.contentInset,
            right: Layout.contentInset
        )
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(sectionHeader(selectedSection))

        switch selectedSection {
        case .garden:
            buildGardenSection(in: stack)
        case .general:
            buildGeneralSection(in: stack)
        case .scene:
            buildSceneSection(in: stack)
        case .wildlife:
            buildWildlifeSection(in: stack)
        case .gnomes:
            buildGnomeSection(in: stack)
        case .audio:
            buildAudioSection(in: stack)
        case .privacyStorage:
            buildPrivacyStorageSection(in: stack)
        case .assets:
            buildAssetsSection(in: stack)
        case .advanced:
            buildAdvancedSection(in: stack)
        case .about:
            buildAboutSection(in: stack)
        }

        contentScrollView.documentView = stack

        // A quick fade makes section switches feel intentional instead of
        // an instant content swap. Scroll-preserving refreshes skip it.
        if !preservingScroll && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            stack.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                stack.animator().alphaValue = 1
            }
        }
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalTo: contentScrollView.contentView.widthAnchor),
            stack.topAnchor.constraint(equalTo: contentScrollView.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentScrollView.contentView.leadingAnchor)
        ])

        if preservingScroll {
            contentScrollView.layoutSubtreeIfNeeded()
            stack.scroll(savedScrollOrigin)
        }

        refreshDynamicContent()
    }

    /// Pushes fresh model values into existing controls without rebuilding the
    /// view tree, so scroll position and keyboard focus survive. Falls back to a
    /// structural re-render when the section's layout itself must change.
    private func refreshDynamicContent() {
        if selectedSection == .audio,
           let renderedMusicSource,
           renderedMusicSource != store.state.settings.musicSource {
            renderSelectedSection(preservingScroll: true)
            return
        }

        if selectedSection == .scene,
           renderedCustomSceneKeys != wallpaperManager.customWallpapers.map(\.key) {
            renderSelectedSection(preservingScroll: true)
            return
        }

        for update in dynamicUpdates {
            update()
        }
    }

    private func registerUpdate(_ update: @escaping () -> Void) {
        dynamicUpdates.append(update)
        update()
    }

    // MARK: - Sections

    private func buildGardenSection(in stack: NSStackView) {
        // Live preview of the actual desktop garden, so settings opens with
        // your garden looking back at you.
        if let previewImage = gardenPreviewImage() {
            let imageView = NSImageView(image: previewImage)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 12
            imageView.layer?.cornerCurve = .continuous
            imageView.layer?.masksToBounds = true
            imageView.layer?.borderWidth = 1
            imageView.layer?.borderColor = NSColor.separatorColor.cgColor
            imageView.translatesAutoresizingMaskIntoConstraints = false
            let aspect = previewImage.size.height / max(1, previewImage.size.width)
            imageView.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.contentMaxWidth - Layout.contentInset).isActive = true
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: aspect).isActive = true
            stack.addArrangedSubview(imageView)
            imageView.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -(Layout.contentInset * 2)).isActive = true
        }

        stack.addArrangedSubview(gardenStatTiles())

        addGroup(title: "Next Up", to: stack, rows: [
            infoRow(title: "Harvest", value: { [weak self] in
                guard let self else {
                    return ""
                }
                return GardenGameLoopInsights(
                    state: self.store.state,
                    sceneKey: self.wallpaperManager.selectedWallpaperSceneKey
                ).harvest.summary
            }),
            infoRow(title: "Seeds", value: { [weak self] in
                guard let self else {
                    return ""
                }
                return GardenGameLoopInsights(
                    state: self.store.state,
                    sceneKey: self.wallpaperManager.selectedWallpaperSceneKey
                ).seeds.summary
            }),
            infoRow(title: "Focus", value: { [weak self] in
                guard let self else {
                    return ""
                }
                let insights = GardenGameLoopInsights(
                    state: self.store.state,
                    sceneKey: self.wallpaperManager.selectedWallpaperSceneKey
                )
                return insights.focus.isActive
                    ? insights.focus.statusSummary
                    : insights.focus.milestoneSummary
            }),
            infoRow(title: "Weather", value: { [weak self] in
                guard let self else {
                    return ""
                }
                return GardenGameLoopInsights(
                    state: self.store.state,
                    sceneKey: self.wallpaperManager.selectedWallpaperSceneKey
                ).weather.summary
            }),
            infoRow(title: "Arrange", value: { [weak self] in
                guard let self else {
                    return ""
                }
                let insight = GardenGameLoopInsights(
                    state: self.store.state,
                    sceneKey: self.wallpaperManager.selectedWallpaperSceneKey
                ).arrangement
                return "\(insight.strategyTitle) - \(insight.summary)"
            })
        ])

        let thirstyCount = store.state.thirstyPlants.count
        let readyCropCount = store.state.plants.filter(\.isHarvestReady).count
        var careRows: [NSView] = [
            buttonRow(
                title: "Water thirsty plants",
                buttonTitle: "Water",
                action: #selector(waterThirstyPlants),
                subtitle: { [weak self] in
                    let count = self?.store.state.thirstyPlants.count ?? 0
                    return count == 0 ? "All plants are hydrated." : "\(count) currently need water."
                },
                isEnabled: { [weak self] in !(self?.store.state.thirstyPlants.isEmpty ?? true) }
            )
        ]
        if readyCropCount > 0 {
            careRows.append(buttonRow(
                title: "Harvest ready crops",
                buttonTitle: "Harvest",
                action: #selector(harvestReadyCrops),
                subtitle: { [weak self] in
                    let count = self?.store.state.plants.filter(\.isHarvestReady).count ?? 0
                    return count == 0
                        ? "Nothing is ready right now."
                        : "\(count) edible plant\(count == 1 ? " is" : "s are") ready to pick."
                },
                isEnabled: { [weak self] in
                    self?.store.state.plants.contains(where: \.isHarvestReady) ?? false
                }
            ))
        }
        careRows.append(infoRow(title: "Recommendation", value: { [weak self] in
            self?.store.state.careRecommendation.summary ?? ""
        }))
        addGroup(title: thirstyCount > 0 || readyCropCount > 0 ? "Needs You" : "Care", to: stack, rows: careRows)

        let journalEntries = store.journal?.recentEntries(limit: 7) ?? []
        if journalEntries.isEmpty {
            addGroup(title: "Garden Diary", to: stack, rows: [
                infoRow(title: "No entries yet", value: { "Plant, harvest, or focus - the diary writes itself" })
            ])
        } else {
            addGroup(
                title: "Garden Diary",
                to: stack,
                rows: journalEntries.map { journalRow(for: $0) }
            )
        }

        addGroup(title: "Keepsakes", to: stack, rows: [
            buttonRow(
                title: "Garden time-lapse",
                buttonTitle: "Export...",
                action: #selector(exportTimeLapse),
                subtitle: { "One frame is saved each day - export them as a movie." }
            )
        ])
    }

    private func gardenPreviewImage() -> NSImage? {
        guard let screen = NSScreen.main ?? NSScreen.screens.first,
              let bitmap = try? GardenDesktopSnapshotRenderer.makeSnapshotBitmap(
                store: store,
                screen: screen,
                screenIndex: NSScreen.screens.firstIndex(of: screen) ?? 0,
                wallpaperImageURL: wallpaperManager.currentWallpaperImageURL
              ) else {
            return nil
        }

        let image = NSImage(size: NSSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
        image.addRepresentation(bitmap)
        return image
    }

    private func gardenStatTiles() -> NSView {
        let state = store.state
        let vitality = state.vitality(at: Date())
        let gardenAgeDays = max(1, Int(Date().timeIntervalSince(state.createdAt) / 86_400) + 1)
        let livingPlantCount = state.plants.filter { !$0.isDead }.count
        let totalHarvests = state.harvestTally.values.reduce(0, +)
        let totalSeeds = state.seedInventory.values.reduce(0, +)
        let focusMinutes = state.focusStats?.totalFocusMinutes ?? 0

        let ring = VitalityRingView(progress: CGFloat(vitality.percentScore) / 100)
        ring.widthAnchor.constraint(equalToConstant: 74).isActive = true
        ring.heightAnchor.constraint(equalToConstant: 74).isActive = true

        let ringColumn = NSStackView(views: [ring, smallLabel("Vitality")])
        ringColumn.orientation = .vertical
        ringColumn.alignment = .centerX
        ringColumn.spacing = 4

        var tiles: [NSView] = [ringColumn]
        for (value, caption) in [
            ("\(livingPlantCount)", "Plants"),
            ("Day \(gardenAgeDays)", "Garden age"),
            ("\(focusMinutes)m", "Focused"),
            ("\(totalHarvests)", "Harvests"),
            ("\(totalSeeds)", "Seeds")
        ] {
            tiles.append(statTile(value: value, caption: caption))
        }

        let row = NSStackView(views: tiles)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 18
        row.distribution = .equalSpacing
        return row
    }

    private func statTile(value: String, caption: String) -> NSView {
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 21, weight: .semibold)
        let captionLabel = smallLabel(caption)

        let tile = NSStackView(views: [valueLabel, captionLabel])
        tile.orientation = .vertical
        tile.alignment = .centerX
        tile.spacing = 2
        return tile
    }

    private func journalRow(for entry: GardenJournalEntry) -> NSView {
        let icon = NSImageView()
        if let image = NSImage(systemSymbolName: entry.symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium)) {
            icon.image = image
            icon.contentTintColor = .secondaryLabelColor
        }
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let textLabel = NSTextField(labelWithString: entry.text)
        textLabel.font = .systemFont(ofSize: 12)
        textLabel.lineBreakMode = .byTruncatingTail

        let dateLabel = NSTextField(labelWithString: Self.relativeDateText(entry.date))
        dateLabel.font = .systemFont(ofSize: 11)
        dateLabel.textColor = .tertiaryLabelColor
        dateLabel.setContentHuggingPriority(.required, for: .horizontal)
        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        return rowContainer([icon, textLabel, NSView.spacer(), dateLabel])
    }

    private static func relativeDateText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// A small vitality donut, drawn in the garden's green.
    private final class VitalityRingView: NSView {
        private let progress: CGFloat

        init(progress: CGFloat) {
            self.progress = min(1, max(0, progress))
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            nil
        }

        override func draw(_ dirtyRect: NSRect) {
            let lineWidth: CGFloat = 7
            let rect = bounds.insetBy(dx: lineWidth / 2 + 1, dy: lineWidth / 2 + 1)
            let center = NSPoint(x: bounds.midX, y: bounds.midY)

            let track = NSBezierPath(ovalIn: rect)
            track.lineWidth = lineWidth
            NSColor.quaternaryLabelColor.setStroke()
            track.stroke()

            if progress > 0.001 {
                let arc = NSBezierPath()
                arc.appendArc(
                    withCenter: center,
                    radius: rect.width / 2,
                    startAngle: 90,
                    endAngle: 90 - 360 * progress,
                    clockwise: true
                )
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                NSColor.systemGreen.setStroke()
                arc.stroke()
            }

            let text = "\(Int((progress * 100).rounded()))%"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
            let size = (text as NSString).size(withAttributes: attributes)
            (text as NSString).draw(
                at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2),
                withAttributes: attributes
            )
        }
    }

    private func buildAboutSection(in stack: NSStackView) {
        addGroup(title: "Plant Wallpaper", to: stack, rows: [
            infoRow(title: "Version", value: { Self.appVersionDescription }),
            infoRow(title: "Species in the catalog", value: { "\(PlantSpecies.allCases.count)" }),
            infoRow(title: "Built-in scenes", value: { "\(GardenWallpaperScene.allCases.count)" }),
            infoRow(title: "Garden started", value: { [weak self] in
                guard let createdAt = self?.store.state.createdAt else {
                    return ""
                }
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                return formatter.string(from: createdAt)
            })
        ])

        addGroup(title: "Keepsakes", to: stack, rows: [
            buttonRow(
                title: "Save a share card",
                buttonTitle: "Save...",
                action: #selector(saveShareCardFromSettings),
                subtitle: { "A social-ready card with your garden's stats and best plants." }
            ),
            buttonRow(
                title: "Save garden health check",
                buttonTitle: "Save...",
                action: #selector(saveHealthCheckFromSettings),
                subtitle: { "Export a compact diagnostic summary for debugging." }
            ),
            buttonRow(
                title: "Replay welcome tour",
                buttonTitle: "Show",
                action: #selector(showWelcomeTourFromSettings),
                subtitle: { "See the click, drag, water, and focus tips again." }
            )
        ])

        let credits = NSTextField(wrappingLabelWithString: "A living garden for your desktop. Plants grow in real time, drink real rain, sleep at night, and remember exactly where you planted them.")
        credits.font = .systemFont(ofSize: 12)
        credits.textColor = .secondaryLabelColor
        stack.addArrangedSubview(credits)
        credits.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -(Layout.contentInset * 2)).isActive = true
    }

    private func buildGeneralSection(in stack: NSStackView) {
        addGroup(title: "Mode", to: stack, rows: [
            experienceModeRow(selectedMode: store.state.settings.experienceMode)
        ])

        addGroup(title: "Startup", to: stack, rows: [
            launchAtLoginRow(),
            switchRow(
                title: "Show Jarvis in main menu",
                subtitle: "Keep the Jarvis Assistant shortcut visible in the menubar dropdown.",
                action: #selector(toggleAssistantMenuItem(_:)),
                isOn: { [weak self] in self?.store.state.settings.isAssistantMenuItemEnabled ?? true }
            )
        ])

        addGroup(title: "Mac Desktop", to: stack, rows: [
            displayBehaviorRow(selectedBehavior: store.state.settings.displayBehavior),
            switchRow(
                title: "AI lock view",
                subtitle: "When interactions are locked, reuse the latest AI lock wallpaper or generate a fresh one from a clean Garden Snapshot.",
                action: #selector(toggleAIGeneratedLockSnapshot(_:)),
                isOn: { [weak self] in self?.store.state.settings.useAIGeneratedLockSnapshot ?? false }
            ),
            buttonRow(
                title: "Screensaver",
                buttonTitle: "Open",
                action: #selector(openScreenSaverSettings),
                subtitle: { Self.screenSaverStatusSummary() }
            )
        ])

        addGroup(title: "Simulation", to: stack, rows: [
            switchRow(
                title: "Pause growth",
                subtitle: "Freeze growth, thirst, health changes, and catch-up updates.",
                action: #selector(togglePaused(_:)),
                isOn: { [weak self] in self?.store.state.isPaused ?? false }
            ),
            switchRow(
                title: "Cozy mode",
                subtitle: "Plants keep growing gently, never die, and care becomes optional instead of urgent.",
                action: #selector(toggleCozyMode(_:)),
                isOn: { [weak self] in self?.store.state.settings.cozyModeEnabled ?? false }
            ),
            sliderRow(
                id: .growthSpeed,
                title: "Growth speed",
                subtitle: "How quickly plants move through growth stages.",
                min: 0.25,
                max: 4.0,
                value: { [weak self] in self?.store.state.settings.growthSpeedMultiplier ?? 1 }
            ),
            sliderRow(
                id: .waterUse,
                title: "Water use",
                subtitle: "How fast hydration drops between watering.",
                min: 0.25,
                max: 2.5,
                value: { [weak self] in self?.store.state.settings.waterUseMultiplier ?? 1 }
            ),
            sliderRow(
                id: .defaultScale,
                title: "New plant size",
                subtitle: "Default scale for plants you add from the menu.",
                min: 0.45,
                max: 2.25,
                value: { [weak self] in self?.store.state.settings.defaultPlantScale ?? 1 }
            ),
            switchRow(
                title: "Plant mature versions",
                subtitle: "New plants start at their fully grown artwork.",
                action: #selector(togglePlantNewPlantsAtMaturity(_:)),
                isOn: { [weak self] in self?.store.state.settings.plantNewPlantsAtMaturity ?? false }
            )
        ])

        addGroup(title: "Performance", to: stack, rows: [
            performanceModeRow(selectedMode: store.state.settings.performanceMode),
            switchRow(
                title: "Auto low-power on battery",
                subtitle: "Use calmer motion when your Mac is running on battery.",
                action: #selector(toggleAutoLowPower(_:)),
                isOn: { [weak self] in self?.store.state.settings.autoLowPowerOnBattery ?? true }
            ),
            buttonRow(
                title: "Decorative garden preset",
                buttonTitle: "Apply",
                action: #selector(applyDecorativeGardenPreset),
                subtitle: { "Low care, no death, fewer alerts, and quieter motion." }
            )
        ])

        addGroup(title: "Weather", to: stack, rows: [
            switchRow(
                title: "Sync with local weather",
                subtitle: "Rain waters plants, fog rolls in, snow slows growth. \(GardenWeatherService.privacySummary)",
                action: #selector(toggleWeatherSync(_:)),
                isOn: { [weak self] in self?.store.state.settings.isWeatherSyncEnabled ?? false }
            ),
            infoRow(title: "Current conditions", value: { [weak self] in
                guard let self else {
                    return ""
                }
                guard self.store.state.settings.isWeatherSyncEnabled else {
                    return "Off"
                }
                return self.store.state.weather?.summary ?? "Waiting for weather..."
            })
        ])

        addGroup(title: "Care", to: stack, rows: [
            buttonRow(
                title: "Water thirsty plants",
                buttonTitle: "Water",
                action: #selector(waterThirstyPlants),
                subtitle: { [weak self] in
                    let count = self?.store.state.thirstyPlants.count ?? 0
                    return count == 0 ? "All plants are hydrated." : "\(count) currently need water."
                },
                isEnabled: { [weak self] in !(self?.store.state.thirstyPlants.isEmpty ?? true) }
            ),
            buttonRow(
                title: "Water all plants",
                buttonTitle: "Water All",
                action: #selector(waterAll),
                subtitle: { [weak self] in "\(self?.store.state.plants.count ?? 0) plants in this scene." },
                isEnabled: { [weak self] in !(self?.store.state.plants.isEmpty ?? true) }
            ),
            buttonRow(
                title: "Smart arrange garden",
                buttonTitle: "Arrange",
                action: #selector(arrangeGarden),
                subtitle: { [weak self] in
                    guard let self else {
                        return ""
                    }
                    return GardenGameLoopInsights(
                        state: self.store.state,
                        sceneKey: self.wallpaperManager.selectedWallpaperSceneKey
                    ).arrangement.summary
                }
            ),
            infoRow(title: "Focus sessions", value: { [weak self] in
                guard let stats = self?.store.state.focusStats, stats.completedSessions > 0 else {
                    return "None yet - start one from the menu bar"
                }
                return "\(stats.completedSessions) completed, \(stats.totalFocusMinutes) min total"
            })
        ])
    }

    private func buildSceneSection(in stack: NSStackView) {
        renderedCustomSceneKeys = wallpaperManager.customWallpapers.map(\.key)

        stack.addArrangedSubview(sceneGalleryView())

        addGroup(title: "Current Scene", to: stack, rows: [
            infoRow(title: "Scene", value: { [weak self] in
                guard let self else {
                    return ""
                }
                let key = self.wallpaperManager.selectedWallpaperSceneKey
                return GardenWallpaperScene(rawValue: key)?.displayName
                    ?? self.wallpaperManager.customWallpapers.first { $0.key == key }?.displayName
                    ?? "Custom Scene"
            }),
            infoRow(title: "Environment", value: { [weak self] in
                GardenScenePlantEnvironment(sceneKey: self?.wallpaperManager.selectedWallpaperSceneKey).displayName
            }),
            infoRow(title: "Plants in scene", value: { [weak self] in
                "\(self?.store.state.plants.count ?? 0)"
            }),
            sliderRow(
                id: .plantDarkening,
                title: "Plant darkening",
                subtitle: "Manual extra shade for plants in this scene only.",
                min: 0,
                max: 0.60,
                value: { [weak self] in self?.store.state.manualPlantDarkening ?? 0 }
            )
        ])

        addGroup(title: "Wallpaper", to: stack, rows: [
            buttonRow(
                title: "Reapply current scene",
                buttonTitle: "Reapply",
                action: #selector(reapplyScene),
                subtitle: { "Refresh the desktop wallpaper render for the selected scene." }
            ),
            buttonRow(
                title: "Choose local wallpaper",
                buttonTitle: "Choose...",
                action: #selector(chooseWallpaper),
                subtitle: { "Import an image as a plantable custom scene." }
            ),
            buttonRow(
                title: "Create AI wallpaper",
                buttonTitle: "Create...",
                action: #selector(createAIWallpaper),
                subtitle: { "Generate a plant-free environment with clear planting areas." }
            ),
            buttonRow(
                title: "Restore previous wallpaper",
                buttonTitle: "Restore",
                action: #selector(restorePreviousWallpaper),
                subtitle: { "Return macOS desktops to their previous wallpaper images." }
            )
        ])

        let customWallpapers = wallpaperManager.customWallpapers
        if !customWallpapers.isEmpty {
            addGroup(
                title: "Your Scenes",
                to: stack,
                rows: customWallpapers.map { customSceneRow(for: $0) }
            )
        }
    }

    private func buildWildlifeSection(in stack: NSStackView) {
        addGroup(title: "Bugs & Butterflies", to: stack, rows: [
            switchRow(
                title: "Show Animated Bugs",
                subtitle: "Render ambient bees, butterflies, flies, fireflies, moths, and dragonflies around visible plants.",
                action: #selector(toggleWildlife(_:)),
                isOn: { [weak self] in self?.store.state.isEffectiveAmbientWildlifeEnabled ?? false }
            ),
            sliderRow(
                id: .wildlifeDensity,
                title: "Bug count",
                subtitle: "Controls how many live insects appear in the active scene.",
                min: 0.25,
                max: 3.0,
                value: { [weak self] in self?.store.state.settings.wildlifeDensityMultiplier ?? 1 }
            ),
            sliderRow(
                id: .bugSize,
                title: "Bug size",
                subtitle: "Scales the visible size of butterflies, bees, flies, moths, fireflies, and dragonflies.",
                min: 0.50,
                max: 2.0,
                value: { [weak self] in self?.store.state.settings.bugSizeMultiplier ?? 1 }
            ),
            sliderRow(
                id: .wildlifeSpeed,
                title: "Flight speed",
                subtitle: "Controls butterfly, fly, and firefly motion speed.",
                min: 0.25,
                max: 3.0,
                value: { [weak self] in self?.store.state.settings.wildlifeSpeedMultiplier ?? 1 }
            )
        ])

        addGroup(title: "Birds", to: stack, rows: [
            sliderRow(
                id: .birdCount,
                title: "Bird count",
                subtitle: "Controls how many Three.js birds each drawn sky area releases.",
                min: 0.25,
                max: 2.0,
                value: { [weak self] in self?.store.state.settings.birdCountMultiplier ?? 1 }
            )
        ])

        addGroup(title: "Cat Companion", to: stack, rows: [
            switchRow(
                title: "Open cat chat on click",
                subtitle: "When enabled, clicking directly on the cat opens the Cat AI Companion window. Clicks on plants, room objects, and radio companions are ignored.",
                action: #selector(toggleCatChatOnClick(_:)),
                isOn: { [weak self] in self?.store.state.settings.isCatChatOnClickEnabled ?? true }
            )
        ])

        addGroup(title: "Comfort", to: stack, rows: [
            rareMomentsModeRow(selectedMode: store.state.settings.rareMomentsMode),
            buttonRow(
                title: "Calm desktop mode",
                buttonTitle: "Apply",
                action: #selector(applyCalmDesktopMode),
                subtitle: { "Still performance, quieter rare moments, and reduced wildlife motion." }
            )
        ])
    }

    private func buildGnomeSection(in stack: NSStackView) {
        addGroup(title: "Society", to: stack, rows: [
            switchRow(
                title: "Gnome societies",
                subtitle: "Enable tiny Three.js societies inside painted gnome habitat zones.",
                action: #selector(toggleGnomeSocieties(_:)),
                isOn: { [weak self] in self?.store.state.settings.gnomeSimulation.isEnabled ?? true }
            ),
            sliderRow(
                id: .gnomePopulation,
                title: "Population",
                subtitle: "Controls how many gnomes settle into each painted zone.",
                min: 0.25,
                max: 2.5,
                value: { [weak self] in self?.store.state.settings.gnomeSimulation.populationMultiplier ?? 1 }
            ),
            sliderRow(
                id: .gnomeTribeSize,
                title: "Tribe size",
                subtitle: "Scales gnome bodies, homes, tunnels, and village props together.",
                min: 0.45,
                max: 2.25,
                value: { [weak self] in self?.store.state.settings.gnomeSimulation.tribeScaleMultiplier ?? 1 }
            ),
            sliderRow(
                id: .gnomeLiveliness,
                title: "Life-like behavior",
                subtitle: "More variation in pausing, wandering, gestures, celebrations, and small social beats.",
                min: 0.25,
                max: 2.5,
                value: { [weak self] in self?.store.state.settings.gnomeSimulation.behaviorLiveliness ?? 1 }
            )
        ])

        addGroup(title: "Village Simulation", to: stack, rows: [
            sliderRow(
                id: .gnomeBuildingSpeed,
                title: "Building speed",
                subtitle: "Controls how quickly cabins, roundhouses, and tiny structures progress.",
                min: 0.10,
                max: 4.0,
                value: { [weak self] in self?.store.state.settings.gnomeSimulation.buildingSpeedMultiplier ?? 1 }
            ),
            sliderRow(
                id: .gnomeSettlementPace,
                title: "Settlement timeframe",
                subtitle: "Days for gnomes to tunnel out from the starter area and populate every outlined area.",
                min: GnomeTribeSettlementPlan.minimumExpansionDurationDays,
                max: GnomeTribeSettlementPlan.maximumExpansionDurationDays,
                value: { [weak self] in
                    self?.store.state.settings.gnomeSimulation.settlementExpansionDays
                        ?? GnomeTribeSettlementPlan.defaultExpansionDurationDays
                }
            ),
            sliderRow(
                id: .gnomeCooperation,
                title: "Cooperation",
                subtitle: "Controls how often gnomes gather, visit neighbors, coordinate, and route through the village hub.",
                min: 0.0,
                max: 2.5,
                value: { [weak self] in self?.store.state.settings.gnomeSimulation.cooperationMultiplier ?? 1 }
            ),
            sliderRow(
                id: .gnomePlantInteraction,
                title: "Plant curiosity",
                subtitle: "Controls how strongly gnomes forage near, inspect, and climb resource-rich plants.",
                min: 0.0,
                max: 2.5,
                value: { [weak self] in self?.store.state.settings.gnomeSimulation.plantInteractionMultiplier ?? 1 }
            ),
            sliderRow(
                id: .gnomeVillageDetail,
                title: "Village detail",
                subtitle: "Adds denser homes, props, and build sites when the painted zone has room.",
                min: 0.50,
                max: 2.0,
                value: { [weak self] in self?.store.state.settings.gnomeSimulation.villageDetailMultiplier ?? 1 }
            )
        ])

        addGroup(title: "Current Scene", to: stack, rows: [
            infoRow(title: "Active zones", value: { [weak self] in
                guard let self else {
                    return "0"
                }
                let count = self.store.state.gnomeTribeZones.count
                let hidden = self.store.state.areGnomeTribesHidden || !self.store.state.settings.gnomeSimulation.isEnabled
                return count == 0
                    ? "None yet - draw one from Garden Tools"
                    : "\(count) zone\(count == 1 ? "" : "s")\(hidden ? " hidden" : " visible")"
            }),
            infoRow(title: "Perspective", value: { [weak self] in
                let perspective = self?.store.state.gnomeTribePerspective ?? .defaultValue
                return "\(Int(perspective.yawDegrees.rounded()))deg yaw, \(Int(perspective.elevationDegrees.rounded()))deg elevation"
            })
        ])
    }

    private func buildAudioSection(in stack: NSStackView) {
        renderedMusicSource = nil
        let companion = currentRadioCompanion

        addGroup(title: "Environmental Soundscape", to: stack, rows: [
            switchRow(
                title: "Ambient scene sounds",
                subtitle: "Synthesized live, no recordings. Scenes adapt across Garden, Room Studio, and Alien/UFO modes.",
                action: #selector(toggleAmbientSound(_:)),
                isOn: { [weak self] in self?.store.state.settings.isAmbientSoundEnabled ?? false }
            ),
            sliderRow(
                id: .ambientVolume,
                title: "Ambience volume",
                subtitle: "Kept gentle by design - it should sit under your music.",
                min: 0,
                max: 1.0,
                value: { [weak self] in self?.store.state.settings.ambientSoundVolume ?? 0.35 }
            ),
            infoRow(title: "Playing now", value: { [weak self] in
                guard let self else {
                    return ""
                }
                return Self.ambienceDescription(for: GardenAmbienceEngine.mix(
                    for: self.store.state,
                    sceneKey: self.store.activeSceneKey
                ))
            })
        ])

        addGroup(title: "Ambience Layers", to: stack, rows: [
            switchRow(
                title: "Wind",
                subtitle: "Rustle level follows the garden's wind strength.",
                action: #selector(toggleWindSound(_:)),
                isOn: { [weak self] in self?.store.state.settings.isWindSoundEnabled ?? false }
            ),
            switchRow(
                title: "Rain",
                subtitle: "Rain and drips play only while live weather says it is raining.",
                action: #selector(toggleRainSound(_:)),
                isOn: { [weak self] in self?.store.state.settings.isRainSoundEnabled ?? false }
            ),
            switchRow(
                title: "Birdsong",
                subtitle: "Daytime chirps, softened during rain and tuned to the current scene.",
                action: #selector(toggleBirdsong(_:)),
                isOn: { [weak self] in self?.store.state.settings.isBirdsongEnabled ?? false }
            ),
            switchRow(
                title: "Crickets",
                subtitle: "Evening insects, cicadas, and night pulses where the scene supports them.",
                action: #selector(toggleCricketSound(_:)),
                isOn: { [weak self] in self?.store.state.settings.isCricketSoundEnabled ?? false }
            )
        ])

        addGroup(title: "Radio Companion", to: stack, rows: [
            switchRow(
                title: "Show radio companion in scene",
                subtitle: "Place a draggable object that plays its own Filtermusic station.",
                action: #selector(toggleMusicButton(_:)),
                isOn: { [weak self] in self?.store.state.musicButton != nil }
            ),
            radioCompanionRow(selectedCompanion: companion),
            radioCompanionPreviewRow(selectedCompanion: companion),
            sliderRow(
                id: .radioCompanionScale,
                title: "Companion size",
                subtitle: "Scales every radio companion on the desktop, including its drag and click target.",
                min: 0.55,
                max: 1.70,
                value: { [weak self] in self?.store.state.settings.radioCompanionScale ?? 1 }
            ),
            radioActivationModeRow(selectedMode: store.state.settings.radioActivationMode),
            buttonRow(
                title: "Station assignment",
                buttonTitle: "Choose...",
                action: #selector(openRadioStationAssignment),
                subtitle: { [weak self] in
                    guard let self else { return "" }
                    return "\(self.currentRadioCompanion.displayName) plays \(self.currentRadioStream.displayName)."
                }
            ),
            infoRow(title: "Station", value: { [weak self] in
                self?.currentRadioStream.displayName ?? GardenRadioStation.chillHopByFluxFM.displayName
            })
        ])

        addGroup(title: "Companion Radio", to: stack, rows: [
            sliderRow(
                id: .musicVolume,
                title: "Radio volume",
                subtitle: "Volume for the companion's live radio stream.",
                min: 0,
                max: 1.0,
                value: { [weak self] in self?.store.state.settings.musicVolume ?? 1 }
            ),
            buttonRow(
                title: "Playback",
                buttonTitle: "Toggle",
                action: #selector(toggleRadioPlayback),
                subtitle: { [weak self] in
                    let stationName = self?.currentRadioStream.displayName
                        ?? GardenRadioStation.chillHopByFluxFM.displayName
                    return GardenRadioPlayer.shared.isPlaying
                        ? "\(stationName) is currently playing."
                        : "\(stationName) is currently stopped."
                },
                buttonTitleProvider: {
                    GardenRadioPlayer.shared.isPlaying ? "Stop Radio" : "Play Radio"
                }
            ),
            buttonRow(
                title: "Filtermusic station",
                buttonTitle: "Open",
                action: #selector(openRadioStation),
                subtitle: { [weak self] in
                    self?.currentRadioStream.shortDescription ?? ""
                }
            )
        ])
    }

    private func buildPrivacyStorageSection(in stack: NSStackView) {
        let recorder = GardenTimeLapseExporter.shared.recorder
        let promptHistory = GardenAIPromptHistoryStore(directoryURL: store.persistence.directoryURL)
        let promptHistoryEntries = promptHistory.entries()
        let readiness = GardenReleaseReadinessReport.makeSummary(
            store: store,
            wallpaperManager: wallpaperManager,
            timeLapseRecorder: recorder
        )
        addGroup(title: "Release Readiness", to: stack, rows: [
            infoRow(title: "Status", value: { "\(readiness.status.displayName) - \(readiness.score)/100" }),
            infoRow(title: "Issues", value: { readiness.issueBreakdownSummary }),
            infoRow(title: "Next action", value: { readiness.nextActionSummary }),
            buttonRow(
                title: "Save garden health check",
                buttonTitle: "Save...",
                action: #selector(saveHealthCheckFromSettings),
                subtitle: { "Exports settings, storage, audio, scene, and launch-readiness diagnostics." }
            )
        ])

        addGroup(title: "Privacy", to: stack, rows: [
            infoRow(title: "Garden data", value: { "Local files on this Mac" }),
            infoRow(title: "OpenAI", value: { "Only used when you generate" }),
            infoRow(title: "Weather", value: { [weak self] in
                self?.store.state.settings.isWeatherSyncEnabled == true ? "Enabled" : "Off"
            }),
            infoRow(title: "Radio", value: { "Streams directly from selected station" }),
            infoRow(title: "ElevenLabs", value: { "Only used when you start Miso voice mode" }),
            buttonRow(
                title: "Input Monitoring",
                buttonTitle: "Open",
                action: #selector(openInputMonitoringSettings),
                subtitle: { "Needed only for desktop plant clicks and drags; the app keeps working in menu-only mode without it." }
            ),
            buttonRow(
                title: "Desktop click behavior",
                buttonTitle: "Open",
                action: #selector(openDesktopDockSettings),
                subtitle: { "For best desktop planting, set macOS Click wallpaper to show desktop to Only in Stage Manager." }
            )
        ])

        addGroup(title: "AI Generation", to: stack, rows: [
            infoRow(title: "Image model", value: { WallpaperImageEditOpenAIConfiguration.model }),
            infoRow(title: "Output format", value: { "PNG" }),
            infoRow(title: "Used for", value: { "AI wallpaper scenes, wallpaper edits, and AI lock views" }),
            wallpaperGenerationQualityRow(selectedQuality: store.state.settings.wallpaperGenerationQuality),
            aiEditStrengthRow(selectedStrength: store.state.settings.aiEditStrength),
            infoRow(title: "Cost and credits", value: { [weak self] in
                self?.store.state.settings.wallpaperGenerationQuality.settingsNote
                    ?? GardenWallpaperGenerationQuality.twoK.settingsNote
            }),
            infoRow(title: "Last wallpaper prompt", value: {
                promptHistory.recentPrompt(for: .newWallpaper) ?? "None yet"
            }),
            infoRow(title: "Last edit prompt", value: {
                promptHistory.recentPrompt(for: .wallpaperEdit) ?? "None yet"
            }),
            infoRow(title: "Last plant prompt", value: {
                promptHistory.recentPrompt(for: .customPlant) ?? "None yet"
            }),
            buttonRow(
                title: "Clear AI prompt history",
                buttonTitle: "Clear...",
                action: #selector(confirmClearPromptHistory),
                subtitle: { "\(promptHistoryEntries.count) saved prompt\(promptHistoryEntries.count == 1 ? "" : "s") for reuse." },
                isEnabled: { !promptHistoryEntries.isEmpty },
                isDestructive: true
            ),
            buttonRow(
                title: "OpenAI API key",
                buttonTitle: "Manage...",
                action: #selector(openAPIKeySettings),
                subtitle: {
                    OpenAIAPIKeyStore.load() == nil
                        ? "No key stored in Keychain."
                        : "A key is stored in Keychain."
                }
            )
        ])

        addGroup(title: "Miso Voice", to: stack, rows: [
            infoRow(title: "Text-to-speech", value: { ElevenLabsMisoVoiceConfiguration.textToSpeechModel }),
            infoRow(title: "Speech-to-text", value: { ElevenLabsMisoVoiceConfiguration.speechToTextModel }),
            buttonRow(
                title: "ElevenLabs API key",
                buttonTitle: "Manage...",
                action: #selector(openElevenLabsAPIKeySettings),
                subtitle: {
                    ElevenLabsAPIKeyStore.load() == nil
                        ? "No key stored in Keychain."
                        : "A key is stored in Keychain."
                }
            )
        ])

        addGroup(title: "Time-Lapse", to: stack, rows: [
            timeLapseCadenceRow(selectedCadence: store.state.settings.timeLapseCadence),
            infoRow(title: "Stored frames", value: {
                recorder?.inventorySummary().storageSummary ?? "Not initialized"
            }),
            infoRow(title: "Retention cap", value: {
                "\(GardenTimeLapseRecorder.maximumStoredFrames) frames, then oldest frames auto-delete"
            }),
            buttonRow(
                title: "Delete time-lapse frames",
                buttonTitle: "Delete...",
                action: #selector(confirmDeleteTimeLapseFrames),
                subtitle: { "Clears captured frames without changing your garden." },
                isEnabled: { (recorder?.inventorySummary().frameCount ?? 0) > 0 },
                isDestructive: true
            )
        ])

        addGroup(title: "Notifications", to: stack, rows: [
            switchRow(
                title: "Care reminders",
                subtitle: "Watering, pruning, and plant-health notices.",
                action: #selector(toggleNotifyCare(_:)),
                isOn: { [weak self] in self?.store.state.settings.notifyCare ?? true }
            ),
            switchRow(
                title: "Weather",
                subtitle: "Rain, dew, and real-weather garden moments.",
                action: #selector(toggleNotifyWeather(_:)),
                isOn: { [weak self] in self?.store.state.settings.notifyWeather ?? true }
            ),
            switchRow(
                title: "Rare moments",
                subtitle: "Fireflies, butterfly migrations, rainbows, and other surprises.",
                action: #selector(toggleNotifyRareMoments(_:)),
                isOn: { [weak self] in self?.store.state.settings.notifyRareMoments ?? true }
            ),
            switchRow(
                title: "Focus",
                subtitle: "Focus session completion and growth reward notices.",
                action: #selector(toggleNotifyFocus(_:)),
                isOn: { [weak self] in self?.store.state.settings.notifyFocus ?? true }
            ),
            switchRow(
                title: "Harvest",
                subtitle: "Ready crops, seeds, and harvest summaries.",
                action: #selector(toggleNotifyHarvest(_:)),
                isOn: { [weak self] in self?.store.state.settings.notifyHarvest ?? true }
            )
        ])

        addGroup(title: "Storage", to: stack, rows: [
            infoRow(title: "Garden data folder", value: { [weak self] in
                Self.storageSummary(for: self?.store.persistence.directoryURL)
            }),
            infoRow(title: "Rendered wallpaper cache", value: { [weak self] in
                Self.storageSummary(for: self?.wallpaperManager.wallpaperDataDirectoryURL)
            }),
            infoRow(title: "AI wallpaper source images", value: { [weak self] in
                Self.storageSummary(for: self?.wallpaperManager.aiWallpaperDataDirectoryURL)
            }),
            infoRow(title: "Imported wallpaper source images", value: { [weak self] in
                Self.storageSummary(for: self?.wallpaperManager.customWallpaperDataDirectoryURL)
            }),
            infoRow(title: "Generated plant assets", value: { [weak self] in
                self?.store.customPlantAssets.inventorySummary().storageSummary ?? "Unavailable"
            }),
            buttonRow(
                title: "Prune rendered wallpaper cache",
                buttonTitle: "Prune",
                action: #selector(pruneWallpaperCache),
                subtitle: { "Keeps source scenes and recent renders; removes stale regenerated PNGs." }
            ),
            buttonRow(
                title: "Delete generated plant assets",
                buttonTitle: "Delete...",
                action: #selector(confirmDeleteGeneratedPlantAssets),
                subtitle: { [weak self] in
                    self?.store.customPlantAssets.inventorySummary().storageSummary ?? "No generated assets."
                },
                isEnabled: { [weak self] in (self?.store.customPlantAssets.inventorySummary().assetCount ?? 0) > 0 },
                isDestructive: true
            ),
            buttonRow(
                title: "Reveal all app data",
                buttonTitle: "Reveal",
                action: #selector(openAppDataFolder),
                subtitle: { "Opens the folder containing gardens, journals, time-lapse frames, and generated assets." }
            ),
            buttonRow(
                title: "Screensaver status",
                buttonTitle: "Open",
                action: #selector(openScreenSaverSettings),
                subtitle: { Self.screenSaverStatusSummary() }
            )
        ])
    }

    private func buildAssetsSection(in stack: NSStackView) {
        let displayableCount = PlantAssetLibrary.shared.displayableSpecies().count
        let completeCount = PlantSpecies.allCases.filter {
            PlantAssetLibrary.shared.hasCompleteGrowthAssetSet(for: $0)
        }.count

        addGroup(title: "Plant Assets", to: stack, rows: [
            infoRow(title: "Displayable species", value: { "\(displayableCount) of \(PlantSpecies.allCases.count)" }),
            infoRow(title: "Complete growth sets", value: { "\(completeCount)" }),
            buttonRow(
                title: "Bundled plant artwork",
                buttonTitle: "Open",
                action: #selector(openPlantAssets),
                subtitle: { "Open the app bundle folder containing plant PNG assets." }
            )
        ])

        addGroup(title: "Generated Scenes", to: stack, rows: [
            infoRow(title: "Custom scenes", value: { [weak self] in
                "\(self?.wallpaperManager.customWallpapers.count ?? 0)"
            }),
            buttonRow(
                title: "AI wallpaper folder",
                buttonTitle: "Open",
                action: #selector(openAIWallpaperFolder),
                subtitle: { "Open generated AI wallpaper outputs." }
            ),
            buttonRow(
                title: "Custom wallpaper folder",
                buttonTitle: "Open",
                action: #selector(openCustomWallpaperFolder),
                subtitle: { "Open imported local wallpaper outputs." }
            ),
            buttonRow(
                title: "OpenAI API key",
                buttonTitle: "Manage...",
                action: #selector(openAPIKeySettings),
                subtitle: {
                    OpenAIAPIKeyStore.load() == nil
                        ? "No key stored in Keychain."
                        : "A key is stored in Keychain."
                }
            )
        ])
    }

    private func buildAdvancedSection(in stack: NSStackView) {
        addGroup(title: "Data", to: stack, rows: [
            buttonRow(
                title: "Open active garden data",
                buttonTitle: "Reveal",
                action: #selector(openGardenData),
                subtitle: { [weak self] in self?.store.activeGardenFileURL.lastPathComponent ?? "" }
            ),
            buttonRow(
                title: "Open app data folder",
                buttonTitle: "Open",
                action: #selector(openAppDataFolder),
                subtitle: { [weak self] in self?.store.persistence.directoryURL.path ?? "" }
            ),
            buttonRow(
                title: "Open wallpaper data folder",
                buttonTitle: "Open",
                action: #selector(openWallpaperDataFolder),
                subtitle: { [weak self] in self?.wallpaperManager.wallpaperDataDirectoryURL.path ?? "" }
            ),
            infoRow(title: "Last save status", value: { [weak self] in
                self?.store.lastError.map { "Error: \($0)" } ?? "Saving normally"
            }),
            buttonRow(
                title: "Save garden health check",
                buttonTitle: "Save...",
                action: #selector(saveHealthCheckFromSettings),
                subtitle: { "Export current garden, settings, weather, audio, time-lapse, and diary diagnostics." }
            )
        ])

        addGroup(title: "Destructive Actions", to: stack, rows: [
            buttonRow(
                title: "Reset garden",
                buttonTitle: "Reset...",
                action: #selector(confirmResetGarden),
                subtitle: { "Replace this scene with the default garden." },
                isDestructive: true
            ),
            buttonRow(
                title: "Delete all plants in scene",
                buttonTitle: "Delete...",
                action: #selector(deleteAllPlantsInScene),
                subtitle: { "Clear only the active scene's plants." },
                isDestructive: true
            )
        ])
    }

    // MARK: - Building blocks

    private func sectionHeader(_ section: Section) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        let title = NSTextField(labelWithString: section.title)
        title.font = .systemFont(ofSize: 26, weight: .bold)
        title.textColor = .labelColor
        stack.addArrangedSubview(title)

        let subtitle = NSTextField(labelWithString: section.subtitle)
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        stack.addArrangedSubview(subtitle)
        return stack
    }

    /// Appends a System Settings-style group to `parentStack`: a bold caption
    /// above a rounded card whose rows are separated by hairlines. Width
    /// constraints are activated only after the group joins the hierarchy.
    @discardableResult
    private func addGroup(title: String, to parentStack: NSStackView, rows: [NSView]) -> NSView {
        let card = NSStackView()
        card.orientation = .vertical
        card.alignment = .leading
        card.spacing = 0
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 10
        card.layer?.cornerCurve = .continuous
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor

        for (index, row) in rows.enumerated() {
            if index > 0 {
                let separator = NSBox()
                separator.boxType = .separator
                card.addArrangedSubview(separator)
                separator.leadingAnchor.constraint(
                    equalTo: card.leadingAnchor,
                    constant: Layout.rowHorizontalPadding
                ).isActive = true
                separator.trailingAnchor.constraint(equalTo: card.trailingAnchor).isActive = true
            }

            card.addArrangedSubview(row)
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor).isActive = true
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor).isActive = true
        }

        let caption = NSTextField(labelWithString: title)
        caption.font = .systemFont(ofSize: 13, weight: .semibold)
        caption.textColor = .labelColor

        let container = NSStackView(views: [caption, card])
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 8
        card.translatesAutoresizingMaskIntoConstraints = false

        parentStack.addArrangedSubview(container)

        card.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        container.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.contentMaxWidth).isActive = true
        let fill = container.widthAnchor.constraint(
            equalTo: parentStack.widthAnchor,
            constant: -(Layout.contentInset * 2)
        )
        fill.priority = .defaultHigh
        fill.isActive = true
        return container
    }

    private func rowContainer(_ views: [NSView], orientation: NSUserInterfaceLayoutOrientation = .horizontal) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = orientation
        row.alignment = orientation == .horizontal ? .centerY : .leading
        row.spacing = orientation == .horizontal ? 12 : 6
        row.edgeInsets = NSEdgeInsets(
            top: Layout.rowVerticalPadding,
            left: Layout.rowHorizontalPadding,
            bottom: Layout.rowVerticalPadding,
            right: Layout.rowHorizontalPadding
        )
        return row
    }

    private func titledTextStack(title: String, subtitle: String?) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .labelColor

        var views: [NSView] = [titleLabel]
        if let subtitle, !subtitle.isEmpty {
            views.append(smallLabel(subtitle))
        }

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        return stack
    }

    private func switchRow(
        title: String,
        subtitle: String,
        action: Selector,
        isOn: @escaping () -> Bool
    ) -> NSView {
        let toggle = NSSwitch()
        toggle.target = self
        toggle.action = action
        toggle.controlSize = .regular
        toggle.setContentHuggingPriority(.required, for: .horizontal)

        registerUpdate { [weak toggle] in
            let desiredState: NSControl.StateValue = isOn() ? .on : .off
            if toggle?.state != desiredState {
                toggle?.state = desiredState
            }
        }

        let row = rowContainer([titledTextStack(title: title, subtitle: subtitle), NSView.spacer(), toggle])
        return row
    }

    private func sliderRow(
        id: SliderID,
        title: String,
        subtitle: String,
        min: Double,
        max: Double,
        value: @escaping () -> Double
    ) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13)

        let valueLabel = NSTextField(labelWithString: "")
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let heading = NSStackView(views: [titleLabel, NSView.spacer(), valueLabel])
        heading.orientation = .horizontal
        heading.alignment = .centerY
        heading.spacing = 8

        let slider = NSSlider(value: value(), minValue: min, maxValue: max, target: self, action: #selector(sliderChanged(_:)))
        slider.identifier = NSUserInterfaceItemIdentifier(id.rawValue)
        slider.isContinuous = true
        slider.numberOfTickMarks = 9
        slider.allowsTickMarkValuesOnly = false

        let resetButton = NSButton(title: "", target: self, action: #selector(resetSliderToDefault(_:)))
        resetButton.identifier = NSUserInterfaceItemIdentifier("reset:" + id.rawValue)
        resetButton.isBordered = false
        resetButton.toolTip = "Reset to default"
        if let resetImage = NSImage(
            systemSymbolName: "arrow.counterclockwise.circle",
            accessibilityDescription: "Reset \(title) to default"
        ) {
            resetButton.image = resetImage
            resetButton.contentTintColor = .tertiaryLabelColor
        }
        resetButton.setContentHuggingPriority(.required, for: .horizontal)
        heading.addArrangedSubview(resetButton)

        registerUpdate { [weak slider, weak valueLabel, weak resetButton, weak self] in
            guard let self else {
                return
            }

            let currentValue = value()
            valueLabel?.stringValue = self.formattedSliderValue(currentValue, for: id)
            if let slider, !slider.isHighlighted, abs(slider.doubleValue - currentValue) > 0.0001 {
                slider.doubleValue = currentValue
            }
            resetButton?.isHidden = abs(currentValue - id.defaultValue) < 0.005
        }

        let column = NSStackView(views: [heading, smallLabel(subtitle), slider])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 5
        heading.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        slider.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true

        let row = rowContainer([column], orientation: .vertical)
        column.widthAnchor.constraint(
            equalTo: row.widthAnchor,
            constant: -(Layout.rowHorizontalPadding * 2)
        ).isActive = true
        return row
    }

    private func buttonRow(
        title: String,
        buttonTitle: String,
        action: Selector,
        subtitle: @escaping () -> String,
        isEnabled: @escaping () -> Bool = { true },
        isDestructive: Bool = false,
        buttonTitleProvider: (() -> String)? = nil
    ) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13)
        let subtitleLabel = smallLabel("")

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let button = NSButton(title: buttonTitle, target: self, action: action)
        button.bezelStyle = .rounded
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        if isDestructive {
            button.hasDestructiveAction = true
            button.contentTintColor = .systemRed
        }

        registerUpdate { [weak subtitleLabel, weak button] in
            let subtitleText = subtitle()
            if subtitleLabel?.stringValue != subtitleText {
                subtitleLabel?.stringValue = subtitleText
            }
            button?.isEnabled = isEnabled()
            if let buttonTitleProvider, let button {
                let buttonText = buttonTitleProvider()
                if button.title != buttonText {
                    button.title = buttonText
                }
            }
        }

        return rowContainer([textStack, NSView.spacer(), button])
    }

    private func infoRow(title: String, value: @escaping () -> String) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13)

        let valueLabel = NSTextField(labelWithString: "")
        valueLabel.font = .systemFont(ofSize: 13)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.lineBreakMode = .byTruncatingMiddle
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        registerUpdate { [weak valueLabel] in
            let text = value()
            if valueLabel?.stringValue != text {
                valueLabel?.stringValue = text
            }
        }

        return rowContainer([titleLabel, NSView.spacer(), valueLabel])
    }

    private func launchAtLoginRow() -> NSView {
        let toggle = NSSwitch()
        toggle.target = self
        toggle.action = #selector(toggleLaunchAtLogin(_:))
        toggle.setContentHuggingPriority(.required, for: .horizontal)

        registerUpdate { [weak toggle] in
            let desiredState: NSControl.StateValue = SMAppService.mainApp.status == .enabled ? .on : .off
            if toggle?.state != desiredState {
                toggle?.state = desiredState
            }
        }

        return rowContainer([
            titledTextStack(
                title: "Launch at login",
                subtitle: "Start Plant Wallpaper automatically when you log in."
            ),
            NSView.spacer(),
            toggle
        ])
    }

    private func musicSourceRow(selectedSource: GardenMusicSource) -> NSView {
        let popup = NSPopUpButton()
        popup.target = self
        popup.action = #selector(musicSourceChanged(_:))
        popup.setContentHuggingPriority(.required, for: .horizontal)

        for source in GardenMusicSource.allCases {
            popup.addItem(withTitle: source.displayName)
            popup.lastItem?.representedObject = source.rawValue
        }
        if let item = popup.itemArray.first(where: { ($0.representedObject as? String) == selectedSource.rawValue }) {
            popup.select(item)
        }

        return rowContainer([
            titledTextStack(title: "Source", subtitle: nil),
            NSView.spacer(),
            popup
        ])
    }

    private func radioCompanionRow(selectedCompanion: GardenRadioCompanion) -> NSView {
        let popup = NSPopUpButton()
        popup.target = self
        popup.action = #selector(radioCompanionChanged(_:))
        popup.setContentHuggingPriority(.required, for: .horizontal)

        for entry in GardenRadioCompanionMenuCatalog.entries {
            popup.addItem(withTitle: entry.title)
            popup.lastItem?.representedObject = entry.companion.rawValue
            popup.lastItem?.toolTip = entry.toolTip
        }
        if let item = popup.itemArray.first(where: { ($0.representedObject as? String) == selectedCompanion.rawValue }) {
            popup.select(item)
        }

        registerUpdate { [weak popup, weak self] in
            guard let popup,
                  let self else {
                return
            }

            let rawValue = self.currentRadioCompanion.rawValue
            if let item = popup.itemArray.first(where: { ($0.representedObject as? String) == rawValue }),
               popup.selectedItem !== item {
                popup.select(item)
            }
        }

        return rowContainer([
            titledTextStack(title: "Companion", subtitle: selectedCompanion.placementSummary),
            NSView.spacer(),
            popup
        ])
    }

    private func timeLapseCadenceRow(selectedCadence: GardenTimeLapseCadence) -> NSView {
        popupRow(
            title: "Capture frames",
            subtitle: "Controls automatic time-lapse snapshots so disk use is predictable.",
            selectedRawValue: selectedCadence.rawValue,
            options: GardenTimeLapseCadence.allCases.map { ($0.rawValue, $0.displayName) },
            action: #selector(timeLapseCadenceChanged(_:))
        )
    }

    private func performanceModeRow(selectedMode: GardenPerformanceMode) -> NSView {
        popupRow(
            title: "Performance mode",
            subtitle: "Still reduces animation work; Lively keeps the garden expressive.",
            selectedRawValue: selectedMode.rawValue,
            options: GardenPerformanceMode.allCases.map { ($0.rawValue, $0.displayName) },
            action: #selector(performanceModeChanged(_:))
        )
    }

    private func experienceModeRow(selectedMode: GardenExperienceMode) -> NSView {
        popupRow(
            title: "Experience mode",
            subtitle: "Garden, Room Studio, and Alien/UFO Garden each switch the scene pack and creation menus.",
            selectedRawValue: selectedMode.rawValue,
            options: GardenExperienceMode.allCases.map { mode in
                let feature = Self.proFeature(for: mode)
                let isLocked = feature.map { !GardenEntitlements.shared.isUnlocked($0) } ?? false
                return (mode.rawValue, isLocked ? "\(mode.displayName) (Pro)" : mode.displayName)
            },
            action: #selector(experienceModeChanged(_:))
        )
    }

    private static func proFeature(for mode: GardenExperienceMode) -> GardenProFeature? {
        switch mode {
        case .garden:
            nil
        case .roomStudio:
            .roomStudio
        case .alienUFO:
            .alienUFOGarden
        }
    }

    private func displayBehaviorRow(selectedBehavior: GardenDisplayBehavior) -> NSView {
        popupRow(
            title: "Display behavior",
            subtitle: "Mirror the garden everywhere, or keep WallpaperGarden on the main display only.",
            selectedRawValue: selectedBehavior.rawValue,
            options: GardenDisplayBehavior.allCases.map { ($0.rawValue, $0.displayName) },
            action: #selector(displayBehaviorChanged(_:))
        )
    }

    private func radioActivationModeRow(selectedMode: GardenRadioActivationMode) -> NSView {
        popupRow(
            title: "Companion click behavior",
            subtitle: "Prevents accidental radio starts while dragging or exploring.",
            selectedRawValue: selectedMode.rawValue,
            options: GardenRadioActivationMode.allCases.map { ($0.rawValue, $0.displayName) },
            action: #selector(radioActivationModeChanged(_:))
        )
    }

    private func radioCompanionPreviewRow(selectedCompanion: GardenRadioCompanion) -> NSView {
        let previewBox = NSView()
        previewBox.wantsLayer = true
        previewBox.layer?.cornerRadius = 14
        previewBox.layer?.cornerCurve = .continuous
        previewBox.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.82).cgColor
        previewBox.layer?.borderWidth = 1
        previewBox.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.65).cgColor
        previewBox.translatesAutoresizingMaskIntoConstraints = false
        previewBox.widthAnchor.constraint(equalToConstant: 156).isActive = true
        previewBox.heightAnchor.constraint(equalToConstant: 136).isActive = true

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        previewBox.addSubview(imageView)

        let widthConstraint = imageView.widthAnchor.constraint(equalToConstant: 82)
        let heightConstraint = imageView.heightAnchor.constraint(equalToConstant: 82)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: previewBox.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: previewBox.centerYAnchor),
            widthConstraint,
            heightConstraint
        ])

        let caption = NSTextField(labelWithString: selectedCompanion.displayName)
        caption.font = .systemFont(ofSize: 12, weight: .medium)
        caption.textColor = .secondaryLabelColor
        caption.alignment = .center
        caption.lineBreakMode = .byTruncatingTail

        registerUpdate { [weak imageView, weak caption, weak widthConstraint, weak heightConstraint, weak self] in
            guard let self else {
                return
            }

            let companion = self.currentRadioCompanion
            imageView?.image = GardenRadioCompanionAssetLibrary.shared.image(for: companion)
                ?? NSImage(systemSymbolName: "radio.fill", accessibilityDescription: companion.displayName)
            caption?.stringValue = "\(companion.displayName) - \(self.formattedSliderValue(self.store.state.settings.radioCompanionScale, for: .radioCompanionScale))"
            let previewSize = 82 * self.store.state.settings.radioCompanionScale
            widthConstraint?.constant = previewSize
            heightConstraint?.constant = previewSize
        }

        let previewStack = NSStackView(views: [previewBox, caption])
        previewStack.orientation = .vertical
        previewStack.alignment = .centerX
        previewStack.spacing = 7

        return rowContainer([
            titledTextStack(
                title: "Size preview",
                subtitle: "Uses the real selected companion artwork at the current desktop scale."
            ),
            NSView.spacer(),
            previewStack
        ])
    }

    private func aiEditStrengthRow(selectedStrength: GardenAIEditStrength) -> NSView {
        popupRow(
            title: "Wallpaper edit strength",
            subtitle: "Subtle keeps the current image closest to what you already have.",
            selectedRawValue: selectedStrength.rawValue,
            options: GardenAIEditStrength.allCases.map { ($0.rawValue, $0.displayName) },
            action: #selector(aiEditStrengthChanged(_:))
        )
    }

    private func wallpaperGenerationQualityRow(selectedQuality: GardenWallpaperGenerationQuality) -> NSView {
        popupRow(
            title: "Wallpaper generation quality",
            subtitle: "2K is lower-cost and quick; 4K is sharper and uses more OpenAI tokens or app credits.",
            selectedRawValue: selectedQuality.rawValue,
            options: GardenWallpaperGenerationQuality.allCases.map {
                ($0.rawValue, "\($0.displayName) - \($0.openAISize)")
            },
            action: #selector(wallpaperGenerationQualityChanged(_:))
        )
    }

    private func rareMomentsModeRow(selectedMode: GardenRareMomentsMode) -> NSView {
        popupRow(
            title: "Rare moments",
            subtitle: "Controls butterflies, fireflies, rainbows, and their notifications.",
            selectedRawValue: selectedMode.rawValue,
            options: GardenRareMomentsMode.allCases.map { ($0.rawValue, $0.displayName) },
            action: #selector(rareMomentsModeChanged(_:))
        )
    }

    private func popupRow(
        title: String,
        subtitle: String?,
        selectedRawValue: String,
        options: [(rawValue: String, title: String)],
        action: Selector
    ) -> NSView {
        let popup = NSPopUpButton()
        popup.target = self
        popup.action = action
        popup.setContentHuggingPriority(.required, for: .horizontal)

        for option in options {
            popup.addItem(withTitle: option.title)
            popup.lastItem?.representedObject = option.rawValue
        }
        if let item = popup.itemArray.first(where: { ($0.representedObject as? String) == selectedRawValue }) {
            popup.select(item)
        }

        return rowContainer([
            titledTextStack(title: title, subtitle: subtitle),
            NSView.spacer(),
            popup
        ])
    }

    private func spotifyLinkRow(value: String) -> NSView {
        let textField = NSTextField(string: value)
        textField.identifier = NSUserInterfaceItemIdentifier("spotifyLaunchURL")
        textField.placeholderString = GardenSettings.defaultSpotifyLaunchURLString
        textField.font = .systemFont(ofSize: 12)
        textField.target = self
        textField.action = #selector(saveSpotifyLink)
        let spotifyTextFieldDelegate = MainActorTextFieldDelegate { [weak self] event in
            self?.controlTextDidEndEditing(event.notification)
        }
        self.spotifyTextFieldDelegate = spotifyTextFieldDelegate
        textField.delegate = spotifyTextFieldDelegate
        textField.lineBreakMode = .byTruncatingTail
        spotifyURLTextField = textField

        registerUpdate { [weak textField, weak self] in
            guard let textField,
                  let self,
                  textField.currentEditor() == nil else {
                return
            }

            let stored = self.store.state.settings.spotifyLaunchURLString
            if textField.stringValue != stored {
                textField.stringValue = stored
            }
        }

        let column = NSStackView(views: [
            titledTextStack(
                title: "Spotify link",
                subtitle: "Use an open.spotify.com link, spotify.link short link, or spotify: URI. Press Return to save."
            ),
            textField
        ])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 6

        let row = rowContainer([column], orientation: .vertical)
        column.widthAnchor.constraint(
            equalTo: row.widthAnchor,
            constant: -(Layout.rowHorizontalPadding * 2)
        ).isActive = true
        textField.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        return row
    }

    /// A visual scene picker: thumbnail cards for every built-in and custom
    /// scene, with a green ring and badge on the active one.
    private func sceneGalleryView() -> NSView {
        let selectedKey = wallpaperManager.selectedWallpaperSceneKey
        var sceneEntries: [(key: String, name: String, isEnabled: Bool)] = GardenWallpaperScene.scenes(for: store.state.settings.experienceMode).map {
            ($0.rawValue, $0.displayName, $0.isSelectableScene)
        }
        sceneEntries.append(
            contentsOf: wallpaperManager
                .customWallpaperSceneRoots(for: store.state.settings.experienceMode)
                .map { ($0.key, $0.displayName, true) }
        )

        let columnsPerRow = 3
        let gallery = NSStackView()
        gallery.orientation = .vertical
        gallery.alignment = .leading
        gallery.spacing = 14

        var rowViews: [NSView] = []
        for (key, name, isEnabled) in sceneEntries {
            rowViews.append(sceneThumbnailCard(key: key, name: name, isSelected: key == selectedKey, isEnabled: isEnabled))
            if rowViews.count == columnsPerRow {
                gallery.addArrangedSubview(galleryRow(rowViews))
                rowViews = []
            }
        }
        if !rowViews.isEmpty {
            gallery.addArrangedSubview(galleryRow(rowViews))
        }
        return gallery
    }

    private func galleryRow(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 14
        return row
    }

    private func sceneThumbnailCard(key: String, name: String, isSelected: Bool, isEnabled: Bool = true) -> NSView {
        let button = NSButton(title: "", target: self, action: #selector(sceneThumbnailClicked(_:)))
        button.identifier = NSUserInterfaceItemIdentifier("scene-thumb:" + key)
        button.isEnabled = isEnabled
        button.alphaValue = isEnabled ? 1 : 0.45
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyUpOrDown
        button.wantsLayer = true
        button.layer?.cornerRadius = 9
        button.layer?.cornerCurve = .continuous
        button.layer?.masksToBounds = true
        button.layer?.borderWidth = isSelected ? 2.5 : 1
        button.layer?.borderColor = isSelected
            ? NSColor.systemGreen.cgColor
            : NSColor.separatorColor.cgColor
        button.toolTip = isEnabled ? name : "\(name) - coming soon"
        if let image = wallpaperManager.thumbnailImage(forSceneKey: key) {
            button.image = image
        } else if let placeholder = NSImage(systemSymbolName: "photo", accessibilityDescription: name) {
            button.image = placeholder
        }
        button.widthAnchor.constraint(equalToConstant: 176).isActive = true
        button.heightAnchor.constraint(equalToConstant: 110).isActive = true

        let displayName = isEnabled ? name : "\(name) (Coming Soon)"
        let nameLabel = NSTextField(labelWithString: isSelected ? "✓ " + displayName : displayName)
        nameLabel.font = .systemFont(ofSize: 11, weight: isSelected ? .semibold : .regular)
        nameLabel.textColor = isEnabled
            ? (isSelected ? .labelColor : .secondaryLabelColor)
            : .disabledControlTextColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.alignment = .center
        nameLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 176).isActive = true

        let card = NSStackView(views: [button, nameLabel])
        card.orientation = .vertical
        card.alignment = .centerX
        card.spacing = 5
        return card
    }

    @objc private func sceneThumbnailClicked(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
              identifier.hasPrefix("scene-thumb:") else {
            return
        }

        let sceneKey = String(identifier.dropFirst("scene-thumb:".count))
        presentSceneDetail(forSceneKey: sceneKey)
    }

    private func presentSceneDetail(forSceneKey sceneKey: String) {
        guard let window else {
            return
        }

        // Make the clicked scene live so the editor previews and edits it.
        if sceneKey != wallpaperManager.selectedWallpaperSceneKey {
            actions.applyScene(sceneKey)
        }

        let controller = GardenSceneDetailWindowController(
            wallpaperManager: wallpaperManager,
            sceneRootKey: sceneKey,
            sceneName: sceneDisplayName(forKey: sceneKey),
            callbacks: GardenSceneDetailWindowController.Callbacks(
                applyVersion: { [weak self] key in
                    self?.actions.applyScene(key)
                },
                generateEdit: { [weak self] prompt, completion in
                    guard let self else {
                        completion(.failure(CancellationError()))
                        return
                    }
                    self.actions.generateSceneEdit(prompt, completion)
                },
                onClose: { [weak self] in
                    self?.sceneDetailController = nil
                    self?.renderSelectedSection(preservingScroll: true)
                }
            )
        )
        sceneDetailController = controller
        controller.present(over: window)
    }

    private func sceneDisplayName(forKey key: String) -> String {
        GardenWallpaperScene(rawValue: key)?.displayName
            ?? wallpaperManager.customWallpapers.first { $0.key == key }?.displayName
            ?? "Custom Scene"
    }

    private func customSceneRow(for record: CustomWallpaperRecord) -> NSView {
        let isAIScene = record.key.hasPrefix("ai-")
        let subtitleText = [
            isAIScene ? "AI generated" : "Imported image",
            Self.sceneDateFormatter.string(from: record.createdAt)
        ].joined(separator: " - ")

        let applyButton = NSButton(title: "Apply", target: self, action: #selector(applyCustomScene(_:)))
        applyButton.bezelStyle = .rounded
        applyButton.identifier = NSUserInterfaceItemIdentifier("apply-\(record.key)")
        applyButton.setContentHuggingPriority(.required, for: .horizontal)

        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteCustomScene(_:)))
        deleteButton.bezelStyle = .rounded
        deleteButton.hasDestructiveAction = true
        deleteButton.contentTintColor = .systemRed
        deleteButton.identifier = NSUserInterfaceItemIdentifier("delete-\(record.key)")
        deleteButton.setContentHuggingPriority(.required, for: .horizontal)

        registerUpdate { [weak applyButton, weak self] in
            guard let applyButton, let self else {
                return
            }

            let isActive = self.wallpaperManager.selectedWallpaperSceneKey == record.key
            applyButton.isEnabled = !isActive
            let title = isActive ? "Active" : "Apply"
            if applyButton.title != title {
                applyButton.title = title
            }
        }

        return rowContainer([
            titledTextStack(
                title: GardenMenuTitleFormatter.compactStatusTitle(record.displayName, maxLength: 44),
                subtitle: subtitleText
            ),
            NSView.spacer(),
            applyButton,
            deleteButton
        ])
    }

    private static let sceneDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private func smallLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 3
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    // MARK: - Settings mutation

    /// Applies a settings change immediately but defers the disk write briefly,
    /// so continuous slider drags don't write JSON on every tick.
    private func updateSettingsDebounced(_ transform: (GardenSettings) -> GardenSettings) {
        store.updateSettings(transform(store.state.settings), persist: false)
        saveDebounceTimer?.invalidate()
        saveDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.flushPendingSettingsSave()
            }
        }
    }

    private func updateSceneVisualsDebounced(_ update: () -> Void) {
        update()
        saveDebounceTimer?.invalidate()
        saveDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.flushPendingSettingsSave()
            }
        }
    }

    private func flushPendingSettingsSave() {
        saveDebounceTimer?.invalidate()
        saveDebounceTimer = nil
        store.save()
    }

    private func formattedSliderValue(_ value: Double, for id: SliderID) -> String {
        switch id {
        case .musicVolume, .ambientVolume:
            return "\(Int((value * 100).rounded()))%"
        case .radioCompanionScale:
            return "\(Int((GardenCanvasView.musicButtonSize * CGFloat(value)).rounded()))pt - \(String(format: "%.2fx", value))"
        case .plantDarkening:
            return "\(Int((value * 100).rounded()))% darker"
        default:
            return String(format: "%.2fx - %@", value, Self.sliderMoodWord(for: value))
        }
    }

    /// Plain-language reading of a multiplier so sliders speak human, not
    /// machine: "0.50x - calm" instead of a bare number.
    private static func sliderMoodWord(for value: Double) -> String {
        switch value {
        case ..<0.55:
            "calm"
        case ..<0.85:
            "gentle"
        case ..<1.2:
            "natural"
        case ..<1.9:
            "lively"
        default:
            "wild"
        }
    }

    // MARK: - Control actions

    private static func ambienceDescription(for mix: GardenAmbienceEngine.Mix) -> String {
        guard mix.masterVolume > 0.001 else {
            return "Off"
        }

        var layers: [String] = []
        if mix.rain > 0.05 {
            layers.append("rain")
        }
        if mix.birds > 0.05 {
            layers.append("birdsong")
        }
        if mix.crickets > 0.05 {
            layers.append("crickets")
        }
        if mix.wind > 0.05 {
            layers.append("wind")
        }
        if mix.water > 0.05 {
            layers.append("water")
        }
        if mix.urbanMurmur > 0.05 {
            layers.append("distant city")
        }
        if mix.roomTone > 0.05 {
            layers.append("room tone")
        }
        if mix.cicadas > 0.05 {
            layers.append("cicadas")
        }
        if mix.chimes > 0.05 {
            layers.append("chimes")
        }
        if mix.smallWildlife > 0.05 {
            layers.append("small wildlife")
        }
        if mix.roomLife > 0.05 {
            layers.append("room life")
        }
        if mix.electronics > 0.05 {
            layers.append("electronics")
        }
        if mix.alienFauna > 0.05 {
            layers.append("alien fauna")
        }
        if mix.habitatHum > 0.05 {
            layers.append("habitat hum")
        }
        if mix.crystallineShimmer > 0.05 {
            layers.append("crystal shimmer")
        }
        if mix.lowRumble > 0.05 {
            layers.append("low rumble")
        }
        return layers.isEmpty ? "Quiet hour" : layers.joined(separator: " + ").capitalized
    }

    private static func storageSummary(for directoryURL: URL?) -> String {
        guard let directoryURL else {
            return "Unavailable"
        }

        let bytes = directoryByteCount(at: directoryURL)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private static func screenSaverStatusSummary() -> String {
        let screenSaverURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers/Plant Wallpaper.saver")
        if FileManager.default.fileExists(atPath: screenSaverURL.path) {
            return "Installed - open macOS settings to use Plant Wallpaper as your screen saver."
        }
        return "Not set up yet - this optional extra needs the Plant Wallpaper screen saver in your Library/Screen Savers folder, then pick it in System Settings ▸ Screen Saver."
    }

    private static func directoryByteCount(at directoryURL: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    @objc private func resetSliderToDefault(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
              identifier.hasPrefix("reset:"),
              let id = SliderID(rawValue: String(identifier.dropFirst("reset:".count))) else {
            return
        }

        let defaultValue = id.defaultValue
        if id == .plantDarkening {
            updateSceneVisualsDebounced { [weak self] in
                self?.store.setManualPlantDarkening(defaultValue, persist: false)
            }
            return
        }

        updateSettingsDebounced { settings in
            switch id {
            case .growthSpeed:
                settings.updating(growthSpeedMultiplier: defaultValue)
            case .waterUse:
                settings.updating(waterUseMultiplier: defaultValue)
            case .defaultScale:
                settings.updating(defaultPlantScale: defaultValue)
            case .wildlifeDensity:
                settings.updating(wildlifeDensityMultiplier: defaultValue)
            case .wildlifeSpeed:
                settings.updating(wildlifeSpeedMultiplier: defaultValue)
            case .bugSize:
                settings.updating(bugSizeMultiplier: defaultValue)
            case .birdCount:
                settings.updating(birdCountMultiplier: defaultValue)
            case .gnomePopulation:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(populationMultiplier: defaultValue))
            case .gnomeTribeSize:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(tribeScaleMultiplier: defaultValue))
            case .gnomeLiveliness:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(behaviorLiveliness: defaultValue))
            case .gnomeBuildingSpeed:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(buildingSpeedMultiplier: defaultValue))
            case .gnomeSettlementPace:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(settlementExpansionDays: defaultValue))
            case .gnomeCooperation:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(cooperationMultiplier: defaultValue))
            case .gnomePlantInteraction:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(plantInteractionMultiplier: defaultValue))
            case .gnomeVillageDetail:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(villageDetailMultiplier: defaultValue))
            case .musicVolume:
                settings.updating(musicVolume: defaultValue)
            case .radioCompanionScale:
                settings.updating(radioCompanionScale: defaultValue)
            case .ambientVolume:
                settings.updating(ambientSoundVolume: defaultValue)
            case .plantDarkening:
                settings
            }
        }
    }

    @objc private func toggleAmbientSound(_ sender: NSSwitch) {
        let isEnabled = sender.state == .on
        store.updateSettings(store.state.settings.updating(isAmbientSoundEnabled: isEnabled))
    }

    @objc private func toggleWindSound(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(isWindSoundEnabled: sender.state == .on))
    }

    @objc private func toggleRainSound(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(isRainSoundEnabled: sender.state == .on))
    }

    @objc private func toggleBirdsong(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(isBirdsongEnabled: sender.state == .on))
    }

    @objc private func toggleCricketSound(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(isCricketSoundEnabled: sender.state == .on))
    }

    @objc private func togglePlantNewPlantsAtMaturity(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(plantNewPlantsAtMaturity: sender.state == .on))
    }

    @objc private func toggleCozyMode(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(cozyModeEnabled: sender.state == .on))
    }

    @objc private func toggleAutoLowPower(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(autoLowPowerOnBattery: sender.state == .on))
    }

    @objc private func toggleAIGeneratedLockSnapshot(_ sender: NSSwitch) {
        if sender.state == .on, !GardenEntitlements.shared.isUnlocked(.aiLockView) {
            sender.state = .off
            showProFeatureAlert(.aiLockView)
            return
        }
        store.updateSettings(store.state.settings.updating(useAIGeneratedLockSnapshot: sender.state == .on))
    }

    @objc private func toggleAssistantMenuItem(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(isAssistantMenuItemEnabled: sender.state == .on))
    }

    @objc private func toggleCatChatOnClick(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(isCatChatOnClickEnabled: sender.state == .on))
    }

    @objc private func toggleGnomeSocieties(_ sender: NSSwitch) {
        let settings = store.state.settings
        store.updateSettings(settings.updating(
            gnomeSimulation: settings.gnomeSimulation.updating(isEnabled: sender.state == .on)
        ))
    }

    @objc private func timeLapseCadenceChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let cadence = GardenTimeLapseCadence(rawValue: rawValue) else {
            return
        }
        store.updateSettings(store.state.settings.updating(timeLapseCadence: cadence))
    }

    @objc private func performanceModeChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let mode = GardenPerformanceMode(rawValue: rawValue) else {
            return
        }
        let settings = store.state.settings
        store.updateSettings(settings.updating(
            wildlifeDensityMultiplier: min(settings.wildlifeDensityMultiplier, mode == .still ? 0.45 : settings.wildlifeDensityMultiplier),
            wildlifeSpeedMultiplier: min(settings.wildlifeSpeedMultiplier, mode == .still ? 0.65 : settings.wildlifeSpeedMultiplier),
            bugSizeMultiplier: min(settings.bugSizeMultiplier, mode == .still ? 0.85 : settings.bugSizeMultiplier),
            birdCountMultiplier: min(settings.birdCountMultiplier, mode == .still ? 0.50 : settings.birdCountMultiplier),
            performanceMode: mode
        ))
    }

    @objc private func experienceModeChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let mode = GardenExperienceMode(rawValue: rawValue) else {
            return
        }
        if let feature = Self.proFeature(for: mode),
           !GardenEntitlements.shared.isUnlocked(feature) {
            showProFeatureAlert(feature)
            renderSelectedSection(preservingScroll: true)
            return
        }
        switchExperienceMode(to: mode)
    }

    private func switchExperienceMode(to mode: GardenExperienceMode) {
        guard store.state.settings.experienceMode != mode else {
            return
        }

        let nextSettings = store.state.settings.updating(experienceMode: mode)
        if let handoffKey = GardenExperienceModeScenePolicy.sceneHandoffKey(
            currentSceneKey: wallpaperManager.selectedWallpaperSceneKey,
            targetMode: mode
        ) {
            actions.applySceneWithSettings(handoffKey, nextSettings)
        } else {
            store.updateSettings(nextSettings)
        }
    }

    @objc private func displayBehaviorChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let behavior = GardenDisplayBehavior(rawValue: rawValue) else {
            return
        }
        store.updateSettings(store.state.settings.updating(displayBehavior: behavior))
    }

    @objc private func radioActivationModeChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let mode = GardenRadioActivationMode(rawValue: rawValue) else {
            return
        }
        store.updateSettings(store.state.settings.updating(radioActivationMode: mode))
    }

    @objc private func wallpaperGenerationQualityChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let quality = GardenWallpaperGenerationQuality(rawValue: rawValue) else {
            return
        }
        store.updateSettings(store.state.settings.updating(wallpaperGenerationQuality: quality))
    }

    @objc private func aiEditStrengthChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let strength = GardenAIEditStrength(rawValue: rawValue) else {
            return
        }
        store.updateSettings(store.state.settings.updating(aiEditStrength: strength))
    }

    @objc private func rareMomentsModeChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let mode = GardenRareMomentsMode(rawValue: rawValue) else {
            return
        }
        store.updateSettings(store.state.settings.updating(rareMomentsMode: mode))
    }

    @objc private func toggleNotifyCare(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(notifyCare: sender.state == .on))
    }

    @objc private func toggleNotifyWeather(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(notifyWeather: sender.state == .on))
    }

    @objc private func toggleNotifyRareMoments(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(notifyRareMoments: sender.state == .on))
    }

    @objc private func toggleNotifyFocus(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(notifyFocus: sender.state == .on))
    }

    @objc private func toggleNotifyHarvest(_ sender: NSSwitch) {
        store.updateSettings(store.state.settings.updating(notifyHarvest: sender.state == .on))
    }

    @objc private func applyDecorativeGardenPreset() {
        store.updateSettings(store.state.settings.updating(
            wildlifeDensityMultiplier: min(store.state.settings.wildlifeDensityMultiplier, 0.65),
            wildlifeSpeedMultiplier: min(store.state.settings.wildlifeSpeedMultiplier, 0.80),
            bugSizeMultiplier: min(store.state.settings.bugSizeMultiplier, 0.95),
            birdCountMultiplier: min(store.state.settings.birdCountMultiplier, 0.75),
            cozyModeEnabled: true,
            performanceMode: .balanced,
            rareMomentsMode: .quiet,
            notifyCare: false,
            notifyHarvest: false
        ))
        renderSelectedSection(preservingScroll: true)
    }

    @objc private func applyCalmDesktopMode() {
        store.updateSettings(store.state.settings.updating(
            wildlifeDensityMultiplier: 0.35,
            wildlifeSpeedMultiplier: 0.55,
            bugSizeMultiplier: 0.75,
            birdCountMultiplier: 0.50,
            performanceMode: .still,
            rareMomentsMode: .quiet
        ))
        renderSelectedSection(preservingScroll: true)
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        guard let rawValue = sender.identifier?.rawValue,
              let id = SliderID(rawValue: rawValue) else {
            return
        }

        if id == .plantDarkening {
            updateSceneVisualsDebounced { [weak self] in
                self?.store.setManualPlantDarkening(sender.doubleValue, persist: false)
            }
            return
        }

        updateSettingsDebounced { settings in
            switch id {
            case .growthSpeed:
                settings.updating(growthSpeedMultiplier: sender.doubleValue)
            case .waterUse:
                settings.updating(waterUseMultiplier: sender.doubleValue)
            case .defaultScale:
                settings.updating(defaultPlantScale: sender.doubleValue)
            case .wildlifeDensity:
                settings.updating(wildlifeDensityMultiplier: sender.doubleValue)
            case .wildlifeSpeed:
                settings.updating(wildlifeSpeedMultiplier: sender.doubleValue)
            case .bugSize:
                settings.updating(bugSizeMultiplier: sender.doubleValue)
            case .birdCount:
                settings.updating(birdCountMultiplier: sender.doubleValue)
            case .gnomePopulation:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(populationMultiplier: sender.doubleValue))
            case .gnomeTribeSize:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(tribeScaleMultiplier: sender.doubleValue))
            case .gnomeLiveliness:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(behaviorLiveliness: sender.doubleValue))
            case .gnomeBuildingSpeed:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(buildingSpeedMultiplier: sender.doubleValue))
            case .gnomeSettlementPace:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(settlementExpansionDays: sender.doubleValue))
            case .gnomeCooperation:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(cooperationMultiplier: sender.doubleValue))
            case .gnomePlantInteraction:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(plantInteractionMultiplier: sender.doubleValue))
            case .gnomeVillageDetail:
                settings.updating(gnomeSimulation: settings.gnomeSimulation.updating(villageDetailMultiplier: sender.doubleValue))
            case .musicVolume:
                settings.updating(musicVolume: sender.doubleValue)
            case .radioCompanionScale:
                settings.updating(radioCompanionScale: sender.doubleValue)
            case .ambientVolume:
                settings.updating(ambientSoundVolume: sender.doubleValue)
            case .plantDarkening:
                settings
            }
        }
    }

    @objc private func togglePaused(_ sender: NSSwitch) {
        store.setPaused(sender.state == .on)
    }

    @objc private func toggleWildlife(_ sender: NSSwitch) {
        store.setAmbientWildlifeEnabledForCurrentMode(sender.state == .on)
    }

    @objc private func toggleWeatherSync(_ sender: NSSwitch) {
        store.updateSettings(
            store.state.settings.updating(isWeatherSyncEnabled: sender.state == .on)
        )
    }

    @objc private func confirmDeleteTimeLapseFrames() {
        let alert = NSAlert()
        alert.messageText = "Delete time-lapse frames?"
        alert.informativeText = "This clears captured time-lapse images from disk. Your garden, scenes, and plants stay unchanged."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete Frames")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        GardenTimeLapseExporter.shared.recorder?.deleteAllFrames()
        renderSelectedSection(preservingScroll: true)
    }

    @objc private func confirmClearPromptHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear AI prompt history?"
        alert.informativeText = "This removes saved wallpaper and custom plant prompts from the reuse helpers. Generated images and plants stay unchanged."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        GardenAIPromptHistoryStore(directoryURL: store.persistence.directoryURL).deleteAll()
        renderSelectedSection(preservingScroll: true)
    }

    @objc private func pruneWallpaperCache() {
        wallpaperManager.pruneRenderedWallpaperCache(keepingNewest: 4)
        renderSelectedSection(preservingScroll: true)
    }

    @objc private func confirmDeleteGeneratedPlantAssets() {
        let summary = store.customPlantAssets.inventorySummary()
        let alert = NSAlert()
        alert.messageText = "Delete generated plant assets?"
        alert.informativeText = "This removes \(summary.storageSummary) from disk and removes any plants that depend on those custom assets. Bundled plants and wallpaper scenes stay unchanged."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete Assets")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        store.customPlantAssets.deleteAllAssets()
        store.removePlantsWithoutDisplayableAssets()
        renderSelectedSection(preservingScroll: true)
    }

    @objc private func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func openDesktopDockSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func openScreenSaverSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func showProFeatureAlert(_ feature: GardenProFeature) {
        let alert = NSAlert()
        alert.messageText = "\(feature.displayName) is a Pro feature"
        alert.informativeText = "\(feature.paywallMessage) Open Pricing & Pro from the main menu when you are ready to upgrade."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSSwitch) {
        let service = SMAppService.mainApp
        do {
            if sender.state == .on {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            sender.state = service.status == .enabled ? .on : .off
            let alert = NSAlert()
            alert.messageText = "Could not update login item"
            alert.informativeText = "\(error.localizedDescription)\n\nLaunch at login requires running the bundled app (Plant Wallpaper.app), not a bare debug binary."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc private func musicSourceChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let source = GardenMusicSource(rawValue: rawValue),
              source != store.state.settings.musicSource else {
            return
        }

        GardenRadioPlayer.shared.stop()
        store.updateSettings(store.state.settings.updating(musicSource: source))
        // The store-change notification re-renders the Audio section since the
        // rendered source no longer matches; no explicit re-render needed.
        if window?.isVisible != true {
            renderSelectedSection(preservingScroll: true)
        }
    }

    @objc private func radioCompanionChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let companion = GardenRadioCompanion(rawValue: rawValue) else {
            return
        }

        let wasPlaying = GardenRadioPlayer.shared.isPlaying
        if store.state.musicButton == nil {
            store.toggleMusicButton(
                screenIndex: 0,
                position: GardenPoint(x: 0.82, y: 0.72),
                companion: companion
            )
        } else {
            store.updateMusicButtonCompanion(companion)
        }
        if wasPlaying {
            GardenRadioPlayer.shared.playRadioStream(companion.stationStream(in: store.state.settings))
        }
        refreshDynamicContent()
    }

    @objc private func openRadioStationAssignment() {
        let alert = NSAlert()
        alert.messageText = "Assign a station to a radio companion"
        alert.informativeText = "Search Filtermusic's free station directory or paste a direct stream URL. A station can only be assigned to one companion."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Assign")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Reset to Default")

        let companionPopup = NSPopUpButton()
        for companion in GardenRadioCompanion.allCases {
            companionPopup.addItem(withTitle: companion.displayName)
            companionPopup.lastItem?.representedObject = companion.rawValue
        }
        companionPopup.selectItem(withTitle: currentRadioCompanion.displayName)

        let searchField = NSSearchField()
        searchField.placeholderString = "Search Filtermusic stations, genres, moods..."
        searchField.stringValue = currentRadioStream.displayName

        let searchButton = NSButton(title: "Search Filtermusic", target: self, action: #selector(searchFiltermusicStations))
        searchButton.bezelStyle = .rounded

        let resultsPopup = NSPopUpButton()
        resultsPopup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let customNameField = NSTextField()
        customNameField.placeholderString = "Optional custom station name"

        let customURLField = NSTextField()
        customURLField.placeholderString = "Optional direct stream URL, e.g. https://example.com/live.mp3"

        let statusLabel = smallLabel("Built-in stations are ready. Search pulls live Filtermusic matches.")
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        let searchRow = NSStackView(views: [searchField, searchButton])
        searchRow.orientation = .horizontal
        searchRow.spacing = 8
        searchField.widthAnchor.constraint(equalToConstant: 280).isActive = true

        let stack = NSStackView(views: [
            labeledControl(title: "Companion", control: companionPopup),
            searchRow,
            labeledControl(title: "Filtermusic result", control: resultsPopup),
            labeledControl(title: "Custom name", control: customNameField),
            labeledControl(title: "Custom stream URL", control: customURLField),
            statusLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.widthAnchor.constraint(equalToConstant: 480).isActive = true
        alert.accessoryView = stack

        radioAssignmentCompanionPopup = companionPopup
        radioAssignmentSearchField = searchField
        radioAssignmentResultsPopup = resultsPopup
        radioAssignmentCustomNameField = customNameField
        radioAssignmentCustomURLField = customURLField
        radioAssignmentStatusLabel = statusLabel
        populateRadioAssignmentResults(GardenRadioStation.allCases.map(\.stream))

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            assignSelectedRadioStream()
        case .alertThirdButtonReturn:
            resetSelectedRadioStreamAssignment()
        default:
            break
        }

        radioAssignmentCompanionPopup = nil
        radioAssignmentSearchField = nil
        radioAssignmentResultsPopup = nil
        radioAssignmentCustomNameField = nil
        radioAssignmentCustomURLField = nil
        radioAssignmentStatusLabel = nil
        radioAssignmentSearchResults = []
    }

    private func labeledControl(title: String, control: NSView) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [titleLabel, control])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        control.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    @objc private func searchFiltermusicStations() {
        let query = radioAssignmentSearchField?.stringValue ?? ""
        radioAssignmentStatusLabel?.stringValue = "Searching Filtermusic..."
        radioAssignmentResultsPopup?.removeAllItems()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let results = await FiltermusicStationSearchService.shared.search(query: query)
            self.populateRadioAssignmentResults(results)
            self.radioAssignmentStatusLabel?.stringValue = results.isEmpty
                ? "No station matches found. Paste a direct stream URL below."
                : "Found \(results.count) station\(results.count == 1 ? "" : "s")."
        }
    }

    private func populateRadioAssignmentResults(_ streams: [GardenRadioStream]) {
        radioAssignmentSearchResults = streams
        radioAssignmentResultsPopup?.removeAllItems()
        for stream in streams {
            radioAssignmentResultsPopup?.addItem(withTitle: stream.displayName)
            radioAssignmentResultsPopup?.lastItem?.representedObject = stream.id
        }
        if let currentItem = radioAssignmentResultsPopup?.itemArray.first(where: { item in
            (item.representedObject as? String) == currentRadioStream.id
        }) {
            radioAssignmentResultsPopup?.select(currentItem)
        }
    }

    private func selectedAssignmentCompanion() -> GardenRadioCompanion {
        guard let rawValue = radioAssignmentCompanionPopup?.selectedItem?.representedObject as? String,
              let companion = GardenRadioCompanion(rawValue: rawValue) else {
            return currentRadioCompanion
        }
        return companion
    }

    private func selectedAssignmentStream() -> GardenRadioStream? {
        let customURLString = radioAssignmentCustomURLField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !customURLString.isEmpty {
            guard let url = URL(string: customURLString),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme) else {
                showRadioAssignmentError("That custom stream URL needs to start with http:// or https://.")
                return nil
            }
            let customName = radioAssignmentCustomNameField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let displayName = customName.isEmpty
                ? (url.host ?? "Custom Radio Stream")
                : customName
            return GardenRadioStream(
                id: "custom:\(url.absoluteString.lowercased())",
                displayName: displayName,
                streamURLStrings: [url.absoluteString],
                filtermusicPageURLString: nil,
                shortDescription: "Custom user-added stream.",
                isBuiltIn: false
            )
        }

        guard let selectedID = radioAssignmentResultsPopup?.selectedItem?.representedObject as? String else {
            return nil
        }
        return radioAssignmentSearchResults.first { $0.id == selectedID }
    }

    private func assignSelectedRadioStream() {
        let companion = selectedAssignmentCompanion()
        guard let stream = selectedAssignmentStream() else {
            return
        }

        let oldStream = companion.stationStream(in: store.state.settings)
        guard let settings = store.state.settings.assigningRadioStream(stream, to: companion) else {
            let owner = store.state.settings.companionAlreadyAssigned(to: stream, excluding: companion)?.displayName
                ?? "another companion"
            showRadioAssignmentError("\(stream.displayName) is already assigned to \(owner). Pick a different station first.")
            return
        }

        store.updateSettings(settings)
        if GardenRadioPlayer.shared.playingRadioStream?.id == oldStream.id {
            GardenRadioPlayer.shared.playRadioStream(stream)
        }
        refreshDynamicContent()
    }

    private func resetSelectedRadioStreamAssignment() {
        let companion = selectedAssignmentCompanion()
        var overrides = store.state.settings.radioCompanionStationOverrides
        overrides.removeValue(forKey: companion.rawValue)
        store.updateSettings(store.state.settings.updating(radioCompanionStationOverrides: overrides))
        refreshDynamicContent()
    }

    private func showRadioAssignmentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Station not assigned"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func toggleMusicButton(_ sender: NSSwitch) {
        let shouldShow = sender.state == .on
        let isShowing = store.state.musicButton != nil
        guard shouldShow != isShowing else {
            return
        }

        let existingPosition = store.state.musicButton?.position ?? GardenPoint(x: 0.82, y: 0.72)
        let existingScreenIndex = store.state.musicButton?.screenIndex ?? 0
        let companion = currentRadioCompanion
        store.toggleMusicButton(screenIndex: existingScreenIndex, position: existingPosition, companion: companion)
        if !shouldShow {
            GardenRadioPlayer.shared.stop()
        }
    }


    @objc private func applyCustomScene(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue.replacingOccurrences(of: "apply-", with: ""),
              !key.isEmpty else {
            return
        }

        actions.applyScene(key)
        refreshDynamicContent()
    }

    @objc private func deleteCustomScene(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue.replacingOccurrences(of: "delete-", with: ""),
              let record = wallpaperManager.customWallpapers.first(where: { $0.key == key }) else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Delete \"\(record.displayName)\"?"
        alert.informativeText = "This removes the scene image and its saved plant placements. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete Scene")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        do {
            let wasSelected = try wallpaperManager.deleteCustomWallpaper(key: key)
            // Remove the scene's saved garden so its plant data doesn't linger.
            let gardenFileURL = store.persistence.fileURL(forSceneKey: key)
            try? FileManager.default.removeItem(at: gardenFileURL)

            if wasSelected {
                actions.applyScene(GardenWallpaperScene.defaultScene.rawValue)
            }
            renderSelectedSection(preservingScroll: true)
        } catch {
            let errorAlert = NSAlert()
            errorAlert.messageText = "Could not delete scene"
            errorAlert.informativeText = error.localizedDescription
            errorAlert.alertStyle = .warning
            errorAlert.addButton(withTitle: "OK")
            errorAlert.runModal()
        }
    }

    @objc private func harvestReadyCrops() {
        store.harvestAllReadyCrops()
    }

    @objc private func exportTimeLapse() {
        GardenTimeLapseExporter.shared.exportInteractively(store: store)
    }

    @objc private func saveShareCardFromSettings() {
        let panel = NSSavePanel()
        panel.title = "Save Share Card"
        panel.nameFieldStringValue = "My Plant Wallpaper Garden.png"
        panel.allowedContentTypes = [.png]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try GardenShareCardRenderer.writeCardPNG(
                state: store.state,
                sceneKey: store.activeSceneKey,
                to: url
            )
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSLog("Plant Wallpaper could not save share card: \(error.localizedDescription)")
        }
    }

    @objc private func saveHealthCheckFromSettings() {
        actions.saveHealthCheck()
    }

    @objc private func showWelcomeTourFromSettings() {
        actions.showWelcomeTour()
    }

    @objc private func waterThirstyPlants() {
        store.waterThirstyPlants()
    }

    @objc private func waterAll() {
        store.waterAll()
    }

    @objc private func arrangeGarden() {
        actions.arrangeGarden()
    }

    @objc private func chooseWallpaper() {
        actions.chooseWallpaper()
    }

    @objc private func createAIWallpaper() {
        actions.createAIWallpaper()
    }

    @objc private func openAPIKeySettings() {
        actions.openAPIKeySettings()
        refreshDynamicContent()
    }

    @objc private func openElevenLabsAPIKeySettings() {
        ElevenLabsAPIKeySettingsPresenter.present()
        refreshDynamicContent()
    }

    @objc private func reapplyScene() {
        actions.reapplyScene()
    }

    @objc private func restorePreviousWallpaper() {
        actions.restorePreviousWallpaper()
    }

    @objc private func confirmResetGarden() {
        let alert = NSAlert()
        alert.messageText = "Reset this scene's garden?"
        alert.informativeText = "All plants in the active scene are replaced with the default garden. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset Garden")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        actions.resetGarden()
    }

    @objc private func deleteAllPlantsInScene() {
        actions.deleteAllPlantsInScene()
    }

    @objc private func toggleRadioPlayback() {
        GardenRadioPlayer.shared.toggleRadioStream(currentRadioStream)
        refreshDynamicContent()
    }

    @objc private func toggleSpotifyPlayback() {
        if GardenRadioPlayer.shared.isPlaying {
            GardenRadioPlayer.shared.stop()
        } else {
            saveSpotifyLink()
            GardenRadioPlayer.shared.playSpotify(using: store.state.settings)
        }
        refreshDynamicContent()
    }

    @objc private func openRadioStation() {
        if let url = currentRadioStream.filtermusicPageURL {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func saveSpotifyLink() {
        updateSpotifyLink(spotifyURLTextField?.stringValue ?? "")
    }

    private func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              textField.identifier?.rawValue == "spotifyLaunchURL" else {
            return
        }

        updateSpotifyLink(textField.stringValue)
    }

    private func updateSpotifyLink(_ rawValue: String) {
        let settings = store.state.settings.updating(spotifyLaunchURLString: rawValue)
        store.updateSettings(settings)
        if spotifyURLTextField?.currentEditor() == nil {
            spotifyURLTextField?.stringValue = settings.spotifyLaunchURLString
        }
    }

    @objc private func openGardenData() {
        NSWorkspace.shared.activateFileViewerSelecting([store.activeGardenFileURL])
    }

    @objc private func openAppDataFolder() {
        NSWorkspace.shared.open(store.persistence.directoryURL)
    }

    @objc private func openWallpaperDataFolder() {
        NSWorkspace.shared.open(wallpaperManager.wallpaperDataDirectoryURL)
    }

    @objc private func openAIWallpaperFolder() {
        NSWorkspace.shared.open(wallpaperManager.aiWallpaperDataDirectoryURL)
    }

    @objc private func openCustomWallpaperFolder() {
        NSWorkspace.shared.open(wallpaperManager.customWallpaperDataDirectoryURL)
    }

    @objc private func openPlantAssets() {
        if let assetsURL = Bundle.appResources.resourceURL?.appendingPathComponent("PlantAssets", isDirectory: true),
           FileManager.default.fileExists(atPath: assetsURL.path) {
            NSWorkspace.shared.open(assetsURL)
        } else if let resourceURL = Bundle.appResources.resourceURL {
            NSWorkspace.shared.open(resourceURL)
        }
    }
}

private extension NSView {
    /// An empty, freely compressible view used to push row content apart.
    static func spacer() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        spacer.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        return spacer
    }
}
