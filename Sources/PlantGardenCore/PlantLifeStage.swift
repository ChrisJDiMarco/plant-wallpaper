import Foundation

public struct PlantLifeStage: Equatable, Sendable {
    public let stageIndex: Int
    public let stageCount: Int
    public let stageNumber: Int
    public let title: String

    public init(
        species: PlantSpecies,
        assetStage: PlantAssetStage,
        stageCount: Int = PlantAssetStage.defaultStageCount
    ) {
        self.init(species: species, stageIndex: assetStage.index, stageCount: stageCount)
    }

    public init(
        species: PlantSpecies,
        stageIndex: Int,
        stageCount: Int = PlantAssetStage.defaultStageCount
    ) {
        let safeStageCount = max(1, stageCount)
        let safeIndex = min(max(0, stageIndex), safeStageCount - 1)
        let titles = Self.titles(for: species)

        self.stageIndex = safeIndex
        self.stageCount = safeStageCount
        self.stageNumber = safeIndex + 1
        self.title = titles[min(safeIndex, titles.count - 1)]
    }

    public var label: String {
        "\(title) \(stageNumber)/\(stageCount)"
    }

    private static func titles(for species: PlantSpecies) -> [String] {
        switch species.kind {
        case .tree:
            [
                "Seedling",
                "Sapling",
                "Young tree",
                "Branching",
                "Canopy forming",
                "Established",
                "Canopy filling",
                "Maturing",
                "Full canopy",
                "Specimen"
            ]
        case .foliage:
            [
                "Cutting",
                "Rooting",
                "New fronds",
                "Leaf set",
                "Filling out",
                "Established",
                "Lush growth",
                "Full foliage",
                "Mature foliage",
                "Specimen"
            ]
        case .edible:
            [
                "Seed",
                "Sprout",
                "Leaf set",
                "Branching",
                "Budding",
                "Flowering",
                "Fruit set",
                "Filling out",
                "Ripening",
                "Harvest ready"
            ]
        case .flower:
            [
                "Seedling",
                "Sprout",
                "Leaf set",
                "Stem rise",
                "Bud forming",
                "Bud swelling",
                "First color",
                "Blooming",
                "Full bloom",
                "Peak bloom"
            ]
        case .meadow:
            [
                "Seed mix",
                "First shoots",
                "Green patch",
                "Stem rise",
                "Buds forming",
                "First flowers",
                "Wild color",
                "Flowering mat",
                "Full meadow",
                "Peak meadow"
            ]
        }
    }
}
