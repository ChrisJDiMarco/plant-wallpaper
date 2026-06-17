import Foundation

public struct GnomeTribeZone: Codable, Equatable, Identifiable, Sendable {
    public static let minimumPointCount = 3
    public static let maximumPointCount = 160

    public var id: UUID
    public var screenIndex: Int
    public var points: [GardenPoint]
    public var createdAt: Date
    public var cultureSeed: Int

    public init(
        id: UUID = UUID(),
        screenIndex: Int,
        points: [GardenPoint],
        createdAt: Date = Date(),
        cultureSeed: Int? = nil
    ) {
        self.id = id
        self.screenIndex = max(0, screenIndex)
        self.points = Self.sanitized(points)
        self.createdAt = createdAt
        self.cultureSeed = cultureSeed ?? Self.seed(for: id)
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

    public var boundingBox: GnomeTribeZoneBounds {
        guard let first = points.first else {
            return GnomeTribeZoneBounds(minX: 0.48, minY: 0.68, maxX: 0.52, maxY: 0.72)
        }

        return points.dropFirst().reduce(
            GnomeTribeZoneBounds(minX: first.x, minY: first.y, maxX: first.x, maxY: first.y)
        ) { bounds, point in
            GnomeTribeZoneBounds(
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

    private static func seed(for id: UUID) -> Int {
        abs(id.uuidString.unicodeScalars.reduce(0) { partial, scalar in
            partial &* 31 &+ Int(scalar.value)
        })
    }
}

public struct GnomeTribeZoneBounds: Codable, Equatable, Sendable {
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

public struct GnomeTribeSettlementPlan: Codable, Equatable, Sendable {
    public static let minimumExpansionDurationDays = 0.25
    public static let maximumExpansionDurationDays = 30.0
    public static let defaultExpansionDurationDays = 7.0

    public var startedAt: Date?
    public var startingZoneID: UUID?
    public var expansionDurationDays: Double

    public init(
        startedAt: Date? = nil,
        startingZoneID: UUID? = nil,
        expansionDurationDays: Double = Self.defaultExpansionDurationDays
    ) {
        self.startedAt = startedAt
        self.startingZoneID = startingZoneID
        self.expansionDurationDays = Self.clampedExpansionDuration(expansionDurationDays)
    }

    public var isCommitted: Bool {
        startedAt != nil
    }

    public func normalized(for zones: [GnomeTribeZone]) -> GnomeTribeSettlementPlan {
        guard !zones.isEmpty else {
            return GnomeTribeSettlementPlan(
                startedAt: nil,
                startingZoneID: nil,
                expansionDurationDays: expansionDurationDays
            )
        }

        let validStartingID = startingZoneID.flatMap { candidateID in
            zones.contains { $0.id == candidateID } ? candidateID : nil
        } ?? zones.first?.id

        return GnomeTribeSettlementPlan(
            startedAt: startedAt,
            startingZoneID: validStartingID,
            expansionDurationDays: expansionDurationDays
        )
    }

    public func committed(
        at date: Date,
        startingZoneID: UUID?,
        zones: [GnomeTribeZone],
        expansionDurationDays: Double? = nil
    ) -> GnomeTribeSettlementPlan {
        GnomeTribeSettlementPlan(
            startedAt: date,
            startingZoneID: startingZoneID ?? self.startingZoneID ?? zones.first?.id,
            expansionDurationDays: expansionDurationDays ?? self.expansionDurationDays
        )
        .normalized(for: zones)
    }

    public static func defaultForExistingZones(_ zones: [GnomeTribeZone]) -> GnomeTribeSettlementPlan {
        guard let firstZone = zones.first else {
            return GnomeTribeSettlementPlan(startedAt: nil)
        }

        let earliestCreatedAt = zones.map(\.createdAt).min() ?? firstZone.createdAt
        return GnomeTribeSettlementPlan(
            startedAt: earliestCreatedAt,
            startingZoneID: firstZone.id
        )
    }

    private static func clampedExpansionDuration(_ value: Double) -> Double {
        guard value.isFinite else {
            return defaultExpansionDurationDays
        }

        return value.clamped(to: minimumExpansionDurationDays...maximumExpansionDurationDays)
    }
}

public struct GnomeTribePerspective: Codable, Equatable, Sendable {
    public static let defaultValue = GnomeTribePerspective()

    public var yawDegrees: Double
    public var elevationDegrees: Double

    /// The lowest (flattest) elevation the camera tilts to — the angle a user
    /// reaches by dragging all the way down. This is the default so freshly
    /// placed gnome zones already sit at the preferred low, grounded view.
    public static let flattestElevation: Double = 24

    public init(
        yawDegrees: Double = 0,
        elevationDegrees: Double = flattestElevation
    ) {
        self.yawDegrees = Self.clampedYaw(yawDegrees)
        self.elevationDegrees = Self.clampedElevation(elevationDegrees)
    }

    public func adjustedByDrag(deltaX: Double, deltaY: Double) -> GnomeTribePerspective {
        GnomeTribePerspective(
            yawDegrees: yawDegrees + deltaX * 0.10,
            elevationDegrees: elevationDegrees + deltaY * 0.08
        )
    }

    private static func clampedYaw(_ value: Double) -> Double {
        guard value.isFinite else {
            return defaultValue.yawDegrees
        }
        return value.clamped(to: -55...55)
    }

    private static func clampedElevation(_ value: Double) -> Double {
        guard value.isFinite else {
            return defaultValue.elevationDegrees
        }
        return value.clamped(to: 24...68)
    }
}
