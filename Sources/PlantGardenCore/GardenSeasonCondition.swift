import Foundation

public enum GardenSeasonMood: String, Codable, Sendable {
    case spring
    case summer
    case autumn
    case winter
}

public struct GardenSeasonCondition: Equatable, Sendable {
    public let mood: GardenSeasonMood
    public let growthEnergy: Double
    public let summary: String

    public init(at date: Date = Date(), calendar: Calendar = .current) {
        let month = calendar.component(.month, from: date)
        switch month {
        case 3...5:
            mood = .spring
            growthEnergy = 0.78
            summary = "Spring renewal"
        case 6...8:
            mood = .summer
            growthEnergy = 0.94
            summary = "Summer canopy"
        case 9...11:
            mood = .autumn
            growthEnergy = 0.52
            summary = "Autumn color"
        default:
            mood = .winter
            growthEnergy = 0.22
            summary = "Winter rest"
        }
    }
}

public extension GardenState {
    func seasonCondition(
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> GardenSeasonCondition {
        GardenSeasonCondition(at: date, calendar: calendar)
    }
}
