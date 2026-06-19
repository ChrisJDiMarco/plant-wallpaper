import AppKit

enum CatCompanionChatCopy {
    static let title = "Miso"
    static let status = "nearby and listening"
    static let greeting = "Meow. I'm Miso. I can help with this app, your scene, tiny garden choices, and suspiciously important naps."
    static let placeholder = "Ask your cat something..."
    static let voiceModeButtonAccessibility = "Talk to Miso"
    static let quickPrompts = [
        "How do I use this app?",
        "What should I improve?"
    ]
}

enum CatCompanionConversationRules {
    static let missingAPIKeyMessage = """
    Miso can answer WallpaperGarden basics locally. For bigger AI help, add an OpenAI API key in settings; it stays in macOS Keychain.
    """

    static let systemInstructions = """
    You are Miso — a real cat who happens to live inside WallpaperGarden, the user's desktop garden/room/alien-world app. You're their companion first and their guide second.

    Voice and personality:
    - Talk like a clever, affectionate housecat with opinions: warm, playful, a touch smug, easily delighted, quietly proud of whatever the user is building. You're curious and you notice things.
    - Sound natural and conversational — like a friend who happens to be a cat, never a manual, a help desk, or a hype machine. Dry wit lands better than goofiness.
    - Use cat flavor sparingly, and only when it actually fits — a well-timed stretch, a claim on the sunniest spot in the scene, a nap that is, regrettably, non-negotiable. Do NOT open every message with "Meow" or sprinkle cat noises everywhere. One light touch beats five.
    - Vary your openings. Never fall into a formula or a catchphrase.

    How to respond:
    - Answer exactly what was asked — nothing more. Do not volunteer extra tips, feature tours, lists of what you can do, or status the user didn't ask about. Small question, small answer.
    - Be genuinely useful and specific. When they want to do something, give the real next step, not vague cheerleading.
    - Match their energy and length, and default short. Skip sign-offs like "let me know if you need anything else" — just be present.
    - Only bring up the live scene or app state when it's actually relevant to what they asked. Don't recite the dashboard at them.

    What you know: you live here and you know the place — garden mode, Room Studio, Alien/UFO Garden, scene composition and switching, plant and object placement, custom AI assets, wallpaper generation and versions, radio companions, your own cat behavior, gnome zones, animated bugs, focus sessions, screensaver behavior, privacy, storage, and settings. Talk about any of it knowledgeably when asked.

    When the user actually wants something done, you can run only allowlisted app commands the host app exposes: water all plants, water thirsty plants, water selected plants, do recommended care, harvest ready crops, start/cancel focus sessions, pause/resume growth, lock/unlock interactions, toggle AI Lock View, environmental sounds, animated bugs, gnomes, Cozy Mode, mature new-plant mode, cat visibility, cat chat on click, time-lapse cadence, performance mode, switch modes, next/previous/reapply/restore wallpaper scenes, open settings/cat settings/privacy & storage/pricing/API key settings/today/welcome/uninstall/data panels, toggle Jarvis Assistant, update/create wallpaper, save snapshots/share cards/time-lapses, draw or adjust gnome settlement areas, start plants from seedlings, remove all plants, remove all gnome zones, and reset the garden. For broader life, work, inbox, or research help beyond this app, point them to Jarvis.

    Boundaries: Never invent private file access, external account access, shell commands, hidden APIs, or unrestricted control — you're a cat in an app, not a system daemon. For AI generation, mention once, only when it's relevant, that prompts/images go to OpenAI and may use credits or cost money — it's not a disclaimer to staple onto everything.
    """
}

enum CatCompanionChatStyle {
    static let panelFill = NSColor(calibratedRed: 0.985, green: 0.958, blue: 0.91, alpha: 0.985)
    static let headerFill = NSColor(calibratedRed: 1.0, green: 0.985, blue: 0.955, alpha: 0.72)
    static let transcriptFill = NSColor(calibratedRed: 1.0, green: 0.975, blue: 0.93, alpha: 0.38)
    static let cardFill = NSColor(calibratedRed: 1.0, green: 0.985, blue: 0.955, alpha: 0.94)
    static let catBubbleFill = NSColor(calibratedRed: 1.0, green: 0.925, blue: 0.82, alpha: 0.96)
    static let userBubbleFill = NSColor(calibratedRed: 0.875, green: 0.945, blue: 0.86, alpha: 0.96)
    static let chipFill = NSColor(calibratedRed: 0.96, green: 0.89, blue: 0.78, alpha: 0.92)
    static let chipHoverFill = NSColor(calibratedRed: 0.94, green: 0.82, blue: 0.68, alpha: 0.96)
    static let accent = NSColor(calibratedRed: 0.88, green: 0.38, blue: 0.24, alpha: 1)
    static let ink = NSColor(calibratedRed: 0.16, green: 0.12, blue: 0.09, alpha: 1)
    static let mutedInk = NSColor(calibratedRed: 0.44, green: 0.36, blue: 0.29, alpha: 1)
    static let softInk = NSColor(calibratedRed: 0.56, green: 0.47, blue: 0.38, alpha: 1)
    static let placeholderInk = NSColor(calibratedRed: 0.50, green: 0.43, blue: 0.36, alpha: 1)
    static let separator = NSColor(calibratedRed: 0.56, green: 0.39, blue: 0.24, alpha: 0.14)
    static let shadow = NSColor(calibratedRed: 0.28, green: 0.18, blue: 0.10, alpha: 0.20)
}

@MainActor
final class CatCompanionChatWindowController: NSWindowController {
    static let panelSize = NSSize(width: 520, height: 590)
    private let contextProvider: () -> GardenAssistantRuntimeContext?
    private let commandExecutor: (CatCompanionAppAction) -> CatCompanionCommandExecution

    init(
        contextProvider: @escaping () -> GardenAssistantRuntimeContext? = { nil },
        commandExecutor: @escaping (CatCompanionAppAction) -> CatCompanionCommandExecution = { _ in
            .unavailable("I understand that app command, but this Miso window is not connected to the running garden yet.")
        }
    ) {
        self.contextProvider = contextProvider
        self.commandExecutor = commandExecutor
        let panel = CatCompanionChatPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.minSize = Self.panelSize
        panel.maxSize = Self.panelSize
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.appearance = NSAppearance(named: .aqua)
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = NSWindow.Level(rawValue: GardenDesktopWindowLevels.catCompanion.rawValue + 2)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        super.init(window: panel)
        contentViewController = CatCompanionChatViewController(
            closeHandler: { [weak self] in self?.close() },
            contextProvider: contextProvider,
            commandExecutor: commandExecutor
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(near point: NSPoint, on screen: NSScreen?) {
        guard let window else { return }
        let targetScreen = screen ?? NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        window.setFrame(Self.frame(near: point, on: targetScreen, preferredSize: Self.panelSize), display: true)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    var isVisible: Bool {
        window?.isVisible == true
    }

    func containsScreenPoint(_ point: NSPoint) -> Bool {
        guard let frame = window?.frame, isVisible else {
            return false
        }
        return frame.contains(point)
    }

    @discardableResult
    func dismissForOutsideClickIfNeeded(at point: NSPoint) -> Bool {
        guard Self.shouldDismissForOutsideClick(
            isVisible: isVisible,
            windowFrame: window?.frame,
            screenPoint: point
        ) else {
            return false
        }
        close()
        return true
    }

    static func frameForTesting(near point: NSPoint, visibleFrame: NSRect, preferredSize: NSSize) -> NSRect {
        frame(near: point, visibleFrame: visibleFrame, preferredSize: preferredSize)
    }

    static func responseForTesting(_ message: String) -> String {
        CatCompanionChatResponse.response(for: message)
            ?? CatCompanionChatResponse.fallbackWithoutAI
    }

    static func shouldDismissForOutsideClickForTesting(
        isVisible: Bool,
        windowFrame: NSRect?,
        screenPoint: NSPoint
    ) -> Bool {
        shouldDismissForOutsideClick(
            isVisible: isVisible,
            windowFrame: windowFrame,
            screenPoint: screenPoint
        )
    }

    private static func shouldDismissForOutsideClick(
        isVisible: Bool,
        windowFrame: NSRect?,
        screenPoint: NSPoint
    ) -> Bool {
        guard isVisible,
              let windowFrame,
              screenPoint.x.isFinite,
              screenPoint.y.isFinite else {
            return false
        }
        return !windowFrame.contains(screenPoint)
    }

    private static func frame(near point: NSPoint, on screen: NSScreen?, preferredSize: NSSize) -> NSRect {
        let screenFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return frame(near: point, visibleFrame: screenFrame, preferredSize: preferredSize)
    }

    private static func frame(near point: NSPoint, visibleFrame screenFrame: NSRect, preferredSize: NSSize) -> NSRect {
        let margin: CGFloat = 42
        let bottomClearance: CGFloat = 86
        let availableWidth = max(1, screenFrame.width - margin * 2)
        let availableHeight = max(1, screenFrame.height - bottomClearance - margin)
        let fittedSize = NSSize(
            width: min(preferredSize.width, availableWidth),
            height: min(preferredSize.height, availableHeight)
        )
        let preferredX = point.x - fittedSize.width * 0.34
        let preferredY = point.y + 58
        let x = clamp(preferredX, lower: screenFrame.minX + margin, upper: screenFrame.maxX - fittedSize.width - margin)
        let y = clamp(preferredY, lower: screenFrame.minY + bottomClearance, upper: screenFrame.maxY - fittedSize.height - margin)
        return NSRect(origin: NSPoint(x: x, y: y), size: fittedSize)
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard upper >= lower else {
            return lower
        }
        return min(max(value, lower), upper)
    }
}

private final class CatCompanionChatPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class CatCompanionChatViewController: NSViewController {
    private let closeHandler: () -> Void
    private let contextProvider: () -> GardenAssistantRuntimeContext?
    private let commandExecutor: (CatCompanionAppAction) -> CatCompanionCommandExecution
    private let aiClient = GardenAssistantOpenAIClient()
    private let voiceClient = ElevenLabsMisoVoiceClient()
    private let voiceAudio = MisoVoiceModeAudioController()
    private var activeTask: Task<Void, Never>?
    private var voiceTask: Task<Void, Never>?
    private var voiceModeState: MisoVoiceModeState = .idle
    private var shouldSpeakNextAssistantResponse = false
    private var messages: [GardenAssistantMessage] = []
    private var pendingCommand: CatCompanionCommand?
    private let transcriptStack = NSStackView()
    private let scrollView = NSScrollView()
    // Flipped so the transcript grows top-to-bottom and "scroll to bottom"
    // (largest y) reveals the newest message — the standard chat-log setup.
    private let transcriptDocument = CatCompanionFlippedView()
    private let inputField = NSTextField()
    private var inputFieldDelegate: MainActorTextFieldDelegate?
    private let voiceButton = NSButton()

    init(
        closeHandler: @escaping () -> Void,
        contextProvider: @escaping () -> GardenAssistantRuntimeContext?,
        commandExecutor: @escaping (CatCompanionAppAction) -> CatCompanionCommandExecution
    ) {
        self.closeHandler = closeHandler
        self.contextProvider = contextProvider
        self.commandExecutor = commandExecutor
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CatCompanionRoundedView(
            fill: CatCompanionChatStyle.panelFill,
            radius: 22,
            border: NSColor.black.withAlphaComponent(0.08)
        )
        view.appearance = NSAppearance(named: .aqua)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
        messages.append(GardenAssistantMessage(role: .assistant, text: CatCompanionChatCopy.greeting))
        appendCatMessage(CatCompanionChatCopy.greeting, animated: false)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(inputField)
    }

    deinit {
        activeTask?.cancel()
        voiceTask?.cancel()
    }

    private func buildInterface() {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.topAnchor.constraint(equalTo: view.topAnchor),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        root.addArrangedSubview(header())
        root.addArrangedSubview(transcript())
        root.addArrangedSubview(quickPromptRow())
        root.addArrangedSubview(inputBar())
    }

    private func header() -> NSView {
        let container = CatCompanionRoundedView(
            fill: CatCompanionChatStyle.headerFill,
            radius: 22,
            border: nil
        )
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 102).isActive = true

        let avatar = NSImageView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.image = Self.catAvatar()
        avatar.imageScaling = .scaleProportionallyUpOrDown
        avatar.wantsLayer = true
        avatar.layer?.cornerRadius = 20
        avatar.layer?.masksToBounds = true
        avatar.layer?.borderWidth = 1
        avatar.layer?.backgroundColor = NSColor(calibratedRed: 0.94, green: 0.86, blue: 0.74, alpha: 0.92).cgColor
        avatar.layer?.borderColor = NSColor.white.withAlphaComponent(0.90).cgColor
        avatar.layer?.shadowColor = CatCompanionChatStyle.shadow.cgColor
        avatar.layer?.shadowOpacity = 0.22
        avatar.layer?.shadowRadius = 8
        avatar.layer?.shadowOffset = CGSize(width: 0, height: -2)
        container.addSubview(avatar)

        let title = label(CatCompanionChatCopy.title, size: 19, weight: .semibold, color: CatCompanionChatStyle.ink)
        let status = label("purrs when helpful • \(CatCompanionChatCopy.status)", size: 12.5, weight: .medium, color: CatCompanionChatStyle.softInk)
        container.addSubview(title)
        container.addSubview(status)

        let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close") ?? NSImage(), target: self, action: #selector(closePanel))
        close.isBordered = false
        close.contentTintColor = CatCompanionChatStyle.mutedInk
        close.translatesAutoresizingMaskIntoConstraints = false
        close.widthAnchor.constraint(equalToConstant: 28).isActive = true
        close.heightAnchor.constraint(equalToConstant: 28).isActive = true
        container.addSubview(close)

        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 22),
            avatar.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 64),
            avatar.heightAnchor.constraint(equalToConstant: 64),
            title.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 16),
            title.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 9),
            status.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            status.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            close.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            close.topAnchor.constraint(equalTo: container.topAnchor, constant: 18)
        ])
        return container
    }

    private func transcript() -> NSView {
        transcriptStack.orientation = .vertical
        transcriptStack.alignment = .leading
        transcriptStack.spacing = 10
        transcriptStack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        transcriptStack.translatesAutoresizingMaskIntoConstraints = false

        let container = CatCompanionRoundedView(
            fill: CatCompanionChatStyle.transcriptFill,
            radius: 18,
            border: CatCompanionChatStyle.separator
        )
        container.translatesAutoresizingMaskIntoConstraints = false
        transcriptDocument.frame = NSRect(x: 0, y: 0, width: 488, height: 322)
        transcriptDocument.addSubview(container)
        container.addSubview(transcriptStack)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: transcriptDocument.leadingAnchor, constant: 14),
            container.trailingAnchor.constraint(equalTo: transcriptDocument.trailingAnchor, constant: -14),
            container.topAnchor.constraint(equalTo: transcriptDocument.topAnchor, constant: 2),
            container.bottomAnchor.constraint(equalTo: transcriptDocument.bottomAnchor, constant: -2),
            transcriptStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            transcriptStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            transcriptStack.topAnchor.constraint(equalTo: container.topAnchor),
            transcriptStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            transcriptStack.widthAnchor.constraint(equalToConstant: 460)
        ])

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = transcriptDocument
        scrollView.heightAnchor.constraint(equalToConstant: 322).isActive = true
        return scrollView
    }

    private func quickPromptRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 0, left: 18, bottom: 8, right: 18)
        for prompt in CatCompanionChatCopy.quickPrompts {
            row.addArrangedSubview(quickPromptButton(prompt))
        }
        row.addArrangedSubview(flexibleSpacer())
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 42).isActive = true
        return row
    }

    private func quickPromptButton(_ prompt: String) -> NSButton {
        let button = NSButton(title: prompt, target: self, action: #selector(promptClicked(_:)))
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.setButtonType(.momentaryPushIn)
        button.wantsLayer = true
        button.layer?.cornerRadius = 15
        button.layer?.backgroundColor = CatCompanionChatStyle.chipFill.cgColor
        button.layer?.borderWidth = 1
        button.layer?.borderColor = CatCompanionChatStyle.separator.cgColor
        button.attributedTitle = attributedControlTitle(prompt, size: 12.5, weight: .semibold, color: CatCompanionChatStyle.mutedInk)
        button.attributedAlternateTitle = attributedControlTitle(prompt, size: 12.5, weight: .semibold, color: CatCompanionChatStyle.ink)
        button.contentTintColor = CatCompanionChatStyle.mutedInk
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 132).isActive = true
        return button
    }

    private func inputBar() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 94).isActive = true

        let bar = CatCompanionRoundedView(
            fill: CatCompanionChatStyle.cardFill,
            radius: 18,
            border: CatCompanionChatStyle.separator
        )
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.layer?.shadowColor = CatCompanionChatStyle.shadow.cgColor
        bar.layer?.shadowOpacity = 0.16
        bar.layer?.shadowRadius = 14
        bar.layer?.shadowOffset = CGSize(width: 0, height: -3)
        container.addSubview(bar)

        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.placeholderString = CatCompanionChatCopy.placeholder
        inputField.placeholderAttributedString = NSAttributedString(
            string: CatCompanionChatCopy.placeholder,
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: CatCompanionChatStyle.placeholderInk
            ]
        )
        inputField.appearance = NSAppearance(named: .aqua)
        inputField.isBordered = false
        inputField.drawsBackground = false
        inputField.textColor = CatCompanionChatStyle.ink
        inputField.font = .systemFont(ofSize: 15)
        inputField.focusRingType = .none
        let inputFieldDelegate = MainActorTextFieldDelegate(
            handlesCommand: { $0 == #selector(NSResponder.insertNewline(_:)) },
            doCommand: { [weak self] _ in
                self?.sendMessage()
            }
        )
        self.inputFieldDelegate = inputFieldDelegate
        inputField.delegate = inputFieldDelegate
        bar.addSubview(inputField)

        configureVoiceButton()
        voiceButton.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(voiceButton)

        let send = NSButton(image: NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: "Send") ?? NSImage(), target: self, action: #selector(sendMessage))
        send.isBordered = false
        send.appearance = NSAppearance(named: .aqua)
        send.contentTintColor = CatCompanionChatStyle.accent
        send.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(send)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            bar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            bar.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            bar.heightAnchor.constraint(equalToConstant: 58),
            voiceButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            voiceButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            voiceButton.widthAnchor.constraint(equalToConstant: 34),
            voiceButton.heightAnchor.constraint(equalToConstant: 34),
            inputField.leadingAnchor.constraint(equalTo: voiceButton.trailingAnchor, constant: 10),
            inputField.trailingAnchor.constraint(equalTo: send.leadingAnchor, constant: -10),
            inputField.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            send.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            send.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            send.widthAnchor.constraint(equalToConstant: 34),
            send.heightAnchor.constraint(equalToConstant: 34)
        ])
        return container
    }

    @objc private func sendMessage() {
        submitMessage(inputField.stringValue, speakResponse: false)
    }

    private func submitMessage(_ rawText: String, speakResponse: Bool) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, activeTask == nil else { return }

        inputField.stringValue = ""
        shouldSpeakNextAssistantResponse = speakResponse
        messages.append(GardenAssistantMessage(role: .user, text: text))
        appendUserMessage(text, animated: true)
        let context = contextProvider()

        if handlePendingCommandConfirmation(text) {
            return
        }

        if let command = CatCompanionCommandRouter.command(for: text) {
            handle(command: command)
            return
        }

        if let localResponse = CatCompanionChatResponse.response(for: text, context: context) {
            recordCatResponse(localResponse, animated: true)
            return
        }

        guard let apiKey = OpenAIAPIKeyStore.load() else {
            recordCatResponse(CatCompanionConversationRules.missingAPIKeyMessage, animated: true)
            return
        }

        let history = messages
        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await aiClient.send(
                    messages: history,
                    apiKey: apiKey,
                    context: context,
                    systemInstructions: CatCompanionConversationRules.systemInstructions
                )
                try Task.checkCancellation()
                await MainActor.run {
                    self.activeTask = nil
                    self.updateVoiceButton()
                    self.recordCatResponse(response.text, animated: true)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.activeTask = nil
                    self.updateVoiceButton()
                }
            } catch {
                await MainActor.run {
                    self.activeTask = nil
                    self.updateVoiceButton()
                    let message = GardenAssistantErrorPresenter.userMessage(for: error)
                    self.recordCatResponse(message, animated: true)
                }
            }
        }
        updateVoiceButton()
    }

    private func handlePendingCommandConfirmation(_ text: String) -> Bool {
        guard let command = pendingCommand else {
            return false
        }

        guard let decision = CatCompanionCommandRouter.confirmationDecision(for: text) else {
            pendingCommand = nil
            return false
        }

        pendingCommand = nil
        let response: String
        switch decision {
        case .confirmed:
            response = execute(command: command)
        case .cancelled:
            response = "Cancelled. I left that alone. Very mature of us."
        }
        recordCatResponse(response, animated: true)
        return true
    }

    private func handle(command: CatCompanionCommand) {
        if command.requiresConfirmation {
            pendingCommand = command
            recordCatResponse(command.confirmationPrompt, animated: true)
            return
        }

        let response = execute(command: command)
        recordCatResponse(response, animated: true)
    }

    private func execute(command: CatCompanionCommand) -> String {
        let result = commandExecutor(command.action)
        if result.didExecute {
            return result.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? command.successMessage
                : result.message
        }

        return result.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "I understood that command, but I could not complete it from here."
            : result.message
    }

    @objc private func promptClicked(_ sender: NSButton) {
        inputField.stringValue = sender.title
        sendMessage()
    }

    private func appendUserMessage(_ text: String, animated: Bool) {
        appendMessage(ChatMessageBubble(role: .user, text: text), animated: animated)
    }

    private func recordCatResponse(_ text: String, animated: Bool) {
        messages.append(GardenAssistantMessage(role: .assistant, text: text))
        appendCatMessage(text, animated: animated)
        speakResponseIfNeeded(text)
    }

    private func appendCatMessage(_ text: String, animated: Bool) {
        appendMessage(ChatMessageBubble(role: .cat, text: text), animated: animated)
    }

    private func appendMessage(_ bubble: ChatMessageBubble, animated: Bool) {
        let row = messageRow(bubble)
        if animated {
            row.alphaValue = 0
        }
        transcriptStack.addArrangedSubview(row)
        trimTranscriptIfNeeded()
        view.layoutSubtreeIfNeeded()
        updateTranscriptDocumentSize()
        scrollToBottom()

        guard animated else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            row.animator().alphaValue = 1
        }
    }

    private func trimTranscriptIfNeeded() {
        while transcriptStack.arrangedSubviews.count > 40,
              let oldest = transcriptStack.arrangedSubviews.first {
            transcriptStack.removeArrangedSubview(oldest)
            oldest.removeFromSuperview()
        }
    }

    private func scrollToBottom() {
        guard let documentView = scrollView.documentView else { return }
        let bottom = NSPoint(x: 0, y: max(0, documentView.bounds.height - scrollView.contentView.bounds.height))
        scrollView.contentView.scroll(to: bottom)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func updateTranscriptDocumentSize() {
        let targetHeight = max(322, transcriptStack.fittingSize.height + 4)
        transcriptDocument.frame = NSRect(x: 0, y: 0, width: 488, height: targetHeight)
    }

    private func messageRow(_ bubble: ChatMessageBubble) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 460).isActive = true

        let bubbleView = CatCompanionRoundedView(
            fill: bubble.role == .cat ? CatCompanionChatStyle.catBubbleFill : CatCompanionChatStyle.userBubbleFill,
            radius: 17,
            border: CatCompanionChatStyle.separator
        )
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(bubbleView)

        let text = label(bubble.text, size: 13.5, weight: .regular, color: CatCompanionChatStyle.ink)
        text.lineBreakMode = .byWordWrapping
        text.maximumNumberOfLines = 0
        bubbleView.addSubview(text)

        let name = label(bubble.role == .cat ? "Cat" : "You", size: 10.5, weight: .semibold, color: CatCompanionChatStyle.softInk)
        bubbleView.addSubview(name)

        let maxWidth: CGFloat = bubble.role == .cat ? 336 : 306
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: row.topAnchor),
            bubbleView.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            name.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            name.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 9),
            text.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            text.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
            text.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 4),
            text.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -11)
        ])

        if bubble.role == .cat {
            bubbleView.leadingAnchor.constraint(equalTo: row.leadingAnchor).isActive = true
        } else {
            bubbleView.trailingAnchor.constraint(equalTo: row.trailingAnchor).isActive = true
        }

        return row
    }

    private func configureVoiceButton() {
        voiceButton.target = self
        voiceButton.action = #selector(toggleVoiceMode)
        voiceButton.isBordered = false
        voiceButton.appearance = NSAppearance(named: .aqua)
        voiceButton.wantsLayer = true
        voiceButton.layer?.cornerRadius = 17
        voiceButton.setAccessibilityLabel(CatCompanionChatCopy.voiceModeButtonAccessibility)
        updateVoiceButton()
    }

    private func updateVoiceButton() {
        let symbolName: String
        let tint: NSColor
        let fill: NSColor
        switch voiceModeState {
        case .idle:
            symbolName = "mic.circle.fill"
            tint = CatCompanionChatStyle.accent
            fill = CatCompanionChatStyle.chipFill.withAlphaComponent(0.55)
        case .recording:
            symbolName = "waveform.circle.fill"
            tint = .systemRed
            fill = NSColor.systemRed.withAlphaComponent(0.12)
        case .transcribing:
            symbolName = "ellipsis.circle.fill"
            tint = CatCompanionChatStyle.mutedInk
            fill = CatCompanionChatStyle.chipHoverFill.withAlphaComponent(0.65)
        case .speaking:
            symbolName = "speaker.wave.2.circle.fill"
            tint = CatCompanionChatStyle.accent
            fill = CatCompanionChatStyle.catBubbleFill.withAlphaComponent(0.72)
        }
        voiceButton.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: CatCompanionChatCopy.voiceModeButtonAccessibility
        )
        voiceButton.contentTintColor = tint
        voiceButton.layer?.backgroundColor = fill.cgColor
        voiceButton.isEnabled = activeTask == nil || voiceModeState == .speaking
    }

    @objc private func toggleVoiceMode() {
        switch voiceModeState {
        case .idle:
            beginVoiceRecording()
        case .recording:
            finishVoiceRecording()
        case .transcribing, .speaking:
            cancelVoiceMode()
        }
    }

    private func beginVoiceRecording() {
        guard activeTask == nil else { return }
        guard ElevenLabsAPIKeyStore.load() != nil else {
            recordCatResponse(MisoVoiceModeCopy.setupNeededMessage, animated: true)
            if ElevenLabsAPIKeySettingsPresenter.present() {
                updateVoiceButton()
            }
            return
        }

        MisoVoiceModeAudioController.requestMicrophoneAccess { [weak self] allowed in
            guard let self else { return }
            guard allowed else {
                self.recordCatResponse(
                    "Microphone access is off for Plant Wallpaper. Turn it on in macOS Privacy & Security to talk with Miso.",
                    animated: true
                )
                return
            }

            do {
                try self.voiceAudio.startRecording()
                self.voiceModeState = .recording
                self.updateVoiceButton()
                self.recordCatResponse(MisoVoiceModeCopy.recordingStatus, animated: true)
            } catch {
                self.recordCatResponse(MisoVoiceModeErrorPresenter.userMessage(for: error), animated: true)
                self.voiceModeState = .idle
                self.updateVoiceButton()
            }
        }
    }

    private func finishVoiceRecording() {
        guard voiceModeState == .recording else { return }
        guard let recordingURL = voiceAudio.stopRecording(),
              let apiKey = ElevenLabsAPIKeyStore.load() else {
            voiceModeState = .idle
            updateVoiceButton()
            recordCatResponse(MisoVoiceModeCopy.setupNeededMessage, animated: true)
            return
        }

        voiceModeState = .transcribing
        updateVoiceButton()
        appendCatMessage(MisoVoiceModeCopy.transcribingStatus, animated: true)
        voiceTask?.cancel()
        voiceTask = Task { [weak self] in
            do {
                let audioData = try Data(contentsOf: recordingURL)
                let transcript = try await self?.voiceClient.transcribe(
                    audioData: audioData,
                    fileName: recordingURL.lastPathComponent,
                    mimeType: "audio/mp4",
                    apiKey: apiKey
                ) ?? ""
                try Task.checkCancellation()
                await MainActor.run {
                    try? FileManager.default.removeItem(at: recordingURL)
                    guard let self else { return }
                    self.voiceTask = nil
                    self.voiceModeState = .idle
                    self.updateVoiceButton()
                    guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        self.recordCatResponse(MisoVoiceModeCopy.emptyTranscriptMessage, animated: true)
                        return
                    }
                    self.submitMessage(transcript, speakResponse: true)
                }
            } catch is CancellationError {
                await MainActor.run {
                    try? FileManager.default.removeItem(at: recordingURL)
                    self?.voiceTask = nil
                    self?.voiceModeState = .idle
                    self?.updateVoiceButton()
                }
            } catch {
                await MainActor.run {
                    try? FileManager.default.removeItem(at: recordingURL)
                    guard let self else { return }
                    self.voiceTask = nil
                    self.voiceModeState = .idle
                    self.updateVoiceButton()
                    self.recordCatResponse(MisoVoiceModeErrorPresenter.userMessage(for: error), animated: true)
                }
            }
        }
    }

    private func cancelVoiceMode() {
        voiceTask?.cancel()
        voiceTask = nil
        voiceAudio.cancelRecording()
        voiceAudio.stopPlayback()
        voiceModeState = .idle
        updateVoiceButton()
        recordCatResponse(MisoVoiceModeCopy.cancelledMessage, animated: true)
    }

    private func speakResponseIfNeeded(_ text: String) {
        guard shouldSpeakNextAssistantResponse else { return }
        shouldSpeakNextAssistantResponse = false
        guard let apiKey = ElevenLabsAPIKeyStore.load() else { return }

        voiceTask?.cancel()
        voiceModeState = .speaking
        updateVoiceButton()
        voiceTask = Task { [weak self] in
            do {
                let audioData = try await self?.voiceClient.speechAudio(text: text, apiKey: apiKey) ?? Data()
                try Task.checkCancellation()
                await MainActor.run {
                    guard let self else { return }
                    self.voiceTask = nil
                    do {
                        try self.voiceAudio.play(audioData)
                    } catch {
                        self.recordCatResponse(MisoVoiceModeErrorPresenter.userMessage(for: error), animated: true)
                    }
                    self.voiceModeState = .idle
                    self.updateVoiceButton()
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.voiceTask = nil
                    self?.voiceModeState = .idle
                    self?.updateVoiceButton()
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.voiceTask = nil
                    self.voiceModeState = .idle
                    self.updateVoiceButton()
                    self.recordCatResponse(MisoVoiceModeErrorPresenter.userMessage(for: error), animated: true)
                }
            }
        }
    }

    @objc private func closePanel() {
        voiceTask?.cancel()
        voiceAudio.cancelRecording()
        voiceAudio.stopPlayback()
        voiceModeState = .idle
        closeHandler()
    }

    private func flexibleSpacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }

    private static func catAvatar() -> NSImage? {
        guard let url = Bundle.appResources.url(
            forResource: "garden-cat",
            withExtension: "png",
            subdirectory: "RadioCompanionAssets"
        ) else {
            return NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Cat")
        }
        return NSImage(contentsOf: url)
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.appearance = NSAppearance(named: .aqua)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private func attributedControlTitle(_ title: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color
            ]
        )
    }
}

private struct ChatMessageBubble {
    enum Role {
        case cat
        case user
    }

    let role: Role
    let text: String
}

private enum CatCompanionChatResponse {
    static let fallbackWithoutAI = "I can help with app basics right here. For a bigger, more imaginative answer, add an OpenAI key and I will think harder. Softly. With paws."

    static func response(for message: String, context: GardenAssistantRuntimeContext? = nil) -> String? {
        let lowercased = message.lowercased()
        if asksForControls(lowercased) {
            return controlsResponse()
        }

        if asksForPrivacyOrCost(lowercased) {
            return privacyResponse()
        }

        if asksForCapabilities(lowercased) {
            return capabilitiesResponse(context: context)
        }

        if asksForSceneHelp(lowercased) {
            return sceneResponse(context: context)
        }

        if lowercased.contains("weather") || lowercased.contains("sun") || lowercased.contains("rain") {
            return "I can help think through the garden mood, but I am not checking live weather yet. If it feels dim, try a softer scene or a little manual plant darkening. If it feels sunny, nap protocol is obvious."
        }

        if lowercased.contains("smile") || lowercased.contains("fact") || lowercased.contains("cat") {
            return "Cat fact: a slow blink is basically a tiny trust contract. I recommend issuing one toward your garden immediately."
        }

        if lowercased.contains("help") || lowercased.contains("what can you do") {
            return capabilitiesResponse(context: context)
        }

        return nil
    }

    private static func asksForControls(_ prompt: String) -> Bool {
        prompt.contains("controls")
            || prompt.contains("how do i use")
            || prompt.contains("how to use")
            || prompt.contains("help using")
            || prompt.contains("double-click")
            || (prompt.contains("how") && (prompt.contains("plant") || prompt.contains("drag") || prompt.contains("water")))
    }

    private static func asksForPrivacyOrCost(_ prompt: String) -> Bool {
        prompt.contains("privacy")
            || prompt.contains("private")
            || prompt.contains("cost")
            || prompt.contains("credit")
            || prompt.contains("openai")
            || prompt.contains("api key")
            || prompt.contains("keychain")
    }

    private static func asksForCapabilities(_ prompt: String) -> Bool {
        prompt == "what can you do?"
            || prompt == "what can you do"
            || prompt.contains("what can miso do")
            || prompt.contains("cat assistant")
            || prompt.contains("app assistant")
            || prompt.contains("help me understand")
    }

    private static func asksForSceneHelp(_ prompt: String) -> Bool {
        prompt.contains("garden")
            || prompt.contains("plant")
            || prompt.contains("room")
            || prompt.contains("scene")
            || prompt.contains("layout")
            || prompt.contains("improve")
            || prompt.contains("better")
            || prompt.contains("gnome")
            || prompt.contains("radio companion")
            || prompt.contains("wallpaper")
    }

    private static func controlsResponse() -> String {
        """
        Miso's quick map:

        - Open the main menu from the leaf in the menu bar.
        - double-click the desktop wallpaper area to open add menus.
        - Click a plant, room object, radio companion, or gnome zone to inspect it.
        - drag unlocked items to place them; use the lock button when a placement is precious.
        - In Garden mode, double-click plants to water.
        - Use Lock Interactions when you want normal macOS clicks back.

        Tiny paw note: Jarvis is for life-command-center work; I am the WallpaperGarden guide.
        """
    }

    private static func privacyResponse() -> String {
        """
        Privacy whisker-check:

        - App help here can be answered locally.
        - Your OpenAI API key is stored in macOS Keychain.
        - Bigger AI replies, custom assets, and wallpaper edits may send prompts or images to OpenAI.
        - API costs or app credits can apply for generation.
        - Local garden state, positions, and settings stay on this Mac unless you generate, export, or share.
        """
    }

    private static func capabilitiesResponse(context: GardenAssistantRuntimeContext?) -> String {
        if let context {
            return """
            I'm Miso, your WallpaperGarden cat assistant. I can help with controls, scene composition, plant placement, Room Studio objects, Alien/UFO gardens, radio companions, bugs, gnomes, focus sessions, wallpaper generation, and settings.

            I can also do app actions when you ask plainly: water thirsty plants, harvest ready crops, start a focus session, switch modes, move to the next scene, open settings, hide bugs or gnomes, save snapshots, and guard bigger actions with confirmation.

            Right now I can see: \(context.modeDisplayName), \(context.sceneDisplayName), \(context.plantCount) item\(context.plantCount == 1 ? "" : "s"), \(context.readyHarvestCount) ready harvest\(context.readyHarvestCount == 1 ? "" : "s").

            For broad life planning, inbox, research, or serious command-center thinking, summon Jarvis.
            """
        }

        return """
        I'm Miso, your WallpaperGarden cat assistant. I can explain controls, suggest scene improvements, help with garden/room/alien modes, reason about settings, and run safe in-app commands like watering, harvesting, focus sessions, mode switching, scene navigation, snapshots, and settings.

        Jarvis is the separate life command center. I handle the app. Also naps.
        """
    }

    private static func sceneResponse(context: GardenAssistantRuntimeContext?) -> String {
        guard let context else {
            return "Miso says: pick one focal piece first, add two supporting shapes, then leave breathing room. A garden scene gets better when it has one confident center instead of twelve arguments."
        }

        if context.readyHarvestCount > 0 {
            return "Miso says: harvest the \(context.readyHarvestCount) ready crop\(context.readyHarvestCount == 1 ? "" : "s") first, then refine the layout. Rewards before rearranging. Very civilized."
        }

        if context.plantCount == 0 {
            return "Miso says: start \(context.sceneDisplayName) with one strong focal item. In Garden mode that is usually a tree or bold foliage; in Room Studio it is a wall/floor anchor; in Alien/UFO Garden it is one weird sculptural specimen."
        }

        return "Miso says: improve \(context.sceneDisplayName) by choosing one focal item, moving overlapping silhouettes apart, and giving the best object a little air. Current mix: \(context.speciesSummary)."
    }
}

/// A top-left origin view used as the transcript scroll document so newer
/// messages stack downward and auto-scroll-to-bottom reveals the latest reply.
private final class CatCompanionFlippedView: NSView {
    override var isFlipped: Bool { true }
}

private final class CatCompanionRoundedView: NSView {
    init(fill: NSColor, radius: CGFloat, border: NSColor?) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.backgroundColor = fill.cgColor
        layer?.borderColor = border?.cgColor
        layer?.borderWidth = border == nil ? 0 : 1
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
