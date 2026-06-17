import XCTest
@testable import PlantWallpaper

/// The cat companion lives in bundled web assets; if SwiftPM resource
/// packaging breaks (e.g. the .copy("WebAssets") declaration is lost),
/// the cat silently never appears. These tests fail loudly instead.
final class CatCompanionAssetTests: XCTestCase {
    func testWebAssetsIndexIsBundled() throws {
        let indexURL = try XCTUnwrap(
            CatCompanionController.webAssetsIndexURL(),
            "WebAssets/cat/index.html missing from bundle — check Package.swift resources"
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: indexURL.path))
    }

    func testAllCatScriptsAreBundled() throws {
        let indexURL = try XCTUnwrap(CatCompanionController.webAssetsIndexURL())
        let catDirectory = indexURL.deletingLastPathComponent()
        for script in ["three.min.js", "fur.js", "cat-model.js", "cat-anim.js", "cat-behavior.js", "cat-purr.js", "main.js"] {
            let scriptURL = catDirectory.appendingPathComponent(script)
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: scriptURL.path),
                "\(script) missing from bundled web assets"
            )
        }
    }

    func testIndexReferencesEveryBundledScript() throws {
        let indexURL = try XCTUnwrap(CatCompanionController.webAssetsIndexURL())
        let html = try String(contentsOf: indexURL, encoding: .utf8)
        for script in ["three.min.js", "fur.js", "cat-model.js", "cat-anim.js", "cat-behavior.js", "cat-purr.js", "main.js"] {
            XCTAssertTrue(html.contains(script), "index.html does not load \(script)")
        }
        XCTAssertLessThan(
            try XCTUnwrap(html.range(of: "cat-purr.js")?.lowerBound),
            try XCTUnwrap(html.range(of: "main.js")?.lowerBound),
            "cat-purr.js must load before main.js creates the bridge"
        )
    }

    func testCatClickAndBugBridgesAreBundled() throws {
        let indexURL = try XCTUnwrap(CatCompanionController.webAssetsIndexURL())
        let catDirectory = indexURL.deletingLastPathComponent()
        let main = try String(
            contentsOf: catDirectory.appendingPathComponent("main.js"),
            encoding: .utf8
        )
        let behavior = try String(
            contentsOf: catDirectory.appendingPathComponent("cat-behavior.js"),
            encoding: .utf8
        )
        XCTAssertTrue(main.contains("return behavior.pokeAt(point.x, point.y);"))
        XCTAssertTrue(main.contains("bugs(items)"))
        XCTAssertTrue(main.contains("type: 'bugCaught'"))
        XCTAssertTrue(behavior.contains("opensChat: false"))
        XCTAssertTrue(behavior.contains("opensChat: isBodyHit"))
        XCTAssertTrue(behavior.contains("setBugs(items)"))
        XCTAssertTrue(behavior.contains("onBugCaught(bug.id"))
    }

    func testCatRespectsGnomeTerritoryAndRendersRidingTack() throws {
        let indexURL = try XCTUnwrap(CatCompanionController.webAssetsIndexURL())
        let catDirectory = indexURL.deletingLastPathComponent()
        let main = try String(
            contentsOf: catDirectory.appendingPathComponent("main.js"),
            encoding: .utf8
        )
        let behavior = try String(
            contentsOf: catDirectory.appendingPathComponent("cat-behavior.js"),
            encoding: .utf8
        )
        let controller = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/PlantWallpaper/CatCompanionController.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(controller.contains("gnomeTerritoryProvider"))
        XCTAssertTrue(controller.contains("plantMissionTargetProvider"))
        XCTAssertTrue(controller.contains("pushGnomeTerritoriesIfNeeded"))
        XCTAssertTrue(controller.contains("pushPlantMissionTargetsIfNeeded"))
        XCTAssertTrue(controller.contains(".gardenStoreDidChange"))
        XCTAssertTrue(main.contains("gnomeTerritories(items)"))
        XCTAssertTrue(main.contains("plantMissionTargets(items)"))
        XCTAssertTrue(main.contains("normalizedPlantMissionTargets"))
        XCTAssertTrue(main.contains("applyGnomeMissionProjection"))
        XCTAssertTrue(main.contains("createGnomeRiderKit"))
        XCTAssertTrue(main.contains("makeStirrup"))
        XCTAssertTrue(main.contains("physics.reinsSag"))
        XCTAssertTrue(main.contains("setVisible(!!riding.active"))
        XCTAssertTrue(behavior.contains("setGnomeTerritories(items)"))
        XCTAssertTrue(behavior.contains("setGnomePlantTargets(items)"))
        XCTAssertTrue(behavior.contains("respectGnomeTerritories"))
        XCTAssertTrue(behavior.contains("chooseGnomePlantMissionTarget"))
        XCTAssertTrue(behavior.contains("gnomeMissionPerspective"))
        XCTAssertTrue(behavior.contains("gnomeRideDirectionFromPosition"))
        XCTAssertTrue(behavior.contains("isInsideGnomeTerritory"))
        XCTAssertTrue(behavior.contains("safeXOutsideGnomeTerritories"))
        XCTAssertTrue(behavior.contains("case 'gnomeWatch'"))
        XCTAssertTrue(behavior.contains("case 'gnomeRide'"))
        XCTAssertTrue(behavior.contains("gnomeRiding"))
        XCTAssertTrue(behavior.contains("depthTrend"))
        XCTAssertTrue(behavior.contains("missionPhase"))
        XCTAssertTrue(behavior.contains("velocityX"))
        XCTAssertTrue(behavior.contains("mouseInsideGnomeTerritory"))
    }

    func testCatPurrAudioIsBundledAndDrivenByPetting() throws {
        let indexURL = try XCTUnwrap(CatCompanionController.webAssetsIndexURL())
        let catDirectory = indexURL.deletingLastPathComponent()
        let main = try String(
            contentsOf: catDirectory.appendingPathComponent("main.js"),
            encoding: .utf8
        )
        let purr = try String(
            contentsOf: catDirectory.appendingPathComponent("cat-purr.js"),
            encoding: .utf8
        )
        let controller = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/PlantWallpaper/CatCompanionController.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(main.contains("CatPurr.create()"))
        XCTAssertTrue(main.contains("behavior.isPurring"))
        XCTAssertTrue(main.contains("purringEnabled"))
        XCTAssertTrue(purr.contains("AudioContext"))
        XCTAssertTrue(purr.contains("makeBrownNoiseBuffer"))
        XCTAssertTrue(purr.contains("setPurring"))
        XCTAssertTrue(purr.contains("0.040 + current * 0.180"))
        XCTAssertTrue(controller.contains("purringEnabled"))
        XCTAssertTrue(controller.contains("mediaTypesRequiringUserActionForPlayback = []"))
    }

    func testCatGroomingUsesWholeBodyPosesAndTongueRig() throws {
        let indexURL = try XCTUnwrap(CatCompanionController.webAssetsIndexURL())
        let catDirectory = indexURL.deletingLastPathComponent()
        let model = try String(
            contentsOf: catDirectory.appendingPathComponent("cat-model.js"),
            encoding: .utf8
        )
        let animation = try String(
            contentsOf: catDirectory.appendingPathComponent("cat-anim.js"),
            encoding: .utf8
        )
        let behavior = try String(
            contentsOf: catDirectory.appendingPathComponent("cat-behavior.js"),
            encoding: .utf8
        )

        XCTAssertTrue(model.contains("realisticTongue: true"))
        XCTAssertTrue(model.contains("groomingTargets: ['paw', 'face', 'flank', 'belly', 'tail', 'haunch']"))
        XCTAssertTrue(model.contains("tongueGroup.visible = false"))
        XCTAssertTrue(model.contains("tongueTip"))
        for pose in ["groomPaw", "groomFace", "groomFlank", "groomBelly", "groomTail", "groomHaunch"] {
            XCTAssertTrue(animation.contains("\(pose):"), "missing animation pose \(pose)")
            XCTAssertTrue(behavior.contains("case '\(pose)'"), "missing behavior state \(pose)")
        }
        XCTAssertTrue(animation.contains("function applyGrooming"))
        XCTAssertTrue(animation.contains("setTongue(lick > 0.08"))
        XCTAssertTrue(behavior.contains("chooseGroomingState('afterBug')"))
        XCTAssertTrue(behavior.contains("chooseGroomingState('afterPet')"))
        XCTAssertTrue(behavior.contains("chooseGroomingState('afterBellyPet')"))
    }

    func testCatMouseHuntingHasVariedStrikeVocabulary() throws {
        let indexURL = try XCTUnwrap(CatCompanionController.webAssetsIndexURL())
        let catDirectory = indexURL.deletingLastPathComponent()
        let animation = try String(
            contentsOf: catDirectory.appendingPathComponent("cat-anim.js"),
            encoding: .utf8
        )
        let behavior = try String(
            contentsOf: catDirectory.appendingPathComponent("cat-behavior.js"),
            encoding: .utf8
        )

        XCTAssertTrue(behavior.contains("function chooseMouseStrike(dist)"))
        XCTAssertTrue(behavior.contains("case 'mouseProbe'"))
        XCTAssertTrue(behavior.contains("case 'mouseFeint'"))
        XCTAssertTrue(behavior.contains("mouseStrikeStreak"))
        for style in ["highGrab", "sideSwipe", "lowPounce", "hookGrab"] {
            XCTAssertTrue(behavior.contains(style), "missing mouse lunge behavior style \(style)")
            XCTAssertTrue(animation.contains(style), "missing mouse lunge animation style \(style)")
        }
        for style in ["probe", "hook", "crossBat", "sidePounce"] {
            XCTAssertTrue(animation.contains(style), "missing cursor-play animation style \(style)")
        }
        XCTAssertTrue(animation.contains("triggerSwipe(alternatePaw, style)"))
        XCTAssertTrue(animation.contains("triggerLunge(duration, style)"))
        XCTAssertTrue(animation.contains("triggerPounce(style)"))
    }

    func testCatBrainSettingsVisualizerIsBundled() throws {
        let indexURL = try XCTUnwrap(
            CatCompanionSettingsWindowController.neuralVisualizerIndexURL(),
            "WebAssets/cat-brain/index.html missing from bundle — check Package.swift resources"
        )
        let directory = indexURL.deletingLastPathComponent()
        for asset in ["index.html", "main.js", "cat-head-neural.png"] {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: directory.appendingPathComponent(asset).path),
                "\(asset) missing from cat brain settings visualizer"
            )
        }

        let html = try String(contentsOf: indexURL, encoding: .utf8)
        XCTAssertTrue(html.contains("../cat/three.min.js"))
        XCTAssertTrue(html.contains("main.js"))
        XCTAssertTrue(html.contains("cat-head-neural.png"))
        XCTAssertTrue(html.contains("brainCanvas"))
        XCTAssertTrue(html.contains("brainFallback"))
    }

    func testCatBrainVisualizerUsesBundledThreeCompatibleGeometry() throws {
        let indexURL = try XCTUnwrap(CatCompanionSettingsWindowController.neuralVisualizerIndexURL())
        let directory = indexURL.deletingLastPathComponent()
        let main = try String(contentsOf: directory.appendingPathComponent("main.js"), encoding: .utf8)

        XCTAssertFalse(
            main.contains("CapsuleGeometry"),
            "Bundled three.min.js is r128 and does not include CapsuleGeometry; using it crashes the neural visualizer before the brain renders."
        )
        XCTAssertTrue(main.contains("CylinderGeometry"))
        XCTAssertTrue(main.contains("SphereGeometry"))
        XCTAssertTrue(main.contains("dataset.brainReady = 'true'"))
        XCTAssertTrue(main.contains("showFallback"))
        XCTAssertTrue(main.contains("ready: document.documentElement.dataset.brainReady === 'true'"))
    }

    func testCatBrainSettingsCopyDescribesNeuralControls() {
        XCTAssertEqual(CatCompanionSettingsCopy.windowTitle, "Cat Companion Neural Lab")
        XCTAssertEqual(CatCompanionSettingsCopy.visualizerTitle, "Neural temperament map")
        XCTAssertTrue(CatCompanionSettingsCopy.personalitySliders.contains("Activity"))
        XCTAssertTrue(CatCompanionSettingsCopy.personalitySliders.contains("Curiosity"))
        XCTAssertTrue(CatCompanionSettingsCopy.personalitySliders.contains("Playfulness"))
        XCTAssertTrue(CatCompanionSettingsCopy.sensoryToggles.contains("Purr when petted"))
        XCTAssertTrue(CatCompanionSettings().purringEnabled)
    }
}
