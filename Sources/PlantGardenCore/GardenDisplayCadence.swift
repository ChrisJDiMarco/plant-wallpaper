import Foundation

public enum GardenDisplayCadenceMood: String, Codable, Sendable {
    case calm
    case active
}

public struct GardenDisplayCadence: Equatable, Sendable {
    public static let calmRefreshInterval: TimeInterval = 2.0
    public static let activeRefreshInterval: TimeInterval = 0.5
    public static let wildlifeRefreshInterval: TimeInterval = 1.25

    public let mood: GardenDisplayCadenceMood
    public let refreshInterval: TimeInterval
    public let summary: String

    /// True while anything besides ambient wildlife is animating: recent
    /// tending, growth milestones, precipitation, or a focus session.
    /// Renderers use this to decide when plant artwork can be served from a
    /// cached layer (calm + wildlife-only) versus drawn live.
    public static func hasTransientActivity(
        state: GardenState,
        at date: Date = Date(),
        activeWindow: TimeInterval = 18,
        milestoneDuration: TimeInterval = 120
    ) -> Bool {
        let cadencePlants = plantsThatShouldDrivePlantCadence(in: state)
        let hasRecentTending = cadencePlants.contains { plant in
            let elapsed = date.timeIntervalSince(plant.lastTendedAt)
            return elapsed >= 0 && elapsed < activeWindow
        }
        let hasRecentMilestone = cadencePlants.contains {
            $0.growthMilestoneIntensity(at: date, duration: milestoneDuration) > 0
        }
        let hasAnimatedWeather = state.weather.map { weather in
            !weather.isStale(at: date) && weather.isPrecipitating
        } ?? false
        let hasActiveFocusSession = state.focusSession?.isActive(at: date) ?? false
        return hasRecentTending || hasRecentMilestone || hasAnimatedWeather || hasActiveFocusSession
    }

    private static func plantsThatShouldDrivePlantCadence(in state: GardenState) -> [Plant] {
        guard state.settings.experienceMode == .roomStudio else {
            return state.plants
        }

        // Generated Room Studio props are decorative cutouts, not living
        // plants. Treating a large custom shelf/rack/poster as a fresh
        // growth/tending event kept Room Studio in active redraw cadence
        // after placement, which made that mode feel heavier than Garden.
        return state.plants.filter { $0.customAssetID == nil }
    }

    public init(
        state: GardenState,
        at date: Date = Date(),
        activeWindow: TimeInterval = 18,
        milestoneDuration: TimeInterval = 120
    ) {
        // Wildlife no longer needs canvas repaints: bugs are Core Animation
        // layers animated by the render server, so their presence doesn't
        // force the active cadence anymore.
        if Self.hasTransientActivity(
            state: state,
            at: date,
            activeWindow: activeWindow,
            milestoneDuration: milestoneDuration
        ) {
            mood = .active
            refreshInterval = Self.activeRefreshInterval
            summary = "Tending refresh"
        } else {
            mood = .calm
            refreshInterval = Self.calmRefreshInterval
            summary = "Calm display"
        }
    }
}

public extension GardenState {
    func displayCadence(
        at date: Date = Date(),
        activeWindow: TimeInterval = 18,
        milestoneDuration: TimeInterval = 120
    ) -> GardenDisplayCadence {
        GardenDisplayCadence(
            state: self,
            at: date,
            activeWindow: activeWindow,
            milestoneDuration: milestoneDuration
        )
    }
}
