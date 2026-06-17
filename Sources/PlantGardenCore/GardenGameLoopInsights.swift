import Foundation

public struct GardenHarvestInsight: Equatable, Sendable {
    public let readyCropCount: Int
    public let readyVarietyCount: Int
    public let expectedSeedYield: Int
    public let totalHarvests: Int

    public var menuTitle: String {
        switch readyCropCount {
        case 0:
            "Harvest Ready Crops"
        case 1:
            "Harvest Ready Crop"
        default:
            "Harvest \(readyCropCount) Ready Crops"
        }
    }

    public var summary: String {
        if readyCropCount > 0 {
            return "\(readyCropCount) crops ready across \(readyVarietyCount) variet\(readyVarietyCount == 1 ? "y" : "ies") - yields \(expectedSeedYield) seeds."
        }

        if totalHarvests > 0 {
            return "\(totalHarvests) lifetime harvest\(totalHarvests == 1 ? "" : "s") gathered."
        }

        return "No crops are ready yet."
    }
}

public struct GardenSeedSuggestion: Equatable, Sendable {
    public let species: PlantSpecies
    public let count: Int
    public let reason: String
}

public struct GardenSeedInsight: Equatable, Sendable {
    public let totalSeeds: Int
    public let speciesCount: Int
    public let plantableSpeciesCount: Int
    public let suggestion: GardenSeedSuggestion?

    public var summary: String {
        guard totalSeeds > 0 else {
            return "No saved seeds yet."
        }

        guard let suggestion else {
            return "\(totalSeeds) seeds saved, but none fit this scene."
        }

        return "Plant \(suggestion.species.displayName) next - \(suggestion.reason)."
    }
}

public struct GardenFocusInsight: Equatable, Sendable {
    public let isActive: Bool
    public let statusSummary: String
    public let completedSessions: Int
    public let totalFocusMinutes: Int
    public let nextMilestoneMinutes: Int?
    public let minutesUntilNextMilestone: Int?

    public var milestoneSummary: String {
        guard let nextMilestoneMinutes, let minutesUntilNextMilestone else {
            return "Focus grove complete for now."
        }

        if minutesUntilNextMilestone == 0 {
            return "\(nextMilestoneMinutes)m focus milestone reached."
        }

        return "\(minutesUntilNextMilestone)m to the \(nextMilestoneMinutes)m focus milestone."
    }
}

public struct GardenWeatherInsight: Equatable, Sendable {
    public let summary: String
    public let isCelebratingRain: Bool
    public let isCelebratingRareMoment: Bool
}

public struct GardenArrangementInsight: Equatable, Sendable {
    public let strategyTitle: String
    public let summary: String
}

public struct GardenGameLoopInsights: Equatable, Sendable {
    public let harvest: GardenHarvestInsight
    public let seeds: GardenSeedInsight
    public let focus: GardenFocusInsight
    public let weather: GardenWeatherInsight
    public let arrangement: GardenArrangementInsight

    public init(
        state: GardenState,
        sceneKey: String?,
        date: Date = Date(),
        calendar: Calendar = .current
    ) {
        harvest = Self.harvestInsight(for: state)
        seeds = Self.seedInsight(for: state, sceneKey: sceneKey)
        focus = Self.focusInsight(for: state, at: date)
        weather = Self.weatherInsight(for: state, at: date, calendar: calendar)
        let strategy = GardenComposition.arrangementStrategy(sceneKey: sceneKey)
        arrangement = GardenArrangementInsight(
            strategyTitle: strategy.title,
            summary: strategy.summary
        )
    }

    private static func harvestInsight(for state: GardenState) -> GardenHarvestInsight {
        let readyCrops = state.plants.filter(\.isHarvestReady)
        let readySpecies = Set(readyCrops.map(\.species))
        return GardenHarvestInsight(
            readyCropCount: readyCrops.count,
            readyVarietyCount: readySpecies.count,
            expectedSeedYield: readyCrops.count * 2,
            totalHarvests: state.harvestTally.values.reduce(0, +)
        )
    }

    private static func seedInsight(for state: GardenState, sceneKey: String?) -> GardenSeedInsight {
        let entries = seedInventoryEntries(in: state)
        let environment = GardenScenePlantEnvironment(sceneKey: sceneKey)
        let plantableEntries = entries.filter { environment.isSuitable($0.species) }
        return GardenSeedInsight(
            totalSeeds: entries.reduce(0) { $0 + $1.count },
            speciesCount: entries.count,
            plantableSpeciesCount: plantableEntries.count,
            suggestion: seedSuggestion(from: plantableEntries, state: state)
        )
    }

    public static func seedInventoryEntries(in state: GardenState) -> [(species: PlantSpecies, count: Int)] {
        state.seedInventory.compactMap { rawValue, count in
            guard count > 0, let species = PlantSpecies(rawValue: rawValue) else {
                return nil
            }

            return (species, count)
        }
        .sorted { lhs, rhs in
            lhs.species.displayName < rhs.species.displayName
        }
    }

    private static func seedSuggestion(
        from entries: [(species: PlantSpecies, count: Int)],
        state: GardenState
    ) -> GardenSeedSuggestion? {
        guard !entries.isEmpty else {
            return nil
        }

        let existingSpeciesCounts = Dictionary(grouping: state.plants, by: \.species)
            .mapValues(\.count)
        let kindCounts = Dictionary(grouping: state.plants, by: { $0.species.kind })
            .mapValues(\.count)
        let minimumKindCount = PlantKind.allCases.map { kindCounts[$0, default: 0] }.min() ?? 0

        let scoredEntries = entries.map { entry -> (entry: (species: PlantSpecies, count: Int), score: Double, reason: String) in
            let existingCount = existingSpeciesCounts[entry.species, default: 0]
            let isNewVariety = existingCount == 0
            let balancesKind = kindCounts[entry.species.kind, default: 0] == minimumKindCount
            let score = (isNewVariety ? 4.0 : 0.0)
                + (balancesKind ? 1.25 : 0.0)
                + min(1.0, Double(entry.count) / 20.0)
            let reason: String
            if isNewVariety {
                reason = "adds a new variety"
            } else if balancesKind {
                reason = "balances your \(entry.species.kind.displayName.lowercased()) plantings"
            } else {
                reason = "uses your fullest seed packet"
            }
            return (entry, score, reason)
        }

        guard let best = scoredEntries.max(by: { lhs, rhs in
            if lhs.score == rhs.score {
                if lhs.entry.count == rhs.entry.count {
                    return lhs.entry.species.displayName > rhs.entry.species.displayName
                }
                return lhs.entry.count < rhs.entry.count
            }
            return lhs.score < rhs.score
        }) else {
            return nil
        }

        return GardenSeedSuggestion(
            species: best.entry.species,
            count: best.entry.count,
            reason: best.reason
        )
    }

    private static func focusInsight(for state: GardenState, at date: Date) -> GardenFocusInsight {
        let stats = state.focusStats ?? GardenFocusStats()
        let totalMinutes = stats.totalFocusMinutes
        let nextMilestone = GardenFocusMilestone.next(after: totalMinutes)
        let activeSummary: String
        let isActive: Bool
        if let session = state.focusSession, session.isActive(at: date) {
            isActive = true
            activeSummary = "Focusing - \(session.remainingSummary(at: date)) left, x\(String(format: "%.1f", GardenFocusSession.growthBoost)) growth."
        } else {
            isActive = false
            activeSummary = stats.completedSessions > 0
                ? "\(stats.completedSessions) sessions, \(totalMinutes)m focused."
                : "No focus sessions yet."
        }

        return GardenFocusInsight(
            isActive: isActive,
            statusSummary: activeSummary,
            completedSessions: stats.completedSessions,
            totalFocusMinutes: totalMinutes,
            nextMilestoneMinutes: nextMilestone,
            minutesUntilNextMilestone: nextMilestone.map { max(0, $0 - totalMinutes) }
        )
    }

    private static func weatherInsight(
        for state: GardenState,
        at date: Date,
        calendar: Calendar
    ) -> GardenWeatherInsight {
        guard state.settings.isWeatherSyncEnabled else {
            return GardenWeatherInsight(
                summary: "Weather sync is off.",
                isCelebratingRain: false,
                isCelebratingRareMoment: false
            )
        }

        let rareMoment = GardenRareMoment.activeMoment(at: date, weather: state.weather, calendar: calendar)
        if let rareMoment {
            return GardenWeatherInsight(
                summary: rareMoment.kind.celebrationText,
                isCelebratingRain: rareMoment.kind == .rainbow,
                isCelebratingRareMoment: true
            )
        }

        guard let weather = state.weather, !weather.isStale(at: date) else {
            return GardenWeatherInsight(
                summary: "Waiting for fresh weather.",
                isCelebratingRain: false,
                isCelebratingRareMoment: false
            )
        }

        if weather.isPrecipitating {
            return GardenWeatherInsight(
                summary: "Rain is watering the garden right now.",
                isCelebratingRain: true,
                isCelebratingRareMoment: false
            )
        }

        return GardenWeatherInsight(
            summary: weather.summary,
            isCelebratingRain: false,
            isCelebratingRareMoment: false
        )
    }
}

public enum GardenFocusMilestone {
    public static let milestones = [25, 100, 250, 500, 1_000, 2_500, 5_000]

    public static func next(after totalMinutes: Int) -> Int? {
        milestones.first { $0 > totalMinutes }
    }

    public static func reached(previousMinutes: Int, currentMinutes: Int) -> Int? {
        milestones.last { milestone in
            previousMinutes < milestone && currentMinutes >= milestone
        }
    }
}
