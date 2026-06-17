import Foundation

public enum PlantCompanionRelationship: String, Codable, Sendable {
    case neutral
    case shelteredUnderstory
    case companionBloom
    case diverseCluster
    case trainedClimber
    case naturalizedPatch
    case crowded
}

public struct PlantCompanionEffect: Equatable, Sendable {
    public let relationship: PlantCompanionRelationship
    public let neighborCount: Int
    public let diverseKindCount: Int
    public let sameKindCrowdingCount: Int
    public let growthMultiplier: Double
    public let waterUseMultiplier: Double
    public let bloomMultiplier: Double
    public let healthAdjustmentPerHour: Double
    public let summary: String
    public let shortSummary: String

    public init(plant: Plant, state: GardenState) {
        let nearbyPlants = state.plants.filter { candidate in
            candidate.id != plant.id
                && candidate.screenIndex == plant.screenIndex
                && Self.distance(plant.position, candidate.position) <= Self.neighborRadius(for: plant, other: candidate)
        }
        let crowdedPlants = nearbyPlants.filter {
            $0.species.kind == plant.species.kind
                && Self.distance(plant.position, $0.position) <= Self.crowdingRadius(for: plant.species.kind)
        }
        let sameSpeciesClusterCount = nearbyPlants.filter {
            $0.species == plant.species
                && Self.distance(plant.position, $0.position) <= Self.clusteringRadius(for: plant.species)
        }.count
        let nearbyKinds = Set(nearbyPlants.map(\.species.kind))
        let treeShelterCount = nearbyPlants.filter { $0.species.kind == .tree }.count
        let floweringNeighborCount = nearbyPlants.filter {
            $0.species.kind == .flower || $0.species.kind == .meadow
        }.count

        neighborCount = nearbyPlants.count
        diverseKindCount = nearbyKinds.subtracting([plant.species.kind]).count
        sameKindCrowdingCount = crowdedPlants.count

        if plant.species.isSupportTrainedClimber && sameSpeciesClusterCount >= 2 {
            relationship = .trainedClimber
            growthMultiplier = 1.03
            waterUseMultiplier = 0.96
            bloomMultiplier = 1.06
            healthAdjustmentPerHour = 0.003
            summary = "Trained on support"
            shortSummary = "On support"
        } else if plant.species.isNaturalizingGroundcover && sameSpeciesClusterCount >= 2 {
            relationship = .naturalizedPatch
            growthMultiplier = 1.02
            waterUseMultiplier = 0.98
            bloomMultiplier = 1.04
            healthAdjustmentPerHour = 0.002
            summary = "Naturalized patch"
            shortSummary = "Naturalized"
        } else if sameKindCrowdingCount >= 2 {
            relationship = .crowded
            growthMultiplier = 0.88
            waterUseMultiplier = 1.08
            bloomMultiplier = 0.86
            healthAdjustmentPerHour = -0.012
            summary = "Crowded roots"
            shortSummary = "Crowded"
        } else if plant.species.kind == .foliage && treeShelterCount > 0 {
            relationship = .shelteredUnderstory
            growthMultiplier = 1.04
            waterUseMultiplier = 0.90
            bloomMultiplier = 1.02
            healthAdjustmentPerHour = 0.004
            summary = "Sheltered understory"
            shortSummary = "Sheltered"
        } else if (plant.species.kind == .flower || plant.species.kind == .meadow)
                    && floweringNeighborCount >= 2 {
            relationship = .companionBloom
            growthMultiplier = 1.05
            waterUseMultiplier = 1.02
            bloomMultiplier = 1.18
            healthAdjustmentPerHour = 0.002
            summary = "Companion bloom"
            shortSummary = "Companion bloom"
        } else if neighborCount >= 2 && diverseKindCount >= 2 {
            relationship = .diverseCluster
            growthMultiplier = 1.03
            waterUseMultiplier = 0.98
            bloomMultiplier = 1.08
            healthAdjustmentPerHour = 0.002
            summary = "Diverse planting"
            shortSummary = "Diverse cluster"
        } else {
            relationship = .neutral
            growthMultiplier = 1
            waterUseMultiplier = 1
            bloomMultiplier = 1
            healthAdjustmentPerHour = 0
            summary = "Room to grow"
            shortSummary = "Room to grow"
        }
    }

    private static func distance(_ lhs: GardenPoint, _ rhs: GardenPoint) -> Double {
        let dx = lhs.x - rhs.x
        let dy = (lhs.y - rhs.y) * 0.68
        return hypot(dx, dy)
    }

    private static func neighborRadius(for plant: Plant, other: Plant) -> Double {
        max(baseNeighborRadius(for: plant.species.kind), baseNeighborRadius(for: other.species.kind))
    }

    private static func baseNeighborRadius(for kind: PlantKind) -> Double {
        switch kind {
        case .tree:
            0.16
        case .meadow:
            0.13
        case .foliage:
            0.11
        case .edible:
            0.105
        case .flower:
            0.10
        }
    }

    private static func crowdingRadius(for kind: PlantKind) -> Double {
        switch kind {
        case .tree:
            0.095
        case .meadow:
            0.082
        case .foliage:
            0.070
        case .edible:
            0.066
        case .flower:
            0.060
        }
    }

    private static func clusteringRadius(for species: PlantSpecies) -> Double {
        if species.isSupportTrainedClimber {
            return 0.135
        }

        if species.isNaturalizingGroundcover {
            return 0.115
        }

        return crowdingRadius(for: species.kind)
    }
}

public extension Plant {
    func companionEffect(in state: GardenState) -> PlantCompanionEffect {
        PlantCompanionEffect(plant: self, state: state)
    }
}
