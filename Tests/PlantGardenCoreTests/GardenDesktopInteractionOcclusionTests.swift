import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden desktop interaction occlusion")
struct GardenDesktopInteractionOcclusionTests {
    @Test("normal app windows block hidden plant dragging")
    func normalAppWindowsBlockHiddenPlantDragging() {
        let windows = [
            snapshot(owner: "Google Chrome", layer: 0, bounds: fullScreen)
        ]

        #expect(!GardenDesktopInteractionOcclusion.allowsGardenInteraction(atX: 284, y: 240, windows: windows))
    }

    @Test("plant wallpaper and desktop layers do not block garden dragging")
    func plantWallpaperAndDesktopLayersDoNotBlockGardenDragging() {
        let windows = [
            snapshot(owner: "Plant Wallpaper", layer: -2_147_483_602, bounds: fullScreen),
            snapshot(owner: "Dock", name: "Wallpaper", layer: -2_147_483_624, bounds: fullScreen)
        ]

        #expect(GardenDesktopInteractionOcclusion.allowsGardenInteraction(atX: 284, y: 240, windows: windows))
    }

    @Test("plant wallpaper menu windows block garden dragging")
    func plantWallpaperMenuWindowsBlockGardenDragging() {
        let windows = [
            snapshot(owner: "Plant Wallpaper", name: "Context Menu", layer: 25, bounds: fullScreen)
        ]

        #expect(!GardenDesktopInteractionOcclusion.allowsGardenInteraction(atX: 284, y: 240, windows: windows))
    }

    @Test("dock owned desktop utility windows do not block garden dragging")
    func dockOwnedDesktopUtilityWindowsDoNotBlockGardenDragging() {
        let windows = [
            snapshot(owner: "Dock", name: "Dock", layer: 20, bounds: fullScreen),
            snapshot(owner: "Dock", layer: 18, bounds: fullScreen),
            snapshot(owner: "Finder", layer: -2_147_483_603, bounds: fullScreen)
        ]

        #expect(GardenDesktopInteractionOcclusion.allowsGardenInteraction(atX: 284, y: 240, windows: windows))
    }

    @Test("notification center full-screen window does not block garden interaction")
    func notificationCenterFullScreenWindowDoesNotBlockGardenInteraction() {
        let windows = [
            snapshot(owner: "Notification Center", name: "Notification Center", layer: 21, bounds: fullScreen)
        ]

        #expect(GardenDesktopInteractionOcclusion.allowsGardenInteraction(atX: 284, y: 240, windows: windows))
    }

    @Test("menu and header windows block garden interaction")
    func menuAndHeaderWindowsBlockGardenInteraction() {
        let windows = [
            snapshot(owner: "Control Center", layer: 25, bounds: GardenDesktopWindowBounds(x: 0, y: 0, width: 1920, height: 40))
        ]

        #expect(!GardenDesktopInteractionOcclusion.allowsGardenInteraction(atX: 284, y: 20, windows: windows))
    }

    @Test("cursor layer is ignored while checking desktop visibility")
    func cursorLayerIsIgnored() {
        let windows = [
            snapshot(owner: "Window Server", name: "Cursor", layer: 2_147_483_630, bounds: GardenDesktopWindowBounds(x: 284, y: 240, width: 1, height: 1))
        ]

        #expect(GardenDesktopInteractionOcclusion.allowsGardenInteraction(atX: 284, y: 240, windows: windows))
    }

    @Test("finder desktop shell is ignored but titled finder windows block")
    func finderDesktopShellIsIgnoredButTitledFinderWindowsBlock() {
        let desktopShell = [
            snapshot(owner: "Finder", layer: 0, bounds: fullScreen)
        ]
        let titledFinderWindow = [
            snapshot(owner: "Finder", name: "Desktop", layer: 0, bounds: fullScreen)
        ]

        #expect(GardenDesktopInteractionOcclusion.allowsGardenInteraction(atX: 284, y: 240, windows: desktopShell))
        #expect(!GardenDesktopInteractionOcclusion.allowsGardenInteraction(atX: 284, y: 240, windows: titledFinderWindow))
    }

    @Test("macOS screen-recording overlay does not block cat mouse interaction")
    func screenRecordingOverlayDoesNotBlockInteraction() {
        // Captured live on macOS 26.5 while a full-screen recording was active:
        // owner "Screenshot", empty name, full-screen, layer 24.
        let windows = [
            snapshot(owner: "Screenshot", layer: 24, bounds: fullScreen)
        ]

        #expect(GardenDesktopInteractionOcclusion.allowsGardenInteraction(atX: 284, y: 240, windows: windows))
    }

    @Test("region and command-line screen capture backdrops do not block interaction")
    func screenCaptureBackdropsDoNotBlockInteraction() {
        let windows = [
            snapshot(owner: "screencapture", layer: 1499, bounds: fullScreen),
            snapshot(owner: "screencaptureui", layer: 1499, bounds: fullScreen),
            snapshot(owner: "Window Server", name: "StatusIndicator", layer: 2_147_483_630, bounds: fullScreen)
        ]

        #expect(GardenDesktopInteractionOcclusion.allowsGardenInteraction(atX: 284, y: 240, windows: windows))
    }

    @Test("a real app window under the cursor still blocks during a screen recording")
    func realAppWindowStillBlocksDuringScreenRecording() {
        // The screen-capture overlay must not mask a genuine app window: when a
        // normal window covers the cursor, the cat should still ignore the mouse
        // even while recording.
        let windows = [
            snapshot(owner: "Screenshot", layer: 24, bounds: fullScreen),
            snapshot(owner: "Google Chrome", layer: 0, bounds: fullScreen)
        ]

        #expect(!GardenDesktopInteractionOcclusion.allowsGardenInteraction(atX: 284, y: 240, windows: windows))
    }

    private var fullScreen: GardenDesktopWindowBounds {
        GardenDesktopWindowBounds(x: 0, y: 0, width: 1920, height: 1080)
    }

    private func snapshot(
        owner: String,
        name: String = "",
        layer: Int,
        alpha: Double = 1,
        bounds: GardenDesktopWindowBounds
    ) -> GardenDesktopWindowSnapshot {
        GardenDesktopWindowSnapshot(
            ownerName: owner,
            windowName: name,
            layer: layer,
            alpha: alpha,
            bounds: bounds
        )
    }
}
