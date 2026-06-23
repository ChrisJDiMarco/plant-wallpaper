import AppKit
import XCTest
@testable import PlantWallpaper

final class GardenInteractionRegionWindowPlanTests: XCTestCase {
    func testUnchangedRegionFramesReuseExistingWindows() {
        let frames = [
            NSRect(x: 10, y: 20, width: 120, height: 80),
            NSRect(x: 200, y: 260, width: 90, height: 70)
        ]

        XCTAssertFalse(
            GardenInteractionRegionWindowPlan.shouldRebuild(
                currentFrames: frames,
                proposedFrames: frames,
                existingWindowCount: frames.count
            )
        )
    }

    func testMissingWindowsRebuildEvenWhenFrameCacheMatches() {
        let frames = [
            NSRect(x: 10, y: 20, width: 120, height: 80)
        ]

        XCTAssertTrue(
            GardenInteractionRegionWindowPlan.shouldRebuild(
                currentFrames: frames,
                proposedFrames: frames,
                existingWindowCount: 0
            )
        )
    }

    func testChangedRegionFramesRebuildWindows() {
        let currentFrames = [
            NSRect(x: 10, y: 20, width: 120, height: 80)
        ]
        let proposedFrames = [
            NSRect(x: 14, y: 20, width: 120, height: 80)
        ]

        XCTAssertTrue(
            GardenInteractionRegionWindowPlan.shouldRebuild(
                currentFrames: currentFrames,
                proposedFrames: proposedFrames,
                existingWindowCount: currentFrames.count
            )
        )
    }

    func testTinyFrameDriftReusesExistingWindows() {
        let currentFrames = [
            NSRect(x: 10, y: 20, width: 120, height: 80)
        ]
        let proposedFrames = [
            NSRect(x: 12, y: 18, width: 122, height: 79)
        ]

        XCTAssertFalse(
            GardenInteractionRegionWindowPlan.shouldRebuild(
                currentFrames: currentFrames,
                proposedFrames: proposedFrames,
                existingWindowCount: currentFrames.count
            )
        )
    }

    func testTinyRegionFramesAreDroppedBeforePlanning() {
        let frames = [
            NSRect(x: 0, y: 0, width: 7, height: 80),
            NSRect(x: 10, y: 10, width: 80, height: 7),
            NSRect(x: 20, y: 20, width: 80, height: 80)
        ]

        XCTAssertEqual(
            GardenInteractionRegionWindowPlan.displayableFrames(from: frames),
            [NSRect(x: 20, y: 20, width: 80, height: 80)]
        )
    }

    func testNearbyRegionFramesAreCoalescedBeforeWindowCreation() {
        let frames = [
            NSRect(x: 0, y: 0, width: 40, height: 40),
            NSRect(x: 50, y: 0, width: 40, height: 40),
            NSRect(x: 220, y: 0, width: 40, height: 40)
        ]

        XCTAssertEqual(
            GardenInteractionRegionWindowPlan.optimizedDisplayableFrames(
                from: frames,
                maximumFrameCount: 8,
                mergePadding: 12
            ),
            [
                NSRect(x: 0, y: 0, width: 90, height: 40),
                NSRect(x: 220, y: 0, width: 40, height: 40)
            ]
        )
    }

    func testDenseRegionPlansAreCappedByMergingClosestPairs() {
        let frames = (0..<8).map { index in
            NSRect(x: CGFloat(index) * 80, y: 0, width: 36, height: 36)
        }

        let optimizedFrames = GardenInteractionRegionWindowPlan.optimizedDisplayableFrames(
            from: frames,
            maximumFrameCount: 4,
            mergePadding: 0
        )

        XCTAssertEqual(optimizedFrames.count, 4)
        XCTAssertTrue(optimizedFrames.allSatisfy { $0.width >= 36 && $0.height >= 36 })
    }

    func testDesktopEventTapIgnoresClicksInsideInteractionWindows() throws {
        let testURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(contentsOf: projectRoot
            .appendingPathComponent("Sources/PlantWallpaper/GardenOverlayController.swift"))

        XCTAssertTrue(source.contains("guard !isPointInsideInteractionWindow(screenPoint),"))
        XCTAssertTrue(source.contains("interactionWindows.contains { $0.frame.contains(screenPoint) }"))
    }

    func testInspectorRegionClicksCannotOpenDesktopPlantingMenu() throws {
        let testURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(contentsOf: projectRoot
            .appendingPathComponent("Sources/PlantWallpaper/GardenOverlayController.swift"))

        XCTAssertTrue(source.contains("allowsDesktopPlantingMenu: false"))
        XCTAssertTrue(source.contains("!isPointOnGardenInteractionSurface(screenPoint)"))
        XCTAssertTrue(source.contains("canvasView.containsSelectionSurface(at: $0)"))
    }
}
