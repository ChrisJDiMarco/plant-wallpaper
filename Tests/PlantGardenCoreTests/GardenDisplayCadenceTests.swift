import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden display cadence")
struct GardenDisplayCadenceTests {
    @Test("calm gardens use a slow still-scene refresh")
    func calmGardensUseSlowStillSceneRefresh() {
        let now = Date(timeIntervalSince1970: 4_000)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.24, y: 0.82),
            lastTendedAt: now.addingTimeInterval(-300),
            growth: 0.54,
            hydration: 0.68,
            health: 0.84
        )
        let state = GardenState(lastUpdatedAt: now, plants: [plant], isAmbientWildlifeEnabled: false)

        let cadence = state.displayCadence(at: now)

        #expect(cadence.mood == .calm)
        #expect(cadence.refreshInterval > 1)
        #expect(cadence.summary == "Calm display")
    }

    @Test("recent tending briefly activates faster feedback refresh")
    func recentTendingBrieflyActivatesFasterFeedbackRefresh() {
        let now = Date(timeIntervalSince1970: 5_000)
        let plant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.64, y: 0.82),
            lastTendedAt: now.addingTimeInterval(-8),
            growth: 0.7,
            hydration: 0.9,
            health: 0.92
        )
        let state = GardenState(lastUpdatedAt: now, plants: [plant])

        let cadence = state.displayCadence(at: now)

        #expect(cadence.mood == .active)
        #expect(cadence.refreshInterval <= 0.5)
        #expect(cadence.summary == "Tending refresh")
    }

    @Test("old tending outside active window returns to calm")
    func oldTendingOutsideActiveWindowReturnsToCalm() {
        let now = Date(timeIntervalSince1970: 6_000)
        let plant = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.44, y: 0.84),
            lastTendedAt: now.addingTimeInterval(-40),
            growth: 0.64,
            hydration: 0.72,
            health: 0.88
        )
        let state = GardenState(lastUpdatedAt: now, plants: [plant], isAmbientWildlifeEnabled: false)

        let cadence = state.displayCadence(at: now, activeWindow: 18)

        #expect(cadence.mood == .calm)
        #expect(cadence.refreshInterval > 1)
    }

    @Test("ambient wildlife no longer forces canvas repaints")
    func ambientWildlifeNoLongerForcesCanvasRepaints() {
        // Wildlife moved to render-server-animated CALayers
        // (GardenBugSystem), so an otherwise-quiet garden stays on the calm
        // canvas cadence even with wildlife enabled.
        let now = Date(timeIntervalSince1970: 6_500)
        let plant = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.44, y: 0.84),
            lastTendedAt: now.addingTimeInterval(-400),
            growth: 0.64,
            hydration: 0.72,
            health: 0.88
        )
        let state = GardenState(lastUpdatedAt: now, plants: [plant], isAmbientWildlifeEnabled: true)

        let cadence = state.displayCadence(at: now, activeWindow: 18)

        #expect(cadence.mood == .calm)
        #expect(cadence.refreshInterval == GardenDisplayCadence.calmRefreshInterval)
        #expect(cadence.summary == "Calm display")
    }

    @Test("recent growth milestones activate faster feedback refresh")
    func recentGrowthMilestonesActivateFasterFeedbackRefresh() {
        let now = Date(timeIntervalSince1970: 7_000)
        let plant = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.30, y: 0.62),
            lastTendedAt: now.addingTimeInterval(-400),
            growth: 0.84,
            hydration: 0.74,
            health: 0.88,
            lastStageChangedAt: now.addingTimeInterval(-45)
        )
        let state = GardenState(lastUpdatedAt: now, plants: [plant])

        let cadence = state.displayCadence(at: now)

        #expect(cadence.mood == .active)
        #expect(cadence.refreshInterval <= 0.5)
    }

    @Test("Room Studio custom props do not force active plant redraw cadence")
    func roomStudioCustomPropsDoNotForceActivePlantRedrawCadence() {
        let now = Date(timeIntervalSince1970: 8_000)
        let prop = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.72, y: 0.82),
            lastTendedAt: now.addingTimeInterval(-3),
            growth: 1.0,
            hydration: 0.9,
            health: 0.94,
            lastStageChangedAt: now.addingTimeInterval(-12),
            nickname: "Open Clothing Rack",
            scale: 5,
            customAssetID: "custom-room-prop"
        )
        let state = GardenState(
            plants: [prop],
            settings: GardenSettings.default.updating(experienceMode: .roomStudio)
        )

        let cadence = state.displayCadence(at: now)

        #expect(cadence.mood == .calm)
        #expect(cadence.refreshInterval == GardenDisplayCadence.calmRefreshInterval)
    }
}
