import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant asset stage mapping")
struct PlantAssetStageTests {
    @Test("stage mapping clamps growth into ten bounded stages")
    func stageMappingClampsGrowth() {
        let belowRange = PlantAssetStage(growth: -0.4)
        let seedling = PlantAssetStage(growth: 0)
        let middle = PlantAssetStage(growth: 0.349)
        let complete = PlantAssetStage(growth: 1.2)

        #expect(belowRange.index == 0)
        #expect(belowRange.nextIndex == 1)
        #expect(belowRange.progressToNext == 0)

        #expect(seedling.index == 0)
        #expect(seedling.nextIndex == 1)
        #expect(seedling.progressToNext == 0)

        #expect(middle.index == 3)
        #expect(abs(middle.progressToNext - 0.49) < 0.001)
        #expect(middle.nextIndex == 4)

        #expect(complete.index == 9)
        #expect(complete.nextIndex == nil)
        #expect(complete.progressToNext == 1)
    }

    @Test("stage mapping exposes a late-stage blend into the next real asset")
    func lateStageBlendOpacity() {
        let early = PlantAssetStage(growth: 0.265)
        let approachingNextStage = PlantAssetStage(growth: 0.292)
        let finalStage = PlantAssetStage(growth: 0.98)

        #expect(early.index == 2)
        #expect(early.blendOpacity == 0)

        #expect(approachingNextStage.index == 2)
        #expect(approachingNextStage.nextIndex == 3)
        #expect(approachingNextStage.blendOpacity > 0.30)
        #expect(approachingNextStage.blendOpacity < 0.64)

        #expect(finalStage.index == 9)
        #expect(finalStage.nextIndex == nil)
        #expect(finalStage.blendOpacity == 0)
    }

    @Test("asset render composite keeps plant PNGs opaque while blending growth stages")
    func assetRenderCompositeKeepsPlantPNGsOpaque() {
        let healthyPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.74),
            growth: 0.292,
            hydration: 1.0,
            health: 1.0
        )
        let dryPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.74),
            growth: 0.292,
            hydration: 0.05,
            health: 0.45
        )
        let deadPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.74),
            growth: 0.292,
            hydration: 0,
            health: 0,
            diedAt: Date(timeIntervalSince1970: 100)
        )
        let stage = PlantAssetStage(growth: 0.292)

        let healthyComposite = PlantAssetRenderComposite(plant: healthyPlant, assetStage: stage)
        let dryComposite = PlantAssetRenderComposite(plant: dryPlant, assetStage: stage)
        let deadComposite = PlantAssetRenderComposite(plant: deadPlant, assetStage: stage)

        #expect(healthyComposite.currentStageOpacity == 1.0)
        #expect(dryComposite.currentStageOpacity == 1.0)
        #expect(deadComposite.currentStageOpacity == 1.0)
        #expect(healthyComposite.nextStageOverlayOpacity == stage.blendOpacity)
        #expect(dryComposite.nextStageOverlayOpacity == stage.blendOpacity)
        #expect(deadComposite.nextStageOverlayOpacity == 0)
    }

    @Test("growth forecast estimates time to the next real asset stage")
    func growthForecastEstimatesNextStageTiming() throws {
        let plant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.82),
            growth: 0.24,
            hydration: 0.72,
            health: 0.8
        )

        let forecast = PlantGrowthForecast(plant: plant)

        #expect(forecast.status == .growing)
        #expect(forecast.stage.index == 2)
        #expect(abs(forecast.growthRemainingToNextStage - 0.06) < 0.001)

        let hours = try #require(forecast.estimatedHoursToNextStage)
        #expect(hours > 2.4)
        #expect(hours < 3.0)
        #expect(forecast.shortSummary == "Next stage ~3h")
    }

    @Test("growth forecast explains stalled or complete plants")
    func growthForecastExplainsStalledAndCompletePlants() {
        let deadPlant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.82),
            growth: 0.48,
            hydration: 0,
            health: 0,
            diedAt: Date(timeIntervalSince1970: 100)
        )
        let dryPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.8),
            growth: 0.28,
            hydration: 0.08,
            health: 0.8
        )
        let unhealthyPlant = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.7, y: 0.68),
            growth: 0.34,
            hydration: 0.72,
            health: 0.18
        )
        let completePlant = Plant(
            species: .pineTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.7, y: 0.65),
            growth: 1,
            hydration: 0.72,
            health: 0.8
        )

        let deadForecast = PlantGrowthForecast(plant: deadPlant)
        let dryForecast = PlantGrowthForecast(plant: dryPlant)
        let unhealthyForecast = PlantGrowthForecast(plant: unhealthyPlant)
        let completeForecast = PlantGrowthForecast(plant: completePlant)

        #expect(deadForecast.status == .dead)
        #expect(deadForecast.estimatedHoursToNextStage == nil)
        #expect(deadForecast.shortSummary == "Dead")

        #expect(dryForecast.status == .needsWater)
        #expect(dryForecast.estimatedHoursToNextStage == nil)
        #expect(dryForecast.shortSummary == "Water to grow")

        #expect(unhealthyForecast.status == .recovering)
        #expect(unhealthyForecast.estimatedHoursToNextStage == nil)
        #expect(unhealthyForecast.shortSummary == "Recovering")

        #expect(completeForecast.status == .complete)
        #expect(completeForecast.estimatedHoursToNextStage == nil)
        #expect(completeForecast.shortSummary == "Fully grown")
    }

    @Test("life stage labels describe all ten real asset phases")
    func lifeStageLabelsDescribeAssetPhases() {
        let treeSeedling = PlantLifeStage(species: .mapleTree, stageIndex: 0, stageCount: 10)
        let treeCanopy = PlantLifeStage(species: .mapleTree, stageIndex: 4, stageCount: 10)
        let flowerBud = PlantLifeStage(species: .tulip, stageIndex: 5, stageCount: 10)
        let flowerBloom = PlantLifeStage(species: .tulip, stageIndex: 8, stageCount: 10)
        let meadowPeak = PlantLifeStage(species: .wildflowerMeadow, stageIndex: 14, stageCount: 10)

        #expect(treeSeedling.title == "Seedling")
        #expect(treeSeedling.label == "Seedling 1/10")
        #expect(treeCanopy.title == "Canopy forming")
        #expect(flowerBud.title == "Bud swelling")
        #expect(flowerBloom.title == "Full bloom")
        #expect(meadowPeak.title == "Peak meadow")
        #expect(meadowPeak.stageNumber == 10)
    }

    @Test("life stage labels can be built from current asset stage")
    func lifeStageLabelsUseAssetStage() {
        let assetStage = PlantAssetStage(growth: 0.72, stageCount: 10)
        let lifeStage = PlantLifeStage(species: .pineTree, assetStage: assetStage, stageCount: 10)

        #expect(assetStage.index == 7)
        #expect(lifeStage.title == "Maturing")
        #expect(lifeStage.label == "Maturing 8/10")
    }
}
