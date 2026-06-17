import Foundation

public enum GardenInteractionTarget: Equatable, Sendable {
    case inspectorAction
    case plant
    case none
}

public enum GardenInteractionPriority {
    public static func target(hasInspectorAction: Bool, hasPlant: Bool) -> GardenInteractionTarget {
        if hasInspectorAction {
            return .inspectorAction
        }

        if hasPlant {
            return .plant
        }

        return .none
    }

    public static func shouldClearSelection(
        hasSelectedPlant: Bool,
        candidateContainsSelectionSurface: [Bool]
    ) -> Bool {
        hasSelectedPlant && !candidateContainsSelectionSurface.contains(true)
    }
}
