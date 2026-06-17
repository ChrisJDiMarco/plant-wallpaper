import Foundation

public enum GardenWildlifeKind: Sendable, Equatable {
    case butterfly
    case bee
    case hoverfly
    case firefly

    public var wingFlapsPerSecond: Double {
        switch self {
        case .butterfly:
            8.5
        case .bee:
            46.0
        case .hoverfly:
            38.0
        case .firefly:
            12.0
        }
    }

    public var maxRenderedWingspanPoints: Double {
        switch self {
        case .butterfly:
            7.2
        case .bee:
            4.4
        case .hoverfly:
            3.8
        case .firefly:
            3.2
        }
    }
}

public struct GardenWildlifeSample: Sendable, Equatable {
    public let kind: GardenWildlifeKind
    public let offset: GardenPoint
    public let altitudeFraction: Double
    public let scale: Double
    public let headingDegrees: Double
    public let wingOpen: Double
    public let wingBlur: Double
    public let pulse: Double

    public init(
        kind: GardenWildlifeKind,
        offset: GardenPoint,
        altitudeFraction: Double,
        scale: Double,
        headingDegrees: Double,
        wingOpen: Double,
        wingBlur: Double,
        pulse: Double
    ) {
        self.kind = kind
        self.offset = offset
        self.altitudeFraction = altitudeFraction
        self.scale = scale
        self.headingDegrees = headingDegrees
        self.wingOpen = wingOpen
        self.wingBlur = wingBlur
        self.pulse = pulse
    }
}

public enum GardenWildlifeMotion {
    public static func pollinatorCount(
        floweringPlantCount: Int,
        wildlifeDensity: Double,
        hasPlants: Bool,
        isEnabled: Bool = true
    ) -> Int {
        guard isEnabled, hasPlants, wildlifeDensity > 0.10 else {
            return 0
        }

        let visibleDensity = max(0.35, wildlifeDensity)
        let rawCount = Double(max(3, floweringPlantCount + 2)) * visibleDensity * 0.72
        return min(5, max(3, Int(rawCount.rounded(.toNearestOrAwayFromZero))))
    }

    public static func sample(
        index: Int,
        time: Double,
        wildlifeDensity: Double,
        hostHeight: Double,
        isNight: Bool
    ) -> GardenWildlifeSample {
        let kind = kind(for: index, isNight: isNight)
        let scale = scale(for: kind, index: index, wildlifeDensity: wildlifeDensity)
        let flightOffset = offset(index: index, time: time, hostHeight: hostHeight, kind: kind)
        let nextOffset = offset(index: index, time: time + 0.08, hostHeight: hostHeight, kind: kind)
        let heading = atan2(nextOffset.y - flightOffset.y, nextOffset.x - flightOffset.x) * 180 / .pi
        let wing = wingState(kind: kind, index: index, time: time)

        return GardenWildlifeSample(
            kind: kind,
            offset: flightOffset,
            altitudeFraction: altitudeFraction(for: kind, index: index),
            scale: scale,
            headingDegrees: heading,
            wingOpen: wing.open,
            wingBlur: wing.blur,
            pulse: wing.pulse
        )
    }

    private static func kind(for index: Int, isNight: Bool) -> GardenWildlifeKind {
        if isNight {
            return .firefly
        }

        switch index % 5 {
        case 0:
            return .butterfly
        case 1, 3:
            return .bee
        default:
            return .hoverfly
        }
    }

    private static func scale(
        for kind: GardenWildlifeKind,
        index: Int,
        wildlifeDensity: Double
    ) -> Double {
        let variation = normalizedWave(seed: 3_911, index: index)
        let densityTrim = max(0, wildlifeDensity - 0.45) * 0.08
        let base: Double
        let spread: Double
        switch kind {
        case .butterfly:
            base = 0.52
            spread = 0.16
        case .bee:
            base = 0.42
            spread = 0.12
        case .hoverfly:
            base = 0.36
            spread = 0.10
        case .firefly:
            base = 0.34
            spread = 0.10
        }

        return max(0.30, min(0.70, base + variation * spread - densityTrim))
    }

    private static func altitudeFraction(for kind: GardenWildlifeKind, index: Int) -> Double {
        let base: Double
        switch kind {
        case .butterfly:
            base = 0.52
        case .bee:
            base = 0.42
        case .hoverfly:
            base = 0.36
        case .firefly:
            base = 0.44
        }

        return base + normalizedWave(seed: 4_127, index: index) * 0.10
    }

    private static func offset(
        index: Int,
        time: Double,
        hostHeight: Double,
        kind: GardenWildlifeKind
    ) -> GardenPoint {
        let seed = Double(index) * 1.618_033_988_75
        let speed = 0.46 + normalizedWave(seed: 5_003, index: index) * 0.20
        let loop = time * speed + seed
        let baseRadius = min(24, max(7, hostHeight * 0.10))
        let radius = baseRadius * (0.76 + normalizedWave(seed: 5_021, index: index) * 0.26)
        let hoverTightness: Double = kind == .hoverfly ? 0.58 : 1.0
        let x = (
            cos(loop) * radius
            + sin(loop * 0.43 + seed) * radius * 0.22
        ) * hoverTightness
        let y = (
            sin(loop * 1.62 + seed * 0.31) * radius * 0.30
            + sin(loop * 0.67 + seed) * 2.8
        ) * hoverTightness

        return GardenPoint(x: x, y: y)
    }

    private static func wingState(
        kind: GardenWildlifeKind,
        index: Int,
        time: Double
    ) -> (open: Double, blur: Double, pulse: Double) {
        let phase = time * kind.wingFlapsPerSecond * 2 * .pi + Double(index) * 0.71
        switch kind {
        case .butterfly:
            let open = 0.18 + pow(abs(sin(phase)), 0.70) * 0.82
            return (open, 0.10, 0.0)
        case .bee:
            let open = 0.44 + sin(phase) * 0.10
            return (open, 0.64, 0.0)
        case .hoverfly:
            let open = 0.40 + sin(phase) * 0.12
            return (open, 0.72, 0.0)
        case .firefly:
            let open = 0.32 + abs(sin(phase)) * 0.12
            let pulse = 0.18 + pow(abs(sin(time * 1.7 + Double(index))), 3.0) * 0.64
            return (open, 0.34, pulse)
        }
    }

    private static func normalizedWave(seed: Double, index: Int) -> Double {
        (sin(seed + Double(index) * 12.9898) + 1) / 2
    }
}
