import CoreGraphics
import Testing
@testable import PlantWallpaper

@Suite("Cat desktop environment")
struct CatDesktopEnvironmentTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test("hidden dock or full visible frame puts cat on screen bottom")
    func hiddenDockReportsNoDock() {
        let environment = CatDesktopEnvironment(
            screenFrame: screen,
            visibleFrame: screen,
            baseGroundFraction: 0.10
        )

        #expect(!environment.dockVisible)
        #expect(environment.dockSide == .none)
        #expect(environment.wallInsetsPx.bottom == 0)
        #expect(environment.effectiveGroundFraction == 0)
    }

    @Test("bottom dock sets ground line to dock top")
    func bottomDockSetsGroundLineToDockTop() {
        let environment = CatDesktopEnvironment(
            screenFrame: screen,
            visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 780),
            baseGroundFraction: 0.10
        )

        #expect(environment.dockVisible)
        #expect(environment.dockSide == .bottom)
        #expect(environment.dockThicknessPx == 80)
        #expect(environment.wallInsetsPx.bottom == 80)
        #expect(abs(environment.effectiveGroundFraction - (80.0 / 900.0)) < 0.0001)
    }

    @Test("large bottom dock uses exact dock height")
    func largeBottomDockUsesExactDockHeight() {
        let environment = CatDesktopEnvironment(
            screenFrame: screen,
            visibleFrame: CGRect(x: 0, y: 120, width: 1440, height: 740),
            baseGroundFraction: 0.10
        )

        #expect(environment.dockSide == .bottom)
        #expect(abs(environment.effectiveGroundFraction - (120.0 / 900.0)) < 0.0001)
    }

    @Test("left dock reports left wall inset")
    func leftDockReportsLeftWallInset() {
        let environment = CatDesktopEnvironment(
            screenFrame: screen,
            visibleFrame: CGRect(x: 96, y: 0, width: 1344, height: 860),
            baseGroundFraction: 0.10
        )

        #expect(environment.dockVisible)
        #expect(environment.dockSide == .left)
        #expect(environment.wallInsetsPx.left == 96)
        #expect(environment.wallInsetsPx.right == 0)
        #expect(environment.wallInsetsPx.bottom == 0)
    }

    @Test("right dock reports right wall inset")
    func rightDockReportsRightWallInset() {
        let environment = CatDesktopEnvironment(
            screenFrame: screen,
            visibleFrame: CGRect(x: 0, y: 0, width: 1320, height: 860),
            baseGroundFraction: 0.10
        )

        #expect(environment.dockVisible)
        #expect(environment.dockSide == .right)
        #expect(environment.wallInsetsPx.right == 120)
        #expect(environment.wallInsetsPx.left == 0)
    }

    @Test("menu bar only top inset is ignored as dock")
    func menuBarOnlyTopInsetIsIgnoredAsDock() {
        let environment = CatDesktopEnvironment(
            screenFrame: screen,
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 860),
            baseGroundFraction: 0.10
        )

        #expect(!environment.dockVisible)
        #expect(environment.dockSide == .none)
        #expect(environment.dockThicknessPx == 0)
        #expect(environment.effectiveGroundFraction == 0)
    }
}
