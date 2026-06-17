import Foundation

public enum GardenWeatherKind: String, Codable, CaseIterable, Sendable {
    case clear
    case partlyCloudy
    case overcast
    case fog
    case drizzle
    case rain
    case snow
    case storm

    /// Maps a WMO weather interpretation code (as served by Open-Meteo)
    /// to a garden weather kind.
    public static func fromWMOCode(_ code: Int) -> GardenWeatherKind {
        switch code {
        case 0:
            .clear
        case 1, 2:
            .partlyCloudy
        case 3:
            .overcast
        case 45, 48:
            .fog
        case 51...57:
            .drizzle
        case 61...67, 80...82:
            .rain
        case 71...77, 85, 86:
            .snow
        case 95...99:
            .storm
        default:
            .partlyCloudy
        }
    }

    public var displayName: String {
        switch self {
        case .clear:
            "Clear"
        case .partlyCloudy:
            "Partly cloudy"
        case .overcast:
            "Overcast"
        case .fog:
            "Fog"
        case .drizzle:
            "Drizzle"
        case .rain:
            "Rain"
        case .snow:
            "Snow"
        case .storm:
            "Storm"
        }
    }

    public var symbolName: String {
        switch self {
        case .clear:
            "sun.max.fill"
        case .partlyCloudy:
            "cloud.sun.fill"
        case .overcast:
            "cloud.fill"
        case .fog:
            "cloud.fog.fill"
        case .drizzle:
            "cloud.drizzle.fill"
        case .rain:
            "cloud.rain.fill"
        case .snow:
            "cloud.snow.fill"
        case .storm:
            "cloud.bolt.rain.fill"
        }
    }
}

/// A snapshot of real-world weather applied to the garden simulation.
/// Rain gently waters plants, fog raises ambient moisture, snow slows growth.
public struct GardenWeatherCondition: Codable, Equatable, Sendable {
    /// Conditions older than this no longer influence the simulation.
    public static let staleAfterSeconds: TimeInterval = 3 * 60 * 60
    /// How long after rain ends a rainbow can hang over the garden.
    public static let rainbowWindowSeconds: TimeInterval = 12 * 60

    public let kind: GardenWeatherKind
    public let temperatureCelsius: Double
    public let fetchedAt: Date
    /// When the most recent precipitation ended, carried across fetches by
    /// the weather service so the garden can celebrate the clearing sky.
    public let precipitationEndedAt: Date?

    public init(
        kind: GardenWeatherKind,
        temperatureCelsius: Double,
        fetchedAt: Date,
        precipitationEndedAt: Date? = nil
    ) {
        self.kind = kind
        self.temperatureCelsius = temperatureCelsius
        self.fetchedAt = fetchedAt
        self.precipitationEndedAt = precipitationEndedAt
    }

    public func isStale(at date: Date = Date()) -> Bool {
        date.timeIntervalSince(fetchedAt) > Self.staleAfterSeconds
    }

    public func recentlyStoppedPrecipitating(at date: Date = Date()) -> Bool {
        guard let precipitationEndedAt else {
            return false
        }

        let elapsed = date.timeIntervalSince(precipitationEndedAt)
        return elapsed >= 0 && elapsed < Self.rainbowWindowSeconds
    }

    /// The ambient moisture level the garden drifts toward in this weather.
    public var ambientMoistureTarget: Double {
        switch kind {
        case .clear:
            0.32
        case .partlyCloudy:
            0.38
        case .overcast:
            0.44
        case .fog:
            0.58
        case .drizzle:
            0.62
        case .rain:
            0.78
        case .snow:
            0.48
        case .storm:
            0.85
        }
    }

    /// Multiplier applied to growth speed in this weather.
    public var growthFactor: Double {
        switch kind {
        case .clear:
            1.05
        case .partlyCloudy:
            1.0
        case .overcast:
            0.94
        case .fog:
            0.90
        case .drizzle:
            1.02
        case .rain:
            1.04
        case .snow:
            0.72
        case .storm:
            0.90
        }
    }

    /// Hydration gained by plants per hour from precipitation.
    public var hydrationPerHour: Double {
        switch kind {
        case .drizzle:
            0.025
        case .rain:
            0.05
        case .storm:
            0.08
        case .snow:
            0.01
        case .clear, .partlyCloudy, .overcast, .fog:
            0
        }
    }

    public var isPrecipitating: Bool {
        hydrationPerHour > 0
    }

    public var summary: String {
        "\(kind.displayName), \(Int(temperatureCelsius.rounded()))°C"
    }
}
