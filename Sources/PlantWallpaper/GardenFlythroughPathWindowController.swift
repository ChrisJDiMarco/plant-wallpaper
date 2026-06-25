import AppKit

struct GardenFlythroughPathSelection {
    let pathInstruction: String?
    let shouldApplyAsWallpaper: Bool
    let durationSeconds: Int

    var segmentCount: Int {
        max(1, durationSeconds / 10)
    }
}

@MainActor
final class GardenFlythroughPathWindowController: NSObject, NSWindowDelegate {
    private let image: NSImage
    private let drawingView: GardenFlythroughPathDrawingView
    private let generateWithPathButton = NSButton(title: "Generate with Path", target: nil, action: nil)
    private let applyAsWallpaperButton = NSButton(checkboxWithTitle: "Set finished video as looping desktop wallpaper", target: nil, action: nil)
    private let durationPopup = NSPopUpButton()
    private var panel: NSPanel?
    private var result: GardenFlythroughPathSelection?
    private var isFinishing = false

    init?(snapshotPNGData: Data) {
        guard let image = NSImage(data: snapshotPNGData), image.size.width > 0, image.size.height > 0 else {
            return nil
        }
        self.image = image
        self.drawingView = GardenFlythroughPathDrawingView(image: image)
        super.init()
        drawingView.onPathChanged = { [weak self] in
            self?.generateWithPathButton.isEnabled = self?.drawingView.hasPath == true
        }
    }

    func runModal() -> GardenFlythroughPathSelection? {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.panel = panel
        panel.title = "Flythrough Path"
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.center()
        panel.contentView = makeContentView()

        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        let response = NSApplication.shared.runModal(for: panel)
        panel.orderOut(nil)
        self.panel = nil
        return response == .OK ? result : nil
    }

    func windowWillClose(_ notification: Notification) {
        guard !isFinishing else {
            return
        }
        NSApplication.shared.stopModal(withCode: .cancel)
    }

    private func makeContentView() -> NSView {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let title = NSTextField(labelWithString: "Draw the flight path")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.alignment = .center

        let subtitle = NSTextField(labelWithString: "Use the bright marker, or let AI choose the route. Choose the length and whether the finished MP4 becomes your desktop.")
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center

        drawingView.translatesAutoresizingMaskIntoConstraints = false
        drawingView.wantsLayer = true
        drawingView.layer?.cornerRadius = 10
        drawingView.layer?.masksToBounds = true

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearPath))
        let aiButton = NSButton(title: "Let AI Decide", target: self, action: #selector(letAIDecide))
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        generateWithPathButton.target = self
        generateWithPathButton.action = #selector(generateWithPath)
        generateWithPathButton.keyEquivalent = "\r"
        generateWithPathButton.isEnabled = false
        applyAsWallpaperButton.state = .off
        for seconds in stride(from: 10, through: 60, by: 10) {
            durationPopup.addItem(withTitle: "\(seconds) seconds")
            durationPopup.lastItem?.representedObject = seconds
        }
        durationPopup.selectItem(withTitle: "60 seconds")

        let durationLabel = NSTextField(labelWithString: "Video length")
        durationLabel.font = .systemFont(ofSize: 13, weight: .medium)
        let durationRow = NSStackView(views: [durationLabel, durationPopup, NSView(), applyAsWallpaperButton])
        durationRow.orientation = .horizontal
        durationRow.alignment = .centerY
        durationRow.spacing = 10
        durationRow.setHuggingPriority(.defaultLow, for: .horizontal)

        let buttonRow = NSStackView(views: [clearButton, NSView(), cancelButton, aiButton, generateWithPathButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 10
        buttonRow.setHuggingPriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [title, subtitle, drawingView, durationRow, buttonRow])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),
            drawingView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            drawingView.heightAnchor.constraint(equalTo: stack.heightAnchor, multiplier: 0.78),
            durationRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        return root
    }

    @objc private func clearPath() {
        drawingView.clear()
    }

    @objc private func letAIDecide() {
        finish(.OK, pathInstruction: nil)
    }

    @objc private func generateWithPath() {
        finish(.OK, pathInstruction: drawingView.pathInstruction())
    }

    @objc private func cancel() {
        finish(.cancel)
    }

    private func finish(_ response: NSApplication.ModalResponse, pathInstruction: String? = nil) {
        result = response == .OK
            ? GardenFlythroughPathSelection(
                pathInstruction: pathInstruction,
                shouldApplyAsWallpaper: applyAsWallpaperButton.state == .on,
                durationSeconds: selectedDurationSeconds()
            )
            : nil
        isFinishing = true
        NSApplication.shared.stopModal(withCode: response)
        panel?.orderOut(nil)
    }

    private func selectedDurationSeconds() -> Int {
        durationPopup.selectedItem?.representedObject as? Int ?? 60
    }
}

private final class GardenFlythroughPathDrawingView: NSView {
    var onPathChanged: (() -> Void)?

    private let image: NSImage
    private var strokes: [[CGPoint]] = []

    var hasPath: Bool {
        strokes.contains { $0.count > 1 }
    }

    init(image: NSImage) {
        self.image = image
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.88).setFill()
        bounds.fill()

        let rect = imageRect()
        image.draw(
            in: rect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )

        drawStrokes(in: rect)
    }

    override func mouseDown(with event: NSEvent) {
        guard let point = normalizedPoint(from: event) else {
            return
        }
        strokes.append([point])
        onPathChanged?()
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let point = normalizedPoint(from: event), !strokes.isEmpty else {
            return
        }
        strokes[strokes.count - 1].append(point)
        onPathChanged?()
        needsDisplay = true
    }

    func clear() {
        strokes.removeAll()
        onPathChanged?()
        needsDisplay = true
    }

    func pathInstruction() -> String? {
        let points = sampledPathPoints(maxCount: 16)
        guard points.count > 1 else {
            return nil
        }

        let coordinates = points
            .map { String(format: "(%.2f, %.2f)", $0.x, $0.y) }
            .joined(separator: " -> ")
        return """
        The user drew the desired flythrough route on the preview. Follow this approximate image-plane path using normalized coordinates where (0,0) is the top-left of the image and (1,1) is the bottom-right:
        \(coordinates)
        Treat the path as camera direction guidance only. Keep it invisible: do not render marker lines, arrows, dots, paint, UI, text, or annotations in the video.
        """
    }

    private func drawStrokes(in rect: NSRect) {
        NSColor.systemYellow.setStroke()
        for stroke in strokes where stroke.count > 1 {
            let path = NSBezierPath()
            path.lineWidth = 8
            path.move(to: viewPoint(from: stroke[0], in: rect))
            for point in stroke.dropFirst() {
                path.line(to: viewPoint(from: point, in: rect))
            }
            path.stroke()
        }

        NSColor.systemPink.setFill()
        for stroke in strokes {
            guard let first = stroke.first else {
                continue
            }
            let point = viewPoint(from: first, in: rect)
            NSBezierPath(ovalIn: NSRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)).fill()
        }
    }

    private func sampledPathPoints(maxCount: Int) -> [CGPoint] {
        let points = strokes.flatMap { $0 }
        guard points.count > maxCount else {
            return points
        }

        return (0..<maxCount).map { index in
            let sourceIndex = Int((Double(index) / Double(maxCount - 1)) * Double(points.count - 1))
            return points[sourceIndex]
        }
    }

    private func normalizedPoint(from event: NSEvent) -> CGPoint? {
        let point = convert(event.locationInWindow, from: nil)
        let rect = imageRect()
        guard rect.contains(point), rect.width > 0, rect.height > 0 else {
            return nil
        }

        return CGPoint(
            x: min(max((point.x - rect.minX) / rect.width, 0), 1),
            y: min(max(1 - ((point.y - rect.minY) / rect.height), 0), 1)
        )
    }

    private func viewPoint(from normalizedPoint: CGPoint, in rect: NSRect) -> NSPoint {
        NSPoint(
            x: rect.minX + normalizedPoint.x * rect.width,
            y: rect.maxY - normalizedPoint.y * rect.height
        )
    }

    private func imageRect() -> NSRect {
        guard image.size.width > 0, image.size.height > 0, bounds.width > 0, bounds.height > 0 else {
            return bounds
        }

        let imageAspect = image.size.width / image.size.height
        let boundsAspect = bounds.width / bounds.height
        if boundsAspect > imageAspect {
            let width = bounds.height * imageAspect
            return NSRect(x: bounds.midX - width / 2, y: bounds.minY, width: width, height: bounds.height)
        }

        let height = bounds.width / imageAspect
        return NSRect(x: bounds.minX, y: bounds.midY - height / 2, width: bounds.width, height: height)
    }
}
