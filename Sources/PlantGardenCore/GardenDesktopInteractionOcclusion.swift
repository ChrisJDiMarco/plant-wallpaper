import Foundation

public struct GardenDesktopWindowSnapshot: Equatable, Sendable {
    public let ownerName: String
    public let windowName: String
    public let layer: Int
    public let alpha: Double
    public let bounds: GardenDesktopWindowBounds

    public init(
        ownerName: String,
        windowName: String,
        layer: Int,
        alpha: Double,
        bounds: GardenDesktopWindowBounds
    ) {
        self.ownerName = ownerName
        self.windowName = windowName
        self.layer = layer
        self.alpha = alpha
        self.bounds = bounds
    }
}

public struct GardenDesktopWindowBounds: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func contains(x pointX: Double, y pointY: Double) -> Bool {
        pointX >= x
            && pointX <= x + width
            && pointY >= y
            && pointY <= y + height
    }
}

public enum GardenDesktopInteractionOcclusion {
    public static func allowsGardenInteraction(
        atX pointX: Double,
        y pointY: Double,
        windows: [GardenDesktopWindowSnapshot]
    ) -> Bool {
        for window in windows {
            guard window.alpha > 0.01,
                  window.bounds.contains(x: pointX, y: pointY) else {
                continue
            }

            if isIgnoredSystemOrGardenWindow(window) {
                continue
            }

            if window.layer >= 0 {
                return false
            }
        }

        return true
    }

    private static func isIgnoredSystemOrGardenWindow(_ window: GardenDesktopWindowSnapshot) -> Bool {
        if window.layer < 0 {
            return true
        }

        if isScreenCaptureOverlayWindow(window) {
            return true
        }

        if window.ownerName == "Window Server" && window.windowName == "Cursor" {
            return true
        }

        if window.ownerName == "Dock" {
            return true
        }

        // Notification Center keeps a persistent full-screen, click-through
        // window over the desktop (verified via CGWindowListCopyWindowInfo:
        // owner "Notification Center", full-display bounds, layer ~21, opaque).
        // Like the Dock's full-screen layer it must not count as occluding, or
        // the entire desktop reads as covered and the garden + cat stop
        // reacting to the mouse (no cursor tracking, petting, or double-click).
        if window.ownerName == "Notification Center" {
            return true
        }

        if window.ownerName == "Finder" && window.windowName.isEmpty {
            return true
        }

        return false
    }

    /// macOS screen recording / screenshot (Command+Shift+5) draws a full-screen
    /// overlay window that sits above the desktop while a recording is active —
    /// and the opaque overlay can linger for several seconds after the recording
    /// ends. Without ignoring it, the desktop garden and cat companion treat the
    /// whole screen as occluded and stop reacting to the mouse (no cursor
    /// tracking, petting, or swiping) for the entire recording.
    ///
    /// These owner names belong to the system screen-capture UI and never to
    /// ordinary application windows, so the overlay must not count as occluding
    /// the desktop. Matching by owner (rather than window layer) is required:
    /// the app's own context menus and the menu-bar/Control Center chrome share
    /// the same high window layers and must keep blocking interaction.
    ///
    /// Owner names verified live on macOS 26.5 via CGWindowListCopyWindowInfo:
    /// - "Screenshot": screencaptureui.app — the lingering full-screen overlay
    ///   seen during interactive full-screen recording.
    /// - "screencapture" / "screencaptureui": the /usr/sbin/screencapture helper
    ///   backdrop used for region and command-line capture.
    /// - Window Server "StatusIndicator": the recording-in-progress indicator.
    private static func isScreenCaptureOverlayWindow(_ window: GardenDesktopWindowSnapshot) -> Bool {
        switch window.ownerName {
        case "Screenshot", "screencapture", "screencaptureui":
            return true
        default:
            return window.ownerName == "Window Server" && window.windowName == "StatusIndicator"
        }
    }
}
