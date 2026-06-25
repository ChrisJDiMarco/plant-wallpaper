import AppKit
import PlantGardenCore
import QuartzCore

/// Records whether the desktop CGEvent tap could be installed. Creation
/// fails when the app lacks Input Monitoring permission; the status menu
/// reads this to tell the operator instead of letting clicks silently
/// degrade to the fallback monitors.
@MainActor
enum GardenDesktopEventTapStatus {
    static var isUnavailable = false
}

private final class GardenOverlayEventRelay: @unchecked Sendable {
    weak var controller: GardenOverlayController?

    init(controller: GardenOverlayController) {
        self.controller = controller
    }

    func dispatch(_ body: @escaping @MainActor (GardenOverlayController) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let controller = self?.controller else {
                return
            }
            MainActor.assumeIsolated {
                body(controller)
            }
        }
    }
}

private final class GardenSceneTransitionView: NSView {
    private let image: NSImage?

    init(frame frameRect: NSRect, image: NSImage?) {
        self.image = image
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let image else {
            return
        }

        image.draw(
            in: bounds,
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }
}

@MainActor
final class GardenOverlayController {
    private let store: GardenStore
    private let musicPlayer: GardenMusicPlaybackControlling
    private var windows: [GardenWindow] = []
    private var sceneTransitionWindows: [GardenWindow] = []
    private var sceneTransitionGeneration = 0

    /// Driven by AppDelegate during AI Lock View: hides every canvas's placed
    /// plants while the generated wallpaper is showing, then restores them.
    var arePlantsHiddenForAILockView = false {
        didSet {
            guard oldValue != arePlantsHiddenForAILockView else { return }
            windows.compactMap { $0.contentView as? GardenCanvasView }.forEach {
                $0.arePlantsHiddenForAILockView = arePlantsHiddenForAILockView
            }
            redrawCanvases()
        }
    }
    private var bugSystems: [GardenBugSystem] = []
    private var interactionWindows: [GardenInteractionRegionWindow] = []
    private var interactionRegionFrames: [NSRect] = []
    private weak var activeDragWindow: GardenWindow?
    private var activeDragPointIndex = 0
    private var globalMouseDownMonitor: Any?
    private var globalMouseDraggedMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var globalMouseMovedMonitor: Any?
    private var pointerRoutingTimer: Timer?
    private var systemCapturePauseTimer: Timer?
    private var notificationObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var mousePressCoordinator = GardenMousePressCoordinator()
    private var lastDragScreenPoint: NSPoint?
    private var lastPointerRoutingScreenPoint: NSPoint?
    private var desktopWindowSnapshotCache: (uptime: TimeInterval, windows: [GardenDesktopWindowSnapshot])?
    private var isPointerPollingDragActive = false
    private var isStatusMenuOpen = false
    private var isDesktopInputPausedForSystemCaptureUI = false
    private var isDispatchingMouseDown = false
    private var isGnomeZoneDrawingMode = false
    private var isBirdSkyZoneDrawingMode = false
    private var isSoilBrushMode = false
    private var isGnomePerspectiveAdjustmentMode = false
    private var gnomePerspectiveDragSession: GnomePerspectiveDragSession?
    private lazy var eventRelay = GardenOverlayEventRelay(controller: self)
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var lastObservedExperienceMode: GardenExperienceMode?
    var desktopPlantingMenuRequestHandler: ((NSPoint) -> Void)?
    var desktopDoubleClickHandler: ((NSPoint) -> Bool)?
    var wallCatClickClaimHandler: ((NSPoint) -> Bool)?
    /// Invoked when the user taps the in-scene "Done" button while adjusting the
    /// gnome perspective, so the host can leave the mode (and update its menu).
    var gnomePerspectiveDoneHandler: (() -> Void)?
    private var lastDesktopPlantingMenuRequest: (uptime: TimeInterval, point: NSPoint)?

    private struct GnomePerspectiveDragSession {
        var startPoint: NSPoint
        var initialPerspective: GnomeTribePerspective
    }

    private var isGardenInteractionLocked: Bool {
        store.state.settings.isGardenInteractionLocked
    }

    init(store: GardenStore, musicPlayer: GardenMusicPlaybackControlling = GardenRadioPlayer.shared) {
        self.store = store
        self.musicPlayer = musicPlayer
        self.lastObservedExperienceMode = store.state.settings.experienceMode
        observeNotification(name: .gardenStoreDidChange, object: store) { controller, _ in
            controller.storeDidChange()
        }
        observeNotification(name: .gardenStatusMenuWillOpen) { controller, _ in
            controller.statusMenuWillOpen()
        }
        observeNotification(name: .gardenStatusMenuDidClose) { controller, _ in
            controller.statusMenuDidClose()
        }
        observeNotification(name: .gardenGnomeZoneDrawingModeDidChange) { controller, notification in
            controller.gnomeZoneDrawingModeDidChange(notification)
        }
        observeNotification(name: .gardenGnomePerspectiveAdjustmentModeDidChange) { controller, notification in
            controller.gnomePerspectiveAdjustmentModeDidChange(notification)
        }
        observeNotification(name: .gardenBirdSkyZoneDrawingModeDidChange) { controller, notification in
            controller.birdSkyZoneDrawingModeDidChange(notification)
        }
        observeNotification(name: .gardenSoilBrushModeDidChange) { controller, notification in
            controller.soilBrushModeDidChange(notification)
        }
        observeNotification(name: .gardenCatCompanionClaimedClick) { controller, notification in
            controller.catCompanionClaimedClick(notification)
        }
        observeNotification(name: .gardenPlantSpotlightVisibilityChanged) { controller, notification in
            controller.plantSpotlightVisibilityChanged(notification)
        }
        observeWorkspaceNotification(name: NSWorkspace.sessionDidResignActiveNotification) { controller, _ in
            controller.desktopInputSessionDidPause()
        }
        observeWorkspaceNotification(name: NSWorkspace.sessionDidBecomeActiveNotification) { controller, _ in
            controller.desktopInputSessionDidResume()
        }
        observeWorkspaceNotification(name: NSWorkspace.screensDidSleepNotification) { controller, _ in
            controller.desktopInputSessionDidPause()
        }
        observeWorkspaceNotification(name: NSWorkspace.screensDidWakeNotification) { controller, _ in
            controller.desktopInputSessionDidResume()
        }
        installEventMonitors()
        installEventTap()
        startPointerRoutingTimer()
        startSystemCapturePauseTimer()
    }

    func shutdown() {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers = []
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers = []
        pointerRoutingTimer?.invalidate()
        pointerRoutingTimer = nil
        systemCapturePauseTimer?.invalidate()
        systemCapturePauseTimer = nil
        if let globalMouseDownMonitor {
            NSEvent.removeMonitor(globalMouseDownMonitor)
            self.globalMouseDownMonitor = nil
        }
        if let globalMouseDraggedMonitor {
            NSEvent.removeMonitor(globalMouseDraggedMonitor)
            self.globalMouseDraggedMonitor = nil
        }
        if let globalMouseUpMonitor {
            NSEvent.removeMonitor(globalMouseUpMonitor)
            self.globalMouseUpMonitor = nil
        }
        if let globalMouseMovedMonitor {
            NSEvent.removeMonitor(globalMouseMovedMonitor)
            self.globalMouseMovedMonitor = nil
        }
        uninstallEventTap()
    }

    private func observeNotification(
        name: Notification.Name,
        object: Any? = nil,
        handler: @escaping @MainActor (GardenOverlayController, Notification) -> Void
    ) {
        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: object,
            queue: .main
        ) { [weak self] notification in
            guard let self else {
                return
            }
            let delivery = MainActorNotificationDelivery(notification: notification)
            MainActor.assumeIsolated {
                handler(self, delivery.notification)
            }
        }
        notificationObservers.append(observer)
    }

    private func observeWorkspaceNotification(
        name: Notification.Name,
        handler: @escaping @MainActor (GardenOverlayController, Notification) -> Void
    ) {
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else {
                return
            }
            let delivery = MainActorNotificationDelivery(notification: notification)
            MainActor.assumeIsolated {
                handler(self, delivery.notification)
            }
        }
        workspaceObservers.append(observer)
    }

    func show() {
        rebuildWindows()
    }

    func performSceneTransition(_ updateScene: @escaping () -> Void) {
        sceneTransitionGeneration += 1
        let generation = sceneTransitionGeneration
        showSceneTransitionCover()
        windows.forEach { $0.alphaValue = 0 }
        updateScene()
        windows.forEach { $0.alphaValue = 0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, generation == self.sceneTransitionGeneration else {
                    return
                }

                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.50
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    self.windows.forEach { $0.animator().alphaValue = 1 }
                    self.sceneTransitionWindows.forEach { $0.animator().alphaValue = 0 }
                } completionHandler: {
                    MainActor.assumeIsolated {
                        guard generation == self.sceneTransitionGeneration else {
                            return
                        }
                        self.closeSceneTransitionCover()
                    }
                }
            }
        }
    }

    func containsForegroundGardenElement(at screenPoint: NSPoint) -> Bool {
        guard !isStatusMenuOpen, !isGardenInteractionLocked else {
            return false
        }

        for window in windows where window.frame.contains(screenPoint) {
            guard let canvasView = window.contentView as? GardenCanvasView else {
                continue
            }

            let candidatePoints = viewPointCandidates(
                for: screenPoint,
                in: window,
                canvasView: canvasView
            )
            if candidatePoints.contains(where: { canvasView.containsInteractiveElement(at: $0) }) {
                return true
            }
        }

        return false
    }

    func containsCatChatBlockingGardenElement(at screenPoint: NSPoint) -> Bool {
        guard !isStatusMenuOpen, !isGardenInteractionLocked else {
            return false
        }

        for window in windows where window.frame.contains(screenPoint) {
            guard let canvasView = window.contentView as? GardenCanvasView else {
                continue
            }

            let candidatePoints = viewPointCandidates(
                for: screenPoint,
                in: window,
                canvasView: canvasView
            )
            if candidatePoints.contains(where: { canvasView.containsCatChatBlockingElement(at: $0) }) {
                return true
            }
        }

        return false
    }

    func canReceiveDesktopSceneClick(at screenPoint: NSPoint) -> Bool {
        canHandleDesktopMouse(at: screenPoint, forceFreshSnapshot: true)
    }

    func rebuildWindows() {
        interactionWindows.forEach { $0.close() }
        interactionWindows = []
        interactionRegionFrames = []
        desktopWindowSnapshotCache = nil
        lastPointerRoutingScreenPoint = nil
        teardownBugSystems()
        windows.forEach { $0.close() }
        windows = NSScreen.screens.enumerated().map { screenIndex, screen in
            let window = GardenWindow(screen: screen)
            let canvasView = GardenCanvasView(
                frame: NSRect(origin: .zero, size: screen.frame.size),
                screenIndex: screenIndex,
                store: store,
                musicPlayer: musicPlayer
            )
            canvasView.isGnomeZoneDrawingMode = isGnomeZoneDrawingMode
            canvasView.isBirdSkyZoneDrawingMode = isBirdSkyZoneDrawingMode
            canvasView.isSoilBrushMode = isSoilBrushMode
            canvasView.isGnomePerspectiveAdjustmentMode = isGnomePerspectiveAdjustmentMode
            canvasView.arePlantsHiddenForAILockView = arePlantsHiddenForAILockView
            canvasView.mouseDownHandler = { [weak self, weak window] event in
                guard let self, let window else {
                    return false
                }

                let screenPoint = window.convertPoint(toScreen: event.locationInWindow)
                return self.handleMouseDown(
                    at: screenPoint,
                    clickCount: event.clickCount,
                    allowsDesktopPlantingMenu: !self.isPointOnGardenInteractionSurface(screenPoint)
                )
            }
            canvasView.mouseDraggedHandler = { [weak self, weak window] event in
                guard let self, let window else {
                    return false
                }

                return self.handleMouseDragged(
                    at: window.convertPoint(toScreen: event.locationInWindow)
                )
            }
            canvasView.mouseUpHandler = { [weak self] _ in
                self?.handleMouseUp()
            }
            window.contentView = canvasView
            window.orderFrontRegardless()
            return window
        }
        syncBugSystems()
        syncPlantSpotlightPresentation()
        updateInteractionRegionWindows()
        updateMouseRouting(at: NSEvent.mouseLocation)
    }

    func refresh() {
        syncBugSystems()
        syncPlantSpotlightPresentation()

        if isGardenInteractionLocked {
            disableMouseRouting()
            redrawCanvases()
            return
        }

        updateInteractionRegionWindows()
        if activeDragWindow == nil {
            updateMouseRouting(at: NSEvent.mouseLocation)
        }

        redrawCanvases()
    }

    func repaint() {
        syncPlantSpotlightPresentation()
        if isGardenInteractionLocked {
            disableMouseRouting()
            redrawCanvases()
            return
        }

        redrawCanvases()
    }

    private func redrawCanvases() {
        // During an active drag the dragged canvas performs targeted
        // dirty-rect invalidation itself. Broadcasting full-screen repaints
        // here on every store change is what made dragging feel jerky.
        guard activeDragWindow == nil else {
            return
        }

        windows.compactMap { $0.contentView as? GardenCanvasView }.forEach { view in
            view.needsDisplay = true
        }
    }

    private func showSceneTransitionCover() {
        closeSceneTransitionCover()
        sceneTransitionWindows = NSScreen.screens.enumerated().map { screenIndex, screen in
            let window = GardenWindow(screen: screen)
            window.level = GardenDesktopWindowLevels.plantSpotlight
            window.alphaValue = 1
            window.contentView = GardenSceneTransitionView(
                frame: NSRect(origin: .zero, size: screen.frame.size),
                image: currentSceneTransitionImage(for: screen, screenIndex: screenIndex)
            )
            window.orderFrontRegardless()
            return window
        }
    }

    private func currentSceneTransitionImage(for screen: NSScreen, screenIndex: Int) -> NSImage? {
        guard let bitmap = try? GardenDesktopSnapshotRenderer.makeSnapshotBitmap(
            store: store,
            screen: screen,
            screenIndex: screenIndex
        ) else {
            return nil
        }

        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return image
    }

    private func closeSceneTransitionCover() {
        sceneTransitionWindows.forEach { $0.close() }
        sceneTransitionWindows = []
    }

    nonisolated static func shouldInstallBugSystems(for state: GardenState) -> Bool {
        state.isEffectiveAmbientWildlifeEnabled
    }

    private func syncBugSystems() {
        guard Self.shouldInstallBugSystems(for: store.state) else {
            teardownBugSystems()
            return
        }

        guard bugSystems.count != windows.count else {
            return
        }

        teardownBugSystems()
        bugSystems = windows.enumerated().compactMap { index, window in
            guard let canvas = window.contentView as? GardenCanvasView else {
                return nil
            }
            return GardenBugSystem(view: canvas, store: store, screenIndex: index)
        }
    }

    private func syncPlantSpotlightPresentation() {
        windows.forEach { window in
            let isVisible = (window.contentView as? GardenCanvasView)?.isPlantExplorerVisibleForSelfTest() == true
            window.setPlantSpotlightVisible(isVisible)
        }
        bugSystems.forEach { $0.syncPresentationState() }
    }

    private func teardownBugSystems() {
        bugSystems.forEach { $0.teardown() }
        bugSystems = []
    }

    private func storeDidChange() {
        let currentMode = store.state.settings.experienceMode
        if let lastObservedExperienceMode,
           lastObservedExperienceMode != currentMode {
            prepareForExperienceModeChange()
        }
        lastObservedExperienceMode = currentMode
        refresh()
    }

    private func plantSpotlightVisibilityChanged(_: Notification) {
        syncPlantSpotlightPresentation()
        if activeDragWindow == nil {
            updateMouseRouting(at: NSEvent.mouseLocation)
        }
    }

    private func prepareForExperienceModeChange() {
        disableMouseRouting()
        clearMusicButtonHover()
        interactionWindows.forEach { $0.close() }
        interactionWindows = []
        interactionRegionFrames = []
        desktopWindowSnapshotCache = nil
        lastDesktopPlantingMenuRequest = nil
        teardownBugSystems()
    }

    private func statusMenuWillOpen() {
        isStatusMenuOpen = true
        handleMouseUp()
        interactionWindows.forEach { $0.close() }
        interactionWindows = []
        interactionRegionFrames = []
        windows.forEach { $0.ignoresMouseEvents = true }
    }

    private func statusMenuDidClose() {
        isStatusMenuOpen = false
        updateInteractionRegionWindows()
        updateMouseRouting(at: NSEvent.mouseLocation)
    }

    private func updateMouseRouting(at mouseLocation: NSPoint) {
        lastPointerRoutingScreenPoint = mouseLocation
        guard !isStatusMenuOpen, !isGardenInteractionLocked else {
            clearMusicButtonHover()
            windows.forEach { $0.ignoresMouseEvents = true }
            return
        }

        guard activeDragWindow == nil else {
            clearMusicButtonHover()
            activeDragWindow?.ignoresMouseEvents = false
            return
        }

        for window in windows {
            guard let canvasView = window.contentView as? GardenCanvasView,
                  window.frame.contains(mouseLocation) else {
                let view = window.contentView as? GardenCanvasView
                view?.clearMusicButtonHover()
                view?.clearPerspectiveHover()
                window.ignoresMouseEvents = true
                continue
            }

            guard canHandleDesktopMouse(at: mouseLocation) else {
                canvasView.clearMusicButtonHover()
                canvasView.clearPerspectiveHover()
                window.ignoresMouseEvents = true
                continue
            }

            let candidatePoints = viewPointCandidates(
                for: mouseLocation,
                in: window,
                canvasView: canvasView
            )
            canvasView.updateMusicButtonHover(at: candidatePoints)
            canvasView.updatePerspectiveHover(at: candidatePoints)

            let shouldReceiveMouse = candidatePoints.contains { viewPoint in
                canvasView.shouldReceiveMouseEvents(at: viewPoint)
            }
            window.ignoresMouseEvents = !shouldReceiveMouse
        }
    }

    private func clearMusicButtonHover() {
        windows.compactMap { $0.contentView as? GardenCanvasView }
            .forEach {
                $0.clearMusicButtonHover()
                $0.clearPerspectiveHover()
            }
    }

    private func gnomeZoneDrawingModeDidChange(_ notification: Notification) {
        let isEnabled = notification.userInfo?["isEnabled"] as? Bool ?? false
        setGnomeZoneDrawingMode(isEnabled)
    }

    private func birdSkyZoneDrawingModeDidChange(_ notification: Notification) {
        let isEnabled = notification.userInfo?["isEnabled"] as? Bool ?? false
        setBirdSkyZoneDrawingMode(isEnabled)
    }

    private func soilBrushModeDidChange(_ notification: Notification) {
        let isEnabled = notification.userInfo?["isEnabled"] as? Bool ?? false
        setSoilBrushMode(isEnabled)
    }

    private func gnomePerspectiveAdjustmentModeDidChange(_ notification: Notification) {
        let isEnabled = notification.userInfo?["isEnabled"] as? Bool ?? false
        setGnomePerspectiveAdjustmentMode(isEnabled)
    }

    private func catCompanionClaimedClick(_ notification: Notification) {
        guard let pointValue = notification.userInfo?["screenPoint"] as? NSValue else {
            return
        }

        let action = notification.userInfo?["action"] as? String
        cancelGardenInteractionBehindCat(
            at: pointValue.pointValue,
            clearsSelection: Self.shouldClearSelectionAfterCatClaim(action: action)
        )
    }

    private static func shouldClearSelectionAfterCatClaim(action _: String?) -> Bool {
        true
    }

    static func shouldClearSelectionAfterCatClaimForTesting(action: String?) -> Bool {
        shouldClearSelectionAfterCatClaim(action: action)
    }

    private func cancelGardenInteractionBehindCat(at screenPoint: NSPoint, clearsSelection: Bool = true) {
        guard !isGardenInteractionLocked else {
            return
        }

        if activeDragWindow != nil || mousePressCoordinator.isPressActive {
            handleMouseUp()
        }

        if clearsSelection, store.selectedPlantID != nil {
            store.setSelectedPlant(nil)
        }

        mousePressCoordinator.markHandled()
        isPointerPollingDragActive = false
        windows.forEach { window in
            if window.frame.contains(screenPoint) {
                window.ignoresMouseEvents = true
            }
        }
        updateInteractionRegionWindows()
        updateMouseRouting(at: screenPoint)
    }

    @discardableResult
    private func claimWallCatClickIfNeeded(at screenPoint: NSPoint) -> Bool {
        guard wallCatClickClaimHandler?(screenPoint) == true else {
            return false
        }

        cancelGardenInteractionBehindCat(
            at: screenPoint,
            clearsSelection: Self.shouldClearSelectionAfterCatClaim(action: "wallJumpDown")
        )
        return true
    }

    private func setGnomeZoneDrawingMode(_ isEnabled: Bool) {
        guard isGnomeZoneDrawingMode != isEnabled else {
            return
        }

        handleMouseUp()
        isGnomeZoneDrawingMode = isEnabled
        windows.compactMap { $0.contentView as? GardenCanvasView }.forEach { view in
            view.isGnomeZoneDrawingMode = isEnabled
        }
        desktopWindowSnapshotCache = nil
        updateInteractionRegionWindows()
        updateMouseRouting(at: NSEvent.mouseLocation)
    }

    private func setBirdSkyZoneDrawingMode(_ isEnabled: Bool) {
        guard isBirdSkyZoneDrawingMode != isEnabled else {
            return
        }

        handleMouseUp()
        isBirdSkyZoneDrawingMode = isEnabled
        windows.compactMap { $0.contentView as? GardenCanvasView }.forEach { view in
            view.isBirdSkyZoneDrawingMode = isEnabled
        }
        desktopWindowSnapshotCache = nil
        updateInteractionRegionWindows()
        updateMouseRouting(at: NSEvent.mouseLocation)
    }

    private func setSoilBrushMode(_ isEnabled: Bool) {
        guard isSoilBrushMode != isEnabled else {
            return
        }

        handleMouseUp()
        isSoilBrushMode = isEnabled
        windows.compactMap { $0.contentView as? GardenCanvasView }.forEach { view in
            view.isSoilBrushMode = isEnabled
        }
        desktopWindowSnapshotCache = nil
        if isEnabled {
            NSCursor.crosshair.set()
        } else {
            NSCursor.arrow.set()
        }
        updateInteractionRegionWindows()
        updateMouseRouting(at: NSEvent.mouseLocation)
    }

    private func setGnomePerspectiveAdjustmentMode(_ isEnabled: Bool) {
        guard isGnomePerspectiveAdjustmentMode != isEnabled else {
            return
        }

        handleMouseUp()
        isGnomePerspectiveAdjustmentMode = isEnabled
        gnomePerspectiveDragSession = nil
        windows.compactMap { $0.contentView as? GardenCanvasView }.forEach { view in
            view.isGnomePerspectiveAdjustmentMode = isEnabled
        }
        desktopWindowSnapshotCache = nil
        updateInteractionRegionWindows()
        updateMouseRouting(at: NSEvent.mouseLocation)
    }

    private func installEventMonitors() {
        let relay = eventRelay
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { event in
            let clickCount = event.clickCount
            relay.dispatch { controller in
                let screenPoint = NSEvent.mouseLocation
                guard !controller.isPointInsideInteractionWindow(screenPoint),
                      !controller.isPointOnGardenInteractionSurface(screenPoint) else {
                    return
                }
                if controller.handleDesktopDoubleClickIfNeeded(at: screenPoint, clickCount: clickCount) {
                    return
                }
                guard controller.canHandleDesktopMouse(at: screenPoint, forceFreshSnapshot: true) else {
                    return
                }

                if controller.claimWallCatClickIfNeeded(at: screenPoint) {
                    return
                }

                if controller.openDesktopPlantingMenuIfNeeded(at: screenPoint, clickCount: clickCount) {
                    return
                }

                if controller.canClearSelectionFromMouseDown(at: screenPoint),
                   controller.clearSelectionIfEmptyScreenPoint(at: screenPoint) {
                    return
                }

                controller.handleMouseDown(at: screenPoint, clickCount: clickCount)
            }
        }

        globalMouseDraggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { _ in
            relay.dispatch { controller in
                let screenPoint = NSEvent.mouseLocation
                guard controller.canHandleDesktopDrag(at: screenPoint, forceFreshSnapshot: true) else {
                    return
                }

                controller.handleMouseDragged(at: screenPoint)
            }
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { _ in
            relay.dispatch { controller in
                controller.handleMouseUp()
            }
        }

        globalMouseMovedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { _ in
            relay.dispatch { controller in
                controller.updateMouseRouting(at: NSEvent.mouseLocation)
            }
        }
    }

    private func installEventTap() {
        uninstallEventTap()
        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseDragged.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.mouseMoved.rawValue)

        let relay = eventRelay
        let userInfo = Unmanaged.passUnretained(relay).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }

                let relay = Unmanaged<GardenOverlayEventRelay>
                    .fromOpaque(userInfo)
                    .takeUnretainedValue()
                let quartzLocation = event.location
                let clickCount = Int(event.getIntegerValueField(.mouseEventClickState))
                relay.dispatch { controller in
                    controller.handleEventTap(
                        type: type,
                        quartzLocation: quartzLocation,
                        clickCount: max(1, clickCount)
                    )
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            NSLog("Plant Wallpaper could not install desktop mouse event tap")
            GardenDesktopEventTapStatus.isUnavailable = true
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTapRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func uninstallEventTap() {
        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
            self.eventTapRunLoopSource = nil
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    private func desktopInputSessionDidPause() {
        handleMouseUp()
        uninstallEventTap()
        isPointerPollingDragActive = false
        isStatusMenuOpen = false
        desktopWindowSnapshotCache = nil
        lastPointerRoutingScreenPoint = nil
        lastDesktopPlantingMenuRequest = nil
        interactionWindows.forEach { $0.close() }
        interactionWindows = []
        interactionRegionFrames = []
        windows.forEach { $0.ignoresMouseEvents = true }
    }

    private func desktopInputSessionDidResume() {
        guard !isDesktopInputPausedForSystemCaptureUI else {
            return
        }

        installEventTap()
        isStatusMenuOpen = false
        desktopWindowSnapshotCache = nil
        lastPointerRoutingScreenPoint = nil
        lastDesktopPlantingMenuRequest = nil
        interactionWindows.forEach { $0.close() }
        interactionWindows = []
        interactionRegionFrames = []
        updateInteractionRegionWindows()
        updateMouseRouting(at: NSEvent.mouseLocation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.desktopWindowSnapshotCache = nil
                self.updateInteractionRegionWindows()
                self.updateMouseRouting(at: NSEvent.mouseLocation)
            }
        }
    }

    private static func isSystemCaptureUIActive() -> Bool {
        let applications = NSWorkspace.shared.runningApplications
        return isSystemCaptureUIActiveForSelfTest(
            processNames: applications.compactMap(\.localizedName),
            bundleIdentifiers: applications.compactMap(\.bundleIdentifier)
        )
    }

    nonisolated static func isSystemCaptureUIActiveForSelfTest(
        processNames: [String],
        bundleIdentifiers: [String]
    ) -> Bool {
        (processNames + bundleIdentifiers).contains { value in
            let normalized = value.lowercased()
            return normalized == "screenshot"
                || normalized == "screencaptureui"
                || normalized.contains("screen capture")
                || normalized.contains("screenshot")
                || normalized.contains("screencapture")
        }
    }

    private func handleEventTap(type: CGEventType, quartzLocation: CGPoint, clickCount: Int) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return
        }

        let screenPoint = appKitScreenPoint(fromQuartzLocation: quartzLocation)
        switch type {
        case .mouseMoved:
            updateMouseRouting(at: screenPoint)
        case .leftMouseDown:
            guard !isPointInsideInteractionWindow(screenPoint),
                  !isPointOnGardenInteractionSurface(screenPoint) else {
                return
            }
            if handleDesktopDoubleClickIfNeeded(at: screenPoint, clickCount: clickCount) {
                return
            }
            guard canHandleDesktopMouse(
                at: screenPoint,
                quartzLocation: quartzLocation,
                forceFreshSnapshot: true
            ) else {
                return
            }

            if claimWallCatClickIfNeeded(at: screenPoint) {
                return
            }

            if openDesktopPlantingMenuIfNeeded(at: screenPoint, clickCount: clickCount) {
                return
            }

            if canClearSelectionFromMouseDown(at: screenPoint),
               clearSelectionIfEmptyScreenPoint(at: screenPoint) {
                return
            }

            _ = handleMouseDown(at: screenPoint, clickCount: clickCount)
        case .leftMouseDragged:
            guard canHandleDesktopDrag(
                at: screenPoint,
                quartzLocation: quartzLocation,
                forceFreshSnapshot: true
            ) else {
                return
            }
            _ = handleMouseDragged(at: screenPoint)
        case .leftMouseUp:
            handleMouseUp()
        default:
            return
        }
    }

    private func isPointInsideInteractionWindow(_ screenPoint: NSPoint) -> Bool {
        interactionWindows.contains { $0.frame.contains(screenPoint) }
    }

    private func isPointOnGardenInteractionSurface(_ screenPoint: NSPoint) -> Bool {
        for window in windows where window.frame.contains(screenPoint) {
            guard let canvasView = window.contentView as? GardenCanvasView else {
                continue
            }

            if viewPointCandidates(for: screenPoint, in: window, canvasView: canvasView)
                .contains(where: { canvasView.containsSelectionSurface(at: $0) }) {
                return true
            }
        }

        return false
    }

    private func startPointerRoutingTimer() {
        pointerRoutingTimer?.invalidate()
        pointerRoutingTimer = Timer.scheduledTimer(
            withTimeInterval: GardenPointerRoutingCadence.refreshInterval,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pointerRoutingTimerFired()
            }
        }
        pointerRoutingTimer?.tolerance = GardenPointerRoutingCadence.refreshInterval * 0.35
    }

    private func startSystemCapturePauseTimer() {
        systemCapturePauseTimer?.invalidate()
        systemCapturePauseTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.systemCapturePauseTimerFired()
            }
        }
        systemCapturePauseTimer?.tolerance = 0.1
    }

    private func systemCapturePauseTimerFired() {
        let isCaptureUIActive = Self.isSystemCaptureUIActive()
        guard isCaptureUIActive != isDesktopInputPausedForSystemCaptureUI else {
            return
        }

        isDesktopInputPausedForSystemCaptureUI = isCaptureUIActive
        if isCaptureUIActive {
            desktopInputSessionDidPause()
        } else {
            desktopInputSessionDidResume()
        }
    }

    private func updateInteractionRegionWindows() {
        guard !isGardenInteractionLocked else {
            interactionWindows.forEach { $0.close() }
            interactionWindows = []
            interactionRegionFrames = []
            return
        }

        guard activeDragWindow == nil, !isStatusMenuOpen, !isDispatchingMouseDown else {
            return
        }

        let proposedFrames = GardenInteractionRegionWindowPlan.optimizedDisplayableFrames(from: windows.flatMap { window -> [NSRect] in
            guard let canvasView = window.contentView as? GardenCanvasView else {
                return []
            }

            return canvasView.interactionRegionRects().map { viewRect in
                let windowRect = canvasView.convert(viewRect, to: nil)
                return window.convertToScreen(windowRect)
                    .insetBy(dx: -3, dy: -3)
                    .integral
            }
        }, maximumFrameCount: maximumInteractionRegionWindowCount())

        guard GardenInteractionRegionWindowPlan.shouldRebuild(
            currentFrames: interactionRegionFrames,
            proposedFrames: proposedFrames,
            existingWindowCount: interactionWindows.count
        ) else {
            return
        }

        interactionWindows.forEach { $0.close() }
        interactionWindows = proposedFrames
            .map { frame in
                let window = GardenInteractionRegionWindow(
                    frame: frame,
                    mouseDownHandler: { [weak self] event, regionWindow in
                        guard let self else {
                            return
                        }

                        let screenPoint = regionWindow.convertPoint(toScreen: event.locationInWindow)
                        _ = self.handleMouseDown(
                            at: screenPoint,
                            clickCount: event.clickCount,
                            allowsDesktopPlantingMenu: !self.isPointOnGardenInteractionSurface(screenPoint)
                        )
                    },
                    mouseDraggedHandler: { [weak self] event, regionWindow in
                        guard let self else {
                            return
                        }

                        _ = self.handleMouseDragged(
                            at: regionWindow.convertPoint(toScreen: event.locationInWindow)
                        )
                    },
                    mouseUpHandler: { [weak self] _, _ in
                        self?.handleMouseUp()
                    }
                )
                window.orderFrontRegardless()
                return window
            }
        interactionRegionFrames = proposedFrames
    }

    private func maximumInteractionRegionWindowCount() -> Int {
        switch store.state.settings.experienceMode {
        case .garden:
            72
        case .roomStudio:
            36
        case .alienUFO:
            40
        }
    }

    private func pointerRoutingTimerFired() {
        let screenPoint = NSEvent.mouseLocation
        let isLeftMouseDown = CGEventSource.buttonState(.hidSystemState, button: .left)
        if GardenPointerRoutingCadence.shouldUpdateMouseRouting(
            previousX: lastPointerRoutingScreenPoint.map { Double($0.x) },
            previousY: lastPointerRoutingScreenPoint.map { Double($0.y) },
            currentX: Double(screenPoint.x),
            currentY: Double(screenPoint.y),
            isMouseButtonDown: isLeftMouseDown,
            hasActiveDrag: activeDragWindow != nil,
            hasActivePress: mousePressCoordinator.isPressActive,
            isPollingDragActive: isPointerPollingDragActive
        ) {
            updateMouseRouting(at: screenPoint)
        }
        pollMouseButtonForDesktopDrag(at: screenPoint, isLeftMouseDown: isLeftMouseDown)
    }

    private func pollMouseButtonForDesktopDrag(at screenPoint: NSPoint, isLeftMouseDown: Bool) {
        if isGardenInteractionLocked || isStatusMenuOpen || isMenuBarArea(screenPoint: screenPoint) {
            if activeDragWindow != nil || isPointerPollingDragActive || mousePressCoordinator.isPressActive {
                handleMouseUp()
            }
            isPointerPollingDragActive = false
            return
        }

        if isLeftMouseDown {
            if activeDragWindow != nil {
                _ = handleMouseDragged(at: screenPoint)
            } else if mousePressCoordinator.isPressActive {
                return
            } else if canHandleDesktopMouse(at: screenPoint) {
                let didBegin = handleMouseDown(at: screenPoint, clickCount: 1)
                if didBegin {
                    isPointerPollingDragActive = true
                }
            }
            return
        }

        if isPointerPollingDragActive || activeDragWindow != nil || mousePressCoordinator.isPressActive {
            handleMouseUp()
        }
        isPointerPollingDragActive = false
    }

    /// Quartz global coordinates have their origin at the top-left of the
    /// PRIMARY display; AppKit's origin is the primary display's bottom-left.
    /// The flip axis is therefore the primary screen's maxY - using the
    /// maximum across all screens shifted every converted point on
    /// multi-display setups, which is what originally forced hit testing to
    /// probe mirrored fallback coordinates.
    private var primaryScreenMaxY: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? NSScreen.main?.frame.maxY ?? 0
    }

    private func appKitScreenPoint(fromQuartzLocation quartzLocation: CGPoint) -> NSPoint {
        NSPoint(x: quartzLocation.x, y: primaryScreenMaxY - quartzLocation.y)
    }

    private func quartzLocation(fromAppKitScreenPoint screenPoint: NSPoint) -> CGPoint {
        CGPoint(x: screenPoint.x, y: primaryScreenMaxY - screenPoint.y)
    }

    private func isDesktopInteractionVisible(
        at quartzLocation: CGPoint,
        forceFreshSnapshot: Bool = false
    ) -> Bool {
        GardenDesktopInteractionOcclusion.allowsGardenInteraction(
            atX: Double(quartzLocation.x),
            y: Double(quartzLocation.y),
            windows: desktopWindowSnapshots(forceRefresh: forceFreshSnapshot)
        )
    }

    private func isMenuBarArea(screenPoint: NSPoint) -> Bool {
        for screen in NSScreen.screens where screen.frame.contains(screenPoint) {
            return GardenDesktopHeaderExclusion.isMenuBarArea(
                pointY: Double(screenPoint.y),
                screenMaxY: Double(screen.frame.maxY),
                visibleFrameMaxY: Double(screen.visibleFrame.maxY)
            )
        }

        return false
    }

    private func canHandleDesktopMouse(
        at screenPoint: NSPoint,
        forceFreshSnapshot: Bool = false
    ) -> Bool {
        canHandleDesktopMouse(
            at: screenPoint,
            quartzLocation: quartzLocation(fromAppKitScreenPoint: screenPoint),
            forceFreshSnapshot: forceFreshSnapshot
        )
    }

    private func canClearSelectionFromMouseDown(at screenPoint: NSPoint) -> Bool {
        GardenDesktopInteractionGate.allowsDesktopSelectionClearing(
            isStatusMenuOpen: isStatusMenuOpen,
            isMenuBarArea: isMenuBarArea(screenPoint: screenPoint),
            isDesktopVisible: isDesktopInteractionVisible(
                at: quartzLocation(fromAppKitScreenPoint: screenPoint),
                forceFreshSnapshot: true
            ),
            isGardenInteractionLocked: isGardenInteractionLocked
        )
    }

    private func canHandleDesktopMouse(
        at screenPoint: NSPoint,
        quartzLocation: CGPoint,
        forceFreshSnapshot: Bool = false
    ) -> Bool {
        GardenDesktopInteractionGate.allowsDesktopMouseHandling(
            isStatusMenuOpen: isStatusMenuOpen,
            isMenuBarArea: isMenuBarArea(screenPoint: screenPoint),
            isDesktopVisible: isDesktopInteractionVisible(at: quartzLocation, forceFreshSnapshot: forceFreshSnapshot),
            isGardenInteractionLocked: isGardenInteractionLocked
        )
    }

    private func canHandleDesktopDrag(
        at screenPoint: NSPoint,
        forceFreshSnapshot: Bool = false
    ) -> Bool {
        canHandleDesktopDrag(
            at: screenPoint,
            quartzLocation: quartzLocation(fromAppKitScreenPoint: screenPoint),
            forceFreshSnapshot: forceFreshSnapshot
        )
    }

    private func canHandleDesktopDrag(
        at screenPoint: NSPoint,
        quartzLocation: CGPoint,
        forceFreshSnapshot: Bool = false
    ) -> Bool {
        GardenDesktopInteractionGate.allowsDesktopDragHandling(
            isStatusMenuOpen: isStatusMenuOpen,
            isMenuBarArea: isMenuBarArea(screenPoint: screenPoint),
            hasActiveDrag: activeDragWindow != nil,
            isDesktopVisible: isDesktopInteractionVisible(
                at: quartzLocation,
                forceFreshSnapshot: forceFreshSnapshot && activeDragWindow == nil
            ),
            isGardenInteractionLocked: isGardenInteractionLocked
        )
    }

    private func desktopWindowSnapshots(forceRefresh: Bool = false) -> [GardenDesktopWindowSnapshot] {
        let now = ProcessInfo.processInfo.systemUptime
        if !forceRefresh,
           let desktopWindowSnapshotCache,
           !GardenDesktopOcclusionSnapshotCadence.shouldRefresh(
                lastRefreshUptime: desktopWindowSnapshotCache.uptime,
                now: now
           ) {
            return desktopWindowSnapshotCache.windows
        }

        guard let windowInfo = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let snapshots: [GardenDesktopWindowSnapshot] = windowInfo.compactMap { info in
            guard let boundsDictionary = info[kCGWindowBounds as String] as? [String: Any],
                  let x = numericValue(boundsDictionary["X"]),
                  let y = numericValue(boundsDictionary["Y"]),
                  let width = numericValue(boundsDictionary["Width"]),
                  let height = numericValue(boundsDictionary["Height"]) else {
                return nil
            }

            return GardenDesktopWindowSnapshot(
                ownerName: info[kCGWindowOwnerName as String] as? String ?? "",
                windowName: info[kCGWindowName as String] as? String ?? "",
                layer: Int(numericValue(info[kCGWindowLayer as String]) ?? 0),
                alpha: numericValue(info[kCGWindowAlpha as String]) ?? 1,
                bounds: GardenDesktopWindowBounds(
                    x: x,
                    y: y,
                    width: width,
                    height: height
                )
            )
        }
        desktopWindowSnapshotCache = (now, snapshots)
        return snapshots
    }

    private func numericValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as String:
            return Double(value)
        default:
            return nil
        }
    }

    @discardableResult
    private func handleMouseDown(
        at screenPoint: NSPoint,
        clickCount: Int,
        allowsDoubleClickWatering: Bool = true,
        allowsDesktopPlantingMenu: Bool = true
    ) -> Bool {
        guard !isGardenInteractionLocked else {
            return false
        }

        if isGnomePerspectiveAdjustmentMode {
            return beginGnomePerspectiveAdjustment(at: screenPoint)
        }

        if isSoilBrushMode {
            return beginSoilBrushStroke(at: screenPoint)
        }
        if isGnomeZoneDrawingMode {
            return beginGnomeZoneDraft(at: screenPoint)
        }
        if isBirdSkyZoneDrawingMode {
            return beginBirdSkyZoneDraft(at: screenPoint)
        }

        if claimWallCatClickIfNeeded(at: screenPoint) {
            return true
        }

        if allowsDesktopPlantingMenu,
           openDesktopPlantingMenuIfNeeded(
               at: screenPoint,
               clickCount: clickCount,
               allowsInteractionWindowOrigin: true
           ) {
            return true
        }

        if mousePressCoordinator.shouldSuppressMouseDown() {
            return true
        }

        isDispatchingMouseDown = true
        defer {
            isDispatchingMouseDown = false
            updateInteractionRegionWindows()
        }

        for window in windows where window.frame.contains(screenPoint) {
            guard let canvasView = window.contentView as? GardenCanvasView else {
                continue
            }

            let selectionClickCount = allowsDoubleClickWatering ? clickCount : 1
            for (pointIndex, viewPoint) in viewPointCandidates(for: screenPoint, in: window, canvasView: canvasView).enumerated() {
                let result = canvasView.beginGardenInteraction(at: viewPoint, clickCount: selectionClickCount)
                switch result {
                case .drag:
                    mousePressCoordinator.markHandled()
                    activeDragWindow = window
                    activeDragPointIndex = pointIndex
                    window.ignoresMouseEvents = false
                    return true
                case .handled:
                    mousePressCoordinator.markHandled()
                    window.ignoresMouseEvents = false
                    return true
                case .none:
                    continue
                }
            }

            for viewPoint in viewPointCandidates(for: screenPoint, in: window, canvasView: canvasView) {
                if canvasView.clearSelectionIfEmptyInteraction(at: viewPoint) {
                    updateMouseRouting(at: screenPoint)
                    mousePressCoordinator.markHandled()
                    window.ignoresMouseEvents = false
                    return true
                }
            }
        }
        return false
    }

    @discardableResult
    private func openDesktopPlantingMenuIfNeeded(
        at screenPoint: NSPoint,
        clickCount: Int,
        allowsInteractionWindowOrigin: Bool = false
    ) -> Bool {
        guard clickCount >= 2,
              !isGardenInteractionLocked,
              !isGnomeZoneDrawingMode,
              !isBirdSkyZoneDrawingMode,
              !isSoilBrushMode,
              !isStatusMenuOpen,
              (allowsInteractionWindowOrigin || !isPointInsideInteractionWindow(screenPoint)),
              !isPointOnGardenInteractionSurface(screenPoint),
              Self.canOpenPlantingMenu(at: screenPoint) else {
            return false
        }

        guard let desktopPlantingMenuRequestHandler else {
            return false
        }

        let uptime = ProcessInfo.processInfo.systemUptime
        if let lastDesktopPlantingMenuRequest,
           uptime - lastDesktopPlantingMenuRequest.uptime < 0.45,
           hypot(
               screenPoint.x - lastDesktopPlantingMenuRequest.point.x,
               screenPoint.y - lastDesktopPlantingMenuRequest.point.y
           ) < 8 {
            return true
        }

        lastDesktopPlantingMenuRequest = (uptime, screenPoint)
        handleMouseUp()
        mousePressCoordinator.markHandled()
        windows.forEach { $0.ignoresMouseEvents = true }
        desktopPlantingMenuRequestHandler(screenPoint)
        return true
    }

    @discardableResult
    private func handleDesktopDoubleClickIfNeeded(at screenPoint: NSPoint, clickCount: Int) -> Bool {
        guard clickCount >= 2,
              !isGardenInteractionLocked,
              !isGnomeZoneDrawingMode,
              !isBirdSkyZoneDrawingMode,
              !isSoilBrushMode,
              !isStatusMenuOpen,
              !isPointInsideInteractionWindow(screenPoint),
              !isPointOnGardenInteractionSurface(screenPoint),
              Self.canOpenPlantingMenu(at: screenPoint),
              let desktopDoubleClickHandler else {
            return false
        }

        let uptime = ProcessInfo.processInfo.systemUptime
        if let lastDesktopPlantingMenuRequest,
           uptime - lastDesktopPlantingMenuRequest.uptime < 0.45,
           hypot(
               screenPoint.x - lastDesktopPlantingMenuRequest.point.x,
               screenPoint.y - lastDesktopPlantingMenuRequest.point.y
           ) < 8 {
            return true
        }

        guard desktopDoubleClickHandler(screenPoint) else {
            return false
        }
        lastDesktopPlantingMenuRequest = (uptime, screenPoint)
        handleMouseUp()
        mousePressCoordinator.markHandled()
        return true
    }

    private static func canOpenPlantingMenu(at screenPoint: NSPoint) -> Bool {
        NSScreen.screens.contains { screen in
            screen.frame.contains(screenPoint)
                && screenPoint.y < screen.frame.maxY - 44
        }
    }

    @discardableResult
    private func beginGnomeZoneDraft(at screenPoint: NSPoint) -> Bool {
        isDispatchingMouseDown = true
        defer {
            isDispatchingMouseDown = false
            updateInteractionRegionWindows()
        }

        for window in windows where window.frame.contains(screenPoint) {
            guard let canvasView = window.contentView as? GardenCanvasView else {
                continue
            }

            let point = viewPointCandidates(for: screenPoint, in: window, canvasView: canvasView)[0]
            guard canvasView.beginGnomeZoneDraft(at: point) else {
                continue
            }

            mousePressCoordinator.markHandled()
            activeDragWindow = window
            activeDragPointIndex = 0
            window.ignoresMouseEvents = false
            return true
        }

        return false
    }

    @discardableResult
    private func beginBirdSkyZoneDraft(at screenPoint: NSPoint) -> Bool {
        isDispatchingMouseDown = true
        defer {
            isDispatchingMouseDown = false
            updateInteractionRegionWindows()
        }

        for window in windows where window.frame.contains(screenPoint) {
            guard let canvasView = window.contentView as? GardenCanvasView else {
                continue
            }

            let point = viewPointCandidates(for: screenPoint, in: window, canvasView: canvasView)[0]
            guard canvasView.beginBirdSkyZoneDraft(at: point) else {
                continue
            }

            mousePressCoordinator.markHandled()
            activeDragWindow = window
            activeDragPointIndex = 0
            window.ignoresMouseEvents = false
            return true
        }

        return false
    }

    @discardableResult
    private func beginSoilBrushStroke(at screenPoint: NSPoint) -> Bool {
        isDispatchingMouseDown = true
        defer {
            isDispatchingMouseDown = false
            updateInteractionRegionWindows()
        }

        for window in windows where window.frame.contains(screenPoint) {
            guard let canvasView = window.contentView as? GardenCanvasView else {
                continue
            }

            let point = viewPointCandidates(for: screenPoint, in: window, canvasView: canvasView)[0]
            guard canvasView.beginSoilBrushStroke(at: point) else {
                continue
            }

            mousePressCoordinator.markHandled()
            activeDragWindow = window
            activeDragPointIndex = 0
            window.ignoresMouseEvents = false
            return true
        }

        return false
    }

    @discardableResult
    private func beginGnomePerspectiveAdjustment(at screenPoint: NSPoint) -> Bool {
        guard !store.state.gnomeTribeZones.isEmpty,
              windows.contains(where: { $0.frame.contains(screenPoint) }) else {
            return false
        }

        // Tapping the floating "Done" button leaves the mode without reopening
        // the menu. Check it before starting a perspective drag.
        for window in windows where window.frame.contains(screenPoint) {
            guard let canvasView = window.contentView as? GardenCanvasView else { continue }
            let viewPoint = canvasView.convert(window.convertPoint(fromScreen: screenPoint), from: nil)
            if canvasView.gnomePerspectiveDoneButtonContains(viewPoint) {
                mousePressCoordinator.markHandled()
                gnomePerspectiveDoneHandler?()
                return true
            }
        }

        gnomePerspectiveDragSession = GnomePerspectiveDragSession(
            startPoint: screenPoint,
            initialPerspective: store.state.gnomeTribePerspective
        )
        mousePressCoordinator.markHandled()
        windows.forEach { window in
            if window.frame.contains(screenPoint) {
                window.ignoresMouseEvents = false
            }
        }
        updateInteractionRegionWindows()
        return true
    }

    @discardableResult
    private func updateGnomePerspectiveAdjustment(
        at screenPoint: NSPoint,
        shouldSave: Bool
    ) -> Bool {
        guard let gnomePerspectiveDragSession else {
            return false
        }

        let adjustedPerspective = gnomePerspectiveDragSession.initialPerspective.adjustedByDrag(
            deltaX: Double(screenPoint.x - gnomePerspectiveDragSession.startPoint.x),
            deltaY: Double(screenPoint.y - gnomePerspectiveDragSession.startPoint.y)
        )
        store.setGnomeTribePerspective(adjustedPerspective, shouldSave: shouldSave)
        mousePressCoordinator.markHandled()
        return true
    }

    @discardableResult
    private func clearSelectionIfEmptyScreenPoint(at screenPoint: NSPoint) -> Bool {
        guard !isGardenInteractionLocked else {
            return false
        }

        guard store.selectedPlantID != nil else {
            return false
        }

        for window in windows where window.frame.contains(screenPoint) {
            guard let canvasView = window.contentView as? GardenCanvasView else {
                continue
            }

            let candidatePoints = viewPointCandidates(for: screenPoint, in: window, canvasView: canvasView)
            let candidateContainsSelectionSurface = candidatePoints.map { viewPoint in
                canvasView.containsSelectionSurface(at: viewPoint)
            }
            guard GardenInteractionPriority.shouldClearSelection(
                hasSelectedPlant: store.selectedPlantID != nil,
                candidateContainsSelectionSurface: candidateContainsSelectionSurface
            ) else {
                continue
            }

            guard let emptyPoint = candidatePoints.first(where: { canvasView.clearSelectionIfEmptyInteraction(at: $0) }) else {
                continue
            }

            _ = emptyPoint
            mousePressCoordinator.markHandled()
            window.ignoresMouseEvents = false
            updateMouseRouting(at: screenPoint)
            return true
        }

        return false
    }

    @discardableResult
    private func handleMouseDragged(at screenPoint: NSPoint) -> Bool {
        guard !isGardenInteractionLocked else {
            return false
        }

        if isGnomePerspectiveAdjustmentMode, gnomePerspectiveDragSession != nil {
            if let lastDragScreenPoint, lastDragScreenPoint == screenPoint {
                return true
            }
            lastDragScreenPoint = screenPoint
            return updateGnomePerspectiveAdjustment(at: screenPoint, shouldSave: false)
        }

        guard let activeDragWindow,
              let canvasView = activeDragWindow.contentView as? GardenCanvasView else {
            return false
        }

        // The same physical drag event arrives via the global monitor, the
        // event tap, and the polling timer. Process each pointer position once.
        if let lastDragScreenPoint, lastDragScreenPoint == screenPoint {
            return true
        }
        lastDragScreenPoint = screenPoint

        let candidates = viewPointCandidates(for: screenPoint, in: activeDragWindow, canvasView: canvasView)
        let viewPoint = candidates.indices.contains(activeDragPointIndex)
            ? candidates[activeDragPointIndex]
            : candidates[0]
        activeDragWindow.ignoresMouseEvents = false
        if isSoilBrushMode {
            return canvasView.continueSoilBrushStroke(at: viewPoint)
        }
        if isGnomeZoneDrawingMode {
            return canvasView.continueGnomeZoneDraft(at: viewPoint)
        }
        if isBirdSkyZoneDrawingMode {
            return canvasView.continueBirdSkyZoneDraft(at: viewPoint)
        }
        return canvasView.continuePlantDrag(at: viewPoint)
    }

    private func handleMouseUp() {
        lastDragScreenPoint = nil
        if gnomePerspectiveDragSession != nil {
            _ = updateGnomePerspectiveAdjustment(at: NSEvent.mouseLocation, shouldSave: true)
            gnomePerspectiveDragSession = nil
            mousePressCoordinator.endPress()
            updateInteractionRegionWindows()
            updateMouseRouting(at: NSEvent.mouseLocation)
            return
        }

        if let activeDragWindow,
           let canvasView = activeDragWindow.contentView as? GardenCanvasView {
            if isSoilBrushMode {
                _ = canvasView.endSoilBrushStroke()
            } else if isGnomeZoneDrawingMode {
                _ = canvasView.endGnomeZoneDraft()
            } else if isBirdSkyZoneDrawingMode {
                _ = canvasView.endBirdSkyZoneDraft()
            } else {
                _ = canvasView.endPlantDrag()
            }
        }
        activeDragWindow = nil
        activeDragPointIndex = 0
        mousePressCoordinator.endPress()
        updateInteractionRegionWindows()
        updateMouseRouting(at: NSEvent.mouseLocation)
    }

    private func disableMouseRouting() {
        lastDragScreenPoint = nil
        isPointerPollingDragActive = false
        gnomePerspectiveDragSession = nil
        if let activeDragWindow,
           let canvasView = activeDragWindow.contentView as? GardenCanvasView {
            if isSoilBrushMode {
                _ = canvasView.endSoilBrushStroke()
            } else if isGnomeZoneDrawingMode {
                _ = canvasView.endGnomeZoneDraft()
            } else if isBirdSkyZoneDrawingMode {
                _ = canvasView.endBirdSkyZoneDraft()
            } else {
                _ = canvasView.endPlantDrag()
            }
        }
        activeDragWindow = nil
        activeDragPointIndex = 0
        mousePressCoordinator.endPress()
        interactionWindows.forEach { $0.close() }
        interactionWindows = []
        interactionRegionFrames = []
        lastPointerRoutingScreenPoint = nil
        windows.forEach { $0.ignoresMouseEvents = true }
    }

    private func viewPointCandidates(
        for screenPoint: NSPoint,
        in window: GardenWindow,
        canvasView: GardenCanvasView
    ) -> [NSPoint] {
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let convertedPoint = canvasView.convert(windowPoint, from: nil)
        return GardenPointerCoordinateCandidates.yValues(
            convertedY: Double(convertedPoint.y),
            viewHeight: Double(canvasView.bounds.height)
        ).map { yValue in
            NSPoint(x: convertedPoint.x, y: CGFloat(yValue))
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
