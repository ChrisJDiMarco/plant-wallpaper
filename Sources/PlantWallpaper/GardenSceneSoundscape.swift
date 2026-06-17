import Foundation

struct GardenSceneSoundscape: Equatable {
    struct BirdProfile: Equatable {
        var description: String
        var presence: Double
        var pitch: Double
        var density: Double
        var brightness: Double
    }

    struct InsectProfile: Equatable {
        var description: String
        var nightPresence: Double
        var pitch: Double
        var cicadaPresence: Double
    }

    struct PlaceBed: Equatable {
        var description: String
        var windExposure: Double
        var leafRustle: Double
        var water: Double
        var urbanMurmur: Double
        var roomTone: Double
        var chimes: Double
        var smallWildlife: Double
        var roomLife: Double
        var electronics: Double
        var alienFauna: Double
        var habitatHum: Double
        var crystallineShimmer: Double
        var lowRumble: Double

        init(
            description: String,
            windExposure: Double,
            leafRustle: Double,
            water: Double,
            urbanMurmur: Double,
            roomTone: Double,
            chimes: Double,
            smallWildlife: Double = 0,
            roomLife: Double = 0,
            electronics: Double = 0,
            alienFauna: Double = 0,
            habitatHum: Double = 0,
            crystallineShimmer: Double = 0,
            lowRumble: Double = 0
        ) {
            self.description = description
            self.windExposure = windExposure
            self.leafRustle = leafRustle
            self.water = water
            self.urbanMurmur = urbanMurmur
            self.roomTone = roomTone
            self.chimes = chimes
            self.smallWildlife = smallWildlife
            self.roomLife = roomLife
            self.electronics = electronics
            self.alienFauna = alienFauna
            self.habitatHum = habitatHum
            self.crystallineShimmer = crystallineShimmer
            self.lowRumble = lowRumble
        }
    }

    var sceneKey: String
    var displayName: String
    var birds: BirdProfile
    var insects: InsectProfile
    var place: PlaceBed

    init(
        sceneKey: String,
        displayName: String,
        birds: BirdProfile,
        insects: InsectProfile,
        place: PlaceBed
    ) {
        self.sceneKey = sceneKey
        self.displayName = displayName
        self.birds = birds
        self.insects = insects
        self.place = place
    }

    init(sceneKey: String?) {
        let canonicalKey = sceneKey.map(GardenWallpaperScene.canonicalKey(for:))
            ?? GardenWallpaperScene.defaultScene.rawValue
        if let scene = GardenWallpaperScene.scene(forKey: canonicalKey) {
            self = Self.profile(for: scene)
        } else {
            self = Self.customProfile(for: canonicalKey)
        }
    }

    static func profile(for scene: GardenWallpaperScene) -> GardenSceneSoundscape {
        switch scene {
        case .emptyConservatoryHall:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "distant garden sparrows filtered through glass",
                    presence: 0.45,
                    pitch: 1.04,
                    density: 0.75,
                    brightness: 0.70
                ),
                insects: .init(
                    description: "barely audible night crickets outside the panes",
                    nightPresence: 0.32,
                    pitch: 0.92,
                    cicadaPresence: 0
                ),
                place: .init(
                    description: "soft glasshouse air and faint room resonance",
                    windExposure: 0.45,
                    leafRustle: 0.18,
                    water: 0,
                    urbanMurmur: 0,
                    roomTone: 0.42,
                    chimes: 0,
                    roomLife: 0.16,
                    crystallineShimmer: 0.05
                )
            )
        case .enclosedGravelCourtyard:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "small courtyard birds with short reflected chirps",
                    presence: 0.62,
                    pitch: 1.10,
                    density: 0.90,
                    brightness: 0.86
                ),
                insects: .init(
                    description: "dry wall crickets tucked into the courtyard edges",
                    nightPresence: 0.58,
                    pitch: 1.04,
                    cicadaPresence: 0.06
                ),
                place: .init(
                    description: "warm air moving over gravel and plaster walls",
                    windExposure: 0.52,
                    leafRustle: 0.10,
                    water: 0,
                    urbanMurmur: 0.06,
                    roomTone: 0.12,
                    chimes: 0,
                    smallWildlife: 0.18
                )
            )
        case .rooftopSeedHouse:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "high swifts and city sparrows over a roofline",
                    presence: 0.78,
                    pitch: 1.22,
                    density: 1.18,
                    brightness: 0.98
                ),
                insects: .init(
                    description: "light rooftop crickets after the city cools",
                    nightPresence: 0.35,
                    pitch: 1.10,
                    cicadaPresence: 0
                ),
                place: .init(
                    description: "distant traffic below, wind around railings",
                    windExposure: 0.90,
                    leafRustle: 0.16,
                    water: 0,
                    urbanMurmur: 0.46,
                    roomTone: 0,
                    chimes: 0,
                    smallWildlife: 0.12,
                    electronics: 0.04
                )
            )
        case .emptyDesertarium:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "sparse desert finch calls in dry open air",
                    presence: 0.28,
                    pitch: 1.18,
                    density: 0.45,
                    brightness: 1.0
                ),
                insects: .init(
                    description: "dry cicadas and a thin night cricket bed",
                    nightPresence: 0.40,
                    pitch: 1.18,
                    cicadaPresence: 0.38
                ),
                place: .init(
                    description: "dry wind and warm glass resonance",
                    windExposure: 1.0,
                    leafRustle: 0.03,
                    water: 0,
                    urbanMurmur: 0,
                    roomTone: 0.10,
                    chimes: 0,
                    smallWildlife: 0.20,
                    crystallineShimmer: 0.02
                )
            )
        case .moonlitEmptyGlasshouse:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "almost no daytime birds, just a distant soft call",
                    presence: 0.20,
                    pitch: 0.92,
                    density: 0.35,
                    brightness: 0.48
                ),
                insects: .init(
                    description: "cool glasshouse crickets and nocturnal ticks",
                    nightPresence: 0.86,
                    pitch: 0.90,
                    cicadaPresence: 0.02
                ),
                place: .init(
                    description: "cool pane resonance and still night air",
                    windExposure: 0.32,
                    leafRustle: 0.08,
                    water: 0,
                    urbanMurmur: 0,
                    roomTone: 0.55,
                    chimes: 0,
                    smallWildlife: 0.10,
                    roomLife: 0.12,
                    crystallineShimmer: 0.10
                )
            )
        case .emptyWaterPavilion:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "water birds and soft reedside chirps",
                    presence: 0.74,
                    pitch: 0.96,
                    density: 0.82,
                    brightness: 0.72
                ),
                insects: .init(
                    description: "humid crickets near water after dusk",
                    nightPresence: 0.72,
                    pitch: 0.96,
                    cicadaPresence: 0.08
                ),
                place: .init(
                    description: "gentle water lap and reed movement",
                    windExposure: 0.58,
                    leafRustle: 0.26,
                    water: 0.72,
                    urbanMurmur: 0,
                    roomTone: 0,
                    chimes: 0,
                    smallWildlife: 0.24,
                    crystallineShimmer: 0.02
                )
            )
        case .victorianSeedGallery:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "polite garden birds softened by old glass",
                    presence: 0.50,
                    pitch: 1.02,
                    density: 0.72,
                    brightness: 0.62
                ),
                insects: .init(
                    description: "tiny crickets beyond the gallery doors",
                    nightPresence: 0.30,
                    pitch: 0.94,
                    cicadaPresence: 0
                ),
                place: .init(
                    description: "subtle indoor glass and timber resonance",
                    windExposure: 0.38,
                    leafRustle: 0.12,
                    water: 0,
                    urbanMurmur: 0,
                    roomTone: 0.48,
                    chimes: 0.03,
                    roomLife: 0.20,
                    crystallineShimmer: 0.07
                )
            )
        case .coastalPlantingTerrace:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "gulls far off with terrace sparrows nearby",
                    presence: 0.70,
                    pitch: 0.88,
                    density: 0.78,
                    brightness: 0.82
                ),
                insects: .init(
                    description: "light coastal crickets under breezy stone",
                    nightPresence: 0.44,
                    pitch: 1.00,
                    cicadaPresence: 0.05
                ),
                place: .init(
                    description: "salt air, terrace wind, and distant surf",
                    windExposure: 1.0,
                    leafRustle: 0.24,
                    water: 0.42,
                    urbanMurmur: 0.04,
                    roomTone: 0,
                    chimes: 0,
                    smallWildlife: 0.16
                )
            )
        case .cozyApartmentStudio:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "muffled window birds from outside the apartment",
                    presence: 0.26,
                    pitch: 1.05,
                    density: 0.46,
                    brightness: 0.46
                ),
                insects: .init(
                    description: "almost no insects indoors",
                    nightPresence: 0.08,
                    pitch: 0.92,
                    cicadaPresence: 0
                ),
                place: .init(
                    description: "warm apartment room tone and distant street hush",
                    windExposure: 0.14,
                    leafRustle: 0.04,
                    water: 0,
                    urbanMurmur: 0.28,
                    roomTone: 0.50,
                    chimes: 0,
                    smallWildlife: 0.02,
                    roomLife: 0.26,
                    electronics: 0.12
                )
            )
        case .cottageBackyardGarden:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "robins, finches, and backyard sparrows",
                    presence: 0.92,
                    pitch: 1.03,
                    density: 1.08,
                    brightness: 0.90
                ),
                insects: .init(
                    description: "healthy suburban crickets at night",
                    nightPresence: 0.68,
                    pitch: 0.98,
                    cicadaPresence: 0.10
                ),
                place: .init(
                    description: "leaf rustle, fence breeze, and quiet yard air",
                    windExposure: 0.66,
                    leafRustle: 0.50,
                    water: 0,
                    urbanMurmur: 0.08,
                    roomTone: 0,
                    chimes: 0,
                    smallWildlife: 0.34
                )
            )
        case .chineseMountainMonkGarden:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "mountain thrushes and clear high-altitude songbirds",
                    presence: 0.76,
                    pitch: 1.08,
                    density: 0.74,
                    brightness: 0.92
                ),
                insects: .init(
                    description: "thin mountain crickets in the cool evening",
                    nightPresence: 0.46,
                    pitch: 1.02,
                    cicadaPresence: 0.04
                ),
                place: .init(
                    description: "pine wind and a very occasional temple bell",
                    windExposure: 0.84,
                    leafRustle: 0.40,
                    water: 0.10,
                    urbanMurmur: 0,
                    roomTone: 0,
                    chimes: 0.18,
                    smallWildlife: 0.22,
                    crystallineShimmer: 0.06
                )
            )
        case .swedishPatioGarden:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "northern tits, blackbirds, and soft patio sparrows",
                    presence: 0.82,
                    pitch: 1.00,
                    density: 0.92,
                    brightness: 0.78
                ),
                insects: .init(
                    description: "cool northern evening crickets, subtle and dry",
                    nightPresence: 0.40,
                    pitch: 0.90,
                    cicadaPresence: 0
                ),
                place: .init(
                    description: "birch leaves, patio air, and quiet neighborhood distance",
                    windExposure: 0.68,
                    leafRustle: 0.44,
                    water: 0,
                    urbanMurmur: 0.10,
                    roomTone: 0,
                    chimes: 0,
                    smallWildlife: 0.20
                )
            )
        case .brazilianRooftopGarden:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "tropical city birds, swifts, and bright rooftop calls",
                    presence: 0.95,
                    pitch: 1.24,
                    density: 1.22,
                    brightness: 1.0
                ),
                insects: .init(
                    description: "warm urban cicadas and lively night insects",
                    nightPresence: 0.74,
                    pitch: 1.16,
                    cicadaPresence: 0.46
                ),
                place: .init(
                    description: "distant Brazilian traffic, rooftop wind, warm city air",
                    windExposure: 0.96,
                    leafRustle: 0.28,
                    water: 0,
                    urbanMurmur: 0.58,
                    roomTone: 0,
                    chimes: 0,
                    smallWildlife: 0.24,
                    electronics: 0.04
                )
            )
        case .ancientEgyptianEstateGarden:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "ibis-like water calls and warm garden finches",
                    presence: 0.64,
                    pitch: 0.86,
                    density: 0.62,
                    brightness: 0.78
                ),
                insects: .init(
                    description: "dry Nile-side cicadas and night crickets",
                    nightPresence: 0.62,
                    pitch: 1.08,
                    cicadaPresence: 0.32
                ),
                place: .init(
                    description: "courtyard heat, shallow water, and stone stillness",
                    windExposure: 0.58,
                    leafRustle: 0.18,
                    water: 0.28,
                    urbanMurmur: 0,
                    roomTone: 0.08,
                    chimes: 0.04,
                    smallWildlife: 0.18,
                    crystallineShimmer: 0.03
                )
            )
        case .texasRusticGarden:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "cardinals, mockingbirds, and open-yard calls",
                    presence: 0.84,
                    pitch: 1.02,
                    density: 0.90,
                    brightness: 0.92
                ),
                insects: .init(
                    description: "hot-weather cicadas by day and strong crickets at night",
                    nightPresence: 0.82,
                    pitch: 1.12,
                    cicadaPresence: 0.52
                ),
                place: .init(
                    description: "dry breeze, distant rural road, and rough timber air",
                    windExposure: 0.88,
                    leafRustle: 0.22,
                    water: 0,
                    urbanMurmur: 0.18,
                    roomTone: 0,
                    chimes: 0,
                    smallWildlife: 0.36
                )
            )
        case .starshipCommandBridge:
            GardenSceneSoundscape(
                sceneKey: scene.rawValue,
                displayName: scene.displayName,
                birds: .init(
                    description: "no birds on the bridge, just a faint imagined arboretum feed",
                    presence: 0.06,
                    pitch: 0.82,
                    density: 0.16,
                    brightness: 0.24
                ),
                insects: .init(
                    description: "almost no insects indoors, only a soft greenhouse life-support shimmer",
                    nightPresence: 0.04,
                    pitch: 0.78,
                    cicadaPresence: 0
                ),
                place: .init(
                    description: "quiet starship room tone, distant console hum, and hydroponic air circulation",
                    windExposure: 0.04,
                    leafRustle: 0.02,
                    water: 0,
                    urbanMurmur: 0,
                    roomTone: 0.72,
                    chimes: 0.06,
                    roomLife: 0.08,
                    electronics: 0.44,
                    alienFauna: 0.08,
                    habitatHum: 0.72,
                    crystallineShimmer: 0.12,
                    lowRumble: 0.24
                )
            )
        case .roomModernBedroomCanvas:
            quietIndoorRoomSoundscape(
                scene: scene,
                birdDescription: "muffled city sparrows beyond the bedroom window",
                placeDescription: "soft apartment room tone, distant street hush, and warm wood resonance",
                urbanMurmur: 0.24,
                roomTone: 0.58,
                roomLife: 0.34,
                electronics: 0.18
            )
        case .roomLoftHangoutCanvas:
            quietIndoorRoomSoundscape(
                scene: scene,
                birdDescription: "distant rooftop birds filtered through loft windows",
                placeDescription: "loft room tone, softened city traffic, concrete reflections, and faint HVAC air",
                urbanMurmur: 0.36,
                roomTone: 0.46,
                roomLife: 0.28,
                electronics: 0.24,
                lowRumble: 0.04
            )
        case .roomMediaDenCanvas:
            quietIndoorRoomSoundscape(
                scene: scene,
                birdDescription: "barely audible evening birds outside the den",
                placeDescription: "low cozy room tone, insulated walls, and quiet media-room air",
                urbanMurmur: 0.08,
                roomTone: 0.64,
                roomLife: 0.34,
                electronics: 0.58,
                lowRumble: 0.06
            )
        case .alienCraterGreenhouse:
            alienSoundscape(
                scene: scene,
                birdDescription: "no Earth birds, only tiny greenhouse exo-trills in recycled air",
                insectDescription: "glassy wing ticks and soft bioluminescent night pulses",
                placeDescription: "sealed crater greenhouse air, hydroponic mist, and dome machinery",
                water: 0.18,
                alienFauna: 0.58,
                habitatHum: 0.64,
                crystallineShimmer: 0.16,
                lowRumble: 0.14
            )
        case .orbitalUfoTerrarium:
            alienSoundscape(
                scene: scene,
                birdDescription: "micro exo-aviary chirps suspended inside a quiet craft",
                insectDescription: "tiny terrarium trills and silver wing taps",
                placeDescription: "orbital craft hum, glass terrarium resonance, and distant starfield hush",
                water: 0.10,
                alienFauna: 0.48,
                habitatHum: 0.78,
                crystallineShimmer: 0.26,
                lowRumble: 0.20
            )
        case .bioluminescentExoplanetOasis:
            alienSoundscape(
                scene: scene,
                birdDescription: "distant melodic exo-fauna calls from luminous oasis reeds",
                insectDescription: "lush night pulses, soft wing glass, and low glowing insect drones",
                placeDescription: "wet exoplanet air, glowing water, and distant crystalline fauna",
                water: 0.42,
                alienFauna: 0.86,
                habitatHum: 0.26,
                crystallineShimmer: 0.32,
                lowRumble: 0.10
            )
        case .martianHydroponicDome:
            alienSoundscape(
                scene: scene,
                birdDescription: "no birds, just clipped hydroponic status chirps",
                insectDescription: "rare dome-contained pollinator ticks in thin air",
                placeDescription: "Mars dome ventilation, nutrient-water trickle, and filtered outside wind",
                water: 0.22,
                alienFauna: 0.34,
                habitatHum: 0.74,
                crystallineShimmer: 0.10,
                lowRumble: 0.22
            )
        case .alienCraterDome:
            alienSoundscape(
                scene: scene,
                birdDescription: "soft synthetic exo-aviary chirps from the crater habitat system",
                insectDescription: "low night trills and dome-wall wing ticks",
                placeDescription: "crater dome pressure hum, far cosmic wind, and crystalline structural shimmer",
                water: 0.08,
                alienFauna: 0.52,
                habitatHum: 0.70,
                crystallineShimmer: 0.24,
                lowRumble: 0.24
            )
        case .alienCliffsideHomeGarden:
            alienSoundscape(
                scene: scene,
                birdDescription: "windborne exo-bird calls echoing below a cliffside home",
                insectDescription: "thin cliff insects and light magnetic-wing ticks",
                placeDescription: "cliff updrafts, habitat vents, and distant alien valley resonance",
                water: 0.08,
                alienFauna: 0.64,
                habitatHum: 0.44,
                crystallineShimmer: 0.18,
                lowRumble: 0.12
            )
        case .alienCivicParkPlaza:
            alienSoundscape(
                scene: scene,
                birdDescription: "small municipal exo-aviary chirps around a civic park",
                insectDescription: "polite plaza pollinator ticks and low glowing insect beds",
                placeDescription: "alien park ambience, distant transit hush, soft civic machinery, and plaza air",
                water: 0.14,
                alienFauna: 0.62,
                habitatHum: 0.42,
                crystallineShimmer: 0.20,
                lowRumble: 0.10,
                urbanMurmur: 0.16
            )
        case .alienStarshipBotanyBay:
            alienSoundscape(
                scene: scene,
                birdDescription: "botany-bay exo chirps generated by environmental control",
                insectDescription: "contained pollinator ticks, tiny bio-sensor pulses, and glassy night trills",
                placeDescription: "starship life-support, botany-bay pumps, and deep hull resonance",
                water: 0.20,
                alienFauna: 0.46,
                habitatHum: 0.86,
                crystallineShimmer: 0.18,
                lowRumble: 0.34,
                electronics: 0.42
            )
        case .alienFloatingIslandSanctuary:
            alienSoundscape(
                scene: scene,
                birdDescription: "distant airborne exo-fauna circling a floating sanctuary",
                insectDescription: "soft floating-island wing ticks and luminous dusk trills",
                placeDescription: "high alien air, levitation-field hum, and crystalline sky shimmer",
                water: 0.12,
                alienFauna: 0.74,
                habitatHum: 0.36,
                crystallineShimmer: 0.34,
                lowRumble: 0.12
            )
        }
    }

    private static func quietIndoorRoomSoundscape(
        scene: GardenWallpaperScene,
        birdDescription: String,
        placeDescription: String,
        urbanMurmur: Double,
        roomTone: Double,
        roomLife: Double,
        electronics: Double,
        lowRumble: Double = 0
    ) -> GardenSceneSoundscape {
        GardenSceneSoundscape(
            sceneKey: scene.rawValue,
            displayName: scene.displayName,
            birds: .init(
                description: birdDescription,
                presence: 0.12,
                pitch: 0.92,
                density: 0.22,
                brightness: 0.30
            ),
            insects: .init(
                description: "almost no insects indoors, just a faint outside night bed",
                nightPresence: 0.04,
                pitch: 0.82,
                cicadaPresence: 0
            ),
            place: .init(
                description: placeDescription,
                windExposure: 0.05,
                leafRustle: 0,
                water: 0,
                urbanMurmur: urbanMurmur,
                roomTone: roomTone,
                chimes: 0,
                roomLife: roomLife,
                electronics: electronics,
                lowRumble: lowRumble
            )
        )
    }

    private static func alienSoundscape(
        scene: GardenWallpaperScene,
        birdDescription: String,
        insectDescription: String,
        placeDescription: String,
        water: Double,
        alienFauna: Double,
        habitatHum: Double,
        crystallineShimmer: Double,
        lowRumble: Double,
        urbanMurmur: Double = 0,
        electronics: Double = 0.18
    ) -> GardenSceneSoundscape {
        GardenSceneSoundscape(
            sceneKey: scene.rawValue,
            displayName: scene.displayName,
            birds: .init(
                description: birdDescription,
                presence: 0.12,
                pitch: 0.72,
                density: 0.24,
                brightness: 0.36
            ),
            insects: .init(
                description: insectDescription,
                nightPresence: 0.48,
                pitch: 0.68,
                cicadaPresence: 0.08
            ),
            place: .init(
                description: placeDescription,
                windExposure: 0.28,
                leafRustle: 0.08,
                water: water,
                urbanMurmur: urbanMurmur,
                roomTone: 0.42,
                chimes: 0.10,
                electronics: electronics,
                alienFauna: alienFauna,
                habitatHum: habitatHum,
                crystallineShimmer: crystallineShimmer,
                lowRumble: lowRumble
            )
        )
    }

    private static func customProfile(for key: String) -> GardenSceneSoundscape {
        let lowercased = key.lowercased()
        let isIndoor = lowercased.contains("indoor") || lowercased.contains("studio")
            || lowercased.contains("room") || lowercased.contains("hall")
        let isWater = lowercased.contains("pond") || lowercased.contains("water")
            || lowercased.contains("coastal") || lowercased.contains("terrace")
        let isUrban = lowercased.contains("city") || lowercased.contains("roof")
            || lowercased.contains("apartment")
        let isAlien = lowercased.contains("alien") || lowercased.contains("ufo")
            || lowercased.contains("orbital") || lowercased.contains("martian")
            || lowercased.contains("exoplanet") || lowercased.contains("starship")

        return GardenSceneSoundscape(
            sceneKey: key,
            displayName: "Custom Scene",
            birds: .init(
                description: isAlien
                    ? "soft speculative exo-aviary chirps"
                    : (isIndoor ? "muffled birds beyond the windows" : "general garden birds"),
                presence: isAlien ? 0.12 : (isIndoor ? 0.30 : 0.72),
                pitch: isAlien ? 0.72 : (isWater ? 0.95 : 1.0),
                density: isAlien ? 0.22 : (isIndoor ? 0.48 : 0.86),
                brightness: isAlien ? 0.34 : (isIndoor ? 0.46 : 0.82)
            ),
            insects: .init(
                description: isAlien
                    ? "glassy alien night trills and bioluminescent ticks"
                    : (isIndoor ? "subtle insects outside" : "garden crickets"),
                nightPresence: isAlien ? 0.42 : (isIndoor ? 0.16 : 0.56),
                pitch: isAlien ? 0.70 : 1.0,
                cicadaPresence: isAlien ? 0.08 : (lowercased.contains("desert") ? 0.34 : 0.08)
            ),
            place: .init(
                description: isAlien
                    ? "sealed habitat hum, strange fauna, and crystalline atmosphere"
                    : (isIndoor ? "room tone and softened outside air" : "open garden air"),
                windExposure: isAlien ? 0.28 : (isIndoor ? 0.25 : 0.64),
                leafRustle: isAlien ? 0.06 : (isIndoor ? 0.08 : 0.28),
                water: isWater ? 0.38 : 0,
                urbanMurmur: isUrban ? 0.34 : 0.04,
                roomTone: isAlien ? 0.36 : (isIndoor ? 0.42 : 0),
                chimes: 0,
                smallWildlife: isIndoor || isAlien ? 0.04 : 0.18,
                roomLife: isIndoor ? 0.24 : 0,
                electronics: isIndoor ? 0.14 : (isAlien ? 0.18 : 0),
                alienFauna: isAlien ? 0.48 : 0,
                habitatHum: isAlien ? 0.50 : 0,
                crystallineShimmer: isAlien ? 0.16 : 0,
                lowRumble: isAlien ? 0.16 : 0
            )
        )
    }
}
