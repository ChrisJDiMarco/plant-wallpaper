import AppKit
import PlantGardenCore

extension GardenCanvasView {
    func drawPendingCustomPlantAssets(dirtyRect: NSRect) {
        guard !arePlantsHiddenForAILockView else { return }
        updatePendingCustomAssetAnimation()

        for pending in store.pendingCustomPlantAssets where pending.screenIndex == screenIndex {
            let rect = pendingCustomPlantRect(for: pending)
            guard rect.intersects(dirtyRect) else {
                continue
            }

            drawPendingCustomPlantAsset(pending, in: rect)
        }
    }

    func pendingCustomPlantInteractionRects() -> [NSRect] {
        store.pendingCustomPlantAssets
            .filter { $0.screenIndex == screenIndex }
            .map { pendingCustomPlantInteractionRect(for: $0) }
    }

    func pendingCustomPlantAssetID(at point: NSPoint) -> UUID? {
        store.pendingCustomPlantAssets
            .filter { $0.screenIndex == screenIndex }
            .first { pendingCustomPlantInteractionRect(for: $0).contains(point) }?
            .id
    }

    @discardableResult
    func beginPendingCustomPlantAssetDrag(at point: NSPoint) -> Bool {
        guard let pending = store.pendingCustomPlantAssets
            .filter({ $0.screenIndex == screenIndex })
            .first(where: { pendingCustomPlantInteractionRect(for: $0).contains(point) }) else {
            return false
        }

        let anchor = pendingCustomPlantAnchor(for: pending)
        pendingCustomAssetDragSession = PendingCustomAssetDragSession(
            pendingID: pending.id,
            dragOffset: NSPoint(x: anchor.x - point.x, y: anchor.y - point.y)
        )
        NSCursor.closedHand.set()
        return true
    }

    @discardableResult
    func continuePendingCustomPlantAssetDrag(at point: NSPoint) -> Bool {
        guard let session = pendingCustomAssetDragSession,
              let pending = store.pendingCustomPlantAsset(id: session.pendingID) else {
            return false
        }

        let oldRect = pendingCustomPlantInteractionRect(for: pending)
        let adjustedPoint = NSPoint(
            x: point.x + session.dragOffset.x,
            y: point.y + session.dragOffset.y
        )
        let nextPosition = GardenPoint(
            x: Double(adjustedPoint.x / max(1, bounds.width)),
            y: Double(adjustedPoint.y / max(1, bounds.height))
        )
        store.movePendingCustomPlantAsset(
            id: session.pendingID,
            to: nextPosition,
            screenIndex: screenIndex,
            notify: false
        )

        let nextPending = store.pendingCustomPlantAsset(id: session.pendingID) ?? pending
        let nextRect = pendingCustomPlantInteractionRect(for: nextPending)
        invalidatePendingCustomPlantAssetRegion(oldRect.union(nextRect))
        return true
    }

    @discardableResult
    func endPendingCustomPlantAssetDrag() -> Bool {
        guard let session = pendingCustomAssetDragSession else {
            return false
        }

        pendingCustomAssetDragSession = nil
        store.settlePendingCustomPlantAsset(id: session.pendingID)
        NSCursor.openHand.set()
        return true
    }

    func stopPendingCustomAssetAnimation() {
        pendingCustomAssetAnimationTimer?.invalidate()
        pendingCustomAssetAnimationTimer = nil
    }

    private func pendingCustomPlantRect(for pending: GardenStore.PendingCustomPlantAsset) -> NSRect {
        let anchor = pendingCustomPlantAnchor(for: pending)
        let size = pendingCustomPlantSize(for: pending.kind)
        return NSRect(
            x: anchor.x - size / 2,
            y: anchor.y - size * 0.86,
            width: size,
            height: size
        )
    }

    private func pendingCustomPlantAnchor(for pending: GardenStore.PendingCustomPlantAsset) -> NSPoint {
        NSPoint(
            x: CGFloat(pending.position.x) * bounds.width,
            y: CGFloat(pending.position.y) * bounds.height
        )
    }

    private func pendingCustomPlantInteractionRect(for pending: GardenStore.PendingCustomPlantAsset) -> NSRect {
        pendingCustomPlantRect(for: pending).insetBy(dx: -18, dy: -18)
    }

    private func pendingCustomPlantSize(for kind: PlantKind) -> CGFloat {
        let viewportFactor = min(1.05, max(0.72, bounds.height / 900.0))
        switch kind {
        case .tree:
            return 102 * viewportFactor
        case .foliage, .edible:
            return 84 * viewportFactor
        case .flower:
            return 80 * viewportFactor
        case .meadow:
            return 76 * viewportFactor
        }
    }

    private func updatePendingCustomAssetAnimation() {
        let hasPendingAssets = store.pendingCustomPlantAssets.contains { $0.screenIndex == screenIndex }
        guard hasPendingAssets else {
            stopPendingCustomAssetAnimation()
            return
        }

        guard pendingCustomAssetAnimationTimer == nil else {
            return
        }

        let timer = Timer.scheduledTimer(
            withTimeInterval: Self.pendingCustomAssetAnimationInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.invalidatePendingCustomPlantAssetRegionsForAnimation()
            }
        }
        timer.tolerance = Self.pendingCustomAssetAnimationInterval * 0.18
        RunLoop.main.add(timer, forMode: .common)
        pendingCustomAssetAnimationTimer = timer
    }

    private func invalidatePendingCustomPlantAssetRegionsForAnimation() {
        let rects = pendingCustomPlantInteractionRects()
        guard !rects.isEmpty else {
            stopPendingCustomAssetAnimation()
            return
        }

        for rect in rects {
            invalidatePendingCustomPlantAssetRegion(rect)
        }
    }

    private func invalidatePendingCustomPlantAssetRegion(_ rect: NSRect) {
        let dirtyRect = rect.insetBy(dx: -22, dy: -22).intersection(bounds)
        guard !dirtyRect.isNull, !dirtyRect.isEmpty else {
            return
        }
        setNeedsDisplay(dirtyRect)
    }

    private func drawPendingCustomPlantAsset(
        _ pending: GardenStore.PendingCustomPlantAsset,
        in rect: NSRect
    ) {
        let elapsed = max(0, currentDateProvider().timeIntervalSince(pending.startedAt))
        let pulse = (sin(elapsed * 4.8) + 1) / 2
        let slowPulse = (sin(elapsed * 1.45) + 1) / 2
        let accent = pendingCustomPlantAccent(for: pending.kind)
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let groundCenter = NSPoint(x: rect.midX, y: rect.maxY - rect.height * 0.15)

        NSGraphicsContext.current?.saveGraphicsState()
        drawPendingGroundGlow(
            center: groundCenter,
            width: rect.width * (0.82 + CGFloat(slowPulse) * 0.08),
            accent: accent
        )
        drawPendingEnergyHalo(in: rect, accent: accent, pulse: CGFloat(pulse))
        drawPendingConstructionRings(
            center: center,
            radius: rect.width * 0.42,
            elapsed: elapsed,
            accent: accent
        )
        drawPendingHologramCore(in: rect, accent: accent, pulse: CGFloat(pulse))
        drawPendingScanLines(in: rect, elapsed: elapsed, accent: accent)
        drawPendingOrbitDots(
            center: center,
            radius: rect.width * 0.43,
            elapsed: elapsed,
            accent: accent
        )
        drawPendingSparkField(in: rect, elapsed: elapsed, accent: accent)
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private func pendingCustomPlantAccent(for kind: PlantKind) -> NSColor {
        switch kind {
        case .flower:
            color(red: 242, green: 84, blue: 150, alpha: 1)
        case .tree:
            color(red: 85, green: 164, blue: 92, alpha: 1)
        case .foliage:
            color(red: 38, green: 177, blue: 148, alpha: 1)
        case .meadow:
            color(red: 184, green: 193, blue: 77, alpha: 1)
        case .edible:
            color(red: 239, green: 139, blue: 53, alpha: 1)
        }
    }

    private func drawPendingGroundGlow(center: NSPoint, width: CGFloat, accent: NSColor) {
        let rect = NSRect(
            x: center.x - width / 2,
            y: center.y - width * 0.12,
            width: width,
            height: width * 0.24
        )
        NSGradient(colors: [
            accent.withAlphaComponent(0.30),
            NSColor.black.withAlphaComponent(0.12),
            NSColor.clear
        ])?.draw(in: NSBezierPath(ovalIn: rect), angle: 0)
    }

    private func drawPendingEnergyHalo(in rect: NSRect, accent: NSColor, pulse: CGFloat) {
        let haloRect = rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06)
        NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.24 + pulse * 0.08),
            accent.withAlphaComponent(0.16),
            NSColor.clear
        ])?.draw(in: NSBezierPath(ovalIn: haloRect), angle: 90)
    }

    private func drawPendingConstructionRings(
        center: NSPoint,
        radius: CGFloat,
        elapsed: TimeInterval,
        accent: NSColor
    ) {
        for index in 0..<3 {
            let phase = elapsed * (1.8 + Double(index) * 0.34) + Double(index) * 1.7
            let ringRadius = radius * (0.76 + CGFloat(index) * 0.15 + CGFloat(sin(phase)) * 0.025)
            let ringRect = NSRect(
                x: center.x - ringRadius,
                y: center.y - ringRadius * (0.76 - CGFloat(index) * 0.07),
                width: ringRadius * 2,
                height: ringRadius * 2 * (0.76 - CGFloat(index) * 0.07)
            )
            let ring = NSBezierPath(ovalIn: ringRect)
            let alpha = 0.15 + CGFloat(index) * 0.08
            accent.withAlphaComponent(alpha).setStroke()
            ring.lineWidth = max(1.4, radius * (0.018 + CGFloat(index) * 0.004))
            ring.stroke()

            let dashPath = NSBezierPath(ovalIn: ringRect.insetBy(dx: 3, dy: 3))
            dashPath.setLineDash([radius * 0.11, radius * 0.055], count: 2, phase: CGFloat(phase) * radius * 0.08)
            NSColor.white.withAlphaComponent(0.12 + CGFloat(index) * 0.04).setStroke()
            dashPath.lineWidth = 1
            dashPath.stroke()
        }
    }

    private func drawPendingHologramCore(in rect: NSRect, accent: NSColor, pulse: CGFloat) {
        let stemPath = NSBezierPath()
        stemPath.move(to: NSPoint(x: rect.midX, y: rect.maxY - rect.height * 0.20))
        stemPath.curve(
            to: NSPoint(x: rect.midX + rect.width * 0.02, y: rect.minY + rect.height * 0.28),
            controlPoint1: NSPoint(x: rect.midX - rect.width * 0.05, y: rect.maxY - rect.height * 0.42),
            controlPoint2: NSPoint(x: rect.midX + rect.width * 0.08, y: rect.minY + rect.height * 0.50)
        )
        accent.withAlphaComponent(0.78 + pulse * 0.18).setStroke()
        stemPath.lineWidth = max(4, rect.width * 0.06)
        stemPath.lineCapStyle = .round
        stemPath.stroke()

        let leafRects = [
            NSRect(
                x: rect.midX - rect.width * 0.38,
                y: rect.minY + rect.height * 0.34,
                width: rect.width * 0.38,
                height: rect.height * 0.20
            ),
            NSRect(
                x: rect.midX + rect.width * 0.02,
                y: rect.minY + rect.height * 0.29,
                width: rect.width * 0.40,
                height: rect.height * 0.21
            )
        ]
        for (index, leafRect) in leafRects.enumerated() {
            let path = NSBezierPath(ovalIn: leafRect)
            NSGradient(colors: [
                accent.withAlphaComponent(0.45 + pulse * 0.10),
                NSColor.white.withAlphaComponent(0.16),
                accent.withAlphaComponent(0.18)
            ])?.draw(in: path, angle: index == 0 ? 18 : 162)
            NSColor.white.withAlphaComponent(0.24).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func drawPendingScanLines(in rect: NSRect, elapsed: TimeInterval, accent: NSColor) {
        let clipPath = NSBezierPath(ovalIn: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08))
        NSGraphicsContext.current?.saveGraphicsState()
        clipPath.addClip()

        let spacing = max(7, rect.height * 0.09)
        let offset = CGFloat(elapsed.truncatingRemainder(dividingBy: 1.0)) * spacing
        var y = rect.minY + offset
        while y <= rect.maxY {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX + rect.width * 0.18, y: y))
            path.line(to: NSPoint(x: rect.maxX - rect.width * 0.18, y: y + rect.height * 0.018))
            accent.withAlphaComponent(0.07).setStroke()
            path.lineWidth = 1
            path.stroke()
            y += spacing
        }

        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private func drawPendingOrbitDots(
        center: NSPoint,
        radius: CGFloat,
        elapsed: TimeInterval,
        accent: NSColor
    ) {
        for index in 0..<8 {
            let angle = elapsed * (2.2 + Double(index % 3) * 0.22) + Double(index) * (.pi * 2 / 8)
            let localRadius = radius * (0.84 + CGFloat(index % 2) * 0.10)
            let dotRadius = max(2.1, radius * (0.035 + CGFloat(index % 3) * 0.006))
            let dotCenter = NSPoint(
                x: center.x + cos(angle) * localRadius,
                y: center.y + sin(angle) * localRadius * 0.55
            )
            let alpha = 0.22 + CGFloat(index % 4) * 0.07
            NSGradient(colors: [
                NSColor.white.withAlphaComponent(alpha + 0.16),
                accent.withAlphaComponent(alpha),
                accent.withAlphaComponent(0.02)
            ])?.draw(in: NSBezierPath(ovalIn: NSRect(
                x: dotCenter.x - dotRadius,
                y: dotCenter.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )), angle: 90)
        }
    }

    private func drawPendingSparkField(in rect: NSRect, elapsed: TimeInterval, accent: NSColor) {
        for index in 0..<9 {
            let seed = Double(index) * 12.9898
            let phase = elapsed * (0.75 + Double(index % 4) * 0.16) + seed
            let x = rect.minX + rect.width * CGFloat(0.16 + 0.68 * pseudoRandom(seed))
            let drift = CGFloat(sin(phase) * 0.035)
            let y = rect.minY + rect.height * CGFloat(0.12 + 0.76 * pseudoRandom(seed + 7.3)) + rect.height * drift
            let size = max(1.4, rect.width * CGFloat(0.012 + 0.016 * pseudoRandom(seed + 3.1)))
            let alpha = 0.10 + CGFloat((sin(phase * 2.0) + 1) / 2) * 0.32
            accent.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: x - size, y: y - size, width: size * 2, height: size * 2)).fill()
        }
    }

    private func pseudoRandom(_ value: Double) -> Double {
        let raw = sin(value) * 43_758.5453
        return raw - floor(raw)
    }
}
