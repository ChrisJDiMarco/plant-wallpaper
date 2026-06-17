import PlantGardenCore
import Testing

@Suite("Garden scene plant environment")
struct GardenScenePlantEnvironmentTests {
    @Test("desertarium limits planting to dry climate species")
    func desertariumLimitsPlantingToDryClimateSpecies() {
        let environment = GardenScenePlantEnvironment(sceneKey: "empty-desertarium")

        #expect(environment.isSuitable(.succulent))
        #expect(environment.isSuitable(.lavender))
        #expect(environment.isSuitable(.creepingThyme))
        #expect(environment.isSuitable(.oliveTree))
        #expect(!environment.isSuitable(.fern))
        #expect(!environment.isSuitable(.waterLily))
        #expect(!environment.isSuitable(.cattails))
        #expect(!environment.isSuitable(.willow))
    }

    @Test("water pavilion favors aquatic and moisture loving plants")
    func waterPavilionFavorsAquaticAndMoistureLovingPlants() {
        let environment = GardenScenePlantEnvironment(sceneKey: "empty-water-pavilion")

        #expect(environment.isSuitable(.waterLily))
        #expect(environment.isSuitable(.cattails))
        #expect(environment.isSuitable(.willow))
        #expect(environment.isSuitable(.fern))
        #expect(environment.isSuitable(.mossCarpet))
        #expect(environment.isSuitable(.pitcherPlant))
        #expect(!environment.isSuitable(.succulent))
        #expect(!environment.isSuitable(.lavender))
    }

    @Test("rooftop seed house favors sunny container plantings")
    func rooftopSeedHouseFavorsSunnyContainerPlantings() {
        let environment = GardenScenePlantEnvironment(sceneKey: "rooftop-seed-house")

        #expect(environment.isSuitable(.bonsai))
        #expect(environment.isSuitable(.herbCluster))
        #expect(environment.isSuitable(.lavender))
        #expect(environment.isSuitable(.dwarfCitrus))
        #expect(environment.isSuitable(.sunflower))
        #expect(!environment.isSuitable(.willow))
        #expect(!environment.isSuitable(.waterLily))
        #expect(!environment.isSuitable(.mushrooms))
    }

    @Test("apartment studio favors indoor container plantings")
    func apartmentStudioFavorsIndoorContainerPlantings() {
        let environment = GardenScenePlantEnvironment(sceneKey: "cozy-apartment-studio")

        #expect(environment.isSuitable(.bonsai))
        #expect(environment.isSuitable(.succulent))
        #expect(environment.isSuitable(.rose))
        #expect(!environment.isSuitable(.waterLily))
        #expect(!environment.isSuitable(.willow))
    }

    @Test("cottage backyard garden favors temperate raised bed plantings")
    func cottageBackyardGardenFavorsTemperateRaisedBedPlantings() {
        let environment = GardenScenePlantEnvironment(sceneKey: "cottage-backyard-garden")

        #expect(environment.displayName == "Cottage Backyard Garden")
        #expect(environment.isSuitable(.rose))
        #expect(environment.isSuitable(.peony))
        #expect(environment.isSuitable(.sunflower))
        #expect(environment.isSuitable(.herbCluster))
        #expect(environment.isSuitable(.determinateTomato))
        #expect(environment.isSuitable(.sweetPepper))
        #expect(environment.isSuitable(.peaVines))
        #expect(environment.isSuitable(.stringBeans))
        #expect(environment.isSuitable(.cucumberVine))
        #expect(environment.isSuitable(.rosemary))
        #expect(environment.isSuitable(.thyme))
        #expect(environment.isSuitable(.oregano))
        #expect(environment.isSuitable(.sage))
        #expect(environment.isSuitable(.cherryTree))
        #expect(!environment.isSuitable(.waterLily))
        #expect(!environment.isSuitable(.cattails))
        #expect(!environment.isSuitable(.mushrooms))
    }

    @Test("global garden scenes infer distinct planting habitats")
    func globalGardenScenesInferDistinctPlantingHabitats() {
        let monkGarden = GardenScenePlantEnvironment(sceneKey: "chinese-mountain-monk-garden")
        let swedishPatio = GardenScenePlantEnvironment(sceneKey: "swedish-patio-garden")
        let brazilianRooftop = GardenScenePlantEnvironment(sceneKey: "brazilian-rooftop-garden")
        let egyptianEstate = GardenScenePlantEnvironment(sceneKey: "ancient-egyptian-estate-garden")
        let texasGarden = GardenScenePlantEnvironment(sceneKey: "texas-rustic-garden")

        #expect(monkGarden.displayName == "Chinese Mountain Monk Garden")
        #expect(monkGarden.isSuitable(.bonsai))
        #expect(monkGarden.isSuitable(.japaneseMaple))
        #expect(monkGarden.isSuitable(.mossCarpet))
        #expect(!monkGarden.isSuitable(.succulent))

        #expect(swedishPatio.displayName == "Swedish Patio Garden")
        #expect(swedishPatio.isSuitable(.tulip))
        #expect(swedishPatio.isSuitable(.peony))
        #expect(swedishPatio.isSuitable(.birch))
        #expect(!swedishPatio.isSuitable(.monstera))

        #expect(brazilianRooftop.displayName == "Brazilian Rooftop Garden")
        #expect(brazilianRooftop.isSuitable(.dwarfCitrus))
        #expect(brazilianRooftop.isSuitable(.jasmine))
        #expect(brazilianRooftop.isSuitable(.bamboo))
        #expect(!brazilianRooftop.isSuitable(.birch))

        #expect(egyptianEstate.displayName == "Ancient Egyptian Estate Garden")
        #expect(egyptianEstate.isSuitable(.waterLily))
        #expect(egyptianEstate.isSuitable(.oliveTree))
        #expect(egyptianEstate.isSuitable(.rosemary))
        #expect(!egyptianEstate.isSuitable(.mushrooms))

        #expect(texasGarden.displayName == "Texas Rustic Garden")
        #expect(texasGarden.isSuitable(.succulent))
        #expect(texasGarden.isSuitable(.ornamentalGrass))
        #expect(texasGarden.isSuitable(.sage))
        #expect(!texasGarden.isSuitable(.waterLily))
    }

    @Test("custom scene keys infer habitat from words")
    func customSceneKeysInferHabitatFromWords() {
        let desert = GardenScenePlantEnvironment(sceneKey: "ai-dry-desert-courtyard")
        let pond = GardenScenePlantEnvironment(sceneKey: "custom-misty-pond-room")

        #expect(desert.isSuitable(.succulent))
        #expect(!desert.isSuitable(.waterLily))
        #expect(pond.isSuitable(.waterLily))
        #expect(pond.isSuitable(.fern))
        #expect(!pond.isSuitable(.succulent))
    }
}
