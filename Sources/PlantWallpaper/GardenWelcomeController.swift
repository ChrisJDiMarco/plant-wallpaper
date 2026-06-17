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
    var eyebrow: String
    var title: String
    var body: String
    var accent: NSColor
    var features: [GardenWelcomeFeature]

    static let catalog: [GardenWelcomeSlide] = [
        GardenWelcomeSlide(
            id: "start",
            symbolName: "leaf.fill",
            eyebrow: "The basics",
            title: "Your desktop is a living garden",
            body: "Plant Wallpaper adds a quiet interactive layer to macOS. Click plants to inspect them, drag them into place, and double-click to water without leaving the desktop.",
            accent: .systemGreen,
            features: [
                GardenWelcomeFeature(symbolName: "cursorarrow.click", title: "Click to inspect", detail: "Health, hydration, care actions, companion effects, and growth forecasts live in the plant inspector."),
                GardenWelcomeFeature(symbolName: "hand.draw.fill", title: "Drag to arrange", detail: "Plants, radio companions, and custom objects stay where you place them in each scene."),
                GardenWelcomeFeature(symbolName: "drop.fill", title: "Water quickly", detail: "Double-click a plant or use Water All, thirsty-only watering, and Smart Care from the leaf menu.")
            ]
        ),
        GardenWelcomeSlide(
            id: "game-loop",
            symbolName: "sparkles",
            eyebrow: "Game loop",
            title: "Grow, harvest, focus, repeat",
            body: "The garden changes over time. Edibles can be harvested, mature plants can yield seeds, and focus sessions give visible growth rewards.",
            accent: .systemMint,
            features: [
                GardenWelcomeFeature(symbolName: "basket.fill", title: "Harvest crops", detail: "Tomatoes, peppers, herbs, peas, beans, cucumbers, and more can cycle through regrowth."),
                GardenWelcomeFeature(symbolName: "seedling", title: "Collect seeds", detail: "Pruning and harvesting mature plants can unlock seed planting for a slower from-scratch loop."),
                GardenWelcomeFeature(symbolName: "timer", title: "Focus sessions", detail: "Start a focus timer from the leaf menu and earn a growth boost for visible garden progress.")
            ]
        ),
        GardenWelcomeSlide(
            id: "create",
            symbolName: "wand.and.stars",
            eyebrow: "Creation tools",
            title: "Make the garden yours with scenes and AI",
            body: "Switch scenes, create AI wallpapers, update the current wallpaper with a prompt, or generate new plant assets from the Add New rows in plant menus.",
            accent: .systemPink,
            features: [
                GardenWelcomeFeature(symbolName: "photo.on.rectangle.angled", title: "Wallpaper scenes", detail: "Use the scene gallery or left/right arrows in the menu to move through built-in and custom scenes."),
                GardenWelcomeFeature(symbolName: "paintbrush.pointed.fill", title: "Custom assets", detail: "Generate transparent PNG plants or room objects with the app's chroma-key cutout pipeline."),
                GardenWelcomeFeature(symbolName: "bed.double.fill", title: "Room Studio", detail: "Switch from Garden mode to Room Studio to decorate bedrooms, hangout rooms, and media spaces.")
            ]
        ),
        GardenWelcomeSlide(
            id: "companions",
            symbolName: "cat.fill",
            eyebrow: "Ambient life",
            title: "Companions, sound, and tiny societies",
            body: "The desktop can host the 3D cat, realistic bug layers, environmental soundscapes, radio companions, and little gnome tribes that live in painted habitat zones.",
            accent: .systemOrange,
            features: [
                GardenWelcomeFeature(symbolName: "cat.fill", title: "3D cat companion", detail: "The cat watches the cursor, swats, climbs, rests near the Dock, and opens a chat panel when clicked."),
                GardenWelcomeFeature(symbolName: "radio.fill", title: "Radio companions", detail: "Place music objects, assign Filtermusic streams, and click them to play or stop a station."),
                GardenWelcomeFeature(symbolName: "figure.2.and.child.holdinghands", title: "Gnome tribes", detail: "Paint a habitat zone from Garden Tools and tiny builders, bards, climbers, and scouts will settle there.")
            ]
        ),
        GardenWelcomeSlide(
            id: "automation",
            symbolName: "sun.max.fill",
            eyebrow: "Living world",
            title: "Weather, time, screensaver, and memories",
            body: "Plants darken with the day, scenes can follow time-of-day artwork, environmental sounds match the place, and your current garden can appear as a macOS screen saver.",
            accent: .systemBlue,
            features: [
                GardenWelcomeFeature(symbolName: "cloud.rain.fill", title: "Weather-aware", detail: "Real rain can water plants, trigger rain audio, and create rare post-rain moments."),
                GardenWelcomeFeature(symbolName: "moon.stars.fill", title: "Time-aware scenes", detail: "Plants and scenes can shift through daylight, golden hour, night, and manual darkening."),
                GardenWelcomeFeature(symbolName: "film.stack.fill", title: "Keepsakes", detail: "Save snapshots, share cards, time-lapses, and use the screen saver to show the live garden.")
            ]
        ),
        GardenWelcomeSlide(
            id: "control",
            symbolName: "slider.horizontal.3",
            eyebrow: "Control center",
            title: "Tune comfort, privacy, performance, and storage",
            body: "Settings is the command center: Cozy Mode, Performance Mode, time-lapse storage, OpenAI transparency, radio behavior, screensaver status, and cleanup tools live there.",
            accent: .systemPurple,
            features: [
                GardenWelcomeFeature(symbolName: "leaf.arrow.triangle.circlepath", title: "Cozy or lively", detail: "Use Cozy Mode, Calm Desktop, rare moments, wildlife, and animation settings to choose the vibe."),
                GardenWelcomeFeature(symbolName: "lock.fill", title: "Lock interactions", detail: "Lock the garden when you want normal macOS clicks while the wallpaper keeps living underneath."),
                GardenWelcomeFeature(symbolName: "externaldrive.fill", title: "Storage and privacy", detail: "Manage generated assets, time-lapse frames, app data, OpenAI usage notes, and cleanup shortcuts.")
            ]
        )
    ]
}

/// One-time first-run welcome tour. The modal is intentionally broader than
/// gesture help: it orients new users to the app's living desktop, game loop,
/// AI tools, room mode, companions, sound, settings, and storage controls.
@MainActor
final class GardenWelcomeController {
    private static let hasShownDefaultsKey = "PlantWallpaper.hasShownWelcome"

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
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 640),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.minSize = NSSize(width: 760, height: 580)

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        panel.contentView = effectView

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 22
        root.edgeInsets = NSEdgeInsets(top: 34, left: 34, bottom: 26, right: 34)
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
        slideHost.spacing = 18
        slideHost.translatesAutoresizingMaskIntoConstraints = false
        slideHost.widthAnchor.constraint(greaterThanOrEqualToConstant: 510).isActive = true
        body.addArrangedSubview(slideHost)
        self.slideHost = slideHost
        root.addArrangedSubview(body)
        body.heightAnchor.constraint(greaterThanOrEqualToConstant: 420).isActive = true

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
        icon.widthAnchor.constraint(equalToConstant: 56).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let title = NSTextField(labelWithString: "Welcome to Plant Wallpaper")
        title.font = .systemFont(ofSize: 28, weight: .bold)
        title.textColor = .labelColor
        title.lineBreakMode = .byWordWrapping

        let subtitle = NSTextField(wrappingLabelWithString: "A living desktop garden, creative wallpaper studio, ambient companion layer, and tiny game loop for macOS.")
        subtitle.font = .systemFont(ofSize: 14)
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
        header.widthAnchor.constraint(greaterThanOrEqualToConstant: 720).isActive = true
        return header
    }

    private func sidebarView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.widthAnchor.constraint(equalToConstant: 190).isActive = true

        sidebarButtons = GardenWelcomeSlide.catalog.enumerated().map { index, slide in
            let button = NSButton(title: slide.eyebrow, target: self, action: #selector(selectSlide(_:)))
            button.bezelStyle = .shadowlessSquare
            button.isBordered = false
            button.alignment = .left
            button.tag = index
            button.image = NSImage(systemSymbolName: slide.symbolName, accessibilityDescription: slide.eyebrow)
            button.imagePosition = .imageLeading
            button.contentTintColor = .secondaryLabelColor
            button.heightAnchor.constraint(equalToConstant: 34).isActive = true
            stack.addArrangedSubview(button)
            return button
        }

        let hint = NSTextField(wrappingLabelWithString: "You can replay this later from Settings or Help & Data.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.maximumNumberOfLines = 3
        stack.addArrangedSubview(NSView.spacer(height: 4))
        stack.addArrangedSubview(hint)
        hint.widthAnchor.constraint(lessThanOrEqualToConstant: 170).isActive = true

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
        footer.widthAnchor.constraint(greaterThanOrEqualToConstant: 740).isActive = true
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

        let hero = slideHeroView(slide)
        slideHost.addArrangedSubview(hero)

        let grid = NSGridView(views: slide.features.map(featureRow))
        grid.rowSpacing = 10
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

    private func slideHeroView(_ slide: GardenWelcomeSlide) -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: slide.symbolName, accessibilityDescription: slide.title)?
            .withSymbolConfiguration(.init(pointSize: 40, weight: .semibold))
        icon.contentTintColor = slide.accent
        icon.widthAnchor.constraint(equalToConstant: 58).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 58).isActive = true

        let eyebrow = NSTextField(labelWithString: slide.eyebrow.uppercased())
        eyebrow.font = .systemFont(ofSize: 11, weight: .bold)
        eyebrow.textColor = slide.accent

        let title = NSTextField(wrappingLabelWithString: slide.title)
        title.font = .systemFont(ofSize: 26, weight: .bold)
        title.textColor = .labelColor
        title.maximumNumberOfLines = 2

        let body = NSTextField(wrappingLabelWithString: slide.body)
        body.font = .systemFont(ofSize: 14)
        body.textColor = .secondaryLabelColor
        body.maximumNumberOfLines = 4
        body.widthAnchor.constraint(lessThanOrEqualToConstant: 500).isActive = true

        let textStack = NSStackView(views: [eyebrow, title, body])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 7

        let stack = NSStackView(views: [icon, textStack])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = 16
        return stack
    }

    private func featureRow(_ feature: GardenWelcomeFeature) -> [NSView] {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: feature.symbolName, accessibilityDescription: feature.title)?
            .withSymbolConfiguration(.init(pointSize: 18, weight: .medium))
        icon.contentTintColor = .secondaryLabelColor
        icon.widthAnchor.constraint(equalToConstant: 32).isActive = true

        let title = NSTextField(labelWithString: feature.title)
        title.font = .systemFont(ofSize: 13, weight: .semibold)

        let detail = NSTextField(wrappingLabelWithString: feature.detail)
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        detail.maximumNumberOfLines = 2
        detail.widthAnchor.constraint(lessThanOrEqualToConstant: 455).isActive = true

        let textStack = NSStackView(views: [title, detail])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

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
