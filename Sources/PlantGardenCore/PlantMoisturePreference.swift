import Foundation

public enum PlantMoistureFit: String, Codable, Sendable {
    case parched
    case dry
    case ideal
    case damp
    case saturated
}

public struct PlantMoisturePreference: Equatable, Sendable {
    public let fit: PlantMoistureFit
    public let targetHydration: ClosedRange<Double>
    public let urgentHydrationThreshold: Double
    public let waterSoonHydrationThreshold: Double
    public let dampHydrationThreshold: Double
    public let saturatedHydrationThreshold: Double
    public let growthMultiplier: Double
    public let waterUseMultiplier: Double
    public let healthAdjustmentPerHour: Double
    public let summary: String
    public let shortSummary: String

    public init(plant: Plant) {
        self.init(species: plant.species, hydration: plant.hydration)
    }

    public init(species: PlantSpecies, hydration: Double) {
        let profile = Self.profile(for: species)
        let hydration = hydration.clampedUnit
        targetHydration = profile.targetHydration
        urgentHydrationThreshold = profile.urgentHydrationThreshold
        waterSoonHydrationThreshold = profile.waterSoonHydrationThreshold
        dampHydrationThreshold = profile.dampHydrationThreshold
        saturatedHydrationThreshold = profile.saturatedHydrationThreshold

        if hydration <= profile.urgentHydrationThreshold {
            fit = .parched
            growthMultiplier = 0.18
            waterUseMultiplier = 0.92
            healthAdjustmentPerHour = -0.055
            summary = "Parched soil"
            shortSummary = "Parched"
        } else if hydration <= profile.waterSoonHydrationThreshold {
            fit = .dry
            growthMultiplier = 0.58
            waterUseMultiplier = 0.96
            healthAdjustmentPerHour = -0.014
            summary = "Needs more moisture"
            shortSummary = "Wants moisture"
        } else if hydration >= profile.saturatedHydrationThreshold {
            fit = .saturated
            growthMultiplier = 0.70
            waterUseMultiplier = 1.18
            healthAdjustmentPerHour = -0.020
            summary = "Saturated soil"
            shortSummary = "Too wet"
        } else if hydration >= profile.dampHydrationThreshold {
            fit = .damp
            growthMultiplier = 0.94
            waterUseMultiplier = 1.08
            healthAdjustmentPerHour = -0.004
            summary = "Damp soil"
            shortSummary = "Soil damp"
        } else {
            fit = .ideal
            growthMultiplier = 1.08
            waterUseMultiplier = 1.0
            healthAdjustmentPerHour = 0.006
            summary = "Moisture steady"
            shortSummary = "Moisture steady"
        }
    }

    private static func profile(for species: PlantSpecies) -> MoistureProfile {
        switch species {
        case .fern, .ivy, .mossCarpet, .cattails, .waterLily, .pitcherPlant, .staghornFern, .blueStarCreeper, .corsicanMint, .redVeinSorrelPatch, .wasabi:
            MoistureProfile(
                targetHydration: 0.56...0.84,
                urgentHydrationThreshold: 0.20,
                waterSoonHydrationThreshold: 0.42,
                dampHydrationThreshold: 0.86,
                saturatedHydrationThreshold: 0.98
            )
        case .monstera, .orchid, .hydrangea, .willow, .ghostOrchid, .jadeVine, .corpseFlower, .queenOfTheNight, .alocasiaDragonScale, .prayerPlant, .blackCoralColocasia, .rainbowEucalyptus:
            MoistureProfile(
                targetHydration: 0.52...0.80,
                urgentHydrationThreshold: 0.18,
                waterSoonHydrationThreshold: 0.38,
                dampHydrationThreshold: 0.84,
                saturatedHydrationThreshold: 0.96
            )
        case .lavender, .lavenderField, .creepingThyme, .herbCluster, .succulent, .oliveTree, .pineTree, .rosemary, .thyme, .oregano, .sage, .chocolateCosmos, .baobab, .dragonBloodTree, .monkeyPuzzleTree, .ravenZZPlant, .silverFallsDichondra, .alpineEdelweissMat, .dragonFruitCactus, .purpleBasil, .shiso, .saffronCrocus:
            MoistureProfile(
                targetHydration: 0.30...0.68,
                urgentHydrationThreshold: 0.11,
                waterSoonHydrationThreshold: 0.24,
                dampHydrationThreshold: 0.76,
                saturatedHydrationThreshold: 0.86
            )
        case .determinateTomato, .sweetPepper, .peaVines, .stringBeans, .cucumberVine, .alpineStrawberry, .glassGemCorn, .cucamelon:
            MoistureProfile(
                targetHydration: 0.48...0.76,
                urgentHydrationThreshold: 0.15,
                waterSoonHydrationThreshold: 0.34,
                dampHydrationThreshold: 0.88,
                saturatedHydrationThreshold: 0.96
            )
        case .mushrooms, .lichens:
            MoistureProfile(
                targetHydration: 0.50...0.86,
                urgentHydrationThreshold: 0.17,
                waterSoonHydrationThreshold: 0.36,
                dampHydrationThreshold: 0.88,
                saturatedHydrationThreshold: 0.98
            )
        case .tulip, .sunflower, .cherryTree, .mapleTree, .bonsai, .japaneseMaple, .birch, .dogwood, .magnolia, .dwarfCitrus, .silkFlossTree, .wildflowerMeadow, .cloverPatch, .wisteria, .jasmine, .peony, .rose, .foxglove, .poppy, .iris, .lily, .bamboo, .ornamentalGrass:
            MoistureProfile(
                targetHydration: 0.46...0.74,
                urgentHydrationThreshold: 0.16,
                waterSoonHydrationThreshold: 0.34,
                dampHydrationThreshold: 0.88,
                saturatedHydrationThreshold: 0.96
            )
        }
    }
}

private struct MoistureProfile: Equatable, Sendable {
    let targetHydration: ClosedRange<Double>
    let urgentHydrationThreshold: Double
    let waterSoonHydrationThreshold: Double
    let dampHydrationThreshold: Double
    let saturatedHydrationThreshold: Double
}

public extension Plant {
    var moisturePreference: PlantMoisturePreference {
        PlantMoisturePreference(plant: self)
    }
}
