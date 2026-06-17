import Foundation

public struct GardenLightProjection: Equatable, Sendable {
    public let shadowOffsetX: Double
    public let shadowOffsetY: Double
    public let shadowLengthMultiplier: Double
    public let shadowOpacityMultiplier: Double
    public let rimLightAlpha: Double

    public init(sunlight: GardenSunlightCondition) {
        switch sunlight.mood {
        case .morning:
            shadowOffsetX = 0.18
            shadowOffsetY = 0.05
            shadowLengthMultiplier = 1.34
            shadowOpacityMultiplier = 0.82
            rimLightAlpha = 0.052
        case .bright:
            shadowOffsetX = 0.02
            shadowOffsetY = 0.02
            shadowLengthMultiplier = 0.92
            shadowOpacityMultiplier = 1.10
            rimLightAlpha = 0.072
        case .golden:
            shadowOffsetX = -0.20
            shadowOffsetY = 0.06
            shadowLengthMultiplier = 1.42
            shadowOpacityMultiplier = 0.88
            rimLightAlpha = 0.064
        case .night:
            shadowOffsetX = 0.03
            shadowOffsetY = 0.01
            shadowLengthMultiplier = 1.12
            shadowOpacityMultiplier = 0.52
            rimLightAlpha = 0.012
        }
    }

    public init(
        shadowOffsetX: Double,
        shadowOffsetY: Double,
        shadowLengthMultiplier: Double,
        shadowOpacityMultiplier: Double,
        rimLightAlpha: Double
    ) {
        self.shadowOffsetX = shadowOffsetX
        self.shadowOffsetY = shadowOffsetY
        self.shadowLengthMultiplier = shadowLengthMultiplier
        self.shadowOpacityMultiplier = shadowOpacityMultiplier
        self.rimLightAlpha = rimLightAlpha
    }

    public func adjusted(
        additionalOffsetX: Double,
        additionalOffsetY: Double,
        lengthMultiplier: Double,
        opacityMultiplier: Double,
        rimLightMultiplier: Double
    ) -> GardenLightProjection {
        GardenLightProjection(
            shadowOffsetX: Self.bounded(shadowOffsetX + additionalOffsetX, lower: -0.34, upper: 0.34),
            shadowOffsetY: Self.bounded(shadowOffsetY + additionalOffsetY, lower: -0.02, upper: 0.12),
            shadowLengthMultiplier: Self.bounded(shadowLengthMultiplier * lengthMultiplier, lower: 0.64, upper: 1.86),
            shadowOpacityMultiplier: Self.bounded(shadowOpacityMultiplier * opacityMultiplier, lower: 0.30, upper: 1.36),
            rimLightAlpha: Self.bounded(rimLightAlpha * rimLightMultiplier, lower: 0.004, upper: 0.10)
        )
    }

    private static func bounded(_ value: Double, lower: Double, upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}

public extension GardenState {
    func lightProjection(
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> GardenLightProjection {
        GardenLightProjection(sunlight: sunlightCondition(at: date, calendar: calendar))
    }
}
