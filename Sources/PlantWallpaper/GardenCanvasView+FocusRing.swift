import AppKit
import PlantGardenCore

/// The ambient on-desktop focus timer: a quiet progress ring in the lower
/// right of the primary garden while a session is running, so the payoff
/// mechanic (focused work grows the garden faster) is visible at a glance.
extension GardenCanvasView {
    func drawFocusSessionRingIfNeeded() {
        guard screenIndex == 0,
              let session = store.state.focusSession,
              session.isActive() else {
            return
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(session.startedAt)
        let completedFraction = CGFloat(min(1, max(0, elapsed / session.duration)))

        let diameter: CGFloat = 64
        let margin: CGFloat = 26
        let viewport = inspectorViewportRect()
        let rect = NSRect(
            x: viewport.maxX - diameter - margin + 12,
            y: viewport.maxY - diameter - margin + 12,
            width: diameter,
            height: diameter
        )
        let center = NSPoint(x: rect.midX, y: rect.midY)

        // Soft backing disc.
        let disc = NSBezierPath(ovalIn: rect.insetBy(dx: -9, dy: -9))
        color(red: 36, green: 48, blue: 33, alpha: 0.38).setFill()
        disc.fill()

        // Track ring.
        let track = NSBezierPath(ovalIn: rect)
        track.lineWidth = 4.5
        color(red: 235, green: 240, blue: 220, alpha: 0.30).setStroke()
        track.stroke()

        // Progress arc from 12 o'clock, sweeping screen-clockwise. The view
        // is flipped, so increasing coordinate angles read as clockwise and
        // 270° is the visual top.
        let progressPath = NSBezierPath()
        let startAngle: CGFloat = 270
        progressPath.appendArc(
            withCenter: center,
            radius: diameter / 2,
            startAngle: startAngle,
            endAngle: startAngle + 360 * completedFraction,
            clockwise: false
        )
        progressPath.lineWidth = 4.5
        progressPath.lineCapStyle = .round
        color(red: 168, green: 214, blue: 120, alpha: 0.92).setStroke()
        progressPath.stroke()

        // Remaining time + growth boost badge.
        let remaining = session.remainingSummary(at: now)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: color(red: 244, green: 248, blue: 234, alpha: 0.95)
        ]
        let textSize = (remaining as NSString).size(withAttributes: attributes)
        (remaining as NSString).draw(
            at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2),
            withAttributes: attributes
        )

        let boostText = "×\(String(format: "%.1f", GardenFocusSession.growthBoost)) growth"
        let boostAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: color(red: 214, green: 232, blue: 186, alpha: 0.85)
        ]
        let boostSize = (boostText as NSString).size(withAttributes: boostAttributes)
        (boostText as NSString).draw(
            at: NSPoint(x: center.x - boostSize.width / 2, y: rect.maxY + 7),
            withAttributes: boostAttributes
        )
    }
}
