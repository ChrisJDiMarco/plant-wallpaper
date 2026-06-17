import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden focus sessions")
struct GardenFocusSessionTests {
    private func makeState(at date: Date) -> GardenState {
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.7),
            plantedAt: date.addingTimeInterval(-3_600),
            lastTendedAt: date.addingTimeInterval(-3_600),
            growth: 0.4,
            hydration: 0.8,
            health: 0.8,
            bloomProgress: 0.3,
            swaySeed: 7,
            scale: 1.0
        )
        return GardenState(
            createdAt: date.addingTimeInterval(-7_200),
            lastUpdatedAt: date,
            plants: [plant]
        )
    }

    @Test("starting a session makes it active and timed")
    func startingSessionMakesItActiveAndTimed() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let state = GardenEngine.startFocusSession(makeState(at: start), duration: 25 * 60, at: start)

        let session = state.focusSession
        #expect(session != nil)
        #expect(session?.isActive(at: start.addingTimeInterval(60)) == true)
        #expect(session?.isCompleted(at: start.addingTimeInterval(25 * 60)) == true)
        #expect(session?.remainingSummary(at: start.addingTimeInterval(5 * 60)) == "20:00")
    }

    @Test("active focus session accelerates growth")
    func activeFocusSessionAcceleratesGrowth() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let baseState = makeState(at: start)
        let focusedState = GardenEngine.startFocusSession(baseState, duration: 50 * 60, at: start)
        let later = start.addingTimeInterval(20 * 60)

        let plainAdvance = GardenEngine.advance(baseState, to: later)
        let focusedAdvance = GardenEngine.advance(focusedState, to: later)

        let plainGrowth = plainAdvance.plants[0].growth
        let focusedGrowth = focusedAdvance.plants[0].growth
        #expect(focusedGrowth > plainGrowth, "Focused garden should grow faster")
    }

    @Test("completed session records stats, clears itself, and rewards plants")
    func completedSessionRecordsStatsAndRewardsPlants() throws {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let baseState = makeState(at: start)
        let state = GardenEngine.startFocusSession(baseState, duration: 25 * 60, at: start)
        let afterCompletion = start.addingTimeInterval(26 * 60)

        let resolved = GardenEngine.advance(state, to: afterCompletion)
        let baseline = GardenEngine.advance(baseState, to: afterCompletion)

        #expect(resolved.focusSession == nil)
        let stats = try #require(resolved.focusStats)
        #expect(stats.completedSessions == 1)
        #expect(abs(stats.totalFocusSeconds - 25 * 60) < 0.5)
        // The reward must survive the advancement pass: compared against the
        // same elapsed time without a focus session, bloom and health are higher.
        #expect(resolved.plants[0].bloomProgress > baseline.plants[0].bloomProgress)
        #expect(resolved.plants[0].health > baseline.plants[0].health)
    }

    @Test("cancelling a session discards it without stats")
    func cancellingSessionDiscardsWithoutStats() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let state = GardenEngine.startFocusSession(makeState(at: start), duration: 25 * 60, at: start)

        let cancelled = GardenEngine.cancelFocusSession(state)

        #expect(cancelled.focusSession == nil)
        #expect(cancelled.focusStats == nil)
    }

    @Test("a session completes even while the garden is paused")
    func sessionCompletesWhilePaused() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var state = GardenEngine.startFocusSession(makeState(at: start), duration: 25 * 60, at: start)
        state = GardenEngine.setPaused(state, isPaused: true, at: start)

        let resolved = GardenEngine.advance(state, to: start.addingTimeInterval(30 * 60))

        #expect(resolved.focusSession == nil)
        #expect(resolved.focusStats?.completedSessions == 1)
    }
}
