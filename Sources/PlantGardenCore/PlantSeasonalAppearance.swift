import Foundation

public enum PlantSeasonalAppearanceMood: String, Codable, Sendable {
    case springFlush
    case summerCanopy
    case autumnColor
    case winterRest
}

public struct PlantSeasonalAppearance: Equatable, Sendable {
    public let mood: PlantSeasonalAppearanceMood
    public let assetOpacityMultiplier: Double
    public let freshGrowthTintAlpha: Double
    public let warmTintAlpha: Double
    public let coolTintAlpha: Double
    public let bloomLiftAlpha: Double
    public let summary: String

    public init(plant: Plant, season: GardenSeasonCondition) {
        let vitality = min(plant.health, plant.hydration).clampedUnit
        let maturity = plant.growth.clampedUnit
        let deciduousFactor = Self.deciduousFactor(for: plant.species)
        let floweringFactor = Self.floweringFactor(for: plant.species)

        switch season.mood {
        case .spring:
            mood = .springFlush
            assetOpacityMultiplier = Self.bounded(0.94 + vitality * 0.06, lower: 0.90, upper: 1.0)
            freshGrowthTintAlpha = Self.bounded((0.025 + vitality * 0.055) * (0.55 + maturity * 0.45), lower: 0.015, upper: 0.09)
            warmTintAlpha = 0.0
            coolTintAlpha = 0.0
            bloomLiftAlpha = Self.bounded(plant.bloomProgress * floweringFactor * 0.055, lower: 0.0, upper: 0.08)
            summary = "Spring flush"
        case .summer:
            mood = .summerCanopy
            assetOpacityMultiplier = Self.bounded(0.97 + vitality * 0.03, lower: 0.94, upper: 1.0)
            freshGrowthTintAlpha = Self.bounded(vitality * 0.028, lower: 0.0, upper: 0.04)
            warmTintAlpha = Self.bounded(0.010 + maturity * 0.010, lower: 0.0, upper: 0.025)
            coolTintAlpha = 0.0
            bloomLiftAlpha = Self.bounded(plant.bloomProgress * floweringFactor * 0.045, lower: 0.0, upper: 0.06)
            summary = "Summer canopy"
        case .autumn:
            mood = .autumnColor
            assetOpacityMultiplier = Self.bounded(0.94 - deciduousFactor * 0.050 + vitality * 0.020, lower: 0.86, upper: 0.98)
            freshGrowthTintAlpha = 0.0
            warmTintAlpha = Self.bounded((0.018 + maturity * 0.090) * deciduousFactor, lower: 0.0, upper: 0.13)
            coolTintAlpha = 0.0
            bloomLiftAlpha = Self.bounded(plant.bloomProgress * floweringFactor * 0.018, lower: 0.0, upper: 0.03)
            summary = "Autumn color"
        case .winter:
            mood = .winterRest
            assetOpacityMultiplier = Self.bounded(0.76 + vitality * 0.12 + (1 - deciduousFactor) * 0.08, lower: 0.72, upper: 0.94)
            freshGrowthTintAlpha = 0.0
            warmTintAlpha = 0.0
            coolTintAlpha = Self.bounded(0.050 + deciduousFactor * 0.070 + (1 - vitality) * 0.040, lower: 0.04, upper: 0.16)
            bloomLiftAlpha = 0.0
            summary = "Winter rest"
        }
    }

    private static func deciduousFactor(for species: PlantSpecies) -> Double {
        switch species {
        case .cherryTree, .mapleTree, .japaneseMaple, .willow, .birch, .dogwood, .magnolia, .dwarfCitrus, .baobab, .dragonBloodTree, .rainbowEucalyptus, .monkeyPuzzleTree, .silkFlossTree:
            1.0
        case .pineTree, .oliveTree, .succulent, .pitcherPlant, .ravenZZPlant, .dragonFruitCactus:
            0.18
        case .fern, .monstera, .ivy, .herbCluster, .bamboo, .alocasiaDragonScale, .prayerPlant, .staghornFern, .blackCoralColocasia:
            0.42
        case .determinateTomato, .sweetPepper, .peaVines, .stringBeans, .cucumberVine, .alpineStrawberry, .glassGemCorn, .cucamelon:
            0.62
        case .rosemary, .thyme, .oregano, .sage, .purpleBasil, .shiso, .saffronCrocus, .wasabi:
            0.38
        case .wildflowerMeadow, .lavenderField, .cloverPatch, .creepingThyme, .ornamentalGrass, .cattails, .mushrooms, .lichens, .waterLily, .blueStarCreeper, .silverFallsDichondra, .corsicanMint, .redVeinSorrelPatch, .alpineEdelweissMat:
            0.70
        case .lavender, .wisteria, .jasmine, .orchid, .tulip, .sunflower, .hydrangea, .peony, .rose, .foxglove, .poppy, .iris, .lily, .ghostOrchid, .jadeVine, .corpseFlower, .queenOfTheNight, .chocolateCosmos:
            0.56
        case .mossCarpet, .bonsai:
            0.36
        }
    }

    private static func floweringFactor(for species: PlantSpecies) -> Double {
        switch species.kind {
        case .flower, .meadow:
            1.0
        case .tree:
            switch species {
            case .cherryTree, .dogwood, .magnolia, .dwarfCitrus:
                0.65
            default:
                0.22
            }
        case .foliage:
            species == .pitcherPlant ? 0.34 : 0.18
        case .edible:
            switch species {
            case .determinateTomato, .sweetPepper, .peaVines, .stringBeans, .cucumberVine:
                0.72
            default:
                0.30
            }
        }
    }

    private static func bounded(_ value: Double, lower: Double, upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}

public extension Plant {
    func seasonalAppearance(for season: GardenSeasonCondition) -> PlantSeasonalAppearance {
        PlantSeasonalAppearance(plant: self, season: season)
    }
}
