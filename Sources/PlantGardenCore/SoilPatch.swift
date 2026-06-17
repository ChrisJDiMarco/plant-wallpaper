import Foundation

public struct SoilPatch: Codable, Equatable, Identifiable, Sendable {
    public static let minimumPointCount = 3
    public static let maximumPointCount = 200

    public var id: UUID
    public var screenIndex: Int
    public var points: [GardenPoint]
    public var createdAt: Date
    public var soilSeed: Int

    public init(
        id: UUID = UUID(),
        screenIndex: Int,
        points: [GardenPoint],
        createdAt: Date = Date(),
        soilSeed: Int? = nil
    ) {
        self.id = id
        self.screenIndex = max(0, screenIndex)
        self.points = Self.sanitized(points)
        self.createdAt = createdAt
        self.soilSeed = soilSeed ?? Self.seed(for: id)
    }

    public var isPlayable: Bool {
        points.count >= Self.minimumPointCount
    }

    public var centroid: GardenPoint {
        guard !points.isEmpty else {
            return GardenPoint(x: 0.5, y: 0.7)
        }

        let totals = points.reduce((x: 0.0, y: 0.0)) { partial, point in
            (partial.x + point.x, partial.y + point.y)
        }
        return GardenPoint(
            x: totals.x / Double(points.count),
            y: totals.y / Double(points.count)
        )
    }

    public var boundingBox: SoilPatchBounds {
        guard let first = points.first else {
            return SoilPatchBounds(minX: 0.48, minY: 0.68, maxX: 0.52, maxY: 0.72)
        }

        return points.dropFirst().reduce(
            SoilPatchBounds(minX: first.x, minY: first.y, maxX: first.x, maxY: first.y)
        ) { bounds, point in
            SoilPatchBounds(
                minX: min(bounds.minX, point.x),
                minY: min(bounds.minY, point.y),
                maxX: max(bounds.maxX, point.x),
                maxY: max(bounds.maxY, point.y)
            )
        }
    }

    public static func sanitized(_ points: [GardenPoint]) -> [GardenPoint] {
        var sampled: [GardenPoint] = []
        sampled.reserveCapacity(min(points.count, maximumPointCount))
        let stride = max(1, Int(ceil(Double(points.count) / Double(maximumPointCount))))

        for (index, point) in points.enumerated() where index % stride == 0 {
            let clampedPoint = GardenPoint(
                x: point.x.clamped(to: 0...1),
                y: point.y.clamped(to: 0...1)
            )
            if sampled.last != clampedPoint {
                sampled.append(clampedPoint)
            }
        }

        return sampled
    }

    public static func seed(for id: UUID) -> Int {
        abs(id.uuidString.unicodeScalars.reduce(0) { partial, scalar in
            partial &* 31 &+ Int(scalar.value)
        })
    }
}

public struct SoilPatchBounds: Codable, Equatable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public var width: Double {
        max(0, maxX - minX)
    }

    public var height: Double {
        max(0, maxY - minY)
    }
}
