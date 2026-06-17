import AppKit
import PlantGardenCore

/// The draggable desktop radio companion: artwork, layout, and hit areas.
extension GardenCanvasView {
    func drawMusicButtonIfNeeded() {
        let now = currentDateProvider()
        for entry in musicButtonRects() {
            let companion = entry.button.companion
            let visualRect = musicButtonVisualRect(for: entry, now: now)
            if shouldDrawMusicButtonHoverSignal(for: entry.index, companion: companion, now: now) {
                drawMusicButtonHoverSignal(in: visualRect, at: now)
            }
            if let image = GardenRadioCompanionAssetLibrary.shared.image(for: companion) {
                drawRadioCompanionAsset(image, in: visualRect)
            } else {
                drawRadioCompanion(companion, in: visualRect.insetBy(dx: 2, dy: 2))
            }
            if musicPlayer.playingRadioStream?.id == companion.stationStream(in: store.state.settings).id {
                drawMusicButtonSignal(in: visualRect)
            }
        }
    }

    func visibleMusicButtonCompanion() -> GardenRadioCompanion? {
        store.state.musicButton?.companion
    }

    func visibleMusicButtonCompanion(at index: Int) -> GardenRadioCompanion? {
        guard store.state.musicButtons.indices.contains(index) else {
            return nil
        }

        return store.state.musicButtons[index].companion
    }

    private func drawRadioCompanionAsset(_ image: NSImage, in rect: NSRect) {
        let sourceSize = image.size
        let sourceAspect = sourceSize.width / max(1, sourceSize.height)
        let targetAspect = rect.width / max(1, rect.height)
        let drawSize: NSSize
        if sourceAspect > targetAspect {
            drawSize = NSSize(width: rect.width, height: rect.width / sourceAspect)
        } else {
            drawSize = NSSize(width: rect.height * sourceAspect, height: rect.height)
        }

        let drawRect = NSRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        image.draw(
            in: drawRect,
            from: NSRect(origin: .zero, size: sourceSize),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func drawRadioCompanion(_ companion: GardenRadioCompanion, in rect: NSRect) {
        switch companion {
        case .gardenCat:
            drawGardenCat(in: rect)
        case .moonMoth:
            drawMoonMoth(in: rect)
        case .mushroomSpeaker:
            drawMushroomSpeaker(in: rect)
        case .brassFrog:
            drawBrassFrog(in: rect)
        case .tinyRocket:
            drawTinyRocket(in: rect)
        case .toyDelorean, .bigfootFieldRadio, .miniUfoTerrarium, .chillGardenGnome, .greyAlienGardener,
             .cassetteSamurai, .sphinxPhonograph, .dubNinjaBonsai, .berlinBearSynth, .cinemaProjectorFirefly:
            drawRadioCompanionPlaceholder(in: rect)
        }
    }

    private func drawRadioCompanionPlaceholder(in rect: NSRect) {
        fillOval(rectPortion(rect, x: 0.16, y: 0.18, width: 0.68, height: 0.58), color(red: 78, green: 92, blue: 88, alpha: 0.98))
        fillOval(rectPortion(rect, x: 0.28, y: 0.30, width: 0.44, height: 0.36), color(red: 204, green: 166, blue: 92, alpha: 0.96))
        strokeLine(from: point(rect, x: 0.50, y: 0.72), to: point(rect, x: 0.50, y: 0.94), color: color(red: 204, green: 166, blue: 92, alpha: 0.92), width: 1.4)
        fillOval(rectPortion(rect, x: 0.47, y: 0.92, width: 0.06, height: 0.06), color(red: 232, green: 207, blue: 133, alpha: 0.96))
        drawRadioBadge(in: rect, tint: color(red: 76, green: 124, blue: 154, alpha: 0.98))
    }

    private func drawGardenCat(in rect: NSRect) {
        fillOval(rectPortion(rect, x: 0.19, y: 0.18, width: 0.58, height: 0.42), color(red: 87, green: 79, blue: 69, alpha: 0.98))
        fillOval(rectPortion(rect, x: 0.39, y: 0.48, width: 0.38, height: 0.33), color(red: 95, green: 86, blue: 74, alpha: 0.98))
        fillPolygon([
            point(rect, x: 0.42, y: 0.74),
            point(rect, x: 0.49, y: 0.95),
            point(rect, x: 0.56, y: 0.74)
        ], fill: color(red: 89, green: 77, blue: 66, alpha: 0.98))
        fillPolygon([
            point(rect, x: 0.63, y: 0.74),
            point(rect, x: 0.72, y: 0.94),
            point(rect, x: 0.75, y: 0.71)
        ], fill: color(red: 89, green: 77, blue: 66, alpha: 0.98))
        fillOval(rectPortion(rect, x: 0.48, y: 0.61, width: 0.055, height: 0.055), color(red: 255, green: 233, blue: 122, alpha: 0.96))
        fillOval(rectPortion(rect, x: 0.65, y: 0.61, width: 0.055, height: 0.055), color(red: 255, green: 233, blue: 122, alpha: 0.96))

        let tail = NSBezierPath()
        tail.move(to: point(rect, x: 0.22, y: 0.45))
        tail.curve(
            to: point(rect, x: 0.10, y: 0.76),
            controlPoint1: point(rect, x: 0.04, y: 0.44),
            controlPoint2: point(rect, x: 0.05, y: 0.72)
        )
        tail.lineWidth = max(3, rect.width * 0.07)
        tail.lineCapStyle = .round
        color(red: 87, green: 79, blue: 69, alpha: 0.98).setStroke()
        tail.stroke()
        drawRadioBadge(in: rect, tint: color(red: 203, green: 164, blue: 82, alpha: 0.98))
    }

    private func drawMoonMoth(in rect: NSRect) {
        fillOval(rectPortion(rect, x: 0.05, y: 0.31, width: 0.42, height: 0.50), color(red: 207, green: 217, blue: 216, alpha: 0.94))
        fillOval(rectPortion(rect, x: 0.53, y: 0.31, width: 0.42, height: 0.50), color(red: 207, green: 217, blue: 216, alpha: 0.94))
        fillOval(rectPortion(rect, x: 0.21, y: 0.15, width: 0.25, height: 0.34), color(red: 182, green: 199, blue: 200, alpha: 0.90))
        fillOval(rectPortion(rect, x: 0.54, y: 0.15, width: 0.25, height: 0.34), color(red: 182, green: 199, blue: 200, alpha: 0.90))
        fillRounded(rectPortion(rect, x: 0.45, y: 0.24, width: 0.10, height: 0.55), radius: rect.width * 0.05, fill: color(red: 94, green: 98, blue: 102, alpha: 0.98))
        fillOval(rectPortion(rect, x: 0.43, y: 0.69, width: 0.14, height: 0.14), color(red: 97, green: 101, blue: 106, alpha: 0.98))
        strokeLine(from: point(rect, x: 0.48, y: 0.80), to: point(rect, x: 0.35, y: 0.96), color: color(red: 111, green: 118, blue: 124, alpha: 0.74), width: 1.1)
        strokeLine(from: point(rect, x: 0.52, y: 0.80), to: point(rect, x: 0.65, y: 0.96), color: color(red: 111, green: 118, blue: 124, alpha: 0.74), width: 1.1)
        drawRadioBadge(in: rect, tint: color(red: 129, green: 151, blue: 193, alpha: 0.98))
    }

    private func drawMushroomSpeaker(in rect: NSRect) {
        let cap = NSBezierPath()
        cap.move(to: point(rect, x: 0.12, y: 0.55))
        cap.curve(
            to: point(rect, x: 0.88, y: 0.55),
            controlPoint1: point(rect, x: 0.22, y: 0.97),
            controlPoint2: point(rect, x: 0.78, y: 0.97)
        )
        cap.curve(
            to: point(rect, x: 0.12, y: 0.55),
            controlPoint1: point(rect, x: 0.76, y: 0.42),
            controlPoint2: point(rect, x: 0.24, y: 0.42)
        )
        cap.close()
        color(red: 170, green: 67, blue: 55, alpha: 0.98).setFill()
        cap.fill()

        fillRounded(rectPortion(rect, x: 0.34, y: 0.14, width: 0.32, height: 0.44), radius: rect.width * 0.12, fill: color(red: 235, green: 220, blue: 181, alpha: 0.98))
        fillOval(rectPortion(rect, x: 0.26, y: 0.63, width: 0.12, height: 0.10), color(red: 251, green: 231, blue: 196, alpha: 0.95))
        fillOval(rectPortion(rect, x: 0.51, y: 0.68, width: 0.10, height: 0.09), color(red: 251, green: 231, blue: 196, alpha: 0.95))
        fillOval(rectPortion(rect, x: 0.67, y: 0.57, width: 0.13, height: 0.10), color(red: 251, green: 231, blue: 196, alpha: 0.95))
        strokeLine(from: point(rect, x: 0.41, y: 0.38), to: point(rect, x: 0.59, y: 0.38), color: color(red: 92, green: 79, blue: 67, alpha: 0.72), width: 1.2)
        strokeLine(from: point(rect, x: 0.42, y: 0.30), to: point(rect, x: 0.58, y: 0.30), color: color(red: 92, green: 79, blue: 67, alpha: 0.62), width: 1.0)
        drawRadioBadge(in: rect, tint: color(red: 202, green: 110, blue: 72, alpha: 0.98))
    }

    private func drawBrassFrog(in rect: NSRect) {
        fillOval(rectPortion(rect, x: 0.20, y: 0.17, width: 0.60, height: 0.48), color(red: 83, green: 132, blue: 78, alpha: 0.98))
        fillOval(rectPortion(rect, x: 0.24, y: 0.49, width: 0.52, height: 0.32), color(red: 91, green: 151, blue: 88, alpha: 0.98))
        fillOval(rectPortion(rect, x: 0.31, y: 0.62, width: 0.14, height: 0.14), color(red: 231, green: 225, blue: 196, alpha: 0.98))
        fillOval(rectPortion(rect, x: 0.56, y: 0.62, width: 0.14, height: 0.14), color(red: 231, green: 225, blue: 196, alpha: 0.98))
        fillOval(rectPortion(rect, x: 0.36, y: 0.67, width: 0.045, height: 0.045), color(red: 33, green: 37, blue: 31, alpha: 0.98))
        fillOval(rectPortion(rect, x: 0.61, y: 0.67, width: 0.045, height: 0.045), color(red: 33, green: 37, blue: 31, alpha: 0.98))
        fillOval(rectPortion(rect, x: 0.38, y: 0.22, width: 0.24, height: 0.24), color(red: 198, green: 154, blue: 78, alpha: 0.96))
        strokeLine(from: point(rect, x: 0.37, y: 0.54), to: point(rect, x: 0.63, y: 0.54), color: color(red: 48, green: 73, blue: 44, alpha: 0.64), width: 1.2)
        drawRadioBadge(in: rect, tint: color(red: 198, green: 154, blue: 78, alpha: 0.98))
    }

    private func drawTinyRocket(in rect: NSRect) {
        let body = NSBezierPath()
        body.move(to: point(rect, x: 0.50, y: 0.92))
        body.curve(
            to: point(rect, x: 0.72, y: 0.30),
            controlPoint1: point(rect, x: 0.74, y: 0.74),
            controlPoint2: point(rect, x: 0.73, y: 0.43)
        )
        body.curve(
            to: point(rect, x: 0.28, y: 0.30),
            controlPoint1: point(rect, x: 0.62, y: 0.18),
            controlPoint2: point(rect, x: 0.38, y: 0.18)
        )
        body.curve(
            to: point(rect, x: 0.50, y: 0.92),
            controlPoint1: point(rect, x: 0.27, y: 0.43),
            controlPoint2: point(rect, x: 0.26, y: 0.74)
        )
        body.close()
        color(red: 230, green: 233, blue: 224, alpha: 0.98).setFill()
        body.fill()
        color(red: 80, green: 92, blue: 104, alpha: 0.58).setStroke()
        body.lineWidth = 1
        body.stroke()

        fillPolygon([
            point(rect, x: 0.28, y: 0.33),
            point(rect, x: 0.11, y: 0.18),
            point(rect, x: 0.34, y: 0.18)
        ], fill: color(red: 76, green: 124, blue: 154, alpha: 0.96))
        fillPolygon([
            point(rect, x: 0.72, y: 0.33),
            point(rect, x: 0.89, y: 0.18),
            point(rect, x: 0.66, y: 0.18)
        ], fill: color(red: 76, green: 124, blue: 154, alpha: 0.96))
        fillOval(rectPortion(rect, x: 0.40, y: 0.55, width: 0.20, height: 0.20), color(red: 79, green: 157, blue: 185, alpha: 0.96))
        fillPolygon([
            point(rect, x: 0.42, y: 0.22),
            point(rect, x: 0.50, y: 0.02),
            point(rect, x: 0.58, y: 0.22)
        ], fill: color(red: 227, green: 117, blue: 65, alpha: 0.96))
        drawRadioBadge(in: rect, tint: color(red: 76, green: 124, blue: 154, alpha: 0.98))
    }

    func drawMusicButtonSignal(in rect: NSRect) {
        for index in 0..<3 {
            let inset = CGFloat(index) * -4 - 2
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: inset, dy: inset))
            color(red: 255, green: 245, blue: 197, alpha: 0.18 - CGFloat(index) * 0.035).setStroke()
            path.lineWidth = 1.0
            path.stroke()
        }
    }

    private func drawMusicButtonHoverSignal(in rect: NSRect, at date: Date) {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let baseRadius = max(rect.width, rect.height) * 0.53
        let phase = CGFloat(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8)

        for index in 0..<3 {
            let localPhase = (phase + CGFloat(index) / 3).truncatingRemainder(dividingBy: 1)
            let radius = baseRadius * (1.00 + localPhase * 0.62)
            let alpha = 0.15 * (1 - localPhase)
            let path = NSBezierPath(ovalIn: NSRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            color(red: 255, green: 232, blue: 163, alpha: alpha).setStroke()
            path.lineWidth = 1.4
            path.stroke()
        }

        for index in 0..<6 {
            let beat = CGFloat(index) / 6
            let angle = (beat + phase * 0.18) * .pi * 2
            let radius = baseRadius * (1.05 + 0.18 * sin((phase + beat) * .pi * 2))
            let sparkCenter = NSPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            let sparkSize = max(2.2, rect.width * 0.025)
            fillOval(
                NSRect(
                    x: sparkCenter.x - sparkSize / 2,
                    y: sparkCenter.y - sparkSize / 2,
                    width: sparkSize,
                    height: sparkSize
                ),
                color(red: 255, green: 244, blue: 203, alpha: 0.12 + 0.08 * sin((phase + beat) * .pi * 2))
            )
        }
    }

    private func drawRadioBadge(in rect: NSRect, tint: NSColor) {
        let badgeRect = rectPortion(rect, x: 0.64, y: 0.12, width: 0.27, height: 0.27)
        fillOval(badgeRect, tint)

        let center = NSPoint(x: badgeRect.midX - badgeRect.width * 0.12, y: badgeRect.midY)
        for index in 0..<2 {
            let path = NSBezierPath()
            path.appendArc(
                withCenter: center,
                radius: badgeRect.width * (0.18 + CGFloat(index) * 0.18),
                startAngle: -46,
                endAngle: 46
            )
            color(red: 255, green: 252, blue: 232, alpha: 0.94).setStroke()
            path.lineWidth = 1.2
            path.stroke()
        }
    }

    private func fillOval(_ rect: NSRect, _ fill: NSColor) {
        fill.setFill()
        NSBezierPath(ovalIn: rect).fill()
    }

    private func fillRounded(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
        fill.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }

    private func fillPolygon(_ points: [NSPoint], fill: NSColor) {
        guard let first = points.first else {
            return
        }

        let path = NSBezierPath()
        path.move(to: first)
        for point in points.dropFirst() {
            path.line(to: point)
        }
        path.close()
        fill.setFill()
        path.fill()
    }

    private func strokeLine(from start: NSPoint, to end: NSPoint, color: NSColor, width: CGFloat) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = width
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }

    private func rectPortion(_ rect: NSRect, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
        NSRect(
            x: rect.minX + rect.width * x,
            y: rect.minY + rect.height * y,
            width: rect.width * width,
            height: rect.height * height
        )
    }

    private func point(_ rect: NSRect, x: CGFloat, y: CGFloat) -> NSPoint {
        NSPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
    }

    func musicButtonRect() -> NSRect? {
        musicButtonRects().first?.rect
    }

    func musicButtonRects() -> [(index: Int, button: GardenMusicButton, rect: NSRect)] {
        store.state.musicButtons.enumerated().compactMap { index, musicButton in
            guard musicButton.screenIndex == screenIndex else {
                return nil
            }

            return (index, musicButton, musicButtonRect(for: musicButton))
        }
    }

    private func musicButtonRect(for musicButton: GardenMusicButton) -> NSRect {
        let size = musicButtonSize
        let halfSize = size / 2
        let center = NSPoint(
            x: min(max(halfSize, CGFloat(musicButton.position.x) * bounds.width), max(halfSize, bounds.width - halfSize)),
            y: min(max(halfSize, CGFloat(musicButton.position.y) * bounds.height), max(halfSize, bounds.height - halfSize))
        )
        return NSRect(
            x: center.x - halfSize,
            y: center.y - halfSize,
            width: size,
            height: size
        )
    }

    var musicButtonSize: CGFloat {
        Self.musicButtonSize * CGFloat(store.state.settings.radioCompanionScale)
    }

    func updateMusicButtonHover(at point: NSPoint, now: Date = Date()) {
        guard drawsInteractiveChrome,
              let hit = musicButtonHit(at: point) else {
            clearMusicButtonHover()
            return
        }

        if musicButtonHoverState?.buttonIndex != hit.index {
            musicButtonHoverState = MusicButtonHoverState(buttonIndex: hit.index, enteredAt: now)
            startMusicButtonHoverAnimationTimer()
            needsDisplay = true
        } else {
            startMusicButtonHoverAnimationTimer()
        }
    }

    func updateMusicButtonHover(at candidatePoints: [NSPoint], now: Date = Date()) {
        guard drawsInteractiveChrome,
              let hitPoint = candidatePoints.first(where: { musicButtonHit(at: $0) != nil }) else {
            clearMusicButtonHover()
            return
        }

        updateMusicButtonHover(at: hitPoint, now: now)
    }

    func clearMusicButtonHover() {
        guard musicButtonHoverState != nil || musicButtonHoverAnimationTimer != nil else {
            return
        }

        musicButtonHoverState = nil
        musicButtonHoverAnimationTimer?.invalidate()
        musicButtonHoverAnimationTimer = nil
        needsDisplay = true
    }

    func musicButtonVisualRects(now: Date = Date()) -> [(index: Int, button: GardenMusicButton, rect: NSRect)] {
        musicButtonRects().map { entry in
            (entry.index, entry.button, musicButtonVisualRect(for: entry, now: now))
        }
    }

    func shouldDrawMusicButtonHoverSignal(
        for index: Int,
        companion: GardenRadioCompanion,
        now: Date = Date()
    ) -> Bool {
        musicButtonHoverProgress(for: index, now: now) > 0
            && musicPlayer.playingRadioStream?.id == companion.stationStream(in: store.state.settings).id
    }

    private func musicButtonVisualRect(
        for entry: (index: Int, button: GardenMusicButton, rect: NSRect),
        now: Date
    ) -> NSRect {
        let progress = musicButtonHoverProgress(for: entry.index, now: now)
        guard progress > 0 else {
            return entry.rect
        }

        let easedProgress = 1 - pow(1 - progress, 3)
        let scale = 1 + Self.musicButtonHoverScaleBonus * easedProgress
        let expandedWidth = entry.rect.width * scale
        let expandedHeight = entry.rect.height * scale
        return NSRect(
            x: entry.rect.midX - expandedWidth / 2,
            y: entry.rect.midY - expandedHeight / 2,
            width: expandedWidth,
            height: expandedHeight
        )
    }

    private func musicButtonHoverProgress(for index: Int, now: Date) -> CGFloat {
        guard let musicButtonHoverState,
              musicButtonHoverState.buttonIndex == index else {
            return 0
        }

        let elapsed = now.timeIntervalSince(musicButtonHoverState.enteredAt)
        let activeElapsed = elapsed - Self.musicButtonHoverActivationInterval
        guard activeElapsed > 0 else {
            return 0
        }
        return min(1, CGFloat(activeElapsed / 0.45))
    }

    private func startMusicButtonHoverAnimationTimer() {
        guard musicButtonHoverAnimationTimer == nil else {
            return
        }

        musicButtonHoverAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1 / 24, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                guard self.musicButtonHoverState != nil else {
                    self.musicButtonHoverAnimationTimer?.invalidate()
                    self.musicButtonHoverAnimationTimer = nil
                    return
                }
                self.needsDisplay = true
            }
        }
    }

    func musicButtonInteractionRect() -> NSRect? {
        musicButtonInteractionRects()
            .map(\.rect)
            .reduce(nil) { combined, rect in
                guard let combined else {
                    return rect
                }

                return combined.union(rect)
            }
    }

    func musicButtonInteractionRects() -> [(index: Int, button: GardenMusicButton, rect: NSRect)] {
        musicButtonRects().map { entry in
            (entry.index, entry.button, entry.rect.insetBy(dx: -Self.musicButtonHitOutset, dy: -Self.musicButtonHitOutset))
        }
    }

    func musicButtonHit(at point: NSPoint) -> (index: Int, button: GardenMusicButton, rect: NSRect)? {
        musicButtonInteractionRects()
            .reversed()
            .first { $0.rect.contains(point) }
    }

    func musicButtonContains(_ point: NSPoint) -> Bool {
        musicButtonHit(at: point) != nil
    }
}
