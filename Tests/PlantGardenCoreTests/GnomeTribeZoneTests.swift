import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Gnome tribe zones")
struct GnomeTribeZoneTests {
    @Test("zone points are normalized but can reach the screen edges")
    func zonePointsAreNormalized() {
        let zone = GnomeTribeZone(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            screenIndex: -2,
            points: [
                GardenPoint(x: -0.5, y: -0.2),
                GardenPoint(x: 0.5, y: 0.6),
                GardenPoint(x: 1.4, y: 1.2)
            ],
            cultureSeed: 42
        )

        #expect(zone.screenIndex == 0)
        #expect(zone.points == [
            GardenPoint(x: 0, y: 0),
            GardenPoint(x: 0.5, y: 0.6),
            GardenPoint(x: 1, y: 1)
        ])
        #expect(zone.isPlayable)
        #expect(zone.boundingBox == GnomeTribeZoneBounds(minX: 0, minY: 0, maxX: 1, maxY: 1))
    }

    @Test("long marker paths are compacted for persistence")
    func longMarkerPathsAreCompacted() {
        let points = (0..<400).map { index in
            GardenPoint(x: Double(index) / 399.0, y: 0.5)
        }

        let zone = GnomeTribeZone(screenIndex: 0, points: points)

        #expect(zone.points.count <= GnomeTribeZone.maximumPointCount)
        #expect(zone.points.first == GardenPoint(x: 0, y: 0.5))
    }

    @Test("garden state keeps playable gnome zones and visibility through coding")
    func gardenStateKeepsPlayableZonesAndVisibilityThroughCoding() throws {
        let zone = GnomeTribeZone(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            screenIndex: 1,
            points: [
                GardenPoint(x: 0.1, y: 0.2),
                GardenPoint(x: 0.4, y: 0.2),
                GardenPoint(x: 0.3, y: 0.6)
            ],
            cultureSeed: 7
        )
        let state = GardenState(gnomeTribeZones: [zone], areGnomeTribesHidden: true)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GardenState.self, from: data)

        #expect(decoded.gnomeTribeZones == [zone])
        #expect(decoded.areGnomeTribesHidden)
        #expect(decoded.gnomeSettlementPlan.isCommitted)
        #expect(decoded.gnomeSettlementPlan.startingZoneID == zone.id)
    }

    @Test("gnome settlement plan can stay in draft until user clicks done")
    func gnomeSettlementPlanCanStayInDraftUntilUserClicksDone() throws {
        let zoneA = GnomeTribeZone(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            screenIndex: 0,
            points: [
                GardenPoint(x: 0.1, y: 0.2),
                GardenPoint(x: 0.3, y: 0.2),
                GardenPoint(x: 0.2, y: 0.5)
            ],
            cultureSeed: 11
        )
        let zoneB = GnomeTribeZone(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            screenIndex: 0,
            points: [
                GardenPoint(x: 0.65, y: 0.25),
                GardenPoint(x: 0.86, y: 0.26),
                GardenPoint(x: 0.76, y: 0.58)
            ],
            cultureSeed: 12
        )

        let draft = GardenState(
            gnomeTribeZones: [zoneA, zoneB],
            gnomeSettlementPlan: GnomeTribeSettlementPlan(startedAt: nil, startingZoneID: zoneB.id)
        )

        #expect(!draft.gnomeSettlementPlan.isCommitted)
        #expect(draft.gnomeSettlementPlan.startingZoneID == zoneB.id)

        let data = try JSONEncoder().encode(draft)
        let decoded = try JSONDecoder().decode(GardenState.self, from: data)

        #expect(decoded.gnomeTribeZones == [zoneA, zoneB])
        #expect(!decoded.gnomeSettlementPlan.isCommitted)
        #expect(decoded.gnomeSettlementPlan.startingZoneID == zoneB.id)
    }

    @Test("gnome settlement plan clamps expansion timeframe")
    func gnomeSettlementPlanClampsExpansionTimeframe() {
        let tooFast = GnomeTribeSettlementPlan(expansionDurationDays: -4)
        let tooSlow = GnomeTribeSettlementPlan(expansionDurationDays: 400)

        #expect(tooFast.expansionDurationDays == GnomeTribeSettlementPlan.minimumExpansionDurationDays)
        #expect(tooSlow.expansionDurationDays == GnomeTribeSettlementPlan.maximumExpansionDurationDays)
    }

    @Test("gnome perspective defaults to the flattest grounded view")
    func gnomePerspectiveDefaultsToFlattest() {
        #expect(GnomeTribePerspective().elevationDegrees == GnomeTribePerspective.flattestElevation)
        #expect(GnomeTribePerspective.defaultValue.elevationDegrees == 24)
        #expect(GnomeTribePerspective.defaultValue.yawDegrees == 0)
    }

    @Test("gnome perspective clamps and adjusts from drag")
    func gnomePerspectiveClampsAndAdjustsFromDrag() {
        let clamped = GnomeTribePerspective(yawDegrees: 400, elevationDegrees: -50)

        #expect(clamped.yawDegrees == 55)
        #expect(clamped.elevationDegrees == 24)

        // Default elevation is the flattest (24); a downward drag raises it.
        let adjusted = GnomeTribePerspective()
            .adjustedByDrag(deltaX: -120, deltaY: 80)

        #expect(adjusted.yawDegrees == -12)
        #expect(abs(adjusted.elevationDegrees - 30.4) < 0.0001)
    }

    @Test("garden state preserves gnome perspective through coding")
    func gardenStatePreservesGnomePerspectiveThroughCoding() throws {
        let state = GardenState(
            gnomeTribePerspective: GnomeTribePerspective(yawDegrees: 18, elevationDegrees: 36)
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GardenState.self, from: data)

        #expect(decoded.gnomeTribePerspective == GnomeTribePerspective(yawDegrees: 18, elevationDegrees: 36))
    }

    @Test("old garden state decodes without gnome zone data")
    func oldGardenStateDecodesWithoutGnomeZoneData() throws {
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

        #expect(decoded.gnomeTribeZones.isEmpty)
        #expect(!decoded.areGnomeTribesHidden)
        #expect(decoded.gnomeTribePerspective == .defaultValue)
        #expect(!decoded.gnomeSettlementPlan.isCommitted)
    }
}
