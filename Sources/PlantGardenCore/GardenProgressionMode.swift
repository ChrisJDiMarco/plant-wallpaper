import Foundation

public struct GardenProgressionProfile: Codable, Equatable, Sendable {
    public var lifestyleFantasy: String
    public var placeInWorld: String
    public var ageBracket: String
    public var vibe: String
    public var avoidList: String

    public init(
        lifestyleFantasy: String,
        placeInWorld: String,
        ageBracket: String,
        vibe: String,
        avoidList: String = ""
    ) {
        self.lifestyleFantasy = lifestyleFantasy.trimmingCharacters(in: .whitespacesAndNewlines)
        self.placeInWorld = placeInWorld.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ageBracket = ageBracket.trimmingCharacters(in: .whitespacesAndNewlines)
        self.vibe = vibe.trimmingCharacters(in: .whitespacesAndNewlines)
        self.avoidList = avoidList.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isUsable: Bool {
        !lifestyleFantasy.isEmpty || !placeInWorld.isEmpty || !vibe.isEmpty
    }
}

public struct GardenSceneProgression: Codable, Equatable, Sendable {
    public static let maximumLevel = 20

    /// How often the ladder advances on its own. `.off` keeps progression
    /// fully manual (the default for every existing and new profile).
    public enum AutoAdvanceCadence: String, Codable, Equatable, Sendable, CaseIterable {
        case off
        case daily
        case weekly

        public var interval: TimeInterval? {
            switch self {
            case .off:
                nil
            case .daily:
                24 * 60 * 60
            case .weekly:
                7 * 24 * 60 * 60
            }
        }

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

    public var isEnabled: Bool
    public var level: Int
    public var profile: GardenProgressionProfile
    public var startedAt: Date
    public var lastAdvancedAt: Date?
    public var autoAdvanceCadence: AutoAdvanceCadence
    /// The wallpaper scene the user had selected when progression was set up.
    /// Turning progression off restores this scene so the desktop returns to
    /// what the user last chose rather than staying on a generated level.
    public var baseSceneKey: String?

    public init(
        isEnabled: Bool = true,
        level: Int = 0,
        profile: GardenProgressionProfile,
        startedAt: Date = Date(),
        lastAdvancedAt: Date? = nil,
        autoAdvanceCadence: AutoAdvanceCadence = .off,
        baseSceneKey: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.level = Self.clampedLevel(level)
        self.profile = profile
        self.startedAt = startedAt
        self.lastAdvancedAt = lastAdvancedAt
        self.autoAdvanceCadence = autoAdvanceCadence
        self.baseSceneKey = baseSceneKey
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case level
        case profile
        case startedAt
        case lastAdvancedAt
        case autoAdvanceCadence
        case baseSceneKey
    }

    // Custom decode keeps profiles saved before auto-advance existed loadable:
    // a missing cadence key defaults to `.off` instead of failing the decode.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isEnabled: try container.decode(Bool.self, forKey: .isEnabled),
            level: try container.decode(Int.self, forKey: .level),
            profile: try container.decode(GardenProgressionProfile.self, forKey: .profile),
            startedAt: try container.decode(Date.self, forKey: .startedAt),
            lastAdvancedAt: try container.decodeIfPresent(Date.self, forKey: .lastAdvancedAt),
            autoAdvanceCadence: try container.decodeIfPresent(AutoAdvanceCadence.self, forKey: .autoAdvanceCadence) ?? .off,
            baseSceneKey: try container.decodeIfPresent(String.self, forKey: .baseSceneKey)
        )
    }

    public var nextLevel: Int {
        min(Self.maximumLevel, level + 1)
    }

    public var canAdvance: Bool {
        isEnabled && level < Self.maximumLevel
    }

    public func advanced(at date: Date = Date()) -> GardenSceneProgression {
        GardenSceneProgression(
            isEnabled: isEnabled,
            level: nextLevel,
            profile: profile,
            startedAt: startedAt,
            lastAdvancedAt: date,
            autoAdvanceCadence: autoAdvanceCadence,
            baseSceneKey: baseSceneKey
        )
    }

    /// Returns a copy with progression paused or resumed, preserving the
    /// earned level, fantasy profile, and timestamps.
    public func settingEnabled(_ isEnabled: Bool) -> GardenSceneProgression {
        GardenSceneProgression(
            isEnabled: isEnabled,
            level: level,
            profile: profile,
            startedAt: startedAt,
            lastAdvancedAt: lastAdvancedAt,
            autoAdvanceCadence: autoAdvanceCadence,
            baseSceneKey: baseSceneKey
        )
    }

    /// Returns a copy with a new auto-advance cadence, preserving everything else.
    public func settingAutoAdvanceCadence(_ cadence: AutoAdvanceCadence) -> GardenSceneProgression {
        GardenSceneProgression(
            isEnabled: isEnabled,
            level: level,
            profile: profile,
            startedAt: startedAt,
            lastAdvancedAt: lastAdvancedAt,
            autoAdvanceCadence: cadence,
            baseSceneKey: baseSceneKey
        )
    }

    /// True when an enabled, advanceable ladder with a cadence has gone long
    /// enough since its last advance (or start) to earn its next level.
    public func isAutoAdvanceDue(now: Date = Date()) -> Bool {
        guard canAdvance, let interval = autoAdvanceCadence.interval else {
            return false
        }
        let reference = lastAdvancedAt ?? startedAt
        return now.timeIntervalSince(reference) >= interval
    }

    public static func clampedLevel(_ level: Int) -> Int {
        min(max(0, level), maximumLevel)
    }

    public static func title(for level: Int, experienceMode: GardenExperienceMode) -> String {
        let safeLevel = clampedLevel(level)
        return switch (experienceMode, safeLevel) {
        case (_, 0):
            "Not Started"
        case (.garden, 1):
            "Bare Soil Patch"
        case (.garden, 2...4):
            "First Real Garden"
        case (.garden, 5...8):
            "Designed Courtyard"
        case (.garden, 9...12):
            "Private Estate Garden"
        case (.garden, 13...16):
            "Grand Botanical Grounds"
        case (.garden, 17...19):
            "Legendary Estate"
        case (.garden, 20):
            "Sultan-Level Paradise"
        case (.roomStudio, 1):
            "Bare First Room"
        case (.roomStudio, 2...4):
            "Cozy Starter Room"
        case (.roomStudio, 5...8):
            "Curated Hangout"
        case (.roomStudio, 9...12):
            "Designer Apartment"
        case (.roomStudio, 13...16):
            "Luxury Residence"
        case (.roomStudio, 17...19):
            "Dream Compound"
        case (.roomStudio, 20):
            "Absurd Palace Suite"
        case (.alienUFO, 1):
            "Bare Crater Plot"
        case (.alienUFO, 2...4):
            "First Alien Habitat"
        case (.alienUFO, 5...8):
            "UFO Botany Lab"
        case (.alienUFO, 9...12):
            "Exoplanet Oasis"
        case (.alienUFO, 13...16):
            "Interstellar Conservatory"
        case (.alienUFO, 17...19):
            "Galactic Bio-Dome Estate"
        case (.alienUFO, 20):
            "Supreme Cosmic Garden"
        default:
            "Level \(safeLevel)"
        }
    }
}
