import Foundation

public struct GardenScenePlantSuitability: Equatable, Sendable {
    public let species: PlantSpecies
    public let sceneDisplayName: String
    public let isSuitable: Bool
    public let reason: String?
}

public struct GardenScenePlantEnvironment: Equatable, Sendable {
    public let sceneKey: String
    public let displayName: String
    public let summary: String

    private let tags: Set<GardenPlantHabitatTag>

    public init(sceneKey: String?) {
        let key = sceneKey?.lowercased() ?? "empty-conservatory-hall"
        let preset = Self.preset(for: key)
        self.sceneKey = key
        displayName = preset.displayName
        summary = preset.summary
        tags = preset.tags
    }

    public func isSuitable(_ species: PlantSpecies) -> Bool {
        suitability(for: species).isSuitable
    }

    public func suitability(for species: PlantSpecies) -> GardenScenePlantSuitability {
        let profile = GardenPlantHabitatProfile.profile(for: species)
        if !profile.excludedSceneTags.isDisjoint(with: tags) {
            return GardenScenePlantSuitability(
                species: species,
                sceneDisplayName: displayName,
                isSuitable: false,
                reason: "\(species.displayName) does not fit the \(displayName)'s \(summary) environment"
            )
        }

        if !profile.requiredSceneTags.isEmpty,
           profile.requiredSceneTags.isDisjoint(with: tags) {
            return GardenScenePlantSuitability(
                species: species,
                sceneDisplayName: displayName,
                isSuitable: false,
                reason: "\(species.displayName) needs a different habitat than the \(displayName)'s \(summary) environment"
            )
        }

        let idealMatches = profile.idealSceneTags.intersection(tags).count
        let toleratedMatches = profile.toleratedSceneTags.intersection(tags).count
        let score = idealMatches * 2 + toleratedMatches
        let isSuitable = score > 0
        return GardenScenePlantSuitability(
            species: species,
            sceneDisplayName: displayName,
            isSuitable: isSuitable,
            reason: isSuitable ? nil : "\(species.displayName) does not belong in the \(displayName)'s \(summary) environment"
        )
    }

    public func suitableSpecies(in kind: PlantKind? = nil) -> [PlantSpecies] {
        PlantSpecies.allCases.filter { species in
            if let kind, species.kind != kind {
                return false
            }

            return isSuitable(species)
        }
    }

    private static func preset(for key: String) -> GardenScenePlantEnvironmentPreset {
        if key.contains("rainforest")
            || key.contains("jungle") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Rainforest Canvas",
                summary: "warm humid layered jungle",
                tags: [.glasshouse, .indoor, .warm, .humid, .wet, .shade, .woodland, .bog, .meadow]
            )
        }

        if key.contains("water")
            || key.contains("pond")
            || key.contains("wetland")
            || key.contains("aquatic")
            || key.contains("pavilion") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Water Pavilion",
                summary: "humid aquatic",
                tags: [.aquatic, .wet, .humid, .bog, .glasshouse, .shade, .temperate, .woodland]
            )
        }

        if key.contains("desert")
            || key.contains("desertarium")
            || key.contains("arid")
            || key.contains("dry") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Desertarium",
                summary: "arid sunlit",
                tags: [.arid, .dry, .sun, .container, .stone, .mediterranean]
            )
        }

        if key.contains("chinese-mountain")
            || key.contains("monk")
            || key.contains("mountain-monk") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Chinese Mountain Monk Garden",
                summary: "cool misty mountain courtyard",
                tags: [.courtyard, .stone, .container, .cool, .shade, .humid, .temperate, .woodland]
            )
        }

        if key.contains("swedish")
            || key.contains("patio") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Swedish Patio Garden",
                summary: "cool temperate patio",
                tags: [.courtyard, .container, .temperate, .cool, .sun, .meadow]
            )
        }

        if key.contains("brazilian-rooftop")
            || key.contains("brazilian") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Brazilian Rooftop Garden",
                summary: "warm humid rooftop",
                tags: [.rooftop, .container, .warm, .humid, .sun, .coastal]
            )
        }

        if key.contains("egyptian")
            || key.contains("estate-garden") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Ancient Egyptian Estate Garden",
                summary: "warm poolside estate",
                tags: [.courtyard, .container, .warm, .sun, .wet, .mediterranean]
            )
        }

        if key.contains("texas")
            || key.contains("rustic-garden") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Texas Rustic Garden",
                summary: "dry rustic homestead",
                tags: [.courtyard, .container, .arid, .dry, .sun, .warm, .stone, .meadow]
            )
        }

        if key.contains("starship")
            || key.contains("command-bridge")
            || key.contains("hydroponic") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Starship Command Bridge",
                summary: "indoor hydroponic container",
                tags: [.indoor, .container, .temperate, .warm, .humid, .shade, .sun]
            )
        }

        if key.contains("alien")
            || key.contains("ufo")
            || key.contains("exoplanet")
            || key.contains("martian") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Alien/UFO Garden",
                summary: "sealed xenobotany habitat",
                tags: [.indoor, .container, .warm, .humid, .sun, .shade, .stone, .night]
            )
        }

        if key.contains("coastal")
            || key.contains("seaside")
            || key.contains("shore")
            || key.contains("terrace") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Coastal Terrace",
                summary: "sunny coastal",
                tags: [.coastal, .sun, .dry, .humid, .temperate, .mediterranean, .meadow, .container]
            )
        }

        if key.contains("rooftop")
            || key.contains("roof")
            || key.contains("seed-house") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Rooftop Seed House",
                summary: "sunny container",
                tags: [.rooftop, .container, .sun, .dry, .temperate, .warm, .mediterranean, .meadow]
            )
        }

        if key.contains("moonlit")
            || key.contains("night")
            || key.contains("misty") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Moonlit Glasshouse",
                summary: "cool humid shade",
                tags: [.glasshouse, .indoor, .humid, .shade, .cool, .night, .temperate, .woodland, .bog]
            )
        }

        if key.contains("gravel")
            || key.contains("courtyard")
            || key.contains("stone") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Gravel Courtyard",
                summary: "dry temperate courtyard",
                tags: [.courtyard, .stone, .dry, .sun, .temperate, .mediterranean, .container]
            )
        }

        if key.contains("victorian")
            || key.contains("seed-gallery")
            || key.contains("nursery") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Victorian Seed Gallery",
                summary: "temperate indoor nursery",
                tags: [.seedlingBench, .indoor, .container, .temperate, .glasshouse, .cool, .sun, .shade, .meadow]
            )
        }

        if key.contains("apartment")
            || key.contains("studio")
            || key.contains("bedroom")
            || key.contains("media-den")
            || key.contains("room-")
            || key.contains("living-room")
            || key.contains("loft") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Apartment Studio",
                summary: "temperate indoor container",
                tags: [.indoor, .container, .temperate, .warm, .sun]
            )
        }

        if key.contains("cottage")
            || key.contains("backyard")
            || key.contains("raised-bed") {
            return GardenScenePlantEnvironmentPreset(
                displayName: "Cottage Backyard Garden",
                summary: "temperate raised-bed",
                tags: [.courtyard, .container, .temperate, .sun, .warm, .meadow]
            )
        }

        return GardenScenePlantEnvironmentPreset(
            displayName: "Conservatory Hall",
            summary: "temperate glasshouse",
            tags: [.glasshouse, .indoor, .container, .temperate, .warm, .humid, .shade, .sun, .woodland, .meadow, .mediterranean]
        )
    }
}

private enum GardenPlantHabitatTag: Hashable, Sendable {
    case aquatic
    case arid
    case bog
    case container
    case cool
    case coastal
    case courtyard
    case dry
    case glasshouse
    case humid
    case indoor
    case meadow
    case mediterranean
    case night
    case rooftop
    case seedlingBench
    case shade
    case stone
    case sun
    case temperate
    case warm
    case wet
    case woodland
}

private struct GardenScenePlantEnvironmentPreset: Equatable, Sendable {
    let displayName: String
    let summary: String
    let tags: Set<GardenPlantHabitatTag>
}

private struct GardenPlantHabitatProfile: Equatable, Sendable {
    let idealSceneTags: Set<GardenPlantHabitatTag>
    let toleratedSceneTags: Set<GardenPlantHabitatTag>
    let requiredSceneTags: Set<GardenPlantHabitatTag>
    let excludedSceneTags: Set<GardenPlantHabitatTag>

    static func profile(for species: PlantSpecies) -> GardenPlantHabitatProfile {
        switch species {
        case .fern:
            profile(ideal: [.humid, .shade, .woodland, .glasshouse], tolerated: [.temperate, .indoor], excluded: [.arid, .dry])
        case .mossCarpet:
            profile(ideal: [.humid, .shade, .woodland], tolerated: [.glasshouse, .wet, .temperate, .cool], excluded: [.arid])
        case .cloverPatch:
            profile(ideal: [.temperate, .meadow, .sun], tolerated: [.cool, .container, .courtyard, .rooftop])
        case .creepingThyme:
            profile(ideal: [.dry, .sun, .mediterranean, .stone], tolerated: [.courtyard, .rooftop, .container, .temperate], excluded: [.aquatic, .bog])
        case .ivy:
            profile(ideal: [.shade, .temperate, .courtyard, .glasshouse], tolerated: [.indoor, .humid, .woodland], excluded: [.arid])
        case .lavender:
            profile(ideal: [.dry, .sun, .mediterranean], tolerated: [.coastal, .rooftop, .container, .courtyard, .glasshouse], excluded: [.aquatic, .wet, .bog])
        case .wisteria:
            profile(ideal: [.temperate, .sun, .courtyard, .glasshouse], tolerated: [.humid, .coastal, .container], excluded: [.arid, .aquatic, .bog])
        case .jasmine:
            profile(ideal: [.warm, .humid, .glasshouse], tolerated: [.coastal, .courtyard, .container, .sun], excluded: [.arid, .cool, .aquatic])
        case .orchid:
            profile(ideal: [.humid, .glasshouse, .warm, .shade], tolerated: [.indoor, .bog], required: [.humid, .glasshouse], excluded: [.arid, .dry, .rooftop])
        case .ghostOrchid:
            profile(ideal: [.humid, .glasshouse, .warm, .shade], tolerated: [.indoor, .woodland], required: [.humid, .glasshouse], excluded: [.arid, .dry, .rooftop, .sun])
        case .tulip:
            profile(ideal: [.temperate, .cool, .sun], tolerated: [.container, .seedlingBench, .courtyard, .glasshouse], excluded: [.arid, .aquatic, .bog])
        case .sunflower:
            profile(ideal: [.sun, .meadow, .container], tolerated: [.rooftop, .temperate, .courtyard], excluded: [.aquatic, .bog])
        case .jadeVine, .queenOfTheNight:
            profile(ideal: [.warm, .humid, .glasshouse], tolerated: [.container, .courtyard, .shade], excluded: [.arid, .cool, .aquatic])
        case .corpseFlower:
            profile(ideal: [.warm, .humid, .glasshouse, .shade], tolerated: [.indoor], required: [.humid, .warm], excluded: [.arid, .dry, .rooftop])
        case .chocolateCosmos:
            profile(ideal: [.sun, .dry, .temperate], tolerated: [.container, .courtyard, .rooftop], excluded: [.aquatic, .bog, .shade])
        case .cherryTree:
            profile(ideal: [.temperate, .sun, .courtyard], tolerated: [.glasshouse, .container, .cool], excluded: [.arid, .aquatic, .bog, .rooftop])
        case .mapleTree:
            profile(ideal: [.temperate, .cool, .courtyard], tolerated: [.glasshouse, .shade, .container], excluded: [.arid, .aquatic, .bog, .rooftop])
        case .bonsai:
            profile(ideal: [.container, .indoor, .temperate], tolerated: [.glasshouse, .rooftop, .dry, .cool, .warm, .stone])
        case .japaneseMaple:
            profile(ideal: [.temperate, .cool, .shade, .courtyard], tolerated: [.glasshouse, .container, .humid], excluded: [.arid, .aquatic, .rooftop])
        case .willow:
            profile(ideal: [.wet, .temperate, .aquatic], tolerated: [.humid, .woodland], required: [.wet, .aquatic, .humid], excluded: [.arid, .dry, .rooftop])
        case .birch:
            profile(ideal: [.cool, .temperate, .courtyard], tolerated: [.glasshouse, .woodland, .sun], excluded: [.arid, .aquatic, .rooftop])
        case .dogwood:
            profile(ideal: [.temperate, .woodland, .courtyard], tolerated: [.shade, .glasshouse, .humid], excluded: [.arid, .aquatic])
        case .magnolia:
            profile(ideal: [.temperate, .warm, .courtyard], tolerated: [.glasshouse, .humid, .sun], excluded: [.arid, .aquatic, .rooftop])
        case .oliveTree:
            profile(ideal: [.dry, .sun, .mediterranean, .coastal], tolerated: [.courtyard, .rooftop, .container, .stone], excluded: [.aquatic, .bog, .shade])
        case .dwarfCitrus:
            profile(ideal: [.warm, .sun, .container], tolerated: [.glasshouse, .coastal, .rooftop, .indoor], excluded: [.cool, .aquatic, .bog])
        case .pineTree:
            profile(ideal: [.temperate, .cool, .sun], tolerated: [.dry, .coastal, .courtyard, .stone, .container], excluded: [.aquatic, .bog])
        case .baobab, .dragonBloodTree:
            profile(ideal: [.arid, .dry, .sun, .stone], tolerated: [.container, .courtyard, .warm], excluded: [.aquatic, .bog, .cool])
        case .rainbowEucalyptus:
            profile(ideal: [.warm, .humid, .sun], tolerated: [.coastal, .glasshouse, .courtyard], excluded: [.arid, .dry, .cool])
        case .monkeyPuzzleTree:
            profile(ideal: [.cool, .temperate, .sun], tolerated: [.coastal, .courtyard, .container], excluded: [.arid, .aquatic, .bog])
        case .silkFlossTree:
            profile(ideal: [.warm, .sun, .courtyard], tolerated: [.dry, .container, .rooftop], excluded: [.cool, .aquatic, .bog])
        case .monstera:
            profile(ideal: [.humid, .warm, .glasshouse, .indoor], tolerated: [.shade], excluded: [.arid, .dry, .rooftop, .cool])
        case .alocasiaDragonScale, .blackCoralColocasia:
            profile(ideal: [.humid, .warm, .shade, .glasshouse], tolerated: [.indoor, .container], excluded: [.arid, .dry, .rooftop, .cool])
        case .ravenZZPlant:
            profile(ideal: [.indoor, .shade, .warm], tolerated: [.dry, .container, .glasshouse], excluded: [.aquatic, .bog])
        case .prayerPlant:
            profile(ideal: [.humid, .warm, .shade, .indoor], tolerated: [.glasshouse, .container], excluded: [.arid, .dry, .rooftop])
        case .staghornFern:
            profile(ideal: [.humid, .shade, .glasshouse], tolerated: [.warm, .indoor, .woodland], excluded: [.arid, .dry, .rooftop])
        case .hydrangea:
            profile(ideal: [.humid, .temperate, .shade], tolerated: [.coastal, .glasshouse, .courtyard, .wet], excluded: [.arid, .dry])
        case .peony:
            profile(ideal: [.temperate, .cool, .sun], tolerated: [.courtyard, .container, .glasshouse], excluded: [.arid, .aquatic, .bog])
        case .rose:
            profile(ideal: [.temperate, .sun, .courtyard], tolerated: [.container, .rooftop, .coastal, .glasshouse], excluded: [.aquatic, .bog, .shade])
        case .foxglove:
            profile(ideal: [.woodland, .temperate, .shade], tolerated: [.humid, .glasshouse, .cool], excluded: [.arid, .dry, .rooftop])
        case .poppy:
            profile(ideal: [.sun, .dry, .temperate], tolerated: [.meadow, .courtyard, .coastal, .container], excluded: [.aquatic, .bog, .shade])
        case .iris:
            profile(ideal: [.wet, .sun, .temperate], tolerated: [.humid, .aquatic, .courtyard, .glasshouse], excluded: [.arid])
        case .lily:
            profile(ideal: [.temperate, .humid, .sun], tolerated: [.glasshouse, .wet, .container], excluded: [.arid, .dry])
        case .wildflowerMeadow:
            profile(ideal: [.meadow, .sun, .temperate], tolerated: [.rooftop, .courtyard, .coastal, .container], excluded: [.aquatic, .bog, .shade])
        case .lavenderField:
            profile(ideal: [.dry, .sun, .mediterranean], tolerated: [.coastal, .rooftop, .courtyard], excluded: [.aquatic, .wet, .bog, .shade])
        case .herbCluster:
            profile(ideal: [.container, .sun, .rooftop], tolerated: [.dry, .mediterranean, .courtyard, .glasshouse, .indoor], excluded: [.aquatic, .bog])
        case .bamboo:
            profile(ideal: [.humid, .warm, .glasshouse], tolerated: [.coastal, .shade, .container, .wet], excluded: [.arid, .dry])
        case .ornamentalGrass:
            profile(ideal: [.sun, .dry, .coastal], tolerated: [.rooftop, .courtyard, .meadow, .container, .temperate], excluded: [.aquatic, .bog])
        case .cattails:
            profile(ideal: [.aquatic, .wet, .sun], tolerated: [.humid, .bog], required: [.aquatic, .wet, .bog], excluded: [.arid, .dry, .rooftop])
        case .mushrooms:
            profile(ideal: [.humid, .shade, .woodland], tolerated: [.glasshouse, .cool, .night], required: [.humid, .shade, .woodland], excluded: [.arid, .dry, .sun, .rooftop])
        case .lichens:
            profile(ideal: [.stone, .cool, .dry], tolerated: [.courtyard, .arid, .coastal, .temperate], excluded: [.aquatic, .bog])
        case .succulent:
            profile(ideal: [.arid, .dry, .sun, .container], tolerated: [.rooftop, .stone, .mediterranean, .indoor], excluded: [.aquatic, .wet, .bog, .humid, .shade])
        case .pitcherPlant:
            profile(ideal: [.bog, .wet, .humid], tolerated: [.glasshouse, .shade], required: [.bog, .wet, .humid], excluded: [.arid, .dry, .rooftop])
        case .waterLily:
            profile(ideal: [.aquatic, .wet, .sun], tolerated: [.humid], required: [.aquatic, .wet], excluded: [.arid, .dry, .rooftop, .stone])
        case .blueStarCreeper, .corsicanMint:
            profile(ideal: [.temperate, .wet, .shade], tolerated: [.courtyard, .container, .cool], excluded: [.arid, .dry])
        case .silverFallsDichondra:
            profile(ideal: [.sun, .dry, .container], tolerated: [.rooftop, .courtyard, .coastal], excluded: [.aquatic, .bog])
        case .redVeinSorrelPatch:
            profile(ideal: [.temperate, .humid, .container], tolerated: [.shade, .courtyard, .rooftop], excluded: [.arid, .dry])
        case .alpineEdelweissMat:
            profile(ideal: [.cool, .dry, .sun, .stone], tolerated: [.container, .courtyard], excluded: [.humid, .aquatic, .bog])
        case .determinateTomato, .sweetPepper, .peaVines, .stringBeans, .cucumberVine:
            profile(ideal: [.container, .sun, .temperate, .warm], tolerated: [.courtyard, .rooftop, .coastal, .meadow], excluded: [.aquatic, .bog, .shade])
        case .rosemary, .thyme, .oregano, .sage:
            profile(ideal: [.container, .sun, .dry, .mediterranean], tolerated: [.courtyard, .rooftop, .temperate, .coastal, .stone], excluded: [.aquatic, .bog])
        case .dragonFruitCactus:
            profile(ideal: [.container, .sun, .dry, .warm], tolerated: [.rooftop, .courtyard, .mediterranean], excluded: [.aquatic, .bog, .cool])
        case .purpleBasil, .shiso:
            profile(ideal: [.container, .sun, .warm], tolerated: [.courtyard, .rooftop, .temperate], excluded: [.aquatic, .bog])
        case .saffronCrocus:
            profile(ideal: [.dry, .sun, .mediterranean], tolerated: [.container, .courtyard, .temperate], excluded: [.aquatic, .bog])
        case .wasabi:
            profile(ideal: [.wet, .shade, .cool], tolerated: [.humid, .container, .glasshouse], required: [.wet, .shade], excluded: [.arid, .dry, .sun, .rooftop])
        case .alpineStrawberry, .glassGemCorn, .cucamelon:
            profile(ideal: [.container, .sun, .temperate, .warm], tolerated: [.courtyard, .rooftop, .meadow], excluded: [.aquatic, .bog, .shade])
        }
    }

    private static func profile(
        ideal: Set<GardenPlantHabitatTag>,
        tolerated: Set<GardenPlantHabitatTag> = [],
        required: Set<GardenPlantHabitatTag> = [],
        excluded: Set<GardenPlantHabitatTag> = []
    ) -> GardenPlantHabitatProfile {
        GardenPlantHabitatProfile(
            idealSceneTags: ideal,
            toleratedSceneTags: tolerated,
            requiredSceneTags: required,
            excludedSceneTags: excluded
        )
    }
}
