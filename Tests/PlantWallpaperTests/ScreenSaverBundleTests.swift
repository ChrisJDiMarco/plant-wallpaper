import Foundation
import Testing

@Suite("Screen saver bundle")
struct ScreenSaverBundleTests {
    @Test("screen saver build ships the WebGL cat assets")
    func screenSaverBuildShipsWebGLCatAssets() throws {
        let scriptURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Scripts/build_screensaver.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        #expect(script.contains("-framework WebKit"))
        #expect(script.contains("Sources/PlantWallpaper/WebAssets"))
        #expect(script.contains("CFBundleShortVersionString"))
        #expect(script.contains("<string>1.0.2</string>"))
        #expect(script.contains("<string>3</string>"))
    }

    @Test("screen saver follows the published desktop cat visibility")
    func screenSaverFollowsPublishedDesktopCatVisibility() throws {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/PlantWallpaperScreenSaver/PlantWallpaperScreenSaverView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("currentSnapshot?.isCatCompanionEnabled"))
        #expect(source.contains("catCompanionEnabled"))
    }

    @Test("screen saver renders live state instead of a frozen desktop PNG")
    func screenSaverRendersLiveStateInsteadOfFrozenDesktopPNG() throws {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/PlantWallpaperScreenSaver/PlantWallpaperScreenSaverView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(!source.contains("gardenSnapshotImageURL"))
        #expect(source.contains("currentSnapshot?.wallpaperImagePath"))
        #expect(source.contains("catRuntimeMemory"))
    }
}
