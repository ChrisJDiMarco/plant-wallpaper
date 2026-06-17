import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Gnome tribe integration")
struct GnomeTribeIntegrationTests {
    @Test("store adds hides and clears scene gnome zones")
    func storeAddsHidesAndClearsSceneGnomeZones() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnome-zone-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = GardenStore(
            state: GardenState(),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )

        store.addGnomeTribeZone(screenIndex: 2, points: [
            GardenPoint(x: 0.2, y: 0.4),
            GardenPoint(x: 0.6, y: 0.4),
            GardenPoint(x: 0.5, y: 0.8)
        ])

        #expect(store.state.gnomeTribeZones.count == 1)
        #expect(store.state.gnomeTribeZones[0].screenIndex == 2)
        #expect(!store.state.areGnomeTribesHidden)
        #expect(!store.state.gnomeSettlementPlan.isCommitted)

        store.commitGnomeTribeSettlement(startingZoneID: store.state.gnomeTribeZones[0].id)

        #expect(store.state.gnomeSettlementPlan.isCommitted)
        #expect(store.state.gnomeSettlementPlan.startingZoneID == store.state.gnomeTribeZones[0].id)

        store.setGnomeTribesHidden(true)

        #expect(store.state.areGnomeTribesHidden)
        #expect(store.state.gnomeTribeZones.count == 1)

        store.setGnomeTribesHidden(false)

        #expect(!store.state.areGnomeTribesHidden)

        store.clearGnomeTribeZones()

        #expect(store.state.gnomeTribeZones.isEmpty)
        #expect(!store.state.areGnomeTribesHidden)
    }

    @Test("store updates scene gnome perspective")
    func storeUpdatesSceneGnomePerspective() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnome-perspective-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = GardenStore(
            state: GardenState(),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )

        store.setGnomeTribePerspective(
            GnomeTribePerspective(yawDegrees: -24, elevationDegrees: 36),
            shouldSave: false
        )

        #expect(store.state.gnomeTribePerspective == GnomeTribePerspective(yawDegrees: -24, elevationDegrees: 36))
    }

    @Test("drawing mode lets the canvas receive desktop drags anywhere")
    func drawingModeReceivesDesktopDragsAnywhere() {
        let store = GardenStore(
            state: GardenState(),
            persistence: GardenPersistence(
                directoryURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("gnome-zone-canvas-\(UUID().uuidString)", isDirectory: true)
            )
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 800, height: 500),
            screenIndex: 0,
            store: store
        )

        #expect(canvasView.shouldReceiveMouseEvents(at: NSPoint(x: 16, y: 16)) == false)

        canvasView.isGnomeZoneDrawingMode = true

        #expect(canvasView.shouldReceiveMouseEvents(at: NSPoint(x: 16, y: 16)))
        #expect(canvasView.interactionRegionRects() == [canvasView.bounds])
    }

    @Test("gnome marker drag saves a normalized zone")
    func gnomeMarkerDragSavesNormalizedZone() {
        let store = GardenStore(
            state: GardenState(),
            persistence: GardenPersistence(
                directoryURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("gnome-zone-drag-\(UUID().uuidString)", isDirectory: true)
            )
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 1000, height: 500),
            screenIndex: 0,
            store: store
        )

        #expect(canvasView.beginGnomeZoneDraft(at: NSPoint(x: 100, y: 200)))
        #expect(canvasView.continueGnomeZoneDraft(at: NSPoint(x: 500, y: 200)))
        #expect(canvasView.continueGnomeZoneDraft(at: NSPoint(x: 420, y: 360)))
        #expect(canvasView.endGnomeZoneDraft())

        #expect(store.state.gnomeTribeZones.count == 1)
        #expect(store.state.gnomeTribeZones[0].points.first == GardenPoint(x: 0.1, y: 0.4))
        #expect(!canvasView.gnomeZoneGuideVisibleForSelfTest())
    }

    @Test("perspective overlay exposes a Done button and per-zone targets")
    func perspectiveOverlayDoneButtonAndZoneTargets() {
        let store = GardenStore(
            state: GardenState(),
            persistence: GardenPersistence(
                directoryURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("gnome-perspective-overlay-\(UUID().uuidString)", isDirectory: true)
            )
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 800, height: 500),
            screenIndex: 0,
            store: store
        )
        store.addGnomeTribeZone(screenIndex: 0, points: [
            GardenPoint(x: 0.2, y: 0.4),
            GardenPoint(x: 0.6, y: 0.4),
            GardenPoint(x: 0.5, y: 0.8)
        ])

        let doneRect = canvasView.gnomePerspectiveDoneButtonRect()
        let doneCenter = NSPoint(x: doneRect.midX, y: doneRect.midY)

        // The Done button only responds while the mode is active.
        #expect(canvasView.gnomePerspectiveDoneButtonContains(doneCenter) == false)
        canvasView.isGnomePerspectiveAdjustmentMode = true
        #expect(canvasView.gnomePerspectiveDoneButtonContains(doneCenter))
        #expect(canvasView.gnomePerspectiveDoneButtonContains(NSPoint(x: 5, y: 5)) == false)

        // Each drawn zone yields a hover/hit target at its centroid.
        let targets = canvasView.gnomePerspectiveZoneTargets()
        #expect(targets.count == 1)
        #expect(abs(targets[0].center.x - 320) < 1)   // x bbox [0.2,0.6] center 0.4 * 800
        #expect(abs(targets[0].center.y - 300) < 1)   // y bbox [0.4,0.8] center 0.6 * 500

        canvasView.updatePerspectiveHover(at: [targets[0].center])
        #expect(canvasView.hoveredPerspectiveZoneIndex == 0)
        #expect(canvasView.isPerspectiveDoneButtonHovered == false)

        canvasView.updatePerspectiveHover(at: [doneCenter])
        #expect(canvasView.isPerspectiveDoneButtonHovered)
        #expect(canvasView.hoveredPerspectiveZoneIndex == nil)
    }

    @Test("gnome web assets are bundled and referenced")
    func gnomeWebAssetsAreBundledAndReferenced() throws {
        let indexURL = try #require(
            GnomeTribeController.webAssetsIndexURL(),
            "WebAssets/gnomes/index.html missing from bundle"
        )
        let directoryURL = indexURL.deletingLastPathComponent()
        let html = try String(contentsOf: indexURL, encoding: .utf8)
        let main = try String(contentsOf: directoryURL.appendingPathComponent("main.js"), encoding: .utf8)

        for fileName in [
            "../cat/three.min.js",
            "projection.js",
            "materials.js",
            "gnome.js",
            "pose.js",
            "buildsite.js",
            "zone.js",
            "detail.js",
            "main.js"
        ] {
            #expect(html.contains(fileName))
        }
        #expect(FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("main.js").path))
        #expect(FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("projection.js").path))
        #expect(FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("gnome.js").path))
        #expect(FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("buildsite.js").path))
        #expect(FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("zone.js").path))
        #expect(FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("pose.js").path))
        #expect(main.contains("new THREE.WebGLRenderer"))
        #expect(main.contains("MeshStandardMaterial"))
        #expect(main.contains("makeGnome"))
        #expect(main.contains("makeBuildSite"))
        #expect(main.contains("buildZone"))
        #expect(main.contains("GnomeProjection.groundPointFromNormalized"))
        #expect(main.contains("renderer: 'three-js'"))
    }

    @Test("gnome society renderer has articulated realistic citizens and build systems")
    func gnomeSocietyRendererHasArticulatedRealisticCitizensAndBuildSystems() throws {
        let indexURL = try #require(GnomeTribeController.webAssetsIndexURL())
        let directoryURL = indexURL.deletingLastPathComponent()
        let main = try String(contentsOf: directoryURL.appendingPathComponent("main.js"), encoding: .utf8)
        let gnome = try String(contentsOf: directoryURL.appendingPathComponent("gnome.js"), encoding: .utf8)
        let pose = try String(contentsOf: directoryURL.appendingPathComponent("pose.js"), encoding: .utf8)
        let buildsite = try String(contentsOf: directoryURL.appendingPathComponent("buildsite.js"), encoding: .utf8)
        let zone = try String(contentsOf: directoryURL.appendingPathComponent("zone.js"), encoding: .utf8)
        let detail = try String(contentsOf: directoryURL.appendingPathComponent("detail.js"), encoding: .utf8)
        let emergence = try String(contentsOf: directoryURL.appendingPathComponent("emergence.js"), encoding: .utf8)
        let rendererSource = [main, gnome, pose, buildsite, zone, detail, emergence].joined(separator: "\n")

        for requiredFragment in [
            "gnome-village-v4-resource-city-growth",
            "function makeGnome",
            "parts",
            "leftUpperArm",
            "rightForeArm",
            "leftThigh",
            "rightShin",
            "function poseGnome",
            "function makeBuildSite",
            "setProgress",
            "smokeAnchor",
            "function populateZone",
            "function buildZone",
            "function makeZoneOutline",
            "function addGnomeDetail",
            "function addHouseDetail",
            "polygon: poly",
            "zoneSignature",
            "perspectiveSignature",
            "normalizedPerspective",
            "buildSites",
            "progress",
            "function applyCircadian",
            "state.simulation",
            "normalizedSimulation",
            "populationMultiplier",
            "tribeScaleMultiplier",
            "behaviorLiveliness",
            "buildingSpeedMultiplier",
            "cooperationMultiplier",
            "plantInteractionMultiplier",
            "villageDetailMultiplier",
            "plantPOIs",
            "function makeMicroFence",
            "function makeWindowBox",
            "function makeMushroomCluster",
            "function addVillageHouseFidelity",
            "function makeConstructionHoist",
            "function makeConstructionMotes",
            "function makeStoneWalk",
            "motion",
            "hearthGlow",
            "setSimulation",
            "function updateSimulation",
            "function disposeObjectTree",
            "gnomeDisposableMaterial",
            "state.fireLightCount = Math.max(0",
            "dailyRoutine",
            "function normalizedDailyRoutine",
            "function applyDailyRoutine",
            "homeLightIntensity",
            "setDailyRoutine",
            "windowLights",
            "routine-buildBias",
            "routine-sleepBias",
            "restingInside",
            "visualVersion"
        ] {
            #expect(rendererSource.contains(requiredFragment))
        }
    }

    @Test("gnome desire paths render as translucent brown earth")
    func gnomeDesirePathsRenderAsTranslucentBrownEarth() throws {
        let indexURL = try #require(GnomeTribeController.webAssetsIndexURL())
        let directoryURL = indexURL.deletingLastPathComponent()
        let emergence = try String(contentsOf: directoryURL.appendingPathComponent("emergence.js"), encoding: .utf8)

        #expect(emergence.contains("var ALPHA_CEIL      = 0.62"))
        #expect(emergence.contains("var COL_DIRT   = [150, 105,  64]"))
        #expect(emergence.contains("var COL_EARTH  = [118,  75,  42]"))
        #expect(emergence.contains("var COL_COBBLE = [ 86,  54,  32]"))
        #expect(emergence.contains("warm translucent brown"))
        #expect(!emergence.contains("COL_COBBLE = [124, 120, 112]"))
        #expect(!emergence.contains("grey cobble"))
    }

    @Test("gnome daily routine follows real local time")
    func gnomeDailyRoutineFollowsRealLocalTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        let preDawn = GnomeTribeController.dailyRoutineForTesting(date: try date(hour: 3, calendar: calendar), calendar: calendar)
        let dawn = GnomeTribeController.dailyRoutineForTesting(date: try date(hour: 6, calendar: calendar), calendar: calendar)
        let morning = GnomeTribeController.dailyRoutineForTesting(date: try date(hour: 10, calendar: calendar), calendar: calendar)
        let afternoon = GnomeTribeController.dailyRoutineForTesting(date: try date(hour: 14, calendar: calendar), calendar: calendar)
        let evening = GnomeTribeController.dailyRoutineForTesting(date: try date(hour: 20, calendar: calendar), calendar: calendar)
        let night = GnomeTribeController.dailyRoutineForTesting(date: try date(hour: 23, calendar: calendar), calendar: calendar)

        #expect(preDawn.phase == "pre-dawn")
        #expect(dawn.phase == "dawn")
        #expect(morning.phase == "morning")
        #expect(afternoon.phase == "midday")
        #expect(evening.phase == "evening")
        #expect(night.phase == "night")
        #expect(night.homeLightIntensity > morning.homeLightIntensity)
        #expect(evening.socialBias > morning.socialBias)
        #expect(morning.buildBias > night.buildBias)
        #expect(preDawn.sleepBias > dawn.sleepBias)
        #expect(night.fireflyIntensity > afternoon.fireflyIntensity)
    }

    @Test("gnome society sends expeditions to tall outside plants and brings samples home")
    func gnomeSocietySendsExpeditionsToTallOutsidePlantsAndBringsSamplesHome() throws {
        let indexURL = try #require(GnomeTribeController.webAssetsIndexURL())
        let directoryURL = indexURL.deletingLastPathComponent()
        let main = try String(contentsOf: directoryURL.appendingPathComponent("main.js"), encoding: .utf8)
        let emergence = try String(contentsOf: directoryURL.appendingPathComponent("emergence.js"), encoding: .utf8)
        let pose = try String(contentsOf: directoryURL.appendingPathComponent("pose.js"), encoding: .utf8)
        let rendererSource = [main, emergence, pose].joined(separator: "\n")

        for requiredFragment in [
            "function expeditionPOIsForPolygon",
            "function createExpeditionKit",
            "function makeCollectionDepot",
            "function updateExpeditionVisuals",
            "expeditionPlant",
            "expeditionPlants",
            "allowOutside",
            "missionPhase",
            "sampleCarried",
            "deliveredSamples",
            "sampleStock",
            "grapplingLine",
            "sampleDepot",
            "resourceBoost",
            "resourceGate",
            "function settlementLifecycle",
            "function applySettlementLifecycle",
            "function makeResourceYard",
            "function makeCityUpgradeLayer",
            "gnomeResourceYard",
            "rawResourcePile",
            "woodPile",
            "tunnelBorrowDepot",
            "interColonySupplyCart",
            "gnomeCityUpgradeLayer",
            "verticalUpgradeTier",
            "gnomeAerialWalkway",
            "action === 'sample'",
            "grappleAim",
            "grappleShoot",
            "ziplineUp",
            "rappelDown",
            "function beginGrappleSequence",
            "function stepGrappleSequence",
            "function beginCollectionSequence",
            "grapplingHook",
            "grappleProgress",
            "ziplineHeight",
            "ropeSag",
            "resourceCollectionPlan",
            "canopyInspect",
            "extractTap",
            "sampleBundle",
            "collectionMotes",
            "toolBlade",
            "function createCollectionContactMarker",
            "collectionContactMarker",
            "resourceCollectionWorkPoint",
            "sampleProcessingBench",
            "resourceLedger",
            "setStock(count, samplePlan",
            "lastDeliveryPulse",
            "harvestMemory",
            "harvestPressureFor",
            "sampleYield",
            "catalogSample"
        ] {
            #expect(rendererSource.contains(requiredFragment))
        }
    }

    @Test("gnome society can ride butterflies around plants and return them safely")
    func gnomeSocietyCanRideButterfliesAroundPlantsAndReturnThemSafely() throws {
        let indexURL = try #require(GnomeTribeController.webAssetsIndexURL())
        let directoryURL = indexURL.deletingLastPathComponent()
        let main = try String(contentsOf: directoryURL.appendingPathComponent("main.js"), encoding: .utf8)
        let emergence = try String(contentsOf: directoryURL.appendingPathComponent("emergence.js"), encoding: .utf8)
        let pose = try String(contentsOf: directoryURL.appendingPathComponent("pose.js"), encoding: .utf8)
        let rendererSource = [main, emergence, pose].joined(separator: "\n")

        for requiredFragment in [
            "function butterflyPOIsForPolygon",
            "butterflyPOIs",
            "function pickButterflyPOI",
            "function maybeChooseButterflyRide",
            "function butterflyFlightPlanFor",
            "function stepButterflyRideSequence",
            "butterflyMount",
            "butterflyLaunch",
            "butterflyRide",
            "butterflyReturn",
            "butterflyRelease",
            "function createButterflyMount",
            "gnomeButterflyMount",
            "butterflySaddle",
            "butterflyReinLeft",
            "butterflyReinRight",
            "wingPivots",
            "function updateButterflyRideVisuals",
            "butterflyDepthCue",
            "butterflyBank",
            "plantTargets"
        ] {
            #expect(rendererSource.contains(requiredFragment))
        }
    }

    @Test("gnome settlement plans stage expansion from a selected starting zone")
    func gnomeSettlementPlansStageExpansionFromASelectedStartingZone() throws {
        let startID = try #require(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
        let farID = try #require(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"))
        let nearID = try #require(UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"))
        let startDate = try date(hour: 12, calendar: Calendar(identifier: .gregorian))
        let zones = [
            GnomeTribeZone(
                id: farID,
                screenIndex: 0,
                points: [
                    GardenPoint(x: 0.78, y: 0.16),
                    GardenPoint(x: 0.94, y: 0.16),
                    GardenPoint(x: 0.86, y: 0.36)
                ]
            ),
            GnomeTribeZone(
                id: startID,
                screenIndex: 0,
                points: [
                    GardenPoint(x: 0.12, y: 0.2),
                    GardenPoint(x: 0.32, y: 0.2),
                    GardenPoint(x: 0.22, y: 0.48)
                ]
            ),
            GnomeTribeZone(
                id: nearID,
                screenIndex: 0,
                points: [
                    GardenPoint(x: 0.42, y: 0.2),
                    GardenPoint(x: 0.58, y: 0.2),
                    GardenPoint(x: 0.50, y: 0.42)
                ]
            )
        ]
        let plan = GnomeTribeSettlementPlan(
            startedAt: startDate,
            startingZoneID: startID,
            expansionDurationDays: 3
        )

        #expect(GnomeTribeController.orderedSettlementZoneIDsForTesting(zones: zones, plan: plan) == [startID, nearID, farID])

        let justStarted = GnomeTribeController.settlementProgressForTesting(
            zone: zones[1],
            zones: zones,
            plan: plan,
            date: startDate
        )
        let farProgress = GnomeTribeController.settlementProgressForTesting(
            zone: zones[0],
            zones: zones,
            plan: plan,
            date: startDate.addingTimeInterval(1.2 * 24 * 60 * 60)
        )

        #expect(justStarted > 0)
        #expect(justStarted < 0.35)
        #expect(farProgress == 0)
    }

    @Test("uncommitted gnome settlement plans do not render until done")
    func uncommittedGnomeSettlementPlansDoNotRenderUntilDone() {
        var state = GardenState(
            gnomeTribeZones: [
                GnomeTribeZone(screenIndex: 0, points: [
                    GardenPoint(x: 0.2, y: 0.4),
                    GardenPoint(x: 0.6, y: 0.4),
                    GardenPoint(x: 0.5, y: 0.8)
                ])
            ],
            gnomeSettlementPlan: GnomeTribeSettlementPlan(startedAt: nil)
        )

        #expect(!GnomeTribeController.shouldShow(for: state))

        state.gnomeSettlementPlan = GnomeTribeSettlementPlan(startedAt: Date(), startingZoneID: state.gnomeTribeZones[0].id)

        #expect(GnomeTribeController.shouldShow(for: state))
    }

    @Test("gnome web layer supports staged settlements and tunnel expansion")
    func gnomeWebLayerSupportsStagedSettlementsAndTunnelExpansion() throws {
        let indexURL = try #require(GnomeTribeController.webAssetsIndexURL())
        let directoryURL = indexURL.deletingLastPathComponent()
        let main = try String(contentsOf: directoryURL.appendingPathComponent("main.js"), encoding: .utf8)

        for requiredFragment in [
            "settlementProgress",
            "isStartingZone",
            "settlementExpansionDays",
            "function makeTunnelEntrance",
            "tunnelEntrances",
            "tunnelMound",
            "function settlementLifecycle",
            "function applySettlementLifecycle",
            "resourceMaturity",
            "finishedFraction",
            "borrowBoost",
            "resourceGate",
            "siteCount",
            "gnomeResourceYard",
            "tunnelBorrowDepot",
            "interColonySupplyCart",
            "gnomeCityUpgradeLayer",
            "verticalUpgradeTier"
        ] {
            #expect(main.contains(requiredFragment))
        }
    }

    @Test("gnome bridge lighting dims at night and honors manual scene darkening")
    func gnomeBridgeLightingDimsAtNightAndHonorsManualSceneDarkening() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let noon = try date(hour: 12, calendar: calendar)
        let night = try date(hour: 23, calendar: calendar)
        let daylightState = GardenState()
        let shadedState = GardenState(manualPlantDarkening: 0.42)

        let noonLight = GnomeTribeController.lightLevelForTesting(
            state: daylightState,
            date: noon,
            calendar: calendar
        )
        let nightLight = GnomeTribeController.lightLevelForTesting(
            state: daylightState,
            date: night,
            calendar: calendar
        )
        let shadedNoonLight = GnomeTribeController.lightLevelForTesting(
            state: shadedState,
            date: noon,
            calendar: calendar
        )

        #expect(noonLight > 0.85)
        #expect(nightLight < noonLight)
        #expect(shadedNoonLight < noonLight)
        #expect(shadedNoonLight > nightLight)
    }

    @Test("gnome bridge gives mature trees and foliage stronger resource value")
    func gnomeBridgeGivesMatureTreesAndFoliageStrongerResourceValue() {
        let tree = Plant(
            species: .japaneseMaple,
            screenIndex: 0,
            position: GardenPoint(x: 0.45, y: 0.58),
            growth: 1.0,
            health: 0.92,
            scale: 1.6
        )
        let flower = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.55, y: 0.72),
            growth: 0.55,
            health: 0.86,
            scale: 0.8
        )

        #expect(GnomeTribeController.resourceValueForTesting(plant: tree) > GnomeTribeController.resourceValueForTesting(plant: flower))
        #expect(GnomeTribeController.resourceValueForTesting(plant: tree) > 0.8)
        #expect(GnomeTribeController.resourceValueForTesting(plant: flower) < 0.7)
    }

    @Test("gnome web layer only runs for visible garden zones")
    func gnomeWebLayerOnlyRunsForVisibleGardenZones() {
        var state = GardenState()
        #expect(!GnomeTribeController.shouldShow(for: state))

        state.gnomeTribeZones = [
            GnomeTribeZone(screenIndex: 0, points: [
                GardenPoint(x: 0.2, y: 0.4),
                GardenPoint(x: 0.6, y: 0.4),
                GardenPoint(x: 0.5, y: 0.8)
            ])
        ]
        state.gnomeSettlementPlan = GnomeTribeSettlementPlan(
            startedAt: Date(),
            startingZoneID: state.gnomeTribeZones[0].id
        )
        #expect(GnomeTribeController.shouldShow(for: state))

        state.settings = state.settings.updating(
            gnomeSimulation: state.settings.gnomeSimulation.updating(isEnabled: false)
        )
        #expect(!GnomeTribeController.shouldShow(for: state))

        state.settings = state.settings.updating(
            gnomeSimulation: state.settings.gnomeSimulation.updating(isEnabled: true)
        )
        #expect(GnomeTribeController.shouldShow(for: state))

        state.areGnomeTribesHidden = true
        #expect(!GnomeTribeController.shouldShow(for: state))

        state.areGnomeTribesHidden = false
        state.settings = state.settings.updating(experienceMode: .roomStudio)
        #expect(!GnomeTribeController.shouldShow(for: state))

        state.settings = state.settings.updating(experienceMode: .alienUFO)
        #expect(!GnomeTribeController.shouldShow(for: state))
    }

    @Test("gnome layer renders below the cat and above the garden")
    func gnomeLayerRendersBelowCatAndAboveGarden() {
        #expect(GnomeTribeWindow.companionLevel.rawValue > GardenWindow.canvasLevel.rawValue)
        #expect(CatCompanionWindow.companionLevel.rawValue > GnomeTribeWindow.companionLevel.rawValue)
    }

    private func date(hour: Int, calendar: Calendar) throws -> Date {
        try #require(DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 14,
            hour: hour
        ).date)
    }
}
