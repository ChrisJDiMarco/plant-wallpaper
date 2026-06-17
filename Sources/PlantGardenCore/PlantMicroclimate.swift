import Foundation

public enum PlantLightExposure: String, Codable, Sendable {
    case brightWindow
    case balancedLight
    case coolShade
}

public enum PlantLightFit: String, Codable, Sendable {
    case ideal
    case tolerable
    case strained
}

public struct PlantMicroclimate: Equatable, Sendable {
    public let exposure: PlantLightExposure
    public let lightFit: PlantLightFit
    public let placementLight: Double
    public let lightFactor: Double
    public let moistureRetention: Double
    public let growthFactor: Double
    public let waterUseFactor: Double
    public let healthAdjustmentPerHour: Double
    public let fitSummary: String
    public let summary: String
    public let shortSummary: String

    public init(
        plant: Plant,
        state: GardenState,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) {
        let x = plant.position.x.clampedUnit
        let y = plant.position.y.clampedUnit
        let horizontalWindowLight = (1 - abs(x - 0.5) / 0.5).clampedUnit
        let verticalWindowLight = ((0.92 - y) / 0.40).clampedUnit
        let placementLight = (0.34 + verticalWindowLight * 0.46 + horizontalWindowLight * 0.20).clampedUnit
        let sunlight = GardenSunlightCondition(at: date, calendar: calendar)
        let season = GardenSeasonCondition(at: date, calendar: calendar)
        let exposure: PlantLightExposure

        if placementLight >= 0.72 {
            exposure = .brightWindow
        } else if placementLight <= 0.46 {
            exposure = .coolShade
        } else {
            exposure = .balancedLight
        }
        let lightFit = Self.lightFit(for: plant.species, exposure: exposure)

        let daylightFactor = 0.82 + sunlight.intensity * 0.18
        let seasonalGrowthFactor = 0.72 + season.growthEnergy * 0.28
        let affinity = Self.lightAffinity(for: plant.species, exposure: exposure, lightFit: lightFit)
        let rawLightFactor = 0.78 + placementLight * 0.34
        let rawGrowthFactor = rawLightFactor * daylightFactor * seasonalGrowthFactor * affinity
        let ambientMoisture = state.ambientMoisture.clampedUnit
        let rawMoistureRetention = 1.10 - placementLight * 0.22 + ambientMoisture * 0.12
        let seasonalWaterFactor = 0.88 + season.growthEnergy * 0.18
        let rawWaterUseFactor = (0.82 + placementLight * 0.42 - ambientMoisture * 0.12) * seasonalWaterFactor

        self.exposure = exposure
        self.lightFit = lightFit
        self.placementLight = placementLight
        self.lightFactor = Self.bounded(rawLightFactor * daylightFactor, lower: 0.72, upper: 1.22)
        self.moistureRetention = Self.bounded(rawMoistureRetention, lower: 0.82, upper: 1.18)
        self.growthFactor = Self.bounded(rawGrowthFactor, lower: 0.56, upper: 1.24)
        self.waterUseFactor = Self.bounded(rawWaterUseFactor, lower: 0.72, upper: 1.28)
        self.healthAdjustmentPerHour = Self.healthAdjustmentPerHour(for: lightFit)
        self.fitSummary = Self.fitSummary(for: lightFit, exposure: exposure)
        self.shortSummary = Self.shortSummary(for: exposure)
        self.summary = "\(Self.longSummary(for: exposure)), \(fitSummary.lowercased()), \(season.summary.lowercased())"
    }

    private static func lightFit(for species: PlantSpecies, exposure: PlantLightExposure) -> PlantLightFit {
        switch species {
        case .fern, .monstera, .ivy, .mossCarpet, .mushrooms, .lichens, .orchid, .hydrangea, .pitcherPlant, .ghostOrchid, .corpseFlower, .alocasiaDragonScale, .ravenZZPlant, .prayerPlant, .staghornFern, .blackCoralColocasia, .blueStarCreeper, .corsicanMint, .redVeinSorrelPatch, .wasabi:
            switch exposure {
            case .brightWindow:
                return .strained
            case .balancedLight:
                return .ideal
            case .coolShade:
                return .ideal
            }
        case .sunflower, .lavender, .tulip, .wildflowerMeadow, .lavenderField, .creepingThyme, .herbCluster, .succulent, .oliveTree, .dwarfCitrus, .poppy, .rose, .iris, .lily, .waterLily, .determinateTomato, .sweetPepper, .peaVines, .stringBeans, .cucumberVine, .rosemary, .thyme, .oregano, .sage, .chocolateCosmos, .baobab, .dragonBloodTree, .silkFlossTree, .silverFallsDichondra, .alpineEdelweissMat, .dragonFruitCactus, .purpleBasil, .shiso, .saffronCrocus, .alpineStrawberry, .glassGemCorn, .cucamelon:
            switch exposure {
            case .brightWindow:
                return .ideal
            case .balancedLight:
                return .tolerable
            case .coolShade:
                return .strained
            }
        case .cherryTree, .mapleTree, .bonsai, .japaneseMaple, .willow, .birch, .dogwood, .magnolia, .jasmine, .peony, .foxglove, .cloverPatch, .ornamentalGrass, .cattails, .bamboo, .wisteria, .jadeVine, .queenOfTheNight, .rainbowEucalyptus, .monkeyPuzzleTree:
            switch exposure {
            case .brightWindow:
                return .ideal
            case .balancedLight:
                return .ideal
            case .coolShade:
                return .tolerable
            }
        case .pineTree:
            switch exposure {
            case .brightWindow:
                return .tolerable
            case .balancedLight:
                return .ideal
            case .coolShade:
                return .ideal
            }
        }
    }

    private static func lightAffinity(
        for species: PlantSpecies,
        exposure: PlantLightExposure,
        lightFit: PlantLightFit
    ) -> Double {
        let baseAffinity: Double
        switch lightFit {
        case .ideal:
            baseAffinity = 1.06
        case .tolerable:
            baseAffinity = 0.98
        case .strained:
            baseAffinity = 0.86
        }

        switch (species.kind, exposure) {
        case (.flower, .brightWindow), (.meadow, .brightWindow):
            return baseAffinity + 0.03
        case (.edible, .brightWindow):
            return baseAffinity + 0.025
        case (.foliage, .coolShade):
            return baseAffinity + 0.02
        default:
            return baseAffinity
        }
    }

    private static func healthAdjustmentPerHour(for lightFit: PlantLightFit) -> Double {
        switch lightFit {
        case .ideal:
            0.006
        case .tolerable:
            0
        case .strained:
            -0.018
        }
    }

    private static func fitSummary(for lightFit: PlantLightFit, exposure: PlantLightExposure) -> String {
        switch lightFit {
        case .ideal:
            return "Ideal light"
        case .tolerable:
            return "Tolerable light"
        case .strained:
            switch exposure {
            case .brightWindow:
                return "Wants gentler light"
            case .balancedLight:
                return "Light stress"
            case .coolShade:
                return "Wants brighter light"
            }
        }
    }

    private static func shortSummary(for exposure: PlantLightExposure) -> String {
        switch exposure {
        case .brightWindow:
            "Bright window"
        case .balancedLight:
            "Balanced light"
        case .coolShade:
            "Cool shade"
        }
    }

    private static func longSummary(for exposure: PlantLightExposure) -> String {
        switch exposure {
        case .brightWindow:
            "Bright window light"
        case .balancedLight:
            "Balanced light"
        case .coolShade:
            "Cool shade"
        }
    }

    private static func bounded(_ value: Double, lower: Double, upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}
