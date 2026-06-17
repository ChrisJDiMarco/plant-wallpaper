import Foundation

/// Occasional ambient events that make the garden feel alive: a firefly
/// night, a butterfly migration crossing the screen, a rainbow after rain.
///
/// Moments are derived deterministically from the calendar day plus a
/// per-day pseudo-random roll, so every machine showing the same garden on
/// the same day sees the same moment, no state or scheduling required.
public enum GardenRareMomentKind: String, CaseIterable, Sendable {
    case fireflyNight
    case butterflyMigration
    case rainbow

    public var title: String {
        switch self {
        case .fireflyNight:
            "Firefly night"
        case .butterflyMigration:
            "Butterfly migration"
        case .rainbow:
            "A rainbow over the garden"
        }
    }

    public var celebrationText: String {
        switch self {
        case .fireflyNight:
            "The garden is glowing tonight - fireflies are out in force."
        case .butterflyMigration:
            "A migration is passing through your garden right now."
        case .rainbow:
            "The rain has passed and left a rainbow over your plants."
        }
    }
}

public struct GardenRareMoment: Equatable, Sendable {
    public let kind: GardenRareMomentKind
    /// 0...1 progress through the moment's window, for animation easing.
    public let progress: Double

    public init(kind: GardenRareMomentKind, progress: Double) {
        self.kind = kind
        self.progress = min(1, max(0, progress))
    }

    /// The moment active at `date`, if any.
    ///
    /// - Firefly nights: ~1 evening in 4, between 21:00 and 23:00.
    /// - Butterfly migrations: ~1 day in 6, a 20-minute crossing in the
    ///   early afternoon.
    /// - Rainbow: whenever rain stopped within the last 12 minutes while
    ///   the sun is up (driven by the live weather feed).
    public static func activeMoment(
        at date: Date = Date(),
        weather: GardenWeatherCondition? = nil,
        calendar: Calendar = .current
    ) -> GardenRareMoment? {
        if let rainbow = rainbowMoment(at: date, weather: weather, calendar: calendar) {
            return rainbow
        }

        let day = dayOrdinal(of: date, calendar: calendar)
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let minuteOfDay = hour * 60 + minute

        if dailyRoll(day: day, salt: 11) % 4 == 0, hour >= 21, hour < 23 {
            let windowStart = 21 * 60
            let progress = Double(minuteOfDay - windowStart) / 120
            return GardenRareMoment(kind: .fireflyNight, progress: progress)
        }

        if dailyRoll(day: day, salt: 29) % 6 == 0 {
            let startMinute = 13 * 60 + Int(dailyRoll(day: day, salt: 47) % 90)
            if minuteOfDay >= startMinute, minuteOfDay < startMinute + 20 {
                let progress = Double(minuteOfDay - startMinute) / 20
                return GardenRareMoment(kind: .butterflyMigration, progress: progress)
            }
        }

        return nil
    }

    private static func rainbowMoment(
        at date: Date,
        weather: GardenWeatherCondition?,
        calendar: Calendar
    ) -> GardenRareMoment? {
        guard let weather,
              !weather.isPrecipitating,
              let precipitationEndedAt = weather.precipitationEndedAt,
              weather.recentlyStoppedPrecipitating(at: date) else {
            return nil
        }

        let hour = calendar.component(.hour, from: date)
        guard hour >= 7, hour < 19 else {
            return nil
        }

        let elapsed = date.timeIntervalSince(precipitationEndedAt)
        return GardenRareMoment(kind: .rainbow, progress: elapsed / GardenWeatherCondition.rainbowWindowSeconds)
    }

    private static func dayOrdinal(of date: Date, calendar: Calendar) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    private static func dailyRoll(day: Int, salt: UInt64) -> UInt64 {
        var value = UInt64(bitPattern: Int64(day)) &* 6_364_136_223_846_793_005 &+ salt
        value ^= value >> 33
        value = value &* 0xFF51_AFD7_ED55_8CCD
        value ^= value >> 33
        return value
    }
}
