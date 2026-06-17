import Foundation

public enum GardenDesktopHeaderExclusion {
    public static func isMenuBarArea(
        pointY: Double,
        screenMaxY: Double,
        visibleFrameMaxY: Double,
        fallbackHeaderHeight: Double = 44
    ) -> Bool {
        let measuredHeaderHeight = max(0, screenMaxY - visibleFrameMaxY)
        let headerHeight = max(fallbackHeaderHeight, measuredHeaderHeight)
        return pointY >= screenMaxY - headerHeight
    }
}
