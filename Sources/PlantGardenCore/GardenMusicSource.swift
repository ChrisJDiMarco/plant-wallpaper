import Foundation

public enum GardenMusicSource: String, Codable, CaseIterable, Sendable {
    case chillHopRadio
    case spotify

    public var displayName: String {
        switch self {
        case .chillHopRadio:
            "ChillHop Radio"
        case .spotify:
            "Spotify"
        }
    }
}
