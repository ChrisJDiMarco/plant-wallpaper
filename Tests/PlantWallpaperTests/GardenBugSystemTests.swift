import AppKit
import PlantGardenCore
import QuartzCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden bug system")
struct GardenBugSystemTests {
    @Test("pollinators strongly prefer blooming host plants")
    func pollinatorsStronglyPreferBloomingHostPlants() {
        let bloomingRose = plant(species: .rose, bloomProgress: 0.95)
        let plainFern = plant(species: .fern, bloomProgress: 0.0)

        #expect(GardenBugSystem.plantAffinity(species: .bee, plant: bloomingRose)
            > GardenBugSystem.plantAffinity(species: .bee, plant: plainFern) + 0.45)
        #expect(GardenBugSystem.plantAffinity(species: .monarchButterfly, plant: bloomingRose)
            > GardenBugSystem.plantAffinity(species: .monarchButterfly, plant: plainFern) + 0.35)
    }

    @Test("dragonflies prefer aquatic landing hosts")
    func dragonfliesPreferAquaticLandingHosts() {
        let waterLily = plant(species: .waterLily, hydration: 0.90, health: 0.95, bloomProgress: 0.20)
        let sunflower = plant(species: .sunflower, hydration: 0.70, health: 0.90, bloomProgress: 0.80)

        #expect(GardenBugSystem.plantAffinity(species: .dragonfly, plant: waterLily)
            > GardenBugSystem.plantAffinity(species: .dragonfly, plant: sunflower))
        #expect(GardenBugSystem.plantLandingAltitude(for: .dragonfly, plant: waterLily)
            < GardenBugSystem.plantLandingAltitude(for: .dragonfly, plant: sunflower))
    }

    @Test("behavior weights expose plant interaction and realistic rest states")
    func behaviorWeightsExposePlantInteractionAndRestStates() {
        let dayContext = GardenBugSystem.BehaviorContext(
            livingPlantCount: 6,
            floweringPlantCount: 4,
            isNight: false,
            sceneKey: "cottage-backyard-garden",
            lastBehavior: nil
        )
        let nightContext = GardenBugSystem.BehaviorContext(
            livingPlantCount: 6,
            floweringPlantCount: 2,
            isNight: true,
            sceneKey: "cottage-backyard-garden",
            lastBehavior: nil
        )

        let beeWeights = Dictionary(uniqueKeysWithValues: GardenBugSystem.behaviorWeights(for: .bee, context: dayContext))
        let dragonflyWeights = Dictionary(uniqueKeysWithValues: GardenBugSystem.behaviorWeights(for: .dragonfly, context: dayContext))
        let fireflyWeights = Dictionary(uniqueKeysWithValues: GardenBugSystem.behaviorWeights(for: .firefly, context: nightContext))

        #expect((beeWeights[.nectarFeed] ?? 0) > (beeWeights[.travel] ?? 0))
        #expect((dragonflyWeights[.patrol] ?? 0) > (dragonflyWeights[.travel] ?? 0))
        #expect((fireflyWeights[.glowDrift] ?? 0) > (fireflyWeights[.travel] ?? 0))
    }

    @Test("high fidelity bug sprites include named anatomy layers")
    func highFidelityBugSpritesIncludeNamedAnatomyLayers() {
        for species in GardenBugSystem.Species.allCases {
            let size = GardenBugSprites.containerSize(for: species)
            let container = CALayer()
            container.bounds = CGRect(x: 0, y: 0, width: size, height: size)

            GardenBugSprites.populate(container: container, species: species, scale: 1)
            let layerNames = Set(recursiveLayerNames(in: container))

            #expect(container.sublayers?.count ?? 0 >= 3)
            #expect(layerNames.contains("body") || layerNames.contains("glow"))
            if species != .firefly {
                #expect(layerNames.contains("wing"))
            }
            if species == .bee || species == .hoverfly {
                #expect(layerNames.contains("leg"))
                #expect(layerNames.contains("antenna"))
            }
            if species == .bee {
                let beeAnatomy: Set<String> = [
                    "abdomen",
                    "abdomenStripe",
                    "thorax",
                    "compoundEye",
                    "ocellus",
                    "wingBlur",
                    "wingVein",
                    "fuzz",
                    "pollen"
                ]
                #expect(beeAnatomy.isSubset(of: layerNames))
            }
        }
    }

    @Test("bee sprites use realistic proportions and high speed wing blur")
    func beeSpritesUseRealisticProportionsAndHighSpeedWingBlur() {
        let size = GardenBugSprites.containerSize(for: .bee)
        let container = CALayer()
        container.bounds = CGRect(x: 0, y: 0, width: size, height: size)

        GardenBugSprites.populate(container: container, species: .bee, scale: 1)
        let layers = recursiveLayers(in: container)
        let abdomen = layers.first { $0.name == "abdomen" }
        let thorax = layers.first { $0.name == "thorax" }
        let head = layers.first { $0.name == "head" }
        let wingBlurCount = layers.filter { $0.name == "wingBlur" }.count
        let wingVeinCount = layers.filter { $0.name == "wingVein" }.count
        let flapAnimations = layers.compactMap { $0.animation(forKey: "flap") as? CABasicAnimation }

        #expect(size > GardenBugSprites.containerSize(for: .hoverfly))
        #expect((abdomen?.bounds.width ?? 0) > (thorax?.bounds.width ?? .greatestFiniteMagnitude))
        #expect((thorax?.bounds.height ?? 0) > (head?.bounds.height ?? .greatestFiniteMagnitude))
        #expect(wingBlurCount == 2)
        #expect(wingVeinCount >= 8)
        #expect(flapAnimations.contains { $0.duration <= 0.025 })
    }

    @Test("behavior animations are attached for feeding and resting")
    func behaviorAnimationsAreAttachedForFeedingAndResting() {
        let container = CALayer()
        let size = GardenBugSprites.containerSize(for: .bee)
        container.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        GardenBugSprites.populate(container: container, species: .bee, scale: 1)

        GardenBugSprites.applyBehavior(.nectarFeed, to: container, species: .bee)
        #expect(container.animationKeys()?.contains("behaviorBob") == true)
        #expect(recursiveAnimationKeys(in: container).contains("forage"))

        GardenBugSprites.applyBehavior(.leafRest, to: container, species: .bee)
        #expect(container.animationKeys()?.contains("restOpacity") == true)
    }

    @Test("bug count setting controls population with a desktop-safe cap")
    func bugCountSettingControlsPopulationWithDesktopSafeCap() {
        let quiet = GardenBugSystem.desiredBugCount(
            isEnabled: true,
            hasPlants: true,
            floweringPlantCount: 1,
            wildlifeDensity: 0.25
        )
        let lively = GardenBugSystem.desiredBugCount(
            isEnabled: true,
            hasPlants: true,
            floweringPlantCount: 5,
            wildlifeDensity: 3.0
        )
        let disabled = GardenBugSystem.desiredBugCount(
            isEnabled: false,
            hasPlants: true,
            floweringPlantCount: 5,
            wildlifeDensity: 3.0
        )

        #expect(quiet >= 1)
        #expect(lively == 12)
        #expect(disabled == 0)
    }

    @Test("bug size setting scales sprite size")
    func bugSizeSettingScalesSpriteSize() {
        let base = GardenBugSprites.containerSize(for: .bee)
        let normal = GardenBugSystem.spriteSize(for: .bee, randomScale: 1, settings: .default)
        let large = GardenBugSystem.spriteSize(
            for: .bee,
            randomScale: 1,
            settings: GardenSettings.default.updating(bugSizeMultiplier: 1.5)
        )
        let tiny = GardenBugSystem.spriteSize(
            for: .bee,
            randomScale: 1,
            settings: GardenSettings.default.updating(bugSizeMultiplier: 0.5)
        )

        #expect(normal == base)
        #expect(large == base * 1.5)
        #expect(tiny == base * 0.5)
    }

    @Test("bug systems install only when ambient wildlife is effective in the current mode")
    func bugSystemsInstallOnlyWhenAmbientWildlifeIsEffectiveInCurrentMode() {
        var state = GardenState(isAmbientWildlifeEnabled: false)
        #expect(!GardenOverlayController.shouldInstallBugSystems(for: state))

        state.isAmbientWildlifeEnabled = true
        #expect(GardenOverlayController.shouldInstallBugSystems(for: state))

        state.settings = state.settings.updating(experienceMode: .roomStudio)
        #expect(!GardenOverlayController.shouldInstallBugSystems(for: state))

        state.settings = state.settings.updating(isRoomStudioWildlifeEnabled: true)
        #expect(GardenOverlayController.shouldInstallBugSystems(for: state))

        state.settings = state.settings.updating(experienceMode: .alienUFO)
        #expect(GardenOverlayController.shouldInstallBugSystems(for: state))
    }

    @Test("live bugs are suppressed while plant spotlight is visible")
    func liveBugsAreSuppressedWhilePlantSpotlightIsVisible() {
        #expect(!GardenBugSystem.shouldSuppressLiveBugs(isPlantSpotlightVisible: false))
        #expect(GardenBugSystem.shouldSuppressLiveBugs(isPlantSpotlightVisible: true))
    }

    private func recursiveLayerNames(in layer: CALayer) -> [String] {
        var names = layer.name.map { [$0] } ?? []
        for sublayer in layer.sublayers ?? [] {
            names.append(contentsOf: recursiveLayerNames(in: sublayer))
        }
        return names
    }

    private func recursiveLayers(in layer: CALayer) -> [CALayer] {
        var layers = [layer]
        for sublayer in layer.sublayers ?? [] {
            layers.append(contentsOf: recursiveLayers(in: sublayer))
        }
        return layers
    }

    private func recursiveAnimationKeys(in layer: CALayer) -> Set<String> {
        var keys = Set(layer.animationKeys() ?? [])
        for sublayer in layer.sublayers ?? [] {
            keys.formUnion(recursiveAnimationKeys(in: sublayer))
        }
        return keys
    }

    private func plant(
        species: PlantSpecies,
        hydration: Double = 0.80,
        health: Double = 0.92,
        bloomProgress: Double
    ) -> Plant {
        Plant(
            species: species,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.72),
            growth: 1,
            hydration: hydration,
            health: health,
            bloomProgress: bloomProgress
        )
    }
}
