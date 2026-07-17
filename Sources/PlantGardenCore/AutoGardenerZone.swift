import Foundation

public enum AutoGardenerPlacementType: String, Codable, CaseIterable, Sendable {
    case smallPot
    case tabletopPot
    case floorPlanter
    case hangingPlanter
    case shelfOrSill
    case wallOrTrellis
    case raisedBed
    case borderBed
    case groundcover
    case statementTree

    public var displayName: String {
        switch self {
        case .smallPot:
            "Small pot"
        case .tabletopPot:
            "Tabletop pot"
        case .floorPlanter:
            "Floor planter"
        case .hangingPlanter:
            "Hanging planter"
        case .shelfOrSill:
            "Shelf / sill"
        case .wallOrTrellis:
            "Wall / trellis"
        case .raisedBed:
            "Raised bed"
        case .borderBed:
            "Border bed"
        case .groundcover:
            "Groundcover"
        case .statementTree:
            "Statement tree"
        }
    }

    public func speciesPalette(sceneKey: String?) -> [PlantSpecies] {
        let key = sceneKey?.lowercased() ?? ""
        if key.contains("water") || key.contains("pond") || key.contains("pavilion") {
            return [.waterLily, .cattails, .fern, .blueStarCreeper, .jasmine]
        }
        if key.contains("desert") || key.contains("arid") || key.contains("dry") || key.contains("texas") {
            return [.succulent, .lavender, .oliveTree, .rosemary, .creepingThyme]
        }
        if key.contains("apartment") || key.contains("studio") || key.contains("living-room") || key.contains("loft") {
            return [.monstera, .prayerPlant, .succulent, .orchid, .bonsai]
        }

        switch self {
        case .smallPot, .tabletopPot:
            return [.succulent, .orchid, .thyme, .bonsai, .saffronCrocus]
        case .floorPlanter:
            return [.monstera, .fern, .dwarfCitrus, .ravenZZPlant, .bamboo]
        case .hangingPlanter:
            return [.ivy, .staghornFern, .jasmine, .silverFallsDichondra, .wisteria]
        case .shelfOrSill:
            return [.prayerPlant, .orchid, .succulent, .herbCluster, .ravenZZPlant]
        case .wallOrTrellis:
            return [.ivy, .wisteria, .jasmine, .jadeVine, .peaVines]
        case .raisedBed:
            return [.determinateTomato, .sweetPepper, .rosemary, .thyme, .lavender]
        case .borderBed:
            return [.lavender, .rose, .hydrangea, .ornamentalGrass, .peony]
        case .groundcover:
            return [.mossCarpet, .cloverPatch, .creepingThyme, .blueStarCreeper, .wildflowerMeadow]
        case .statementTree:
            return [.japaneseMaple, .cherryTree, .dogwood, .magnolia, .oliveTree]
        }
    }
}

public enum AutoGardenerSize: String, Codable, CaseIterable, Sendable {
    case tiny
    case small
    case medium
    case large

    public var displayName: String {
        switch self {
        case .tiny:
            "Tiny"
        case .small:
            "Small"
        case .medium:
            "Medium"
        case .large:
            "Large"
        }
    }

    public var plantCount: Int {
        switch self {
        case .tiny:
            1
        case .small:
            2
        case .medium:
            3
        case .large:
            4
        }
    }

    public func scale(for species: PlantSpecies) -> Double {
        let range = species.defaultScaleRange
        let base = (range.lowerBound + range.upperBound) / 2
        let multiplier: Double
        switch self {
        case .tiny:
            multiplier = 0.62
        case .small:
            multiplier = 0.82
        case .medium:
            multiplier = 1.0
        case .large:
            multiplier = 1.18
        }
        return (base * multiplier).clamped(to: 0.48...1.75)
    }
}

public struct AutoGardenerZone: Codable, Equatable, Identifiable, Sendable {
    public static let minimumPointCount = 3
    public static let maximumPointCount = 160

    public var id: UUID
    public var screenIndex: Int
    public var points: [GardenPoint]
    public var createdAt: Date
    public var placementType: AutoGardenerPlacementType
    public var size: AutoGardenerSize

    public init(
        id: UUID = UUID(),
        screenIndex: Int,
        points: [GardenPoint],
        createdAt: Date = Date(),
        placementType: AutoGardenerPlacementType = .floorPlanter,
        size: AutoGardenerSize = .medium
    ) {
        self.id = id
        self.screenIndex = max(0, screenIndex)
        self.points = Self.sanitized(points)
        self.createdAt = createdAt
        self.placementType = placementType
        self.size = size
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
        return GardenPoint(x: totals.x / Double(points.count), y: totals.y / Double(points.count))
    }

    public var boundingBox: AutoGardenerZoneBounds {
        guard let first = points.first else {
            return AutoGardenerZoneBounds(minX: 0.48, minY: 0.68, maxX: 0.52, maxY: 0.72)
        }

        return points.dropFirst().reduce(
            AutoGardenerZoneBounds(minX: first.x, minY: first.y, maxX: first.x, maxY: first.y)
        ) { bounds, point in
            AutoGardenerZoneBounds(
                minX: min(bounds.minX, point.x),
                minY: min(bounds.minY, point.y),
                maxX: max(bounds.maxX, point.x),
                maxY: max(bounds.maxY, point.y)
            )
        }
    }

    public func plantingPoints() -> [GardenPoint] {
        let count = placementType == .statementTree ? 1 : size.plantCount
        guard count > 1 else {
            return [centroid.clamped]
        }

        let bounds = boundingBox
        let width = max(0.02, bounds.width)
        let height = max(0.02, bounds.height)
        return (0..<count).map { index in
            let fraction = (Double(index) + 0.5) / Double(count)
            let wave = sin(Double(index + 1) * 1.618) * 0.18
            return GardenPoint(
                x: bounds.minX + width * fraction,
                y: bounds.minY + height * (0.5 + wave)
            ).clamped
        }
    }

    public func recommendedSpecies(sceneKey: String?) -> [PlantSpecies] {
        let palette = placementType.speciesPalette(sceneKey: sceneKey)
        let offset = abs(id.uuidString.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) })
        return plantingPoints().indices.map { index in
            palette[(offset + index * 3) % palette.count]
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
}

public struct AutoGardenerZoneBounds: Codable, Equatable, Sendable {
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
