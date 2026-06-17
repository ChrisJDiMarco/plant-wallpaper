import Foundation
import PlantGardenCore

enum GardenWallpaperScene: String, CaseIterable {
    case emptyConservatoryHall = "empty-conservatory-hall"
    case enclosedGravelCourtyard = "enclosed-gravel-courtyard"
    case rooftopSeedHouse = "rooftop-seed-house"
    case emptyDesertarium = "empty-desertarium"
    case moonlitEmptyGlasshouse = "moonlit-empty-glasshouse"
    case emptyWaterPavilion = "empty-water-pavilion"
    case victorianSeedGallery = "victorian-seed-gallery"
    case coastalPlantingTerrace = "coastal-planting-terrace"
    case cozyApartmentStudio = "cozy-apartment-studio"
    case cottageBackyardGarden = "cottage-backyard-garden"
    case chineseMountainMonkGarden = "chinese-mountain-monk-garden"
    case swedishPatioGarden = "swedish-patio-garden"
    case brazilianRooftopGarden = "brazilian-rooftop-garden"
    case ancientEgyptianEstateGarden = "ancient-egyptian-estate-garden"
    case texasRusticGarden = "texas-rustic-garden"
    case starshipCommandBridge = "starship-command-bridge"
    case roomModernBedroomCanvas = "room-modern-bedroom-canvas"
    case roomLoftHangoutCanvas = "room-loft-hangout-canvas"
    case roomMediaDenCanvas = "room-media-den-canvas"
    case alienCraterGreenhouse = "alien-crater-greenhouse"
    case orbitalUfoTerrarium = "orbital-ufo-terrarium"
    case bioluminescentExoplanetOasis = "bioluminescent-exoplanet-oasis"
    case martianHydroponicDome = "martian-hydroponic-dome"
    case alienCraterDome = "alien-crater-dome"
    case alienCliffsideHomeGarden = "alien-cliffside-home-garden"
    case alienCivicParkPlaza = "alien-civic-park-plaza"
    case alienStarshipBotanyBay = "alien-starship-botany-bay"
    case alienFloatingIslandSanctuary = "alien-floating-island-sanctuary"

    static let defaultScene: GardenWallpaperScene = .emptyConservatoryHall
    static let defaultRoomStudioScene: GardenWallpaperScene = .roomModernBedroomCanvas
    static let defaultAlienUFOScene: GardenWallpaperScene = .alienCraterDome

    static func canonicalKey(for key: String) -> String {
        switch key {
        case "moonlit-glasshouse":
            moonlitEmptyGlasshouse.rawValue
        default:
            key
        }
    }

    static func scene(forKey key: String) -> GardenWallpaperScene? {
        GardenWallpaperScene(rawValue: canonicalKey(for: key))
    }

    static func scenes(for mode: GardenExperienceMode) -> [GardenWallpaperScene] {
        allCases.filter { $0.experienceMode == mode }
    }

    static func selectableScenes(for mode: GardenExperienceMode) -> [GardenWallpaperScene] {
        scenes(for: mode).filter(\.isSelectableScene)
    }

    var experienceMode: GardenExperienceMode {
        switch self {
        case .roomModernBedroomCanvas, .roomLoftHangoutCanvas, .roomMediaDenCanvas:
            .roomStudio
        case .alienCraterGreenhouse,
             .orbitalUfoTerrarium,
             .bioluminescentExoplanetOasis,
             .martianHydroponicDome,
             .alienCraterDome,
             .alienCliffsideHomeGarden,
             .alienCivicParkPlaza,
             .alienStarshipBotanyBay,
             .alienFloatingIslandSanctuary:
            .alienUFO
        default:
            .garden
        }
    }

    var displayName: String {
        switch self {
        case .emptyConservatoryHall:
            "Empty Conservatory Hall"
        case .enclosedGravelCourtyard:
            "Enclosed Gravel Courtyard"
        case .rooftopSeedHouse:
            "Rooftop Seed House"
        case .emptyDesertarium:
            "Empty Desertarium"
        case .moonlitEmptyGlasshouse:
            "Moonlit Empty Glasshouse"
        case .emptyWaterPavilion:
            "Empty Water Pavilion"
        case .victorianSeedGallery:
            "Victorian Seed Gallery"
        case .coastalPlantingTerrace:
            "Coastal Planting Terrace"
        case .cozyApartmentStudio:
            "Cozy Apartment Studio"
        case .cottageBackyardGarden:
            "Cottage Backyard Garden"
        case .chineseMountainMonkGarden:
            "Chinese Mountain Monk Garden"
        case .swedishPatioGarden:
            "Swedish Patio Garden"
        case .brazilianRooftopGarden:
            "Brazilian Rooftop Garden"
        case .ancientEgyptianEstateGarden:
            "Ancient Egyptian Estate Garden"
        case .texasRusticGarden:
            "Texas Rustic Garden"
        case .starshipCommandBridge:
            "Starship Command Bridge"
        case .roomModernBedroomCanvas:
            "Modern Bedroom Canvas"
        case .roomLoftHangoutCanvas:
            "Loft Hangout Canvas"
        case .roomMediaDenCanvas:
            "Media Den Canvas"
        case .alienCraterGreenhouse:
            "Alien Crater Greenhouse"
        case .orbitalUfoTerrarium:
            "Orbital UFO Terrarium"
        case .bioluminescentExoplanetOasis:
            "Bioluminescent Exoplanet Oasis"
        case .martianHydroponicDome:
            "Martian Hydroponic Dome"
        case .alienCraterDome:
            "Alien Crater Dome"
        case .alienCliffsideHomeGarden:
            "Alien Cliffside Home Garden"
        case .alienCivicParkPlaza:
            "Alien Civic Park Plaza"
        case .alienStarshipBotanyBay:
            "Alien Starship Botany Bay"
        case .alienFloatingIslandSanctuary:
            "Alien Floating Island Sanctuary"
        }
    }

    var symbolName: String {
        switch self {
        case .emptyConservatoryHall:
            "building.columns.fill"
        case .enclosedGravelCourtyard:
            "circle.grid.cross.fill"
        case .rooftopSeedHouse:
            "building.2.fill"
        case .emptyDesertarium:
            "sun.max.fill"
        case .moonlitEmptyGlasshouse:
            "moon.stars.fill"
        case .emptyWaterPavilion:
            "water.waves"
        case .victorianSeedGallery:
            "archivebox.fill"
        case .coastalPlantingTerrace:
            "water.waves"
        case .cozyApartmentStudio:
            "sofa.fill"
        case .cottageBackyardGarden:
            "house.fill"
        case .chineseMountainMonkGarden:
            "mountain.2.fill"
        case .swedishPatioGarden:
            "sun.max.fill"
        case .brazilianRooftopGarden:
            "building.2.fill"
        case .ancientEgyptianEstateGarden:
            "building.columns.fill"
        case .texasRusticGarden:
            "house.fill"
        case .starshipCommandBridge:
            "sparkles"
        case .roomModernBedroomCanvas:
            "bed.double.fill"
        case .roomLoftHangoutCanvas:
            "sofa.fill"
        case .roomMediaDenCanvas:
            "play.tv.fill"
        case .alienCraterGreenhouse:
            "sparkles"
        case .orbitalUfoTerrarium:
            "circle.dotted"
        case .bioluminescentExoplanetOasis:
            "moon.stars.fill"
        case .martianHydroponicDome:
            "globe.americas.fill"
        case .alienCraterDome:
            "moon.stars.fill"
        case .alienCliffsideHomeGarden:
            "house.and.flag.fill"
        case .alienCivicParkPlaza:
            "circle.hexagongrid.fill"
        case .alienStarshipBotanyBay:
            "sparkles"
        case .alienFloatingIslandSanctuary:
            "cloud.fill"
        }
    }

    var isSelectableScene: Bool {
        hasBundledPNGArtwork && unavailableSceneReason == nil
    }

    var unavailableSceneReason: String? {
        switch self {
        case .alienCraterGreenhouse,
             .orbitalUfoTerrarium,
             .bioluminescentExoplanetOasis,
             .martianHydroponicDome:
            "Final PNG scene artwork is coming soon"
        default:
            hasBundledPNGArtwork ? nil : "Bundled PNG scene artwork is missing"
        }
    }

    private var hasBundledPNGArtwork: Bool {
        if Bundle.appResources.url(
            forResource: rawValue,
            withExtension: "png",
            subdirectory: "SceneAssets"
        ) != nil {
            return true
        }

        let sourceTreeURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/SceneAssets/\(rawValue).png")
        return FileManager.default.fileExists(atPath: sourceTreeURL.path)
    }
}

enum GardenSceneDayCyclePhase: String, CaseIterable {
    case sunrise
    case morning
    case midday
    case afternoon
    case goldenHour = "golden-hour"
    case night

    init(date: Date, calendar: Calendar = .current) {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<8:
            self = .sunrise
        case 8..<11:
            self = .morning
        case 11..<15:
            self = .midday
        case 15..<18:
            self = .afternoon
        case 18..<21:
            self = .goldenHour
        default:
            self = .night
        }
    }

    var displayName: String {
        switch self {
        case .sunrise:
            "Sunrise"
        case .morning:
            "Morning"
        case .midday:
            "Midday"
        case .afternoon:
            "Afternoon"
        case .goldenHour:
            "Golden Hour"
        case .night:
            "Night"
        }
    }
}

extension GardenWallpaperScene {
    var hasDayCycleArtwork: Bool {
        self == .brazilianRooftopGarden
    }

    func dayCycleAssetName(for phase: GardenSceneDayCyclePhase) -> String? {
        guard hasDayCycleArtwork else {
            return nil
        }

        return "\(rawValue)-\(phase.rawValue)"
    }
}
