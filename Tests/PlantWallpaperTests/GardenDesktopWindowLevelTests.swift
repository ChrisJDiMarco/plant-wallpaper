import XCTest
@testable import PlantWallpaper

@MainActor
final class GardenDesktopWindowLevelTests: XCTestCase {
    func testCatCompanionRendersAboveGardenWindows() {
        XCTAssertGreaterThan(
            CatCompanionWindow.companionLevel.rawValue,
            GardenWindow.canvasLevel.rawValue,
            "Cat companion should render above the plant canvas so plants cannot visually cover it."
        )
        XCTAssertGreaterThan(
            CatCompanionWindow.companionLevel.rawValue,
            GardenInteractionRegionWindow.interactionLevel.rawValue,
            "Cat companion should render above transparent interaction regions so ordering remains stable while editing plants."
        )
    }

    func testPlantSpotlightRendersAboveLiveGardenOverlays() {
        XCTAssertEqual(
            GardenWindow.canvasLevel(isPlantSpotlightVisible: false),
            GardenWindow.canvasLevel
        )
        XCTAssertGreaterThan(
            GardenWindow.canvasLevel(isPlantSpotlightVisible: true).rawValue,
            GnomeTribeWindow.companionLevel.rawValue,
            "Plant spotlight should temporarily rise above gnome tribe windows."
        )
        XCTAssertGreaterThan(
            GardenWindow.canvasLevel(isPlantSpotlightVisible: true).rawValue,
            BirdFlockWindow.companionLevel.rawValue,
            "Plant spotlight should temporarily rise above bird flock windows."
        )
        XCTAssertGreaterThan(
            GardenWindow.canvasLevel(isPlantSpotlightVisible: true).rawValue,
            CatCompanionWindow.companionLevel.rawValue,
            "Plant spotlight should temporarily rise above live companion overlays while it is acting as a modal."
        )
    }
}
