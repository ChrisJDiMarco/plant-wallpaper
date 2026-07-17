import AppKit
import PlantGardenCore

@MainActor
final class AutoGardenerSetupPanelController: NSWindowController {
    private let store: GardenStore
    private let onDone: () -> Void
    private let onAutoPlant: () -> Void
    private let countLabel = NSTextField(labelWithString: "")
    private let autoPlantButton = NSButton(title: "Auto-Plant", target: nil, action: nil)
    private let rowsDocumentView = NSView()
    private let rowsStack = NSStackView()
    private var storeObserver: NSObjectProtocol?

    init(
        store: GardenStore,
        onDone: @escaping () -> Void,
        onAutoPlant: @escaping () -> Void
    ) {
        self.store = store
        self.onDone = onDone
        self.onAutoPlant = onAutoPlant

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 500),
            styleMask: [.titled, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Auto Gardener"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .windowBackgroundColor
        panel.minSize = NSSize(width: 520, height: 420)

        super.init(window: panel)
        buildContent()
        refresh()
        storeObserver = NotificationCenter.default.addObserver(
            forName: .gardenStoreDidChange,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        MainActor.assumeIsolated {
            removeStoreObserver()
        }
    }

    override func close() {
        removeStoreObserver()
        super.close()
    }

    private func removeStoreObserver() {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
            self.storeObserver = nil
        }
    }

    func showNearStatusItem() {
        refresh()
        if let buttonWindow = NSApp.windows.first(where: { $0.className.contains("StatusBar") }),
           let window {
            let origin = NSPoint(x: buttonWindow.frame.minX, y: buttonWindow.frame.minY - window.frame.height - 10)
            window.setFrameOrigin(origin)
        } else if let screen = NSScreen.main, let window {
            window.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - window.frame.width / 2,
                y: screen.visibleFrame.maxY - window.frame.height - 80
            ))
        }
        showWindow(nil)
        window?.orderFrontRegardless()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else {
            return
        }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        header.addArrangedSubview(symbolBadge())

        let headerText = NSStackView()
        headerText.orientation = .vertical
        headerText.spacing = 3
        headerText.addArrangedSubview(label("Plan plantable areas", size: 22, weight: .semibold))
        headerText.addArrangedSubview(label(
            "Tune each highlighted spot before Auto-Plant fills the scene.",
            size: 13,
            weight: .regular,
            color: .secondaryLabelColor
        ))
        header.addArrangedSubview(headerText)
        headerText.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(header)

        countLabel.font = .systemFont(ofSize: 13, weight: .medium)
        countLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(sectionHeader())

        rowsStack.orientation = .vertical
        rowsStack.spacing = 10
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        rowsDocumentView.translatesAutoresizingMaskIntoConstraints = false
        rowsDocumentView.addSubview(rowsStack)

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .allowed
        scrollView.documentView = rowsDocumentView
        scrollView.heightAnchor.constraint(equalToConstant: 290).isActive = true
        stack.addArrangedSubview(scrollView)

        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 10
        buttonStack.addArrangedSubview(NSView())

        let done = NSButton(title: "Done", target: self, action: #selector(doneClicked))
        done.bezelStyle = .rounded
        done.controlSize = .large
        done.widthAnchor.constraint(equalToConstant: 108).isActive = true
        autoPlantButton.target = self
        autoPlantButton.action = #selector(autoPlantClicked)
        autoPlantButton.bezelStyle = .rounded
        autoPlantButton.controlSize = .large
        autoPlantButton.keyEquivalent = "\r"
        autoPlantButton.bezelColor = .systemGreen
        autoPlantButton.widthAnchor.constraint(equalToConstant: 132).isActive = true
        buttonStack.addArrangedSubview(done)
        buttonStack.addArrangedSubview(autoPlantButton)
        stack.addArrangedSubview(buttonStack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            rowsDocumentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            rowsDocumentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: rowsDocumentView.leadingAnchor, constant: 2),
            rowsStack.trailingAnchor.constraint(equalTo: rowsDocumentView.trailingAnchor, constant: -8),
            rowsStack.topAnchor.constraint(equalTo: rowsDocumentView.topAnchor, constant: 2),
            rowsStack.bottomAnchor.constraint(equalTo: rowsDocumentView.bottomAnchor, constant: -2)
        ])
    }

    private func sectionHeader() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.addArrangedSubview(label("Highlighted spots", size: 13, weight: .semibold, color: .secondaryLabelColor))
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(countLabel)
        return row
    }

    private func refresh() {
        let zones = store.state.autoGardenerZones
        countLabel.stringValue = "\(zones.count) area\(zones.count == 1 ? "" : "s")"
        autoPlantButton.isEnabled = !zones.isEmpty
        autoPlantButton.toolTip = zones.isEmpty
            ? "Draw an Auto Gardener area first."
            : "Plant the highlighted areas with the selected hints."

        rowsStack.arrangedSubviews.forEach { view in
            rowsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard !zones.isEmpty else {
            rowsStack.addArrangedSubview(emptyState())
            return
        }

        for (index, zone) in zones.enumerated() {
            rowsStack.addArrangedSubview(row(for: zone, index: index))
        }
    }

    private func row(for zone: AutoGardenerZone, index: Int) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.78).cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor

        let centroid = zone.centroid
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        row.addArrangedSubview(numberBadge(index + 1))

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 3
        textStack.addArrangedSubview(label(
            "Area \(index + 1)",
            size: 13,
            weight: .semibold
        ))
        textStack.addArrangedSubview(label(
            "\(Int(centroid.x * 100))% across, \(Int(centroid.y * 100))% down",
            size: 11,
            weight: .regular,
            color: .secondaryLabelColor
        ))
        let picks = zone.recommendedSpecies(sceneKey: store.activeSceneKey)
            .prefix(3)
            .map(\.displayName)
            .joined(separator: ", ")
        textStack.addArrangedSubview(label(
            "Best picks: \(picks)",
            size: 11,
            weight: .regular,
            color: .secondaryLabelColor
        ))
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(textStack)

        let controls = NSStackView()
        controls.orientation = .vertical
        controls.spacing = 6
        controls.alignment = .trailing

        let placement = NSPopUpButton(frame: .zero, pullsDown: false)
        placement.identifier = NSUserInterfaceItemIdentifier(zone.id.uuidString)
        placement.controlSize = .small
        for type in AutoGardenerPlacementType.allCases {
            placement.addItem(withTitle: type.displayName)
            placement.lastItem?.representedObject = type.rawValue
        }
        placement.selectItem(withTitle: zone.placementType.displayName)
        placement.target = self
        placement.action = #selector(placementChanged(_:))
        placement.widthAnchor.constraint(equalToConstant: 190).isActive = true
        controls.addArrangedSubview(placement)

        let size = NSPopUpButton(frame: .zero, pullsDown: false)
        size.identifier = NSUserInterfaceItemIdentifier(zone.id.uuidString)
        size.controlSize = .small
        for option in AutoGardenerSize.allCases {
            size.addItem(withTitle: option.displayName)
            size.lastItem?.representedObject = option.rawValue
        }
        size.selectItem(withTitle: zone.size.displayName)
        size.target = self
        size.action = #selector(sizeChanged(_:))
        size.widthAnchor.constraint(equalToConstant: 190).isActive = true
        controls.addArrangedSubview(size)
        row.addArrangedSubview(controls)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 92)
        ])
        return card
    }

    private func emptyState() -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        stack.addArrangedSubview(symbolBadge())
        stack.addArrangedSubview(label("Draw on the wallpaper to add plantable spots.", size: 13, weight: .medium))
        stack.addArrangedSubview(label(
            "Small pots, shelves, beds, and open patches will appear here.",
            size: 11,
            weight: .regular,
            color: .secondaryLabelColor
        ))

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
            stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -16)
        ])
        return card
    }

    private func label(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight,
        color: NSColor = .labelColor
    ) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.maximumNumberOfLines = 2
        return field
    }

    private func numberBadge(_ number: Int) -> NSView {
        let badge = NSTextField(labelWithString: "\(number)")
        badge.alignment = .center
        badge.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        badge.textColor = .systemGreen
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 16
        badge.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.13).cgColor
        badge.widthAnchor.constraint(equalToConstant: 32).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return badge
    }

    private func symbolBadge() -> NSView {
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 18
        badge.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.14).cgColor

        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: nil)
        imageView.contentTintColor = .systemGreen
        imageView.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(imageView)

        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 36),
            badge.heightAnchor.constraint(equalToConstant: 36),
            imageView.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 17),
            imageView.heightAnchor.constraint(equalToConstant: 17)
        ])
        return badge
    }

    @objc private func placementChanged(_ sender: NSPopUpButton) {
        guard let id = sender.identifier.flatMap({ UUID(uuidString: $0.rawValue) }),
              let rawValue = sender.selectedItem?.representedObject as? String,
              let placementType = AutoGardenerPlacementType(rawValue: rawValue) else {
            return
        }
        store.updateAutoGardenerZone(id: id, placementType: placementType)
    }

    @objc private func sizeChanged(_ sender: NSPopUpButton) {
        guard let id = sender.identifier.flatMap({ UUID(uuidString: $0.rawValue) }),
              let rawValue = sender.selectedItem?.representedObject as? String,
              let size = AutoGardenerSize(rawValue: rawValue) else {
            return
        }
        store.updateAutoGardenerZone(id: id, size: size)
    }

    @objc private func doneClicked() {
        close()
        onDone()
    }

    @objc private func autoPlantClicked() {
        guard !store.state.autoGardenerZones.isEmpty else {
            NSSound.beep()
            return
        }

        close()
        onAutoPlant()
    }
}
