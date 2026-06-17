import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden engine")
struct GardenEngineTests {
    @Test("plant placement lock toggles without moving the plant")
    func plantPlacementLockTogglesWithoutMovingPlant() throws {
        let plant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.42, y: 0.76),
            growth: 0.8,
            hydration: 0.7,
            health: 0.9
        )
        let state = GardenState(plants: [plant])

        let locked = GardenEngine.setPlantPlacementLocked(state, id: plant.id, isLocked: true)
        let lockedPlant = try #require(locked.plants.first { $0.id == plant.id })
        #expect(lockedPlant.placementLocked)
        #expect(lockedPlant.position == plant.position)

        let unlocked = GardenEngine.setPlantPlacementLocked(locked, id: plant.id, isLocked: false)
        #expect(unlocked.plants.first { $0.id == plant.id }?.placementLocked == false)
    }

    @Test("plants decode missing placement lock as unlocked")
    func plantsDecodeMissingPlacementLockAsUnlocked() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000123",
          "species": "rose",
          "screenIndex": 0,
          "position": { "x": 0.5, "y": 0.72 },
          "plantedAt": 100,
          "lastTendedAt": 100,
          "ageSeconds": 0,
          "growth": 0.7,
          "hydration": 0.8,
          "health": 0.9,
          "bloomProgress": 0.4,
          "nickname": "Rose",
          "swaySeed": 4.2,
          "scale": 1.0
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let plant = try decoder.decode(Plant.self, from: json)

        #expect(!plant.placementLocked)
    }

    @Test("hydrated plants grow and keep healthy")
    func hydratedPlantsGrow() {
        let startDate = Date(timeIntervalSince1970: 100)
        let plant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.8),
            plantedAt: startDate,
            lastTendedAt: startDate,
            growth: 0.25,
            hydration: 0.78,
            health: 0.8,
            bloomProgress: 0
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let advanced = GardenEngine.advance(state, to: startDate.addingTimeInterval(6 * 3_600))
        let advancedPlant = try! #require(advanced.plants.first)

        #expect(advancedPlant.growth > plant.growth)
        #expect(advancedPlant.health >= plant.health)
        #expect(advancedPlant.hydration < plant.hydration)
    }

    @Test("garden settings adjust growth and water speed")
    func gardenSettingsAdjustGrowthAndWaterSpeed() throws {
        let startDate = Date(timeIntervalSince1970: 140)
        let plant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.8),
            plantedAt: startDate,
            lastTendedAt: startDate,
            growth: 0.25,
            hydration: 0.78,
            health: 0.8,
            bloomProgress: 0
        )
        let slowState = GardenState(
            lastUpdatedAt: startDate,
            plants: [plant],
            settings: GardenSettings(growthSpeedMultiplier: 0.5, waterUseMultiplier: 0.5)
        )
        let fastState = GardenState(
            lastUpdatedAt: startDate,
            plants: [plant],
            settings: GardenSettings(growthSpeedMultiplier: 2.0, waterUseMultiplier: 2.0)
        )

        let slowPlant = try #require(GardenEngine.advance(slowState, to: startDate.addingTimeInterval(6 * 3_600)).plants.first)
        let fastPlant = try #require(GardenEngine.advance(fastState, to: startDate.addingTimeInterval(6 * 3_600)).plants.first)

        #expect(fastPlant.growth - plant.growth > slowPlant.growth - plant.growth)
        #expect(plant.hydration - fastPlant.hydration > plant.hydration - slowPlant.hydration)
    }

    @Test("bright window placement grows faster than cool shade")
    func brightWindowPlacementGrowsFasterThanCoolShade() throws {
        let startDate = date(month: 7, hour: 13)
        let brightPlant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.58),
            plantedAt: startDate,
            lastTendedAt: startDate,
            growth: 0.32,
            hydration: 0.78,
            health: 0.82
        )
        let shadedPlant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.08, y: 0.90),
            plantedAt: startDate,
            lastTendedAt: startDate,
            growth: 0.32,
            hydration: 0.78,
            health: 0.82
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [brightPlant, shadedPlant])

        let advanced = GardenEngine.advance(state, to: startDate.addingTimeInterval(3 * 3_600))
        let brightAdvanced = try #require(advanced.plants.first { $0.id == brightPlant.id })
        let shadedAdvanced = try #require(advanced.plants.first { $0.id == shadedPlant.id })

        #expect(brightAdvanced.growth - brightPlant.growth > shadedAdvanced.growth - shadedPlant.growth)
        #expect(brightAdvanced.hydration < shadedAdvanced.hydration)
    }

    @Test("strained light lowers health compared with ideal light")
    func strainedLightLowersHealthComparedWithIdealLight() throws {
        let startDate = date(month: 7, hour: 13)
        let idealFern = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.08, y: 0.90),
            plantedAt: startDate,
            lastTendedAt: startDate,
            growth: 0.44,
            hydration: 0.74,
            health: 0.72
        )
        let strainedFern = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.58),
            plantedAt: startDate,
            lastTendedAt: startDate,
            growth: 0.44,
            hydration: 0.74,
            health: 0.72
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [idealFern, strainedFern])

        let advanced = GardenEngine.advance(state, to: startDate.addingTimeInterval(6 * 3_600))
        let idealAdvanced = try #require(advanced.plants.first { $0.id == idealFern.id })
        let strainedAdvanced = try #require(advanced.plants.first { $0.id == strainedFern.id })

        #expect(idealAdvanced.health > strainedAdvanced.health)
    }

    @Test("advancing across a real asset stage records milestone time")
    func advancingAcrossAssetStageRecordsMilestoneTime() throws {
        let startDate = Date(timeIntervalSince1970: 320)
        let advancedDate = startDate.addingTimeInterval(3_600)
        let plant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.82),
            plantedAt: startDate,
            lastTendedAt: startDate,
            growth: 0.095,
            hydration: 0.78,
            health: 0.84
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let advanced = GardenEngine.advance(state, to: advancedDate)
        let advancedPlant = try #require(advanced.plants.first)

        #expect(PlantAssetStage(growth: plant.growth).index == 0)
        #expect(PlantAssetStage(growth: advancedPlant.growth).index == 1)
        #expect(advancedPlant.lastStageChangedAt == advancedDate)
    }

    @Test("ignored dry plants stop thriving")
    func dryPlantsLoseHealth() {
        let startDate = Date(timeIntervalSince1970: 500)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.3, y: 0.82),
            plantedAt: startDate,
            lastTendedAt: startDate,
            growth: 0.52,
            hydration: 0.05,
            health: 0.7,
            bloomProgress: 0.2
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let advanced = GardenEngine.advance(state, to: startDate.addingTimeInterval(3 * 3_600))
        let advancedPlant = try! #require(advanced.plants.first)

        #expect(advancedPlant.health < plant.health)
        #expect(advancedPlant.growth == plant.growth)
    }

    @Test("unwatered plants wilt before dying")
    func unwateredPlantsWiltBeforeDying() throws {
        let startDate = Date(timeIntervalSince1970: 620)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.3, y: 0.82),
            plantedAt: startDate,
            lastTendedAt: startDate,
            growth: 0.58,
            hydration: 0.04,
            health: 0.34,
            bloomProgress: 0.26
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let advanced = GardenEngine.advance(state, to: startDate.addingTimeInterval(3 * 3_600))
        let advancedPlant = try #require(advanced.plants.first)

        #expect(advancedPlant.isWilting)
        #expect(!advancedPlant.isDead)
        #expect(advancedPlant.diedAt == nil)
        #expect(advancedPlant.health < plant.health)
        #expect(advancedPlant.bloomProgress < plant.bloomProgress)
        #expect(advancedPlant.growth == plant.growth)
    }

    @Test("sustained neglect eventually kills plants")
    func sustainedNeglectEventuallyKillsPlants() throws {
        let startDate = Date(timeIntervalSince1970: 700)
        let deathDate = startDate.addingTimeInterval(4 * 3_600)
        let plant = Plant(
            species: .hydrangea,
            screenIndex: 0,
            position: GardenPoint(x: 0.48, y: 0.78),
            plantedAt: startDate,
            lastTendedAt: startDate,
            growth: 0.66,
            hydration: 0.01,
            health: 0.14,
            bloomProgress: 0.42
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let advanced = GardenEngine.advance(state, to: deathDate)
        let deadPlant = try #require(advanced.plants.first)

        #expect(deadPlant.isDead)
        #expect(deadPlant.diedAt == deathDate)
        #expect(deadPlant.health == 0)
        #expect(deadPlant.hydration == 0)
        #expect(deadPlant.bloomProgress == 0)
        #expect(deadPlant.growth == plant.growth)
        #expect(deadPlant.careNeed == .dead)
        #expect(deadPlant.statusSummary == "Dead")
    }

    @Test("dead plants do not revive from care actions")
    func deadPlantsDoNotReviveFromCareActions() throws {
        let startDate = Date(timeIntervalSince1970: 780)
        let deadPlant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.80),
            plantedAt: startDate,
            lastTendedAt: startDate,
            growth: 0.72,
            hydration: 0,
            health: 0,
            bloomProgress: 0,
            diedAt: startDate
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [deadPlant])
        let tendedDate = startDate.addingTimeInterval(120)

        let watered = GardenEngine.waterPlant(state, id: deadPlant.id, amount: 1, at: tendedDate)
        let pruned = GardenEngine.prunePlant(watered, id: deadPlant.id, at: tendedDate)
        let nourished = GardenEngine.nourishPlant(pruned, id: deadPlant.id, at: tendedDate)
        let enjoyed = GardenEngine.enjoyPlant(nourished, id: deadPlant.id, at: tendedDate)
        let tendedPlant = try #require(enjoyed.plants.first)

        #expect(tendedPlant.isDead)
        #expect(tendedPlant.diedAt == startDate)
        #expect(tendedPlant.health == 0)
        #expect(tendedPlant.hydration == 0)
        #expect(tendedPlant.growth == deadPlant.growth)
        #expect(tendedPlant.lastTendedAt == startDate)
    }

    @Test("dead plant care actions leave state untouched")
    func deadPlantCareActionsLeaveStateUntouched() {
        let startDate = Date(timeIntervalSince1970: 840)
        let deadPlant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.80),
            plantedAt: startDate,
            lastTendedAt: startDate,
            growth: 0.72,
            hydration: 0,
            health: 0,
            bloomProgress: 0,
            diedAt: startDate
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [deadPlant])
        let tendedDate = startDate.addingTimeInterval(120)

        #expect(GardenEngine.waterPlant(state, id: deadPlant.id, amount: 1, at: tendedDate) == state)
        #expect(GardenEngine.prunePlant(state, id: deadPlant.id, at: tendedDate) == state)
        #expect(GardenEngine.nourishPlant(state, id: deadPlant.id, at: tendedDate) == state)
        #expect(GardenEngine.enjoyPlant(state, id: deadPlant.id, at: tendedDate) == state)
    }

    @Test("missing plant care actions leave state untouched")
    func missingPlantCareActionsLeaveStateUntouched() {
        let startDate = Date(timeIntervalSince1970: 900)
        let plant = Plant(
            species: .rose,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.80),
            growth: 0.72,
            hydration: 0.62,
            health: 0.74,
            bloomProgress: 0.42
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])
        let missingID = UUID()
        let tendedDate = startDate.addingTimeInterval(120)

        #expect(GardenEngine.waterPlant(state, id: missingID, amount: 1, at: tendedDate) == state)
        #expect(GardenEngine.prunePlant(state, id: missingID, at: tendedDate) == state)
        #expect(GardenEngine.nourishPlant(state, id: missingID, at: tendedDate) == state)
        #expect(GardenEngine.enjoyPlant(state, id: missingID, at: tendedDate) == state)
    }

    @Test("watering is capped and records tending time")
    func wateringAllPlantsCapsHydration() {
        let startDate = Date(timeIntervalSince1970: 1_000)
        let plant = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.4, y: 0.75),
            lastTendedAt: startDate,
            hydration: 0.9,
            health: 0.6
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])
        let wateredDate = startDate.addingTimeInterval(60)

        let watered = GardenEngine.waterAll(state, amount: 0.5, at: wateredDate)
        let wateredPlant = try! #require(watered.plants.first)

        #expect(wateredPlant.hydration == 1)
        #expect(wateredPlant.health > plant.health)
        #expect(wateredPlant.lastTendedAt == wateredDate)
    }

    @Test("watering thirsty plants with no thirsty plants leaves state untouched")
    func wateringThirstyPlantsWithNoThirstyPlantsLeavesStateUntouched() {
        let startDate = Date(timeIntervalSince1970: 1_040)
        let plant = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.4, y: 0.75),
            hydration: 0.88,
            health: 0.76
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let watered = GardenEngine.waterThirstyPlants(
            state,
            at: startDate.addingTimeInterval(120)
        )

        #expect(watered == state)
    }

    @Test("removing all plants clears only plant collection")
    func removingAllPlantsClearsPlantCollection() {
        let startDate = Date(timeIntervalSince1970: 1_080)
        let plants = [
            Plant(species: .lavender, screenIndex: 0, position: GardenPoint(x: 0.4, y: 0.75)),
            Plant(species: .pineTree, screenIndex: 0, position: GardenPoint(x: 0.7, y: 0.62))
        ]
        let state = GardenState(lastUpdatedAt: startDate, plants: plants, ambientMoisture: 0.41, windStrength: 0.29)
        let clearedDate = startDate.addingTimeInterval(30)

        let cleared = GardenEngine.removeAllPlants(state, at: clearedDate)

        #expect(cleared.plants.isEmpty)
        #expect(cleared.ambientMoisture == state.ambientMoisture)
        #expect(cleared.windStrength == state.windStrength)
        #expect(cleared.lastUpdatedAt == clearedDate)
    }

    @Test("removing a missing plant leaves state untouched")
    func removingMissingPlantLeavesStateUntouched() {
        let startDate = Date(timeIntervalSince1970: 1_085)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.22, y: 0.74),
            growth: 0.44,
            hydration: 0.70,
            health: 0.82
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let removed = GardenEngine.removePlant(
            state,
            id: UUID(),
            at: startDate.addingTimeInterval(90)
        )

        #expect(removed == state)
    }

    @Test("removing all plants from an empty garden leaves state untouched")
    func removingAllPlantsFromEmptyGardenLeavesStateUntouched() {
        let startDate = Date(timeIntervalSince1970: 1_090)
        let state = GardenState(lastUpdatedAt: startDate, plants: [], ambientMoisture: 0.44, windStrength: 0.12)

        let removed = GardenEngine.removeAllPlants(
            state,
            at: startDate.addingTimeInterval(90)
        )

        #expect(removed == state)
    }

    @Test("screen constraint keeps plants visible after displays disconnect")
    func screenConstraintKeepsPlantsVisibleAfterDisplaysDisconnect() throws {
        let startDate = Date(timeIntervalSince1970: 1_120)
        let movedDate = startDate.addingTimeInterval(45)
        let plants = [
            Plant(species: .lavender, screenIndex: 0, position: GardenPoint(x: 0.4, y: 0.75)),
            Plant(species: .pineTree, screenIndex: 1, position: GardenPoint(x: 0.7, y: 0.62)),
            Plant(species: .fern, screenIndex: 2, position: GardenPoint(x: 0.2, y: 0.84))
        ]
        let state = GardenState(lastUpdatedAt: startDate, plants: plants, ambientMoisture: 0.41, windStrength: 0.29)

        let constrained = GardenEngine.constrainPlantsToScreenCount(state, screenCount: 1, at: movedDate)

        #expect(constrained.plants.map(\.id) == plants.map(\.id))
        #expect(constrained.plants.map(\.screenIndex) == [0, 0, 0])
        #expect(constrained.plants[1].position == plants[1].position)
        #expect(constrained.ambientMoisture == state.ambientMoisture)
        #expect(constrained.windStrength == state.windStrength)
        #expect(constrained.lastUpdatedAt == movedDate)
    }

    @Test("screen constraint leaves already visible plants untouched")
    func screenConstraintLeavesVisiblePlantsUntouched() {
        let startDate = Date(timeIntervalSince1970: 1_160)
        let plants = [
            Plant(species: .lavender, screenIndex: 0, position: GardenPoint(x: 0.4, y: 0.75)),
            Plant(species: .pineTree, screenIndex: 1, position: GardenPoint(x: 0.7, y: 0.62))
        ]
        let state = GardenState(lastUpdatedAt: startDate, plants: plants, ambientMoisture: 0.41, windStrength: 0.29)

        let constrained = GardenEngine.constrainPlantsToScreenCount(
            state,
            screenCount: 2,
            at: startDate.addingTimeInterval(45)
        )

        #expect(constrained == state)
    }

    @Test("moving a plant records the movement time")
    func movingPlantRecordsMovementTime() throws {
        let startDate = Date(timeIntervalSince1970: 1_180)
        let movedDate = startDate.addingTimeInterval(90)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.82),
            growth: 0.42,
            hydration: 0.74,
            health: 0.80
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let moved = GardenEngine.movePlant(
            state,
            id: plant.id,
            to: GardenPoint(x: 0.9, y: -0.2),
            screenIndex: 2,
            at: movedDate
        )
        let movedPlant = try #require(moved.plants.first)

        #expect(movedPlant.id == plant.id)
        #expect(movedPlant.position == GardenPoint(x: 0.9, y: -0.2).clamped)
        #expect(movedPlant.screenIndex == 2)
        #expect(moved.lastUpdatedAt == movedDate)
    }

    @Test("moving a missing plant leaves state untouched")
    func movingMissingPlantLeavesStateUntouched() {
        let startDate = Date(timeIntervalSince1970: 1_190)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.82),
            growth: 0.42,
            hydration: 0.74,
            health: 0.80
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let moved = GardenEngine.movePlant(
            state,
            id: UUID(),
            to: GardenPoint(x: 0.9, y: 0.2),
            screenIndex: 2,
            at: startDate.addingTimeInterval(90)
        )

        #expect(moved == state)
    }

    @Test("moving a plant to the same resolved location leaves state untouched")
    func movingPlantToSameResolvedLocationLeavesStateUntouched() {
        let startDate = Date(timeIntervalSince1970: 1_195)
        let plant = Plant(
            species: .fern,
            screenIndex: 1,
            position: GardenPoint(x: 0.2, y: 0.82),
            growth: 0.42,
            hydration: 0.74,
            health: 0.80
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let moved = GardenEngine.movePlant(
            state,
            id: plant.id,
            to: plant.position,
            screenIndex: plant.screenIndex,
            at: startDate.addingTimeInterval(90)
        )

        #expect(moved == state)
    }

    @Test("resizing a plant records the scale change time")
    func resizingPlantRecordsScaleChangeTime() throws {
        let startDate = Date(timeIntervalSince1970: 1_205)
        let resizedDate = startDate.addingTimeInterval(45)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.82),
            growth: 0.42,
            hydration: 0.74,
            health: 0.80,
            scale: 1.0
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let resized = GardenEngine.resizePlant(
            state,
            id: plant.id,
            toScale: 1.45,
            at: resizedDate
        )
        let resizedPlant = try #require(resized.plants.first)

        #expect(resizedPlant.id == plant.id)
        #expect(resizedPlant.scale == 1.45)
        #expect(resized.lastUpdatedAt == resizedDate)
    }

    @Test("resizing clamps to editable plant scale bounds")
    func resizingClampsToEditablePlantScaleBounds() throws {
        let startDate = Date(timeIntervalSince1970: 1_210)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.82),
            growth: 0.42,
            hydration: 0.74,
            health: 0.80,
            scale: 1.0
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let tooSmall = GardenEngine.resizePlant(
            state,
            id: plant.id,
            toScale: 0.01,
            at: startDate.addingTimeInterval(1)
        )
        let tooLarge = GardenEngine.resizePlant(
            state,
            id: plant.id,
            toScale: 9.0,
            at: startDate.addingTimeInterval(2)
        )
        let tooSmallPlant = try #require(tooSmall.plants.first)
        let tooLargePlant = try #require(tooLarge.plants.first)

        #expect(tooSmallPlant.scale == GardenEngine.minimumPlantScale)
        #expect(tooLargePlant.scale == GardenEngine.maximumPlantScale)
    }

    @Test("resizing can use a larger custom maximum scale")
    func resizingCanUseLargerCustomMaximumScale() throws {
        let startDate = Date(timeIntervalSince1970: 1_212)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.82),
            growth: 1.0,
            hydration: 0.74,
            health: 0.80,
            scale: 1.0
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let resized = GardenEngine.resizePlant(
            state,
            id: plant.id,
            toScale: 7.5,
            maximumScale: 8.0,
            at: startDate.addingTimeInterval(1)
        )
        let resizedPlant = try #require(resized.plants.first)

        #expect(resizedPlant.scale == 7.5)
    }

    @Test("resizing a missing plant leaves state untouched")
    func resizingMissingPlantLeavesStateUntouched() {
        let startDate = Date(timeIntervalSince1970: 1_215)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.82),
            growth: 0.42,
            hydration: 0.74,
            health: 0.80,
            scale: 1.0
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let resized = GardenEngine.resizePlant(
            state,
            id: UUID(),
            toScale: 1.4,
            at: startDate.addingTimeInterval(90)
        )

        #expect(resized == state)
    }

    @Test("cloning a plant creates a nearby copy with the same plant state")
    func cloningPlantCreatesNearbyCopyWithSamePlantState() throws {
        let startDate = Date(timeIntervalSince1970: 1_220)
        let clonedDate = startDate.addingTimeInterval(30)
        let cloneID = UUID(uuidString: "00000000-0000-0000-0000-000000000222") ?? UUID()
        let plant = Plant(
            species: .ornamentalGrass,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.78),
            plantedAt: startDate.addingTimeInterval(-900),
            lastTendedAt: startDate.addingTimeInterval(-120),
            ageSeconds: 900,
            growth: 0.82,
            hydration: 0.74,
            health: 0.80,
            bloomProgress: 0.36,
            nickname: "Front grass",
            swaySeed: 12,
            scale: 1.42
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let cloned = GardenEngine.clonePlant(
            state,
            id: plant.id,
            clonedID: cloneID,
            at: clonedDate
        )
        let originalPlant = try #require(cloned.plants.first)
        let clonedPlant = try #require(cloned.plants.last)

        #expect(cloned.plants.count == 2)
        #expect(originalPlant == plant)
        #expect(clonedPlant.id == cloneID)
        #expect(clonedPlant.id != plant.id)
        #expect(clonedPlant.species == plant.species)
        #expect(clonedPlant.screenIndex == plant.screenIndex)
        #expect(clonedPlant.position != plant.position)
        #expect(clonedPlant.growth == plant.growth)
        #expect(clonedPlant.hydration == plant.hydration)
        #expect(clonedPlant.health == plant.health)
        #expect(clonedPlant.bloomProgress == plant.bloomProgress)
        #expect(clonedPlant.nickname == plant.nickname)
        #expect(clonedPlant.scale == plant.scale)
        #expect(cloned.lastUpdatedAt == clonedDate)
    }

    @Test("cloning a missing plant leaves state untouched")
    func cloningMissingPlantLeavesStateUntouched() {
        let startDate = Date(timeIntervalSince1970: 1_225)
        let plant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.82),
            growth: 0.42,
            hydration: 0.74,
            health: 0.80,
            scale: 1.0
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let cloned = GardenEngine.clonePlant(
            state,
            id: UUID(),
            clonedID: UUID(),
            at: startDate.addingTimeInterval(90)
        )

        #expect(cloned == state)
    }

    @Test("pruning improves health without making the plant jump forward")
    func pruningImprovesHealth() {
        let startDate = Date(timeIntervalSince1970: 2_000)
        let plant = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.7, y: 0.74),
            growth: 0.7,
            hydration: 0.5,
            health: 0.45,
            bloomProgress: 0.2
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])

        let pruned = GardenEngine.prunePlant(state, id: plant.id, at: startDate)
        let prunedPlant = try! #require(pruned.plants.first)

        #expect(prunedPlant.health > plant.health)
        #expect(prunedPlant.bloomProgress > plant.bloomProgress)
        #expect(prunedPlant.growth < plant.growth)
    }

    @Test("nourishing selected plants gently improves growth and health")
    func nourishingImprovesGrowthAndHealth() throws {
        let startDate = Date(timeIntervalSince1970: 2_500)
        let plant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.82),
            growth: 0.58,
            hydration: 0.72,
            health: 0.62,
            bloomProgress: 0.16
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])
        let tendedDate = startDate.addingTimeInterval(45)

        let nourished = GardenEngine.nourishPlant(state, id: plant.id, at: tendedDate)
        let nourishedPlant = try #require(nourished.plants.first)

        #expect(nourishedPlant.growth > plant.growth)
        #expect(nourishedPlant.growth - plant.growth < 0.08)
        #expect(nourishedPlant.health > plant.health)
        #expect(nourishedPlant.bloomProgress > plant.bloomProgress)
        #expect(nourishedPlant.lastTendedAt == tendedDate)
    }

    @Test("seasonal phenology changes bloom speed")
    func seasonalPhenologyChangesBloomSpeed() throws {
        let summerStart = date(month: 7, hour: 12)
        let winterStart = date(month: 1, hour: 12)
        let plant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.70),
            growth: 0.82,
            hydration: 0.82,
            health: 0.88,
            bloomProgress: 0.18
        )
        let summerState = GardenState(lastUpdatedAt: summerStart, plants: [plant])
        let winterState = GardenState(lastUpdatedAt: winterStart, plants: [plant])

        let summerAdvanced = GardenEngine.advance(summerState, to: summerStart.addingTimeInterval(6 * 3_600))
        let winterAdvanced = GardenEngine.advance(winterState, to: winterStart.addingTimeInterval(6 * 3_600))

        let summerPlant = try #require(summerAdvanced.plants.first)
        let winterPlant = try #require(winterAdvanced.plants.first)

        #expect(summerPlant.bloomProgress > winterPlant.bloomProgress)
        #expect(summerPlant.bloomProgress > plant.bloomProgress)
    }

    @Test("companion planting shelters foliage")
    func companionPlantingSheltersFoliage() throws {
        let startDate = date(month: 7, hour: 13)
        let fern = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.25, y: 0.76),
            growth: 0.46,
            hydration: 0.72,
            health: 0.70
        )
        let tree = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.22, y: 0.64),
            growth: 0.84,
            hydration: 0.76,
            health: 0.86
        )
        let isolatedState = GardenState(lastUpdatedAt: startDate, plants: [fern])
        let shelteredState = GardenState(lastUpdatedAt: startDate, plants: [fern, tree])

        let isolated = GardenEngine.advance(isolatedState, to: startDate.addingTimeInterval(6 * 3_600))
        let sheltered = GardenEngine.advance(shelteredState, to: startDate.addingTimeInterval(6 * 3_600))

        let isolatedFern = try #require(isolated.plants.first { $0.id == fern.id })
        let shelteredFern = try #require(sheltered.plants.first { $0.id == fern.id })

        #expect(shelteredFern.hydration > isolatedFern.hydration)
        #expect(shelteredFern.health > isolatedFern.health)
    }

    @Test("companion planting improves flower bloom")
    func companionPlantingImprovesFlowerBloom() throws {
        let startDate = date(month: 7, hour: 12)
        let sunflower = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.77),
            growth: 0.84,
            hydration: 0.78,
            health: 0.82,
            bloomProgress: 0.18
        )
        let meadow = Plant(
            species: .wildflowerMeadow,
            screenIndex: 0,
            position: GardenPoint(x: 0.49, y: 0.80),
            growth: 0.74,
            hydration: 0.78,
            health: 0.82,
            bloomProgress: 0.40
        )
        let lavender = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.56, y: 0.78),
            growth: 0.70,
            hydration: 0.78,
            health: 0.82,
            bloomProgress: 0.34
        )
        let isolatedState = GardenState(lastUpdatedAt: startDate, plants: [sunflower])
        let companionState = GardenState(lastUpdatedAt: startDate, plants: [sunflower, meadow, lavender])

        let isolated = GardenEngine.advance(isolatedState, to: startDate.addingTimeInterval(5 * 3_600))
        let companion = GardenEngine.advance(companionState, to: startDate.addingTimeInterval(5 * 3_600))

        let isolatedSunflower = try #require(isolated.plants.first { $0.id == sunflower.id })
        let companionSunflower = try #require(companion.plants.first { $0.id == sunflower.id })

        #expect(companionSunflower.bloomProgress > isolatedSunflower.bloomProgress)
        #expect(companionSunflower.growth > isolatedSunflower.growth)
    }

    @Test("bed placement protects plant health")
    func bedPlacementProtectsPlantHealth() throws {
        let startDate = date(month: 7, hour: 13)
        let rooted = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.76),
            growth: 0.48,
            hydration: 0.72,
            health: 0.74
        )
        let exposed = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.36),
            growth: 0.48,
            hydration: 0.72,
            health: 0.74
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [rooted, exposed])

        let advanced = GardenEngine.advance(state, to: startDate.addingTimeInterval(6 * 3_600))
        let rootedAdvanced = try #require(advanced.plants.first { $0.id == rooted.id })
        let exposedAdvanced = try #require(advanced.plants.first { $0.id == exposed.id })

        #expect(rootedAdvanced.health > exposedAdvanced.health)
        #expect(rootedAdvanced.hydration > exposedAdvanced.hydration)
    }

    @Test("trained climbers on structures are stabilized instead of removed")
    func trainedClimbersOnStructuresAreStabilizedInsteadOfRemoved() throws {
        let startDate = date(month: 7, hour: 13)
        let ivy = Plant(
            species: .ivy,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.36),
            growth: 0.82,
            hydration: 0.04,
            health: 0,
            diedAt: startDate.addingTimeInterval(-3_600)
        )
        let neighborA = Plant(
            species: .ivy,
            screenIndex: 0,
            position: GardenPoint(x: 0.56, y: 0.41),
            growth: 0.78,
            hydration: 0.72,
            health: 0.78
        )
        let neighborB = Plant(
            species: .ivy,
            screenIndex: 0,
            position: GardenPoint(x: 0.44, y: 0.43),
            growth: 0.76,
            hydration: 0.70,
            health: 0.80
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [ivy, neighborA, neighborB])

        let advanced = GardenEngine.advance(state, to: startDate.addingTimeInterval(90 * 60))
        let advancedIvy = try #require(advanced.plants.first { $0.id == ivy.id })

        #expect(!advancedIvy.isDead)
        #expect(advancedIvy.diedAt == nil)
        #expect(advancedIvy.health >= 0.32)
        #expect(advancedIvy.careNeed != .dead)
        #expect(advanced.careRecommendation.kind != .removeDead)
    }

    @Test("drought tolerant plants handle dry soil better")
    func droughtTolerantPlantsHandleDrySoilBetter() throws {
        let startDate = date(month: 7, hour: 13)
        let lavender = Plant(
            species: .lavender,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.76),
            growth: 0.46,
            hydration: 0.32,
            health: 0.76
        )
        let fern = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.76),
            growth: 0.46,
            hydration: 0.32,
            health: 0.76
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [lavender, fern])

        let advanced = GardenEngine.advance(state, to: startDate.addingTimeInterval(5 * 3_600))
        let lavenderAdvanced = try #require(advanced.plants.first { $0.id == lavender.id })
        let fernAdvanced = try #require(advanced.plants.first { $0.id == fern.id })

        #expect(lavenderAdvanced.health > fernAdvanced.health)
        #expect(lavenderAdvanced.growth > fernAdvanced.growth)
    }

    @Test("circadian daylight grows faster than night rest")
    func circadianDaylightGrowsFasterThanNightRest() throws {
        let brightStart = date(month: 7, hour: 12)
        let nightStart = date(month: 7, hour: 0)
        let plant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.76),
            growth: 0.46,
            hydration: 0.78,
            health: 0.84,
            bloomProgress: 0.22
        )
        let brightState = GardenState(lastUpdatedAt: brightStart, plants: [plant])
        let nightState = GardenState(lastUpdatedAt: nightStart, plants: [plant])

        let brightAdvanced = GardenEngine.advance(brightState, to: brightStart.addingTimeInterval(3 * 3_600))
        let nightAdvanced = GardenEngine.advance(nightState, to: nightStart.addingTimeInterval(3 * 3_600))

        let brightPlant = try #require(brightAdvanced.plants.first)
        let nightPlant = try #require(nightAdvanced.plants.first)

        #expect(brightPlant.growth > nightPlant.growth)
        #expect(brightPlant.hydration < nightPlant.hydration)
    }

    @Test("nourishing across a real asset stage records milestone time")
    func nourishingAcrossAssetStageRecordsMilestoneTime() throws {
        let startDate = Date(timeIntervalSince1970: 2_560)
        let plant = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.52, y: 0.82),
            growth: 0.285,
            hydration: 0.72,
            health: 0.72
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [plant])
        let tendedDate = startDate.addingTimeInterval(30)

        let nourished = GardenEngine.nourishPlant(state, id: plant.id, at: tendedDate)
        let nourishedPlant = try #require(nourished.plants.first)

        #expect(PlantAssetStage(growth: plant.growth).index == 2)
        #expect(PlantAssetStage(growth: nourishedPlant.growth).index == 3)
        #expect(nourishedPlant.lastStageChangedAt == tendedDate)
    }

    @Test("adding a plant honors explicit screen and position")
    func addingPlantHonorsExplicitPlacement() throws {
        let startDate = Date(timeIntervalSince1970: 2_700)
        let state = GardenState(lastUpdatedAt: startDate, plants: [])
        let requestedPosition = GardenPoint(x: 0.63, y: 0.74)

        let planted = GardenEngine.addPlant(
            state,
            species: .monstera,
            screenIndex: 2,
            position: requestedPosition,
            at: startDate
        )
        let plant = try #require(planted.plants.first)

        #expect(plant.species == .monstera)
        #expect(plant.screenIndex == 2)
        #expect(plant.position == requestedPosition)
        #expect(plant.growth == 0.08)
    }

    @Test("composition keeps cursor planting near intent while avoiding overlap")
    func compositionKeepsCursorPlantingNearIntentWhileAvoidingOverlap() {
        let preferredPosition = GardenPoint(x: 0.50, y: 0.78)
        let existingPlants = [
            Plant(species: .tulip, screenIndex: 0, position: GardenPoint(x: 0.50, y: 0.78)),
            Plant(species: .lavender, screenIndex: 0, position: GardenPoint(x: 0.55, y: 0.79)),
            Plant(species: .fern, screenIndex: 1, position: GardenPoint(x: 0.52, y: 0.78))
        ]

        let resolved = GardenComposition.resolvedPlantingPosition(
            for: .sunflower,
            preferredPosition: preferredPosition,
            existingPlants: existingPlants,
            screenIndex: 0
        )

        #expect(distance(resolved, preferredPosition) > 0.055)
        #expect(distance(resolved, preferredPosition) < 0.18)
        #expect(distance(resolved, existingPlants[0].position) >= 0.075)
        #expect(distance(resolved, existingPlants[1].position) >= 0.075)
        #expect(resolved.y >= 0.52)
        #expect(resolved.y <= 0.92)
    }

    @Test("composition preserves open cursor planting positions")
    func compositionPreservesOpenCursorPlantingPositions() {
        let preferredPosition = GardenPoint(x: 0.68, y: 0.74)
        let existingPlants = [
            Plant(species: .pineTree, screenIndex: 0, position: GardenPoint(x: 0.22, y: 0.62)),
            Plant(species: .monstera, screenIndex: 0, position: GardenPoint(x: 0.31, y: 0.78))
        ]

        let resolved = GardenComposition.resolvedPlantingPosition(
            for: .tulip,
            preferredPosition: preferredPosition,
            existingPlants: existingPlants,
            screenIndex: 0
        )

        #expect(resolved == preferredPosition)
    }

    @Test("composition keeps cursor planting in reachable garden band")
    func compositionKeepsCursorPlantingReachable() {
        let resolved = GardenComposition.resolvedPlantingPosition(
            for: .ivy,
            preferredPosition: GardenPoint(x: 0.99, y: 0.50),
            existingPlants: [],
            screenIndex: 0
        )

        #expect(resolved.x == 0.92)
        #expect(resolved.y == 0.56)
    }

    @Test("care needs identify thirsty and recovering plants")
    func careNeedsIdentifyAttention() {
        let thirstyPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.8),
            hydration: 0.21,
            health: 0.8
        )
        let recoveringPlant = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.6, y: 0.7),
            hydration: 0.6,
            health: 0.18
        )
        let thrivingPlant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.75),
            growth: 0.88,
            hydration: 0.72,
            health: 0.84,
            bloomProgress: 0.75
        )

        #expect(thirstyPlant.careNeed == .waterSoon)
        #expect(recoveringPlant.careNeed == .recovering)
        #expect(thrivingPlant.careNeed == .thriving)
    }

    @Test("garden summary counts plants needing attention")
    func gardenSummaryCountsNeeds() {
        let plants = [
            Plant(species: .fern, screenIndex: 0, position: GardenPoint(x: 0.2, y: 0.8), hydration: 0.12, health: 0.8),
            Plant(species: .tulip, screenIndex: 0, position: GardenPoint(x: 0.4, y: 0.8), hydration: 0.28, health: 0.75),
            Plant(species: .pineTree, screenIndex: 0, position: GardenPoint(x: 0.7, y: 0.65), hydration: 0.7, health: 0.22),
            Plant(species: .tulip, screenIndex: 0, position: GardenPoint(x: 0.5, y: 0.82), hydration: 0.7, health: 0.8)
        ]
        let state = GardenState(plants: plants)

        #expect(state.plantsNeedingCare.count == 3)
        #expect(state.thirstyPlants.count == 2)
        #expect(state.careSummary == "3 need care")
    }

    @Test("watering thirsty plants only tends plants that need water")
    func wateringThirstyPlantsOnlyTargetsDryPlants() throws {
        let startDate = Date(timeIntervalSince1970: 2_820)
        let thirstyPlant = Plant(
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.2, y: 0.8),
            lastTendedAt: startDate,
            hydration: 0.18,
            health: 0.8
        )
        let steadyPlant = Plant(
            species: .sunflower,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.75),
            lastTendedAt: startDate,
            hydration: 0.72,
            health: 0.84
        )
        let state = GardenState(lastUpdatedAt: startDate, plants: [thirstyPlant, steadyPlant])
        let tendedDate = startDate.addingTimeInterval(90)

        let watered = GardenEngine.waterThirstyPlants(state, amount: 0.4, at: tendedDate)
        let wateredThirstyPlant = try #require(watered.plants.first { $0.id == thirstyPlant.id })
        let unchangedSteadyPlant = try #require(watered.plants.first { $0.id == steadyPlant.id })

        #expect(wateredThirstyPlant.hydration > thirstyPlant.hydration)
        #expect(wateredThirstyPlant.lastTendedAt == tendedDate)
        #expect(unchangedSteadyPlant.hydration == steadyPlant.hydration)
        #expect(unchangedSteadyPlant.lastTendedAt == steadyPlant.lastTendedAt)
        #expect(watered.lastUpdatedAt == tendedDate)
    }

    @Test("default garden is diverse and bounded")
    func defaultGardenHasDiversePlants() {
        let garden = GardenState.defaultGarden(screenCount: 2)
        let species = Set(garden.plants.map(\.species))

        #expect(garden.plants.count >= 8)
        #expect(species.count >= 6)
        #expect(garden.plants.allSatisfy { plant in
            plant.position.x >= 0 && plant.position.x <= 1 &&
                plant.position.y >= 0 && plant.position.y <= 1 &&
                plant.screenIndex >= 0 && plant.screenIndex <= 1
        })
    }

    @Test("default garden uses layered botanical grouping")
    func defaultGardenUsesLayeredGrouping() throws {
        let garden = GardenState.defaultGarden(screenCount: 1)
        let trees = garden.plants.filter { $0.species.kind == .tree }
        let flowers = garden.plants.filter { $0.species.kind == .flower }
        let meadow = try #require(garden.plants.first { $0.species.kind == .meadow })

        let averageTreeY = trees.map(\.position.y).reduce(0, +) / Double(trees.count)
        let averageFlowerY = flowers.map(\.position.y).reduce(0, +) / Double(flowers.count)

        #expect(averageTreeY < averageFlowerY)
        #expect(meadow.position.y > averageFlowerY)
        #expect(garden.compositionVersion == GardenComposition.currentVersion)
    }

    @Test("arranging a garden preserves plant identity and growth state")
    func arrangingPreservesIdentityAndGrowth() throws {
        let startDate = Date(timeIntervalSince1970: 3_000)
        let plant = Plant(
            species: .cherryTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.5),
            growth: 0.71,
            hydration: 0.54,
            health: 0.83
        )
        let state = GardenState(
            version: 1,
            compositionVersion: nil,
            lastUpdatedAt: startDate,
            plants: [plant]
        )

        let arranged = GardenEngine.arrangeGarden(state, screenCount: 1, at: startDate)
        let arrangedPlant = try #require(arranged.plants.first)

        #expect(arrangedPlant.id == plant.id)
        #expect(arrangedPlant.growth == plant.growth)
        #expect(arrangedPlant.hydration == plant.hydration)
        #expect(arrangedPlant.position != plant.position)
        #expect(arranged.compositionVersion == GardenComposition.currentVersion)
    }

    private func distance(_ lhs: GardenPoint, _ rhs: GardenPoint) -> Double {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private func date(month: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = utcCalendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = month
        components.day = 15
        components.hour = hour
        return components.date!
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
