import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Harvest and seeds")
struct GardenHarvestAndSeedsTests {
    private func edibleGarden(growth: Double) -> (GardenState, UUID) {
        let plant = Plant(
            species: .rosemary,
            screenIndex: 0,
            position: GardenPoint(x: 0.4, y: 0.7),
            growth: growth,
            hydration: 0.8,
            health: 0.9
        )
        return (GardenState(plants: [plant]), plant.id)
    }

    @Test("harvesting a ready edible counts the crop, yields seeds, and regrows")
    func harvestingReadyEdible() throws {
        let (state, plantID) = edibleGarden(growth: 0.95)

        let harvestedState = GardenEngine.harvestPlant(state, id: plantID)

        #expect(harvestedState.harvestTally[PlantSpecies.rosemary.rawValue] == 1)
        #expect(harvestedState.seedInventory[PlantSpecies.rosemary.rawValue] == 2)
        let plant = try #require(harvestedState.plants.first)
        #expect(plant.growth == 0.30)
        #expect(!plant.isHarvestReady)
    }

    @Test("harvesting an immature edible is a no-op")
    func harvestingImmatureEdible() {
        let (state, plantID) = edibleGarden(growth: 0.5)

        let result = GardenEngine.harvestPlant(state, id: plantID)

        #expect(result == state)
    }

    @Test("harvesting a non-edible is a no-op")
    func harvestingNonEdible() {
        let plant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.4, y: 0.7),
            growth: 0.95,
            hydration: 0.8,
            health: 0.9
        )
        let state = GardenState(plants: [plant])

        #expect(GardenEngine.harvestPlant(state, id: plant.id) == state)
    }

    @Test("harvesting ready crops batches tally, seeds, and regrowth")
    func harvestingReadyCropsBatchesTallySeedsAndRegrowth() throws {
        let tomato = Plant(
            species: .determinateTomato,
            screenIndex: 0,
            position: GardenPoint(x: 0.32, y: 0.72),
            growth: 0.92,
            hydration: 0.8,
            health: 0.9
        )
        let pepper = Plant(
            species: .sweetPepper,
            screenIndex: 0,
            position: GardenPoint(x: 0.46, y: 0.72),
            growth: 0.90,
            hydration: 0.8,
            health: 0.9
        )
        let youngCucumber = Plant(
            species: .cucumberVine,
            screenIndex: 0,
            position: GardenPoint(x: 0.60, y: 0.72),
            growth: 0.50,
            hydration: 0.8,
            health: 0.9
        )
        let state = GardenState(plants: [tomato, pepper, youngCucumber])

        let harvested = GardenEngine.harvestReadyCrops(state)

        #expect(harvested.harvestTally[PlantSpecies.determinateTomato.rawValue] == 1)
        #expect(harvested.harvestTally[PlantSpecies.sweetPepper.rawValue] == 1)
        #expect(harvested.harvestTally[PlantSpecies.cucumberVine.rawValue] == nil)
        #expect(harvested.seedInventory[PlantSpecies.determinateTomato.rawValue] == 2)
        #expect(harvested.seedInventory[PlantSpecies.sweetPepper.rawValue] == 2)
        let tomatoAfter = try #require(harvested.plants.first { $0.id == tomato.id })
        let cucumberAfter = try #require(harvested.plants.first { $0.id == youngCucumber.id })
        #expect(tomatoAfter.growth == 0.30)
        #expect(cucumberAfter.growth == youngCucumber.growth)
    }

    @Test("pruning a mature plant yields a seed; immature does not")
    func pruningYieldsSeedsOnlyWhenMature() {
        let maturePlant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.3, y: 0.7),
            growth: 0.9,
            hydration: 0.8,
            health: 0.9
        )
        let youngPlant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.6, y: 0.7),
            growth: 0.3,
            hydration: 0.8,
            health: 0.9
        )
        let state = GardenState(plants: [maturePlant, youngPlant])

        let afterMaturePrune = GardenEngine.prunePlant(state, id: maturePlant.id)
        let afterYoungPrune = GardenEngine.prunePlant(state, id: youngPlant.id)

        #expect(afterMaturePrune.seedInventory[PlantSpecies.rose.rawValue] == 1)
        #expect(afterYoungPrune.seedInventory[PlantSpecies.tulip.rawValue] == nil)
    }

    @Test("planting a seed consumes inventory and starts a seedling")
    func plantingSeedConsumesInventory() throws {
        var state = GardenState(plants: [])
        state.seedInventory[PlantSpecies.rose.rawValue] = 1

        let planted = GardenEngine.plantSeed(
            state,
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.7)
        )

        #expect(planted.plants.count == 1)
        let seedling = try #require(planted.plants.first)
        #expect(seedling.growth == 0.04)
        #expect(planted.seedInventory[PlantSpecies.rose.rawValue] == nil)

        // No seeds left: planting again is a no-op.
        #expect(GardenEngine.plantSeed(planted, species: .rose, screenIndex: 0, position: GardenPoint(x: 0.5, y: 0.7)) == planted)
    }

    @Test("completed focus session records stages grown")
    func completedFocusSessionRecordsStagesGrown() {
        let now = Date()
        var state = GardenState(plants: [
            Plant(
                species: .sunflower,
                screenIndex: 0,
                position: GardenPoint(x: 0.5, y: 0.7),
                growth: 0.40,
                hydration: 0.9,
                health: 0.95
            )
        ])
        state = GardenEngine.startFocusSession(state, duration: 60, at: now)

        // Simulate the session running past its end with growth happening.
        let completed = GardenEngine.advance(state, to: now.addingTimeInterval(2 * 3_600))

        #expect(completed.focusSession == nil)
        #expect(completed.focusStats?.completedSessions == 1)
        #expect(completed.focusStats?.lastSessionStagesGrown != nil)
    }
}

@Suite("Rare moments")
struct GardenRareMomentTests {
    @Test("rainbow appears after rain ends in daylight")
    func rainbowAppearsAfterRain() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 11
        components.hour = 14
        let calendar = Calendar.current
        let afternoon = try #require(calendar.date(from: components))

        let weather = GardenWeatherCondition(
            kind: .partlyCloudy,
            temperatureCelsius: 21,
            fetchedAt: afternoon,
            precipitationEndedAt: afternoon.addingTimeInterval(-4 * 60)
        )

        let moment = GardenRareMoment.activeMoment(at: afternoon, weather: weather, calendar: calendar)
        #expect(moment?.kind == .rainbow)
    }

    @Test("no rainbow while still raining or long after")
    func noRainbowWhileRainingOrLongAfter() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 11
        components.hour = 14
        let calendar = Calendar.current
        let afternoon = try #require(calendar.date(from: components))

        let raining = GardenWeatherCondition(kind: .rain, temperatureCelsius: 18, fetchedAt: afternoon)
        #expect(GardenRareMoment.activeMoment(at: afternoon, weather: raining, calendar: calendar)?.kind != .rainbow)

        let longAgo = GardenWeatherCondition(
            kind: .clear,
            temperatureCelsius: 21,
            fetchedAt: afternoon,
            precipitationEndedAt: afternoon.addingTimeInterval(-60 * 60)
        )
        #expect(GardenRareMoment.activeMoment(at: afternoon, weather: longAgo, calendar: calendar)?.kind != .rainbow)
    }

    @Test("scheduled moments are deterministic for a given date")
    func scheduledMomentsAreDeterministic() {
        let date = Date(timeIntervalSince1970: 1_780_000_000)
        let first = GardenRareMoment.activeMoment(at: date, weather: nil)
        let second = GardenRareMoment.activeMoment(at: date, weather: nil)
        #expect(first == second)
    }
}
