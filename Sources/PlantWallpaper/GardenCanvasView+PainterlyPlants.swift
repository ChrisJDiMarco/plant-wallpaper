import AppKit
import PlantGardenCore

/// Painterly procedural plants: the hand-drawn flower, foliage, meadow, and
/// tree renderers used when a species has no staged PNG artwork, plus their
/// bloom shapes.
extension GardenCanvasView {
    func drawFlowerPlant(_ plant: Plant, anchor: NSPoint, height: CGFloat, sway: CGFloat, palette: PlantPalette) {
        let maturity = CGFloat(plant.growth)
        let top = NSPoint(x: anchor.x + sway, y: anchor.y - height)
        let stemWidth = max(2, height * 0.035)

        drawCurve(
            from: anchor,
            control1: NSPoint(x: anchor.x - sway * 0.2, y: anchor.y - height * 0.35),
            control2: NSPoint(x: anchor.x + sway * 0.8, y: anchor.y - height * 0.74),
            to: top,
            color: palette.accent.withAlphaComponent(0.38),
            width: stemWidth * 1.9
        )
        drawCurve(
            from: anchor,
            control1: NSPoint(x: anchor.x - sway * 0.2, y: anchor.y - height * 0.35),
            control2: NSPoint(x: anchor.x + sway * 0.8, y: anchor.y - height * 0.74),
            to: top,
            color: palette.stem,
            width: stemWidth
        )

        let leafCount = plant.species == .lavender ? 7 : 5
        for index in 0..<leafCount {
            let fraction = CGFloat(index + 1) / CGFloat(leafCount + 1)
            let center = NSPoint(
                x: anchor.x + sway * fraction * 0.7,
                y: anchor.y - height * fraction
            )
            let angle: CGFloat = index.isMultiple(of: 2) ? -32 : 34
            drawLeaf(
                center: center,
                size: NSSize(width: height * 0.23, height: height * 0.088),
                angle: angle,
                fill: index.isMultiple(of: 2) ? palette.leafA : palette.leafB
            )
            drawLeafVein(center: center, size: NSSize(width: height * 0.18, height: 1.5), angle: angle, color: palette.accent.withAlphaComponent(0.26))
        }

        guard maturity > 0.22 else {
            drawLeaf(center: top, size: NSSize(width: 14, height: 10), angle: 0, fill: palette.leafB)
            return
        }

        switch plant.species {
        case .lavender:
            drawLavenderBloom(top: top, height: height, plant: plant, palette: palette)
        case .sunflower:
            drawSunflowerBloom(top: top, height: height, plant: plant, palette: palette)
        default:
            drawLooseBloom(
                center: top,
                radius: max(13, height * (0.14 + CGFloat(plant.bloomProgress) * 0.04)),
                petalCount: 9,
                palette: palette,
                bloom: CGFloat(max(0.22, plant.bloomProgress))
            )
        }
    }

    func drawFoliagePlant(_ plant: Plant, anchor: NSPoint, height: CGFloat, sway: CGFloat, palette: PlantPalette) {
        let leafCount = plant.species == .monstera ? 12 : 22
        let spread = height * (plant.species == .monstera ? 0.64 : 0.48)

        drawCurve(
            from: anchor,
            control1: NSPoint(x: anchor.x - sway * 0.25, y: anchor.y - height * 0.34),
            control2: NSPoint(x: anchor.x + sway * 0.35, y: anchor.y - height * 0.72),
            to: NSPoint(x: anchor.x + sway, y: anchor.y - height * 0.92),
            color: palette.stem,
            width: max(2, height * 0.028)
        )

        for index in 0..<leafCount {
            let wave = deterministicWave(seed: plant.swaySeed, index: index)
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let yFraction = CGFloat(index + 1) / CGFloat(leafCount + 1)
            let center = NSPoint(
                x: anchor.x + side * spread * (0.18 + abs(wave) * 0.78) + sway * yFraction,
                y: anchor.y - height * (0.12 + yFraction * 0.86)
            )
            let width = height * (plant.species == .monstera ? 0.25 : 0.16) * (0.75 + abs(wave) * 0.35)
            let leafHeight = height * (plant.species == .monstera ? 0.19 : 0.08)
            let angle = side * (plant.species == .monstera ? 22 : 42) + wave * 8
            drawLeaf(
                center: center,
                size: NSSize(width: width, height: leafHeight),
                angle: angle,
                fill: index.isMultiple(of: 3) ? palette.leafB : palette.leafA
            )
            drawLeafVein(center: center, size: NSSize(width: width * 0.70, height: 1.4), angle: angle, color: palette.accent.withAlphaComponent(0.24))
        }
    }

    func drawMeadow(_ plant: Plant, anchor: NSPoint, height: CGFloat, sway: CGFloat, palette: PlantPalette) {
        let stemCount = 13
        for index in 0..<stemCount {
            let wave = deterministicWave(seed: plant.swaySeed, index: index)
            let offsetX = wave * height * 0.55
            let stemHeight = height * (0.35 + abs(deterministicWave(seed: plant.swaySeed + 11, index: index)) * 0.72)
            let base = NSPoint(x: anchor.x + offsetX, y: anchor.y + CGFloat(index % 3) * 2)
            let top = NSPoint(x: base.x + sway * 0.22, y: base.y - stemHeight)

            drawCurve(
                from: base,
                control1: NSPoint(x: base.x + sway * 0.12, y: base.y - stemHeight * 0.32),
                control2: NSPoint(x: top.x - sway * 0.1, y: base.y - stemHeight * 0.68),
                to: top,
                color: palette.stem.withAlphaComponent(0.72),
                width: 1.25
            )

            if plant.growth > 0.25 {
                drawLooseBloom(
                    center: top,
                    radius: 4 + CGFloat(plant.bloomProgress) * 5,
                    petalCount: 5,
                    palette: palette,
                    bloom: CGFloat(max(0.35, plant.bloomProgress))
                )
            }
        }
    }

    func drawBroadleafTree(_ plant: Plant, anchor: NSPoint, height: CGFloat, sway: CGFloat, palette: PlantPalette) {
        let trunkTop = NSPoint(x: anchor.x + sway * 0.35, y: anchor.y - height * 0.64)
        let trunkWidth = max(5, height * 0.055)
        drawCurve(
            from: anchor,
            control1: NSPoint(x: anchor.x - 5, y: anchor.y - height * 0.22),
            control2: NSPoint(x: trunkTop.x + 4, y: anchor.y - height * 0.48),
            to: trunkTop,
            color: palette.trunk.shadow(withLevel: 0.18) ?? palette.trunk,
            width: trunkWidth * 1.25
        )
        drawCurve(
            from: anchor,
            control1: NSPoint(x: anchor.x - 5, y: anchor.y - height * 0.22),
            control2: NSPoint(x: trunkTop.x + 4, y: anchor.y - height * 0.48),
            to: trunkTop,
            color: palette.trunk,
            width: trunkWidth * 0.82
        )

        for index in 0..<6 {
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let baseY = anchor.y - height * (0.28 + CGFloat(index) * 0.055)
            let base = NSPoint(x: anchor.x + sway * 0.12, y: baseY)
            let end = NSPoint(
                x: base.x + side * height * (0.16 + CGFloat(index % 3) * 0.025),
                y: base.y - height * (0.10 + CGFloat(index % 2) * 0.04)
            )
            drawCurve(
                from: base,
                control1: NSPoint(x: base.x + side * height * 0.07, y: base.y - height * 0.02),
                control2: NSPoint(x: end.x - side * height * 0.04, y: end.y + height * 0.04),
                to: end,
                color: palette.trunk.withAlphaComponent(0.82),
                width: max(2, trunkWidth * 0.45)
            )
        }

        let canopyCenter = NSPoint(x: trunkTop.x + sway * 0.35, y: trunkTop.y - height * 0.10)
        for index in 0..<15 {
            let waveX = deterministicWave(seed: plant.swaySeed, index: index)
            let waveY = deterministicWave(seed: plant.swaySeed + 99, index: index)
            let center = NSPoint(
                x: canopyCenter.x + waveX * height * 0.34,
                y: canopyCenter.y + waveY * height * 0.23
            )
            let radius = height * (0.14 + abs(waveX) * 0.05)
            let fill = index.isMultiple(of: 3) ? palette.leafB : palette.leafA
            drawCircle(center: center, radius: radius, fill: fill.withAlphaComponent(0.92), stroke: palette.accent.withAlphaComponent(0.08))
        }

        if plant.bloomProgress > 0.2 {
            for index in 0..<10 {
                let waveX = deterministicWave(seed: plant.swaySeed + 7, index: index)
                let waveY = deterministicWave(seed: plant.swaySeed + 31, index: index)
                let center = NSPoint(
                    x: canopyCenter.x + waveX * height * 0.31,
                    y: canopyCenter.y + waveY * height * 0.19
                )
                drawCircle(
                    center: center,
                    radius: 3 + CGFloat(plant.bloomProgress) * 4,
                    fill: palette.flowerA.withAlphaComponent(0.88),
                    stroke: nil
                )
            }
        }
    }

    func drawPineTree(_ plant: Plant, anchor: NSPoint, height: CGFloat, sway: CGFloat, palette: PlantPalette) {
        let trunkTop = NSPoint(x: anchor.x + sway * 0.18, y: anchor.y - height * 0.68)
        drawCurve(
            from: anchor,
            control1: NSPoint(x: anchor.x - 2, y: anchor.y - height * 0.22),
            control2: NSPoint(x: trunkTop.x + 2, y: anchor.y - height * 0.46),
            to: trunkTop,
            color: palette.trunk,
            width: max(4, height * 0.045)
        )

        let layerCount = 7
        for index in 0..<layerCount {
            let fraction = CGFloat(index) / CGFloat(layerCount)
            let centerY = anchor.y - height * (0.24 + fraction * 0.58)
            let halfWidth = height * (0.34 - fraction * 0.045)
            let layerHeight = height * 0.24
            let centerX = anchor.x + sway * fraction
            let path = NSBezierPath()
            path.move(to: NSPoint(x: centerX, y: centerY - layerHeight))
            path.line(to: NSPoint(x: centerX - halfWidth, y: centerY))
            path.line(to: NSPoint(x: centerX + halfWidth, y: centerY))
            path.close()
            (index.isMultiple(of: 2) ? palette.leafA : palette.leafB).withAlphaComponent(0.94).setFill()
            path.fill()
            palette.accent.withAlphaComponent(0.18).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    func drawLavenderBloom(top: NSPoint, height: CGFloat, plant: Plant, palette: PlantPalette) {
        let bloomCount = 8
        for index in 0..<bloomCount {
            let offset = CGFloat(index) * height * 0.035
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let center = NSPoint(x: top.x + side * height * 0.035, y: top.y + offset)
            drawOval(
                center: center,
                size: NSSize(width: height * 0.08, height: height * 0.04),
                angle: side * 24,
                fill: (index.isMultiple(of: 3) ? palette.flowerB : palette.flowerA)
                    .withAlphaComponent(0.72 + CGFloat(plant.bloomProgress) * 0.24),
                stroke: nil
            )
        }
    }

    func drawSunflowerBloom(top: NSPoint, height: CGFloat, plant: Plant, palette: PlantPalette) {
        drawLooseBloom(
            center: top,
            radius: height * (0.11 + CGFloat(plant.bloomProgress) * 0.045),
            petalCount: 13,
            palette: palette,
            bloom: CGFloat(max(0.35, plant.bloomProgress))
        )
        drawOval(
            center: NSPoint(x: top.x + height * 0.010, y: top.y + height * 0.012),
            size: NSSize(width: height * 0.090, height: height * 0.060),
            angle: 8,
            fill: palette.accent.withAlphaComponent(0.72),
            stroke: color(red: 89, green: 55, blue: 28, alpha: 0.26)
        )
    }

    func drawLooseBloom(
        center: NSPoint,
        radius: CGFloat,
        petalCount: Int,
        palette: PlantPalette,
        bloom: CGFloat
    ) {
        let petalOffsets = [
            (x: -0.58, y: 0.02, angle: -24.0, width: 0.74, height: 0.32),
            (x: -0.32, y: -0.42, angle: -10.0, width: 0.84, height: 0.34),
            (x: 0.12, y: -0.50, angle: 8.0, width: 0.86, height: 0.33),
            (x: 0.48, y: -0.20, angle: 29.0, width: 0.76, height: 0.31),
            (x: 0.38, y: 0.22, angle: 45.0, width: 0.62, height: 0.27),
            (x: -0.08, y: 0.32, angle: 5.0, width: 0.56, height: 0.24),
            (x: -0.48, y: 0.23, angle: -42.0, width: 0.58, height: 0.25)
        ]

        for index in 0..<petalCount {
            let petal = petalOffsets[index % petalOffsets.count]
            let jitterX = deterministicWave(seed: 4_101, index: index) * radius * 0.10
            let jitterY = deterministicWave(seed: 4_117, index: index) * radius * 0.07
            drawOval(
                center: NSPoint(
                    x: center.x + CGFloat(petal.x) * radius + jitterX,
                    y: center.y + CGFloat(petal.y) * radius + jitterY
                ),
                size: NSSize(width: radius * CGFloat(petal.width), height: radius * CGFloat(petal.height)),
                angle: CGFloat(petal.angle) + deterministicWave(seed: 4_133, index: index) * 7,
                fill: (index.isMultiple(of: 2) ? palette.flowerA : palette.flowerB)
                    .withAlphaComponent(0.58 + bloom * 0.30),
                stroke: palette.accent.withAlphaComponent(0.10)
            )
        }

        drawOval(
            center: NSPoint(x: center.x + radius * 0.04, y: center.y + radius * 0.02),
            size: NSSize(width: max(4, radius * 0.36), height: max(2.5, radius * 0.22)),
            angle: -6,
            fill: palette.accent.withAlphaComponent(0.38 + bloom * 0.20),
            stroke: color(red: 255, green: 248, blue: 195, alpha: 0.10)
        )
    }
}
