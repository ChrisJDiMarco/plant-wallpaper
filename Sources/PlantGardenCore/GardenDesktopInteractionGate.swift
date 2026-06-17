import Foundation

public enum GardenDesktopInteractionGate {
    public static func allowsDesktopMouseHandling(
        isStatusMenuOpen: Bool,
        isMenuBarArea: Bool,
        isDesktopVisible: Bool,
        isGardenInteractionLocked: Bool = false
    ) -> Bool {
        !isGardenInteractionLocked && !isStatusMenuOpen && !isMenuBarArea && isDesktopVisible
    }

    public static func allowsDesktopSelectionClearing(
        isStatusMenuOpen: Bool,
        isMenuBarArea: Bool,
        isDesktopVisible: Bool,
        isGardenInteractionLocked: Bool = false
    ) -> Bool {
        !isGardenInteractionLocked && !isStatusMenuOpen && !isMenuBarArea && isDesktopVisible
    }

    public static func allowsDesktopDragHandling(
        isStatusMenuOpen: Bool,
        isMenuBarArea: Bool,
        hasActiveDrag: Bool,
        isDesktopVisible: Bool,
        isGardenInteractionLocked: Bool = false
    ) -> Bool {
        !isGardenInteractionLocked && !isStatusMenuOpen && !isMenuBarArea && (hasActiveDrag || isDesktopVisible)
    }
}
