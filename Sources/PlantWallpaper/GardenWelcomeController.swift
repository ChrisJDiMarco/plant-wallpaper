import AppKit
import PlantGardenCore

struct GardenWelcomeFeature: Equatable {
    var symbolName: String
    var title: String
    var detail: String
}

struct GardenWelcomeSlide: Equatable {
    var id: String
    var symbolName: String
    var artwork: GardenWelcomeArtwork.Kind
    var eyebrow: String
    var title: String
    var body: String
    var accent: NSColor
    var features: [GardenWelcomeFeature]

    static let catalog: [GardenWelcomeSlide] = [
        GardenWelcomeSlide(
            id: "start",
            symbolName: "leaf.fill",
            artwork: .desktopGarden,
            eyebrow: "The basics",
            title: "Your desktop is a living garden",
            body: "Plant Wallpaper adds a quiet, living layer over macOS. Click a plant to inspect it, drag plants into place, and double-click a plant to water it.",
            accent: .systemGreen,
            features: [
                GardenWelcomeFeature(symbolName: "cursorarrow.click", title: "Click to inspect", detail: "Health, hydration, care actions, companion effects, and growth forecasts all open in the plant inspector."),
                GardenWelcomeFeature(symbolName: "hand.draw.fill", title: "Drag to arrange", detail: "Plants, radio companions, and custom objects stay exactly where you place them in each scene."),
                GardenWelcomeFeature(symbolName: "plus.viewfinder", title: "Plant anywhere", detail: "Double-click any empty desktop spot to open a Plant Here menu and add plants right where you clicked."),
                GardenWelcomeFeature(symbolName: "hand.raised.fill", title: "Clicks work everywhere", detail: "Reaching plants over other windows uses macOS Input Monitoring. It only watches mouse clicks, never keystrokes — and it's optional.")
            ]
        ),
        GardenWelcomeSlide(
            id: "control",
            symbolName: "lock.fill",
            artwork: .deskControl,
            eyebrow: "Everyday control",
            title: "Use your Mac normally anytime",
            body: "Want plain Mac clicks back? Click the leaf icon in your menu bar and choose Lock Garden Interactions — it sits right under Pause.",
            accent: .systemBlue,
            features: [
                GardenWelcomeFeature(symbolName: "lock.fill", title: "Lock interactions", detail: "Locking makes every click pass straight through to your desktop and apps. The scene keeps living underneath; unlock to play again."),
                GardenWelcomeFeature(symbolName: "pause.circle.fill", title: "Pause anytime", detail: "Pause freezes growth and motion so your desktop holds perfectly still whenever you want calm."),
                GardenWelcomeFeature(symbolName: "arrow.uturn.backward.circle.fill", title: "Your wallpaper is safe", detail: "Your previous desktop wallpaper is saved. Restore it from Settings or Wallpaper & Scenes ▸ Restore Previous Wallpaper."),
                GardenWelcomeFeature(symbolName: "power", title: "Quit when you like", detail: "Quit from the same menu. The leaf icon is always in your menu bar to bring everything back.")
            ]
        ),
        GardenWelcomeSlide(
            id: "game-loop",
            symbolName: "sparkles",
            artwork: .gameLoop,
            eyebrow: "Game loop",
            title: "Grow, harvest, focus, repeat",
            body: "The garden changes over time. Harvest edibles, collect seeds from mature plants, and earn visible growth from focus sessions.",
            accent: .systemMint,
            features: [
                GardenWelcomeFeature(symbolName: "basket.fill", title: "Harvest crops", detail: "Tomatoes, peppers, herbs, peas, beans, cucumbers and more cycle through regrowth you can harvest."),
                GardenWelcomeFeature(symbolName: "seedling", title: "Collect seeds", detail: "Pruning and harvesting mature plants unlocks seeds for a slower, from-scratch planting loop."),
                GardenWelcomeFeature(symbolName: "timer", title: "Focus sessions", detail: "Start a focus timer from the menu and earn a growth boost for real garden progress."),
                GardenWelcomeFeature(symbolName: "chart.line.uptrend.xyaxis", title: "Progression Mode", detail: "Opt into a 20-level fantasy arc that upgrades your scene as your garden thrives.")
            ]
        ),
        GardenWelcomeSlide(
            id: "create",
            symbolName: "wand.and.stars",
            artwork: .create,
            eyebrow: "Creation tools",
            title: "Make it yours with scenes and AI",
            body: "Switch scenes with the menu arrows or the gallery, generate new AI wallpapers, restyle the current one, or create your own plant assets.",
            accent: .systemPurple,
            features: [
                GardenWelcomeFeature(symbolName: "photo.on.rectangle.angled", title: "Wallpaper scenes", detail: "Move through built-in and custom scenes with the left/right arrows or the scene gallery."),
                GardenWelcomeFeature(symbolName: "wand.and.stars", title: "AI wallpapers", detail: "Create a wallpaper from a prompt, or Update Current Wallpaper to restyle it. Roll back from Wallpaper Versions."),
                GardenWelcomeFeature(symbolName: "paintbrush.pointed.fill", title: "Custom assets", detail: "Generate transparent PNG plants or room objects with the built-in chroma-key cutout pipeline."),
                GardenWelcomeFeature(symbolName: "key.fill", title: "Bring your own AI key", detail: "AI features use your own OpenAI key — a paid OpenAI account, billed per image. Add it once; it's stored in your Keychain.")
            ]
        ),
        GardenWelcomeSlide(
            id: "worlds",
            symbolName: "bed.double.fill",
            artwork: .worlds,
            eyebrow: "More worlds",
            title: "Room Studio and alien worlds",
            body: "Switch the whole experience from Garden to Room Studio or Alien/UFO using the Mode menu. Room Studio and Alien are Pro features.",
            accent: .systemIndigo,
            features: [
                GardenWelcomeFeature(symbolName: "bed.double.fill", title: "Room Studio", detail: "Decorate cozy bedrooms, loft hangouts, and media dens with placeable objects instead of plants."),
                GardenWelcomeFeature(symbolName: "sparkles", title: "Alien gardens", detail: "Grow otherworldly species inside glowing domes, terrariums, and orbital sanctuaries."),
                GardenWelcomeFeature(symbolName: "crown.fill", title: "Free vs Pro", detail: "Check exactly what's included on the Pricing & Pro screen in the menu before you start.")
            ]
        ),
        GardenWelcomeSlide(
            id: "companions",
            symbolName: "cat.fill",
            artwork: .companions,
            eyebrow: "Ambient life",
            title: "Companions, sound, and societies",
            body: "Your desktop can host a 3D cat, realistic bugs, environmental soundscapes, radio companions, and gnome tribes in painted habitat zones.",
            accent: .systemOrange,
            features: [
                GardenWelcomeFeature(symbolName: "cat.fill", title: "3D cat companion", detail: "The cat watches your cursor, swats, climbs, and rests near the Dock. Click it to chat (toggle off in Settings)."),
                GardenWelcomeFeature(symbolName: "radio.fill", title: "Radio companions", detail: "Place music objects, assign Filtermusic streams, and click them to play or stop a station."),
                GardenWelcomeFeature(symbolName: "figure.2.and.child.holdinghands", title: "Gnome tribes", detail: "Paint a habitat zone in Garden Tools and tiny builders, bards, and scouts settle in to live there."),
                GardenWelcomeFeature(symbolName: "sparkles.rectangle.stack.fill", title: "Jarvis Assistant", detail: "Ask the built-in assistant to tend, plant, or restyle your garden by text or voice.")
            ]
        ),
        GardenWelcomeSlide(
            id: "living-world",
            symbolName: "sun.max.fill",
            artwork: .livingWorld,
            eyebrow: "Living world",
            title: "Weather, time, and keepsakes",
            body: "Plants shift with the day, scenes can follow time-of-day artwork, sounds match the place, and real weather can water your plants.",
            accent: .systemTeal,
            features: [
                GardenWelcomeFeature(symbolName: "cloud.rain.fill", title: "Weather-aware", detail: "Real rain can water plants, play rain audio, and trigger rare post-rain rainbow moments."),
                GardenWelcomeFeature(symbolName: "moon.stars.fill", title: "Time-aware scenes", detail: "Plants and scenes shift through daylight, golden hour, night, and manual darkening."),
                GardenWelcomeFeature(symbolName: "film.stack.fill", title: "Keepsakes & screen saver", detail: "Save snapshots, share cards, and time-lapses — and optionally set your live garden as a macOS screen saver.")
            ]
        ),
        GardenWelcomeSlide(
            id: "control-center",
            symbolName: "slider.horizontal.3",
            artwork: .controlCenter,
            eyebrow: "Control center",
            title: "Comfort, privacy, and storage",
            body: "Settings is your command center: Cozy Mode, Performance Mode, calm options, time-lapse storage, OpenAI transparency, and cleanup tools.",
            accent: .systemPink,
            features: [
                GardenWelcomeFeature(symbolName: "leaf.arrow.triangle.circlepath", title: "Cozy or lively", detail: "Use Cozy Mode, Calm Desktop, rare moments, and wildlife settings to choose the vibe."),
                GardenWelcomeFeature(symbolName: "externaldrive.fill", title: "Storage & privacy", detail: "Manage generated assets, time-lapse frames, app data, and see exactly how your OpenAI key is used."),
                GardenWelcomeFeature(symbolName: "questionmark.circle", title: "Replay this tour", detail: "Reopen this welcome tour anytime from Help & Data, or ask the Jarvis Assistant to open it.")
            ]
        )
    ]
}

/// One-time first-run welcome tour. The modal is intentionally broader than
/// gesture help: it orients new users to the app's living desktop, everyday
/// controls (lock, pause, restore wallpaper), the game loop, AI tools, room and
/// alien modes, companions, sound, the living world, and settings — each slide
/// paired with a crafted illustration.
@MainActor
final class GardenWelcomeController {
    private static let hasShownDefaultsKey = "PlantWallpaper.hasShownWelcome"
    private static let bannerSize = NSSize(width: 512, height: 168)

    private let store: GardenStore
    private let defaults: UserDefaults
    private var window: NSWindow?
    private var currentSlideIndex = 0
    private weak var slideHost: NSStackView?
    private weak var pageLabel: NSTextField?
    private weak var previousButton: NSButton?
    private weak var nextButton: NSButton?
    private var dotButtons: [NSButton] = []
    private var sidebarButtons: [NSButton] = []

    init(store: GardenStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    func showIfFirstRun() {
        guard !defaults.bool(forKey: Self.hasShownDefaultsKey) else {
            return
        }

        defaults.set(true, forKey: Self.hasShownDefaultsKey)
        show()
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        currentSlideIndex = 0
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 736),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.minSize = NSSize(width: 820, height: 680)

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        panel.contentView = effectView

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 20
        root.edgeInsets = NSEdgeInsets(top: 32, left: 34, bottom: 24, right: 34)
        root.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            root.topAnchor.constraint(equalTo: effectView.topAnchor),
            root.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
        ])

        root.addArrangedSubview(headerView())
        let body = NSStackView()
        body.orientation = .horizontal
        body.alignment = .top
        body.spacing = 22
        body.translatesAutoresizingMaskIntoConstraints = false
        body.addArrangedSubview(sidebarView())

        let slideHost = NSStackView()
        slideHost.orientation = .vertical
        slideHost.alignment = .leading
        slideHost.spacing = 16
        slideHost.translatesAutoresizingMaskIntoConstraints = false
        slideHost.widthAnchor.constraint(greaterThanOrEqualToConstant: 512).isActive = true
        body.addArrangedSubview(slideHost)
        self.slideHost = slideHost
        root.addArrangedSubview(body)
        body.heightAnchor.constraint(greaterThanOrEqualToConstant: 500).isActive = true

        root.addArrangedSubview(footerView())
        refreshSlide()

        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window = panel
    }

    private func headerView() -> NSView {
        let icon = NSImageView()
        icon.image = Bundle.appResources.image(forResource: "AppIcon") ?? NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Plant Wallpaper")
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 54).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 54).isActive = true

        let title = NSTextField(labelWithString: "Welcome to Plant Wallpaper")
        title.font = .systemFont(ofSize: 27, weight: .bold)
        title.textColor = .labelColor
        title.lineBreakMode = .byWordWrapping

        let subtitle = NSTextField(wrappingLabelWithString: "A living desktop garden, wallpaper studio, and ambient companion layer for macOS. It all lives in the leaf icon in your menu bar — click it anytime for scenes, settings, and help.")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2

        let textStack = NSStackView(views: [title, subtitle])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        let header = NSStackView(views: [icon, textStack])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 14
        header.widthAnchor.constraint(greaterThanOrEqualToConstant: 760).isActive = true
        return header
    }

    private func sidebarView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.widthAnchor.constraint(equalToConstant: 196).isActive = true

        sidebarButtons = GardenWelcomeSlide.catalog.enumerated().map { index, slide in
            let button = NSButton(title: slide.eyebrow, target: self, action: #selector(selectSlide(_:)))
            button.bezelStyle = .shadowlessSquare
            button.isBordered = false
            button.alignment = .left
            button.tag = index
            button.image = NSImage(systemSymbolName: slide.symbolName, accessibilityDescription: slide.eyebrow)
            button.imagePosition = .imageLeading
            button.contentTintColor = .secondaryLabelColor
            button.heightAnchor.constraint(equalToConstant: 32).isActive = true
            stack.addArrangedSubview(button)
            return button
        }

        let hint = NSTextField(wrappingLabelWithString: "Replay this later from the menu's Help & Data ▸ Show Welcome Tour.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.maximumNumberOfLines = 3
        stack.addArrangedSubview(NSView.spacer(height: 4))
        stack.addArrangedSubview(hint)
        hint.widthAnchor.constraint(lessThanOrEqualToConstant: 176).isActive = true

        return stack
    }

    private func footerView() -> NSView {
        let previous = NSButton(title: "Back", target: self, action: #selector(previousSlide))
        previous.bezelStyle = .rounded
        previousButton = previous

        let dots = NSStackView()
        dots.orientation = .horizontal
        dots.spacing = 6
        dotButtons = GardenWelcomeSlide.catalog.indices.map { index in
            let dot = NSButton(title: " ", target: self, action: #selector(selectSlide(_:)))
            dot.bezelStyle = .circular
            dot.tag = index
            dot.widthAnchor.constraint(equalToConstant: 12).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 12).isActive = true
            dots.addArrangedSubview(dot)
            return dot
        }

        let pageLabel = NSTextField(labelWithString: "")
        pageLabel.font = .systemFont(ofSize: 12)
        pageLabel.textColor = .secondaryLabelColor
        self.pageLabel = pageLabel

        let plantButton = NSButton(title: "Plant a flower", target: self, action: #selector(plantFirstFlower))
        plantButton.bezelStyle = .rounded

        let next = NSButton(title: "Next", target: self, action: #selector(nextSlide))
        next.bezelStyle = .rounded
        next.keyEquivalent = "\r"
        nextButton = next

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let footer = NSStackView(views: [previous, dots, pageLabel, spacer, plantButton, next])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 12
        footer.widthAnchor.constraint(greaterThanOrEqualToConstant: 780).isActive = true
        return footer
    }

    private func refreshSlide() {
        guard let slideHost else {
            return
        }
        let slide = GardenWelcomeSlide.catalog[currentSlideIndex]
        slideHost.arrangedSubviews.forEach { view in
            slideHost.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        slideHost.addArrangedSubview(bannerView(slide))
        slideHost.addArrangedSubview(slideTextView(slide))

        let grid = NSGridView(views: slide.features.map(featureRow))
        grid.rowSpacing = 9
        grid.columnSpacing = 0
        grid.translatesAutoresizingMaskIntoConstraints = false
        slideHost.addArrangedSubview(grid)

        pageLabel?.stringValue = "\(currentSlideIndex + 1) of \(GardenWelcomeSlide.catalog.count)"
        previousButton?.isEnabled = currentSlideIndex > 0
        nextButton?.title = currentSlideIndex == GardenWelcomeSlide.catalog.count - 1 ? "Start exploring" : "Next"

        for (index, button) in dotButtons.enumerated() {
            button.state = index == currentSlideIndex ? .on : .off
            button.contentTintColor = index == currentSlideIndex ? slide.accent : .tertiaryLabelColor
        }
        for (index, button) in sidebarButtons.enumerated() {
            button.contentTintColor = index == currentSlideIndex ? slide.accent : .secondaryLabelColor
            button.font = .systemFont(ofSize: 13, weight: index == currentSlideIndex ? .semibold : .regular)
        }
    }

    private func bannerView(_ slide: GardenWelcomeSlide) -> NSView {
        let banner = NSImageView()
        banner.image = GardenWelcomeArtwork.image(for: slide.artwork, size: Self.bannerSize)
        banner.imageScaling = .scaleProportionallyUpOrDown
        banner.setAccessibilityLabel("\(slide.title) illustration")
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.widthAnchor.constraint(equalToConstant: Self.bannerSize.width).isActive = true
        banner.heightAnchor.constraint(equalToConstant: Self.bannerSize.height).isActive = true
        return banner
    }

    private func slideTextView(_ slide: GardenWelcomeSlide) -> NSView {
        let eyebrow = NSTextField(labelWithString: slide.eyebrow.uppercased())
        eyebrow.font = .systemFont(ofSize: 11, weight: .bold)
        eyebrow.textColor = slide.accent

        let title = NSTextField(wrappingLabelWithString: slide.title)
        title.font = .systemFont(ofSize: 23, weight: .bold)
        title.textColor = .labelColor
        title.maximumNumberOfLines = 2

        let body = NSTextField(wrappingLabelWithString: slide.body)
        body.font = .systemFont(ofSize: 13.5)
        body.textColor = .secondaryLabelColor
        body.maximumNumberOfLines = 3
        body.widthAnchor.constraint(lessThanOrEqualToConstant: 512).isActive = true

        let textStack = NSStackView(views: [eyebrow, title, body])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 5
        return textStack
    }

    private func featureRow(_ feature: GardenWelcomeFeature) -> [NSView] {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: feature.symbolName, accessibilityDescription: feature.title)?
            .withSymbolConfiguration(.init(pointSize: 17, weight: .medium))
        icon.contentTintColor = .secondaryLabelColor
        icon.widthAnchor.constraint(equalToConstant: 30).isActive = true

        let title = NSTextField(labelWithString: feature.title)
        title.font = .systemFont(ofSize: 13, weight: .semibold)

        let detail = NSTextField(wrappingLabelWithString: feature.detail)
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        detail.maximumNumberOfLines = 2
        detail.widthAnchor.constraint(lessThanOrEqualToConstant: 470).isActive = true

        let textStack = NSStackView(views: [title, detail])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1

        return [icon, textStack]
    }

    @objc private func selectSlide(_ sender: NSButton) {
        currentSlideIndex = min(max(0, sender.tag), GardenWelcomeSlide.catalog.count - 1)
        refreshSlide()
    }

    @objc private func previousSlide() {
        currentSlideIndex = max(0, currentSlideIndex - 1)
        refreshSlide()
    }

    @objc private func nextSlide() {
        guard currentSlideIndex < GardenWelcomeSlide.catalog.count - 1 else {
            dismiss()
            return
        }

        currentSlideIndex += 1
        refreshSlide()
    }

    @objc private func plantFirstFlower() {
        let environment = GardenScenePlantEnvironment(sceneKey: store.activeSceneKey)
        let species = PlantSpecies.flowers.filter {
            environment.isSuitable($0) && PlantAssetLibrary.shared.hasDisplayableAsset(for: $0)
        }.randomElement() ?? .tulip
        store.addPlant(species: species, screenIndex: 0)
        dismiss()
    }

    @objc private func dismiss() {
        window?.close()
        window = nil
    }
}

private extension NSView {
    static func spacer(height: CGFloat) -> NSView {
        let view = NSView()
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }
}
