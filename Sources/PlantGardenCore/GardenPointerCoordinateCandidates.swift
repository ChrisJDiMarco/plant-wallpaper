import Foundation

public enum GardenPointerCoordinateCandidates {
    /// Returns the candidate y coordinates to hit test for a pointer event.
    ///
    /// Historically this also returned the vertically mirrored coordinate to
    /// paper over an event-source flip bug. That meant every click was hit
    /// tested at two screen positions, so clicks on empty desktop could
    /// activate a plant living at the mirrored point - and clicks meant to
    /// clear a selection were suppressed for the same reason. The flip itself
    /// is now fixed at the source (primary-screen Quartz conversion), so the
    /// converted coordinate is the only valid candidate.
    public static func yValues(convertedY: Double, viewHeight: Double) -> [Double] {
        _ = viewHeight
        return [convertedY]
    }
}
