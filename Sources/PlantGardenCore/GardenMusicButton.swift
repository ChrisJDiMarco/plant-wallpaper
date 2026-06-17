import Foundation

public struct GardenMusicButton: Codable, Equatable, Sendable {
    public var screenIndex: Int
    public var position: GardenPoint
    public var companion: GardenRadioCompanion

    public init(
        screenIndex: Int = 0,
        position: GardenPoint = GardenPoint(x: 0.82, y: 0.72),
        companion: GardenRadioCompanion = .gardenCat
    ) {
        self.screenIndex = max(0, screenIndex)
        self.position = position.clamped
        self.companion = companion
    }

    private enum CodingKeys: String, CodingKey {
        case screenIndex
        case position
        case companion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            screenIndex: try container.decodeIfPresent(Int.self, forKey: .screenIndex) ?? 0,
            position: try container.decodeIfPresent(GardenPoint.self, forKey: .position)
                ?? GardenPoint(x: 0.82, y: 0.72),
            companion: try container.decodeIfPresent(GardenRadioCompanion.self, forKey: .companion)
                ?? .gardenCat
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(screenIndex, forKey: .screenIndex)
        try container.encode(position, forKey: .position)
        try container.encode(companion, forKey: .companion)
    }
}
