import Foundation

public enum GardenDewMood: String, Codable, Sendable {
    case none
    case morningDew
    case freshlyWatered
}

public struct GardenDewCondition: Equatable, Sendable {
    public let mood: GardenDewMood
    public let intensity: Double

    public init(
        state: GardenState,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) {
        let hour = calendar.component(.hour, from: date)
        let moisture = state.ambientMoisture.clampedUnit
        let isMorning = (5..<10).contains(hour)

        if isMorning && moisture >= 0.42 {
            mood = .morningDew
            intensity = (0.28 + moisture * 0.62).clampedUnit
        } else if moisture >= 0.82 {
            mood = .freshlyWatered
            intensity = ((moisture - 0.70) / 0.30).clampedUnit
        } else {
            mood = .none
            intensity = 0
        }
    }

    public var isVisible: Bool {
        intensity > 0
    }

    public var summary: String {
        switch mood {
        case .none:
            "No dew"
        case .morningDew:
            "Morning dew"
        case .freshlyWatered:
            "Fresh moisture"
        }
    }
}

public extension GardenState {
    func dewCondition(
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> GardenDewCondition {
        GardenDewCondition(state: self, at: date, calendar: calendar)
    }
}
