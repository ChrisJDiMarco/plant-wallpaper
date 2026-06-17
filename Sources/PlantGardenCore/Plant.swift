import Foundation

public enum GrowthStage: String, Codable, Sendable {
    case seedling
    case sprout
    case young
    case mature
    case blooming
    case dead
}

public enum PlantCareNeed: String, Codable, Sendable {
    case dead
    case urgentWater
    case waterSoon
    case recovering
    case nourish
    case thriving

    public var summary: String {
        switch self {
        case .dead:
            "Dead"
        case .urgentWater:
            "Water now"
        case .waterSoon:
            "Needs water"
        case .recovering:
            "Recovering"
        case .nourish:
            "Ready to feed"
        case .thriving:
            "Thriving"
        }
    }

    public var needsAttention: Bool {
        switch self {
        case .dead, .urgentWater, .waterSoon, .recovering:
            true
        case .nourish, .thriving:
            false
        }
    }

    public var isThirsty: Bool {
        switch self {
        case .urgentWater, .waterSoon:
            true
        case .dead, .recovering, .nourish, .thriving:
            false
        }
    }
}

public struct Plant: Codable, Equatable, Identifiable, Sendable {
    public static let deathHealthThreshold = 0.02

    public var id: UUID
    public var species: PlantSpecies
    public var screenIndex: Int
    public var position: GardenPoint
    public var plantedAt: Date
    public var lastTendedAt: Date
    public var ageSeconds: TimeInterval
    public var growth: Double
    public var hydration: Double
    public var health: Double
    public var bloomProgress: Double
    public var lastStageChangedAt: Date?
    public var lastNourishedAt: Date?
    public var diedAt: Date?
    public var nickname: String
    public var swaySeed: Double
    public var scale: Double
    public var customAssetID: String?
    public var placementLocked: Bool

    public init(
        id: UUID = UUID(),
        species: PlantSpecies,
        screenIndex: Int,
        position: GardenPoint,
        plantedAt: Date = Date(),
        lastTendedAt: Date = Date(),
        ageSeconds: TimeInterval = 0,
        growth: Double = 0.08,
        hydration: Double = 0.78,
        health: Double = 0.86,
        bloomProgress: Double = 0,
        lastStageChangedAt: Date? = nil,
        lastNourishedAt: Date? = nil,
        diedAt: Date? = nil,
        nickname: String? = nil,
        swaySeed: Double = Double.random(in: 0...10_000),
        scale: Double? = nil,
        customAssetID: String? = nil,
        placementLocked: Bool = false
    ) {
        self.id = id
        self.species = species
        self.screenIndex = screenIndex
        self.position = position.clamped
        self.plantedAt = plantedAt
        self.lastTendedAt = lastTendedAt
        self.ageSeconds = max(0, ageSeconds)
        self.growth = growth.clampedUnit
        self.hydration = hydration.clampedUnit
        self.health = health.clampedUnit
        self.bloomProgress = bloomProgress.clampedUnit
        self.lastStageChangedAt = lastStageChangedAt
        self.lastNourishedAt = lastNourishedAt
        self.diedAt = diedAt
        self.nickname = nickname ?? species.displayName
        self.swaySeed = swaySeed
        self.scale = scale ?? Double.random(in: species.defaultScaleRange)
        self.customAssetID = customAssetID
        self.placementLocked = placementLocked
    }

    enum CodingKeys: String, CodingKey {
        case id
        case species
        case screenIndex
        case position
        case plantedAt
        case lastTendedAt
        case ageSeconds
        case growth
        case hydration
        case health
        case bloomProgress
        case lastStageChangedAt
        case lastNourishedAt
        case diedAt
        case nickname
        case swaySeed
        case scale
        case customAssetID
        case placementLocked
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            species: try container.decode(PlantSpecies.self, forKey: .species),
            screenIndex: try container.decode(Int.self, forKey: .screenIndex),
            position: try container.decode(GardenPoint.self, forKey: .position),
            plantedAt: try container.decode(Date.self, forKey: .plantedAt),
            lastTendedAt: try container.decode(Date.self, forKey: .lastTendedAt),
            ageSeconds: try container.decode(TimeInterval.self, forKey: .ageSeconds),
            growth: try container.decode(Double.self, forKey: .growth),
            hydration: try container.decode(Double.self, forKey: .hydration),
            health: try container.decode(Double.self, forKey: .health),
            bloomProgress: try container.decode(Double.self, forKey: .bloomProgress),
            lastStageChangedAt: try container.decodeIfPresent(Date.self, forKey: .lastStageChangedAt),
            lastNourishedAt: try container.decodeIfPresent(Date.self, forKey: .lastNourishedAt),
            diedAt: try container.decodeIfPresent(Date.self, forKey: .diedAt),
            nickname: try container.decode(String.self, forKey: .nickname),
            swaySeed: try container.decode(Double.self, forKey: .swaySeed),
            scale: try container.decode(Double.self, forKey: .scale),
            customAssetID: try container.decodeIfPresent(String.self, forKey: .customAssetID),
            placementLocked: try container.decodeIfPresent(Bool.self, forKey: .placementLocked) ?? false
        )
    }

    public var growthStage: GrowthStage {
        if isDead {
            return .dead
        }

        if bloomProgress > 0.62 {
            return .blooming
        }

        switch growth {
        case ..<0.18:
            return .seedling
        case ..<0.42:
            return .sprout
        case ..<0.78:
            return .young
        default:
            return .mature
        }
    }

    public var isWilting: Bool {
        isDead || hydration < 0.18 || health < 0.28
    }

    /// Edible plants at high growth can be harvested: the crop is counted,
    /// seeds are yielded, and the plant cycles back to regrowth.
    public var isHarvestReady: Bool {
        species.kind == .edible
            && growth >= GardenEngine.harvestReadyGrowthThreshold
            && !isDead
    }

    public var isDead: Bool {
        diedAt != nil || health <= Self.deathHealthThreshold
    }

    public var careNeed: PlantCareNeed {
        if isDead {
            return .dead
        }

        let moisture = moisturePreference

        if moisture.fit == .parched {
            return .urgentWater
        }

        if health < 0.26 {
            return .recovering
        }

        if moisture.fit == .dry {
            return .waterSoon
        }

        if growthStage != .blooming
            && growth < 0.94
            && health > 0.56
            && moisture.fit == .ideal
            && nutrientProfile.fit != .rich {
            return .nourish
        }

        return .thriving
    }

    public var statusSummary: String {
        if isDead {
            return "Dead"
        }

        if growthStage == .blooming {
            return "Blooming"
        }

        if growth > 0.82 {
            return "Mature"
        }

        return careNeed.summary
    }
}
