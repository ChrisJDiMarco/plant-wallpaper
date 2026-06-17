import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant root zone")
struct PlantRootZoneTests {
    @Test("seedlings have a tight new planting collar")
    func seedlingsHaveTightNewPlantingCollar() {
        let plant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.82),
            ageSeconds: 1_200,
            growth: 0.08,
            hydration: 0.72,
            health: 0.82
        )

        let rootZone = PlantRootZone(plant: plant)

        #expect(rootZone.stage == .newPlanting)
        #expect(rootZone.radiusMultiplier < 0.70)
        #expect(rootZone.surfaceDetailCount <= 5)
        #expect(rootZone.summary == "New planting")
    }

    @Test("mature trees have broad established root zones")
    func matureTreesHaveBroadEstablishedRootZones() {
        let plant = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.44, y: 0.66),
            ageSeconds: 7 * 24 * 3_600,
            growth: 0.88,
            hydration: 0.68,
            health: 0.86
        )

        let rootZone = PlantRootZone(plant: plant)

        #expect(rootZone.stage == .established)
        #expect(rootZone.radiusMultiplier > 1.10)
        #expect(rootZone.surfaceDetailCount >= 10)
        #expect(rootZone.summary == "Established roots")
    }

    @Test("hydrated root zones render richer soil")
    func hydratedRootZonesRenderRicherSoil() {
        let dryPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.30, y: 0.82),
            ageSeconds: 2 * 24 * 3_600,
            growth: 0.48,
            hydration: 0.24,
            health: 0.80
        )
        let wetPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.30, y: 0.82),
            ageSeconds: 2 * 24 * 3_600,
            growth: 0.48,
            hydration: 0.92,
            health: 0.80
        )

        let dryRootZone = PlantRootZone(plant: dryPlant)
        let wetRootZone = PlantRootZone(plant: wetPlant)

        #expect(wetRootZone.soilDarkness > dryRootZone.soilDarkness)
        #expect(wetRootZone.moistureSheen > dryRootZone.moistureSheen)
    }
}
