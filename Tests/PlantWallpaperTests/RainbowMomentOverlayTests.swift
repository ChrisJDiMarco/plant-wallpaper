import XCTest
import PlantGardenCore
@testable import PlantWallpaper

final class RainbowMomentOverlayTests: XCTestCase {
    func testRainbowWebAssetsAreBundledAndShaderDriven() throws {
        let indexURL = try XCTUnwrap(
            RainbowMomentController.webAssetsIndexURL(),
            "WebAssets/rainbow/index.html missing from bundle"
        )
        let directoryURL = indexURL.deletingLastPathComponent()
        let html = try String(contentsOf: indexURL, encoding: .utf8)
        let scriptURL = directoryURL.appendingPathComponent("main.js")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(html.contains("../cat/three.min.js"))
        XCTAssertTrue(html.contains("main.js"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertTrue(script.contains("window.rainbowBridge"))
        XCTAssertTrue(script.contains("THREE.ShaderMaterial"))
        XCTAssertTrue(script.contains("uPresence"))
        XCTAssertTrue(script.contains("uProgress"))
    }

    @MainActor
    func testRainbowLayerSitsAboveGardenAndBelowInteractiveCompanions() {
        let rainbowLevel = RainbowMomentWindow.rainbowLevel.rawValue
        let canvasLevel = GardenWindow.canvasLevel.rawValue
        let interactionLevel = GardenInteractionRegionWindow.interactionLevel.rawValue
        let gnomeLevel = GnomeTribeWindow.companionLevel.rawValue
        let catLevel = CatCompanionWindow.companionLevel.rawValue

        XCTAssertGreaterThan(rainbowLevel, canvasLevel)
        XCTAssertLessThan(rainbowLevel, interactionLevel)
        XCTAssertLessThan(rainbowLevel, gnomeLevel)
        XCTAssertLessThan(rainbowLevel, catLevel)
    }

    func testLegacyFlatRainbowArcIsNotDrawnByCanvas() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/PlantWallpaper/GardenCanvasView+RareMoments.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("drawRainbowArc(moment:)"))
        XCTAssertFalse(source.contains("appendArc("))
    }

    func testRainbowWebLayerOnlyRunsForActiveRainbowMoment() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 11
        components.hour = 14
        let calendar = Calendar.current
        let afternoon = try XCTUnwrap(calendar.date(from: components))
        let rainbowWeather = GardenWeatherCondition(
            kind: .partlyCloudy,
            temperatureCelsius: 21,
            fetchedAt: afternoon,
            precipitationEndedAt: afternoon.addingTimeInterval(-4 * 60)
        )

        var state = GardenState(weather: rainbowWeather)
        XCTAssertTrue(RainbowMomentController.shouldShow(for: state, at: afternoon))

        state.settings = state.settings.updating(rareMomentsMode: .off)
        XCTAssertFalse(RainbowMomentController.shouldShow(for: state, at: afternoon))

        let raining = GardenWeatherCondition(kind: .rain, temperatureCelsius: 18, fetchedAt: afternoon)
        state = GardenState(weather: raining)
        XCTAssertFalse(RainbowMomentController.shouldShow(for: state, at: afternoon))

        state = GardenState()
        XCTAssertFalse(RainbowMomentController.shouldShow(for: state, at: afternoon))
    }
}
