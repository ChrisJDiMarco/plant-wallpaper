import Foundation

public enum GardenVitalityMood: String, Codable, Sendable {
    case flourishing
    case steady
    case thirsty
    case recovering
    case dead
    case dormant
}

public struct GardenVitality: Equatable, Sendable {
    public let plantCount: Int
    public let score: Double
    public let mood: GardenVitalityMood
    public let needsCareCount: Int
    public let thirstyCount: Int
    public let recoveringCount: Int
    public let deadCount: Int
    public let recentMilestoneCount: Int

    public init(
        state: GardenState,
        at date: Date = Date(),
        milestoneDuration: TimeInterval = 120
    ) {
        let plants = state.plants
        plantCount = plants.count
        needsCareCount = state.plantsNeedingCare.count
        thirstyCount = state.thirstyPlants.count
        recoveringCount = plants.filter { $0.careNeed == .recovering }.count
        deadCount = plants.filter(\.isDead).count
        recentMilestoneCount = plants.filter {
            $0.growthMilestoneIntensity(at: date, duration: milestoneDuration) > 0
        }.count

        guard !plants.isEmpty else {
            score = 0
            mood = .dormant
            return
        }

        let divisor = Double(plants.count)
        let averageHydration = plants.map(\.hydration).reduce(0, +) / divisor
        let averageHealth = plants.map(\.health).reduce(0, +) / divisor
        let averageGrowth = plants.map(\.growth).reduce(0, +) / divisor
        let milestoneBonus = recentMilestoneCount > 0 ? 0.15 : 0

        score = (
            averageHydration * 0.28
                + averageHealth * 0.32
                + averageGrowth * 0.25
                + milestoneBonus
        ).clampedUnit

        if deadCount > 0 {
            mood = .dead
        } else if thirstyCount > 0 {
            mood = .thirsty
        } else if recoveringCount > 0 {
            mood = .recovering
        } else if score >= 0.84 {
            mood = .flourishing
        } else {
            mood = .steady
        }
    }

    public var summary: String {
        switch mood {
        case .dormant:
            "No plants yet"
        case .dead:
            deadCount == 1 ? "1 dead" : "\(deadCount) dead"
        case .thirsty:
            thirstyCount == 1 ? "1 thirsty" : "\(thirstyCount) thirsty"
        case .recovering:
            recoveringCount == 1 ? "1 recovering" : "\(recoveringCount) recovering"
        case .flourishing:
            "Garden flourishing"
        case .steady:
            "Garden steady"
        }
    }

    public var percentScore: Int {
        Int((score * 100).rounded())
    }
}

public extension GardenState {
    func vitality(at date: Date = Date()) -> GardenVitality {
        GardenVitality(state: self, at: date)
    }
}
