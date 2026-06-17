import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden desktop header exclusion")
struct GardenDesktopHeaderExclusionTests {
    @Test("menu bar area blocks garden interaction")
    func menuBarAreaBlocksGardenInteraction() {
        #expect(GardenDesktopHeaderExclusion.isMenuBarArea(
            pointY: 1_055,
            screenMaxY: 1_080,
            visibleFrameMaxY: 1_045
        ))
    }

    @Test("desktop area below header stays interactive")
    func desktopAreaBelowHeaderStaysInteractive() {
        #expect(!GardenDesktopHeaderExclusion.isMenuBarArea(
            pointY: 1_000,
            screenMaxY: 1_080,
            visibleFrameMaxY: 1_045
        ))
    }
}
