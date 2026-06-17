import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden desktop interaction gate")
struct GardenDesktopInteractionGateTests {
    @Test("open status menu blocks desktop mouse handling")
    func openStatusMenuBlocksDesktopMouseHandling() {
        #expect(!GardenDesktopInteractionGate.allowsDesktopMouseHandling(
            isStatusMenuOpen: true,
            isMenuBarArea: false,
            isDesktopVisible: true
        ))
    }

    @Test("menu bar area blocks desktop mouse handling")
    func menuBarAreaBlocksDesktopMouseHandling() {
        #expect(!GardenDesktopInteractionGate.allowsDesktopMouseHandling(
            isStatusMenuOpen: false,
            isMenuBarArea: true,
            isDesktopVisible: true
        ))
    }

    @Test("desktop mouse handling requires visible desktop")
    func desktopMouseHandlingRequiresVisibleDesktop() {
        #expect(!GardenDesktopInteractionGate.allowsDesktopMouseHandling(
            isStatusMenuOpen: false,
            isMenuBarArea: false,
            isDesktopVisible: false
        ))
    }

    @Test("locked garden blocks desktop mouse handling")
    func lockedGardenBlocksDesktopMouseHandling() {
        #expect(!GardenDesktopInteractionGate.allowsDesktopMouseHandling(
            isStatusMenuOpen: false,
            isMenuBarArea: false,
            isDesktopVisible: true,
            isGardenInteractionLocked: true
        ))
    }

    @Test("selection clearing requires visible desktop")
    func selectionClearingRequiresVisibleDesktop() {
        #expect(GardenDesktopInteractionGate.allowsDesktopSelectionClearing(
            isStatusMenuOpen: false,
            isMenuBarArea: false,
            isDesktopVisible: true
        ))
        #expect(!GardenDesktopInteractionGate.allowsDesktopSelectionClearing(
            isStatusMenuOpen: false,
            isMenuBarArea: false,
            isDesktopVisible: false
        ))
    }

    @Test("selection clearing is blocked by status menu and menu bar")
    func selectionClearingIsBlockedByStatusMenuAndMenuBar() {
        #expect(!GardenDesktopInteractionGate.allowsDesktopSelectionClearing(
            isStatusMenuOpen: true,
            isMenuBarArea: false,
            isDesktopVisible: true
        ))
        #expect(!GardenDesktopInteractionGate.allowsDesktopSelectionClearing(
            isStatusMenuOpen: false,
            isMenuBarArea: true,
            isDesktopVisible: true
        ))
    }

    @Test("locked garden blocks desktop selection clearing")
    func lockedGardenBlocksDesktopSelectionClearing() {
        #expect(!GardenDesktopInteractionGate.allowsDesktopSelectionClearing(
            isStatusMenuOpen: false,
            isMenuBarArea: false,
            isDesktopVisible: true,
            isGardenInteractionLocked: true
        ))
    }

    @Test("active drags continue over visible desktop but not while menu is open")
    func activeDragsContinueOverVisibleDesktopButNotWhileMenuIsOpen() {
        #expect(GardenDesktopInteractionGate.allowsDesktopDragHandling(
            isStatusMenuOpen: false,
            isMenuBarArea: false,
            hasActiveDrag: true,
            isDesktopVisible: false
        ))

        #expect(!GardenDesktopInteractionGate.allowsDesktopDragHandling(
            isStatusMenuOpen: true,
            isMenuBarArea: false,
            hasActiveDrag: true,
            isDesktopVisible: true
        ))
    }

    @Test("locked garden blocks active drags")
    func lockedGardenBlocksActiveDrags() {
        #expect(!GardenDesktopInteractionGate.allowsDesktopDragHandling(
            isStatusMenuOpen: false,
            isMenuBarArea: false,
            hasActiveDrag: true,
            isDesktopVisible: true,
            isGardenInteractionLocked: true
        ))
    }
}
