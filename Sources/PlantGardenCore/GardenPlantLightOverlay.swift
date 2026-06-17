import Foundation

public struct GardenPlantLightOverlay: Equatable, Sendable {
    public let opacity: Double

    public init(sunlight: GardenSunlightCondition, manualDarkening: Double = 0) {
        let automaticOpacity: Double = switch sunlight.mood {
        case .bright:
            0
        case .morning:
            0.08
        case .golden:
            0.16
        case .night:
            0.50
        }

        opacity = (automaticOpacity + manualDarkening.clamped(to: 0...0.60))
            .clamped(to: 0...0.75)
    }

    public var signatureBucket: Int {
        Int((opacity * 1_000).rounded())
    }
}

public extension GardenState {
    func plantLightOverlay(
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> GardenPlantLightOverlay {
        GardenPlantLightOverlay(
            sunlight: sunlightCondition(at: date, calendar: calendar),
            manualDarkening: manualPlantDarkening
        )
    }
}
