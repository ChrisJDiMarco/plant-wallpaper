import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant species biodiversity catalog")
struct PlantSpeciesBiodiversityTests {
    @Test("catalog includes the requested expanded plant set")
    func catalogIncludesRequestedExpandedPlantSet() {
        let requestedSpecies: Set<PlantSpecies> = [
            .mossCarpet,
            .cloverPatch,
            .creepingThyme,
            .ivy,
            .wisteria,
            .jasmine,
            .orchid,
            .bonsai,
            .japaneseMaple,
            .willow,
            .birch,
            .dogwood,
            .magnolia,
            .oliveTree,
            .dwarfCitrus,
            .hydrangea,
            .peony,
            .rose,
            .foxglove,
            .poppy,
            .iris,
            .lily,
            .lavenderField,
            .herbCluster,
            .bamboo,
            .ornamentalGrass,
            .cattails,
            .mushrooms,
            .lichens,
            .succulent,
            .pitcherPlant,
            .waterLily,
            .determinateTomato,
            .sweetPepper,
            .peaVines,
            .stringBeans,
            .cucumberVine,
            .rosemary,
            .thyme,
            .oregano,
            .sage,
            .ghostOrchid,
            .jadeVine,
            .corpseFlower,
            .queenOfTheNight,
            .chocolateCosmos,
            .baobab,
            .dragonBloodTree,
            .rainbowEucalyptus,
            .monkeyPuzzleTree,
            .silkFlossTree,
            .alocasiaDragonScale,
            .ravenZZPlant,
            .prayerPlant,
            .staghornFern,
            .blackCoralColocasia,
            .blueStarCreeper,
            .silverFallsDichondra,
            .corsicanMint,
            .redVeinSorrelPatch,
            .alpineEdelweissMat,
            .dragonFruitCactus,
            .purpleBasil,
            .shiso,
            .saffronCrocus,
            .wasabi,
            .alpineStrawberry,
            .glassGemCorn,
            .cucamelon
        ]

        #expect(Set(PlantSpecies.allCases).isSuperset(of: requestedSpecies))
        #expect(requestedSpecies.allSatisfy { !$0.displayName.isEmpty })
    }

    @Test("quick planting buckets expose flowers trees foliage and groundcovers")
    func quickPlantingBucketsExposeExpandedSpecies() {
        #expect(PlantSpecies.flowers.contains(.wisteria))
        #expect(PlantSpecies.flowers.contains(.rose))
        #expect(PlantSpecies.trees.contains(.japaneseMaple))
        #expect(PlantSpecies.trees.contains(.willow))
        #expect(PlantSpecies.foliage.contains(.bamboo))
        #expect(PlantSpecies.foliage.contains(.pitcherPlant))
        #expect(PlantSpecies.meadows.contains(.waterLily))
        #expect(PlantSpecies.meadows.contains(.cattails))
        #expect(PlantSpecies.edibles.contains(.determinateTomato))
        #expect(PlantSpecies.edibles.contains(.sweetPepper))
        #expect(PlantSpecies.edibles.contains(.cucumberVine))
        #expect(PlantSpecies.edibles.contains(.rosemary))
        #expect(PlantSpecies.edibles.contains(.sage))
        #expect(PlantSpecies.flowers.contains(.ghostOrchid))
        #expect(PlantSpecies.trees.contains(.dragonBloodTree))
        #expect(PlantSpecies.foliage.contains(.alocasiaDragonScale))
        #expect(PlantSpecies.meadows.contains(.silverFallsDichondra))
        #expect(PlantSpecies.edibles.contains(.dragonFruitCactus))
        #expect(PlantSpecies.artworkPlaceholderSpecies.isEmpty)
    }

    @Test("default garden keeps curated starter biodiversity")
    func defaultGardenKeepsCuratedStarterBiodiversity() {
        let garden = GardenState.defaultGarden(screenCount: 2)
        let defaultSpecies = Set(garden.plants.map(\.species))

        #expect(defaultSpecies == Set(PlantSpecies.defaultGardenSpecies))
        #expect(!defaultSpecies.contains(.ghostOrchid))
        #expect(!defaultSpecies.contains(.baobab))
        #expect(!defaultSpecies.contains(.dragonFruitCactus))
        #expect(garden.plants.allSatisfy { $0.compositionVersionSafeScreenIndex })
    }

    @Test("room studio indoor plant catalog stays room appropriate")
    func roomStudioIndoorPlantCatalogStaysRoomAppropriate() {
        #expect(PlantSpecies.roomStudioIndoorSpecies.contains(.monstera))
        #expect(PlantSpecies.roomStudioIndoorSpecies.contains(.fern))
        #expect(PlantSpecies.roomStudioIndoorSpecies.contains(.succulent))
        #expect(PlantSpecies.roomStudioIndoorSpecies.contains(.orchid))
        #expect(PlantSpecies.roomStudioIndoorSpecies.contains(.bonsai))
        #expect(PlantSpecies.roomStudioIndoorSpecies.contains(.ravenZZPlant))
        #expect(!PlantSpecies.roomStudioIndoorSpecies.contains(.sunflower))
        #expect(!PlantSpecies.roomStudioIndoorSpecies.contains(.willow))
        #expect(!PlantSpecies.roomStudioIndoorSpecies.contains(.determinateTomato))
    }
}

private extension Plant {
    var compositionVersionSafeScreenIndex: Bool {
        screenIndex >= 0 && screenIndex <= 1
    }
}
