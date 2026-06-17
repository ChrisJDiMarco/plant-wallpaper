import XCTest
@testable import PlantWallpaper

final class CatCompanionChatWindowTests: XCTestCase {
    func testDefaultChatPanelCopyMatchesCompanionDesign() {
        XCTAssertEqual(CatCompanionChatCopy.title, "Miso")
        XCTAssertEqual(CatCompanionChatCopy.status, "nearby and listening")
        XCTAssertTrue(CatCompanionChatCopy.greeting.contains("Meow"))
        XCTAssertEqual(CatCompanionChatCopy.placeholder, "Ask your cat something...")
        XCTAssertEqual(CatCompanionChatCopy.quickPrompts.count, 2)
        XCTAssertTrue(CatCompanionChatCopy.quickPrompts.contains("How do I use this app?"))
    }

    @MainActor
    func testChatPanelUsesFixedLightMinimalDesign() {
        XCTAssertEqual(CatCompanionChatWindowController.panelSize, NSSize(width: 520, height: 590))
        XCTAssertGreaterThan(CatCompanionChatStyle.panelFill.brightnessComponent, 0.90)
        XCTAssertGreaterThan(CatCompanionChatStyle.cardFill.alphaComponent, 0.70)
        XCTAssertLessThan(CatCompanionChatStyle.ink.brightnessComponent, 0.25)
    }

    @MainActor
    func testChatPanelReadableTextColorsStayDarkOnLightSurfaces() {
        XCTAssertGreaterThan(CatCompanionChatStyle.panelFill.brightnessComponent, 0.90)
        XCTAssertGreaterThan(CatCompanionChatStyle.cardFill.brightnessComponent, 0.90)
        XCTAssertGreaterThan(CatCompanionChatStyle.chipFill.brightnessComponent, 0.70)
        XCTAssertLessThan(CatCompanionChatStyle.ink.brightnessComponent, 0.25)
        XCTAssertLessThan(CatCompanionChatStyle.mutedInk.brightnessComponent, 0.50)
        XCTAssertLessThan(CatCompanionChatStyle.softInk.brightnessComponent, 0.60)
        XCTAssertLessThan(CatCompanionChatStyle.placeholderInk.brightnessComponent, 0.60)
    }

    @MainActor
    func testChatPanelStaysVisibleAfterTheOpeningClickBurst() throws {
        let controller = CatCompanionChatWindowController()
        let panel = try XCTUnwrap(controller.window as? NSPanel)

        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertTrue(panel.isFloatingPanel)
    }

    @MainActor
    func testChatPanelDismissesOnlyForVisibleOutsideClicks() {
        let frame = NSRect(x: 200, y: 180, width: 520, height: 590)

        XCTAssertFalse(CatCompanionChatWindowController.shouldDismissForOutsideClickForTesting(
            isVisible: false,
            windowFrame: frame,
            screenPoint: NSPoint(x: 100, y: 100)
        ))
        XCTAssertFalse(CatCompanionChatWindowController.shouldDismissForOutsideClickForTesting(
            isVisible: true,
            windowFrame: frame,
            screenPoint: NSPoint(x: 360, y: 420)
        ))
        XCTAssertTrue(CatCompanionChatWindowController.shouldDismissForOutsideClickForTesting(
            isVisible: true,
            windowFrame: frame,
            screenPoint: NSPoint(x: 100, y: 100)
        ))
        XCTAssertFalse(CatCompanionChatWindowController.shouldDismissForOutsideClickForTesting(
            isVisible: true,
            windowFrame: frame,
            screenPoint: NSPoint(x: CGFloat.nan, y: 100)
        ))
    }

    @MainActor
    func testChatPanelFrameStaysInsideVisibleScreen() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        let frame = CatCompanionChatWindowController.frameForTesting(
            near: NSPoint(x: 1430, y: 880),
            visibleFrame: visibleFrame,
            preferredSize: CatCompanionChatWindowController.panelSize
        )

        XCTAssertEqual(frame.size, CatCompanionChatWindowController.panelSize)
        XCTAssertGreaterThanOrEqual(frame.minX, visibleFrame.minX + 42)
        XCTAssertGreaterThanOrEqual(frame.minY, visibleFrame.minY + 86)
        XCTAssertLessThanOrEqual(frame.maxX, visibleFrame.maxX - 42)
        XCTAssertLessThanOrEqual(frame.maxY, visibleFrame.maxY - 42)
    }

    @MainActor
    func testChatPanelFrameFitsSmallScreens() {
        let visibleFrame = NSRect(x: 20, y: 40, width: 500, height: 620)

        let frame = CatCompanionChatWindowController.frameForTesting(
            near: NSPoint(x: 45, y: 70),
            visibleFrame: visibleFrame,
            preferredSize: CatCompanionChatWindowController.panelSize
        )

        XCTAssertLessThanOrEqual(frame.width, visibleFrame.width - 84)
        XCTAssertLessThanOrEqual(frame.height, visibleFrame.height - 128)
        XCTAssertGreaterThanOrEqual(frame.minX, visibleFrame.minX + 42)
        XCTAssertGreaterThanOrEqual(frame.minY, visibleFrame.minY + 86)
    }

    @MainActor
    func testCatChatResponsesRouteCommonLocalRequests() {
        XCTAssertTrue(CatCompanionChatWindowController.responseForTesting("How's my garden?").contains("garden"))
        XCTAssertTrue(CatCompanionChatWindowController.responseForTesting("make me smile").contains("slow blink"))
        XCTAssertTrue(CatCompanionChatWindowController.responseForTesting("what can you do?").contains("WallpaperGarden"))
        XCTAssertTrue(CatCompanionChatWindowController.responseForTesting("what can you do?").contains("watering"))
    }

    @MainActor
    func testCatChatOwnsWallpaperGardenHelpAndAssistantPersonality() {
        let controls = CatCompanionChatWindowController.responseForTesting("How do I use this app?")
        let privacy = CatCompanionChatWindowController.responseForTesting("what about privacy and AI costs?")
        let appHelp = CatCompanionChatWindowController.responseForTesting("help me improve this scene")

        XCTAssertTrue(controls.contains("double-click"))
        XCTAssertTrue(controls.contains("main menu"))
        XCTAssertTrue(controls.contains("drag"))
        XCTAssertTrue(privacy.contains("Keychain"))
        XCTAssertTrue(privacy.contains("OpenAI"))
        XCTAssertTrue(appHelp.localizedCaseInsensitiveContains("focal"))
        XCTAssertTrue(appHelp.contains("Miso"))
    }

    @MainActor
    func testCatChatUsesAppSpecificOpenAIInstructions() {
        XCTAssertTrue(CatCompanionConversationRules.systemInstructions.contains("Miso"))
        XCTAssertTrue(CatCompanionConversationRules.systemInstructions.contains("WallpaperGarden"))
        XCTAssertTrue(CatCompanionConversationRules.systemInstructions.localizedCaseInsensitiveContains("cat"))
    }

    @MainActor
    func testCatChatOnlyOpensForEnabledCatHitsEvenWhenPlantIsBehindIt() {
        let bodyHit: [String: Any] = ["hit": true, "opensChat": true, "action": "chat"]
        let miss: [String: Any] = ["hit": false, "opensChat": false, "action": "none"]
        let wallTap: [String: Any] = ["hit": true, "opensChat": false, "action": "wallJumpDown"]

        XCTAssertTrue(CatCompanionController.shouldOpenChatForTesting(
            clickResult: bodyHit,
            isChatOnClickEnabled: true,
            isForegroundGardenElement: false
        ))
        XCTAssertFalse(CatCompanionController.shouldOpenChatForTesting(
            clickResult: bodyHit,
            isChatOnClickEnabled: false,
            isForegroundGardenElement: false
        ))
        XCTAssertTrue(CatCompanionController.shouldOpenChatForTesting(
            clickResult: bodyHit,
            isChatOnClickEnabled: true,
            isForegroundGardenElement: true
        ))
        XCTAssertFalse(CatCompanionController.shouldOpenChatForTesting(
            clickResult: miss,
            isChatOnClickEnabled: true,
            isForegroundGardenElement: false
        ))
        XCTAssertFalse(CatCompanionController.shouldOpenChatForTesting(
            clickResult: wallTap,
            isChatOnClickEnabled: true,
            isForegroundGardenElement: false
        ))
    }

    @MainActor
    func testRadioOrObjectSurfaceBlocksCatChatEvenIfCatHitTestWouldHit() {
        let bodyHit: [String: Any] = ["hit": true, "opensChat": true, "action": "chat"]

        XCTAssertFalse(CatCompanionController.shouldOpenChatForTesting(
            clickResult: bodyHit,
            isChatOnClickEnabled: true,
            isForegroundGardenElement: false,
            isChatBlockingGardenElement: true
        ))
    }

    @MainActor
    func testCatHitTestingStillRunsWhenPlantsAreBehindTheCat() {
        let point = NSPoint(x: 430, y: 510)

        XCTAssertTrue(CatCompanionController.shouldForwardClickForTesting(
            at: point,
            isEnabled: true,
            isDesktopSceneVisible: true,
            isForegroundGardenElement: true
        ))
        XCTAssertFalse(CatCompanionController.shouldForwardClickForTesting(
            at: point,
            isEnabled: false,
            isDesktopSceneVisible: true,
            isForegroundGardenElement: false
        ))
        XCTAssertFalse(CatCompanionController.shouldForwardClickForTesting(
            at: point,
            isEnabled: true,
            isDesktopSceneVisible: false,
            isForegroundGardenElement: false
        ))
        XCTAssertTrue(CatCompanionController.shouldForwardClickForTesting(
            at: point,
            isEnabled: true,
            isDesktopSceneVisible: true,
            isForegroundGardenElement: false
        ))
    }

    @MainActor
    func testMouseTrackingOnlyRunsOverVisibleDesktopScene() {
        let point = NSPoint(x: 430, y: 510)

        XCTAssertTrue(CatCompanionController.shouldTrackMouseForTesting(
            at: point,
            isEnabled: true,
            mouseReactions: true,
            isDesktopSceneVisible: true,
            hasWindows: true
        ))
        XCTAssertFalse(CatCompanionController.shouldTrackMouseForTesting(
            at: point,
            isEnabled: true,
            mouseReactions: true,
            isDesktopSceneVisible: false,
            hasWindows: true
        ))
        XCTAssertFalse(CatCompanionController.shouldTrackMouseForTesting(
            at: point,
            isEnabled: true,
            mouseReactions: false,
            isDesktopSceneVisible: true,
            hasWindows: true
        ))
        XCTAssertFalse(CatCompanionController.shouldTrackMouseForTesting(
            at: point,
            isEnabled: false,
            mouseReactions: true,
            isDesktopSceneVisible: true,
            hasWindows: true
        ))
        XCTAssertFalse(CatCompanionController.shouldTrackMouseForTesting(
            at: NSPoint(x: CGFloat.nan, y: 510),
            isEnabled: true,
            mouseReactions: true,
            isDesktopSceneVisible: true,
            hasWindows: true
        ))
    }

    @MainActor
    func testWallClimbingCatClickConsumesGardenSelection() {
        let updatedAt = Date(timeIntervalSince1970: 1_000)
        let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let snapshot = CatCompanionClickSnapshot(
            screenFrame: screenFrame,
            stateName: "wallClimb",
            worldX: 1.55,
            worldY: 2.0,
            catSizePx: 175,
            groundFraction: 0,
            updatedAt: updatedAt
        )
        let clickPoint = Self.screenPoint(
            screenFrame: screenFrame,
            worldX: snapshot.worldX,
            worldY: snapshot.worldY + 0.45,
            catSizePx: snapshot.catSizePx,
            groundFraction: snapshot.groundFraction
        )

        XCTAssertTrue(CatCompanionController.shouldConsumeGardenClickForTesting(
            snapshot: snapshot,
            at: clickPoint,
            now: updatedAt.addingTimeInterval(0.1)
        ))

        let visibleSideBodyPoint = Self.screenPoint(
            screenFrame: screenFrame,
            worldX: snapshot.worldX - 1.38,
            worldY: snapshot.worldY + 0.45,
            catSizePx: snapshot.catSizePx,
            groundFraction: snapshot.groundFraction
        )
        XCTAssertTrue(CatCompanionController.shouldConsumeGardenClickForTesting(
            snapshot: snapshot,
            at: visibleSideBodyPoint,
            now: updatedAt.addingTimeInterval(0.1)
        ))
    }

    @MainActor
    func testOnlyFreshWallCatBodyClicksConsumeGardenSelection() {
        let updatedAt = Date(timeIntervalSince1970: 1_000)
        let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let wallSnapshot = CatCompanionClickSnapshot(
            screenFrame: screenFrame,
            stateName: "wallHang",
            worldX: -1.55,
            worldY: 2.4,
            catSizePx: 175,
            groundFraction: 0,
            updatedAt: updatedAt
        )
        let idleSnapshot = CatCompanionClickSnapshot(
            screenFrame: screenFrame,
            stateName: "idle",
            worldX: wallSnapshot.worldX,
            worldY: wallSnapshot.worldY,
            catSizePx: wallSnapshot.catSizePx,
            groundFraction: wallSnapshot.groundFraction,
            updatedAt: updatedAt
        )
        let bodyPoint = Self.screenPoint(
            screenFrame: screenFrame,
            worldX: wallSnapshot.worldX,
            worldY: wallSnapshot.worldY + 0.45,
            catSizePx: wallSnapshot.catSizePx,
            groundFraction: wallSnapshot.groundFraction
        )
        let missPoint = NSPoint(x: bodyPoint.x + 640, y: bodyPoint.y)

        XCTAssertFalse(CatCompanionController.shouldConsumeGardenClickForTesting(
            snapshot: idleSnapshot,
            at: bodyPoint,
            now: updatedAt.addingTimeInterval(0.1)
        ))
        XCTAssertFalse(CatCompanionController.shouldConsumeGardenClickForTesting(
            snapshot: wallSnapshot,
            at: missPoint,
            now: updatedAt.addingTimeInterval(0.1)
        ))
        XCTAssertFalse(CatCompanionController.shouldConsumeGardenClickForTesting(
            snapshot: wallSnapshot,
            at: bodyPoint,
            now: updatedAt.addingTimeInterval(CatCompanionClickSnapshot.freshInterval + 0.1)
        ))
    }

    @MainActor
    func testWallJumpDownClaimClearsBehindCatSelection() {
        XCTAssertTrue(GardenOverlayController.shouldClearSelectionAfterCatClaimForTesting(action: "wallJumpDown"))
        XCTAssertTrue(GardenOverlayController.shouldClearSelectionAfterCatClaimForTesting(action: "chat"))
        XCTAssertTrue(GardenOverlayController.shouldClearSelectionAfterCatClaimForTesting(action: nil))
    }

    private static func screenPoint(
        screenFrame: NSRect,
        worldX: Double,
        worldY: Double,
        catSizePx: Double,
        groundFraction: Double
    ) -> NSPoint {
        let worldPerPx = 0.62 / catSizePx
        let localX = Double(screenFrame.width) / 2 + worldX / worldPerPx
        let localYFromBottom = groundFraction * Double(screenFrame.height) + worldY / worldPerPx
        return NSPoint(
            x: screenFrame.minX + CGFloat(localX),
            y: screenFrame.minY + CGFloat(localYFromBottom)
        )
    }
}
