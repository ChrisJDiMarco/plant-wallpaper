import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant scene anchor")
struct PlantSceneAnchorTests {
    @Test("mature foreground trees have stronger ground contact than seedlings")
    func matureForegroundTreesHaveStrongerGroundContactThanSeedlings() {
        let seedling = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.48, y: 0.58),
            ageSeconds: 1_200,
            growth: 0.08,
            hydration: 0.62,
            health: 0.82
        )
        let tree = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.48, y: 0.92),
            ageSeconds: 8 * 24 * 3_600,
            growth: 0.92,
            hydration: 0.76,
            health: 0.90
        )

        let seedlingAnchor = PlantSceneAnchor(plant: seedling)
        let treeAnchor = PlantSceneAnchor(plant: tree)

        #expect(treeAnchor.contactShadowWidthMultiplier > seedlingAnchor.contactShadowWidthMultiplier)
        #expect(treeAnchor.contactShadowOpacity > seedlingAnchor.contactShadowOpacity)
        #expect(treeAnchor.groundOcclusionOpacity > seedlingAnchor.groundOcclusionOpacity)
    }

    @Test("healthy hydrated plants get more reflected ground lift")
    func healthyHydratedPlantsGetMoreReflectedGroundLift() {
        let struggling = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.36, y: 0.82),
            ageSeconds: 2 * 24 * 3_600,
            growth: 0.56,
            hydration: 0.18,
            health: 0.30
        )
        let thriving = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.36, y: 0.82),
            ageSeconds: 2 * 24 * 3_600,
            growth: 0.56,
            hydration: 0.88,
            health: 0.90
        )

        let strugglingAnchor = PlantSceneAnchor(plant: struggling)
        let thrivingAnchor = PlantSceneAnchor(plant: thriving)

        #expect(thrivingAnchor.reflectionOpacity > strugglingAnchor.reflectionOpacity)
        #expect(thrivingAnchor.groundTintOpacity > strugglingAnchor.groundTintOpacity)
    }

    @Test("background plants stay visually softer than foreground plants")
    func backgroundPlantsStayVisuallySofterThanForegroundPlants() {
        let background = Plant(
            species: .monstera,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.56),
            ageSeconds: 3 * 24 * 3_600,
            growth: 0.72,
            hydration: 0.74,
            health: 0.84
        )
        let foreground = Plant(
            species: .monstera,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.92),
            ageSeconds: 3 * 24 * 3_600,
            growth: 0.72,
            hydration: 0.74,
            health: 0.84
        )

        let backgroundAnchor = PlantSceneAnchor(plant: background)
        let foregroundAnchor = PlantSceneAnchor(plant: foreground)

        #expect(backgroundAnchor.contactShadowOpacity < foregroundAnchor.contactShadowOpacity)
        #expect(backgroundAnchor.contactShadowWidthMultiplier < foregroundAnchor.contactShadowWidthMultiplier)
        #expect(backgroundAnchor.contactShadowHeightRatio <= foregroundAnchor.contactShadowHeightRatio)
    }
}
