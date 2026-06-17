import AppKit
import PlantGardenCore

/// Ambient wildlife: butterflies, bees, hoverflies, and fireflies that
/// drift through the garden, plus their wing, leg, and shadow detailing.
extension GardenCanvasView {
    func drawAmbientWildlife(profile: GardenSceneVisualProfile, plants: [Plant]) {
        let wildlifeDensity = profile.wildlifeDensity * store.state.settings.wildlifeDensityMultiplier
        let pollinatorCount = GardenWildlifeMotion.pollinatorCount(
            floweringPlantCount: plants.filter { $0.bloomProgress > 0.28 && !$0.isDead }.count,
            wildlifeDensity: wildlifeDensity,
            hasPlants: !plants.isEmpty,
            isEnabled: store.state.isEffectiveAmbientWildlifeEnabled
        )
        guard pollinatorCount > 0 else {
            return
        }

        let floweringPlants = plants.filter { $0.bloomProgress > 0.28 && !$0.isDead }
        let now = Date().timeIntervalSinceReferenceDate * store.state.settings.wildlifeSpeedMultiplier
        let isNight = store.state.sunlightCondition().mood == .night
        for index in 0..<pollinatorCount {
            let host: Plant
            if floweringPlants.isEmpty {
                host = plants[index % plants.count]
            } else {
                host = floweringPlants[index % floweringPlants.count]
            }
            let anchor = anchorPoint(for: host)
            let hostHeight = realisticHeight(for: host, baseHeight: height(for: host))
            let sample = GardenWildlifeMotion.sample(
                index: index,
                time: now,
                wildlifeDensity: wildlifeDensity,
                hostHeight: Double(hostHeight),
                isNight: isNight
            )
            let center = NSPoint(
                x: anchor.x + CGFloat(sample.offset.x),
                y: anchor.y - hostHeight * CGFloat(sample.altitudeFraction) + CGFloat(sample.offset.y)
            )
            drawWildlife(sample, at: center, profile: profile)
        }
    }

    func drawWildlife(_ sample: GardenWildlifeSample, at center: NSPoint, profile: GardenSceneVisualProfile) {
        switch sample.kind {
        case .butterfly:
            drawButterfly(sample, at: center, profile: profile)
        case .bee:
            drawBee(sample, at: center, profile: profile)
        case .hoverfly:
            drawHoverfly(sample, at: center, profile: profile)
        case .firefly:
            drawFirefly(sample, at: center)
        }
    }

    func drawButterfly(_ sample: GardenWildlifeSample, at center: NSPoint, profile: GardenSceneVisualProfile) {
        let scale = CGFloat(sample.scale) * 2.10
        let heading = CGFloat(sample.headingDegrees)
        let wingOpen = CGFloat(sample.wingOpen)
        let wingAlpha = CGFloat(0.46 + min(0.22, profile.wildlifeDensity * 0.18))
        let wingFillA = color(
            red: 220,
            green: 170 + CGFloat(profile.warmth) * 24,
            blue: 92,
            alpha: wingAlpha
        )
        let wingFillB = color(red: 255, green: 221, blue: 142, alpha: wingAlpha * 0.82)
        let bodyColor = color(red: 48, green: 32, blue: 23, alpha: 0.76)
        let veinColor = color(red: 52, green: 35, blue: 26, alpha: 0.22)
        let wingWidth = (4.5 + wingOpen * 4.4) * scale
        let wingHeight = (2.2 + wingOpen * 1.8) * scale
        let wingSpread = (1.7 + wingOpen * 1.22) * scale

        drawInsectShadow(center: center, scale: scale, width: 12, height: 4.4, headingDegrees: heading, alpha: 0.13)

        drawInsectOval(
            center: orientedPoint(center, dx: -0.45 * scale, dy: -wingSpread * 0.78, headingDegrees: heading),
            size: NSSize(width: wingWidth * 0.68, height: wingHeight * 0.72),
            angle: heading - 50 - wingOpen * 10,
            fill: wingFillB,
            stroke: veinColor.withAlphaComponent(0.20)
        )
        drawInsectOval(
            center: orientedPoint(center, dx: -0.45 * scale, dy: wingSpread * 0.78, headingDegrees: heading),
            size: NSSize(width: wingWidth * 0.68, height: wingHeight * 0.72),
            angle: heading + 50 + wingOpen * 10,
            fill: wingFillB,
            stroke: veinColor.withAlphaComponent(0.20)
        )
        drawInsectOval(
            center: orientedPoint(center, dx: 0.28 * scale, dy: -wingSpread, headingDegrees: heading),
            size: NSSize(width: wingWidth, height: wingHeight),
            angle: heading - 32 - wingOpen * 12,
            fill: wingFillA,
            stroke: veinColor
        )
        drawInsectOval(
            center: orientedPoint(center, dx: 0.28 * scale, dy: wingSpread, headingDegrees: heading),
            size: NSSize(width: wingWidth, height: wingHeight),
            angle: heading + 32 + wingOpen * 12,
            fill: wingFillA,
            stroke: veinColor
        )

        drawButterflyWingDetails(center: center, wingSpread: wingSpread, wingOpen: wingOpen, scale: scale, heading: heading, veinColor: veinColor)

        drawLine(
            from: orientedPoint(center, dx: -2.1 * scale, dy: 0, headingDegrees: heading),
            to: orientedPoint(center, dx: 2.25 * scale, dy: 0, headingDegrees: heading),
            color: bodyColor,
            width: max(0.7, 0.88 * scale)
        )
        drawInsectOval(
            center: orientedPoint(center, dx: 0.1 * scale, dy: 0, headingDegrees: heading),
            size: NSSize(width: 2.3 * scale, height: 1.05 * scale),
            angle: heading,
            fill: color(red: 75, green: 50, blue: 32, alpha: 0.78),
            stroke: bodyColor.withAlphaComponent(0.42)
        )
        drawInsectOval(
            center: orientedPoint(center, dx: 2.34 * scale, dy: 0, headingDegrees: heading),
            size: NSSize(width: 0.92 * scale, height: 0.78 * scale),
            angle: heading,
            fill: color(red: 32, green: 24, blue: 20, alpha: 0.72),
            stroke: nil
        )
        for segment in [CGFloat(-1.25), CGFloat(-0.45), CGFloat(0.38), CGFloat(1.12)] {
            drawLine(
                from: orientedPoint(center, dx: segment * scale, dy: -0.42 * scale, headingDegrees: heading),
                to: orientedPoint(center, dx: segment * scale, dy: 0.42 * scale, headingDegrees: heading),
                color: color(red: 22, green: 17, blue: 13, alpha: 0.22),
                width: max(0.24, 0.23 * scale)
            )
        }
        drawLine(
            from: orientedPoint(center, dx: 2.35 * scale, dy: -0.20 * scale, headingDegrees: heading),
            to: orientedPoint(center, dx: 3.18 * scale, dy: -0.86 * scale, headingDegrees: heading),
            color: bodyColor.withAlphaComponent(0.42),
            width: max(0.25, 0.22 * scale)
        )
        drawLine(
            from: orientedPoint(center, dx: 2.35 * scale, dy: 0.20 * scale, headingDegrees: heading),
            to: orientedPoint(center, dx: 3.18 * scale, dy: 0.86 * scale, headingDegrees: heading),
            color: bodyColor.withAlphaComponent(0.42),
            width: max(0.25, 0.22 * scale)
        )
    }

    func drawBee(_ sample: GardenWildlifeSample, at center: NSPoint, profile: GardenSceneVisualProfile) {
        let scale = CGFloat(sample.scale) * 2.05
        let heading = CGFloat(sample.headingDegrees)
        let blurAlpha = CGFloat(0.28 + sample.wingBlur * 0.18)
        let bodyFill = color(red: 196, green: 142, blue: 38, alpha: 0.78)
        let bodyStroke = color(red: 39, green: 30, blue: 20, alpha: 0.62)
        let wingFill = color(red: 236, green: 250, blue: 238, alpha: blurAlpha)

        drawInsectShadow(center: center, scale: scale, width: 8.8, height: 3.5, headingDegrees: heading, alpha: 0.12)

        drawInsectOval(
            center: orientedPoint(center, dx: -0.18 * scale, dy: -1.20 * scale, headingDegrees: heading),
            size: NSSize(width: 4.15 * scale, height: 1.55 * scale),
            angle: heading - 18,
            fill: wingFill,
            stroke: color(red: 208, green: 234, blue: 220, alpha: blurAlpha * 0.60)
        )
        drawInsectOval(
            center: orientedPoint(center, dx: -0.18 * scale, dy: 1.20 * scale, headingDegrees: heading),
            size: NSSize(width: 4.15 * scale, height: 1.55 * scale),
            angle: heading + 18,
            fill: wingFill,
            stroke: color(red: 208, green: 234, blue: 220, alpha: blurAlpha * 0.60)
        )
        drawFlyWingVeins(center: center, scale: scale, heading: heading, side: -1, color: bodyStroke.withAlphaComponent(0.20))
        drawFlyWingVeins(center: center, scale: scale, heading: heading, side: 1, color: bodyStroke.withAlphaComponent(0.20))

        drawInsectOval(
            center: orientedPoint(center, dx: -1.55 * scale, dy: 0, headingDegrees: heading),
            size: NSSize(width: 2.25 * scale, height: 1.72 * scale),
            angle: heading,
            fill: color(red: 74, green: 52, blue: 29, alpha: 0.76),
            stroke: bodyStroke.withAlphaComponent(0.34)
        )
        drawInsectOval(
            center: center,
            size: NSSize(width: 4.45 * scale, height: 2.05 * scale),
            angle: heading,
            fill: bodyFill,
            stroke: bodyStroke
        )
        drawInsectOval(
            center: orientedPoint(center, dx: 2.18 * scale, dy: 0, headingDegrees: heading),
            size: NSSize(width: 1.05 * scale, height: 0.92 * scale),
            angle: heading,
            fill: color(red: 35, green: 27, blue: 20, alpha: 0.72),
            stroke: nil
        )
        for stripe in [CGFloat(-0.95), CGFloat(-0.18), CGFloat(0.62), CGFloat(1.28)] {
            drawLine(
                from: orientedPoint(center, dx: stripe * scale, dy: -0.86 * scale, headingDegrees: heading),
                to: orientedPoint(center, dx: stripe * scale, dy: 0.86 * scale, headingDegrees: heading),
                color: bodyStroke.withAlphaComponent(0.54),
                width: max(0.34, 0.34 * scale)
            )
        }
        drawInsectLegs(center: center, scale: scale, heading: heading, color: bodyStroke.withAlphaComponent(0.52))
        drawLine(
            from: orientedPoint(center, dx: -0.85 * scale, dy: -0.18 * scale, headingDegrees: heading),
            to: orientedPoint(center, dx: 1.55 * scale, dy: -0.38 * scale, headingDegrees: heading),
            color: color(red: 255, green: 223, blue: 108, alpha: 0.28),
            width: max(0.24, 0.22 * scale)
        )
    }

    func drawHoverfly(_ sample: GardenWildlifeSample, at center: NSPoint, profile: GardenSceneVisualProfile) {
        let scale = CGFloat(sample.scale) * 2.20
        let heading = CGFloat(sample.headingDegrees)
        let blurAlpha = CGFloat(0.26 + sample.wingBlur * 0.18)
        let bodyFill = color(red: 126 + CGFloat(profile.warmth) * 18, green: 91, blue: 38, alpha: 0.68)
        let wingFill = color(red: 232, green: 250, blue: 236, alpha: blurAlpha)

        drawInsectShadow(center: center, scale: scale, width: 7.6, height: 3.1, headingDegrees: heading, alpha: 0.12)

        drawInsectOval(
            center: orientedPoint(center, dx: -0.28 * scale, dy: -1.02 * scale, headingDegrees: heading),
            size: NSSize(width: 3.65 * scale, height: 1.15 * scale),
            angle: heading - 20,
            fill: wingFill,
            stroke: color(red: 204, green: 234, blue: 220, alpha: blurAlpha * 0.58)
        )
        drawInsectOval(
            center: orientedPoint(center, dx: -0.28 * scale, dy: 1.02 * scale, headingDegrees: heading),
            size: NSSize(width: 3.65 * scale, height: 1.15 * scale),
            angle: heading + 20,
            fill: wingFill,
            stroke: color(red: 204, green: 234, blue: 220, alpha: blurAlpha * 0.58)
        )
        drawFlyWingVeins(center: center, scale: scale * 0.86, heading: heading, side: -1, color: bodyFill.withAlphaComponent(0.22))
        drawFlyWingVeins(center: center, scale: scale * 0.86, heading: heading, side: 1, color: bodyFill.withAlphaComponent(0.22))

        drawInsectOval(
            center: orientedPoint(center, dx: -1.55 * scale, dy: 0, headingDegrees: heading),
            size: NSSize(width: 1.95 * scale, height: 1.18 * scale),
            angle: heading,
            fill: color(red: 44, green: 33, blue: 20, alpha: 0.58),
            stroke: nil
        )
        drawLine(
            from: orientedPoint(center, dx: -1.7 * scale, dy: 0, headingDegrees: heading),
            to: orientedPoint(center, dx: 1.8 * scale, dy: 0, headingDegrees: heading),
            color: bodyFill,
            width: max(0.58, 0.86 * scale)
        )
        for stripe in [CGFloat(-0.72), CGFloat(0.12), CGFloat(0.88)] {
            drawLine(
                from: orientedPoint(center, dx: stripe * scale, dy: -0.50 * scale, headingDegrees: heading),
                to: orientedPoint(center, dx: stripe * scale, dy: 0.50 * scale, headingDegrees: heading),
                color: color(red: 232, green: 174, blue: 58, alpha: 0.48),
                width: max(0.28, 0.28 * scale)
            )
        }
        drawInsectOval(
            center: orientedPoint(center, dx: 1.78 * scale, dy: -0.28 * scale, headingDegrees: heading),
            size: NSSize(width: 0.86 * scale, height: 0.76 * scale),
            angle: heading,
            fill: color(red: 88, green: 42, blue: 30, alpha: 0.60),
            stroke: nil
        )
        drawInsectOval(
            center: orientedPoint(center, dx: 1.78 * scale, dy: 0.28 * scale, headingDegrees: heading),
            size: NSSize(width: 0.86 * scale, height: 0.76 * scale),
            angle: heading,
            fill: color(red: 88, green: 42, blue: 30, alpha: 0.60),
            stroke: nil
        )
        drawInsectLegs(center: center, scale: scale * 0.82, heading: heading, color: color(red: 35, green: 28, blue: 20, alpha: 0.42))
    }

    func drawFirefly(_ sample: GardenWildlifeSample, at center: NSPoint) {
        let scale = CGFloat(sample.scale) * 1.90
        let glow = CGFloat(sample.pulse)
        let radius = (4.6 + glow * 3.0) * scale
        let glowRect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        NSGradient(colors: [
            color(red: 224, green: 255, blue: 145, alpha: glow * 0.18),
            color(red: 224, green: 255, blue: 145, alpha: 0)
        ])?.draw(in: glowRect, relativeCenterPosition: .zero)
        let heading = CGFloat(sample.headingDegrees)
        drawInsectShadow(center: center, scale: scale, width: 6.5, height: 2.7, headingDegrees: heading, alpha: 0.10)
        drawInsectOval(
            center: orientedPoint(center, dx: -0.15 * scale, dy: -0.86 * scale, headingDegrees: heading),
            size: NSSize(width: 2.8 * scale, height: 0.96 * scale),
            angle: heading - 18,
            fill: color(red: 218, green: 239, blue: 196, alpha: 0.18),
            stroke: color(red: 180, green: 210, blue: 170, alpha: 0.10)
        )
        drawInsectOval(
            center: orientedPoint(center, dx: -0.15 * scale, dy: 0.86 * scale, headingDegrees: heading),
            size: NSSize(width: 2.8 * scale, height: 0.96 * scale),
            angle: heading + 18,
            fill: color(red: 218, green: 239, blue: 196, alpha: 0.18),
            stroke: color(red: 180, green: 210, blue: 170, alpha: 0.10)
        )
        drawLine(
            from: orientedPoint(center, dx: -1.65 * scale, dy: 0, headingDegrees: heading),
            to: orientedPoint(center, dx: 1.82 * scale, dy: 0, headingDegrees: heading),
            color: color(red: 50, green: 61, blue: 38, alpha: 0.48),
            width: max(0.44, 0.74 * scale)
        )
        drawInsectOval(
            center: orientedPoint(center, dx: 1.28 * scale, dy: 0, headingDegrees: heading),
            size: NSSize(width: 1.24 * scale, height: 0.90 * scale),
            angle: heading,
            fill: color(red: 224, green: 255, blue: 145, alpha: glow * 0.48),
            stroke: nil
        )
    }

    func drawButterflyWingDetails(
        center: NSPoint,
        wingSpread: CGFloat,
        wingOpen: CGFloat,
        scale: CGFloat,
        heading: CGFloat,
        veinColor: NSColor
    ) {
        for side in [CGFloat(-1), CGFloat(1)] {
            let socket = orientedPoint(center, dx: -0.18 * scale, dy: 0.36 * scale * side, headingDegrees: heading)
            let wingCenter = orientedPoint(center, dx: 0.28 * scale, dy: wingSpread * side, headingDegrees: heading)
            for rib in [CGFloat(-0.82), CGFloat(-0.30), CGFloat(0.22), CGFloat(0.74)] {
                let tip = orientedPoint(
                    wingCenter,
                    dx: (1.1 + wingOpen * 1.2) * scale,
                    dy: rib * 1.25 * scale * side,
                    headingDegrees: heading
                )
                drawLine(from: socket, to: tip, color: veinColor, width: max(0.18, 0.16 * scale))
            }

            drawInsectOval(
                center: orientedPoint(wingCenter, dx: 1.05 * scale, dy: -0.48 * scale * side, headingDegrees: heading),
                size: NSSize(width: 0.78 * scale, height: 0.36 * scale),
                angle: heading + 8 * side,
                fill: veinColor.withAlphaComponent(0.16),
                stroke: nil
            )
            drawInsectOval(
                center: orientedPoint(wingCenter, dx: -0.62 * scale, dy: 0.36 * scale * side, headingDegrees: heading),
                size: NSSize(width: 0.54 * scale, height: 0.26 * scale),
                angle: heading - 18 * side,
                fill: color(red: 255, green: 239, blue: 178, alpha: 0.20),
                stroke: nil
            )
        }
    }

    func drawFlyWingVeins(center: NSPoint, scale: CGFloat, heading: CGFloat, side: CGFloat, color: NSColor) {
        let root = orientedPoint(center, dx: -0.55 * scale, dy: 0.46 * scale * side, headingDegrees: heading)
        for rib in [CGFloat(-0.52), CGFloat(0), CGFloat(0.50)] {
            let tip = orientedPoint(
                center,
                dx: (0.98 + abs(rib) * 0.24) * scale,
                dy: (1.18 + rib) * scale * side,
                headingDegrees: heading
            )
            drawLine(from: root, to: tip, color: color, width: max(0.16, 0.14 * scale))
        }
    }

    func drawInsectLegs(center: NSPoint, scale: CGFloat, heading: CGFloat, color: NSColor) {
        for offset in [CGFloat(-0.92), CGFloat(-0.10), CGFloat(0.72)] {
            for side in [CGFloat(-1), CGFloat(1)] {
                let start = orientedPoint(center, dx: offset * scale, dy: 0.46 * scale * side, headingDegrees: heading)
                let knee = orientedPoint(center, dx: (offset - 0.18) * scale, dy: 1.00 * scale * side, headingDegrees: heading)
                let foot = orientedPoint(center, dx: (offset - 0.58) * scale, dy: 1.24 * scale * side, headingDegrees: heading)
                drawLine(from: start, to: knee, color: color, width: max(0.16, 0.14 * scale))
                drawLine(from: knee, to: foot, color: color.withAlphaComponent(0.70), width: max(0.14, 0.12 * scale))
            }
        }
    }

    func drawInsectShadow(
        center: NSPoint,
        scale: CGFloat,
        width: CGFloat,
        height: CGFloat,
        headingDegrees: CGFloat,
        alpha: CGFloat
    ) {
        drawOval(
            center: orientedPoint(center, dx: -0.22 * scale, dy: 1.8 * scale, headingDegrees: headingDegrees),
            size: NSSize(width: width * scale, height: height * scale),
            angle: headingDegrees,
            fill: color(red: 21, green: 24, blue: 18, alpha: alpha),
            stroke: nil
        )
    }

    func drawInsectOval(center: NSPoint, size: NSSize, angle: CGFloat, fill: NSColor, stroke: NSColor?) {
        drawOval(center: center, size: size, angle: angle, fill: fill, stroke: stroke)
    }

    func orientedPoint(
        _ center: NSPoint,
        dx: CGFloat,
        dy: CGFloat,
        headingDegrees: CGFloat
    ) -> NSPoint {
        let radians = headingDegrees * .pi / 180
        let cosValue = cos(radians)
        let sinValue = sin(radians)
        return NSPoint(
            x: center.x + dx * cosValue - dy * sinValue,
            y: center.y + dx * sinValue + dy * cosValue
        )
    }
}
