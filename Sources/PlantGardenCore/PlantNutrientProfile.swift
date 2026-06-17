import Foundation

public enum PlantNutrientFit: String, Codable, Sendable {
    case depleted
    case hungry
    case balanced
    case rich
}

public struct PlantNutrientProfile: Equatable, Sendable {
    public let fit: PlantNutrientFit
    public let demand: Double
    public let growthMultiplier: Double
    public let bloomMultiplier: Double
    public let healthAdjustmentPerHour: Double
    public let summary: String
    public let shortSummary: String

    public init(plant: Plant, at date: Date = Date()) {
        let recency = Self.nourishmentRecency(for: plant, at: date)
        let demand = Self.baseDemand(for: plant.species)
            * (0.42 + plant.growth.clampedUnit * 0.52 + plant.bloomProgress.clampedUnit * 0.28)
        let nutritionScore = min(1, max(-1, recency - demand))

        self.demand = demand.clampedUnit

        if nutritionScore >= 0.36 {
            fit = .rich
            growthMultiplier = 1.10
            bloomMultiplier = 1.08
            healthAdjustmentPerHour = 0.006
            summary = "Fresh nutrients"
            shortSummary = "Rich soil"
        } else if nutritionScore >= -0.16 {
            fit = .balanced
            growthMultiplier = 1.02
            bloomMultiplier = 1.0
            healthAdjustmentPerHour = 0.002
            summary = "Nutrients steady"
            shortSummary = "Fed"
        } else if nutritionScore >= -0.52 {
            fit = .hungry
            growthMultiplier = 0.90
            bloomMultiplier = 0.86
            healthAdjustmentPerHour = -0.003
            summary = "Nutrient hungry"
            shortSummary = "Hungry"
        } else {
            fit = .depleted
            growthMultiplier = 0.72
            bloomMultiplier = 0.68
            healthAdjustmentPerHour = -0.014
            summary = "Depleted soil"
            shortSummary = "Depleted"
        }
    }

    private static func nourishmentRecency(for plant: Plant, at date: Date) -> Double {
        guard let lastNourishedAt = plant.lastNourishedAt else {
            return plant.growth < 0.36 ? 0.42 : 0.18
        }

        let elapsedDays = max(0, date.timeIntervalSince(lastNourishedAt) / 86_400)
        switch elapsedDays {
        case ..<1:
            return 1.0
        case ..<3:
            return 0.72
        case ..<10:
            return 0.44
        case ..<21:
            return 0.22
        default:
            return 0.08
        }
    }

    private static func baseDemand(for species: PlantSpecies) -> Double {
        switch species {
        case .determinateTomato, .sweetPepper, .peaVines, .stringBeans, .cucumberVine, .dragonFruitCactus, .alpineStrawberry, .glassGemCorn, .cucamelon:
            0.76
        case .sunflower, .wildflowerMeadow, .lavenderField, .hydrangea, .peony, .rose, .foxglove, .lily, .waterLily, .corpseFlower, .jadeVine, .queenOfTheNight, .blueStarCreeper, .redVeinSorrelPatch, .alpineEdelweissMat:
            0.74
        case .cherryTree, .mapleTree, .japaneseMaple, .willow, .birch, .dogwood, .magnolia, .dwarfCitrus, .baobab, .dragonBloodTree, .rainbowEucalyptus, .silkFlossTree:
            0.68
        case .tulip, .monstera, .orchid, .iris, .poppy, .wisteria, .jasmine, .bamboo, .pitcherPlant, .ghostOrchid, .chocolateCosmos, .alocasiaDragonScale, .blackCoralColocasia, .wasabi:
            0.56
        case .fern, .ivy, .cattails, .ornamentalGrass, .cloverPatch, .prayerPlant, .staghornFern, .silverFallsDichondra, .corsicanMint:
            0.48
        case .pineTree, .bonsai, .oliveTree, .succulent, .mushrooms, .monkeyPuzzleTree, .ravenZZPlant:
            0.42
        case .lavender, .creepingThyme, .mossCarpet, .herbCluster, .lichens, .rosemary, .thyme, .oregano, .sage, .purpleBasil, .shiso, .saffronCrocus:
            0.34
        }
    }
}

public extension Plant {
    func nutrientProfile(at date: Date = Date()) -> PlantNutrientProfile {
        PlantNutrientProfile(plant: self, at: date)
    }

    var nutrientProfile: PlantNutrientProfile {
        PlantNutrientProfile(plant: self)
    }
}
