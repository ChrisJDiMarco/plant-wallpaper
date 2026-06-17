import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant ground integration")
struct PlantGroundIntegrationTests {
    @Test("rooted mature foreground plants get the strongest bed tuck")
    func rootedMatureForegroundPlantsGetStrongestBedTuck() {
        let seedling = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.58),
            ageSeconds: 1_200,
            growth: 0.08,
            hydration: 0.70,
            health: 0.84
        )
        let tree = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.88),
            ageSeconds: 9 * 24 * 3_600,
            growth: 0.92,
            hydration: 0.78,
            health: 0.90
        )

        let seedlingIntegration = PlantGroundIntegration(plant: seedling)
        let treeIntegration = PlantGroundIntegration(plant: tree)

        #expect(treeIntegration.occlusionHeightRatio > seedlingIntegration.occlusionHeightRatio)
        #expect(treeIntegration.occlusionOpacity > seedlingIntegration.occlusionOpacity)
        #expect(treeIntegration.surfaceDetailCount > seedlingIntegration.surfaceDetailCount)
        #expect(treeIntegration.shortSummary == "Tucked in")
    }

    @Test("off bed plants look exposed instead of deeply tucked")
    func offBedPlantsLookExposedInsteadOfDeeplyTucked() {
        let rooted = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.78),
            ageSeconds: 4 * 24 * 3_600,
            growth: 0.66,
            hydration: 0.76,
            health: 0.88
        )
        let exposed = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.36),
            ageSeconds: 4 * 24 * 3_600,
            growth: 0.66,
            hydration: 0.76,
            health: 0.88
        )

        let rootedIntegration = PlantGroundIntegration(plant: rooted)
        let exposedIntegration = PlantGroundIntegration(plant: exposed)

        #expect(rootedIntegration.occlusionOpacity > exposedIntegration.occlusionOpacity)
        #expect(rootedIntegration.widthMultiplier > exposedIntegration.widthMultiplier)
        #expect(exposedIntegration.shortSummary == "Exposed base")
    }

    @Test("hydrated rooted plants show richer bed surface detail")
    func hydratedRootedPlantsShowRicherBedSurfaceDetail() {
        let dry = Plant(
            species: .wildflowerMeadow,
            screenIndex: 0,
            position: GardenPoint(x: 0.76, y: 0.66),
            ageSeconds: 3 * 24 * 3_600,
            growth: 0.64,
            hydration: 0.22,
            health: 0.82
        )
        let wet = Plant(
            species: .wildflowerMeadow,
            screenIndex: 0,
            position: GardenPoint(x: 0.76, y: 0.66),
            ageSeconds: 3 * 24 * 3_600,
            growth: 0.64,
            hydration: 0.88,
            health: 0.82
        )

        let dryIntegration = PlantGroundIntegration(plant: dry)
        let wetIntegration = PlantGroundIntegration(plant: wet)

        #expect(wetIntegration.surfaceTintOpacity > dryIntegration.surfaceTintOpacity)
        #expect(wetIntegration.surfaceDetailCount >= dryIntegration.surfaceDetailCount)
    }
}
