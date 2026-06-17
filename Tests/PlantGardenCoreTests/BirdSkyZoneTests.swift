import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Bird sky zones")
struct BirdSkyZoneTests {
    @Test("sky zone points are normalized but can reach the screen edges")
    func skyZonePointsAreNormalized() {
        let zone = BirdSkyZone(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            screenIndex: -4,
            points: [
                GardenPoint(x: -0.5, y: -0.2),
                GardenPoint(x: 0.5, y: 0.2),
                GardenPoint(x: 1.4, y: 1.2)
            ],
            skySeed: 42
        )

        #expect(zone.screenIndex == 0)
        #expect(zone.points == [
            GardenPoint(x: 0, y: 0),
            GardenPoint(x: 0.5, y: 0.2),
            GardenPoint(x: 1, y: 1)
        ])
        #expect(zone.isPlayable)
        #expect(zone.boundingBox == BirdSkyZoneBounds(minX: 0, minY: 0, maxX: 1, maxY: 1))
    }

    @Test("long sky marker paths are compacted for persistence")
    func longSkyMarkerPathsAreCompacted() {
        let points = (0..<400).map { index in
            GardenPoint(x: Double(index) / 399.0, y: 0.18)
        }

        let zone = BirdSkyZone(screenIndex: 0, points: points)

        #expect(zone.points.count <= BirdSkyZone.maximumPointCount)
        #expect(zone.points.first == GardenPoint(x: 0, y: 0.18))
    }

    @Test("garden state keeps bird sky zones and visibility through coding")
    func gardenStateKeepsBirdSkyZonesAndVisibilityThroughCoding() throws {
        let zone = BirdSkyZone(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            screenIndex: 1,
            points: [
                GardenPoint(x: 0.1, y: 0.1),
                GardenPoint(x: 0.7, y: 0.12),
                GardenPoint(x: 0.55, y: 0.38)
            ],
            skySeed: 77
        )
        let state = GardenState(birdSkyZones: [zone], areBirdFlocksHidden: true)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GardenState.self, from: data)

        #expect(decoded.birdSkyZones == [zone])
        #expect(decoded.areBirdFlocksHidden)
    }

    @Test("old garden state decodes without bird sky zone data")
    func oldGardenStateDecodesWithoutBirdSkyZoneData() throws {
        let data = Data("""
        {
          "version": 2,
          "isUserArranged": false,
          "createdAt": 0,
          "lastUpdatedAt": 0,
          "plants": [],
          "ambientMoisture": 0.4,
          "windStrength": 0.2,
          "isPaused": false,
          "isAmbientWildlifeEnabled": true,
          "musicButtons": [],
          "settings": {},
          "seedInventory": {},
          "harvestTally": {}
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(GardenState.self, from: data)

        #expect(decoded.birdSkyZones.isEmpty)
        #expect(!decoded.areBirdFlocksHidden)
    }
}
