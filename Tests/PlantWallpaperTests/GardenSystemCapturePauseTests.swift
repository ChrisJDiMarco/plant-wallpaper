import Testing
@testable import PlantWallpaper

@Suite("Garden system capture pausing")
struct GardenSystemCapturePauseTests {
    @Test("macOS screenshot tools pause desktop input routing")
    func macOSScreenshotToolsPauseDesktopInputRouting() {
        #expect(GardenOverlayController.isSystemCaptureUIActiveForSelfTest(
            processNames: ["Screenshot"],
            bundleIdentifiers: []
        ))
        #expect(GardenOverlayController.isSystemCaptureUIActiveForSelfTest(
            processNames: ["screencaptureui"],
            bundleIdentifiers: ["com.apple.screencaptureui"]
        ))
        #expect(!GardenOverlayController.isSystemCaptureUIActiveForSelfTest(
            processNames: ["Plant Wallpaper"],
            bundleIdentifiers: ["com.chrisdimarco.PlantWallpaper"]
        ))
    }
}
