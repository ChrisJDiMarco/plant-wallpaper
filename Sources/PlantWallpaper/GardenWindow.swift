import AppKit

enum GardenDesktopWindowLevels {
    private static var desktopIconBase: Int {
        Int(CGWindowLevelForKey(.desktopIconWindow))
    }

    static var canvas: NSWindow.Level {
        NSWindow.Level(rawValue: desktopIconBase + 1)
    }

    static var rainbowMoment: NSWindow.Level {
        NSWindow.Level(rawValue: desktopIconBase + 2)
    }

    static var interactionRegion: NSWindow.Level {
        NSWindow.Level(rawValue: desktopIconBase + 3)
    }

    static var gnomeTribe: NSWindow.Level {
        NSWindow.Level(rawValue: desktopIconBase + 4)
    }

    static var birdFlock: NSWindow.Level {
        NSWindow.Level(rawValue: desktopIconBase + 4)
    }

    static var catCompanion: NSWindow.Level {
        NSWindow.Level(rawValue: desktopIconBase + 5)
    }

    static var plantSpotlight: NSWindow.Level {
        NSWindow.Level(rawValue: desktopIconBase + 6)
    }
}

@MainActor
final class GardenWindow: NSWindow {
    static var canvasLevel: NSWindow.Level {
        GardenDesktopWindowLevels.canvas
    }

    static var plantSpotlightLevel: NSWindow.Level {
        GardenDesktopWindowLevels.plantSpotlight
    }

    static func canvasLevel(isPlantSpotlightVisible: Bool) -> NSWindow.Level {
        isPlantSpotlightVisible ? plantSpotlightLevel : canvasLevel
    }

    func setPlantSpotlightVisible(_ isVisible: Bool) {
        level = Self.canvasLevel(isPlantSpotlightVisible: isVisible)
    }

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: true)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        level = Self.canvasLevel
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

@MainActor
final class GardenInteractionRegionWindow: NSWindow {
    static var interactionLevel: NSWindow.Level {
        GardenDesktopWindowLevels.interactionRegion
    }

    init(
        frame: NSRect,
        mouseDownHandler: @escaping (NSEvent, GardenInteractionRegionWindow) -> Void,
        mouseDraggedHandler: @escaping (NSEvent, GardenInteractionRegionWindow) -> Void,
        mouseUpHandler: @escaping (NSEvent, GardenInteractionRegionWindow) -> Void
    ) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setFrame(frame, display: false)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = false
        isReleasedWhenClosed = false
        level = Self.interactionLevel
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        contentView = GardenInteractionRegionView(
            mouseDownHandler: mouseDownHandler,
            mouseDraggedHandler: mouseDraggedHandler,
            mouseUpHandler: mouseUpHandler
        )
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

@MainActor
private final class GardenInteractionRegionView: NSView {
    private let mouseDownHandler: (NSEvent, GardenInteractionRegionWindow) -> Void
    private let mouseDraggedHandler: (NSEvent, GardenInteractionRegionWindow) -> Void
    private let mouseUpHandler: (NSEvent, GardenInteractionRegionWindow) -> Void

    init(
        mouseDownHandler: @escaping (NSEvent, GardenInteractionRegionWindow) -> Void,
        mouseDraggedHandler: @escaping (NSEvent, GardenInteractionRegionWindow) -> Void,
        mouseUpHandler: @escaping (NSEvent, GardenInteractionRegionWindow) -> Void
    ) {
        self.mouseDownHandler = mouseDownHandler
        self.mouseDraggedHandler = mouseDraggedHandler
        self.mouseUpHandler = mouseUpHandler
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func mouseDown(with event: NSEvent) {
        guard let regionWindow = window as? GardenInteractionRegionWindow else {
            return
        }

        mouseDownHandler(event, regionWindow)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let regionWindow = window as? GardenInteractionRegionWindow else {
            return
        }

        mouseDraggedHandler(event, regionWindow)
    }

    override func mouseUp(with event: NSEvent) {
        guard let regionWindow = window as? GardenInteractionRegionWindow else {
            return
        }

        mouseUpHandler(event, regionWindow)
    }
}
