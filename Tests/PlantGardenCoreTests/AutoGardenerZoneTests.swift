import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Auto Gardener zones")
struct AutoGardenerZoneTests {
    @Test("zone keeps metadata and normalizes points through coding")
    func zoneKeepsMetadataAndNormalizesPointsThroughCoding() throws {
        let zone = AutoGardenerZone(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            screenIndex: -1,
            points: [
                GardenPoint(x: -0.2, y: 0.1),
                GardenPoint(x: 0.5, y: 0.4),
                GardenPoint(x: 1.2, y: 1.4)
            ],
            placementType: .smallPot,
            size: .tiny
        )
        let state = GardenState(autoGardenerZones: [zone])

        let decoded = try JSONDecoder().decode(GardenState.self, from: JSONEncoder().encode(state))

        #expect(decoded.autoGardenerZones == [zone])
        #expect(decoded.autoGardenerZones[0].screenIndex == 0)
        #expect(decoded.autoGardenerZones[0].points.first == GardenPoint(x: 0, y: 0.1))
        #expect(decoded.autoGardenerZones[0].placementType == .smallPot)
        #expect(decoded.autoGardenerZones[0].size == .tiny)
    }

    @Test("zone produces matching plant points and scene-aware species")
    func zoneProducesPlantingPlan() {
        let zone = AutoGardenerZone(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            screenIndex: 0,
            points: [
                GardenPoint(x: 0.2, y: 0.3),
                GardenPoint(x: 0.6, y: 0.3),
                GardenPoint(x: 0.5, y: 0.7)
            ],
            placementType: .groundcover,
            size: .large
        )

        #expect(zone.plantingPoints().count == 4)
        let waterPalette: Set<PlantSpecies> = [.waterLily, .cattails, .fern, .blueStarCreeper, .jasmine]
        #expect(zone.recommendedSpecies(sceneKey: "misty-pond").count == 4)
        #expect(zone.recommendedSpecies(sceneKey: "misty-pond").allSatisfy { waterPalette.contains($0) })
    }
}
