import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden wildlife motion")
struct GardenWildlifeMotionTests {
    @Test("ambient wildlife can be disabled")
    func ambientWildlifeCanBeDisabled() {
        #expect(GardenWildlifeMotion.pollinatorCount(
            floweringPlantCount: 6,
            wildlifeDensity: 0.90,
            hasPlants: true,
            isEnabled: false
        ) == 0)
    }

    @Test("pollinator counts stay subtle and bounded")
    func pollinatorCountsStaySubtleAndBounded() {
        #expect(GardenWildlifeMotion.pollinatorCount(floweringPlantCount: 0, wildlifeDensity: 0.08, hasPlants: true) == 0)
        #expect(GardenWildlifeMotion.pollinatorCount(floweringPlantCount: 0, wildlifeDensity: 0.70, hasPlants: false) == 0)
        #expect(GardenWildlifeMotion.pollinatorCount(floweringPlantCount: 8, wildlifeDensity: 0.90, hasPlants: true) <= 5)
    }

    @Test("enabled pollinators render visibly around planted gardens")
    func enabledPollinatorsRenderVisiblyAroundPlantedGardens() {
        let count = GardenWildlifeMotion.pollinatorCount(
            floweringPlantCount: 0,
            wildlifeDensity: 0.22,
            hasPlants: true,
            isEnabled: true
        )
        let kinds = (0..<count).map {
            GardenWildlifeMotion.sample(
                index: $0,
                time: 120,
                wildlifeDensity: 0.22,
                hostHeight: 160,
                isNight: false
            ).kind
        }

        #expect(count >= 3)
        #expect(kinds.contains(.butterfly))
        #expect(kinds.contains(.hoverfly))
    }

    @Test("insect samples stay small enough for desktop scale")
    func insectSamplesStaySmallEnoughForDesktopScale() {
        for index in 0..<16 {
            let daySample = GardenWildlifeMotion.sample(
                index: index,
                time: 1_000,
                wildlifeDensity: 0.70,
                hostHeight: 180,
                isNight: false
            )
            let nightSample = GardenWildlifeMotion.sample(
                index: index,
                time: 1_000,
                wildlifeDensity: 0.70,
                hostHeight: 180,
                isNight: true
            )

            #expect(daySample.scale <= 0.70)
            #expect(nightSample.scale <= 0.70)
            #expect(daySample.kind.maxRenderedWingspanPoints <= 7.2)
            #expect(nightSample.kind.maxRenderedWingspanPoints <= 7.2)
        }
    }

    @Test("wing cadence distinguishes butterflies from high speed insects")
    func wingCadenceDistinguishesButterfliesFromHighSpeedInsects() {
        #expect(GardenWildlifeKind.butterfly.wingFlapsPerSecond >= 7)
        #expect(GardenWildlifeKind.butterfly.wingFlapsPerSecond <= 12)
        #expect(GardenWildlifeKind.bee.wingFlapsPerSecond >= 35)
        #expect(GardenWildlifeKind.hoverfly.wingFlapsPerSecond >= 30)
    }

    @Test("flight offsets move fluidly without large jumps")
    func flightOffsetsMoveFluidlyWithoutLargeJumps() {
        let first = GardenWildlifeMotion.sample(
            index: 2,
            time: 42.0,
            wildlifeDensity: 0.70,
            hostHeight: 220,
            isNight: false
        )
        let second = GardenWildlifeMotion.sample(
            index: 2,
            time: 42.10,
            wildlifeDensity: 0.70,
            hostHeight: 220,
            isNight: false
        )
        let third = GardenWildlifeMotion.sample(
            index: 2,
            time: 42.20,
            wildlifeDensity: 0.70,
            hostHeight: 220,
            isNight: false
        )

        #expect(distance(first.offset, second.offset) < 4.0)
        #expect(distance(second.offset, third.offset) < 4.0)
    }

    @Test("night samples use fireflies")
    func nightSamplesUseFireflies() {
        let sample = GardenWildlifeMotion.sample(
            index: 0,
            time: 300,
            wildlifeDensity: 0.70,
            hostHeight: 180,
            isNight: true
        )

        #expect(sample.kind == .firefly)
        #expect(sample.pulse > 0)
    }

    private func distance(_ lhs: GardenPoint, _ rhs: GardenPoint) -> Double {
        sqrt(pow(lhs.x - rhs.x, 2) + pow(lhs.y - rhs.y, 2))
    }
}
