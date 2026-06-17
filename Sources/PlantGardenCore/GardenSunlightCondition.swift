import Foundation

public enum GardenSunlightMood: String, Codable, Sendable {
    case morning
    case bright
    case golden
    case night
}

public struct GardenSunlightCondition: Equatable, Sendable {
    public let mood: GardenSunlightMood
    public let intensity: Double
    public let summary: String

    public init(at date: Date = Date(), calendar: Calendar = .current) {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<10:
            mood = .morning
            intensity = 0.56
            summary = "Morning light"
        case 10..<17:
            mood = .bright
            intensity = 0.92
            summary = "Bright light"
        case 17..<21:
            mood = .golden
            intensity = 0.68
            summary = "Golden light"
        default:
            mood = .night
            intensity = 0.12
            summary = "Night rest"
        }
    }
}

public extension GardenState {
    func sunlightCondition(
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> GardenSunlightCondition {
        GardenSunlightCondition(at: date, calendar: calendar)
    }
}
