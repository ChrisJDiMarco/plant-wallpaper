import Foundation

/// One line in the garden's diary: a planting, a growth milestone, a
/// harvest, a completed focus session, a weather event, or a rare moment.
public struct GardenJournalEntry: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case planted
        case milestone
        case harvest
        case focus
        case weather
        case moment
        case care
    }

    public var id: UUID
    public let date: Date
    public let kind: Kind
    public let text: String

    public init(id: UUID = UUID(), date: Date = Date(), kind: Kind, text: String) {
        self.id = id
        self.date = date
        self.kind = kind
        self.text = text
    }

    public var symbolName: String {
        switch kind {
        case .planted:
            "leaf.fill"
        case .milestone:
            "arrow.up.right.circle.fill"
        case .harvest:
            "basket.fill"
        case .focus:
            "timer"
        case .weather:
            "cloud.rain.fill"
        case .moment:
            "sparkles"
        case .care:
            "drop.fill"
        }
    }
}
