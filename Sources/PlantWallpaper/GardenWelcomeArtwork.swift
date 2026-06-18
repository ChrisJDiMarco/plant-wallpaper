import AppKit

/// Self-contained vector illustrations for the welcome tour. Each one renders
/// as a rounded "hero card" with its own palette so it reads crisply on the
/// panel's translucent blur in both light and dark appearances — no bundled
/// screenshots to go stale, and everything scales to retina.
enum GardenWelcomeArtwork {
    enum Kind {
        case desktopGarden
        case deskControl
        case gameLoop
        case create
        case worlds
        case companions
        case livingWorld
        case controlCenter
    }

    static func image(for kind: Kind, size: NSSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            let card = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
            card.addClip()
            switch kind {
            case .desktopGarden: drawDesktopGarden(rect)
            case .deskControl: drawDeskControl(rect)
            case .gameLoop: drawGameLoop(rect)
            case .create: drawCreate(rect)
            case .worlds: drawWorlds(rect)
            case .companions: drawCompanions(rect)
            case .livingWorld: drawLivingWorld(rect)
            case .controlCenter: drawControlCenter(rect)
            }
            // A hairline inset stroke keeps the card crisp against the blur.
            let stroke = NSBezierPath(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), xRadius: 17, yRadius: 17)
            NSColor.white.withAlphaComponent(0.16).setStroke()
            stroke.lineWidth = 1.5
            stroke.stroke()
            return true
        }
    }

    // MARK: - Palette helpers

    private static func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }

    private static func fillVerticalGradient(_ rect: NSRect, top: NSColor, bottom: NSColor) {
        let gradient = NSGradient(starting: top, ending: bottom)
        gradient?.draw(in: rect, angle: -90)
    }

    private static func softGround(_ rect: NSRect, height: CGFloat, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.minX, y: rect.minY + height * 0.7))
        path.curve(
            to: NSPoint(x: rect.maxX, y: rect.minY + height * 0.7),
            controlPoint1: NSPoint(x: rect.midX - rect.width * 0.2, y: rect.minY + height),
            controlPoint2: NSPoint(x: rect.midX + rect.width * 0.2, y: rect.minY + height * 0.45)
        )
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        path.close()
        color.setFill()
        path.fill()
    }

    /// A simple potted/bush plant centered on its base point.
    private static func drawPlant(baseX: CGFloat, baseY: CGFloat, scale: CGFloat, leaf: NSColor, bloom: NSColor?) {
        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: baseX, y: baseY))
        stem.line(to: NSPoint(x: baseX, y: baseY + 34 * scale))
        stem.lineWidth = 3 * scale
        color(86, 122, 78).setStroke()
        stem.stroke()

        let foliage: [(CGFloat, CGFloat, CGFloat)] = [
            (-9, 24, 11), (9, 26, 11), (0, 36, 13), (-5, 14, 9), (6, 16, 9)
        ]
        leaf.setFill()
        for (dx, dy, r) in foliage {
            let bubble = NSBezierPath(ovalIn: NSRect(
                x: baseX + dx * scale - r * scale,
                y: baseY + dy * scale - r * scale,
                width: r * 2 * scale,
                height: r * 2 * scale
            ))
            bubble.fill()
        }
        if let bloom {
            bloom.setFill()
            for (dx, dy) in [(-6.0, 30.0), (7.0, 24.0), (0.0, 40.0)] {
                let dot = NSBezierPath(ovalIn: NSRect(
                    x: baseX + CGFloat(dx) * scale - 3.5 * scale,
                    y: baseY + CGFloat(dy) * scale - 3.5 * scale,
                    width: 7 * scale, height: 7 * scale
                ))
                dot.fill()
            }
        }
    }

    private static func drawCursor(at point: NSPoint, scale: CGFloat = 1) {
        let p = NSBezierPath()
        p.move(to: point)
        p.line(to: NSPoint(x: point.x, y: point.y - 22 * scale))
        p.line(to: NSPoint(x: point.x + 6 * scale, y: point.y - 16 * scale))
        p.line(to: NSPoint(x: point.x + 10 * scale, y: point.y - 24 * scale))
        p.line(to: NSPoint(x: point.x + 14 * scale, y: point.y - 22 * scale))
        p.line(to: NSPoint(x: point.x + 9 * scale, y: point.y - 13 * scale))
        p.line(to: NSPoint(x: point.x + 16 * scale, y: point.y - 13 * scale))
        p.close()
        NSColor.white.setFill()
        p.fill()
        NSColor.black.withAlphaComponent(0.55).setStroke()
        p.lineWidth = 1.2
        p.stroke()
    }

    private static func drawText(_ string: String, at point: NSPoint, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color
        ]
        (string as NSString).draw(at: point, withAttributes: attrs)
    }

    private static func drawSymbol(_ name: String, in rect: NSRect, color: NSColor) {
        let config = NSImage.SymbolConfiguration(pointSize: rect.height, weight: .semibold)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }
        let tinted = NSImage(size: rect.size, flipped: false) { drawRect in
            color.set()
            drawRect.fill()
            symbol.draw(in: drawRect, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
        tinted.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    // MARK: - Illustrations

    private static func drawDesktopGarden(_ rect: NSRect) {
        fillVerticalGradient(rect, top: color(70, 132, 96), bottom: color(38, 86, 70))
        softGround(rect, height: rect.height * 0.42, color: color(46, 96, 70))
        let groundY = rect.minY + rect.height * 0.22
        drawPlant(baseX: rect.minX + rect.width * 0.18, baseY: groundY, scale: 1.0, leaf: color(150, 205, 138), bloom: color(255, 209, 102))
        drawPlant(baseX: rect.minX + rect.width * 0.34, baseY: groundY - 4, scale: 1.25, leaf: color(120, 188, 120), bloom: nil)
        drawPlant(baseX: rect.minX + rect.width * 0.52, baseY: groundY, scale: 0.9, leaf: color(168, 214, 150), bloom: color(244, 162, 97))
        drawPlant(baseX: rect.minX + rect.width * 0.7, baseY: groundY - 2, scale: 1.1, leaf: color(132, 198, 132), bloom: nil)
        // Click ripple + cursor on a plant.
        let rippleCenter = NSPoint(x: rect.minX + rect.width * 0.7, y: groundY + rect.height * 0.34)
        for (i, r) in [10.0, 18.0, 26.0].enumerated() {
            let ring = NSBezierPath(ovalIn: NSRect(x: rippleCenter.x - r, y: rippleCenter.y - r, width: r * 2, height: r * 2))
            NSColor.white.withAlphaComponent(0.30 - CGFloat(i) * 0.08).setStroke()
            ring.lineWidth = 2
            ring.stroke()
        }
        drawCursor(at: NSPoint(x: rippleCenter.x + 4, y: rippleCenter.y + 6))
    }

    private static func drawDeskControl(_ rect: NSRect) {
        fillVerticalGradient(rect, top: color(58, 74, 110), bottom: color(33, 42, 74))
        // A mock menu-bar dropdown, highlighting "Lock Garden Interactions".
        let panel = rect.insetBy(dx: rect.width * 0.16, dy: rect.height * 0.12)
        let panelPath = NSBezierPath(roundedRect: panel, xRadius: 12, yRadius: 12)
        color(248, 248, 250, 0.97).setFill()
        panelPath.fill()
        NSColor.black.withAlphaComponent(0.12).setStroke()
        panelPath.lineWidth = 1
        panelPath.stroke()

        let ink = color(40, 42, 48)
        let rows = ["Water All", "Plant Here", "Pause Growth"]
        let rowHeight = panel.height / 5.6
        var y = panel.maxY - rowHeight * 1.0
        // Title
        drawText("Plant Wallpaper", at: NSPoint(x: panel.minX + 16, y: y + rowHeight * 0.18), size: 11, color: color(120, 124, 134), weight: .semibold)
        y -= rowHeight
        for row in rows {
            drawText(row, at: NSPoint(x: panel.minX + 18, y: y + rowHeight * 0.22), size: 12, color: ink)
            y -= rowHeight
        }
        // Highlighted Lock row.
        let highlight = NSRect(x: panel.minX + 6, y: y + 2, width: panel.width - 12, height: rowHeight - 4)
        let hlPath = NSBezierPath(roundedRect: highlight, xRadius: 6, yRadius: 6)
        color(64, 120, 226).setFill()
        hlPath.fill()
        drawSymbol("lock.fill", in: NSRect(x: highlight.minX + 12, y: highlight.midY - 7, width: 14, height: 14), color: .white)
        drawText("Lock Garden Interactions", at: NSPoint(x: highlight.minX + 34, y: highlight.midY - 7), size: 12, color: .white, weight: .semibold)
        y -= rowHeight
        drawText("Settings & Dashboard…", at: NSPoint(x: panel.minX + 18, y: y + rowHeight * 0.22), size: 12, color: color(96, 100, 110))
    }

    private static func drawGameLoop(_ rect: NSRect) {
        fillVerticalGradient(rect, top: color(96, 168, 138), bottom: color(52, 120, 104))
        softGround(rect, height: rect.height * 0.36, color: color(60, 124, 100))
        let groundY = rect.minY + rect.height * 0.2
        // Three growth stages left → right.
        let xs = [0.2, 0.42, 0.64]
        let scales: [CGFloat] = [0.5, 0.85, 1.25]
        let blooms: [NSColor?] = [nil, nil, color(255, 209, 102)]
        for i in 0..<3 {
            drawPlant(baseX: rect.minX + rect.width * CGFloat(xs[i]), baseY: groundY, scale: scales[i], leaf: color(168, 220, 150), bloom: blooms[i])
        }
        // Arrows between stages.
        for x in [0.31, 0.53] {
            let ax = rect.minX + rect.width * CGFloat(x)
            let ay = groundY + rect.height * 0.34
            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: ax - 9, y: ay))
            arrow.line(to: NSPoint(x: ax + 7, y: ay))
            arrow.move(to: NSPoint(x: ax + 1, y: ay + 5))
            arrow.line(to: NSPoint(x: ax + 8, y: ay))
            arrow.line(to: NSPoint(x: ax + 1, y: ay - 5))
            NSColor.white.withAlphaComponent(0.85).setStroke()
            arrow.lineWidth = 2
            arrow.stroke()
        }
        // Harvest basket motif (top-right).
        drawSymbol("basket.fill", in: NSRect(x: rect.maxX - rect.width * 0.2, y: rect.maxY - rect.height * 0.42, width: 40, height: 40), color: color(255, 224, 150))
    }

    private static func drawCreate(_ rect: NSRect) {
        fillVerticalGradient(rect, top: color(150, 96, 180), bottom: color(96, 58, 138))
        // A framed canvas being conjured.
        let frame = NSRect(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.24, width: rect.width * 0.42, height: rect.height * 0.5)
        let framePath = NSBezierPath(roundedRect: frame, xRadius: 8, yRadius: 8)
        fillVerticalGradient(frame, top: color(120, 196, 168), bottom: color(74, 150, 132))
        NSColor.white.withAlphaComponent(0.85).setStroke()
        framePath.lineWidth = 2
        framePath.stroke()
        drawPlant(baseX: frame.minX + frame.width * 0.5, baseY: frame.minY + 8, scale: 0.7, leaf: color(190, 230, 170), bloom: color(255, 200, 120))
        // Sparkle wand + stars.
        drawSymbol("wand.and.stars", in: NSRect(x: rect.maxX - rect.width * 0.34, y: rect.midY - 4, width: 52, height: 52), color: color(255, 226, 150))
        for (sx, sy, s) in [(0.7, 0.72, 10.0), (0.82, 0.5, 7.0), (0.64, 0.4, 6.0)] {
            drawSymbol("sparkle", in: NSRect(x: rect.minX + rect.width * sx, y: rect.minY + rect.height * sy, width: s, height: s), color: .white)
        }
    }

    private static func drawWorlds(_ rect: NSRect) {
        // Split: cozy room (left) / alien dome (right).
        let left = NSRect(x: rect.minX, y: rect.minY, width: rect.width * 0.5, height: rect.height)
        let right = NSRect(x: rect.midX, y: rect.minY, width: rect.width * 0.5, height: rect.height)
        fillVerticalGradient(left, top: color(206, 150, 120), bottom: color(150, 100, 86))
        fillVerticalGradient(right, top: color(70, 96, 168), bottom: color(40, 54, 110))
        // Room: bed + lamp.
        let floorY = rect.minY + rect.height * 0.2
        color(120, 80, 66).setFill()
        NSBezierPath(rect: NSRect(x: left.minX, y: left.minY, width: left.width, height: rect.height * 0.2)).fill()
        let bed = NSRect(x: left.minX + left.width * 0.16, y: floorY, width: left.width * 0.5, height: rect.height * 0.24)
        color(236, 222, 210).setFill()
        NSBezierPath(roundedRect: bed, xRadius: 5, yRadius: 5).fill()
        color(232, 170, 120).setFill()
        NSBezierPath(roundedRect: NSRect(x: bed.minX, y: bed.minY, width: bed.width * 0.28, height: bed.height), xRadius: 5, yRadius: 5).fill()
        drawSymbol("lamp.desk.fill", in: NSRect(x: left.maxX - 44, y: floorY, width: 30, height: 40), color: color(255, 224, 168))
        // Alien dome.
        let domeC = NSPoint(x: right.midX, y: floorY + 6)
        let dome = NSBezierPath()
        dome.appendArc(withCenter: domeC, radius: right.width * 0.34, startAngle: 0, endAngle: 180)
        color(150, 224, 210, 0.45).setFill()
        dome.fill()
        NSColor.white.withAlphaComponent(0.6).setStroke()
        dome.lineWidth = 1.5
        dome.stroke()
        drawPlant(baseX: domeC.x, baseY: floorY, scale: 0.7, leaf: color(150, 230, 200), bloom: color(120, 220, 255))
        drawSymbol("sparkles", in: NSRect(x: right.midX - 8, y: rect.maxY - rect.height * 0.34, width: 22, height: 22), color: .white)
    }

    private static func drawCompanions(_ rect: NSRect) {
        fillVerticalGradient(rect, top: color(244, 168, 96), bottom: color(196, 110, 76))
        softGround(rect, height: rect.height * 0.34, color: color(150, 96, 70))
        let groundY = rect.minY + rect.height * 0.18
        // Cat silhouette watching a cursor.
        let cat = NSPoint(x: rect.minX + rect.width * 0.26, y: groundY)
        let body = NSBezierPath(ovalIn: NSRect(x: cat.x - 26, y: cat.y, width: 52, height: 36))
        color(54, 46, 60).setFill()
        body.fill()
        let head = NSBezierPath(ovalIn: NSRect(x: cat.x + 6, y: cat.y + 20, width: 28, height: 26))
        head.fill()
        let ear = NSBezierPath()
        ear.move(to: NSPoint(x: cat.x + 10, y: cat.y + 42))
        ear.line(to: NSPoint(x: cat.x + 14, y: cat.y + 54))
        ear.line(to: NSPoint(x: cat.x + 20, y: cat.y + 44))
        ear.close()
        ear.fill()
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: cat.x - 24, y: cat.y + 6))
        tail.curve(to: NSPoint(x: cat.x - 40, y: cat.y + 30), controlPoint1: NSPoint(x: cat.x - 40, y: cat.y), controlPoint2: NSPoint(x: cat.x - 44, y: cat.y + 18))
        tail.lineWidth = 6
        color(54, 46, 60).setStroke()
        tail.stroke()
        drawCursor(at: NSPoint(x: cat.x + 56, y: cat.y + 40), scale: 0.9)
        // Tiny gnome.
        let gnome = NSPoint(x: rect.minX + rect.width * 0.62, y: groundY)
        let robe = NSBezierPath()
        robe.move(to: NSPoint(x: gnome.x - 9, y: gnome.y))
        robe.line(to: NSPoint(x: gnome.x + 9, y: gnome.y))
        robe.line(to: NSPoint(x: gnome.x, y: gnome.y + 22))
        robe.close()
        color(96, 150, 210).setFill()
        robe.fill()
        let hat = NSBezierPath()
        hat.move(to: NSPoint(x: gnome.x - 8, y: gnome.y + 22))
        hat.line(to: NSPoint(x: gnome.x + 8, y: gnome.y + 22))
        hat.line(to: NSPoint(x: gnome.x, y: gnome.y + 42))
        hat.close()
        color(214, 92, 88).setFill()
        hat.fill()
        NSColor(srgbRed: 0.98, green: 0.9, blue: 0.82, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: gnome.x - 5, y: gnome.y + 18, width: 10, height: 9)).fill()
        // Birds.
        for (bx, by) in [(0.8, 0.78), (0.86, 0.68), (0.74, 0.72)] {
            let bird = NSBezierPath()
            let px = rect.minX + rect.width * CGFloat(bx)
            let py = rect.minY + rect.height * CGFloat(by)
            bird.move(to: NSPoint(x: px - 7, y: py))
            bird.curve(to: NSPoint(x: px, y: py + 3), controlPoint1: NSPoint(x: px - 4, y: py + 5), controlPoint2: NSPoint(x: px - 2, y: py + 5))
            bird.curve(to: NSPoint(x: px + 7, y: py), controlPoint1: NSPoint(x: px + 2, y: py + 5), controlPoint2: NSPoint(x: px + 4, y: py + 5))
            NSColor.white.withAlphaComponent(0.9).setStroke()
            bird.lineWidth = 1.8
            bird.stroke()
        }
    }

    private static func drawLivingWorld(_ rect: NSRect) {
        // Day → night split sky.
        let dayRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width * 0.55, height: rect.height)
        let nightRect = NSRect(x: rect.minX + rect.width * 0.55, y: rect.minY, width: rect.width * 0.45, height: rect.height)
        fillVerticalGradient(dayRect, top: color(120, 196, 244), bottom: color(180, 224, 236))
        fillVerticalGradient(nightRect, top: color(40, 44, 92), bottom: color(64, 60, 110))
        // Sun.
        drawSymbol("sun.max.fill", in: NSRect(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.height * 0.4, width: 40, height: 40), color: color(255, 214, 102))
        // Moon + stars.
        drawSymbol("moon.stars.fill", in: NSRect(x: rect.maxX - rect.width * 0.2, y: rect.maxY - rect.height * 0.42, width: 38, height: 38), color: color(228, 230, 255))
        // Rain streaks over the day side.
        color(255, 255, 255, 0.5).setStroke()
        for i in 0..<6 {
            let rx = dayRect.minX + dayRect.width * (0.28 + CGFloat(i) * 0.09)
            let streak = NSBezierPath()
            streak.move(to: NSPoint(x: rx, y: rect.minY + rect.height * 0.5))
            streak.line(to: NSPoint(x: rx - 4, y: rect.minY + rect.height * 0.34))
            streak.lineWidth = 1.6
            streak.stroke()
        }
        // Rainbow arc straddling the seam.
        let colors = [color(244, 120, 120), color(244, 188, 96), color(150, 214, 130), color(110, 170, 240)]
        for (i, c) in colors.enumerated() {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.16), radius: rect.width * 0.2 - CGFloat(i) * 6, startAngle: 20, endAngle: 160)
            c.withAlphaComponent(0.85).setStroke()
            arc.lineWidth = 5
            arc.stroke()
        }
        softGround(rect, height: rect.height * 0.2, color: color(70, 120, 84))
        drawPlant(baseX: rect.minX + rect.width * 0.3, baseY: rect.minY + rect.height * 0.1, scale: 0.8, leaf: color(150, 205, 138), bloom: color(255, 209, 102))
    }

    private static func drawControlCenter(_ rect: NSRect) {
        fillVerticalGradient(rect, top: color(96, 110, 150), bottom: color(56, 64, 104))
        // A settings panel with toggles and sliders.
        let panel = rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.16)
        color(248, 248, 250, 0.96).setFill()
        let panelPath = NSBezierPath(roundedRect: panel, xRadius: 12, yRadius: 12)
        panelPath.fill()
        let rowH = panel.height / 4.0
        // Two toggle rows.
        for (i, on) in [true, false].enumerated() {
            let y = panel.maxY - rowH * CGFloat(i + 1) + rowH * 0.3
            color(60, 64, 74).setFill()
            NSBezierPath(roundedRect: NSRect(x: panel.minX + 16, y: y + 2, width: panel.width * 0.4, height: 8), xRadius: 4, yRadius: 4).fill()
            let track = NSRect(x: panel.maxX - 56, y: y - 1, width: 40, height: 18)
            (on ? color(72, 190, 130) : color(196, 200, 208)).setFill()
            NSBezierPath(roundedRect: track, xRadius: 9, yRadius: 9).fill()
            NSColor.white.setFill()
            let knobX = on ? track.maxX - 16 : track.minX + 2
            NSBezierPath(ovalIn: NSRect(x: knobX, y: track.minY + 2, width: 14, height: 14)).fill()
        }
        // Two slider rows.
        for i in 0..<2 {
            let y = panel.minY + rowH * CGFloat(i) + rowH * 0.45
            color(214, 218, 226).setFill()
            NSBezierPath(roundedRect: NSRect(x: panel.minX + 16, y: y, width: panel.width - 32, height: 6), xRadius: 3, yRadius: 3).fill()
            let frac: CGFloat = i == 0 ? 0.62 : 0.4
            color(96, 140, 226).setFill()
            NSBezierPath(roundedRect: NSRect(x: panel.minX + 16, y: y, width: (panel.width - 32) * frac, height: 6), xRadius: 3, yRadius: 3).fill()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: panel.minX + 16 + (panel.width - 32) * frac - 7, y: y - 5, width: 16, height: 16)).fill()
            color(150, 154, 164).setStroke()
            let knob = NSBezierPath(ovalIn: NSRect(x: panel.minX + 16 + (panel.width - 32) * frac - 7, y: y - 5, width: 16, height: 16))
            knob.lineWidth = 1
            knob.stroke()
        }
    }
}
