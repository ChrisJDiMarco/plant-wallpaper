import AppKit

/// A pop-out editor for a single wallpaper scene: a large preview, version
/// navigation across every edit made to the scene, and a prompt box for
/// generating a new AI version. Presented as a sheet from the Settings window.
@MainActor
final class GardenSceneDetailWindowController: NSWindowController {
    struct Callbacks {
        /// Apply a specific version key as the live desktop scene.
        var applyVersion: (String) -> Void
        /// Generate a new AI version from the currently applied scene.
        var generateEdit: (String, @escaping (Result<Void, Error>) -> Void) -> Void
        /// Called after the sheet closes so the gallery can refresh.
        var onClose: () -> Void
    }

    private let wallpaperManager: WallpaperManager
    private let sceneRootKey: String
    private let sceneName: String
    private let callbacks: Callbacks

    private var versions: [WallpaperVersionEntry] = []
    private var viewedIndex = 0
    private var isGenerating = false
    private weak var parentWindow: NSWindow?

    private let previewImageView = NSImageView()
    private let versionLabel = NSTextField(labelWithString: "")
    private let previousButton = NSButton()
    private let nextButton = NSButton()
    private let applyButton = NSButton()
    private let appliedBadge = NSTextField(labelWithString: "Now showing")
    private let promptField = NSTextField()
    private let generateButton = NSButton()
    private let progressIndicator = NSProgressIndicator()
    private let statusLabel = NSTextField(labelWithString: "")

    init(
        wallpaperManager: WallpaperManager,
        sceneRootKey: String,
        sceneName: String,
        callbacks: Callbacks
    ) {
        self.wallpaperManager = wallpaperManager
        self.sceneRootKey = wallpaperManager.wallpaperSceneRootKey(for: sceneRootKey)
        self.sceneName = sceneName
        self.callbacks = callbacks

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = sceneName
        super.init(window: window)

        buildLayout()
        reloadVersions(selecting: wallpaperManager.selectedWallpaperSceneKey)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(over parentWindow: NSWindow) {
        self.parentWindow = parentWindow
        guard let window else {
            return
        }
        parentWindow.beginSheet(window) { [weak self] _ in
            self?.callbacks.onClose()
        }
    }

    // MARK: - Layout

    private func buildLayout() {
        guard let content = window?.contentView else {
            return
        }

        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.cornerRadius = 12
        previewImageView.layer?.cornerCurve = .continuous
        previewImageView.layer?.masksToBounds = true
        previewImageView.layer?.borderWidth = 1
        previewImageView.layer?.borderColor = NSColor.separatorColor.cgColor
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.heightAnchor.constraint(equalToConstant: 372).isActive = true

        configureNavButton(previousButton, symbol: "chevron.left", action: #selector(showPreviousVersion))
        configureNavButton(nextButton, symbol: "chevron.right", action: #selector(showNextVersion))

        versionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        versionLabel.alignment = .center
        versionLabel.lineBreakMode = .byTruncatingTail
        versionLabel.maximumNumberOfLines = 1
        versionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        versionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        appliedBadge.font = .systemFont(ofSize: 11, weight: .semibold)
        appliedBadge.textColor = .systemGreen
        appliedBadge.alignment = .center

        applyButton.title = "Use This Version"
        applyButton.bezelStyle = .rounded
        applyButton.target = self
        applyButton.action = #selector(applyViewedVersion)
        applyButton.setContentHuggingPriority(.required, for: .horizontal)

        let versionRow = NSStackView(views: [previousButton, versionLabel, nextButton, applyButton])
        versionRow.orientation = .horizontal
        versionRow.alignment = .centerY
        versionRow.spacing = 10
        versionRow.translatesAutoresizingMaskIntoConstraints = false

        let promptTitle = NSTextField(labelWithString: "Make a new version with AI")
        promptTitle.font = .systemFont(ofSize: 13, weight: .semibold)

        let promptHint = NSTextField(wrappingLabelWithString: "Describe a change or a whole new take. A fresh version is created and applied — your earlier versions stay available with the arrows.")
        promptHint.font = .systemFont(ofSize: 11.5)
        promptHint.textColor = .secondaryLabelColor

        promptField.placeholderString = "e.g. add warm sunset light and a stone fountain"
        promptField.font = .systemFont(ofSize: 13)
        promptField.lineBreakMode = .byTruncatingTail
        promptField.target = self
        promptField.action = #selector(generateNewVersion)
        promptField.translatesAutoresizingMaskIntoConstraints = false
        promptField.heightAnchor.constraint(equalToConstant: 30).isActive = true

        generateButton.title = "Generate"
        generateButton.bezelStyle = .rounded
        generateButton.keyEquivalent = "\r"
        generateButton.target = self
        generateButton.action = #selector(generateNewVersion)
        generateButton.setContentHuggingPriority(.required, for: .horizontal)

        let promptRow = NSStackView(views: [promptField, generateButton])
        promptRow.orientation = .horizontal
        promptRow.alignment = .centerY
        promptRow.spacing = 10
        promptRow.translatesAutoresizingMaskIntoConstraints = false

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 11.5)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.maximumNumberOfLines = 1
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let statusRow = NSStackView(views: [progressIndicator, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 8

        let doneButton = NSButton(title: "Done", target: self, action: #selector(closeSheet))
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\u{1b}"

        let footerRow = NSStackView(views: [statusRow, NSView.detailSpacer(), doneButton])
        footerRow.orientation = .horizontal
        footerRow.alignment = .centerY

        let column = NSStackView(views: [
            previewImageView,
            versionRow,
            appliedBadge,
            separatorLine(),
            promptTitle,
            promptHint,
            promptRow,
            footerRow
        ])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false
        column.setHuggingPriority(.defaultLow, for: .horizontal)
        content.addSubview(column)

        NSLayoutConstraint.activate([
            // Pin a fixed content width so no label (a long version name or a
            // long error message) can ever stretch the window past the screen.
            content.widthAnchor.constraint(equalToConstant: 720),
            column.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            column.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            column.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            previewImageView.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            versionRow.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            versionRow.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            promptHint.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            promptHint.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            promptRow.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            promptRow.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            footerRow.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            footerRow.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            appliedBadge.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            appliedBadge.trailingAnchor.constraint(equalTo: column.trailingAnchor)
        ])
    }

    private func configureNavButton(_ button: NSButton, symbol: String, action: Selector) {
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        button.imagePosition = .imageOnly
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func separatorLine() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        line.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        return line
    }

    // MARK: - State

    private func reloadVersions(selecting preferredKey: String?) {
        versions = wallpaperManager.wallpaperVersions(forSceneKey: sceneRootKey)
        if versions.isEmpty {
            versions = [WallpaperVersionEntry(
                key: sceneRootKey,
                title: sceneName,
                tooltip: sceneName,
                createdAt: nil,
                isOriginal: true
            )]
        }
        if let preferredKey, let index = versions.firstIndex(where: { $0.key == preferredKey }) {
            viewedIndex = index
        } else {
            viewedIndex = 0
        }
        updateForViewedVersion()
    }

    private func updateForViewedVersion() {
        let safeIndex = min(max(0, viewedIndex), versions.count - 1)
        viewedIndex = safeIndex
        let entry = versions[safeIndex]

        previewImageView.image = wallpaperManager.thumbnailImage(forSceneKey: entry.key)

        let position = "Version \(versions.count - safeIndex) of \(versions.count)"
        let descriptor = entry.isOriginal ? "Original" : entry.title
        versionLabel.stringValue = "\(position) · \(descriptor)"
        versionLabel.toolTip = entry.tooltip

        previousButton.isEnabled = !isGenerating && safeIndex < versions.count - 1
        nextButton.isEnabled = !isGenerating && safeIndex > 0

        let isApplied = entry.key == wallpaperManager.selectedWallpaperSceneKey
        appliedBadge.isHidden = !isApplied
        applyButton.isHidden = isApplied
        applyButton.isEnabled = !isGenerating
    }

    private func setGenerating(_ generating: Bool, status: String) {
        isGenerating = generating
        statusLabel.stringValue = status
        statusLabel.toolTip = status.isEmpty ? nil : status
        promptField.isEnabled = !generating
        generateButton.isEnabled = !generating
        if generating {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
        updateForViewedVersion()
    }

    // MARK: - Actions

    @objc private func showPreviousVersion() {
        guard !isGenerating else { return }
        viewedIndex += 1
        updateForViewedVersion()
    }

    @objc private func showNextVersion() {
        guard !isGenerating else { return }
        viewedIndex -= 1
        updateForViewedVersion()
    }

    @objc private func applyViewedVersion() {
        guard !isGenerating, versions.indices.contains(viewedIndex) else { return }
        callbacks.applyVersion(versions[viewedIndex].key)
        updateForViewedVersion()
    }

    @objc private func generateNewVersion() {
        guard !isGenerating else { return }
        let prompt = promptField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            statusLabel.stringValue = "Type what you'd like changed first."
            return
        }

        // Edit from whatever version is on screen, so "generate" acts on what
        // the user is looking at rather than whatever happens to be applied.
        if versions.indices.contains(viewedIndex),
           versions[viewedIndex].key != wallpaperManager.selectedWallpaperSceneKey {
            callbacks.applyVersion(versions[viewedIndex].key)
        }

        setGenerating(true, status: "Generating a new version… this can take a minute.")
        callbacks.generateEdit(prompt) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.promptField.stringValue = ""
                self.setGenerating(false, status: "New version applied.")
                self.reloadVersions(selecting: self.wallpaperManager.selectedWallpaperSceneKey)
            case .failure(let error):
                if error is CancellationError {
                    self.setGenerating(false, status: "Generation cancelled.")
                    return
                }
                self.setGenerating(false, status: error.localizedDescription)
            }
        }
    }

    @objc private func closeSheet() {
        guard let window, let parentWindow else {
            return
        }
        parentWindow.endSheet(window)
    }

    // MARK: - Self-test hooks

    func versionCountForSelfTest() -> Int {
        versions.count
    }

    func viewedVersionKeyForSelfTest() -> String {
        versions[viewedIndex].key
    }

    func showPreviousVersionForSelfTest() {
        showPreviousVersion()
    }

    func showNextVersionForSelfTest() {
        showNextVersion()
    }
}

private extension NSView {
    static func detailSpacer() -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return spacer
    }
}
