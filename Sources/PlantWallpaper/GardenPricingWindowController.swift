import AppKit
import PlantGardenCore

/// The "Pricing & Pro" page. Renders the Free and Pro tiers as clickable cards
/// with a call-to-action button on each. Choosing Pro unlocks full access
/// locally on this Mac immediately (the hook a real checkout would replace);
/// choosing Free returns to the free tier. Reflects and updates the live
/// entitlement state.
@MainActor
final class GardenPricingWindowController: NSObject {
    private let onOpenAPIKeySettings: () -> Void

    private var window: NSWindow?
    private weak var titleLabel: NSTextField?
    private weak var subtitleLabel: NSTextField?
    private weak var currentPlanLabel: NSTextField?
    private weak var freeCTAButton: NSButton?
    private weak var proCTAButton: NSButton?

    private static let cardWidth: CGFloat = 312
    private static let contentWidth: CGFloat = 648

    init(onOpenAPIKeySettings: @escaping () -> Void) {
        self.onOpenAPIKeySettings = onOpenAPIKeySettings
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(entitlementsDidChange),
            name: .gardenEntitlementsDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show(lockedFeature: GardenProFeature? = nil) {
        if window == nil {
            buildWindow()
        }
        applyHeadline(lockedFeature: lockedFeature)
        refreshPlanState()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 708, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.minSize = NSSize(width: 700, height: 540)
        panel.delegate = self

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        panel.contentView = effectView

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.edgeInsets = NSEdgeInsets(top: 28, left: 30, bottom: 24, right: 30)
        root.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            root.topAnchor.constraint(equalTo: effectView.topAnchor),
            root.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
        ])

        let title = label(GardenPricingCatalog.title, font: .systemFont(ofSize: 26, weight: .bold), color: .labelColor, lines: 1)
        titleLabel = title

        let subtitle = label(GardenPricingCatalog.subtitle, font: .systemFont(ofSize: 13), color: .secondaryLabelColor, lines: 3)
        subtitle.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true
        subtitleLabel = subtitle

        let currentPlan = label("", font: .systemFont(ofSize: 12, weight: .semibold), color: .secondaryLabelColor, lines: 1)
        currentPlanLabel = currentPlan

        let freeCTA = ctaButton(action: #selector(chooseFree))
        freeCTAButton = freeCTA
        let proCTA = ctaButton(action: #selector(choosePro))
        proCTAButton = proCTA

        let tierRow = NSStackView(views: [
            card(GardenPricingCatalog.free, accent: .systemGreen, isPrimary: false, cta: freeCTA),
            card(GardenPricingCatalog.pro, accent: .systemIndigo, isPrimary: true, cta: proCTA)
        ])
        tierRow.orientation = .horizontal
        tierRow.alignment = .top
        tierRow.distribution = .fillEqually
        tierRow.spacing = 16
        tierRow.translatesAutoresizingMaskIntoConstraints = false
        tierRow.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true

        let footer = label(GardenPricingCatalog.footer, font: .systemFont(ofSize: 11.5), color: .tertiaryLabelColor, lines: 3)
        footer.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true

        root.addArrangedSubview(title)
        root.addArrangedSubview(subtitle)
        root.addArrangedSubview(currentPlan)
        root.addArrangedSubview(tierRow)
        root.addArrangedSubview(footer)
        root.addArrangedSubview(actionRow())

        window = panel
    }

    // MARK: - Sections

    private func actionRow() -> NSView {
        let apiKey = NSButton(title: "API Key Settings", target: self, action: #selector(openAPIKeySettings))
        apiKey.bezelStyle = .rounded

        let done = NSButton(title: "Done", target: self, action: #selector(closeWindow))
        done.bezelStyle = .rounded

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [apiKey, spacer, done])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true
        return row
    }

    private func card(_ tier: GardenPricingTier, accent: NSColor, isPrimary: Bool, cta: NSButton) -> NSView {
        let card = NSStackView()
        card.orientation = .vertical
        card.alignment = .leading
        card.spacing = 9
        card.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.backgroundColor = isPrimary
            ? accent.withAlphaComponent(0.13).cgColor
            : NSColor.controlBackgroundColor.withAlphaComponent(0.82).cgColor
        card.layer?.borderWidth = isPrimary ? 1.4 : 1
        card.layer?.borderColor = accent.withAlphaComponent(isPrimary ? 0.55 : 0.22).cgColor

        let name = label(tier.name, font: .systemFont(ofSize: 18, weight: .semibold), color: .labelColor, lines: 1)
        let header = NSStackView(views: [name, spacerView(), badge(tier.badge, accent: accent)])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalToConstant: Self.cardWidth - 32).isActive = true

        let price = label(tier.price, font: .systemFont(ofSize: 22, weight: .bold), color: accent, lines: 1)
        let summary = label(tier.summary, font: .systemFont(ofSize: 12), color: .secondaryLabelColor, lines: 2)

        card.addArrangedSubview(header)
        card.addArrangedSubview(price)
        card.addArrangedSubview(summary)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: Self.cardWidth - 32).isActive = true
        card.addArrangedSubview(divider)

        for feature in tier.features {
            card.addArrangedSubview(featureRow(feature, accent: accent))
        }

        card.addArrangedSubview(spacerView())
        cta.translatesAutoresizingMaskIntoConstraints = false
        cta.widthAnchor.constraint(equalToConstant: Self.cardWidth - 32).isActive = true
        card.addArrangedSubview(cta)

        card.translatesAutoresizingMaskIntoConstraints = false
        card.widthAnchor.constraint(equalToConstant: Self.cardWidth).isActive = true
        card.heightAnchor.constraint(equalToConstant: 318).isActive = true
        return card
    }

    private func ctaButton(action: Selector) -> NSButton {
        let button = NSButton(title: "", target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .large
        return button
    }

    private func featureRow(_ text: String, accent: NSColor) -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Included")
        icon.symbolConfiguration = .init(pointSize: 13, weight: .semibold)
        icon.contentTintColor = accent
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let textLabel = label(text, font: .systemFont(ofSize: 11.5), color: .labelColor, lines: 3)
        let row = NSStackView(views: [icon, textLabel])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 7
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: Self.cardWidth - 32).isActive = true
        textLabel.widthAnchor.constraint(equalToConstant: Self.cardWidth - 59).isActive = true
        return row
    }

    private func badge(_ text: String, accent: NSColor) -> NSView {
        let badgeLabel = label(text, font: .systemFont(ofSize: 10, weight: .semibold), color: accent, lines: 1)
        badgeLabel.alignment = .center

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.backgroundColor = accent.withAlphaComponent(0.14).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        container.widthAnchor.constraint(equalToConstant: max(72, CGFloat(text.count * 7 + 18))).isActive = true
        container.heightAnchor.constraint(equalToConstant: 22).isActive = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            badgeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            badgeLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    private func label(_ text: String, font: NSFont, color: NSColor, lines: Int) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = lines
        return label
    }

    private func spacerView() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    // MARK: - State

    private func applyHeadline(lockedFeature: GardenProFeature?) {
        if let lockedFeature {
            titleLabel?.stringValue = "\(lockedFeature.displayName) is a Pro feature"
            subtitleLabel?.stringValue = "\(lockedFeature.paywallMessage) \(GardenPricingCatalog.subtitle)"
        } else {
            titleLabel?.stringValue = GardenPricingCatalog.title
            subtitleLabel?.stringValue = GardenPricingCatalog.subtitle
        }
    }

    private func refreshPlanState() {
        let entitlements = GardenEntitlements.shared
        let isPro = entitlements.isPro
        currentPlanLabel?.stringValue = "Current plan: \(entitlements.tier.displayName) — \(entitlements.sourceDescription)"

        if let freeCTAButton {
            freeCTAButton.title = isPro ? "Switch to Free" : "Current plan"
            freeCTAButton.isEnabled = isPro
            freeCTAButton.keyEquivalent = ""
        }
        if let proCTAButton {
            proCTAButton.title = isPro ? "Current plan" : "Get Pro — Full Access"
            proCTAButton.isEnabled = !isPro
            proCTAButton.keyEquivalent = isPro ? "" : "\r"
        }
    }

    // MARK: - Actions

    @objc private func choosePro() {
        GardenEntitlements.shared.unlockProLocally()
        refreshPlanState()
    }

    @objc private func chooseFree() {
        GardenEntitlements.shared.selectFreeLocally()
        refreshPlanState()
    }

    @objc private func openAPIKeySettings() {
        onOpenAPIKeySettings()
    }

    @objc private func closeWindow() {
        window?.close()
    }

    @objc private func entitlementsDidChange() {
        refreshPlanState()
    }
}

extension GardenPricingWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
