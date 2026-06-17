import AppKit
import PlantGardenCore

/// Rare ambient moments drawn over the garden. Rainbows are intentionally
/// handled by RainbowMomentController's Three.js light layer so they do not
/// look like flat vector art baked over the scene.
extension GardenCanvasView {
    func drawRareMomentOverlay(profile: GardenSceneVisualProfile) {
        guard store.state.settings.rareMomentsMode != .off else {
            return
        }
        guard let moment = GardenRareMoment.activeMoment(at: Date(), weather: store.state.weather) else {
            return
        }

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, moment.kind != .rainbow {
            return
        }

        switch moment.kind {
        case .fireflyNight:
            drawFireflySwarm(moment: moment)
        case .butterflyMigration:
            drawButterflyMigration(moment: moment, profile: profile)
        case .rainbow:
            return
        }
    }

    /// Eases in/out over the moment's window so it never pops.
    private func momentPresence(_ moment: GardenRareMoment) -> CGFloat {
        let fadeWindow = 0.12
        let fadeIn = min(1, moment.progress / fadeWindow)
        let fadeOut = min(1, (1 - moment.progress) / fadeWindow)
        return CGFloat(max(0, min(fadeIn, fadeOut)))
    }

    private func drawFireflySwarm(moment: GardenRareMoment) {
        let presence = momentPresence(moment)
        guard presence > 0.01, bounds.width > 0 else {
            return
        }

        let time = Date().timeIntervalSince1970
        let count = 26
        for index in 0..<count {
            let seed = Double(index) * 73.137
            let drift = time * (0.018 + 0.012 * fract(seed * 0.31))
            let x = bounds.width * CGFloat(fract(seed * 0.171 + drift * 0.13))
            let baseY = 0.30 + 0.55 * fract(seed * 0.39)
            let bob = sin(time * (0.5 + fract(seed) * 0.7) + seed) * 14
            let y = bounds.height * CGFloat(baseY) + CGFloat(bob)
            let pulse = 0.5 + 0.5 * sin(time * (1.1 + fract(seed * 0.7) * 1.4) + seed * 2)
            let glow = CGFloat(pulse) * presence

            guard glow > 0.06 else {
                continue
            }

            let radius = 1.6 + glow * 2.2
            let halo = NSBezierPath(ovalIn: NSRect(
                x: x - radius * 3,
                y: y - radius * 3,
                width: radius * 6,
                height: radius * 6
            ))
            color(red: 214, green: 255, blue: 140, alpha: 0.085 * glow).setFill()
            halo.fill()

            let body = NSBezierPath(ovalIn: NSRect(
                x: x - radius,
                y: y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            color(red: 226, green: 255, blue: 150, alpha: 0.85 * glow).setFill()
            body.fill()
        }
    }

    private func drawButterflyMigration(moment: GardenRareMoment, profile: GardenSceneVisualProfile) {
        let presence = momentPresence(moment)
        guard presence > 0.01, bounds.width > 0 else {
            return
        }

        let time = Date().timeIntervalSince1970
        let count = 9
        for index in 0..<count {
            let seed = Double(index) * 41.71
            // The flock crosses the full screen over the moment's window,
            // staggered so it reads as a stream rather than a line.
            let lag = fract(seed * 0.23) * 0.35
            let travel = (moment.progress * 1.5 - lag).truncatingRemainder(dividingBy: 1.2)
            guard travel > 0, travel < 1.2 else {
                continue
            }

            let x = bounds.width * CGFloat(travel - 0.1)
            let lane = 0.18 + 0.34 * fract(seed * 0.57)
            let bob = sin(time * 1.7 + seed) * 16 + sin(time * 0.6 + seed * 3) * 9
            let y = bounds.height * CGFloat(lane) + CGFloat(bob)
            let flutter = 0.5 + 0.5 * sin(time * 11 + seed * 5)

            let sample = GardenWildlifeSample(
                kind: .butterfly,
                offset: GardenPoint(x: 0, y: 0),
                altitudeFraction: 0.7,
                scale: (0.55 + fract(seed * 0.83) * 0.5) * Double(presence),
                headingDegrees: 8 + sin(time * 0.9 + seed) * 14,
                wingOpen: flutter,
                wingBlur: 0.25,
                pulse: flutter
            )
            drawButterfly(sample, at: NSPoint(x: x, y: y), profile: profile)
        }
    }

    private func fract(_ value: Double) -> Double {
        value - value.rounded(.down)
    }
}
