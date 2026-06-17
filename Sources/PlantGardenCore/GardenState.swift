import Foundation

public struct GardenState: Codable, Equatable, Sendable {
    public static let schemaVersion = 3

    public var version: Int
    public var compositionVersion: Int?
    /// True once the operator has placed, moved, resized, or arranged plants
    /// themselves. A user-arranged garden is never auto-rearranged by
    /// composition-version upgrades, no matter how the version moves.
    public var isUserArranged: Bool
    public var createdAt: Date
    public var lastUpdatedAt: Date
    public var plants: [Plant]
    public var ambientMoisture: Double
    public var windStrength: Double
    /// Extra user-directed darkness applied to plant artwork in this scene.
    /// Saved on the scene's garden file so every wallpaper scene can have its
    /// own compositing taste.
    public var manualPlantDarkening: Double
    public var isPaused: Bool
    public var isAmbientWildlifeEnabled: Bool
    public var musicButtons: [GardenMusicButton]
    /// Scene-authored habitats where procedural gnome tribes can live,
    /// build, and interact with nearby plants.
    public var gnomeTribeZones: [GnomeTribeZone]
    /// Settlement lifecycle for multi-zone gnome societies. While uncommitted,
    /// the user can keep outlining areas without the Three.js village starting.
    public var gnomeSettlementPlan: GnomeTribeSettlementPlan
    public var areGnomeTribesHidden: Bool
    public var gnomeTribePerspective: GnomeTribePerspective
    /// Scene-authored sky corridors where procedural Three.js birds can fly.
    public var birdSkyZones: [BirdSkyZone]
    public var areBirdFlocksHidden: Bool
    /// Hand-painted patches of fresh soil. Plants placed on top of a patch
    /// sink their base into the dirt so they read as planted in the ground.
    public var soilPatches: [SoilPatch]
    public var musicButton: GardenMusicButton? {
        get {
            musicButtons.first
        }
        set {
            if let newValue {
                if musicButtons.isEmpty {
                    musicButtons = [newValue]
                } else {
                    musicButtons[0] = newValue
                }
            } else {
                musicButtons.removeAll()
            }
        }
    }
    public var settings: GardenSettings
    public var weather: GardenWeatherCondition?
    public var focusSession: GardenFocusSession?
    public var focusStats: GardenFocusStats?
    /// Optional per-scene fantasy upgrade ladder for AI-generated room/garden progression.
    public var progression: GardenSceneProgression?
    /// Seeds earned by pruning mature plants and harvesting edibles,
    /// keyed by species raw value. Spent via plant-from-seed.
    public var seedInventory: [String: Int]
    /// Lifetime harvest counts per edible species raw value.
    public var harvestTally: [String: Int]

    public init(
        version: Int = GardenState.schemaVersion,
        compositionVersion: Int? = GardenComposition.currentVersion,
        isUserArranged: Bool = false,
        createdAt: Date = Date(),
        lastUpdatedAt: Date = Date(),
        plants: [Plant] = [],
        ambientMoisture: Double = 0.36,
        windStrength: Double = 0.22,
        manualPlantDarkening: Double = 0,
        isPaused: Bool = false,
        isAmbientWildlifeEnabled: Bool = true,
        musicButton: GardenMusicButton? = nil,
        musicButtons: [GardenMusicButton]? = nil,
        gnomeTribeZones: [GnomeTribeZone] = [],
        gnomeSettlementPlan: GnomeTribeSettlementPlan? = nil,
        areGnomeTribesHidden: Bool = false,
        gnomeTribePerspective: GnomeTribePerspective = .defaultValue,
        birdSkyZones: [BirdSkyZone] = [],
        areBirdFlocksHidden: Bool = false,
        soilPatches: [SoilPatch] = [],
        settings: GardenSettings = .default,
        weather: GardenWeatherCondition? = nil,
        focusSession: GardenFocusSession? = nil,
        focusStats: GardenFocusStats? = nil,
        progression: GardenSceneProgression? = nil,
        seedInventory: [String: Int] = [:],
        harvestTally: [String: Int] = [:]
    ) {
        self.version = version
        self.compositionVersion = compositionVersion
        self.isUserArranged = isUserArranged
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.plants = plants
        self.ambientMoisture = ambientMoisture.clampedUnit
        self.windStrength = windStrength.clampedUnit
        self.manualPlantDarkening = manualPlantDarkening.clamped(to: 0...0.60)
        self.isPaused = isPaused
        self.isAmbientWildlifeEnabled = isAmbientWildlifeEnabled
        if let musicButtons {
            self.musicButtons = musicButtons
        } else if let musicButton {
            self.musicButtons = [musicButton]
        } else {
            self.musicButtons = []
        }
        let playableGnomeZones = gnomeTribeZones.filter(\.isPlayable)
        self.gnomeTribeZones = playableGnomeZones
        if let gnomeSettlementPlan {
            self.gnomeSettlementPlan = gnomeSettlementPlan.normalized(for: playableGnomeZones)
        } else {
            self.gnomeSettlementPlan = GnomeTribeSettlementPlan.defaultForExistingZones(playableGnomeZones)
        }
        self.areGnomeTribesHidden = areGnomeTribesHidden
        self.gnomeTribePerspective = gnomeTribePerspective
        self.birdSkyZones = birdSkyZones.filter(\.isPlayable)
        self.areBirdFlocksHidden = areBirdFlocksHidden
        self.soilPatches = soilPatches.filter(\.isPlayable)
        self.settings = settings
        self.weather = weather
        self.focusSession = focusSession
        self.focusStats = focusStats
        self.progression = progression
        self.seedInventory = seedInventory
        self.harvestTally = harvestTally
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case compositionVersion
        case isUserArranged
        case createdAt
        case lastUpdatedAt
        case plants
        case ambientMoisture
        case windStrength
        case manualPlantDarkening
        case isPaused
        case isAmbientWildlifeEnabled
        case musicButton
        case musicButtons
        case gnomeTribeZones
        case gnomeSettlementPlan
        case areGnomeTribesHidden
        case gnomeTribePerspective
        case birdSkyZones
        case areBirdFlocksHidden
        case soilPatches
        case settings
        case weather
        case focusSession
        case focusStats
        case progression
        case seedInventory
        case harvestTally
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            version: try container.decodeIfPresent(Int.self, forKey: .version) ?? GardenState.schemaVersion,
            compositionVersion: try container.decodeIfPresent(Int.self, forKey: .compositionVersion),
            isUserArranged: try container.decodeIfPresent(Bool.self, forKey: .isUserArranged) ?? false,
            createdAt: try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(),
            lastUpdatedAt: try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt) ?? Date(),
            plants: try container.decodeIfPresent([Plant].self, forKey: .plants) ?? [],
            ambientMoisture: try container.decodeIfPresent(Double.self, forKey: .ambientMoisture) ?? 0.36,
            windStrength: try container.decodeIfPresent(Double.self, forKey: .windStrength) ?? 0.22,
            manualPlantDarkening: try container.decodeIfPresent(Double.self, forKey: .manualPlantDarkening) ?? 0,
            isPaused: try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false,
            isAmbientWildlifeEnabled: try container.decodeIfPresent(
                Bool.self,
                forKey: .isAmbientWildlifeEnabled
            ) ?? true,
            musicButton: try container.decodeIfPresent(GardenMusicButton.self, forKey: .musicButton),
            musicButtons: try container.decodeIfPresent([GardenMusicButton].self, forKey: .musicButtons),
            gnomeTribeZones: try container.decodeIfPresent([GnomeTribeZone].self, forKey: .gnomeTribeZones) ?? [],
            gnomeSettlementPlan: try container.decodeIfPresent(
                GnomeTribeSettlementPlan.self,
                forKey: .gnomeSettlementPlan
            ),
            areGnomeTribesHidden: try container.decodeIfPresent(Bool.self, forKey: .areGnomeTribesHidden) ?? false,
            gnomeTribePerspective: try container.decodeIfPresent(
                GnomeTribePerspective.self,
                forKey: .gnomeTribePerspective
            ) ?? .defaultValue,
            birdSkyZones: try container.decodeIfPresent([BirdSkyZone].self, forKey: .birdSkyZones) ?? [],
            areBirdFlocksHidden: try container.decodeIfPresent(Bool.self, forKey: .areBirdFlocksHidden) ?? false,
            soilPatches: try container.decodeIfPresent([SoilPatch].self, forKey: .soilPatches) ?? [],
            settings: try container.decodeIfPresent(GardenSettings.self, forKey: .settings) ?? .default,
            weather: try container.decodeIfPresent(GardenWeatherCondition.self, forKey: .weather),
            focusSession: try container.decodeIfPresent(GardenFocusSession.self, forKey: .focusSession),
            focusStats: try container.decodeIfPresent(GardenFocusStats.self, forKey: .focusStats),
            progression: try container.decodeIfPresent(GardenSceneProgression.self, forKey: .progression),
            seedInventory: try container.decodeIfPresent([String: Int].self, forKey: .seedInventory) ?? [:],
            harvestTally: try container.decodeIfPresent([String: Int].self, forKey: .harvestTally) ?? [:]
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(compositionVersion, forKey: .compositionVersion)
        try container.encode(isUserArranged, forKey: .isUserArranged)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
        try container.encode(plants, forKey: .plants)
        try container.encode(ambientMoisture, forKey: .ambientMoisture)
        try container.encode(windStrength, forKey: .windStrength)
        try container.encode(manualPlantDarkening, forKey: .manualPlantDarkening)
        try container.encode(isPaused, forKey: .isPaused)
        try container.encode(isAmbientWildlifeEnabled, forKey: .isAmbientWildlifeEnabled)
        try container.encode(musicButtons, forKey: .musicButtons)
        try container.encodeIfPresent(musicButton, forKey: .musicButton)
        try container.encode(gnomeTribeZones, forKey: .gnomeTribeZones)
        try container.encode(gnomeSettlementPlan, forKey: .gnomeSettlementPlan)
        try container.encode(areGnomeTribesHidden, forKey: .areGnomeTribesHidden)
        try container.encode(gnomeTribePerspective, forKey: .gnomeTribePerspective)
        try container.encode(birdSkyZones, forKey: .birdSkyZones)
        try container.encode(areBirdFlocksHidden, forKey: .areBirdFlocksHidden)
        try container.encode(soilPatches, forKey: .soilPatches)
        try container.encode(settings, forKey: .settings)
        try container.encodeIfPresent(weather, forKey: .weather)
        try container.encodeIfPresent(focusSession, forKey: .focusSession)
        try container.encodeIfPresent(focusStats, forKey: .focusStats)
        try container.encodeIfPresent(progression, forKey: .progression)
        try container.encode(seedInventory, forKey: .seedInventory)
        try container.encode(harvestTally, forKey: .harvestTally)
    }

    public static func defaultGarden(screenCount: Int = 1, now: Date = Date()) -> GardenState {
        let safeScreenCount = max(1, screenCount)
        let plants = PlantSpecies.defaultGardenSpecies.enumerated().map { index, plantSpecies in
            Plant(
                species: plantSpecies,
                screenIndex: index % safeScreenCount,
                position: GardenComposition.position(
                    for: plantSpecies,
                    ordinal: index,
                    screenIndex: index % safeScreenCount
                ),
                plantedAt: now.addingTimeInterval(-TimeInterval(index + 1) * 1_800),
                lastTendedAt: now,
                ageSeconds: TimeInterval(index + 1) * 1_800,
                growth: min(0.96, 0.22 + Double(index % 6) * 0.13),
                hydration: 0.68 + Double(index % 3) * 0.07,
                health: 0.78 + Double(index % 4) * 0.045,
                bloomProgress: plantSpecies.kind == .tree ? 0.22 : Double(index % 4) * 0.18,
                swaySeed: Double(index) * 137.0 + 17.0,
                scale: GardenComposition.scale(for: plantSpecies, ordinal: index)
            )
        }

        return GardenState(
            compositionVersion: GardenComposition.currentVersion,
            createdAt: now,
            lastUpdatedAt: now,
            plants: GardenComposition.arrangedPlants(plants, screenCount: safeScreenCount),
            ambientMoisture: 0.38,
            windStrength: 0.24,
            isPaused: false,
            isAmbientWildlifeEnabled: true,
            musicButton: nil,
            settings: .default
        )
    }

    public var plantsNeedingCare: [Plant] {
        plants.filter { $0.careNeed.needsAttention }
    }

    public var thirstyPlants: [Plant] {
        plants.filter { $0.careNeed.isThirsty }
    }

    public var careSummary: String {
        let needCount = plantsNeedingCare.count
        switch needCount {
        case 0:
            return "Garden steady"
        case 1:
            return "1 needs care"
        default:
            return "\(needCount) need care"
        }
    }

    public var isEffectiveAmbientWildlifeEnabled: Bool {
        isAmbientWildlifeEnabled && settings.allowsAmbientWildlifeInExperienceMode
    }
}
