import AppKit
import PlantGardenCore

@MainActor
final class GnomeSettlementSetupPanelController: NSWindowController {
    private let store: GardenStore
    private let onDone: (UUID?) -> Void
    private let onCancel: () -> Void
    private let countLabel = NSTextField(labelWithString: "")
    private let startZonePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let timeframeSlider = NSSlider(
        value: GardenGnomeSimulationSettings.default.settlementExpansionDays,
        minValue: GnomeTribeSettlementPlan.minimumExpansionDurationDays,
        maxValue: GnomeTribeSettlementPlan.maximumExpansionDurationDays,
        target: nil,
        action: nil
    )
    private let timeframeValueLabel = NSTextField(labelWithString: "")
    private var storeObserver: NSObjectProtocol?

    init(
        store: GardenStore,
        onDone: @escaping (UUID?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.store = store
        self.onDone = onDone
        self.onCancel = onCancel

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 258),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Gnome Settlement"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .windowBackgroundColor

        super.init(window: panel)
        buildContent()
        refresh()
        storeObserver = NotificationCenter.default.addObserver(
            forName: .gardenStoreDidChange,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func close() {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
            self.storeObserver = nil
        }
        super.close()
    }

    var selectedStartingZoneID: UUID? {
        startZonePopup.selectedItem?.representedObject as? UUID
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
        contentView.layer?.cornerRadius = 18

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 22, bottom: 18, right: 22)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let title = NSTextField(labelWithString: "Outline every gnome living area")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .labelColor
        stack.addArrangedSubview(title)

        let subtitle = NSTextField(wrappingLabelWithString: "Drag on the wallpaper to mark each area. Click Done when all areas are drawn; the tribe starts in one area and tunnels outward over time.")
        subtitle.font = .systemFont(ofSize: 12, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        stack.addArrangedSubview(subtitle)

        countLabel.font = .systemFont(ofSize: 13, weight: .medium)
        countLabel.textColor = .labelColor
        stack.addArrangedSubview(countLabel)

        stack.addArrangedSubview(labeledRow(title: "Start in", control: startZonePopup))

        timeframeSlider.target = self
        timeframeSlider.action = #selector(timeframeChanged(_:))
        stack.addArrangedSubview(labeledRow(title: "Build out over", control: timeframeSlider, value: timeframeValueLabel))

        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually

        let cancel = NSButton(title: "Keep Draft", target: self, action: #selector(cancelClicked))
        cancel.bezelStyle = .rounded
        let done = NSButton(title: "Done, Start Tribe", target: self, action: #selector(doneClicked))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        buttonStack.addArrangedSubview(cancel)
        buttonStack.addArrangedSubview(done)
        stack.addArrangedSubview(buttonStack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func labeledRow(title: String, control: NSView, value: NSTextField? = nil) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.widthAnchor.constraint(equalToConstant: 88).isActive = true
        row.addArrangedSubview(label)
        row.addArrangedSubview(control)
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)

        if let value {
            value.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            value.textColor = .secondaryLabelColor
            value.alignment = .right
            value.widthAnchor.constraint(equalToConstant: 70).isActive = true
            row.addArrangedSubview(value)
        }

        return row
    }

    private func refresh() {
        let zones = store.state.gnomeTribeZones
        countLabel.stringValue = "\(zones.count) outlined area\(zones.count == 1 ? "" : "s")"

        let selectedID = selectedStartingZoneID ?? store.state.gnomeSettlementPlan.startingZoneID
        startZonePopup.removeAllItems()
        for (index, zone) in zones.enumerated() {
            startZonePopup.addItem(withTitle: "Area \(index + 1)")
            startZonePopup.lastItem?.representedObject = zone.id
        }
        if zones.isEmpty {
            startZonePopup.addItem(withTitle: "Draw an area first")
            startZonePopup.isEnabled = false
        } else {
            startZonePopup.isEnabled = true
            let selectedIndex = zones.firstIndex { $0.id == selectedID } ?? 0
            startZonePopup.selectItem(at: selectedIndex)
        }

        timeframeSlider.doubleValue = store.state.settings.gnomeSimulation.settlementExpansionDays
        updateTimeframeLabel()
    }

    @objc private func timeframeChanged(_ sender: NSSlider) {
        updateTimeframeLabel()
        let settings = store.state.settings
        store.updateSettings(settings.updating(
            gnomeSimulation: settings.gnomeSimulation.updating(settlementExpansionDays: sender.doubleValue)
        ))
    }

    @objc private func doneClicked() {
        guard !store.state.gnomeTribeZones.isEmpty else {
            NSSound.beep()
            return
        }

        close()
        onDone(selectedStartingZoneID)
    }

    @objc private func cancelClicked() {
        close()
        onCancel()
    }

    private func updateTimeframeLabel() {
        let days = timeframeSlider.doubleValue
        timeframeValueLabel.stringValue = days < 1
            ? "\(Int((days * 24).rounded())) hr"
            : "\(String(format: "%.1f", days)) d"
    }
}
