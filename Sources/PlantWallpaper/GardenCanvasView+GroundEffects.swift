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

    func drawPlantCastShadow(
        for plant: Plant,
        anchor: NSPoint,
        width: CGFloat,
        projection: GardenLightProjection
    ) {
        let castShadow = plant.castShadow(projection: projection)
        guard castShadow.isVisible else {
            return
        }

        let castWidth = max(
            18,
            width
                * CGFloat(castShadow.widthMultiplier)
                * (0.90 + CGFloat(castShadow.lengthMultiplier) * 0.24)
        )
        let castHeight = max(
            7,
            castWidth * (0.14 + (1 - CGFloat(castShadow.softness)) * 0.055)
        )
        let offsetX = width * CGFloat(castShadow.offsetXMultiplier)
        let offsetY = width * CGFloat(castShadow.offsetYMultiplier)
        let baseRect = NSRect(
            x: anchor.x - castWidth / 2 + offsetX,
            y: anchor.y - castHeight * 0.72 + offsetY,
            width: castWidth,
            height: castHeight
        )

        for layer in 0..<3 {
            let layerFraction = CGFloat(layer) / 2
            let insetX = -castWidth * (0.18 - layerFraction * 0.07)
            let insetY = -castHeight * (0.38 - layerFraction * 0.16)
            let alpha = CGFloat(castShadow.opacity) * (0.16 + layerFraction * 0.20)
            let path = NSBezierPath(ovalIn: baseRect.insetBy(dx: insetX, dy: insetY))
            color(red: 15, green: 22, blue: 16, alpha: alpha).setFill()
            path.fill()
        }

        for index in 0..<castShadow.canopyLobeCount {
            let xWave = deterministicWave(seed: plant.swaySeed + 14_011, index: index)
            let yWave = deterministicWave(seed: plant.swaySeed + 14_317, index: index)
            let sizeWave = abs(deterministicWave(seed: plant.swaySeed + 14_603, index: index))
            let lobeWidth = castWidth * (0.18 + sizeWave * 0.16)
            let lobeHeight = castHeight * (0.78 + sizeWave * 0.42)
            let lobeRect = NSRect(
                x: baseRect.midX + xWave * castWidth * 0.34 - lobeWidth / 2,
                y: baseRect.midY + yWave * castHeight * 0.28 - lobeHeight / 2,
                width: lobeWidth,
                height: lobeHeight
            )
            let lobe = NSBezierPath(ovalIn: lobeRect)
            color(red: 18, green: 28, blue: 18, alpha: CGFloat(castShadow.opacity) * 0.22).setFill()
            lobe.fill()
        }
    }

    func drawRealisticContactShadow(
        for plant: Plant,
        anchor: NSPoint,
        width: CGFloat,
        selected: Bool,
        projection: GardenLightProjection
    ) {
        let depth = plant.depthProfile
        let sceneAnchor = plant.sceneAnchor
        let lengthMultiplier = CGFloat(projection.shadowLengthMultiplier)
        let shadowWidth = width
            * CGFloat(sceneAnchor.contactShadowWidthMultiplier)
            * lengthMultiplier
        let shadowHeight = max(
            10,
            shadowWidth * CGFloat(sceneAnchor.contactShadowHeightRatio) / max(0.92, lengthMultiplier)
        )
        let offsetX = width * CGFloat(projection.shadowOffsetX) * CGFloat(depth.shadowScale)
        let offsetY = shadowHeight * CGFloat(projection.shadowOffsetY)
        let rect = NSRect(
            x: anchor.x - shadowWidth / 2 + offsetX,
            y: anchor.y - shadowHeight * 0.52 + offsetY,
            width: shadowWidth,
            height: shadowHeight
        )
        let path = NSBezierPath(ovalIn: rect)
        let alpha = min(
            0.48,
            CGFloat(sceneAnchor.contactShadowOpacity)
                * (selected ? 1.16 : 1)
                * CGFloat(projection.shadowOpacityMultiplier)
        )
        color(red: 18, green: 24, blue: 18, alpha: alpha).setFill()
        path.fill()
    }

    func drawBaseOcclusion(for plant: Plant, anchor: NSPoint, width: CGFloat) {
        let sceneAnchor = plant.sceneAnchor
        let footprintWidth = width * CGFloat(sceneAnchor.contactShadowWidthMultiplier)
        let footprintHeight = max(9, footprintWidth * CGFloat(sceneAnchor.contactShadowHeightRatio) * 0.72)
        let tintRect = NSRect(
            x: anchor.x - footprintWidth * 0.56,
            y: anchor.y - footprintHeight * 1.26,
            width: footprintWidth * 1.12,
            height: footprintHeight * 2.18
        )
        let tint = NSBezierPath(ovalIn: tintRect)
        groundTintColor(for: plant, alpha: CGFloat(sceneAnchor.groundTintOpacity)).setFill()
        tint.fill()

        let occlusionRect = NSRect(
            x: anchor.x - footprintWidth * 0.42,
            y: anchor.y - footprintHeight * 0.62,
            width: footprintWidth * 0.84,
            height: footprintHeight
        )
        let occlusion = NSBezierPath(ovalIn: occlusionRect)
        color(red: 21, green: 25, blue: 18, alpha: CGFloat(sceneAnchor.groundOcclusionOpacity)).setFill()
        occlusion.fill()
    }

    func drawGroundIntegrationOverlay(for plant: Plant, anchor: NSPoint, width: CGFloat) {
        let integration = plant.groundIntegration
        let tuckWidth = max(16, width * CGFloat(integration.widthMultiplier))
        let tuckHeight = max(6, width * CGFloat(integration.occlusionHeightRatio))
        let tuckRect = NSRect(
            x: anchor.x - tuckWidth / 2,
            y: anchor.y - tuckHeight * 0.82,
            width: tuckWidth,
            height: tuckHeight
        )

        let surface = NSBezierPath(roundedRect: tuckRect, xRadius: tuckHeight * 0.52, yRadius: tuckHeight * 0.48)
        groundTintColor(for: plant, alpha: CGFloat(integration.surfaceTintOpacity)).setFill()
        surface.fill()

        let occlusionRect = tuckRect.insetBy(dx: tuckWidth * 0.06, dy: -tuckHeight * 0.08)
        let occlusion = NSBezierPath(roundedRect: occlusionRect, xRadius: tuckHeight * 0.48, yRadius: tuckHeight * 0.42)
        color(red: 41, green: 35, blue: 24, alpha: CGFloat(integration.occlusionOpacity)).setFill()
        occlusion.fill()

        let highlight = NSBezierPath()
        highlight.move(to: NSPoint(x: tuckRect.minX + tuckWidth * 0.10, y: tuckRect.midY - tuckHeight * 0.10))
        highlight.curve(
            to: NSPoint(x: tuckRect.maxX - tuckWidth * 0.10, y: tuckRect.midY - tuckHeight * 0.04),
            controlPoint1: NSPoint(x: tuckRect.minX + tuckWidth * 0.34, y: tuckRect.minY + tuckHeight * 0.04),
            controlPoint2: NSPoint(x: tuckRect.maxX - tuckWidth * 0.30, y: tuckRect.minY + tuckHeight * 0.12)
        )
        color(red: 207, green: 174, blue: 111, alpha: CGFloat(integration.surfaceTintOpacity) * 0.62).setStroke()
        highlight.lineWidth = 0.8
        highlight.stroke()

        for index in 0..<integration.surfaceDetailCount {
            let xWave = deterministicWave(seed: plant.swaySeed + 15_101, index: index)
            let yWave = deterministicWave(seed: plant.swaySeed + 15_307, index: index)
            let center = NSPoint(
                x: tuckRect.midX + xWave * tuckWidth * 0.42,
                y: tuckRect.midY + yWave * tuckHeight * 0.22
            )
            if index.isMultiple(of: 3) {
                drawCircle(
                    center: center,
                    radius: max(0.9, tuckHeight * 0.10),
                    fill: color(red: 91, green: 67, blue: 42, alpha: CGFloat(integration.occlusionOpacity) * 0.78),
                    stroke: nil
                )
            } else {
                drawOval(
                    center: center,
                    size: NSSize(width: max(3.4, tuckWidth * 0.050), height: max(1.4, tuckHeight * 0.16)),
                    angle: deterministicWave(seed: plant.swaySeed + 15_509, index: index) * 70,
                    fill: index.isMultiple(of: 2)
                        ? color(red: 82, green: 112, blue: 61, alpha: CGFloat(integration.surfaceTintOpacity) * 1.20)
                        : color(red: 119, green: 86, blue: 48, alpha: CGFloat(integration.occlusionOpacity) * 0.72),
                    stroke: nil
                )
            }
        }
    }

    func drawSelectionGroundRing(for plant: Plant, anchor: NSPoint, height: CGFloat) {
        let widthFactor: CGFloat
        switch plant.species.kind {
        case .tree:
            widthFactor = 0.82
        case .foliage:
            widthFactor = 0.74
        case .edible:
            widthFactor = 0.72
        case .flower:
            widthFactor = 0.66
        case .meadow:
            widthFactor = 0.96
        }

        let ringWidth = max(54, min(bounds.width * 0.18, height * widthFactor))
        let ringHeight = max(14, ringWidth * 0.22)
        let rect = NSRect(
            x: anchor.x - ringWidth / 2,
            y: anchor.y - ringHeight * 0.55,
            width: ringWidth,
            height: ringHeight
        )

        let glow = NSBezierPath(ovalIn: rect.insetBy(dx: -ringWidth * 0.10, dy: -ringHeight * 0.22))
        color(red: 250, green: 220, blue: 137, alpha: 0.11).setFill()
        glow.fill()

        let ring = NSBezierPath(ovalIn: rect)
        color(red: 255, green: 236, blue: 162, alpha: 0.44).setStroke()
        ring.lineWidth = 1.35
        ring.setLineDash([4.5, 4.0], count: 2, phase: 0)
        ring.stroke()

        let inner = NSBezierPath(ovalIn: rect.insetBy(dx: ringWidth * 0.10, dy: ringHeight * 0.20))
        color(red: 99, green: 134, blue: 77, alpha: 0.12).setFill()
        inner.fill()
    }

    func drawAmbientLift(around rect: NSRect, for plant: Plant) {
        let sceneAnchor = plant.sceneAnchor
        guard plant.health > 0.25, sceneAnchor.reflectionOpacity > 0.012 else {
            return
        }

        let haloRect = rect.insetBy(dx: -rect.width * 0.08, dy: -rect.height * 0.05)
        let path = NSBezierPath(ovalIn: NSRect(
            x: haloRect.minX,
            y: haloRect.maxY - rect.height * 0.20,
            width: haloRect.width,
            height: rect.height * 0.20
        ))
        groundTintColor(for: plant, alpha: CGFloat(sceneAnchor.reflectionOpacity)).setFill()
        path.fill()
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

    func drawShadow(at anchor: NSPoint, width: CGFloat, alpha: CGFloat, projection: GardenLightProjection) {
        let shadowWidth = width * CGFloat(projection.shadowLengthMultiplier)
        let shadowHeight = max(10, 16 / max(0.92, CGFloat(projection.shadowLengthMultiplier)))
        let rect = NSRect(
            x: anchor.x - shadowWidth / 2 + width * CGFloat(projection.shadowOffsetX),
            y: anchor.y - 8 + shadowHeight * CGFloat(projection.shadowOffsetY),
            width: shadowWidth,
            height: shadowHeight
        )
        let path = NSBezierPath(ovalIn: rect)
        color(red: 0, green: 0, blue: 0, alpha: alpha * CGFloat(projection.shadowOpacityMultiplier)).setFill()
        path.fill()
    }
}
