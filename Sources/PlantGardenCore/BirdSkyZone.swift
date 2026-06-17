import Foundation

public struct BirdSkyZone: Codable, Equatable, Identifiable, Sendable {
    public static let minimumPointCount = 3
    public static let maximumPointCount = 160

    public var id: UUID
    public var screenIndex: Int
    public var points: [GardenPoint]
    public var createdAt: Date
    public var skySeed: Int

    public init(
        id: UUID = UUID(),
        screenIndex: Int,
        points: [GardenPoint],
        createdAt: Date = Date(),
        skySeed: Int? = nil
    ) {
        self.id = id
        self.screenIndex = max(0, screenIndex)
        self.points = Self.sanitized(points)
        self.createdAt = createdAt
        self.skySeed = skySeed ?? abs(id.uuidString.hashValue % 1_000_000)
    }

    public var isPlayable: Bool {
        points.count >= Self.minimumPointCount
    }

    public var centroid: GardenPoint {
        guard !points.isEmpty else {
            return GardenPoint(x: 0.5, y: 0.25)
        }

        let sums = points.reduce((x: 0.0, y: 0.0)) { partial, point in
            (partial.x + point.x, partial.y + point.y)
        }
        return GardenPoint(
            x: (sums.x / Double(points.count)).clampedUnit,
            y: (sums.y / Double(points.count)).clampedUnit
        )
    }

    public var boundingBox: BirdSkyZoneBounds {
        guard let first = points.first else {
            return BirdSkyZoneBounds(minX: 0, minY: 0, maxX: 0, maxY: 0)
        }

        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        return BirdSkyZoneBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
    }

    private static func sanitized(_ points: [GardenPoint]) -> [GardenPoint] {
        guard !points.isEmpty else {
            return []
        }

        let clampedPoints = points.map { point in
            GardenPoint(x: point.x.clampedUnit, y: point.y.clampedUnit)
        }
        guard clampedPoints.count > maximumPointCount else {
            return clampedPoints
        }

        let step = Double(clampedPoints.count - 1) / Double(maximumPointCount - 1)
        return (0..<maximumPointCount).map { index in
            clampedPoints[Int((Double(index) * step).rounded())]
        }
    }
}

public struct BirdSkyZoneBounds: Codable, Equatable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX.clampedUnit
        self.minY = minY.clampedUnit
        self.maxX = maxX.clampedUnit
        self.maxY = maxY.clampedUnit
    }
}
