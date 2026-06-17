import AppKit
import PlantGardenCore

/// Live ambient bugs as Core Animation layers.
///
/// The painted-into-the-canvas wildlife could only move as fast as the
/// canvas repaints (every 0.5s — a slideshow). Here each bug is a tiny
/// layer tree whose flight path and wing flaps run as CAAnimations on the
/// macOS render server: silky 60/120fps motion with near-zero app CPU.
/// The app only wakes every couple of seconds to plan the next flight leg.
@MainActor
final class GardenBugSystem {
    private weak var view: GardenCanvasView?
    private let store: GardenStore
    private let screenIndex: Int
    private let hostLayer = CALayer()
    private var bugs: [Bug] = []
    private var planTimer: Timer?
    private var preyTimer: Timer?
    private var catchObserver: NSObjectProtocol?
    private var populationFingerprint = ""
    private var generation = 0
    private var isSuppressedByPlantSpotlight = false
    private static let maximumVisibleBugs = 12

    static func shouldSuppressLiveBugs(isPlantSpotlightVisible: Bool) -> Bool {
        isPlantSpotlightVisible
    }

    enum Species: String, CaseIterable {
        case monarchButterfly
        case whiteButterfly
        case blueMorphoButterfly
        case bee
        case dragonfly
        case hoverfly
        case moth
        case firefly
    }

    enum BehaviorKind: String, CaseIterable {
        case travel
        case plantVisit
        case nectarFeed
        case leafRest
        case bask
        case groom
        case patrol
        case glowDrift
    }

    struct BehaviorContext: Equatable {
        var livingPlantCount: Int
        var floweringPlantCount: Int
        var isNight: Bool
        var sceneKey: String
        var lastBehavior: BehaviorKind?
    }

    struct PlantVisitCandidate {
        var plantID: UUID
        var score: Double
        var hoverPoint: CGPoint
        var landingPoint: CGPoint
    }

    struct PreySnapshot: Equatable {
        var id: String
        var species: String
        var screenIndex: Int
        var screenX: CGFloat
        var screenY: CGFloat
        var isPlantFocused: Bool
    }

    private final class Bug {
        let id = UUID().uuidString
        let species: Species
        let container: CALayer
        let scale: CGFloat
        var isHovering = false
        var behavior: BehaviorKind = .travel
        var lastPlantID: UUID?
        init(species: Species, container: CALayer, scale: CGFloat) {
            self.species = species
            self.container = container
            self.scale = scale
        }
    }

    init(view: GardenCanvasView, store: GardenStore, screenIndex: Int) {
        self.view = view
        self.store = store
        self.screenIndex = screenIndex
        hostLayer.frame = view.bounds
        hostLayer.zPosition = 40
        hostLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(hostLayer)
        planTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncPopulation()
            }
        }
        planTimer?.tolerance = 0.5
        preyTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.publishPreySnapshot()
            }
        }
        preyTimer?.tolerance = 0.06
        catchObserver = NotificationCenter.default.addObserver(
            forName: .gardenCatCaughtBug,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let bugID = notification.userInfo?["bugID"] as? String
            let targetScreen = notification.userInfo?["screenIndex"] as? Int
            Task { @MainActor in
                self?.handleCatCaughtBug(id: bugID, screenIndex: targetScreen)
            }
        }
        syncPopulation()
    }

    func teardown() {
        planTimer?.invalidate()
        planTimer = nil
        preyTimer?.invalidate()
        preyTimer = nil
        if let catchObserver {
            NotificationCenter.default.removeObserver(catchObserver)
        }
        catchObserver = nil
        generation += 1
        hostLayer.removeFromSuperlayer()
        bugs = []
    }

    func syncPresentationState() {
        let isPlantSpotlightVisible = view?.isPlantExplorerVisibleForSelfTest() == true
        setSuppressedByPlantSpotlight(Self.shouldSuppressLiveBugs(isPlantSpotlightVisible: isPlantSpotlightVisible))
    }

    private func setSuppressedByPlantSpotlight(_ isSuppressed: Bool) {
        guard isSuppressedByPlantSpotlight != isSuppressed else {
            return
        }
        isSuppressedByPlantSpotlight = isSuppressed
        hostLayer.isHidden = isSuppressed
        publishPreySnapshot()
    }

    // MARK: - Habitat

    /// Which bugs live in which scene, day vs night. The weights bias the
    /// random draw, so a cottage garden is bee-and-butterfly country while
    /// the water pavilion belongs to dragonflies.
    static func habitat(sceneKey: String, isNight: Bool) -> [(Species, Double)] {
        if isNight {
            // Night fliers everywhere; fireflies favor lush outdoor scenes.
            let fireflyWeight: Double = sceneKey.contains("cottage") || sceneKey.contains("texas")
                || sceneKey.contains("moonlit") || sceneKey.contains("monk") ? 1.2 : 0.45
            return [(.moth, 1.0), (.firefly, fireflyWeight)]
        }
        switch GardenWallpaperScene.scene(forKey: sceneKey) {
        case .emptyWaterPavilion:
            return [(.dragonfly, 1.4), (.blueMorphoButterfly, 0.4), (.hoverfly, 0.3)]
        case .emptyDesertarium:
            return [(.hoverfly, 1.0), (.monarchButterfly, 0.5), (.dragonfly, 0.3)]
        case .moonlitEmptyGlasshouse:
            return [(.moth, 1.2), (.firefly, 0.8)]
        case .cottageBackyardGarden, .swedishPatioGarden:
            return [(.bee, 1.2), (.whiteButterfly, 0.9), (.monarchButterfly, 0.6), (.hoverfly, 0.4)]
        case .brazilianRooftopGarden:
            return [(.blueMorphoButterfly, 1.3), (.hoverfly, 0.6), (.bee, 0.5)]
        case .ancientEgyptianEstateGarden:
            return [(.dragonfly, 1.0), (.bee, 0.8), (.whiteButterfly, 0.4)]
        case .chineseMountainMonkGarden:
            return [(.blueMorphoButterfly, 1.0), (.dragonfly, 0.7), (.whiteButterfly, 0.5)]
        case .texasRusticGarden:
            return [(.monarchButterfly, 1.2), (.bee, 0.9), (.hoverfly, 0.4)]
        case .coastalPlantingTerrace:
            return [(.whiteButterfly, 1.1), (.bee, 0.7), (.dragonfly, 0.5)]
        case .alienCraterGreenhouse,
             .orbitalUfoTerrarium,
             .bioluminescentExoplanetOasis,
             .martianHydroponicDome,
             .alienCraterDome,
             .alienCliffsideHomeGarden,
             .alienCivicParkPlaza,
             .alienStarshipBotanyBay,
             .alienFloatingIslandSanctuary:
            return [(.firefly, 1.2), (.moth, 0.8), (.blueMorphoButterfly, 0.6), (.hoverfly, 0.4)]
        case .cozyApartmentStudio, .victorianSeedGallery, .emptyConservatoryHall:
            return [(.hoverfly, 1.0), (.whiteButterfly, 0.7)]
        default:
            return [(.whiteButterfly, 1.0), (.bee, 0.8), (.hoverfly, 0.6)]
        }
    }

    // MARK: - Population

    private func syncPopulation() {
        syncPresentationState()
        guard let view, let window = view.window, window.isVisible else {
            return
        }
        let state = store.state
        let plants = livingPlants()
        let profile = GardenSceneVisualProfile(sceneKey: store.activeSceneKey)
        let density = profile.wildlifeDensity * state.settings.wildlifeDensityMultiplier
        let isNight = state.sunlightCondition().mood == .night
        let flowering = plants.filter { $0.bloomProgress > 0.28 }.count
        let desired = Self.desiredBugCount(
            isEnabled: state.isEffectiveAmbientWildlifeEnabled,
            hasPlants: !plants.isEmpty,
            floweringPlantCount: flowering,
            wildlifeDensity: density
        )

        let fingerprint = "\(store.activeSceneKey ?? "")|\(isNight)|\(desired)|\(state.settings.bugSizeMultiplier)"
        if fingerprint != populationFingerprint {
            populationFingerprint = fingerprint
            rebuildPopulation(count: desired, isNight: isNight)
        }
        publishPreySnapshot()
    }

    private func rebuildPopulation(count: Int, isNight: Bool) {
        generation += 1
        for bug in bugs {
            let layer = bug.container
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.8)
            layer.opacity = 0
            CATransaction.setCompletionBlock {
                layer.removeFromSuperlayer()
            }
            CATransaction.commit()
        }
        bugs = []
        guard count > 0 else {
            return
        }

        let table = Self.habitat(sceneKey: store.activeSceneKey ?? "", isNight: isNight)
        for _ in 0..<count {
            let species = Self.pickWeighted(table)
            let bug = makeBug(species: species)
            bugs.append(bug)
            hostLayer.addSublayer(bug.container)
            planLeg(for: bug, generation: generation, firstLeg: true)
        }
    }

    private static func pickWeighted(_ table: [(Species, Double)]) -> Species {
        let total = table.reduce(0) { $0 + $1.1 }
        var roll = Double.random(in: 0..<max(0.001, total))
        for (species, weight) in table {
            roll -= weight
            if roll <= 0 {
                return species
            }
        }
        return table[0].0
    }

    static func pickWeightedBehavior(_ table: [(BehaviorKind, Double)]) -> BehaviorKind {
        let total = table.reduce(0) { $0 + $1.1 }
        var roll = Double.random(in: 0..<max(0.001, total))
        for (behavior, weight) in table {
            roll -= weight
            if roll <= 0 {
                return behavior
            }
        }
        return table.first?.0 ?? .travel
    }

    static func desiredBugCount(
        isEnabled: Bool,
        hasPlants: Bool,
        floweringPlantCount: Int,
        wildlifeDensity: Double
    ) -> Int {
        guard isEnabled, hasPlants, wildlifeDensity > 0.05 else {
            return 0
        }
        let hostFactor = Double(min(floweringPlantCount + 1, 5))
        return min(maximumVisibleBugs, max(1, Int((hostFactor * wildlifeDensity * 1.4).rounded())))
    }

    // MARK: - Bug construction

    private func makeBug(species: Species) -> Bug {
        let randomScale = CGFloat.random(in: 0.85...1.25)
        let scale = randomScale * CGFloat(store.state.settings.bugSizeMultiplier)
        let container = CALayer()
        let size = Self.spriteSize(
            for: species,
            randomScale: randomScale,
            settings: store.state.settings
        )
        container.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        container.position = randomAirPoint()
        // Perspective so wing rotations out of the screen plane read as 3D.
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / 110
        container.sublayerTransform = perspective
        container.opacity = 0

        GardenBugSprites.populate(container: container, species: species, scale: scale)
        GardenBugSprites.applyBehavior(.travel, to: container, species: species)

        // Fade in gently.
        CATransaction.begin()
        CATransaction.setAnimationDuration(1.2)
        container.opacity = 1
        CATransaction.commit()

        return Bug(species: species, container: container, scale: scale)
    }

    static func spriteSize(for species: Species, randomScale: CGFloat, settings: GardenSettings) -> CGFloat {
        GardenBugSprites.containerSize(for: species)
            * randomScale
            * CGFloat(settings.bugSizeMultiplier)
    }

    // MARK: - Flight planning

    private func planLeg(for bug: Bug, generation: Int, firstLeg: Bool = false) {
        guard generation == self.generation, let view, bugs.contains(where: { $0 === bug }) else {
            return
        }
        let speedMultiplier = max(0.2, store.state.settings.wildlifeSpeedMultiplier)
        let start = firstLeg
            ? bug.container.position
            : (bug.container.presentation()?.position ?? bug.container.position)

        let context = behaviorContext(lastBehavior: bug.behavior)
        let behavior = Self.pickWeightedBehavior(Self.behaviorWeights(for: bug.species, context: context))
        let plantCandidate = plantVisitCandidate(for: bug, from: start)
        let target: CGPoint
        if Self.behaviorWantsPlant(behavior), let plantCandidate {
            target = behavior == .plantVisit ? plantCandidate.hoverPoint : plantCandidate.landingPoint
            bug.lastPlantID = plantCandidate.plantID
        } else {
            target = nextAirTarget(near: view.bounds, from: start, species: bug.species)
        }

        let path = CGMutablePath()
        path.move(to: start)
        let motion = GardenBugSprites.motion(for: bug.species)
        if behavior == .patrol || behavior == .glowDrift {
            addPatrolPath(to: path, start: start, target: target, species: bug.species, bounds: view.bounds)
        } else {
            // Wandering bezier with species-tuned jitter: butterflies
            // flutter widely, dragonflies dart straight, moths spiral.
            var previous = start
            // Dragonflies fly direct but throw in the occasional sharp dart —
            // mostly one straight leg, sometimes a two-segment course change.
            let hops = bug.species == .dragonfly
                ? (Int.random(in: 0..<10) < 7 ? 1 : 2)
                : Int.random(in: 2...4)
            for hop in 0..<hops {
                let t = CGFloat(hop + 1) / CGFloat(hops)
                let mid = CGPoint(
                    x: start.x + (target.x - start.x) * t + CGFloat.random(in: -motion.jitter...motion.jitter),
                    y: start.y + (target.y - start.y) * t + CGFloat.random(in: -motion.jitter...motion.jitter)
                )
                let control = CGPoint(
                    x: (previous.x + mid.x) / 2 + CGFloat.random(in: -motion.jitter...motion.jitter),
                    y: (previous.y + mid.y) / 2 + CGFloat.random(in: -motion.jitter...motion.jitter)
                )
                path.addQuadCurve(to: mid, control: control)
                previous = mid
            }
        }

        let distance = hypot(target.x - start.x, target.y - start.y) * (behavior == .patrol ? 1.9 : 1.35)
        let duration = max(0.8, Double(distance) / (motion.speed * speedMultiplier))

        let flight = CAKeyframeAnimation(keyPath: "position")
        flight.path = path
        flight.duration = duration
        flight.calculationMode = .cubicPaced
        flight.rotationMode = motion.alignsToPath ? .rotateAuto : nil
        flight.timingFunction = CAMediaTimingFunction(name: behavior == .patrol ? .linear : .easeInEaseOut)
        flight.fillMode = .forwards
        flight.isRemovedOnCompletion = true

        bug.isHovering = behavior == .plantVisit
        bug.behavior = behavior
        GardenBugSprites.applyBehavior(behavior, to: bug.container, species: bug.species)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bug.container.position = target
        CATransaction.setCompletionBlock { [weak self] in
            Task { @MainActor in
                self?.beginPostFlightBehavior(for: bug, behavior: behavior, generation: generation)
            }
        }
        bug.container.add(flight, forKey: "flight")
        CATransaction.commit()
    }

    private func beginPostFlightBehavior(for bug: Bug, behavior: BehaviorKind, generation: Int) {
        guard generation == self.generation, bugs.contains(where: { $0 === bug }) else {
            return
        }

        let dwell = Self.dwellDuration(for: behavior, species: bug.species)
        guard dwell > 0 else {
            planLeg(for: bug, generation: generation)
            return
        }

        GardenBugSprites.applyBehavior(behavior, to: bug.container, species: bug.species)
        DispatchQueue.main.asyncAfter(deadline: .now() + dwell) { [weak self, weak bug] in
            Task { @MainActor in
                guard let self, let bug else {
                    return
                }
                bug.isHovering = false
                self.planLeg(for: bug, generation: generation)
            }
        }
    }

    private func addPatrolPath(
        to path: CGMutablePath,
        start: CGPoint,
        target: CGPoint,
        species: Species,
        bounds: CGRect
    ) {
        if species == .firefly || species == .moth {
            let radius = CGFloat.random(in: 20...54)
            let center = CGPoint(
                x: min(max((start.x + target.x) / 2, bounds.minX + radius), bounds.maxX - radius),
                y: min(max((start.y + target.y) / 2, bounds.minY + radius), bounds.maxY - radius)
            )
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 1.25))
            return
        }

        let control1 = CGPoint(x: start.x + CGFloat.random(in: -80...80), y: start.y + CGFloat.random(in: -60...60))
        let control2 = CGPoint(x: target.x + CGFloat.random(in: -80...80), y: target.y + CGFloat.random(in: -60...60))
        path.addCurve(to: target, control1: control1, control2: control2)
    }

    /// Somewhere worth flying in open air.
    private func nextAirTarget(near bounds: CGRect, from _: CGPoint, species: Species) -> CGPoint {
        let verticalRange: ClosedRange<CGFloat>
        switch species {
        case .dragonfly:
            verticalRange = bounds.height * 0.32...bounds.height * 0.76
        case .firefly, .moth:
            verticalRange = bounds.height * 0.26...bounds.height * 0.88
        default:
            verticalRange = bounds.height * 0.24...bounds.height * 0.84
        }

        return CGPoint(
            x: CGFloat.random(in: bounds.width * 0.1...bounds.width * 0.9),
            y: CGFloat.random(in: verticalRange)
        )
    }

    private func randomAirPoint() -> CGPoint {
        guard let view else {
            return .zero
        }
        return CGPoint(
            x: CGFloat.random(in: view.bounds.width * 0.15...view.bounds.width * 0.85),
            y: CGFloat.random(in: view.bounds.height * 0.35...view.bounds.height * 0.85)
        )
    }

    private func behaviorContext(lastBehavior: BehaviorKind?) -> BehaviorContext {
        let plants = livingPlants()
        return BehaviorContext(
            livingPlantCount: plants.count,
            floweringPlantCount: plants.filter { $0.bloomProgress > 0.28 }.count,
            isNight: store.state.sunlightCondition().mood == .night,
            sceneKey: store.activeSceneKey ?? "",
            lastBehavior: lastBehavior
        )
    }

    private func livingPlants() -> [Plant] {
        store.state.plants.filter { $0.screenIndex == screenIndex && !$0.isDead }
    }

    private func plantVisitCandidate(for bug: Bug, from point: CGPoint) -> PlantVisitCandidate? {
        guard let view else {
            return nil
        }

        let candidates = livingPlants().compactMap { plant -> PlantVisitCandidate? in
            let affinity = Self.plantAffinity(species: bug.species, plant: plant)
            guard affinity > 0.05 else {
                return nil
            }

            let anchor = view.anchorPoint(for: plant)
            let height = view.realisticHeight(for: plant, baseHeight: view.height(for: plant))
            let lateral = CGFloat.random(in: -0.22...0.22) * max(36, height * 0.38)
            let altitude = CGFloat(Self.plantLandingAltitude(for: bug.species, plant: plant))
            let landing = CGPoint(
                x: min(max(anchor.x + lateral, 26), view.bounds.maxX - 26),
                y: min(max(anchor.y - height * altitude, 32), view.bounds.maxY - 42)
            )
            let hover = CGPoint(
                x: min(max(landing.x + CGFloat.random(in: -18...18), 26), view.bounds.maxX - 26),
                y: min(max(landing.y - CGFloat.random(in: 10...28), 28), view.bounds.maxY - 42)
            )
            let distancePenalty = min(0.35, Double(hypot(landing.x - point.x, landing.y - point.y)) / 2_800)
            let repeatPenalty = plant.id == bug.lastPlantID ? 0.10 : 0
            return PlantVisitCandidate(
                plantID: plant.id,
                score: affinity - distancePenalty - repeatPenalty,
                hoverPoint: hover,
                landingPoint: landing
            )
        }

        return candidates.max { $0.score < $1.score }
    }

    static func behaviorWeights(for species: Species, context: BehaviorContext) -> [(BehaviorKind, Double)] {
        if context.isNight {
            switch species {
            case .firefly:
                return [(.glowDrift, 1.35), (.plantVisit, 0.40), (.leafRest, 0.22), (.travel, 0.18)]
            case .moth:
                return [(.plantVisit, 0.95), (.groom, 0.35), (.patrol, 0.30), (.leafRest, 0.24), (.travel, 0.18)]
            default:
                return [(.leafRest, 0.65), (.travel, 0.18)]
            }
        }

        let hasPlants = context.livingPlantCount > 0
        let hasFlowers = context.floweringPlantCount > 0
        let plantWeight = hasPlants ? 0.55 : 0
        let nectarWeight = hasFlowers ? 0.70 : 0

        var weights: [(BehaviorKind, Double)]
        switch species {
        case .bee:
            weights = [(.nectarFeed, nectarWeight + 0.45), (.plantVisit, plantWeight), (.groom, 0.24), (.travel, 0.20)]
        case .hoverfly:
            weights = [(.plantVisit, plantWeight + 0.45), (.nectarFeed, nectarWeight * 0.65), (.patrol, 0.42), (.travel, 0.18)]
        case .dragonfly:
            // Patrol dominates (fast direct passes); bask = crisp mid-air
            // hovers between darts. Travel stays the rarest — darners don't
            // meander.
            weights = [(.patrol, 0.82), (.bask, 0.46), (.plantVisit, plantWeight * 0.62), (.travel, 0.20)]
        case .monarchButterfly, .whiteButterfly, .blueMorphoButterfly:
            weights = [(.plantVisit, plantWeight + 0.42), (.nectarFeed, nectarWeight * 0.72), (.bask, 0.32), (.travel, 0.22)]
        case .moth:
            weights = [(.leafRest, 0.54), (.plantVisit, plantWeight * 0.48), (.groom, 0.34), (.travel, 0.18)]
        case .firefly:
            weights = [(.leafRest, 0.48), (.travel, 0.24)]
        }

        if let last = context.lastBehavior {
            weights = weights.map { behavior, weight in
                behavior == last ? (behavior, weight * 0.55) : (behavior, weight)
            }
        }

        return weights.filter { $0.1 > 0.001 }
    }

    static func plantAffinity(species: Species, plant: Plant) -> Double {
        var score = 0.16
        if plant.bloomProgress > 0.28 {
            score += 0.42 + plant.bloomProgress * 0.22
        }
        if plant.hydration > 0.45 {
            score += 0.08
        }

        switch species {
        case .bee, .hoverfly:
            if plant.species.kind == .flower || plant.species.kind == .edible {
                score += 0.30
            }
            if plant.species == .lavender || plant.species == .sunflower || plant.species == .rose || plant.species == .thyme {
                score += 0.22
            }
        case .monarchButterfly, .whiteButterfly, .blueMorphoButterfly:
            if plant.species.kind == .flower || plant.species.kind == .meadow {
                score += 0.28
            }
            if plant.species == .wildflowerMeadow || plant.species == .lavenderField {
                score += 0.20
            }
        case .dragonfly:
            if plant.species == .waterLily || plant.species == .cattails {
                score += 0.50
            }
            if plant.species.kind == .meadow {
                score += 0.12
            }
        case .moth:
            if plant.species == .jasmine || plant.species == .lily || plant.species == .orchid {
                score += 0.30
            }
            if plant.species.kind == .flower {
                score += 0.18
            }
        case .firefly:
            if plant.species.kind == .meadow || plant.species == .fern || plant.species == .ivy {
                score += 0.16
            }
        }

        return min(1.45, score)
    }

    static func plantLandingAltitude(for species: Species, plant: Plant) -> Double {
        switch species {
        case .bee, .hoverfly:
            plant.bloomProgress > 0.28 ? 0.74 : 0.58
        case .dragonfly:
            plant.species == .waterLily || plant.species == .cattails ? 0.42 : 0.72
        case .firefly:
            0.50
        case .moth:
            0.66
        case .monarchButterfly, .whiteButterfly, .blueMorphoButterfly:
            plant.bloomProgress > 0.28 ? 0.78 : 0.64
        }
    }

    static func behaviorWantsPlant(_ behavior: BehaviorKind) -> Bool {
        switch behavior {
        case .plantVisit, .nectarFeed, .leafRest, .bask, .groom:
            true
        case .travel, .patrol, .glowDrift:
            false
        }
    }

    static func dwellDuration(for behavior: BehaviorKind, species: Species) -> TimeInterval {
        let base: ClosedRange<TimeInterval>
        switch behavior {
        case .nectarFeed:
            base = species == .bee || species == .hoverfly ? 1.8...4.4 : 1.4...3.2
        case .plantVisit:
            base = 0.7...1.8
        case .leafRest:
            base = 3.0...8.0
        case .bask:
            base = 2.5...5.5
        case .groom:
            base = 1.2...3.0
        case .travel, .patrol, .glowDrift:
            return 0
        }
        return TimeInterval.random(in: base)
    }

    // MARK: - Cat prey bridge

    private func publishPreySnapshot() {
        guard !isSuppressedByPlantSpotlight,
              let view,
              let window = view.window,
              window.isVisible else {
            postEmptyPreySnapshot()
            return
        }

        let snapshots = bugs.compactMap { bug -> PreySnapshot? in
            let layer = bug.container.presentation() ?? bug.container
            guard layer.opacity > 0.08 else {
                return nil
            }
            let localPoint = NSPoint(x: layer.position.x, y: layer.position.y)
            let windowPoint = view.convert(localPoint, to: nil)
            let screenPoint = window.convertPoint(toScreen: windowPoint)
            return PreySnapshot(
                id: bug.id,
                species: bug.species.rawValue,
                screenIndex: screenIndex,
                screenX: screenPoint.x,
                screenY: screenPoint.y,
                isPlantFocused: Self.behaviorWantsPlant(bug.behavior)
            )
        }

        NotificationCenter.default.post(
            name: .gardenBugPreySnapshotDidChange,
            object: self,
            userInfo: ["screenIndex": screenIndex, "bugs": snapshots]
        )
    }

    private func postEmptyPreySnapshot() {
        NotificationCenter.default.post(
            name: .gardenBugPreySnapshotDidChange,
            object: self,
            userInfo: ["screenIndex": screenIndex, "bugs": [PreySnapshot]()]
        )
    }

    private func handleCatCaughtBug(id bugID: String?, screenIndex targetScreen: Int?) {
        guard let bugID else {
            return
        }
        if let targetScreen, targetScreen != screenIndex {
            return
        }
        catchBug(id: bugID)
    }

    private func catchBug(id: String) {
        guard let index = bugs.firstIndex(where: { $0.id == id }) else {
            return
        }
        let bug = bugs.remove(at: index)
        bug.container.removeAllAnimations()
        bug.container.sublayers?.forEach { $0.removeAllAnimations() }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.28)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        bug.container.opacity = 0
        bug.container.transform = CATransform3DMakeScale(0.28, 0.28, 1)
        CATransaction.setCompletionBlock {
            bug.container.removeFromSuperlayer()
        }
        CATransaction.commit()
        publishPreySnapshot()

        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval.random(in: 10...22)) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.populationFingerprint = ""
                self.syncPopulation()
            }
        }
    }
}

extension Notification.Name {
    static let gardenBugPreySnapshotDidChange = Notification.Name("gardenBugPreySnapshotDidChange")
    static let gardenCatCaughtBug = Notification.Name("gardenCatCaughtBug")
}
