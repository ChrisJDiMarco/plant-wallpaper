import Foundation
import PlantGardenCore

enum GardenMenuTitleFormatter {
    static let statusTitleMaxLength = 54
    static let selectedPlantTitleMaxLength = 48
    static let sceneTitleMaxLength = 44

    static func compactStatusTitle(_ title: String, maxLength: Int = statusTitleMaxLength) -> String {
        let safeMaxLength = max(4, maxLength)
        guard title.count > safeMaxLength else {
            return title
        }

        let endIndex = title.index(title.startIndex, offsetBy: safeMaxLength - 3)
        let trimmedPrefix = title[..<endIndex]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-:,. "))
        let prefix = trimmedPrefix.isEmpty ? String(title.prefix(safeMaxLength - 3)) : trimmedPrefix
        return "\(prefix)..."
    }
}

enum GardenAmbientSoundLayer: String, CaseIterable {
    case master
    case birdsong
    case crickets
    case wind
    case rain
    case water
    case urbanMurmur
    case roomTone
    case cicadas
    case chimes
    case smallWildlife
    case roomLife
    case electronics
    case alienFauna
    case habitatHum
    case crystallineShimmer
    case lowRumble
}

struct GardenAmbientSoundMenuEntry: Equatable {
    let id: GardenAmbientSoundLayer
    let title: String
    let symbolName: String
}

struct GardenPricingTier: Equatable {
    let name: String
    let price: String
    let badge: String
    let summary: String
    let features: [String]
}

enum GardenPricingCatalog {
    static let title = "Pricing & Pro"
    static let menuTitle = "Pricing & Pro..."
    static let subtitle = "A generous free desktop garden, with Pro for premium worlds, hosted AI credits, and advanced creative tools."
    static let free = GardenPricingTier(
        name: "Free",
        price: "$0",
        badge: "Start here",
        summary: "A calm living desktop garden without a subscription.",
        features: [
            "Core Garden mode with manual planting, watering, harvesting, and seeds",
            "Starter wallpaper scenes and basic scene switching",
            "Cat companion, environmental sounds, basic radio companions, and wildlife",
            "Use your own OpenAI API key for optional AI generation"
        ]
    )
    static let pro = GardenPricingTier(
        name: "Pro",
        price: "$8/mo or $60/yr",
        badge: "Recommended",
        summary: "For people who want the app to become a full creative world.",
        features: [
            "Room Studio, Alien/UFO Garden, premium scene packs, and future themed modes",
            "Monthly hosted AI credits for custom plants, props, companions, and wallpaper edits",
            "Progression mode, time-of-day wallpaper sets, advanced screensaver syncing, and time-lapse export",
            "Premium companions, gnome tribes, advanced bug behaviors, prompt history, and storage tools"
        ]
    )

    static let footer = "Free can use your own OpenAI API key for optional generation. Pro includes hosted AI credits; extra high-volume or 4K generations use credit packs so AI costs stay transparent."
}

enum GardenAmbientSoundMenuCatalog {
    static let entries: [GardenAmbientSoundMenuEntry] = [
        GardenAmbientSoundMenuEntry(
            id: .master,
            title: "Environmental Sounds",
            symbolName: "speaker.wave.2.fill"
        ),
        GardenAmbientSoundMenuEntry(
            id: .birdsong,
            title: "Birdsong",
            symbolName: "bird.fill"
        ),
        GardenAmbientSoundMenuEntry(
            id: .crickets,
            title: "Crickets",
            symbolName: "antenna.radiowaves.left.and.right"
        ),
        GardenAmbientSoundMenuEntry(
            id: .wind,
            title: "Wind",
            symbolName: "wind"
        ),
        GardenAmbientSoundMenuEntry(
            id: .rain,
            title: "Rain",
            symbolName: "cloud.rain.fill"
        ),
        GardenAmbientSoundMenuEntry(
            id: .water,
            title: "Water & Ripples",
            symbolName: "water.waves"
        ),
        GardenAmbientSoundMenuEntry(
            id: .urbanMurmur,
            title: "Distant City",
            symbolName: "building.2.fill"
        ),
        GardenAmbientSoundMenuEntry(
            id: .roomTone,
            title: "Room Tone",
            symbolName: "house.fill"
        ),
        GardenAmbientSoundMenuEntry(
            id: .cicadas,
            title: "Cicadas",
            symbolName: "waveform"
        ),
        GardenAmbientSoundMenuEntry(
            id: .chimes,
            title: "Chimes",
            symbolName: "bell.fill"
        ),
        GardenAmbientSoundMenuEntry(
            id: .smallWildlife,
            title: "Small Wildlife",
            symbolName: "leaf.fill"
        ),
        GardenAmbientSoundMenuEntry(
            id: .roomLife,
            title: "Room Life",
            symbolName: "sofa.fill"
        ),
        GardenAmbientSoundMenuEntry(
            id: .electronics,
            title: "Electronics Hum",
            symbolName: "desktopcomputer"
        ),
        GardenAmbientSoundMenuEntry(
            id: .alienFauna,
            title: "Alien Fauna",
            symbolName: "sparkles"
        ),
        GardenAmbientSoundMenuEntry(
            id: .habitatHum,
            title: "Habitat Hum",
            symbolName: "circle.hexagongrid.fill"
        ),
        GardenAmbientSoundMenuEntry(
            id: .crystallineShimmer,
            title: "Crystal Shimmer",
            symbolName: "diamond.fill"
        ),
        GardenAmbientSoundMenuEntry(
            id: .lowRumble,
            title: "Low Rumble",
            symbolName: "waveform.path.ecg"
        )
    ]
}

struct GardenPlantSpecificMenuEntry: Equatable {
    let species: PlantSpecies
    let isAssetAvailable: Bool
    let isSceneSuitable: Bool
    let disabledReason: String?

    var isEnabled: Bool {
        disabledReason == nil
    }
}

enum GardenPlantCategoryMenuTitle {
    static func addNewTitle(for kind: PlantKind) -> String {
        "Add New \(kind.displayName)..."
    }

    static func randomTitle(for kind: PlantKind) -> String {
        "Random \(kind.displayName) Here"
    }

    static func leadingTitles(for kind: PlantKind) -> [String] {
        [
            addNewTitle(for: kind),
            randomTitle(for: kind)
        ]
    }
}

enum RoomStudioPlantMenuCatalog {
    static let title = "Add Indoor Plant Here"
    static let addNewTitle = "Add New Indoor Plant..."
    static let randomTitle = "Random Indoor Plant Here"
    static let starterDescription = "a premium indoor potted plant for a bedroom or chill room, tasteful ceramic planter, realistic leaves, clean silhouette"

    static let leadingTitles = [
        addNewTitle,
        randomTitle
    ]
}

struct RainforestFutureAsset: Equatable {
    let title: String
    let kind: PlantKind
    let promptSeed: String
}

struct RainforestPropAsset: Equatable {
    let title: String
    let symbolName: String
    let promptSeed: String
}

enum RainforestAssetMenuCatalog {
    static let title = "Build Rainforest Here"
    static let propMenuTitle = "Rainforest Props & Atmosphere"
    static let comingSoonTitle = "Coming Soon - needs PNG assets"

    static func title(for kind: PlantKind) -> String {
        switch kind {
        case .flower:
            "Rainforest Flowers Here"
        case .tree:
            "Rainforest Trees Here"
        case .foliage:
            "Rainforest Foliage Here"
        case .meadow:
            "Rainforest Floor Here"
        case .edible:
            "Rainforest Edibles Here"
        }
    }

    static func addNewTitle(for kind: PlantKind) -> String {
        switch kind {
        case .meadow:
            "Add New Rainforest Floor Asset..."
        default:
            "Add New Rainforest \(kind.displayName)..."
        }
    }

    static func randomTitle(for kind: PlantKind) -> String {
        switch kind {
        case .meadow:
            "Random Rainforest Floor Asset Here"
        default:
            "Random Rainforest \(kind.displayName) Here"
        }
    }

    static func starterDescription(for kind: PlantKind) -> String {
        switch kind {
        case .flower:
            "A large tropical orchid cluster with humid glossy leaves, hanging roots, saturated petals, and a clean natural base"
        case .tree:
            "A broad rainforest understory tree cutout with buttress roots, layered glossy canopy, mossy bark, and a clean root edge"
        case .foliage:
            "A huge layered monstera and fern foliage cluster with overlapping leaves, humid highlights, and a dramatic jungle silhouette"
        case .meadow:
            "A dense rainforest floor mat with moss, leaf litter, tiny ferns, wet stones, and an irregular organic edge"
        case .edible:
            "A lush tropical edible vine with broad leaves, tendrils, small fruit, and a clean natural base"
        }
    }

    static func futureAssets(in kind: PlantKind) -> [RainforestFutureAsset] {
        futureAssets.filter { $0.kind == kind }
    }

    static let futureAssets: [RainforestFutureAsset] = [
        RainforestFutureAsset(title: "Canopy Leaf Wall", kind: .tree, promptSeed: "a tall wall of overlapping rainforest canopy leaves with deep layered silhouette"),
        RainforestFutureAsset(title: "Buttress Root Tree", kind: .tree, promptSeed: "a rainforest tree trunk with dramatic buttress roots, moss, and damp bark texture"),
        RainforestFutureAsset(title: "Strangler Fig Column", kind: .tree, promptSeed: "twisting strangler fig roots wrapping into a vertical rainforest column"),
        RainforestFutureAsset(title: "Young Kapok Tree", kind: .tree, promptSeed: "young kapok tree cutout with broad leaves and sculptural rainforest roots"),
        RainforestFutureAsset(title: "Palm Crown Layer", kind: .tree, promptSeed: "oversized palm fronds forming a dense upper canopy layer"),
        RainforestFutureAsset(title: "Giant Banana Leaves", kind: .foliage, promptSeed: "huge torn banana leaves with glossy humid highlights for foreground layering"),
        RainforestFutureAsset(title: "Philodendron Wall", kind: .foliage, promptSeed: "dense climbing philodendron leaf wall with overlapping heart-shaped leaves"),
        RainforestFutureAsset(title: "Bird's Nest Fern Cluster", kind: .foliage, promptSeed: "large bird's nest fern cluster with rippled fronds and damp central rosette"),
        RainforestFutureAsset(title: "Vine Curtain", kind: .foliage, promptSeed: "hanging curtain of rainforest vines with varied leaf sizes and dangling tendrils"),
        RainforestFutureAsset(title: "Liana Rope Vines", kind: .foliage, promptSeed: "thick twisting liana vines looping downward with small leaves and moss"),
        RainforestFutureAsset(title: "Foreground Monstera Leaves", kind: .foliage, promptSeed: "extra large foreground monstera leaves cropped-friendly but isolated as a full cutout"),
        RainforestFutureAsset(title: "Heliconia Torch Cluster", kind: .flower, promptSeed: "bright red-orange heliconia flower bracts with lush tropical leaves"),
        RainforestFutureAsset(title: "Bromeliad Nest", kind: .flower, promptSeed: "rainforest bromeliad cluster with water-catching rosettes and saturated flower spike"),
        RainforestFutureAsset(title: "Passionflower Vine", kind: .flower, promptSeed: "delicate passionflower vine with curling tendrils and layered leaves"),
        RainforestFutureAsset(title: "Jungle Ginger Bloom", kind: .flower, promptSeed: "torch ginger bloom with waxy pink bracts and tropical leaves"),
        RainforestFutureAsset(title: "Mossy Floor Patch", kind: .meadow, promptSeed: "wet rainforest moss patch with leaf litter, tiny ferns, and irregular edges"),
        RainforestFutureAsset(title: "Fern Floor Mat", kind: .meadow, promptSeed: "low carpet of young ferns for filling the bottom of a jungle collage"),
        RainforestFutureAsset(title: "Leaf Litter Carpet", kind: .meadow, promptSeed: "brown-green rainforest leaf litter mat with damp natural texture"),
        RainforestFutureAsset(title: "Tiny Mushroom Colony", kind: .meadow, promptSeed: "cluster of tiny rainforest mushrooms emerging from moss and wet bark"),
        RainforestFutureAsset(title: "Cacao Sapling", kind: .edible, promptSeed: "young cacao plant with glossy leaves and small colorful pods"),
        RainforestFutureAsset(title: "Coffee Shrub", kind: .edible, promptSeed: "lush coffee shrub with red berries and rainforest understory leaves"),
        RainforestFutureAsset(title: "Vanilla Orchid Vine", kind: .edible, promptSeed: "vanilla orchid vine with thick leaves, tendrils, and pale flowers")
    ]

    static let propAssets: [RainforestPropAsset] = [
        RainforestPropAsset(title: "Mossy Boulder", symbolName: "mountain.2.fill", promptSeed: "rounded wet rainforest boulder with moss, lichen, and soft shadow base"),
        RainforestPropAsset(title: "Fallen Jungle Log", symbolName: "tree.fill", promptSeed: "fallen damp jungle log with moss, fungus, and exposed bark texture"),
        RainforestPropAsset(title: "Root Tangle", symbolName: "point.3.connected.trianglepath.dotted", promptSeed: "tangled exposed rainforest roots for foreground layering"),
        RainforestPropAsset(title: "Wet Stone Cluster", symbolName: "circle.hexagongrid.fill", promptSeed: "small cluster of wet stones with moss and leaf litter"),
        RainforestPropAsset(title: "Mist Veil", symbolName: "cloud.fog.fill", promptSeed: "soft semi-transparent rainforest mist veil for depth layering"),
        RainforestPropAsset(title: "Sunbeam Haze", symbolName: "sun.rays.fill", promptSeed: "warm diagonal jungle sunbeam haze layer"),
        RainforestPropAsset(title: "Hanging Moss Strands", symbolName: "line.3.horizontal.decrease", promptSeed: "long hanging moss strands with small leaves and natural gaps"),
        RainforestPropAsset(title: "Rain Droplet Leaf", symbolName: "drop.fill", promptSeed: "oversized leaf with rain droplets for close foreground framing"),
        RainforestPropAsset(title: "Epiphyte Branch", symbolName: "leaf.fill", promptSeed: "branch covered in epiphytes, moss, tiny orchids, and dangling roots"),
        RainforestPropAsset(title: "Jungle Edge Shadow", symbolName: "circle.lefthalf.filled", promptSeed: "soft dark foreground leaf-shadow layer for natural depth")
    ]
}

struct AlienPlantMenuSpecimen: Equatable {
    let title: String
    let kind: PlantKind
    let promptSeed: String

    var assetName: String {
        AlienPlantMenuCatalog.assetName(for: self)
    }

    var customAssetID: String {
        AlienPlantMenuCatalog.customAssetID(for: self)
    }
}

enum AlienPlantMenuCatalog {
    static let categoryOrder: [PlantKind] = [.flower, .tree, .foliage, .meadow, .edible]

    static func title(for kind: PlantKind) -> String {
        "Plant Alien \(kind.displayName) Here"
    }

    static func addNewTitle(for kind: PlantKind) -> String {
        "Add New Alien \(kind.displayName)..."
    }

    static func randomTitle(for kind: PlantKind) -> String {
        "Random Alien \(kind.displayName) Here"
    }

    static func starterDescription(for kind: PlantKind) -> String {
        specimens(in: kind).first?.promptSeed
            ?? "A beautiful alien \(kind.displayName.lowercased()) with believable speculative botany, bioluminescent details, crisp silhouette, and clean root contact"
    }

    static func specimens(in kind: PlantKind) -> [AlienPlantMenuSpecimen] {
        specimens.filter { $0.kind == kind }
    }

    static func specimen(forCustomAssetID customAssetID: String) -> AlienPlantMenuSpecimen? {
        guard customAssetID.hasPrefix(customAssetIDPrefix) else {
            return nil
        }

        let assetName = String(customAssetID.dropFirst(customAssetIDPrefix.count))
        return specimens.first { Self.assetName(for: $0) == assetName }
    }

    static func assetName(for specimen: AlienPlantMenuSpecimen) -> String {
        specimen.title
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? String(character) : "-"
            }
            .joined()
            .split(separator: "-")
            .joined(separator: "-")
    }

    static func customAssetID(for specimen: AlienPlantMenuSpecimen) -> String {
        "\(customAssetIDPrefix)\(assetName(for: specimen))"
    }

    static let customAssetIDPrefix = "alien-specimen-"

    static let specimens: [AlienPlantMenuSpecimen] = [
        AlienPlantMenuSpecimen(
            title: "Nebula Orchid",
            kind: .flower,
            promptSeed: "an elegant alien orchid with translucent nebula-colored petals, tiny star-like freckles, and thin cyan vascular lines"
        ),
        AlienPlantMenuSpecimen(
            title: "Ion Lily",
            kind: .flower,
            promptSeed: "a tall alien lily with ion-blue filaments, luminous pollen pods, and pearlescent curved petals"
        ),
        AlienPlantMenuSpecimen(
            title: "Pulsar Bloom",
            kind: .flower,
            promptSeed: "a radial alien bloom with concentric glowing petals, soft violet membranes, and a pulsing-looking central seed eye"
        ),
        AlienPlantMenuSpecimen(
            title: "Zero-G Glass Tulip",
            kind: .flower,
            promptSeed: "a glassy alien tulip with floating inner stamens, clear aqua petals, and a thin flexible chrome-green stem"
        ),
        AlienPlantMenuSpecimen(
            title: "Venusian Bellflower",
            kind: .flower,
            promptSeed: "a hanging alien bellflower with warm coral translucent bells, waxy tendrils, and glowing nectar beads"
        ),
        AlienPlantMenuSpecimen(
            title: "Saturn Ring Willow",
            kind: .tree,
            promptSeed: "a miniature alien willow with a ringed canopy like Saturn, drooping luminous strands, and a smooth pale trunk"
        ),
        AlienPlantMenuSpecimen(
            title: "Crater Bonsai",
            kind: .tree,
            promptSeed: "a tiny alien bonsai grown from crater stone, twisted black trunk, teal leaf clusters, and exposed mineral roots"
        ),
        AlienPlantMenuSpecimen(
            title: "Europa Coral Tree",
            kind: .tree,
            promptSeed: "a coral-like alien tree with branching ivory limbs, icy blue growth tips, and porous ocean-moon texture"
        ),
        AlienPlantMenuSpecimen(
            title: "Quasar Palm",
            kind: .tree,
            promptSeed: "a sculptural alien palm with metallic purple fronds, glowing rib veins, and a segmented silver trunk"
        ),
        AlienPlantMenuSpecimen(
            title: "Meteor Bark Cypress",
            kind: .tree,
            promptSeed: "a narrow alien cypress with meteor-black cracked bark, ember-red sap seams, and soft smoke-colored foliage"
        ),
        AlienPlantMenuSpecimen(
            title: "Plasma Fern",
            kind: .foliage,
            promptSeed: "a translucent alien fern with cyan plasma veins, layered fronds, and tiny floating seed nodules"
        ),
        AlienPlantMenuSpecimen(
            title: "Jellyleaf Monstera",
            kind: .foliage,
            promptSeed: "a lush alien monstera-like foliage plant with gelatinous emerald leaves, oval perforations, and faint internal glow"
        ),
        AlienPlantMenuSpecimen(
            title: "Chrome Spore Fan",
            kind: .foliage,
            promptSeed: "a fan-shaped alien foliage plant with chrome-edged leaves, velvet indigo surfaces, and soft spore pearls"
        ),
        AlienPlantMenuSpecimen(
            title: "Ganymede Ribbon Grass",
            kind: .foliage,
            promptSeed: "a ribboning alien grass cluster with long silver-green straps, blue undersides, and curled sensing tips"
        ),
        AlienPlantMenuSpecimen(
            title: "Telepathic Moss Fan",
            kind: .foliage,
            promptSeed: "a compact alien moss-fan hybrid with layered brain-coral folds, turquoise highlights, and soft fuzzy texture"
        ),
        AlienPlantMenuSpecimen(
            title: "Starlight Moss",
            kind: .meadow,
            promptSeed: "a low alien groundcover mat of dark velvet moss dotted with tiny starlight specks and a clean organic edge"
        ),
        AlienPlantMenuSpecimen(
            title: "Magnetic Clover",
            kind: .meadow,
            promptSeed: "a low alien clover patch with triangular iridescent leaves, tiny magnetic bead flowers, and dense creeping texture"
        ),
        AlienPlantMenuSpecimen(
            title: "Lunar Lichen Carpet",
            kind: .meadow,
            promptSeed: "a low lunar lichen carpet with pale blue crusts, silver fuzz, crater-like pores, and an irregular natural edge"
        ),
        AlienPlantMenuSpecimen(
            title: "Comet Tail Creeper",
            kind: .meadow,
            promptSeed: "a trailing alien groundcover with comet-tail tendrils, white glowing tips, and soft blue-green mats"
        ),
        AlienPlantMenuSpecimen(
            title: "Red Planet Puffcaps",
            kind: .meadow,
            promptSeed: "a small patch of alien puffcap fungi with dusty red caps, glowing pores, and clustered squat silhouettes"
        ),
        AlienPlantMenuSpecimen(
            title: "Moon Melon Vine",
            kind: .edible,
            promptSeed: "a productive alien vine with small moonlike melons, pale leaves, curling tendrils, and luminous fruit seams"
        ),
        AlienPlantMenuSpecimen(
            title: "Starfruit Pod Cluster",
            kind: .edible,
            promptSeed: "a compact alien crop plant with star-shaped edible pods, glossy blue leaves, and branching golden stems"
        ),
        AlienPlantMenuSpecimen(
            title: "Cosmic Pepper Bush",
            kind: .edible,
            promptSeed: "a bushy alien pepper plant with glossy black leaves and colorful galaxy-speckled hanging peppers"
        ),
        AlienPlantMenuSpecimen(
            title: "Asteroid Herb",
            kind: .edible,
            promptSeed: "a small alien herb cluster with mineral-gray stems, aromatic purple leaves, and tiny crystal seed heads"
        ),
        AlienPlantMenuSpecimen(
            title: "Glowberry Cane",
            kind: .edible,
            promptSeed: "a cane-like alien berry crop with translucent glowberries, segmented green-purple stems, and clean root base"
        )
    ]
}

@MainActor
enum GardenPlantSpecificMenuCatalog {
    static let categoryOrder: [PlantKind] = [.flower, .tree, .foliage, .meadow, .edible]

    static func entries(
        sceneKey: String?,
        assetLibrary: PlantAssetLibrary = .shared
    ) -> [GardenPlantSpecificMenuEntry] {
        let environment = GardenScenePlantEnvironment(sceneKey: sceneKey)
        return PlantSpecies.allCases.map { species in
            let isAssetAvailable = assetLibrary.hasDisplayableAsset(for: species)
            let suitability = environment.suitability(for: species)
            let disabledReasons = [
                isAssetAvailable ? nil : "\(species.displayName) needs high quality PNG growth assets",
                suitability.isSuitable ? nil : suitability.reason
            ].compactMap { $0 }

            return GardenPlantSpecificMenuEntry(
                species: species,
                isAssetAvailable: isAssetAvailable,
                isSceneSuitable: suitability.isSuitable,
                disabledReason: disabledReasons.isEmpty ? nil : disabledReasons.joined(separator: " - ")
            )
        }
    }

    static func entries(
        sceneKey: String?,
        in kind: PlantKind,
        assetLibrary: PlantAssetLibrary = .shared
    ) -> [GardenPlantSpecificMenuEntry] {
        entries(sceneKey: sceneKey, assetLibrary: assetLibrary)
            .filter { $0.species.kind == kind }
            .sorted { $0.species.displayName < $1.species.displayName }
    }

    static func roomStudioIndoorEntries(
        sceneKey: String?,
        assetLibrary: PlantAssetLibrary = .shared
    ) -> [GardenPlantSpecificMenuEntry] {
        let indoorSpecies = Set(PlantSpecies.roomStudioIndoorSpecies)
        return entries(sceneKey: sceneKey, assetLibrary: assetLibrary)
            .filter { indoorSpecies.contains($0.species) }
            .sorted { left, right in
                guard let leftIndex = PlantSpecies.roomStudioIndoorSpecies.firstIndex(of: left.species),
                      let rightIndex = PlantSpecies.roomStudioIndoorSpecies.firstIndex(of: right.species) else {
                    return left.species.displayName < right.species.displayName
                }

                return leftIndex < rightIndex
            }
    }

    static func rainforestEntries(
        in kind: PlantKind,
        assetLibrary: PlantAssetLibrary = .shared
    ) -> [GardenPlantSpecificMenuEntry] {
        let rainforestSpecies = PlantSpecies.rainforestSpecies
        return rainforestSpecies
            .filter { $0.kind == kind }
            .map { species in
                let isAssetAvailable = assetLibrary.hasDisplayableAsset(for: species)
                return GardenPlantSpecificMenuEntry(
                    species: species,
                    isAssetAvailable: isAssetAvailable,
                    isSceneSuitable: true,
                    disabledReason: isAssetAvailable ? nil : "\(species.displayName) needs high quality PNG growth assets"
                )
            }
            .sorted { left, right in
                guard let leftIndex = rainforestSpecies.firstIndex(of: left.species),
                      let rightIndex = rainforestSpecies.firstIndex(of: right.species) else {
                    return left.species.displayName < right.species.displayName
                }

                return leftIndex < rightIndex
            }
    }

    static func enabledRainforestSpecies(
        in kind: PlantKind,
        assetLibrary: PlantAssetLibrary = .shared
    ) -> [PlantSpecies] {
        rainforestEntries(in: kind, assetLibrary: assetLibrary).compactMap { entry in
            entry.isEnabled ? entry.species : nil
        }
    }

    static func enabledSpecies(
        sceneKey: String?,
        in kind: PlantKind? = nil,
        assetLibrary: PlantAssetLibrary = .shared
    ) -> [PlantSpecies] {
        entries(sceneKey: sceneKey, assetLibrary: assetLibrary).compactMap { entry in
            if let kind, entry.species.kind != kind {
                return nil
            }

            return entry.isEnabled ? entry.species : nil
        }
    }

    static func enabledRoomStudioIndoorSpecies(
        sceneKey: String?,
        assetLibrary: PlantAssetLibrary = .shared
    ) -> [PlantSpecies] {
        roomStudioIndoorEntries(sceneKey: sceneKey, assetLibrary: assetLibrary).compactMap { entry in
            entry.isEnabled ? entry.species : nil
        }
    }

    static func hasEnabledSpecies(
        sceneKey: String?,
        in kind: PlantKind,
        assetLibrary: PlantAssetLibrary = .shared
    ) -> Bool {
        !enabledSpecies(sceneKey: sceneKey, in: kind, assetLibrary: assetLibrary).isEmpty
    }
}
