import AppKit

/// In-scene UI for the gnome perspective-adjustment mode: a minimalist rotate
/// gizmo over each user-drawn gnome area (brightening on hover) plus a floating
/// "Done" button so the user can leave the mode without reopening the menu.
extension GardenCanvasView {
    private enum PerspectiveOverlayMetrics {
        static let doneSize = NSSize(width: 128, height: 38)
        static let doneTopInset: CGFloat = 86
        static let gizmoRadius: CGFloat = 24
        static let gizmoHoverRadius: CGFloat = 30
        static let zoneHoverSlop: CGFloat = 14
    }

    /// Centroid + hit radius (view coordinates) of each saved gnome area on this
    /// screen, paired with its index in the filtered list.
    func gnomePerspectiveZoneTargets() -> [(index: Int, center: NSPoint, radius: CGFloat)] {
        let zones = store.state.gnomeTribeZones.filter { $0.screenIndex == screenIndex }
        var targets: [(index: Int, center: NSPoint, radius: CGFloat)] = []
        for (index, zone) in zones.enumerated() {
            let points = zone.points.map { point in
                NSPoint(x: bounds.width * CGFloat(point.x), y: bounds.height * CGFloat(point.y))
            }
            guard !points.isEmpty else { continue }
            var minX = points[0].x, maxX = points[0].x, minY = points[0].y, maxY = points[0].y
            for p in points {
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
            let center = NSPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
            let radius = min(max(min(maxX - minX, maxY - minY) * 0.3, 22), 44)
            targets.append((index, center, radius))
        }
        return targets
    }

    func gnomePerspectiveDoneButtonRect() -> NSRect {
        let size = PerspectiveOverlayMetrics.doneSize
        return NSRect(
            x: (bounds.width - size.width) / 2,
            y: bounds.height - PerspectiveOverlayMetrics.doneTopInset - size.height,
            width: size.width,
            height: size.height
        )
    }

    func gnomePerspectiveDoneButtonContains(_ viewPoint: NSPoint) -> Bool {
        guard isGnomePerspectiveAdjustmentMode else { return false }
        return gnomePerspectiveDoneButtonRect().insetBy(dx: -6, dy: -6).contains(viewPoint)
    }

    func updatePerspectiveHover(at candidatePoints: [NSPoint]) {
        guard isGnomePerspectiveAdjustmentMode else {
            clearPerspectiveHover()
            return
        }

        var doneHovered = false
        var zoneIndex: Int?
        let doneRect = gnomePerspectiveDoneButtonRect().insetBy(dx: -6, dy: -6)
        let targets = gnomePerspectiveZoneTargets()
        for point in candidatePoints {
            if doneRect.contains(point) { doneHovered = true; break }
            for target in targets {
                let slop = target.radius + PerspectiveOverlayMetrics.zoneHoverSlop
                if hypot(point.x - target.center.x, point.y - target.center.y) <= slop {
                    zoneIndex = target.index
                    break
                }
            }
            if zoneIndex != nil { break }
        }

        if doneHovered != isPerspectiveDoneButtonHovered || zoneIndex != hoveredPerspectiveZoneIndex {
            isPerspectiveDoneButtonHovered = doneHovered
            hoveredPerspectiveZoneIndex = zoneIndex
            needsDisplay = true
        }
    }

    func clearPerspectiveHover() {
        guard hoveredPerspectiveZoneIndex != nil || isPerspectiveDoneButtonHovered else { return }
        hoveredPerspectiveZoneIndex = nil
        isPerspectiveDoneButtonHovered = false
        needsDisplay = true
    }

    func drawGnomePerspectiveOverlayIfNeeded() {
        guard isGnomePerspectiveAdjustmentMode else { return }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        for target in gnomePerspectiveZoneTargets() {
            drawPerspectiveGizmo(
                at: target.center,
                hovered: target.index == hoveredPerspectiveZoneIndex
            )
        }
        drawPerspectiveDoneButton()
    }

    private func drawPerspectiveGizmo(at center: NSPoint, hovered: Bool) {
        let radius = hovered ? PerspectiveOverlayMetrics.gizmoHoverRadius : PerspectiveOverlayMetrics.gizmoRadius
        let alpha: CGFloat = hovered ? 0.95 : 0.5
        let tint = NSColor.systemGreen.withAlphaComponent(alpha)

        // orbit ring
        let ring = NSBezierPath(ovalIn: NSRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
        ring.lineWidth = hovered ? 2.4 : 1.6
        tint.setStroke()
        ring.stroke()

        // two opposing rotation arcs with arrowheads, suggesting "spin to aim"
        NSColor.white.withAlphaComponent(alpha).setStroke()
        for flip in [CGFloat(1), CGFloat(-1)] {
            let arc = NSBezierPath()
            arc.appendArc(
                withCenter: center,
                radius: radius + 4,
                startAngle: flip > 0 ? 20 : 200,
                endAngle: flip > 0 ? 120 : 300
            )
            arc.lineWidth = hovered ? 2.4 : 1.6
            arc.stroke()
            let tipAngle = (flip > 0 ? 120.0 : 300.0) * .pi / 180
            let tip = NSPoint(
                x: center.x + cos(tipAngle) * (radius + 4),
                y: center.y + sin(tipAngle) * (radius + 4)
            )
            drawArrowhead(at: tip, angle: tipAngle + .pi / 2, size: hovered ? 6 : 4.5,
                          color: NSColor.white.withAlphaComponent(alpha))
        }

        // center dot
        let dotR: CGFloat = hovered ? 3.2 : 2.4
        let dot = NSBezierPath(ovalIn: NSRect(
            x: center.x - dotR, y: center.y - dotR, width: dotR * 2, height: dotR * 2
        ))
        tint.setFill()
        dot.fill()

        if hovered {
            drawCenteredLabel(
                "Drag to tilt",
                at: NSPoint(x: center.x, y: center.y - radius - 14),
                fontSize: 11,
                color: .white,
                background: NSColor.black.withAlphaComponent(0.5)
            )
        }
    }

    private func drawPerspectiveDoneButton() {
        let rect = gnomePerspectiveDoneButtonRect()
        let hovered = isPerspectiveDoneButtonHovered
        let fill = (hovered ? NSColor.systemGreen : NSColor.black).withAlphaComponent(hovered ? 0.92 : 0.62)
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        fill.setFill()
        path.fill()
        NSColor.white.withAlphaComponent(hovered ? 0.95 : 0.6).setStroke()
        path.lineWidth = 1.2
        path.stroke()

        let title = NSAttributedString(string: "✓  Done", attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.white
        ])
        let size = title.size()
        title.draw(at: NSPoint(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2
        ))
    }

    private func drawArrowhead(at point: NSPoint, angle: CGFloat, size: CGFloat, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: point)
        path.line(to: NSPoint(
            x: point.x + cos(angle + 2.5) * size,
            y: point.y + sin(angle + 2.5) * size
        ))
        path.line(to: NSPoint(
            x: point.x + cos(angle - 2.5) * size,
            y: point.y + sin(angle - 2.5) * size
        ))
        path.close()
        color.setFill()
        path.fill()
    }

    private func drawCenteredLabel(
        _ text: String,
        at center: NSPoint,
        fontSize: CGFloat,
        color: NSColor,
        background: NSColor
    ) {
        let attributed = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: color
        ])
        let size = attributed.size()
        let pad: CGFloat = 6
        let box = NSRect(
            x: center.x - size.width / 2 - pad,
            y: center.y - size.height / 2 - pad / 2,
            width: size.width + pad * 2,
            height: size.height + pad
        )
        let bg = NSBezierPath(roundedRect: box, xRadius: 5, yRadius: 5)
        background.setFill()
        bg.fill()
        attributed.draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
    }
}
