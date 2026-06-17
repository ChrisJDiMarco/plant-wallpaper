import Foundation

public enum PlantKind: String, Codable, CaseIterable, Sendable, Hashable {
    case flower
    case foliage
    case tree
    case meadow
    case edible

    public var displayName: String {
        switch self {
        case .flower:
            "Flower"
        case .foliage:
            "Foliage"
        case .tree:
            "Tree"
        case .meadow:
            "Groundcover"
        case .edible:
            "Edible"
        }
    }
}

public enum PlantSpecies: String, Codable, CaseIterable, Identifiable, Sendable {
    case fern
    case mossCarpet
    case cloverPatch
    case creepingThyme
    case ivy
    case lavender
    case wisteria
    case jasmine
    case orchid
    case tulip
    case sunflower
    case cherryTree
    case mapleTree
    case bonsai
    case japaneseMaple
    case willow
    case birch
    case dogwood
    case magnolia
    case oliveTree
    case dwarfCitrus
    case pineTree
    case monstera
    case hydrangea
    case peony
    case rose
    case foxglove
    case poppy
    case iris
    case lily
    case ghostOrchid
    case jadeVine
    case corpseFlower
    case queenOfTheNight
    case chocolateCosmos
    case wildflowerMeadow
    case lavenderField
    case herbCluster
    case bamboo
    case ornamentalGrass
    case cattails
    case mushrooms
    case lichens
    case succulent
    case pitcherPlant
    case waterLily
    case baobab
    case dragonBloodTree
    case rainbowEucalyptus
    case monkeyPuzzleTree
    case silkFlossTree
    case alocasiaDragonScale
    case ravenZZPlant
    case prayerPlant
    case staghornFern
    case blackCoralColocasia
    case blueStarCreeper
    case silverFallsDichondra
    case corsicanMint
    case redVeinSorrelPatch
    case alpineEdelweissMat
    case determinateTomato
    case sweetPepper
    case peaVines
    case stringBeans
    case cucumberVine
    case rosemary
    case thyme
    case oregano
    case sage
    case dragonFruitCactus
    case purpleBasil
    case shiso
    case saffronCrocus
    case wasabi
    case alpineStrawberry
    case glassGemCorn
    case cucamelon

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fern:
            "Fern"
        case .mossCarpet:
            "Moss Carpet"
        case .cloverPatch:
            "Clover Patch"
        case .creepingThyme:
            "Creeping Thyme"
        case .ivy:
            "Ivy"
        case .lavender:
            "Lavender"
        case .wisteria:
            "Wisteria"
        case .jasmine:
            "Jasmine"
        case .orchid:
            "Orchid"
        case .tulip:
            "Tulip"
        case .sunflower:
            "Sunflower"
        case .cherryTree:
            "Cherry Tree"
        case .mapleTree:
            "Maple Tree"
        case .bonsai:
            "Bonsai"
        case .japaneseMaple:
            "Japanese Maple"
        case .willow:
            "Willow"
        case .birch:
            "Birch"
        case .dogwood:
            "Dogwood"
        case .magnolia:
            "Magnolia"
        case .oliveTree:
            "Olive Tree"
        case .dwarfCitrus:
            "Dwarf Citrus"
        case .pineTree:
            "Pine Tree"
        case .monstera:
            "Monstera"
        case .hydrangea:
            "Hydrangea"
        case .peony:
            "Peony"
        case .rose:
            "Rose"
        case .foxglove:
            "Foxglove"
        case .poppy:
            "Poppy"
        case .iris:
            "Iris"
        case .lily:
            "Lily"
        case .ghostOrchid:
            "Ghost Orchid"
        case .jadeVine:
            "Jade Vine"
        case .corpseFlower:
            "Corpse Flower"
        case .queenOfTheNight:
            "Queen of the Night"
        case .chocolateCosmos:
            "Chocolate Cosmos"
        case .wildflowerMeadow:
            "Wildflower Meadow"
        case .lavenderField:
            "Lavender Field"
        case .herbCluster:
            "Rosemary Basil Mint"
        case .bamboo:
            "Bamboo"
        case .ornamentalGrass:
            "Ornamental Grass"
        case .cattails:
            "Cattails"
        case .mushrooms:
            "Mushrooms"
        case .lichens:
            "Lichens"
        case .succulent:
            "Succulent"
        case .pitcherPlant:
            "Pitcher Plant"
        case .waterLily:
            "Water Lily"
        case .baobab:
            "Baobab"
        case .dragonBloodTree:
            "Dragon Blood Tree"
        case .rainbowEucalyptus:
            "Rainbow Eucalyptus"
        case .monkeyPuzzleTree:
            "Monkey Puzzle Tree"
        case .silkFlossTree:
            "Silk Floss Tree"
        case .alocasiaDragonScale:
            "Alocasia Dragon Scale"
        case .ravenZZPlant:
            "Raven ZZ Plant"
        case .prayerPlant:
            "Prayer Plant"
        case .staghornFern:
            "Staghorn Fern"
        case .blackCoralColocasia:
            "Black Coral Colocasia"
        case .blueStarCreeper:
            "Blue Star Creeper"
        case .silverFallsDichondra:
            "Silver Falls Dichondra"
        case .corsicanMint:
            "Corsican Mint"
        case .redVeinSorrelPatch:
            "Red Vein Sorrel Patch"
        case .alpineEdelweissMat:
            "Alpine Edelweiss Mat"
        case .determinateTomato:
            "Determinate Tomato"
        case .sweetPepper:
            "Sweet Pepper"
        case .peaVines:
            "Pea Vines"
        case .stringBeans:
            "String Beans"
        case .cucumberVine:
            "Cucumber Vine"
        case .rosemary:
            "Rosemary"
        case .thyme:
            "Thyme"
        case .oregano:
            "Oregano"
        case .sage:
            "Sage"
        case .dragonFruitCactus:
            "Dragon Fruit Cactus"
        case .purpleBasil:
            "Purple Basil"
        case .shiso:
            "Shiso"
        case .saffronCrocus:
            "Saffron Crocus"
        case .wasabi:
            "Wasabi"
        case .alpineStrawberry:
            "Alpine Strawberry"
        case .glassGemCorn:
            "Glass Gem Corn"
        case .cucamelon:
            "Cucamelon"
        }
    }

    public var kind: PlantKind {
        switch self {
        case .cherryTree, .mapleTree, .bonsai, .japaneseMaple, .willow, .birch, .dogwood, .magnolia, .oliveTree, .dwarfCitrus, .pineTree, .baobab, .dragonBloodTree, .rainbowEucalyptus, .monkeyPuzzleTree, .silkFlossTree:
            .tree
        case .fern, .ivy, .monstera, .herbCluster, .bamboo, .succulent, .pitcherPlant, .alocasiaDragonScale, .ravenZZPlant, .prayerPlant, .staghornFern, .blackCoralColocasia:
            .foliage
        case .mossCarpet, .cloverPatch, .creepingThyme, .wildflowerMeadow, .lavenderField, .ornamentalGrass, .cattails, .mushrooms, .lichens, .waterLily, .blueStarCreeper, .silverFallsDichondra, .corsicanMint, .redVeinSorrelPatch, .alpineEdelweissMat:
            .meadow
        case .lavender, .wisteria, .jasmine, .orchid, .tulip, .sunflower, .hydrangea, .peony, .rose, .foxglove, .poppy, .iris, .lily, .ghostOrchid, .jadeVine, .corpseFlower, .queenOfTheNight, .chocolateCosmos:
            .flower
        case .determinateTomato, .sweetPepper, .peaVines, .stringBeans, .cucumberVine, .rosemary, .thyme, .oregano, .sage, .dragonFruitCactus, .purpleBasil, .shiso, .saffronCrocus, .wasabi, .alpineStrawberry, .glassGemCorn, .cucamelon:
            .edible
        }
    }

    public var isSupportTrainedClimber: Bool {
        switch self {
        case .ivy, .wisteria, .jasmine, .jadeVine:
            true
        default:
            false
        }
    }

    public var isNaturalizingGroundcover: Bool {
        switch self {
        case .mossCarpet,
             .cloverPatch,
             .creepingThyme,
             .wildflowerMeadow,
             .lavenderField,
             .ornamentalGrass,
             .mushrooms,
             .lichens,
             .blueStarCreeper,
             .silverFallsDichondra,
             .corsicanMint,
             .redVeinSorrelPatch,
             .alpineEdelweissMat:
            true
        default:
            false
        }
    }

    public var isArtworkPlaceholder: Bool {
        Self.artworkPlaceholderSpecies.contains(self)
    }

    public static let artworkPlaceholderSpecies: Set<PlantSpecies> = []

    public static let defaultGardenSpecies: [PlantSpecies] = [
        .fern,
        .mossCarpet,
        .cloverPatch,
        .creepingThyme,
        .ivy,
        .lavender,
        .wisteria,
        .jasmine,
        .orchid,
        .tulip,
        .sunflower,
        .cherryTree,
        .mapleTree,
        .bonsai,
        .japaneseMaple,
        .willow,
        .birch,
        .dogwood,
        .magnolia,
        .oliveTree,
        .dwarfCitrus,
        .pineTree,
        .monstera,
        .hydrangea,
        .peony,
        .rose,
        .foxglove,
        .poppy,
        .iris,
        .lily,
        .wildflowerMeadow,
        .lavenderField,
        .herbCluster,
        .bamboo,
        .ornamentalGrass,
        .cattails,
        .mushrooms,
        .lichens,
        .succulent,
        .pitcherPlant,
        .waterLily,
        .determinateTomato,
        .sweetPepper,
        .peaVines,
        .stringBeans,
        .cucumberVine,
        .rosemary,
        .thyme,
        .oregano,
        .sage
    ]

    public static var roomStudioIndoorSpecies: [PlantSpecies] {
        [
            .monstera,
            .fern,
            .succulent,
            .orchid,
            .bonsai,
            .ivy,
            .pitcherPlant,
            .herbCluster,
            .bamboo,
            .lavender,
            .dwarfCitrus,
            .alocasiaDragonScale,
            .ravenZZPlant,
            .prayerPlant,
            .staghornFern,
            .blackCoralColocasia
        ]
    }

    public var growthPerHour: Double {
        switch self {
        case .mossCarpet, .cloverPatch, .creepingThyme, .mushrooms, .lichens, .blueStarCreeper, .silverFallsDichondra, .corsicanMint, .redVeinSorrelPatch, .alpineEdelweissMat:
            0.026
        case .wildflowerMeadow, .lavenderField:
            0.024
        case .ornamentalGrass, .cattails:
            0.021
        case .waterLily:
            0.018
        case .fern, .ivy, .herbCluster, .prayerPlant, .staghornFern:
            0.015
        case .rosemary, .oregano, .sage, .purpleBasil, .shiso:
            0.016
        case .thyme, .saffronCrocus:
            0.020
        case .determinateTomato, .sweetPepper, .peaVines, .stringBeans, .cucumberVine, .dragonFruitCactus, .wasabi, .alpineStrawberry, .glassGemCorn, .cucamelon:
            0.021
        case .monstera, .succulent, .pitcherPlant, .alocasiaDragonScale, .ravenZZPlant, .blackCoralColocasia:
            0.012
        case .bamboo:
            0.018
        case .lavender, .wisteria, .jasmine, .orchid, .hydrangea, .peony, .rose, .foxglove, .poppy, .iris, .lily, .ghostOrchid, .jadeVine, .queenOfTheNight, .chocolateCosmos:
            0.018
        case .corpseFlower:
            0.011
        case .tulip:
            0.022
        case .sunflower:
            0.019
        case .cherryTree, .dogwood, .magnolia, .dwarfCitrus, .silkFlossTree:
            0.009
        case .mapleTree, .japaneseMaple, .willow, .birch, .oliveTree, .rainbowEucalyptus, .dragonBloodTree:
            0.008
        case .bonsai:
            0.006
        case .pineTree, .baobab, .monkeyPuzzleTree:
            0.007
        }
    }

    public var waterUsePerHour: Double {
        switch self {
        case .fern, .monstera, .ivy, .pitcherPlant, .mossCarpet, .cattails, .waterLily, .alocasiaDragonScale, .prayerPlant, .staghornFern, .blackCoralColocasia, .blueStarCreeper, .corsicanMint, .redVeinSorrelPatch, .wasabi:
            0.026
        case .lavender, .lavenderField, .creepingThyme, .herbCluster, .succulent, .oliveTree, .ravenZZPlant, .silverFallsDichondra, .alpineEdelweissMat, .dragonFruitCactus:
            0.018
        case .rosemary, .thyme, .oregano, .sage, .purpleBasil, .shiso, .saffronCrocus:
            0.017
        case .determinateTomato, .sweetPepper, .peaVines, .stringBeans, .cucumberVine, .alpineStrawberry, .glassGemCorn, .cucamelon:
            0.024
        case .tulip, .sunflower, .hydrangea, .peony, .rose, .foxglove, .poppy, .iris, .lily, .orchid, .jasmine, .wisteria, .ghostOrchid, .jadeVine, .corpseFlower, .queenOfTheNight, .chocolateCosmos:
            0.023
        case .cherryTree, .mapleTree, .bonsai, .japaneseMaple, .willow, .birch, .dogwood, .magnolia, .dwarfCitrus, .baobab, .dragonBloodTree, .rainbowEucalyptus, .silkFlossTree:
            0.020
        case .pineTree, .monkeyPuzzleTree:
            0.014
        case .wildflowerMeadow, .cloverPatch, .ornamentalGrass, .mushrooms, .lichens, .bamboo:
            0.021
        }
    }

    public var bloomPerHour: Double {
        switch self {
        case .fern, .pineTree, .monstera, .ivy, .bamboo, .succulent, .pitcherPlant, .mossCarpet, .ornamentalGrass, .mushrooms, .lichens, .alocasiaDragonScale, .ravenZZPlant, .prayerPlant, .staghornFern, .blackCoralColocasia, .baobab, .dragonBloodTree, .rainbowEucalyptus, .monkeyPuzzleTree:
            0.006
        case .lavender, .tulip, .sunflower, .wildflowerMeadow, .lavenderField, .cloverPatch, .creepingThyme, .wisteria, .jasmine, .orchid, .hydrangea, .peony, .rose, .foxglove, .poppy, .iris, .lily, .waterLily, .cattails, .ghostOrchid, .jadeVine, .corpseFlower, .queenOfTheNight, .chocolateCosmos, .blueStarCreeper, .silverFallsDichondra, .corsicanMint, .redVeinSorrelPatch, .alpineEdelweissMat:
            0.030
        case .cherryTree, .dogwood, .magnolia, .dwarfCitrus, .silkFlossTree:
            0.020
        case .determinateTomato, .sweetPepper, .peaVines, .stringBeans, .cucumberVine, .dragonFruitCactus, .alpineStrawberry, .glassGemCorn, .cucamelon:
            0.024
        case .mapleTree, .bonsai, .japaneseMaple, .willow, .birch, .oliveTree:
            0.010
        case .herbCluster, .rosemary, .thyme, .oregano, .sage, .purpleBasil, .shiso, .saffronCrocus, .wasabi:
            0.012
        }
    }

    public var matureHeightMultiplier: Double {
        switch self {
        case .mossCarpet, .cloverPatch, .creepingThyme, .mushrooms, .lichens, .blueStarCreeper, .corsicanMint, .redVeinSorrelPatch:
            0.28
        case .wildflowerMeadow, .lavenderField, .ornamentalGrass, .cattails, .waterLily, .silverFallsDichondra, .alpineEdelweissMat:
            0.42
        case .thyme, .shiso, .saffronCrocus:
            0.38
        case .rosemary, .oregano, .sage, .purpleBasil, .wasabi, .alpineStrawberry:
            0.60
        case .tulip, .lavender, .jasmine, .orchid, .hydrangea, .peony, .rose, .poppy, .iris, .lily, .ghostOrchid, .queenOfTheNight, .chocolateCosmos:
            0.72
        case .determinateTomato, .sweetPepper, .cucamelon:
            0.78
        case .wisteria, .foxglove, .peaVines, .stringBeans, .cucumberVine, .jadeVine, .dragonFruitCactus, .glassGemCorn:
            0.92
        case .fern, .ivy, .herbCluster, .succulent, .pitcherPlant, .prayerPlant, .staghornFern:
            0.78
        case .sunflower, .monstera, .bamboo, .alocasiaDragonScale, .ravenZZPlant, .blackCoralColocasia, .corpseFlower:
            0.95
        case .bonsai:
            0.96
        case .cherryTree, .mapleTree, .japaneseMaple, .birch, .dogwood, .magnolia, .oliveTree, .dwarfCitrus, .dragonBloodTree, .silkFlossTree:
            1.55
        case .pineTree, .willow, .baobab, .rainbowEucalyptus, .monkeyPuzzleTree:
            1.75
        }
    }

    public var defaultScaleRange: ClosedRange<Double> {
        switch self {
        case .mossCarpet, .cloverPatch, .creepingThyme, .lichens, .blueStarCreeper, .silverFallsDichondra, .corsicanMint, .redVeinSorrelPatch, .alpineEdelweissMat:
            1.10...1.58
        case .bonsai, .dwarfCitrus:
            0.62...0.94
        case .lavenderField, .wildflowerMeadow, .ornamentalGrass:
            1.00...1.46
        case .peaVines, .stringBeans, .cucumberVine, .cucamelon:
            0.72...1.08
        case .determinateTomato, .sweetPepper, .dragonFruitCactus, .alpineStrawberry, .glassGemCorn:
            0.80...1.18
        case .rosemary, .thyme, .oregano, .sage, .purpleBasil, .shiso, .saffronCrocus, .wasabi:
            0.82...1.20
        default:
            switch kind {
            case .tree:
                0.78...1.18
            case .meadow:
                0.9...1.35
            case .foliage:
                0.75...1.15
            case .flower:
                0.8...1.25
            case .edible:
                0.78...1.18
            }
        }
    }

    public static var flowers: [PlantSpecies] {
        [
            .lavender,
            .wisteria,
            .jasmine,
            .orchid,
            .tulip,
            .sunflower,
            .hydrangea,
            .peony,
            .rose,
            .foxglove,
            .poppy,
            .iris,
            .lily,
            .ghostOrchid,
            .jadeVine,
            .corpseFlower,
            .queenOfTheNight,
            .chocolateCosmos
        ]
    }

    public static var trees: [PlantSpecies] {
        [
            .cherryTree,
            .mapleTree,
            .bonsai,
            .japaneseMaple,
            .willow,
            .birch,
            .dogwood,
            .magnolia,
            .oliveTree,
            .dwarfCitrus,
            .pineTree,
            .baobab,
            .dragonBloodTree,
            .rainbowEucalyptus,
            .monkeyPuzzleTree,
            .silkFlossTree
        ]
    }

    public static var foliage: [PlantSpecies] {
        [
            .fern,
            .ivy,
            .monstera,
            .herbCluster,
            .bamboo,
            .succulent,
            .pitcherPlant,
            .alocasiaDragonScale,
            .ravenZZPlant,
            .prayerPlant,
            .staghornFern,
            .blackCoralColocasia
        ]
    }

    public static var meadows: [PlantSpecies] {
        [
            .mossCarpet,
            .cloverPatch,
            .creepingThyme,
            .wildflowerMeadow,
            .lavenderField,
            .ornamentalGrass,
            .cattails,
            .mushrooms,
            .lichens,
            .waterLily,
            .blueStarCreeper,
            .silverFallsDichondra,
            .corsicanMint,
            .redVeinSorrelPatch,
            .alpineEdelweissMat
        ]
    }

    public static var edibles: [PlantSpecies] {
        [
            .determinateTomato,
            .sweetPepper,
            .peaVines,
            .stringBeans,
            .cucumberVine,
            .rosemary,
            .thyme,
            .oregano,
            .sage,
            .dragonFruitCactus,
            .purpleBasil,
            .shiso,
            .saffronCrocus,
            .wasabi,
            .alpineStrawberry,
            .glassGemCorn,
            .cucamelon
        ]
    }
}
