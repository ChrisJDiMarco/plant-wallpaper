import Foundation

public struct GardenPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var clamped: GardenPoint {
        GardenPoint(
            x: min(0.98, max(0.02, x)),
            y: min(0.96, max(0.08, y))
        )
    }
}

public extension Double {
    var clampedUnit: Double {
        min(1, max(0, self))
    }

    func clamped(to range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
