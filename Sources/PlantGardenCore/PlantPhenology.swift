import Foundation

public enum PlantPhenologyPhase: String, Codable, Sendable {
    case springBloom
    case summerBloom
    case autumnColor
    case evergreen
    case foliageFlush
    case winterRest
    case steadyGrowth
}

public struct PlantPhenology: Equatable, Sendable {
    public let phase: PlantPhenologyPhase
    public let bloomMultiplier: Double
    public let bloomFadePerHour: Double
    public let summary: String

    public init(plant: Plant, season: GardenSeasonCondition) {
        switch (plant.species, season.mood) {
        case (.cherryTree, .spring):
            phase = .springBloom
            bloomMultiplier = 1.70
            bloomFadePerHour = 0
            summary = "Spring blossom"
        case (.cherryTree, .autumn):
            phase = .autumnColor
            bloomMultiplier = 0.18
            bloomFadePerHour = 0.018
            summary = "Autumn color"
        case (.mapleTree, .autumn), (.japaneseMaple, .autumn), (.dogwood, .autumn), (.birch, .autumn):
            phase = .autumnColor
            bloomMultiplier = 0.16
            bloomFadePerHour = 0.018
            summary = "Autumn color"
        case (.pineTree, _):
            phase = .evergreen
            bloomMultiplier = season.mood == .winter ? 0.34 : 0.42
            bloomFadePerHour = season.mood == .winter ? 0.004 : 0
            summary = "Evergreen steady"
        case (.sunflower, .summer), (.lavender, .summer), (.wildflowerMeadow, .summer), (.lavenderField, .summer), (.rose, .summer), (.hydrangea, .summer), (.lily, .summer), (.waterLily, .summer):
            phase = .summerBloom
            bloomMultiplier = 1.45
            bloomFadePerHour = 0
            summary = "Summer bloom"
        case (.tulip, .spring), (.wisteria, .spring), (.jasmine, .spring), (.orchid, .spring), (.peony, .spring), (.foxglove, .spring), (.poppy, .spring), (.iris, .spring), (.magnolia, .spring), (.dogwood, .spring), (.dwarfCitrus, .spring), (.cloverPatch, .spring), (.creepingThyme, .spring):
            phase = .springBloom
            bloomMultiplier = 1.35
            bloomFadePerHour = 0
            summary = "Spring bloom"
        case (.fern, .spring), (.monstera, .spring), (.ivy, .spring), (.herbCluster, .spring), (.bamboo, .spring), (.succulent, .spring), (.pitcherPlant, .spring), (.mossCarpet, .spring), (.ornamentalGrass, .spring), (.cattails, .spring):
            phase = .foliageFlush
            bloomMultiplier = 0.34
            bloomFadePerHour = 0
            summary = "Foliage flush"
        case (_, .winter):
            phase = .winterRest
            bloomMultiplier = 0.05
            bloomFadePerHour = 0.026
            summary = "Winter rest"
        case (.mapleTree, .spring), (.mapleTree, .summer), (.japaneseMaple, .spring), (.japaneseMaple, .summer), (.cherryTree, .summer), (.willow, .spring), (.willow, .summer), (.birch, .spring), (.birch, .summer), (.oliveTree, .spring), (.oliveTree, .summer), (.bonsai, .spring), (.bonsai, .summer):
            phase = .steadyGrowth
            bloomMultiplier = 0.54
            bloomFadePerHour = 0
            summary = "Canopy growth"
        case (_, .autumn):
            phase = .autumnColor
            bloomMultiplier = 0.32
            bloomFadePerHour = 0.012
            summary = "Autumn color"
        case (_, .spring):
            phase = .foliageFlush
            bloomMultiplier = 0.82
            bloomFadePerHour = 0
            summary = "Spring growth"
        default:
            phase = .summerBloom
            bloomMultiplier = 1.05
            bloomFadePerHour = 0
            summary = "Summer growth"
        }
    }
}

public extension Plant {
    func phenology(for season: GardenSeasonCondition) -> PlantPhenology {
        PlantPhenology(plant: self, season: season)
    }
}
