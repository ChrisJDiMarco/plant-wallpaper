import AppKit
import PlantGardenCore

/// The gardener profile panel. Shows the local identity (name + avatar), the
/// current plan, and a few garden stats, with quick jumps to pricing and
/// settings. There is no account server — this is a local profile.
@MainActor
final class GardenProfileWindowController: NSObject {
    private let store: GardenStore
    private let profileStore: GardenProfileStore
    private let onManagePlan: () -> Void
    private let onOpenSettings: () -> Void

    private var window: NSWindow?
    private weak var nameField: NSTextField?
    private weak var avatarImageView: NSImageView?
    private weak var planBadgeContainer: NSView?
    private weak var planBadgeLabel: NSTextField?
    private weak var planDetailLabel: NSTextField?
    private weak var managePlanButton: NSButton?
    private weak var statsHost: NSStackView?
    private var avatarButtons: [NSButton] = []
    private var entitlementsObserver: NSObjectProtocol?
    private var windowDelegate: MainActorWindowDelegate?
    private var nameFieldDelegate: MainActorTextFieldDelegate?

    private static let memberSinceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    init(
        store: GardenStore,
        profileStore: GardenProfileStore = GardenProfileStore(),
        onManagePlan: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.store = store
        self.profileStore = profileStore
        self.onManagePlan = onManagePlan
        self.onOpenSettings = onOpenSettings
        super.init()
        entitlementsObserver = NotificationCenter.default.addObserver(
            forName: .gardenEntitlementsDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.entitlementsDidChange()
            }
        }
    }

    func show() {
        if let window {
            refreshStats()
            refreshPlanViews()
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.minSize = NSSize(width: 520, height: 520)
        let windowDelegate = MainActorWindowDelegate { [weak self] _ in
            self?.windowWillClose()
        }
        self.windowDelegate = windowDelegate
        panel.delegate = windowDelegate

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        panel.contentView = effectView

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 22
        root.edgeInsets = NSEdgeInsets(top: 30, left: 30, bottom: 26, right: 30)
        root.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            root.topAnchor.constraint(equalTo: effectView.topAnchor),
            root.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
        ])

        root.addArrangedSubview(headerView())
        root.addArrangedSubview(avatarPickerView())

        let statsHost = NSStackView()
        statsHost.orientation = .horizontal
        statsHost.alignment = .top
        statsHost.distribution = .fillEqually
        statsHost.spacing = 12
        statsHost.translatesAutoresizingMaskIntoConstraints = false
        statsHost.widthAnchor.constraint(equalToConstant: 500).isActive = true
        self.statsHost = statsHost
        root.addArrangedSubview(statsHost)

        root.addArrangedSubview(footerView())

        refreshStats()
        refreshPlanViews()

        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window = panel
    }

    // MARK: - Sections

    private func headerView() -> NSView {
        let avatar = NSImageView()
        avatar.image = NSImage(systemSymbolName: profileStore.avatarSymbol, accessibilityDescription: "Avatar")?
            .withSymbolConfiguration(.init(pointSize: 34, weight: .semibold))
        avatar.contentTintColor = .systemGreen
        avatar.wantsLayer = true
        avatar.layer?.cornerRadius = 36
        avatar.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.16).cgColor
        avatar.imageAlignment = .alignCenter
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.widthAnchor.constraint(equalToConstant: 72).isActive = true
        avatar.heightAnchor.constraint(equalToConstant: 72).isActive = true
        avatarImageView = avatar

        let eyebrow = NSTextField(labelWithString: "YOUR PROFILE")
        eyebrow.font = .systemFont(ofSize: 11, weight: .bold)
        eyebrow.textColor = .systemGreen

        let nameField = NSTextField(string: profileStore.displayName)
        nameField.font = .systemFont(ofSize: 24, weight: .bold)
        nameField.textColor = .labelColor
        nameField.isBordered = false
        nameField.drawsBackground = false
        nameField.focusRingType = .none
        let nameFieldDelegate = MainActorTextFieldDelegate { [weak self] event in
            self?.controlTextDidEndEditing(event.notification)
        }
        self.nameFieldDelegate = nameFieldDelegate
        nameField.delegate = nameFieldDelegate
        nameField.placeholderString = GardenProfile.defaultDisplayName
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.widthAnchor.constraint(equalToConstant: 360).isActive = true
        self.nameField = nameField

        let editHint = NSTextField(labelWithString: "Click your name to rename")
        editHint.font = .systemFont(ofSize: 11)
        editHint.textColor = .tertiaryLabelColor

        let memberSince = NSTextField(labelWithString: "Gardening since \(Self.memberSinceFormatter.string(from: store.state.createdAt))")
        memberSince.font = .systemFont(ofSize: 12)
        memberSince.textColor = .secondaryLabelColor

        let planBadge = makePlanBadge()

        let textStack = NSStackView(views: [eyebrow, nameField, editHint, memberSince, planBadge])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 5
        textStack.setCustomSpacing(8, after: editHint)

        let header = NSStackView(views: [avatar, textStack])
        header.orientation = .horizontal
        header.alignment = .top
        header.spacing = 16
        header.widthAnchor.constraint(equalToConstant: 500).isActive = true
        return header
    }

    private func makePlanBadge() -> NSView {
        let badgeLabel = NSTextField(labelWithString: "")
        badgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.alignment = .center
        planBadgeLabel = badgeLabel

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 24).isActive = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            badgeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            badgeLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        planBadgeContainer = container

        let detail = NSTextField(labelWithString: "")
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        planDetailLabel = detail

        let row = NSStackView(views: [container, detail])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func avatarPickerView() -> NSView {
        let label = NSTextField(labelWithString: "Avatar")
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        avatarButtons = GardenProfile.avatarSymbols.enumerated().map { index, symbol in
            let button = NSButton(title: "", target: self, action: #selector(selectAvatar(_:)))
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.tag = index
            button.wantsLayer = true
            button.layer?.cornerRadius = 8
            button.imagePosition = .imageOnly
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: symbol)?
                .withSymbolConfiguration(.init(pointSize: 16, weight: .medium))
            button.widthAnchor.constraint(equalToConstant: 38).isActive = true
            button.heightAnchor.constraint(equalToConstant: 38).isActive = true
            buttons.addArrangedSubview(button)
            return button
        }
        refreshAvatarSelection()

        let stack = NSStackView(views: [label, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }

    private func footerView() -> NSView {
        let manage = NSButton(title: "Manage Plan", target: self, action: #selector(managePlan))
        manage.bezelStyle = .rounded
        manage.keyEquivalent = "\r"
        managePlanButton = manage

        let settings = NSButton(title: "Open Settings", target: self, action: #selector(openSettings))
        settings.bezelStyle = .rounded

        let close = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        close.bezelStyle = .rounded

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let footer = NSStackView(views: [settings, spacer, close, manage])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 12
        footer.widthAnchor.constraint(equalToConstant: 500).isActive = true
        return footer
    }

    private func statTile(value: String, caption: String, accent: NSColor) -> NSView {
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        valueLabel.textColor = accent

        let captionLabel = NSTextField(wrappingLabelWithString: caption)
        captionLabel.font = .systemFont(ofSize: 12, weight: .regular)
        captionLabel.textColor = .secondaryLabelColor
        captionLabel.maximumNumberOfLines = 2

        let card = NSStackView(views: [valueLabel, captionLabel])
        card.orientation = .vertical
        card.alignment = .leading
        card.spacing = 4
        card.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        card.wantsLayer = true
        card.layer?.cornerRadius = 12
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.82).cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = accent.withAlphaComponent(0.2).cgColor
        card.heightAnchor.constraint(equalToConstant: 92).isActive = true
        return card
    }

    // MARK: - Refresh

    private func refreshStats() {
        guard let statsHost else {
            return
        }
        statsHost.arrangedSubviews.forEach { view in
            statsHost.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let plants = store.state.plants
        let speciesVariety = Set(plants.map(\.species)).count
        let focusStats = store.state.focusStats

        statsHost.addArrangedSubview(statTile(
            value: "\(plants.count)",
            caption: "Plants growing",
            accent: .systemGreen
        ))
        statsHost.addArrangedSubview(statTile(
            value: "\(speciesVariety)",
            caption: "Species variety",
            accent: .systemTeal
        ))
        statsHost.addArrangedSubview(statTile(
            value: "\(focusStats?.completedSessions ?? 0)",
            caption: "Focus sessions",
            accent: .systemIndigo
        ))
        statsHost.addArrangedSubview(statTile(
            value: "\(focusStats?.totalFocusMinutes ?? 0)",
            caption: "Focus minutes",
            accent: .systemPurple
        ))
    }

    private func refreshPlanViews() {
        let entitlements = GardenEntitlements.shared
        let isPro = entitlements.isPro
        let accent: NSColor = isPro ? .systemIndigo : .systemGreen

        planBadgeLabel?.stringValue = isPro ? "PRO — FULL ACCESS" : "FREE"
        planBadgeLabel?.textColor = accent
        planBadgeContainer?.layer?.backgroundColor = accent.withAlphaComponent(0.16).cgColor
        planDetailLabel?.stringValue = entitlements.sourceDescription
        managePlanButton?.title = isPro ? "Manage Plan" : "Upgrade to Pro"

        avatarImageView?.contentTintColor = accent
        avatarImageView?.layer?.backgroundColor = accent.withAlphaComponent(0.16).cgColor
    }

    private func refreshAvatarSelection() {
        let current = profileStore.avatarSymbol
        for (index, button) in avatarButtons.enumerated() {
            let symbol = GardenProfile.avatarSymbols[index]
            let isSelected = symbol == current
            button.layer?.backgroundColor = isSelected
                ? NSColor.systemGreen.withAlphaComponent(0.18).cgColor
                : NSColor.clear.cgColor
            button.contentTintColor = isSelected ? .systemGreen : .secondaryLabelColor
        }
    }

    // MARK: - Actions

    @objc private func selectAvatar(_ sender: NSButton) {
        guard GardenProfile.avatarSymbols.indices.contains(sender.tag) else {
            return
        }
        let symbol = GardenProfile.avatarSymbols[sender.tag]
        profileStore.avatarSymbol = symbol
        avatarImageView?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Avatar")?
            .withSymbolConfiguration(.init(pointSize: 34, weight: .semibold))
        refreshAvatarSelection()
    }

    @objc private func managePlan() {
        onManagePlan()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func closeWindow() {
        window?.close()
    }

    private func entitlementsDidChange() {
        refreshPlanViews()
    }
    private func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === nameField else {
            return
        }
        profileStore.displayName = field.stringValue
        field.stringValue = profileStore.displayName
    }

    private func windowWillClose() {
        if let nameField {
            profileStore.displayName = nameField.stringValue
        }
        window = nil
        windowDelegate = nil
        nameFieldDelegate = nil
    }
}
