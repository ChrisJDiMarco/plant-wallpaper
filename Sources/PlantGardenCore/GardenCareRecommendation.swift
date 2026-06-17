import Foundation

public enum GardenCareRecommendationKind: String, Codable, Sendable {
    case plantFirst
    case removeDead
    case waterThirsty
    case prune
    case nourish
    case enjoy
}

public struct GardenCareRecommendation: Equatable, Sendable {
    public let kind: GardenCareRecommendationKind
    public let targetPlantID: UUID?
    public let summary: String
    public let detail: String

    public init(state: GardenState) {
        if state.plants.isEmpty {
            kind = .plantFirst
            targetPlantID = nil
            summary = "Plant something"
            detail = "Start the garden"
            return
        }

        if let deadPlant = state.plants.first(where: { $0.isDead && !Self.isDesignProtected($0, in: state) }) {
            kind = .removeDead
            targetPlantID = deadPlant.id
            summary = "Remove \(deadPlant.nickname)"
            detail = "Clear dead plant"
            return
        }

        let thirstyPlants = state.thirstyPlants
        if !thirstyPlants.isEmpty {
            kind = .waterThirsty
            targetPlantID = nil
            summary = thirstyPlants.count == 1 ? "Water 1 thirsty plant" : "Water \(thirstyPlants.count) thirsty plants"
            detail = "Restore hydration"
            return
        }

        if let recoveringPlant = state.plants.first(where: {
            $0.careNeed == .recovering && !Self.isDesignProtected($0, in: state)
        }) {
            kind = .prune
            targetPlantID = recoveringPlant.id
            summary = "Prune \(recoveringPlant.nickname)"
            detail = "Help it recover"
            return
        }

        if let feedReadyPlant = state.plants.first(where: { $0.careNeed == .nourish }) {
            kind = .nourish
            targetPlantID = feedReadyPlant.id
            summary = "Nourish \(feedReadyPlant.nickname)"
            detail = "Push toward next stage"
            return
        }

        kind = .enjoy
        targetPlantID = nil
        summary = "Enjoy the garden"
        detail = "Everything is steady"
    }

    private static func isDesignProtected(_ plant: Plant, in state: GardenState) -> Bool {
        let effect = plant.companionEffect(in: state)
        let affinity = plant.bedAffinity

        if plant.species.isSupportTrainedClimber {
            return affinity.fit == .support || effect.relationship == .trainedClimber
        }

        return plant.species.isNaturalizingGroundcover && effect.relationship == .naturalizedPatch
    }

    public var isActionable: Bool {
        kind != .enjoy
    }
}

public extension GardenState {
    var careRecommendation: GardenCareRecommendation {
        GardenCareRecommendation(state: self)
    }
}
