import Foundation

public enum PlantDepthBand: String, Codable, Sendable {
    case background
    case midground
    case foreground
}

public struct PlantDepthProfile: Equatable, Sendable {
    public let band: PlantDepthBand
    public let depth: Double
    public let heightScale: Double
    public let shadowScale: Double
    public let shadowOpacityMultiplier: Double

    public init(positionY: Double) {
        let normalizedY = positionY.clampedUnit
        let sceneDepth = ((normalizedY - 0.52) / 0.40).clampedUnit
        depth = sceneDepth

        switch normalizedY {
        case ..<0.64:
            band = .background
        case 0.84...:
            band = .foreground
        default:
            band = .midground
        }

        heightScale = 0.82 + sceneDepth * 0.36
        shadowScale = 0.82 + sceneDepth * 0.42
        shadowOpacityMultiplier = 0.70 + sceneDepth * 0.50
    }
}

public extension Plant {
    var depthProfile: PlantDepthProfile {
        PlantDepthProfile(positionY: position.y)
    }
}
