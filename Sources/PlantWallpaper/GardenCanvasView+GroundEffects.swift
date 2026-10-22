import AppKit
import PlantGardenCore

/// Ground integration: contact shadows, cast shadows, occlusion, ground
/// tint, ambient lift, and the selection ground ring.
extension GardenCanvasView {
    func opacity(for plant: Plant) -> CGFloat {
        if plant.isDead {
            let depthOpacity = 0.92 + plant.depthProfile.depth * 0.08
            return CGFloat(0.34 * depthOpacity)
        }

        let vitality = min(plant.health, plant.hydration)
        let depthOpacity = 0.92 + plant.depthProfile.depth * 0.08
        return CGFloat(min(1, (0.42 + vitality * 0.58) * depthOpacity))
    }

    func drawSceneDirectionalShadow(
        for plant: Plant,
        anchor: NSPoint,
        width: CGFloat,
        height: CGFloat,
        selected: Bool,
        projection: GardenLightProjection,
        profile: GardenSceneVisualProfile
    ) {
        let castShadow = plant.castShadow(projection: projection)
        guard castShadow.isVisible else {
            return
        }

        let depthScale = CGFloat(0.78 + plant.depthProfile.depth * 0.30)
        let length = max(18, width * CGFloat(castShadow.lengthMultiplier) * depthScale)
        let spread = max(12, width * CGFloat(castShadow.widthMultiplier) * (0.42 + CGFloat(profile.contactSoftness) * 0.20))
        let offset = NSPoint(
            x: width * CGFloat(castShadow.offsetXMultiplier),
            y: max(5, height * 0.020) + width * CGFloat(castShadow.offsetYMultiplier)
        )
        let direction = offset.x == 0 ? CGFloat(projection.shadowOffsetX >= 0 ? 1 : -1) : (offset.x > 0 ? 1 : -1)
        let base = NSPoint(x: anchor.x + offset.x * 0.28, y: anchor.y + offset.y * 0.22)
        let tip = NSPoint(x: base.x + direction * length, y: base.y + length * 0.18)

        for layer in 0..<4 {
            let fraction = CGFloat(layer) / 3
            let layerSpread = spread * (1.20 - fraction * 0.22)
            let layerAlpha = CGFloat(castShadow.opacity)
                * CGFloat(profile.shadowOpacityMultiplier)
                * (selected ? 1.14 : 1.0)
                * (0.11 + fraction * 0.045)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: base.x - layerSpread * 0.46, y: base.y - layerSpread * 0.10))
            path.curve(
                to: NSPoint(x: tip.x, y: tip.y),
                controlPoint1: NSPoint(x: base.x + direction * length * 0.26, y: base.y - layerSpread * 0.42),
                controlPoint2: NSPoint(x: base.x + direction * length * 0.70, y: base.y - layerSpread * 0.18)
            )
            path.curve(
                to: NSPoint(x: base.x + layerSpread * 0.48, y: base.y + layerSpread * 0.12),
                controlPoint1: NSPoint(x: base.x + direction * length * 0.68, y: base.y + layerSpread * 0.25),
                controlPoint2: NSPoint(x: base.x + direction * length * 0.22, y: base.y + layerSpread * 0.38)
            )
            path.close()
            color(red: 22, green: 25, blue: 18, alpha: min(0.18, layerAlpha)).setFill()
            path.fill()
        }

        let veinCount = min(7, max(3, castShadow.canopyLobeCount / 2))
        for index in 0..<veinCount {
            let wave = deterministicWave(seed: plant.swaySeed + 16_401, index: index)
            let start = NSPoint(
                x: base.x + wave * spread * 0.32,
                y: base.y + deterministicWave(seed: plant.swaySeed + 16_607, index: index) * spread * 0.12
            )
            let end = NSPoint(
                x: start.x + direction * length * CGFloat(0.28 + Double(index) / Double(max(1, veinCount)) * 0.42),
                y: start.y + spread * CGFloat(-0.10 + Double(index % 3) * 0.08)
            )
            drawCurve(
                from: start,
                control1: NSPoint(x: start.x + direction * length * 0.18, y: start.y - spread * 0.18),
                control2: NSPoint(x: end.x - direction * length * 0.10, y: end.y + spread * 0.10),
                to: end,
                color: color(red: 20, green: 24, blue: 17, alpha: CGFloat(castShadow.opacity) * 0.12),
                width: max(0.7, spread * 0.010)
            )
        }
    }

    func drawRootContactIntegration(
        for plant: Plant,
        anchor: NSPoint,
        width: CGFloat,
        profile: GardenSceneVisualProfile
    ) {
        let integration = plant.groundIntegration
        let tuckWidth = max(18, width * CGFloat(integration.widthMultiplier) * 0.70)
        let tuckHeight = max(4, width * CGFloat(integration.occlusionHeightRatio) * (0.58 + CGFloat(profile.humidity) * 0.18))
        let y = anchor.y - tuckHeight * 0.38
        let alpha = CGFloat(integration.occlusionOpacity) * CGFloat(0.64 + profile.shadowOpacityMultiplier * 0.28)

        for layer in 0..<3 {
            let fraction = CGFloat(layer) / 2
            let path = NSBezierPath()
            let half = tuckWidth * (0.40 + fraction * 0.11)
            let topY = y - tuckHeight * (0.30 + fraction * 0.12)
            path.move(to: NSPoint(x: anchor.x - half, y: topY))
            path.curve(
                to: NSPoint(x: anchor.x + half, y: topY + tuckHeight * 0.08),
                controlPoint1: NSPoint(x: anchor.x - half * 0.34, y: topY - tuckHeight * 0.34),
                controlPoint2: NSPoint(x: anchor.x + half * 0.36, y: topY - tuckHeight * 0.26)
            )
            path.line(to: NSPoint(x: anchor.x + half * 0.74, y: topY + tuckHeight * (0.56 + fraction * 0.16)))
            path.curve(
                to: NSPoint(x: anchor.x - half * 0.74, y: topY + tuckHeight * 0.50),
                controlPoint1: NSPoint(x: anchor.x + half * 0.28, y: topY + tuckHeight * 0.76),
                controlPoint2: NSPoint(x: anchor.x - half * 0.32, y: topY + tuckHeight * 0.72)
            )
            path.close()
            color(red: 36, green: 30, blue: 21, alpha: min(0.16, alpha * (0.26 + fraction * 0.20))).setFill()
            path.fill()
        }

        drawLine(
            from: NSPoint(x: anchor.x - tuckWidth * 0.31, y: y + tuckHeight * 0.15),
            to: NSPoint(x: anchor.x + tuckWidth * 0.32, y: y + tuckHeight * 0.18),
            color: groundTintColor(for: plant, alpha: CGFloat(integration.surfaceTintOpacity) * 0.42),
            width: max(0.8, tuckHeight * 0.12)
        )
    }

    func drawForegroundOcclusion(
        for plant: Plant,
        rect: NSRect,
        anchor: NSPoint,
        profile: GardenSceneVisualProfile
    ) {
        let opacity = CGFloat(profile.occlusionOpacity(for: plant))
        guard opacity > 0.001 else {
            return
        }

        let height = max(6, min(rect.height * 0.12, bounds.height * 0.045))
        let width = rect.width * 0.90
        let y = anchor.y - height * 0.82
        let path = NSBezierPath()
        path.move(to: NSPoint(x: anchor.x - width * 0.52, y: y))
        path.curve(
            to: NSPoint(x: anchor.x + width * 0.52, y: y + height * 0.02),
            controlPoint1: NSPoint(x: anchor.x - width * 0.20, y: y - height * 0.20),
            controlPoint2: NSPoint(x: anchor.x + width * 0.18, y: y - height * 0.16)
        )
        path.line(to: NSPoint(x: anchor.x + width * 0.45, y: y + height))
        path.curve(
            to: NSPoint(x: anchor.x - width * 0.45, y: y + height * 0.92),
            controlPoint1: NSPoint(x: anchor.x + width * 0.20, y: y + height * 1.15),
            controlPoint2: NSPoint(x: anchor.x - width * 0.20, y: y + height * 1.10)
        )
        path.close()
        color(red: 47, green: 42, blue: 31, alpha: opacity).setFill()
        path.fill()

        drawLine(
            from: NSPoint(x: anchor.x - width * 0.46, y: y + height * 0.18),
            to: NSPoint(x: anchor.x + width * 0.42, y: y + height * 0.22),
            color: color(red: 214, green: 198, blue: 158, alpha: opacity * 0.46),
            width: 0.85
        )
    }

    func groundTintColor(for plant: Plant, alpha: CGFloat) -> NSColor {
        switch plant.species.kind {
        case .tree:
            color(red: 126, green: 151, blue: 87, alpha: alpha)
        case .foliage:
            color(red: 112, green: 164, blue: 104, alpha: alpha)
        case .edible:
            color(red: 128, green: 166, blue: 92, alpha: alpha)
        case .flower:
            color(red: 160, green: 176, blue: 96, alpha: alpha)
        case .meadow:
            color(red: 139, green: 184, blue: 95, alpha: alpha)
        }
    }

}
