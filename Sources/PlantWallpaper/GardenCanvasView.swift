import AppKit
import PlantGardenCore

extension Notification.Name {
    static let gardenPlantSpotlightVisibilityChanged = Notification.Name("gardenPlantSpotlightVisibilityChanged")
}

@MainActor
final class GardenCanvasView: NSView {
    enum InspectorAction: CaseIterable {
        case care
        case water
        case nourish
        case harvest
        case prune
        case clone
        case explore
        case lockPlacement
        case remove

        var symbolName: String {
            switch self {
            case .care:
                "heart.fill"
            case .water:
                "drop.fill"
            case .nourish:
                "sparkles"
            case .harvest:
                "basket.fill"
            case .prune:
                "scissors"
            case .clone:
                "doc.on.doc"
            case .explore:
                "sparkle.magnifyingglass"
            case .lockPlacement:
                "lock.open.fill"
            case .remove:
                "trash"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .care:
                "Smart Care"
            case .water:
                "Water"
            case .nourish:
                "Nourish"
            case .harvest:
                "Harvest"
            case .prune:
                "Prune"
            case .clone:
                "Clone"
            case .explore:
                "Explore"
            case .lockPlacement:
                "Lock Placement"
            case .remove:
                "Remove"
            }
        }
    }

    enum GardenCanvasInteractionResult: Equatable {
        case none
        case handled
        case drag
    }

    enum ResizeHandle: CaseIterable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight

        func cornerPoint(in rect: NSRect) -> NSPoint {
            switch self {
            case .topLeft:
                NSPoint(x: rect.minX, y: rect.minY)
            case .topRight:
                NSPoint(x: rect.maxX, y: rect.minY)
            case .bottomLeft:
                NSPoint(x: rect.minX, y: rect.maxY)
            case .bottomRight:
                NSPoint(x: rect.maxX, y: rect.maxY)
            }
        }
    }

    struct PlantResizeSession {
        var plantID: UUID
        var frameCenter: NSPoint
        var initialScale: Double
        var initialDistanceFromCenter: CGFloat
    }

    struct MusicButtonDragSession {
        var buttonIndex: Int
        var initialCenter: NSPoint
        var dragOffset: NSPoint
        var clickCount: Int
        var didMove: Bool
    }

    struct MusicButtonHoverState: Equatable {
        var buttonIndex: Int
        var enteredAt: Date
    }

    struct PendingCustomAssetDragSession {
        var pendingID: UUID
        var dragOffset: NSPoint
    }

    static let selectionFrameOutset: CGFloat = 10
    static let selectionFrameLineHitWidth: CGFloat = 10
    static let resizeHandleSize: CGFloat = 12
    static let resizeHandleHitOutset: CGFloat = 5
    static let musicButtonSize: CGFloat = 82
    static let musicButtonHitOutset: CGFloat = 8
    static let musicButtonHoverActivationInterval: TimeInterval = 3.0
    static let musicButtonHoverScaleBonus: CGFloat = 0.18
    static let pendingCustomAssetAnimationInterval: TimeInterval = 1.0 / 60.0
    static let gnomeZoneMarkerWidth: CGFloat = 46
    static let birdSkyZoneMarkerWidth: CGFloat = 54
    private static let gardenPlantLayerCachePixelBudget = 18_000_000
    private static let roomStudioPlantLayerCachePixelBudget = 6_000_000
    private static let alienPlantLayerCachePixelBudget = 10_000_000

    let screenIndex: Int
    let store: GardenStore
    let musicPlayer: GardenMusicPlaybackControlling
    /// Distance (in points) the pointer must travel before a press on a plant
    /// becomes a drag. Prevents selection clicks from nudging plants.
    static let plantDragStartThreshold: CGFloat = 4

    var draggingPlantID: UUID?
    var resizeSession: PlantResizeSession?
    var musicButtonDragSession: MusicButtonDragSession?
    var musicButtonHoverState: MusicButtonHoverState?
    var pendingCustomAssetDragSession: PendingCustomAssetDragSession?
    var pendingCustomAssetAnimationTimer: Timer?
    var isGnomeZoneDrawingMode = false {
        didSet {
            guard oldValue != isGnomeZoneDrawingMode else {
                return
            }
            if !isGnomeZoneDrawingMode {
                gnomeZoneDraftPoints = []
            }
            needsDisplay = true
        }
    }
    var isGnomePerspectiveAdjustmentMode = false {
        didSet {
            guard oldValue != isGnomePerspectiveAdjustmentMode else {
                return
            }
            if !isGnomePerspectiveAdjustmentMode {
                hoveredPerspectiveZoneIndex = nil
                isPerspectiveDoneButtonHovered = false
            }
            needsDisplay = true
        }
    }
    // Hover state for the in-scene perspective overlay (per-zone rotate gizmos
    // + the floating Done button). Updated as the pointer moves while the mode
    // is active; nil/false otherwise.
    var hoveredPerspectiveZoneIndex: Int?
    var isPerspectiveDoneButtonHovered = false
    var gnomeZoneDraftPoints: [NSPoint] = []
    var isBirdSkyZoneDrawingMode = false {
        didSet {
            guard oldValue != isBirdSkyZoneDrawingMode else {
                return
            }
            if !isBirdSkyZoneDrawingMode {
                birdSkyZoneDraftPoints = []
            }
            needsDisplay = true
        }
    }
    var birdSkyZoneDraftPoints: [NSPoint] = []
    var isSoilBrushMode = false {
        didSet {
            guard oldValue != isSoilBrushMode else {
                return
            }
            if !isSoilBrushMode {
                soilBrushDraftPoints = []
            }
            needsDisplay = true
        }
    }
    var soilBrushDraftPoints: [NSPoint] = []
    var soilBrushRadius: CGFloat = 28
    private var musicButtonHoverTrackingArea: NSTrackingArea?
    var musicButtonHoverAnimationTimer: Timer?
    var dragOffset = NSPoint.zero
    var dragStartPoint = NSPoint.zero
    var dragDidMovePlant = false
    var pinnedInspectorPlantID: UUID?
    var pinnedInspectorRect: NSRect?
    var plantExplorerPlantID: UUID? {
        didSet {
            guard (oldValue != nil) != (plantExplorerPlantID != nil) else {
                return
            }
            NotificationCenter.default.post(
                name: .gardenPlantSpotlightVisibilityChanged,
                object: self,
                userInfo: [
                    "screenIndex": screenIndex,
                    "isVisible": plantExplorerPlantID != nil
                ]
            )
        }
    }
    var mouseDownHandler: ((NSEvent) -> Bool)?
    var mouseDraggedHandler: ((NSEvent) -> Bool)?
    var mouseUpHandler: ((NSEvent) -> Void)?
    /// Snapshot renders set this to false so saved images contain only the
    /// garden itself - no selection frame, inspector, or drawing guides.
    var drawsInteractiveChrome = true
    /// Offscreen exports still need real placed scene objects, such as radio
    /// companions, while keeping inspector/selection UI out of the image.
    var drawsSceneObjectsWhenChromeHidden = false

    /// While AI Lock View has baked the garden into a generated wallpaper, the
    /// user's placed plants/trees are hidden so only the new wallpaper shows;
    /// they reappear when AI Lock View ends. Transient view state — never
    /// persisted, resets to false on launch. The offscreen snapshot renderer
    /// keeps this false so the source image sent to OpenAI still contains the
    /// plants for the model to paint over.
    var arePlantsHiddenForAILockView = false

    /// Cached rendering of every plant on this canvas. Plant artwork is
    /// deterministic given plant state, so in steady state (wildlife/mist
    /// ticks only) each repaint blits this layer instead of re-rendering
    /// N plants — shadows, root integration, and all. Rebuilt only when the
    /// render-relevant state signature changes.
    private var plantsLayerImage: NSImage?
    private var plantsLayerRect = NSRect.zero
    private var plantsLayerSignature = 0
    /// Cached soil-sink depth per plant id. Invalidated when the soil-patch
    /// set changes or the view geometry/backing scale changes, because the
    /// hit-test that produces it depends on both.
    var soilSinkDepthCache: [UUID: CGFloat] = [:]
    var soilSinkCacheSignature = 0
    var soilSinkCacheBounds = NSRect.zero
    var currentDateProvider: () -> Date = Date.init

    override var isFlipped: Bool {
        true
    }

    init(
        frame frameRect: NSRect,
        screenIndex: Int,
        store: GardenStore,
        musicPlayer: GardenMusicPlaybackControlling = GardenRadioPlayer.shared
    ) {
        self.screenIndex = screenIndex
        self.store = store
        self.musicPlayer = musicPlayer
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            clearMusicButtonHover()
            stopPendingCustomAssetAnimation()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let musicButtonHoverTrackingArea {
            removeTrackingArea(musicButtonHoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        musicButtonHoverTrackingArea = trackingArea
        addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil)
        updateMusicButtonHover(at: point)
        updatePerspectiveHover(at: [point])
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        clearMusicButtonHover()
        clearPerspectiveHover()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let profile = sceneVisualProfile()
        let drawsGardenAtmosphere = drawsGardenAtmosphericCanvasEffects()
        if drawsGardenAtmosphere {
            drawAtmosphereBehindPlants(profile: profile)
            drawSceneMist(profile: profile)
            drawGroundGlow(profile: profile)
        }

        let plants = store.state.plants
            .filter { $0.screenIndex == screenIndex }
            .sorted { $0.position.y < $1.position.y }

        // Soil patches render UNDER plants so plant bases sink into the dirt.
        drawSoilPatchesIfNeeded()
        drawPlants(plants, profile: profile, dirtyRect: dirtyRect)
        drawPendingCustomPlantAssets(dirtyRect: dirtyRect)

        // Ambient wildlife lives on GardenBugSystem's CALayers now —
        // render-server animated at full refresh rate instead of being
        // repainted here at the canvas cadence. Offscreen exports
        // (snapshots, share cards) still draw the painted bugs so saved
        // images aren't empty of life.
        if !drawsInteractiveChrome {
            drawAmbientWildlife(profile: profile, plants: plants)
        }
        if drawsGardenAtmosphere {
            drawForegroundSceneHaze(profile: profile)
            drawWeatherOverlay(profile: profile)
            drawRareMomentOverlay(profile: profile)
        }

        if drawsInteractiveChrome || drawsSceneObjectsWhenChromeHidden {
            drawMusicButtonIfNeeded()
        }

        guard drawsInteractiveChrome else {
            return
        }

        drawFocusSessionRingIfNeeded()
        drawSoilBrushDraftIfNeeded()
        drawGnomeTribeZonesIfNeeded()
        drawGnomePerspectiveOverlayIfNeeded()
        drawBirdSkyZonesIfNeeded()

        if let selectedPlant = store.selectedPlant,
           selectedPlant.screenIndex == screenIndex,
           canDisplay(selectedPlant) {
            drawSelectionFrame(for: selectedPlant)
            drawInspector(for: selectedPlant)
        }

        drawPlantExplorerIfNeeded()
    }

    private func drawsGardenAtmosphericCanvasEffects() -> Bool {
        store.state.settings.experienceMode == .garden
    }

    private func drawPlants(_ plants: [Plant], profile: GardenSceneVisualProfile, dirtyRect: NSRect) {
        guard !arePlantsHiddenForAILockView else {
            plantsLayerImage = nil
            return
        }
        guard !plants.isEmpty else {
            plantsLayerImage = nil
            return
        }

        // Live rendering whenever anything plant-level is animating
        // (tending glows, milestones, rain, focus sessions), during direct
        // manipulation, and for offscreen exports. This is exactly the old
        // draw path, so animated visuals are unchanged.
        let mustDrawLive = window == nil
            || draggingPlantID != nil
            || resizeSession != nil
            || GardenDisplayCadence.hasTransientActivity(state: store.state)
        if mustDrawLive {
            plantsLayerImage = nil
            // Skip geometry work for plants that cannot intersect the dirty
            // region - during drags only a small rect repaints per event.
            for plant in plants where dirtyRect == bounds || redrawRect(for: plant).intersects(dirtyRect) {
                drawPlant(plant, profile: profile)
            }
            return
        }

        guard plantLayerCachePlan(for: plants).shouldUseCompositeCache else {
            plantsLayerImage = nil
            plantsLayerRect = .zero
            for plant in plants where dirtyRect == bounds || redrawRect(for: plant).intersects(dirtyRect) {
                drawPlant(plant, profile: profile)
            }
            return
        }

        let signature = plantsRenderSignature(for: plants)
        if plantsLayerImage == nil || signature != plantsLayerSignature {
            rebuildPlantsLayer(plants: plants, profile: profile)
            plantsLayerSignature = signature
        }
        guard let layer = plantsLayerImage, plantsLayerRect.intersects(dirtyRect) else {
            return
        }
        layer.draw(
            in: plantsLayerRect,
            from: NSRect(origin: .zero, size: layer.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.none]
        )
    }

    private func drawGnomeTribeZonesIfNeeded() {
        guard isGnomeZoneDrawingMode || !gnomeZoneDraftPoints.isEmpty else {
            return
        }

        NSGraphicsContext.saveGraphicsState()
        if isGnomeZoneDrawingMode {
            let savedZones = store.state.gnomeTribeZones.filter { $0.screenIndex == screenIndex }
            for zone in savedZones {
                let points = zone.points.map { point in
                    NSPoint(
                        x: bounds.width * CGFloat(point.x),
                        y: bounds.height * CGFloat(point.y)
                    )
                }
                drawGnomeZonePath(
                    points: points,
                    fill: NSColor.systemGreen.withAlphaComponent(0.08),
                    stroke: NSColor.systemGreen.withAlphaComponent(0.34)
                )
            }
        }
        if !gnomeZoneDraftPoints.isEmpty {
            drawGnomeZonePath(
                points: gnomeZoneDraftPoints,
                fill: NSColor.systemGreen.withAlphaComponent(0.16),
                stroke: NSColor.systemYellow.withAlphaComponent(0.58)
            )
            drawGnomeMarkerCaps(points: gnomeZoneDraftPoints)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawGnomeZonePath(points: [NSPoint], fill: NSColor, stroke: NSColor) {
        guard points.count >= 2 else {
            return
        }

        let path = NSBezierPath()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = Self.gnomeZoneMarkerWidth
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.line(to: point)
        }
        stroke.setStroke()
        path.stroke()

        guard points.count >= GnomeTribeZone.minimumPointCount else {
            return
        }

        let filledPath = NSBezierPath()
        filledPath.move(to: points[0])
        for point in points.dropFirst() {
            filledPath.line(to: point)
        }
        filledPath.close()
        fill.setFill()
        filledPath.fill()
    }

    private func drawGnomeMarkerCaps(points: [NSPoint]) {
        guard let last = points.last else {
            return
        }

        let capRect = NSRect(
            x: last.x - Self.gnomeZoneMarkerWidth / 2,
            y: last.y - Self.gnomeZoneMarkerWidth / 2,
            width: Self.gnomeZoneMarkerWidth,
            height: Self.gnomeZoneMarkerWidth
        )
        let cap = NSBezierPath(ovalIn: capRect)
        NSColor.systemYellow.withAlphaComponent(0.35).setFill()
        cap.fill()
        NSColor.white.withAlphaComponent(0.48).setStroke()
        cap.lineWidth = 2
        cap.stroke()
    }

    private func drawBirdSkyZonesIfNeeded() {
        guard isBirdSkyZoneDrawingMode || !birdSkyZoneDraftPoints.isEmpty else {
            return
        }

        NSGraphicsContext.saveGraphicsState()
        if isBirdSkyZoneDrawingMode {
            let savedZones = store.state.birdSkyZones.filter { $0.screenIndex == screenIndex }
            for zone in savedZones {
                let points = zone.points.map { point in
                    NSPoint(
                        x: bounds.width * CGFloat(point.x),
                        y: bounds.height * CGFloat(point.y)
                    )
                }
                drawBirdSkyZonePath(
                    points: points,
                    fill: NSColor.systemCyan.withAlphaComponent(0.07),
                    stroke: NSColor.systemCyan.withAlphaComponent(0.28)
                )
            }
        }

        if !birdSkyZoneDraftPoints.isEmpty {
            drawBirdSkyZonePath(
                points: birdSkyZoneDraftPoints,
                fill: NSColor.systemCyan.withAlphaComponent(0.15),
                stroke: NSColor.white.withAlphaComponent(0.62)
            )
            drawBirdSkyMarkerCaps(points: birdSkyZoneDraftPoints)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawBirdSkyZonePath(points: [NSPoint], fill: NSColor, stroke: NSColor) {
        guard points.count >= 2 else {
            return
        }

        let path = NSBezierPath()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = Self.birdSkyZoneMarkerWidth
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.line(to: point)
        }
        stroke.setStroke()
        path.stroke()

        guard points.count >= BirdSkyZone.minimumPointCount else {
            return
        }

        let filledPath = NSBezierPath()
        filledPath.move(to: points[0])
        for point in points.dropFirst() {
            filledPath.line(to: point)
        }
        filledPath.close()
        fill.setFill()
        filledPath.fill()
    }

    private func drawBirdSkyMarkerCaps(points: [NSPoint]) {
        guard let last = points.last else {
            return
        }

        let capRect = NSRect(
            x: last.x - Self.birdSkyZoneMarkerWidth / 2,
            y: last.y - Self.birdSkyZoneMarkerWidth / 2,
            width: Self.birdSkyZoneMarkerWidth,
            height: Self.birdSkyZoneMarkerWidth
        )
        let cap = NSBezierPath(ovalIn: capRect)
        NSColor.systemCyan.withAlphaComponent(0.24).setFill()
        cap.fill()
        NSColor.white.withAlphaComponent(0.58).setStroke()
        cap.lineWidth = 2
        cap.stroke()
    }

    /// Everything the plant renderer reads, quantized so imperceptible
    /// simulation drift (growth creeping by fractions of a percent each
    /// tick) doesn't force rebuilds.
    private func plantsRenderSignature(for plants: [Plant]) -> Int {
        var hasher = Hasher()
        hasher.combine(arePlantsHiddenForAILockView)
        hasher.combine(bounds.width)
        hasher.combine(bounds.height)
        let backingScale = window?.backingScaleFactor ?? 2
        hasher.combine(backingScale)
        hasher.combine(store.activeSceneKey)
        hasher.combine(store.selectedPlantID)
        // Soil patches change where plant bases sink, so the cached plant
        // bitmap must rebuild when the patch set changes.
        for patch in store.state.soilPatches where patch.screenIndex == screenIndex {
            hasher.combine(patch.id)
            hasher.combine(patch.points.count)
            hasher.combine(patch.soilSeed)
            let patchBounds = patch.boundingBox
            hasher.combine(Int((patchBounds.minX * 10_000).rounded()))
            hasher.combine(Int((patchBounds.minY * 10_000).rounded()))
            hasher.combine(Int((patchBounds.maxX * 10_000).rounded()))
            hasher.combine(Int((patchBounds.maxY * 10_000).rounded()))
        }
        hasher.combine(String(describing: store.state.lightProjection(at: currentDateProvider())))
        hasher.combine(store.state.plantLightOverlay(at: currentDateProvider()).signatureBucket)
        for record in store.customPlantAssets.records {
            hasher.combine(record.id)
        }
        for plant in plants {
            hasher.combine(plant.id)
            hasher.combine(plant.species)
            hasher.combine(Int((plant.position.x * Double(bounds.width) * Double(backingScale)).rounded()))
            hasher.combine(Int((plant.position.y * Double(bounds.height) * Double(backingScale)).rounded()))
            hasher.combine(Int((plant.growth * 2000).rounded()))
            hasher.combine(Int((plant.hydration * 100).rounded()))
            hasher.combine(Int((plant.health * 100).rounded()))
            hasher.combine(Int((plant.bloomProgress * 100).rounded()))
            hasher.combine(Int((plant.scale * 1000).rounded()))
            hasher.combine(plant.swaySeed)
            hasher.combine(plant.customAssetID)
            hasher.combine(plant.isDead)
        }
        return hasher.finalize()
    }

    private struct PlantLayerCachePlan {
        var targetRect: NSRect
        var pixelCount: Int
        var shouldUseCompositeCache: Bool
    }

    private func plantLayerCachePlan(for plants: [Plant], backingScale: CGFloat? = nil) -> PlantLayerCachePlan {
        let target = plantLayerTargetRect(for: plants)
        let scale = backingScale ?? window?.backingScaleFactor ?? 2
        let pixelCount = plantLayerPixelCount(for: target, backingScale: scale)
        return PlantLayerCachePlan(
            targetRect: target,
            pixelCount: pixelCount,
            shouldUseCompositeCache: pixelCount > 0 && pixelCount <= plantLayerCachePixelBudget
        )
    }

    private var plantLayerCachePixelBudget: Int {
        switch store.state.settings.experienceMode {
        case .garden:
            Self.gardenPlantLayerCachePixelBudget
        case .roomStudio:
            Self.roomStudioPlantLayerCachePixelBudget
        case .alienUFO:
            Self.alienPlantLayerCachePixelBudget
        }
    }

    private func plantLayerTargetRect(for plants: [Plant]) -> NSRect {
        var union = NSRect.null
        for plant in plants {
            union = union.union(redrawRect(for: plant))
        }
        return union.intersection(bounds).integral
    }

    private func plantLayerPixelCount(for target: NSRect, backingScale: CGFloat) -> Int {
        guard !target.isNull, !target.isEmpty, target.width > 0, target.height > 0 else {
            return 0
        }

        let scale = max(1, backingScale)
        let pixelsWide = Int((target.width * scale).rounded(.up))
        let pixelsHigh = Int((target.height * scale).rounded(.up))
        guard pixelsWide > 0, pixelsHigh > 0 else {
            return 0
        }
        return pixelsWide * pixelsHigh
    }

    private func rebuildPlantsLayer(plants: [Plant], profile: GardenSceneVisualProfile) {
        plantsLayerImage = nil
        // Size the layer to the plants' union, not the screen — scenes with
        // few plants pay for what they use.
        let plan = plantLayerCachePlan(for: plants)
        guard plan.shouldUseCompositeCache else {
            plantsLayerRect = .zero
            return
        }
        let target = plan.targetRect
        let scale = window?.backingScaleFactor ?? 2
        let pixelsWide = Int((target.width * scale).rounded())
        let pixelsHigh = Int((target.height * scale).rounded())
        guard pixelsWide > 0, pixelsHigh > 0,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelsWide,
                pixelsHigh: pixelsHigh,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ) else {
            return
        }
        rep.size = target.size
        guard let base = NSGraphicsContext(bitmapImageRep: rep) else {
            return
        }

        NSGraphicsContext.saveGraphicsState()
        let flipped = NSGraphicsContext(cgContext: base.cgContext, flipped: true)
        NSGraphicsContext.current = flipped
        // Match this flipped view's coordinate space, offset to the layer's
        // origin, so drawPlant renders exactly as it would on screen.
        flipped.cgContext.translateBy(x: 0, y: target.height)
        flipped.cgContext.scaleBy(x: 1, y: -1)
        flipped.cgContext.translateBy(x: -target.minX, y: -target.minY)
        for plant in plants {
            drawPlant(plant, profile: profile)
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: target.size)
        image.addRepresentation(rep)
        plantsLayerImage = image
        plantsLayerRect = target
    }

    func plantLayerCachePlanForSelfTest(backingScale: CGFloat = 2) -> (pixelCount: Int, shouldUseCompositeCache: Bool)? {
        let plants = store.state.plants
            .filter { $0.screenIndex == screenIndex }
            .filter { canDisplay($0) }
            .sorted { $0.position.y < $1.position.y }
        guard !plants.isEmpty else {
            return nil
        }

        let plan = plantLayerCachePlan(for: plants, backingScale: backingScale)
        return (plan.pixelCount, plan.shouldUseCompositeCache)
    }

    func plantLayerAlphaBoundsForSelfTest(useCachedLayer: Bool, backingScale: CGFloat = 2) -> NSRect? {
        plantLayerBitmapForSelfTest(useCachedLayer: useCachedLayer, backingScale: backingScale)
            .flatMap { Self.alphaBounds(in: $0, backingScale: backingScale) }
    }

    func gnomeZoneGuideVisibleForSelfTest() -> Bool {
        isGnomeZoneDrawingMode || !gnomeZoneDraftPoints.isEmpty
    }

    func birdSkyZoneGuideVisibleForSelfTest() -> Bool {
        isBirdSkyZoneDrawingMode || !birdSkyZoneDraftPoints.isEmpty
    }

    func drawsGardenAtmosphericCanvasEffectsForSelfTest() -> Bool {
        drawsGardenAtmosphericCanvasEffects()
    }

    func plantLayerAverageBrightnessForSelfTest(
        useCachedLayer: Bool,
        date: Date,
        backingScale: CGFloat = 2
    ) -> CGFloat? {
        let previousProvider = currentDateProvider
        currentDateProvider = { date }
        defer { currentDateProvider = previousProvider }

        guard let rep = plantLayerBitmapForSelfTest(
            useCachedLayer: useCachedLayer,
            backingScale: backingScale
        ) else {
            return nil
        }

        return Self.averageBrightness(in: rep)
    }

    private func plantLayerBitmapForSelfTest(useCachedLayer: Bool, backingScale: CGFloat) -> NSBitmapImageRep? {
        let plants = store.state.plants
            .filter { $0.screenIndex == screenIndex }
            .filter { canDisplay($0) }
            .sorted { $0.position.y < $1.position.y }
        guard !plants.isEmpty else {
            return nil
        }

        let pixelsWide = max(1, Int((bounds.width * backingScale).rounded()))
        let pixelsHigh = max(1, Int((bounds.height * backingScale).rounded()))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        rep.size = bounds.size
        guard let base = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        let flipped = NSGraphicsContext(cgContext: base.cgContext, flipped: true)
        NSGraphicsContext.current = flipped
        flipped.cgContext.translateBy(x: 0, y: bounds.height)
        flipped.cgContext.scaleBy(x: 1, y: -1)
        if useCachedLayer {
            rebuildPlantsLayer(plants: plants, profile: sceneVisualProfile())
            if let layer = plantsLayerImage {
                layer.draw(
                    in: plantsLayerRect,
                    from: NSRect(origin: .zero, size: layer.size),
                    operation: .sourceOver,
                    fraction: 1,
                    respectFlipped: true,
                    hints: [.interpolation: NSImageInterpolation.none]
                )
            }
        } else {
            let profile = sceneVisualProfile()
            for plant in plants {
                drawPlant(plant, profile: profile)
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        return rep
    }

    private static func alphaBounds(in rep: NSBitmapImageRep, backingScale: CGFloat) -> NSRect? {
        var minX = rep.pixelsWide
        var minY = rep.pixelsHigh
        var maxX = -1
        var maxY = -1

        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.02 else {
                    continue
                }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        return NSRect(
            x: CGFloat(minX) / backingScale,
            y: CGFloat(minY) / backingScale,
            width: CGFloat(maxX - minX + 1) / backingScale,
            height: CGFloat(maxY - minY + 1) / backingScale
        )
    }

    private static func averageBrightness(in rep: NSBitmapImageRep) -> CGFloat? {
        var brightness: CGFloat = 0
        var pixelCount: CGFloat = 0

        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let color = rep.colorAt(x: x, y: y),
                      color.alphaComponent > 0.08 else {
                    continue
                }
                brightness += (color.redComponent + color.greenComponent + color.blueComponent) / 3
                pixelCount += 1
            }
        }

        guard pixelCount > 0 else {
            return nil
        }

        return brightness / pixelCount
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if plantExplorerContains(point) {
            return self
        }

        if let selectedPlant = store.selectedPlant,
           selectedPlant.screenIndex == screenIndex,
           canDisplay(selectedPlant),
           (inspectorRect(for: selectedPlant).contains(point)
            || selectedPlantResizeSurfaceContains(point, for: selectedPlant)) {
            return self
        }

        if plantID(at: point, hitSlop: 12) != nil {
            return self
        }

        if pendingCustomPlantAssetID(at: point) != nil {
            return self
        }

        if musicButtonContains(point) {
            return self
        }

        if canClearSelectionFromEmptyInteraction(at: point) {
            return self
        }

        return nil
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        for plant in store.state.plants where plant.screenIndex == screenIndex && canDisplay(plant) {
            // Open-hand only over the visible artwork, not the padded hit box.
            let cursorRect = artworkRect(for: plant).intersection(bounds)
            if !cursorRect.isNull, !cursorRect.isEmpty {
                addCursorRect(cursorRect, cursor: .openHand)
            }
        }

        if let selectedPlant = store.selectedPlant,
           selectedPlant.screenIndex == screenIndex,
           canDisplay(selectedPlant) {
            for (_, rect) in resizeHandleRects(for: selectedPlant) {
                addCursorRect(rect.insetBy(dx: -Self.resizeHandleHitOutset, dy: -Self.resizeHandleHitOutset), cursor: .crosshair)
            }

            for (_, rect) in inspectorActionRects(for: selectedPlant) {
                addCursorRect(rect, cursor: .pointingHand)
            }
        }

        for rect in pendingCustomPlantInteractionRects() {
            addCursorRect(rect, cursor: .openHand)
        }

        if let closeRect = plantExplorerCloseRectIfVisible() {
            addCursorRect(closeRect, cursor: .pointingHand)
        }

        for entry in musicButtonInteractionRects() {
            addCursorRect(entry.rect, cursor: .pointingHand)
        }
    }

    func containsInteractiveElement(at point: NSPoint) -> Bool {
        if plantExplorerContains(point) {
            return true
        }

        if draggingPlantID != nil {
            return true
        }

        if pendingCustomAssetDragSession != nil || pendingCustomPlantAssetID(at: point) != nil {
            return true
        }

        if musicButtonDragSession != nil || musicButtonContains(point) {
            return true
        }

        if plantID(at: point, hitSlop: 12) != nil {
            return true
        }

        if let selectedPlant = store.selectedPlant,
           selectedPlant.screenIndex == screenIndex,
           canDisplay(selectedPlant),
           (inspectorRect(for: selectedPlant).contains(point)
            || selectedPlantResizeSurfaceContains(point, for: selectedPlant)) {
            return true
        }

        return false
    }

    func containsCatChatBlockingElement(at point: NSPoint) -> Bool {
        if plantExplorerContains(point) {
            return true
        }

        if pendingCustomAssetDragSession != nil || pendingCustomPlantAssetID(at: point) != nil {
            return true
        }

        if musicButtonDragSession != nil || musicButtonContains(point) {
            return true
        }

        if let selectedPlant = store.selectedPlant,
           selectedPlant.screenIndex == screenIndex,
           canDisplay(selectedPlant),
           (inspectorRect(for: selectedPlant).contains(point)
            || selectedPlantResizeSurfaceContains(point, for: selectedPlant)) {
            return true
        }

        return false
    }

    func shouldReceiveMouseEvents(at point: NSPoint) -> Bool {
        if isGnomeZoneDrawingMode || isBirdSkyZoneDrawingMode || isSoilBrushMode || isGnomePerspectiveAdjustmentMode {
            return true
        }
        return containsInteractiveElement(at: point) || canClearSelectionFromEmptyInteraction(at: point)
    }

    func containsSelectionSurface(at point: NSPoint) -> Bool {
        if plantExplorerContains(point) {
            return true
        }

        if musicButtonContains(point) {
            return true
        }

        if pendingCustomPlantAssetID(at: point) != nil {
            return true
        }

        if plantID(at: point, hitSlop: 12) != nil {
            return true
        }

        if let selectedPlant = store.selectedPlant,
           selectedPlant.screenIndex == screenIndex,
           canDisplay(selectedPlant),
           (inspectorRect(for: selectedPlant).contains(point)
            || selectedPlantResizeSurfaceContains(point, for: selectedPlant)) {
            return true
        }

        return false
    }

    func interactionRegionRects() -> [NSRect] {
        if isGnomeZoneDrawingMode || isBirdSkyZoneDrawingMode || isSoilBrushMode || isGnomePerspectiveAdjustmentMode {
            return [bounds]
        }

        // Region windows hug the visible artwork (plus click slop) instead of
        // the padded hit boxes, so desktop clicks near plants are not
        // intercepted and silently dropped.
        var rects = store.state.plants
            .filter { $0.screenIndex == screenIndex }
            .filter { canDisplay($0) }
            .map { artworkRect(for: $0).insetBy(dx: -14, dy: -14).intersection(bounds) }
            .filter { !$0.isNull && !$0.isEmpty }

        rects.append(contentsOf: musicButtonInteractionRects()
            .map { $0.rect.intersection(bounds) }
            .filter { !$0.isNull && !$0.isEmpty })

        rects.append(contentsOf: pendingCustomPlantInteractionRects()
            .map { $0.intersection(bounds) }
            .filter { !$0.isNull && !$0.isEmpty })

        if let selectedPlant = store.selectedPlant,
           selectedPlant.screenIndex == screenIndex,
           canDisplay(selectedPlant) {
            if let explorerRect = plantExplorerRectIfVisible() {
                rects.append(explorerRect.intersection(bounds))
            }

            rects.append(contentsOf: resizeHandleRects(for: selectedPlant)
                .map { _, rect in
                    rect.insetBy(dx: -Self.resizeHandleHitOutset, dy: -Self.resizeHandleHitOutset).intersection(bounds)
                }
                .filter { !$0.isNull && !$0.isEmpty })

            let inspectorRegion = inspectorRect(for: selectedPlant).intersection(bounds)
            if !inspectorRegion.isNull && !inspectorRegion.isEmpty {
                rects.append(inspectorRegion)
            }
        }

        return rects
    }

    func canDisplay(_ plant: Plant) -> Bool {
        PlantDisplayAssetResolver.hasDisplayableAsset(for: plant, customAssets: store.customPlantAssets)
    }

    func sceneVisualProfile() -> GardenSceneVisualProfile {
        GardenSceneVisualProfile(sceneKey: store.activeSceneKey)
    }

    private func canClearSelectionFromEmptyInteraction(at point: NSPoint) -> Bool {
        store.selectedPlantID != nil && !containsSelectionSurface(at: point)
    }

    @discardableResult
    func clearSelectionIfEmptyInteraction(at point: NSPoint) -> Bool {
        guard canClearSelectionFromEmptyInteraction(at: point) else {
            return false
        }

        pinnedInspectorPlantID = nil
        pinnedInspectorRect = nil
        plantExplorerPlantID = nil
        draggingPlantID = nil
        dragDidMovePlant = false
        resizeSession = nil
        musicButtonDragSession = nil
        pendingCustomAssetDragSession = nil
        store.setSelectedPlant(nil)
        return true
    }

    func inspectorActionHitPointsForSelfTest() -> [NSPoint] {
        guard let selectedPlant = store.selectedPlant,
              selectedPlant.screenIndex == screenIndex else {
            return []
        }

        return inspectorActionRects(for: selectedPlant).map { _, rect in
            NSPoint(x: rect.midX, y: rect.midY)
        }
    }

    func inspectorActionEdgeHitPointsForSelfTest() -> [NSPoint] {
        guard let selectedPlant = store.selectedPlant,
              selectedPlant.screenIndex == screenIndex else {
            return []
        }

        return inspectorActionRects(for: selectedPlant).map { _, rect in
            NSPoint(x: rect.maxX + 5, y: rect.midY)
        }
    }

    func inspectorBodyHitPointForSelfTest() -> NSPoint? {
        guard let selectedPlant = store.selectedPlant,
              selectedPlant.screenIndex == screenIndex else {
            return nil
        }

        let rect = inspectorRect(for: selectedPlant)
        return NSPoint(x: rect.minX + 18, y: rect.minY + 18)
    }

    func resizeHandleHitPointsForSelfTest() -> [NSPoint] {
        guard let selectedPlant = store.selectedPlant,
              selectedPlant.screenIndex == screenIndex else {
            return []
        }

        return resizeHandleRects(for: selectedPlant).map { _, rect in
            NSPoint(x: rect.midX, y: rect.midY)
        }
    }

    func musicButtonHitPointForSelfTest() -> NSPoint? {
        guard let rect = musicButtonRect() else {
            return nil
        }

        return NSPoint(x: rect.midX, y: rect.midY)
    }

    @discardableResult
    func beginGardenInteractionIfPresent(at point: NSPoint, clickCount: Int = 1) -> Bool {
        beginGardenInteraction(at: point, clickCount: clickCount) != .none
    }

    @discardableResult
    func beginGardenInteraction(at point: NSPoint, clickCount: Int = 1) -> GardenCanvasInteractionResult {
        if isSoilBrushMode {
            return beginSoilBrushStroke(at: point) ? .drag : .none
        }
        if isGnomeZoneDrawingMode {
            return beginGnomeZoneDraft(at: point) ? .drag : .none
        }
        if isBirdSkyZoneDrawingMode {
            return beginBirdSkyZoneDraft(at: point) ? .drag : .none
        }

        if plantExplorerContains(point) {
            if plantExplorerCloseRectIfVisible()?.contains(point) == true {
                plantExplorerPlantID = nil
                needsDisplay = true
            }
            return .handled
        }

        if let selectedPlant = store.selectedPlant,
           selectedPlant.screenIndex == screenIndex,
           canDisplay(selectedPlant) {
            if let resizeHandle = resizeHandle(at: point, for: selectedPlant) {
                beginPlantResize(plant: selectedPlant, handle: resizeHandle)
                return .drag
            }

            if let selectedInspectorAction = inspectorAction(at: point, for: selectedPlant) {
                performInspectorAction(selectedInspectorAction)
                return .handled
            }

            if inspectorRect(for: selectedPlant).contains(point) {
                return .handled
            }

            if selectionFrameEdgeContains(point, for: selectedPlant) {
                return .handled
            }
        }

        if musicButtonContains(point) {
            beginMusicButtonInteraction(at: point, clickCount: clickCount)
            return .drag
        }

        if beginPendingCustomPlantAssetDrag(at: point) {
            return .drag
        }

        let hitPlantID = plantID(at: point, hitSlop: 12)
        if GardenInteractionPriority.target(hasInspectorAction: false, hasPlant: hitPlantID != nil) == .plant {
            if let hitPlantID {
                beginPlantInteraction(plantID: hitPlantID, at: point, clickCount: clickCount)
                let hitPlant = store.state.plants.first { $0.id == hitPlantID }
                return clickCount >= 2 || hitPlant?.placementLocked == true ? .handled : .drag
            }
        }

        return .none
    }

    @discardableResult
    func beginGnomeZoneDraft(at point: NSPoint) -> Bool {
        guard bounds.contains(point) else {
            return false
        }

        gnomeZoneDraftPoints = [point]
        needsDisplay = true
        return true
    }

    @discardableResult
    func continueGnomeZoneDraft(at point: NSPoint) -> Bool {
        guard !gnomeZoneDraftPoints.isEmpty else {
            return false
        }

        let clippedPoint = NSPoint(
            x: min(bounds.width, max(0, point.x)),
            y: min(bounds.height, max(0, point.y))
        )
        if let lastPoint = gnomeZoneDraftPoints.last,
           hypot(clippedPoint.x - lastPoint.x, clippedPoint.y - lastPoint.y) < 8 {
            return true
        }

        gnomeZoneDraftPoints.append(clippedPoint)
        setNeedsDisplay(bounds)
        return true
    }

    @discardableResult
    func endGnomeZoneDraft() -> Bool {
        defer {
            gnomeZoneDraftPoints = []
            needsDisplay = true
        }

        guard gnomeZoneDraftPoints.count >= GnomeTribeZone.minimumPointCount else {
            return false
        }

        let points = gnomeZoneDraftPoints.map { point in
            GardenPoint(
                x: Double(point.x / max(1, bounds.width)),
                y: Double(point.y / max(1, bounds.height))
            )
        }
        store.addGnomeTribeZone(screenIndex: screenIndex, points: points)
        return true
    }

    @discardableResult
    func beginBirdSkyZoneDraft(at point: NSPoint) -> Bool {
        guard bounds.contains(point) else {
            return false
        }

        birdSkyZoneDraftPoints = [point]
        needsDisplay = true
        return true
    }

    @discardableResult
    func continueBirdSkyZoneDraft(at point: NSPoint) -> Bool {
        guard !birdSkyZoneDraftPoints.isEmpty else {
            return false
        }

        let clippedPoint = NSPoint(
            x: min(bounds.width, max(0, point.x)),
            y: min(bounds.height, max(0, point.y))
        )
        if let lastPoint = birdSkyZoneDraftPoints.last,
           hypot(clippedPoint.x - lastPoint.x, clippedPoint.y - lastPoint.y) < 8 {
            return true
        }

        birdSkyZoneDraftPoints.append(clippedPoint)
        setNeedsDisplay(bounds)
        return true
    }

    @discardableResult
    func endBirdSkyZoneDraft() -> Bool {
        defer {
            birdSkyZoneDraftPoints = []
            needsDisplay = true
        }

        guard birdSkyZoneDraftPoints.count >= BirdSkyZone.minimumPointCount else {
            return false
        }

        let points = birdSkyZoneDraftPoints.map { point in
            GardenPoint(
                x: Double(point.x / max(1, bounds.width)),
                y: Double(point.y / max(1, bounds.height))
            )
        }
        store.addBirdSkyZone(screenIndex: screenIndex, points: points)
        return true
    }

    @discardableResult
    func beginSoilBrushStroke(at point: NSPoint) -> Bool {
        guard bounds.contains(point) else {
            return false
        }

        soilBrushDraftPoints = [point]
        needsDisplay = true
        return true
    }

    @discardableResult
    func continueSoilBrushStroke(at point: NSPoint) -> Bool {
        guard !soilBrushDraftPoints.isEmpty else {
            return false
        }

        let clippedPoint = NSPoint(
            x: min(bounds.width, max(0, point.x)),
            y: min(bounds.height, max(0, point.y))
        )
        if let lastPoint = soilBrushDraftPoints.last,
           hypot(clippedPoint.x - lastPoint.x, clippedPoint.y - lastPoint.y) < 8 {
            return true
        }

        soilBrushDraftPoints.append(clippedPoint)
        setNeedsDisplay(bounds)
        return true
    }

    @discardableResult
    func endSoilBrushStroke() -> Bool {
        defer {
            soilBrushDraftPoints = []
            needsDisplay = true
        }

        guard soilBrushDraftPoints.count >= SoilPatch.minimumPointCount else {
            return false
        }

        let points = soilBrushDraftPoints.map { point in
            GardenPoint(
                x: Double(point.x / max(1, bounds.width)),
                y: Double(point.y / max(1, bounds.height))
            )
        }
        store.addSoilPatch(screenIndex: screenIndex, points: points)
        return true
    }

    @discardableResult
    func continuePlantDrag(at point: NSPoint) -> Bool {
        if pendingCustomAssetDragSession != nil {
            return continuePendingCustomPlantAssetDrag(at: point)
        }

        if musicButtonDragSession != nil {
            return continueMusicButtonDrag(at: point)
        }

        if resizeSession != nil {
            return continuePlantResize(at: point)
        }

        guard let draggingPlantID else {
            return false
        }

        // A press only becomes a drag after the pointer travels a few points.
        // Without this, every selection click that wiggles by a pixel moves
        // the plant (and marks the scene as hand-arranged).
        if !dragDidMovePlant {
            let travel = hypot(point.x - dragStartPoint.x, point.y - dragStartPoint.y)
            guard travel >= Self.plantDragStartThreshold else {
                return true
            }

            dragDidMovePlant = true
            NSCursor.closedHand.set()
        }

        store.setSelectedPlant(draggingPlantID)
        let adjustedPoint = NSPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y)
        invalidatePlantRegion(plantID: draggingPlantID) {
            store.moveSelectedPlant(
                to: GardenPoint(
                    x: Double(adjustedPoint.x / max(1, bounds.width)),
                    y: Double(adjustedPoint.y / max(1, bounds.height))
                ),
                screenIndex: screenIndex
            )
            repinInspectorToFollowPlant(draggingPlantID)
        }
        return true
    }

    @discardableResult
    func endPlantDrag() -> Bool {
        if pendingCustomAssetDragSession != nil {
            return endPendingCustomPlantAssetDrag()
        }

        if musicButtonDragSession != nil {
            return endMusicButtonInteraction()
        }

        if resizeSession != nil {
            return endPlantResize()
        }

        guard draggingPlantID != nil else {
            return false
        }

        let didMovePlant = dragDidMovePlant
        draggingPlantID = nil
        dragDidMovePlant = false
        if didMovePlant {
            // Only persist when the plant actually moved; plain selection
            // clicks shouldn't rewrite the garden file.
            store.save()
            window?.invalidateCursorRects(for: self)
            // One full repaint after the gesture to settle anything the
            // targeted dirty rects intentionally skipped mid-drag.
            needsDisplay = true
        }
        return true
    }

    override func mouseDown(with event: NSEvent) {
        if mouseDownHandler?(event) == true {
            return
        }

        let point = convert(event.locationInWindow, from: nil)

        if beginGardenInteractionIfPresent(at: point, clickCount: event.clickCount) {
            return
        }

        clearSelectionIfEmptyInteraction(at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        if mouseDraggedHandler?(event) == true {
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        continuePlantDrag(at: point)
    }

    override func mouseUp(with event: NSEvent) {
        if let mouseUpHandler {
            mouseUpHandler(event)
            return
        }

        endPlantDrag()
    }

    func anchorPoint(for plant: Plant) -> NSPoint {
        NSPoint(
            x: CGFloat(plant.position.x) * bounds.width,
            y: CGFloat(plant.position.y) * bounds.height
        )
    }

    func height(for plant: Plant) -> CGFloat {
        let viewportFactor = min(1.05, max(0.72, bounds.height / 900.0))
        let growthFactor = 0.16 + CGFloat(plant.growth) * 0.84
        let depthScale = CGFloat(plant.depthProfile.heightScale)
        let baseHeight = CGFloat(104 * plant.species.matureHeightMultiplier * plant.scale)
        return min(bounds.height * 0.48, max(20, baseHeight * growthFactor * viewportFactor * depthScale))
    }

    func realisticHeight(for plant: Plant, baseHeight: CGFloat) -> CGFloat {
        let multiplier: CGFloat
        let minimumHeight: CGFloat
        let maxScreenFraction: CGFloat

        if isRoomStudioObject(plant) {
            multiplier = 1.82
            minimumHeight = 96
            maxScreenFraction = 0.88
        } else {
            switch plant.species.kind {
            case .tree:
                multiplier = 1.86
                minimumHeight = 160
                maxScreenFraction = 0.62
            case .foliage:
                multiplier = 1.72
                minimumHeight = 118
                maxScreenFraction = 0.34
            case .edible:
                multiplier = 1.78
                minimumHeight = 112
                maxScreenFraction = 0.40
            case .flower:
                multiplier = plant.species == .sunflower ? 2.05 : 1.88
                minimumHeight = plant.species == .sunflower ? 156 : 116
                maxScreenFraction = 0.42
            case .meadow:
                multiplier = 2.52
                minimumHeight = 122
                maxScreenFraction = 0.36
            }
        }

        let depthScale = CGFloat(plant.depthProfile.heightScale)
        let maturityMinimum = minimumHeight * depthScale * (0.42 + CGFloat(plant.growth) * 0.58)
        return min(bounds.height * maxScreenFraction, max(maturityMinimum, baseHeight * multiplier))
    }

    func isRoomStudioObject(_ plant: Plant) -> Bool {
        guard let customAssetID = plant.customAssetID else {
            return false
        }

        return store.customPlantAssets.isRoomObjectAsset(forCustomAssetID: customAssetID)
    }

    func drawLine(from start: NSPoint, to end: NSPoint, color: NSColor, width: CGFloat) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        color.setStroke()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.stroke()
    }

    func drawCurve(
        from: NSPoint,
        control1: NSPoint,
        control2: NSPoint,
        to: NSPoint,
        color: NSColor,
        width: CGFloat
    ) {
        let path = NSBezierPath()
        path.move(to: from)
        path.curve(to: to, controlPoint1: control1, controlPoint2: control2)
        color.setStroke()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.stroke()
    }

    func drawLeaf(center: NSPoint, size: NSSize, angle: CGFloat, fill: NSColor) {
        drawOval(center: center, size: size, angle: angle, fill: fill, stroke: fill.shadow(withLevel: 0.28))
    }

    func drawOval(center: NSPoint, size: NSSize, angle: CGFloat, fill: NSColor, stroke: NSColor?) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: angle * .pi / 180)
        let path = NSBezierPath(ovalIn: NSRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        fill.setFill()
        path.fill()
        if let stroke {
            stroke.setStroke()
            path.lineWidth = 0.65
            path.stroke()
        }
        context.restoreGState()
    }

    func drawCircle(center: NSPoint, radius: CGFloat, fill: NSColor, stroke: NSColor?) {
        // Intentionally disabled: circular renderer marks read as UI artifacts on the desktop garden.
    }

}
