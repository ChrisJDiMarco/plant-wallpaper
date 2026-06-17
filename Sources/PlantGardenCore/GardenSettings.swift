import Foundation

public enum GardenTimeLapseCadence: String, Codable, CaseIterable, Sendable {
    case off
    case daily
    case weekly

    public var displayName: String {
        switch self {
        case .off:
            "Off"
        case .daily:
            "Daily"
        case .weekly:
            "Weekly"
        }
    }
}

public enum GardenExperienceMode: String, Codable, CaseIterable, Sendable {
    case garden
    case roomStudio
    case alienUFO

    public var displayName: String {
        switch self {
        case .garden:
            "Garden"
        case .roomStudio:
            "Room Studio"
        case .alienUFO:
            "Alien/UFO Garden"
        }
    }
}

public enum GardenPerformanceMode: String, Codable, CaseIterable, Sendable {
    case still
    case balanced
    case lively

    public var displayName: String {
        switch self {
        case .still:
            "Still"
        case .balanced:
            "Balanced"
        case .lively:
            "Lively"
        }
    }
}

public enum GardenRadioActivationMode: String, Codable, CaseIterable, Sendable {
    case singleClick
    case doubleClick
    case disabled

    public var displayName: String {
        switch self {
        case .singleClick:
            "Click to Play"
        case .doubleClick:
            "Double-Click to Play"
        case .disabled:
            "Disabled"
        }
    }
}

public enum GardenAIEditStrength: String, Codable, CaseIterable, Sendable {
    case subtle
    case medium
    case bigChange

    public var displayName: String {
        switch self {
        case .subtle:
            "Subtle"
        case .medium:
            "Medium"
        case .bigChange:
            "Big Change"
        }
    }

    public var promptInstruction: String {
        switch self {
        case .subtle:
            "Use a subtle edit strength: preserve nearly everything and make the smallest plausible visual change."
        case .medium:
            "Use a medium edit strength: preserve the composition while making the requested change clearly visible."
        case .bigChange:
            "Use a larger edit strength: keep the scene identity and planting areas, but allow a more dramatic requested change."
        }
    }
}

public enum GardenWallpaperGenerationQuality: String, Codable, CaseIterable, Sendable {
    case twoK
    case fourK

    public var displayName: String {
        switch self {
        case .twoK:
            "2K Standard"
        case .fourK:
            "4K High Detail"
        }
    }

    public var openAISize: String {
        switch self {
        case .twoK:
            "2048x1152"
        case .fourK:
            "3840x2160"
        }
    }

    public var openAIQuality: String {
        switch self {
        case .twoK:
            "medium"
        case .fourK:
            "high"
        }
    }

    public var settingsNote: String {
        switch self {
        case .twoK:
            "2K uses fewer OpenAI image tokens and is the lower-cost default; app-hosted plans would count it as one generation credit."
        case .fourK:
            "4K is sharper and costs more OpenAI image tokens; app-hosted plans may use more credits after the monthly allowance."
        }
    }
}

public enum GardenRareMomentsMode: String, Codable, CaseIterable, Sendable {
    case off
    case quiet
    case full

    public var displayName: String {
        switch self {
        case .off:
            "Off"
        case .quiet:
            "Quiet"
        case .full:
            "Full"
        }
    }
}

public enum GardenDisplayBehavior: String, Codable, CaseIterable, Sendable {
    case mirrorAllDisplays
    case mainDisplayOnly

    public var displayName: String {
        switch self {
        case .mirrorAllDisplays:
            "Mirror on All Displays"
        case .mainDisplayOnly:
            "Main Display Only"
        }
    }
}

public struct GardenGnomeSimulationSettings: Codable, Equatable, Sendable {
    public static let `default` = GardenGnomeSimulationSettings()

    public let isEnabled: Bool
    public let populationMultiplier: Double
    public let tribeScaleMultiplier: Double
    public let behaviorLiveliness: Double
    public let buildingSpeedMultiplier: Double
    public let cooperationMultiplier: Double
    public let plantInteractionMultiplier: Double
    public let villageDetailMultiplier: Double
    public let settlementExpansionDays: Double

    public init(
        isEnabled: Bool = true,
        populationMultiplier: Double = 1.0,
        tribeScaleMultiplier: Double = 1.0,
        behaviorLiveliness: Double = 1.0,
        buildingSpeedMultiplier: Double = 1.0,
        cooperationMultiplier: Double = 1.0,
        plantInteractionMultiplier: Double = 1.0,
        villageDetailMultiplier: Double = 1.0,
        settlementExpansionDays: Double = GnomeTribeSettlementPlan.defaultExpansionDurationDays
    ) {
        self.isEnabled = isEnabled
        self.populationMultiplier = Self.clamp(populationMultiplier, min: 0.25, max: 2.5)
        self.tribeScaleMultiplier = Self.clamp(tribeScaleMultiplier, min: 0.45, max: 2.25)
        self.behaviorLiveliness = Self.clamp(behaviorLiveliness, min: 0.25, max: 2.5)
        self.buildingSpeedMultiplier = Self.clamp(buildingSpeedMultiplier, min: 0.10, max: 4.0)
        self.cooperationMultiplier = Self.clamp(cooperationMultiplier, min: 0.0, max: 2.5)
        self.plantInteractionMultiplier = Self.clamp(plantInteractionMultiplier, min: 0.0, max: 2.5)
        self.villageDetailMultiplier = Self.clamp(villageDetailMultiplier, min: 0.50, max: 2.0)
        self.settlementExpansionDays = Self.clamp(
            settlementExpansionDays,
            min: GnomeTribeSettlementPlan.minimumExpansionDurationDays,
            max: GnomeTribeSettlementPlan.maximumExpansionDurationDays
        )
    }

    public func updating(
        isEnabled: Bool? = nil,
        populationMultiplier: Double? = nil,
        tribeScaleMultiplier: Double? = nil,
        behaviorLiveliness: Double? = nil,
        buildingSpeedMultiplier: Double? = nil,
        cooperationMultiplier: Double? = nil,
        plantInteractionMultiplier: Double? = nil,
        villageDetailMultiplier: Double? = nil,
        settlementExpansionDays: Double? = nil
    ) -> GardenGnomeSimulationSettings {
        GardenGnomeSimulationSettings(
            isEnabled: isEnabled ?? self.isEnabled,
            populationMultiplier: populationMultiplier ?? self.populationMultiplier,
            tribeScaleMultiplier: tribeScaleMultiplier ?? self.tribeScaleMultiplier,
            behaviorLiveliness: behaviorLiveliness ?? self.behaviorLiveliness,
            buildingSpeedMultiplier: buildingSpeedMultiplier ?? self.buildingSpeedMultiplier,
            cooperationMultiplier: cooperationMultiplier ?? self.cooperationMultiplier,
            plantInteractionMultiplier: plantInteractionMultiplier ?? self.plantInteractionMultiplier,
            villageDetailMultiplier: villageDetailMultiplier ?? self.villageDetailMultiplier,
            settlementExpansionDays: settlementExpansionDays ?? self.settlementExpansionDays
        )
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case populationMultiplier
        case tribeScaleMultiplier
        case behaviorLiveliness
        case buildingSpeedMultiplier
        case cooperationMultiplier
        case plantInteractionMultiplier
        case villageDetailMultiplier
        case settlementExpansionDays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true,
            populationMultiplier: try container.decodeIfPresent(
                Double.self,
                forKey: .populationMultiplier
            ) ?? 1.0,
            tribeScaleMultiplier: try container.decodeIfPresent(
                Double.self,
                forKey: .tribeScaleMultiplier
            ) ?? 1.0,
            behaviorLiveliness: try container.decodeIfPresent(
                Double.self,
                forKey: .behaviorLiveliness
            ) ?? 1.0,
            buildingSpeedMultiplier: try container.decodeIfPresent(
                Double.self,
                forKey: .buildingSpeedMultiplier
            ) ?? 1.0,
            cooperationMultiplier: try container.decodeIfPresent(
                Double.self,
                forKey: .cooperationMultiplier
            ) ?? 1.0,
            plantInteractionMultiplier: try container.decodeIfPresent(
                Double.self,
                forKey: .plantInteractionMultiplier
            ) ?? 1.0,
            villageDetailMultiplier: try container.decodeIfPresent(
                Double.self,
                forKey: .villageDetailMultiplier
            ) ?? 1.0,
            settlementExpansionDays: try container.decodeIfPresent(
                Double.self,
                forKey: .settlementExpansionDays
            ) ?? GnomeTribeSettlementPlan.defaultExpansionDurationDays
        )
    }

    private static func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        guard value.isFinite else {
            return minimum
        }

        return Swift.min(maximum, Swift.max(minimum, value))
    }
}

public struct GardenSettings: Codable, Equatable, Sendable {
    public static let `default` = GardenSettings()
    public static let defaultSpotifyLaunchURLString = "https://open.spotify.com/search/chillhop"

    public let growthSpeedMultiplier: Double
    public let waterUseMultiplier: Double
    public let defaultPlantScale: Double
    public let plantNewPlantsAtMaturity: Bool
    public let wildlifeDensityMultiplier: Double
    public let wildlifeSpeedMultiplier: Double
    public let bugSizeMultiplier: Double
    public let gnomeSimulation: GardenGnomeSimulationSettings
    public let musicVolume: Double
    public let radioCompanionScale: Double
    public let radioCompanionStationOverrides: [String: GardenRadioStream]
    public let musicSource: GardenMusicSource
    public let spotifyLaunchURLString: String
    public let isWeatherSyncEnabled: Bool
    public let isAmbientSoundEnabled: Bool
    public let ambientSoundVolume: Double
    public let isWindSoundEnabled: Bool
    public let isRainSoundEnabled: Bool
    public let isBirdsongEnabled: Bool
    public let isCricketSoundEnabled: Bool
    public let isWaterSoundEnabled: Bool
    public let isUrbanMurmurSoundEnabled: Bool
    public let isRoomToneSoundEnabled: Bool
    public let isCicadaSoundEnabled: Bool
    public let isChimeSoundEnabled: Bool
    public let isSmallWildlifeSoundEnabled: Bool
    public let isRoomLifeSoundEnabled: Bool
    public let isElectronicsSoundEnabled: Bool
    public let isAlienFaunaSoundEnabled: Bool
    public let isHabitatHumSoundEnabled: Bool
    public let isCrystallineShimmerSoundEnabled: Bool
    public let isLowRumbleSoundEnabled: Bool
    public let isGardenInteractionLocked: Bool
    public let useAIGeneratedLockSnapshot: Bool
    public let isAssistantMenuItemEnabled: Bool
    public let isCatChatOnClickEnabled: Bool
    public let isRoomStudioWildlifeEnabled: Bool
    public let experienceMode: GardenExperienceMode
    public let timeLapseCadence: GardenTimeLapseCadence
    public let cozyModeEnabled: Bool
    public let performanceMode: GardenPerformanceMode
    public let autoLowPowerOnBattery: Bool
    public let radioActivationMode: GardenRadioActivationMode
    public let wallpaperGenerationQuality: GardenWallpaperGenerationQuality
    public let aiEditStrength: GardenAIEditStrength
    public let rareMomentsMode: GardenRareMomentsMode
    public let displayBehavior: GardenDisplayBehavior
    public let notifyCare: Bool
    public let notifyWeather: Bool
    public let notifyRareMoments: Bool
    public let notifyFocus: Bool
    public let notifyHarvest: Bool

    public init(
        growthSpeedMultiplier: Double = 1.0,
        waterUseMultiplier: Double = 1.0,
        defaultPlantScale: Double = 1.0,
        plantNewPlantsAtMaturity: Bool = false,
        wildlifeDensityMultiplier: Double = 1.0,
        wildlifeSpeedMultiplier: Double = 1.0,
        bugSizeMultiplier: Double = 1.0,
        gnomeSimulation: GardenGnomeSimulationSettings = .default,
        musicVolume: Double = 1.0,
        radioCompanionScale: Double = 1.0,
        radioCompanionStationOverrides: [String: GardenRadioStream] = [:],
        musicSource: GardenMusicSource = .chillHopRadio,
        spotifyLaunchURLString: String = GardenSettings.defaultSpotifyLaunchURLString,
        isWeatherSyncEnabled: Bool = false,
        isAmbientSoundEnabled: Bool = false,
        ambientSoundVolume: Double = 0.35,
        isWindSoundEnabled: Bool = true,
        isRainSoundEnabled: Bool = true,
        isBirdsongEnabled: Bool = true,
        isCricketSoundEnabled: Bool = true,
        isWaterSoundEnabled: Bool = true,
        isUrbanMurmurSoundEnabled: Bool = true,
        isRoomToneSoundEnabled: Bool = true,
        isCicadaSoundEnabled: Bool = true,
        isChimeSoundEnabled: Bool = true,
        isSmallWildlifeSoundEnabled: Bool = true,
        isRoomLifeSoundEnabled: Bool = true,
        isElectronicsSoundEnabled: Bool = true,
        isAlienFaunaSoundEnabled: Bool = true,
        isHabitatHumSoundEnabled: Bool = true,
        isCrystallineShimmerSoundEnabled: Bool = true,
        isLowRumbleSoundEnabled: Bool = true,
        isGardenInteractionLocked: Bool = false,
        useAIGeneratedLockSnapshot: Bool = false,
        isAssistantMenuItemEnabled: Bool = true,
        isCatChatOnClickEnabled: Bool = true,
        isRoomStudioWildlifeEnabled: Bool = false,
        experienceMode: GardenExperienceMode = .garden,
        timeLapseCadence: GardenTimeLapseCadence = .daily,
        cozyModeEnabled: Bool = false,
        performanceMode: GardenPerformanceMode = .balanced,
        autoLowPowerOnBattery: Bool = true,
        radioActivationMode: GardenRadioActivationMode = .singleClick,
        wallpaperGenerationQuality: GardenWallpaperGenerationQuality = .twoK,
        aiEditStrength: GardenAIEditStrength = .subtle,
        rareMomentsMode: GardenRareMomentsMode = .full,
        displayBehavior: GardenDisplayBehavior = .mirrorAllDisplays,
        notifyCare: Bool = true,
        notifyWeather: Bool = true,
        notifyRareMoments: Bool = true,
        notifyFocus: Bool = true,
        notifyHarvest: Bool = true
    ) {
        self.growthSpeedMultiplier = Self.clamp(growthSpeedMultiplier, min: 0.25, max: 4.0)
        self.waterUseMultiplier = Self.clamp(waterUseMultiplier, min: 0.25, max: 2.5)
        self.defaultPlantScale = Self.clamp(defaultPlantScale, min: 0.45, max: 2.25)
        self.plantNewPlantsAtMaturity = plantNewPlantsAtMaturity
        self.wildlifeDensityMultiplier = Self.clamp(wildlifeDensityMultiplier, min: 0.25, max: 3.0)
        self.wildlifeSpeedMultiplier = Self.clamp(wildlifeSpeedMultiplier, min: 0.25, max: 3.0)
        self.bugSizeMultiplier = Self.clamp(bugSizeMultiplier, min: 0.50, max: 2.0)
        self.gnomeSimulation = gnomeSimulation
        self.musicVolume = Self.clamp(musicVolume, min: 0, max: 1.0)
        self.radioCompanionScale = Self.clamp(radioCompanionScale, min: 0.55, max: 1.70)
        self.radioCompanionStationOverrides = Self.sanitizedRadioCompanionStationOverrides(radioCompanionStationOverrides)
        self.musicSource = musicSource
        self.spotifyLaunchURLString = Self.normalizedSpotifyLaunchURLString(spotifyLaunchURLString)
        self.isWeatherSyncEnabled = isWeatherSyncEnabled
        self.isAmbientSoundEnabled = isAmbientSoundEnabled
        self.ambientSoundVolume = Self.clamp(ambientSoundVolume, min: 0, max: 1.0)
        self.isWindSoundEnabled = isWindSoundEnabled
        self.isRainSoundEnabled = isRainSoundEnabled
        self.isBirdsongEnabled = isBirdsongEnabled
        self.isCricketSoundEnabled = isCricketSoundEnabled
        self.isWaterSoundEnabled = isWaterSoundEnabled
        self.isUrbanMurmurSoundEnabled = isUrbanMurmurSoundEnabled
        self.isRoomToneSoundEnabled = isRoomToneSoundEnabled
        self.isCicadaSoundEnabled = isCicadaSoundEnabled
        self.isChimeSoundEnabled = isChimeSoundEnabled
        self.isSmallWildlifeSoundEnabled = isSmallWildlifeSoundEnabled
        self.isRoomLifeSoundEnabled = isRoomLifeSoundEnabled
        self.isElectronicsSoundEnabled = isElectronicsSoundEnabled
        self.isAlienFaunaSoundEnabled = isAlienFaunaSoundEnabled
        self.isHabitatHumSoundEnabled = isHabitatHumSoundEnabled
        self.isCrystallineShimmerSoundEnabled = isCrystallineShimmerSoundEnabled
        self.isLowRumbleSoundEnabled = isLowRumbleSoundEnabled
        self.isGardenInteractionLocked = isGardenInteractionLocked
        self.useAIGeneratedLockSnapshot = useAIGeneratedLockSnapshot
        self.isAssistantMenuItemEnabled = isAssistantMenuItemEnabled
        self.isCatChatOnClickEnabled = isCatChatOnClickEnabled
        self.isRoomStudioWildlifeEnabled = isRoomStudioWildlifeEnabled
        self.experienceMode = experienceMode
        self.timeLapseCadence = timeLapseCadence
        self.cozyModeEnabled = cozyModeEnabled
        self.performanceMode = performanceMode
        self.autoLowPowerOnBattery = autoLowPowerOnBattery
        self.radioActivationMode = radioActivationMode
        self.wallpaperGenerationQuality = wallpaperGenerationQuality
        self.aiEditStrength = aiEditStrength
        self.rareMomentsMode = rareMomentsMode
        self.displayBehavior = displayBehavior
        self.notifyCare = notifyCare
        self.notifyWeather = notifyWeather
        self.notifyRareMoments = notifyRareMoments
        self.notifyFocus = notifyFocus
        self.notifyHarvest = notifyHarvest
    }

    private enum CodingKeys: String, CodingKey {
        case growthSpeedMultiplier
        case waterUseMultiplier
        case defaultPlantScale
        case plantNewPlantsAtMaturity
        case wildlifeDensityMultiplier
        case wildlifeSpeedMultiplier
        case bugSizeMultiplier
        case gnomeSimulation
        case musicVolume
        case radioCompanionScale
        case radioCompanionStationOverrides
        case musicSource
        case spotifyLaunchURLString
        case isWeatherSyncEnabled
        case isAmbientSoundEnabled
        case ambientSoundVolume
        case isWindSoundEnabled
        case isRainSoundEnabled
        case isBirdsongEnabled
        case isCricketSoundEnabled
        case isWaterSoundEnabled
        case isUrbanMurmurSoundEnabled
        case isRoomToneSoundEnabled
        case isCicadaSoundEnabled
        case isChimeSoundEnabled
        case isSmallWildlifeSoundEnabled
        case isRoomLifeSoundEnabled
        case isElectronicsSoundEnabled
        case isAlienFaunaSoundEnabled
        case isHabitatHumSoundEnabled
        case isCrystallineShimmerSoundEnabled
        case isLowRumbleSoundEnabled
        case isGardenInteractionLocked
        case useAIGeneratedLockSnapshot
        case isAssistantMenuItemEnabled
        case isCatChatOnClickEnabled
        case isRoomStudioWildlifeEnabled
        case experienceMode
        case timeLapseCadence
        case cozyModeEnabled
        case performanceMode
        case autoLowPowerOnBattery
        case radioActivationMode
        case wallpaperGenerationQuality
        case aiEditStrength
        case rareMomentsMode
        case displayBehavior
        case notifyCare
        case notifyWeather
        case notifyRareMoments
        case notifyFocus
        case notifyHarvest
    }

    /// Backward-compatible decoding: settings saved by older versions omit
    /// newer keys; they must decode with defaults instead of failing (which
    /// would discard the user's whole garden file).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            growthSpeedMultiplier: try container.decodeIfPresent(Double.self, forKey: .growthSpeedMultiplier) ?? 1.0,
            waterUseMultiplier: try container.decodeIfPresent(Double.self, forKey: .waterUseMultiplier) ?? 1.0,
            defaultPlantScale: try container.decodeIfPresent(Double.self, forKey: .defaultPlantScale) ?? 1.0,
            plantNewPlantsAtMaturity: try container.decodeIfPresent(Bool.self, forKey: .plantNewPlantsAtMaturity) ?? false,
            wildlifeDensityMultiplier: try container.decodeIfPresent(Double.self, forKey: .wildlifeDensityMultiplier) ?? 1.0,
            wildlifeSpeedMultiplier: try container.decodeIfPresent(Double.self, forKey: .wildlifeSpeedMultiplier) ?? 1.0,
            bugSizeMultiplier: try container.decodeIfPresent(Double.self, forKey: .bugSizeMultiplier) ?? 1.0,
            gnomeSimulation: try container.decodeIfPresent(
                GardenGnomeSimulationSettings.self,
                forKey: .gnomeSimulation
            ) ?? .default,
            musicVolume: try container.decodeIfPresent(Double.self, forKey: .musicVolume) ?? 1.0,
            radioCompanionScale: try container.decodeIfPresent(Double.self, forKey: .radioCompanionScale) ?? 1.0,
            radioCompanionStationOverrides: try container.decodeIfPresent(
                [String: GardenRadioStream].self,
                forKey: .radioCompanionStationOverrides
            ) ?? [:],
            musicSource: try container.decodeIfPresent(GardenMusicSource.self, forKey: .musicSource) ?? .chillHopRadio,
            spotifyLaunchURLString: try container.decodeIfPresent(String.self, forKey: .spotifyLaunchURLString)
                ?? GardenSettings.defaultSpotifyLaunchURLString,
            isWeatherSyncEnabled: try container.decodeIfPresent(Bool.self, forKey: .isWeatherSyncEnabled) ?? false,
            isAmbientSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isAmbientSoundEnabled) ?? false,
            ambientSoundVolume: try container.decodeIfPresent(Double.self, forKey: .ambientSoundVolume) ?? 0.35,
            isWindSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isWindSoundEnabled) ?? true,
            isRainSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isRainSoundEnabled) ?? true,
            isBirdsongEnabled: try container.decodeIfPresent(Bool.self, forKey: .isBirdsongEnabled) ?? true,
            isCricketSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isCricketSoundEnabled) ?? true,
            isWaterSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isWaterSoundEnabled) ?? true,
            isUrbanMurmurSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isUrbanMurmurSoundEnabled) ?? true,
            isRoomToneSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isRoomToneSoundEnabled) ?? true,
            isCicadaSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isCicadaSoundEnabled) ?? true,
            isChimeSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isChimeSoundEnabled) ?? true,
            isSmallWildlifeSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isSmallWildlifeSoundEnabled) ?? true,
            isRoomLifeSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isRoomLifeSoundEnabled) ?? true,
            isElectronicsSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isElectronicsSoundEnabled) ?? true,
            isAlienFaunaSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isAlienFaunaSoundEnabled) ?? true,
            isHabitatHumSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isHabitatHumSoundEnabled) ?? true,
            isCrystallineShimmerSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isCrystallineShimmerSoundEnabled) ?? true,
            isLowRumbleSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .isLowRumbleSoundEnabled) ?? true,
            isGardenInteractionLocked: try container.decodeIfPresent(Bool.self, forKey: .isGardenInteractionLocked) ?? false,
            useAIGeneratedLockSnapshot: try container.decodeIfPresent(Bool.self, forKey: .useAIGeneratedLockSnapshot) ?? false,
            isAssistantMenuItemEnabled: try container.decodeIfPresent(Bool.self, forKey: .isAssistantMenuItemEnabled) ?? true,
            isCatChatOnClickEnabled: try container.decodeIfPresent(Bool.self, forKey: .isCatChatOnClickEnabled) ?? true,
            isRoomStudioWildlifeEnabled: try container.decodeIfPresent(
                Bool.self,
                forKey: .isRoomStudioWildlifeEnabled
            ) ?? false,
            experienceMode: try container.decodeIfPresent(GardenExperienceMode.self, forKey: .experienceMode) ?? .garden,
            timeLapseCadence: try container.decodeIfPresent(GardenTimeLapseCadence.self, forKey: .timeLapseCadence) ?? .daily,
            cozyModeEnabled: try container.decodeIfPresent(Bool.self, forKey: .cozyModeEnabled) ?? false,
            performanceMode: try container.decodeIfPresent(GardenPerformanceMode.self, forKey: .performanceMode) ?? .balanced,
            autoLowPowerOnBattery: try container.decodeIfPresent(Bool.self, forKey: .autoLowPowerOnBattery) ?? true,
            radioActivationMode: try container.decodeIfPresent(GardenRadioActivationMode.self, forKey: .radioActivationMode) ?? .singleClick,
            wallpaperGenerationQuality: try container.decodeIfPresent(
                GardenWallpaperGenerationQuality.self,
                forKey: .wallpaperGenerationQuality
            ) ?? .twoK,
            aiEditStrength: try container.decodeIfPresent(GardenAIEditStrength.self, forKey: .aiEditStrength) ?? .subtle,
            rareMomentsMode: try container.decodeIfPresent(GardenRareMomentsMode.self, forKey: .rareMomentsMode) ?? .full,
            displayBehavior: try container.decodeIfPresent(GardenDisplayBehavior.self, forKey: .displayBehavior) ?? .mirrorAllDisplays,
            notifyCare: try container.decodeIfPresent(Bool.self, forKey: .notifyCare) ?? true,
            notifyWeather: try container.decodeIfPresent(Bool.self, forKey: .notifyWeather) ?? true,
            notifyRareMoments: try container.decodeIfPresent(Bool.self, forKey: .notifyRareMoments) ?? true,
            notifyFocus: try container.decodeIfPresent(Bool.self, forKey: .notifyFocus) ?? true,
            notifyHarvest: try container.decodeIfPresent(Bool.self, forKey: .notifyHarvest) ?? true
        )
    }

    public func updating(
        growthSpeedMultiplier: Double? = nil,
        waterUseMultiplier: Double? = nil,
        defaultPlantScale: Double? = nil,
        plantNewPlantsAtMaturity: Bool? = nil,
        wildlifeDensityMultiplier: Double? = nil,
        wildlifeSpeedMultiplier: Double? = nil,
        bugSizeMultiplier: Double? = nil,
        gnomeSimulation: GardenGnomeSimulationSettings? = nil,
        musicVolume: Double? = nil,
        radioCompanionScale: Double? = nil,
        radioCompanionStationOverrides: [String: GardenRadioStream]? = nil,
        musicSource: GardenMusicSource? = nil,
        spotifyLaunchURLString: String? = nil,
        isWeatherSyncEnabled: Bool? = nil,
        isAmbientSoundEnabled: Bool? = nil,
        ambientSoundVolume: Double? = nil,
        isWindSoundEnabled: Bool? = nil,
        isRainSoundEnabled: Bool? = nil,
        isBirdsongEnabled: Bool? = nil,
        isCricketSoundEnabled: Bool? = nil,
        isWaterSoundEnabled: Bool? = nil,
        isUrbanMurmurSoundEnabled: Bool? = nil,
        isRoomToneSoundEnabled: Bool? = nil,
        isCicadaSoundEnabled: Bool? = nil,
        isChimeSoundEnabled: Bool? = nil,
        isSmallWildlifeSoundEnabled: Bool? = nil,
        isRoomLifeSoundEnabled: Bool? = nil,
        isElectronicsSoundEnabled: Bool? = nil,
        isAlienFaunaSoundEnabled: Bool? = nil,
        isHabitatHumSoundEnabled: Bool? = nil,
        isCrystallineShimmerSoundEnabled: Bool? = nil,
        isLowRumbleSoundEnabled: Bool? = nil,
        isGardenInteractionLocked: Bool? = nil,
        useAIGeneratedLockSnapshot: Bool? = nil,
        isAssistantMenuItemEnabled: Bool? = nil,
        isCatChatOnClickEnabled: Bool? = nil,
        isRoomStudioWildlifeEnabled: Bool? = nil,
        experienceMode: GardenExperienceMode? = nil,
        timeLapseCadence: GardenTimeLapseCadence? = nil,
        cozyModeEnabled: Bool? = nil,
        performanceMode: GardenPerformanceMode? = nil,
        autoLowPowerOnBattery: Bool? = nil,
        radioActivationMode: GardenRadioActivationMode? = nil,
        wallpaperGenerationQuality: GardenWallpaperGenerationQuality? = nil,
        aiEditStrength: GardenAIEditStrength? = nil,
        rareMomentsMode: GardenRareMomentsMode? = nil,
        displayBehavior: GardenDisplayBehavior? = nil,
        notifyCare: Bool? = nil,
        notifyWeather: Bool? = nil,
        notifyRareMoments: Bool? = nil,
        notifyFocus: Bool? = nil,
        notifyHarvest: Bool? = nil
    ) -> GardenSettings {
        GardenSettings(
            growthSpeedMultiplier: growthSpeedMultiplier ?? self.growthSpeedMultiplier,
            waterUseMultiplier: waterUseMultiplier ?? self.waterUseMultiplier,
            defaultPlantScale: defaultPlantScale ?? self.defaultPlantScale,
            plantNewPlantsAtMaturity: plantNewPlantsAtMaturity ?? self.plantNewPlantsAtMaturity,
            wildlifeDensityMultiplier: wildlifeDensityMultiplier ?? self.wildlifeDensityMultiplier,
            wildlifeSpeedMultiplier: wildlifeSpeedMultiplier ?? self.wildlifeSpeedMultiplier,
            bugSizeMultiplier: bugSizeMultiplier ?? self.bugSizeMultiplier,
            gnomeSimulation: gnomeSimulation ?? self.gnomeSimulation,
            musicVolume: musicVolume ?? self.musicVolume,
            radioCompanionScale: radioCompanionScale ?? self.radioCompanionScale,
            radioCompanionStationOverrides: radioCompanionStationOverrides ?? self.radioCompanionStationOverrides,
            musicSource: musicSource ?? self.musicSource,
            spotifyLaunchURLString: spotifyLaunchURLString ?? self.spotifyLaunchURLString,
            isWeatherSyncEnabled: isWeatherSyncEnabled ?? self.isWeatherSyncEnabled,
            isAmbientSoundEnabled: isAmbientSoundEnabled ?? self.isAmbientSoundEnabled,
            ambientSoundVolume: ambientSoundVolume ?? self.ambientSoundVolume,
            isWindSoundEnabled: isWindSoundEnabled ?? self.isWindSoundEnabled,
            isRainSoundEnabled: isRainSoundEnabled ?? self.isRainSoundEnabled,
            isBirdsongEnabled: isBirdsongEnabled ?? self.isBirdsongEnabled,
            isCricketSoundEnabled: isCricketSoundEnabled ?? self.isCricketSoundEnabled,
            isWaterSoundEnabled: isWaterSoundEnabled ?? self.isWaterSoundEnabled,
            isUrbanMurmurSoundEnabled: isUrbanMurmurSoundEnabled ?? self.isUrbanMurmurSoundEnabled,
            isRoomToneSoundEnabled: isRoomToneSoundEnabled ?? self.isRoomToneSoundEnabled,
            isCicadaSoundEnabled: isCicadaSoundEnabled ?? self.isCicadaSoundEnabled,
            isChimeSoundEnabled: isChimeSoundEnabled ?? self.isChimeSoundEnabled,
            isSmallWildlifeSoundEnabled: isSmallWildlifeSoundEnabled ?? self.isSmallWildlifeSoundEnabled,
            isRoomLifeSoundEnabled: isRoomLifeSoundEnabled ?? self.isRoomLifeSoundEnabled,
            isElectronicsSoundEnabled: isElectronicsSoundEnabled ?? self.isElectronicsSoundEnabled,
            isAlienFaunaSoundEnabled: isAlienFaunaSoundEnabled ?? self.isAlienFaunaSoundEnabled,
            isHabitatHumSoundEnabled: isHabitatHumSoundEnabled ?? self.isHabitatHumSoundEnabled,
            isCrystallineShimmerSoundEnabled: isCrystallineShimmerSoundEnabled ?? self.isCrystallineShimmerSoundEnabled,
            isLowRumbleSoundEnabled: isLowRumbleSoundEnabled ?? self.isLowRumbleSoundEnabled,
            isGardenInteractionLocked: isGardenInteractionLocked ?? self.isGardenInteractionLocked,
            useAIGeneratedLockSnapshot: useAIGeneratedLockSnapshot ?? self.useAIGeneratedLockSnapshot,
            isAssistantMenuItemEnabled: isAssistantMenuItemEnabled ?? self.isAssistantMenuItemEnabled,
            isCatChatOnClickEnabled: isCatChatOnClickEnabled ?? self.isCatChatOnClickEnabled,
            isRoomStudioWildlifeEnabled: isRoomStudioWildlifeEnabled ?? self.isRoomStudioWildlifeEnabled,
            experienceMode: experienceMode ?? self.experienceMode,
            timeLapseCadence: timeLapseCadence ?? self.timeLapseCadence,
            cozyModeEnabled: cozyModeEnabled ?? self.cozyModeEnabled,
            performanceMode: performanceMode ?? self.performanceMode,
            autoLowPowerOnBattery: autoLowPowerOnBattery ?? self.autoLowPowerOnBattery,
            radioActivationMode: radioActivationMode ?? self.radioActivationMode,
            wallpaperGenerationQuality: wallpaperGenerationQuality ?? self.wallpaperGenerationQuality,
            aiEditStrength: aiEditStrength ?? self.aiEditStrength,
            rareMomentsMode: rareMomentsMode ?? self.rareMomentsMode,
            displayBehavior: displayBehavior ?? self.displayBehavior,
            notifyCare: notifyCare ?? self.notifyCare,
            notifyWeather: notifyWeather ?? self.notifyWeather,
            notifyRareMoments: notifyRareMoments ?? self.notifyRareMoments,
            notifyFocus: notifyFocus ?? self.notifyFocus,
            notifyHarvest: notifyHarvest ?? self.notifyHarvest
        )
    }

    public var spotifyLaunchURL: URL {
        URL(string: spotifyLaunchURLString) ?? URL(string: Self.defaultSpotifyLaunchURLString)!
    }

    public var allowsAmbientWildlifeInExperienceMode: Bool {
        experienceMode != .roomStudio || isRoomStudioWildlifeEnabled
    }

    public func radioStream(for companion: GardenRadioCompanion) -> GardenRadioStream {
        companion.stationStream(in: self)
    }

    public func companionAlreadyAssigned(to stream: GardenRadioStream, excluding companion: GardenRadioCompanion) -> GardenRadioCompanion? {
        GardenRadioCompanion.allCases.first { candidate in
            candidate != companion && radioStream(for: candidate).id == stream.id
        }
    }

    public func assigningRadioStream(_ stream: GardenRadioStream, to companion: GardenRadioCompanion) -> GardenSettings? {
        guard companionAlreadyAssigned(to: stream, excluding: companion) == nil else {
            return nil
        }

        var overrides = radioCompanionStationOverrides
        if stream.id == companion.station.stream.id {
            overrides.removeValue(forKey: companion.rawValue)
        } else {
            overrides[companion.rawValue] = stream
        }
        return updating(radioCompanionStationOverrides: overrides)
    }

    private static func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        guard value.isFinite else {
            return minimum
        }

        return Swift.min(maximum, Swift.max(minimum, value))
    }

    private static func normalizedSpotifyLaunchURLString(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Self.defaultSpotifyLaunchURLString
        }

        if trimmed.lowercased().hasPrefix("spotify:") {
            return trimmed
        }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host?.lowercased(),
              (host == "open.spotify.com" || host == "play.spotify.com" || host == "spotify.link") else {
            return Self.defaultSpotifyLaunchURLString
        }

        return trimmed
    }

    private static func sanitizedRadioCompanionStationOverrides(_ overrides: [String: GardenRadioStream]) -> [String: GardenRadioStream] {
        var sanitized: [String: GardenRadioStream] = [:]
        var usedStreamIDs = Set<String>()
        for companion in GardenRadioCompanion.allCases {
            guard let stream = overrides[companion.rawValue],
                  !stream.streamURLStrings.isEmpty,
                  !usedStreamIDs.contains(stream.id) else {
                continue
            }
            sanitized[companion.rawValue] = stream
            usedStreamIDs.insert(stream.id)
        }
        return sanitized
    }
}
