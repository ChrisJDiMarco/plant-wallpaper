import AppKit
import PlantGardenCore

/// Hand-drawn species artwork: the per-species procedural signatures plus
/// the painterly flower/foliage/meadow/tree fallbacks and bloom shapes.
extension GardenCanvasView {
    func drawSpeciesSignature(
        for plant: Plant,
        in rect: NSRect,
        anchor: NSPoint,
        height: CGFloat,
        palette: PlantPalette
    ) {
        guard !plant.isDead else {
            return
        }

        let bloom = CGFloat(max(0.18, plant.bloomProgress))
        let signatureAlpha = opacity(for: plant) * 0.72

        switch plant.species {
        case .mossCarpet:
            drawMossCarpetSignature(anchor: anchor, width: rect.width, palette: palette, alpha: signatureAlpha)
        case .cloverPatch:
            drawCloverPatchSignature(anchor: anchor, width: rect.width, palette: palette, alpha: signatureAlpha)
        case .creepingThyme:
            drawCreepingThymeSignature(anchor: anchor, width: rect.width, palette: palette, bloom: bloom)
        case .ivy:
            drawIvySignature(rect: rect, palette: palette)
        case .wisteria:
            drawDroopingBloomSignature(rect: rect, palette: palette, bloom: bloom, clusterCount: 6)
        case .jasmine:
            drawLooseBlossomSpraySignature(rect: rect, palette: palette, bloom: bloom, count: 7)
        case .orchid:
            drawOrchidSignature(rect: rect, palette: palette, bloom: bloom)
        case .bonsai:
            drawBonsaiSignature(rect: rect, anchor: anchor, palette: palette)
        case .japaneseMaple:
            drawJapaneseMapleSignature(rect: rect, palette: palette)
        case .willow:
            drawWillowSignature(rect: rect, palette: palette)
        case .birch:
            drawBirchSignature(rect: rect, anchor: anchor)
        case .dogwood:
            drawBranchBlossomSignature(rect: rect, palette: palette, bloom: bloom, count: 8)
        case .magnolia:
            drawMagnoliaSignature(rect: rect, palette: palette, bloom: bloom)
        case .oliveTree:
            drawOliveSignature(rect: rect, palette: palette)
        case .dwarfCitrus:
            drawCitrusSignature(rect: rect, palette: palette)
        case .hydrangea:
            drawHydrangeaSignature(rect: rect, palette: palette, bloom: bloom)
        case .peony:
            drawClusteredPetalSignature(rect: rect, palette: palette, bloom: bloom, density: 12)
        case .rose:
            drawRoseSignature(rect: rect, palette: palette, bloom: bloom)
        case .foxglove:
            drawFoxgloveSignature(rect: rect, anchor: anchor, palette: palette, bloom: bloom)
        case .poppy:
            drawClusteredPetalSignature(rect: rect, palette: palette, bloom: bloom, density: 7)
        case .iris:
            drawIrisSignature(rect: rect, anchor: anchor, palette: palette, bloom: bloom)
        case .lily:
            drawLilySignature(rect: rect, palette: palette, bloom: bloom)
        case .lavenderField:
            drawLavenderFieldSignature(anchor: anchor, width: rect.width, palette: palette, bloom: bloom)
        case .herbCluster:
            drawHerbClusterSignature(anchor: anchor, height: height, palette: palette)
        case .bamboo:
            drawBambooSignature(rect: rect, anchor: anchor, palette: palette)
        case .ornamentalGrass:
            drawOrnamentalGrassSignature(anchor: anchor, height: height, width: rect.width, palette: palette)
        case .cattails:
            drawCattailsSignature(anchor: anchor, height: height, width: rect.width, palette: palette)
        case .mushrooms:
            drawMushroomSignature(anchor: anchor, width: rect.width, palette: palette)
        case .lichens:
            drawLichenSignature(anchor: anchor, width: rect.width, palette: palette)
        case .succulent:
            drawSucculentSignature(anchor: anchor, height: height, palette: palette)
        case .pitcherPlant:
            drawPitcherPlantSignature(anchor: anchor, height: height, palette: palette)
        case .waterLily:
            drawWaterLilySignature(anchor: anchor, width: rect.width, palette: palette, bloom: bloom)
        case .fern, .lavender, .tulip, .sunflower, .cherryTree, .mapleTree, .pineTree, .monstera, .wildflowerMeadow, .determinateTomato, .sweetPepper, .peaVines, .stringBeans, .cucumberVine, .rosemary, .thyme, .oregano, .sage, .ghostOrchid, .jadeVine, .corpseFlower, .queenOfTheNight, .chocolateCosmos, .baobab, .dragonBloodTree, .rainbowEucalyptus, .monkeyPuzzleTree, .silkFlossTree, .alocasiaDragonScale, .ravenZZPlant, .prayerPlant, .staghornFern, .blackCoralColocasia, .blueStarCreeper, .silverFallsDichondra, .corsicanMint, .redVeinSorrelPatch, .alpineEdelweissMat, .dragonFruitCactus, .purpleBasil, .shiso, .saffronCrocus, .wasabi, .alpineStrawberry, .glassGemCorn, .cucamelon:
            break
        }
    }

    func drawMossCarpetSignature(anchor: NSPoint, width: CGFloat, palette: PlantPalette, alpha: CGFloat) {
        for index in 0..<18 {
            let x = anchor.x + deterministicWave(seed: 1_601, index: index) * width * 0.46
            let y = anchor.y - 5 + deterministicWave(seed: 1_617, index: index) * 9
            drawOval(
                center: NSPoint(x: x, y: y),
                size: NSSize(width: 12 + CGFloat(index % 4) * 3, height: 4 + CGFloat(index % 3)),
                angle: deterministicWave(seed: 1_633, index: index) * 80,
                fill: (index.isMultiple(of: 2) ? palette.leafA : palette.leafB).withAlphaComponent(alpha * 0.70),
                stroke: nil
            )
        }
    }

    func drawCloverPatchSignature(anchor: NSPoint, width: CGFloat, palette: PlantPalette, alpha: CGFloat) {
        for index in 0..<9 {
            let center = NSPoint(
                x: anchor.x + deterministicWave(seed: 1_701, index: index) * width * 0.40,
                y: anchor.y - 10 + deterministicWave(seed: 1_717, index: index) * 13
            )
            drawCurve(
                from: NSPoint(x: center.x - 7, y: center.y + 5),
                control1: NSPoint(x: center.x - 2, y: center.y + 1),
                control2: NSPoint(x: center.x + 3, y: center.y - 2),
                to: NSPoint(x: center.x + 8, y: center.y - 4),
                color: palette.stem.withAlphaComponent(alpha * 0.46),
                width: 0.75
            )
            let leafOffsets = [
                (x: -4.2, y: -1.8, angle: -28.0, width: 8.2, height: 4.4),
                (x: 1.4, y: -4.8, angle: 8.0, width: 7.4, height: 4.8),
                (x: 5.2, y: -1.2, angle: 34.0, width: 7.8, height: 4.1)
            ]
            for leaf in leafOffsets {
                drawOval(
                    center: NSPoint(x: center.x + leaf.x, y: center.y + leaf.y),
                    size: NSSize(width: leaf.width, height: leaf.height),
                    angle: leaf.angle + Double(deterministicWave(seed: 1_733, index: index) * 8),
                    fill: palette.leafB.withAlphaComponent(alpha * 0.62),
                    stroke: nil
                )
            }
        }
    }

    func drawCreepingThymeSignature(anchor: NSPoint, width: CGFloat, palette: PlantPalette, bloom: CGFloat) {
        for index in 0..<12 {
            let start = NSPoint(
                x: anchor.x - width * 0.42 + CGFloat(index) / 11.0 * width * 0.84,
                y: anchor.y - 6 + deterministicWave(seed: 1_801, index: index) * 7
            )
            drawCurve(
                from: start,
                control1: NSPoint(x: start.x + width * 0.035, y: start.y - 9),
                control2: NSPoint(x: start.x + width * 0.075, y: start.y + 4),
                to: NSPoint(x: start.x + width * 0.11, y: start.y - 3),
                color: palette.stem.withAlphaComponent(0.48),
                width: 1.0
            )
            if index.isMultiple(of: 3) {
                drawOval(
                    center: NSPoint(x: start.x + width * 0.055, y: start.y - 6),
                    size: NSSize(width: 8, height: 3.5),
                    angle: deterministicWave(seed: 1_817, index: index) * 40,
                    fill: palette.flowerA.withAlphaComponent(0.34 + bloom * 0.22),
                    stroke: nil
                )
            }
        }
    }

    func drawIvySignature(rect: NSRect, palette: PlantPalette) {
        let start = NSPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY - rect.height * 0.05)
        let end = NSPoint(x: rect.minX + rect.width * 0.82, y: rect.minY + rect.height * 0.12)
        drawCurve(
            from: start,
            control1: NSPoint(x: rect.minX - rect.width * 0.06, y: rect.midY),
            control2: NSPoint(x: rect.maxX + rect.width * 0.06, y: rect.midY),
            to: end,
            color: palette.stem.withAlphaComponent(0.48),
            width: 2.0
        )
        for index in 0..<12 {
            let fraction = CGFloat(index) / 11.0
            let x = rect.minX + rect.width * (0.18 + fraction * 0.64)
            let y = rect.maxY - rect.height * (0.06 + fraction * 0.78)
            drawLeaf(
                center: NSPoint(x: x, y: y),
                size: NSSize(width: rect.width * 0.11, height: rect.height * 0.026),
                angle: (index.isMultiple(of: 2) ? -36 : 34),
                fill: (index.isMultiple(of: 2) ? palette.leafA : palette.leafB).withAlphaComponent(0.64)
            )
        }
    }

    func drawDroopingBloomSignature(rect: NSRect, palette: PlantPalette, bloom: CGFloat, clusterCount: Int) {
        for index in 0..<clusterCount {
            let x = rect.minX + rect.width * (0.28 + CGFloat(index) / CGFloat(max(1, clusterCount - 1)) * 0.44)
            let top = NSPoint(x: x, y: rect.minY + rect.height * (0.12 + abs(deterministicWave(seed: 1_901, index: index)) * 0.16))
            let length = rect.height * (0.12 + abs(deterministicWave(seed: 1_917, index: index)) * 0.12)
            drawCurve(
                from: top,
                control1: NSPoint(x: top.x - 4, y: top.y + length * 0.30),
                control2: NSPoint(x: top.x + 5, y: top.y + length * 0.64),
                to: NSPoint(x: top.x, y: top.y + length),
                color: palette.stem.withAlphaComponent(0.38),
                width: 1.0
            )
            for petal in 0..<4 {
                drawOval(
                    center: NSPoint(x: top.x + deterministicWave(seed: 1_933 + Double(index), index: petal) * 7, y: top.y + CGFloat(petal + 1) * length * 0.18),
                    size: NSSize(width: 8 + bloom * 3, height: 4 + bloom * 2),
                    angle: deterministicWave(seed: 1_949, index: petal) * 30,
                    fill: (petal.isMultiple(of: 2) ? palette.flowerA : palette.flowerB).withAlphaComponent(0.48 + bloom * 0.26),
                    stroke: nil
                )
            }
        }
    }

    func drawLooseBlossomSpraySignature(rect: NSRect, palette: PlantPalette, bloom: CGFloat, count: Int) {
        for index in 0..<count {
            let center = NSPoint(
                x: rect.minX + rect.width * (0.26 + abs(deterministicWave(seed: 2_001, index: index)) * 0.48),
                y: rect.minY + rect.height * (0.16 + abs(deterministicWave(seed: 2_017, index: index)) * 0.34)
            )
            drawLine(
                from: NSPoint(x: center.x - rect.width * 0.050, y: center.y + rect.height * 0.030),
                to: center,
                color: palette.stem.withAlphaComponent(0.24),
                width: 0.8
            )
            let petalOffsets = [
                (x: -6.0, y: -2.0, angle: -28.0, width: 11.0, height: 4.0),
                (x: -1.5, y: -5.0, angle: -6.0, width: 10.0, height: 4.3),
                (x: 4.2, y: -3.0, angle: 22.0, width: 10.5, height: 4.0),
                (x: 2.0, y: 1.8, angle: 43.0, width: 8.5, height: 3.3)
            ]
            for (petalIndex, petal) in petalOffsets.enumerated() {
                let jitter = deterministicWave(seed: 2_033 + Double(index), index: petalIndex) * 2.2
                drawOval(
                    center: NSPoint(x: center.x + petal.x + jitter, y: center.y + petal.y - jitter * 0.3),
                    size: NSSize(width: petal.width + bloom * 2.5, height: petal.height + bloom * 1.2),
                    angle: petal.angle + Double(jitter),
                    fill: (petalIndex.isMultiple(of: 2) ? palette.flowerA : palette.flowerB).withAlphaComponent(0.50 + bloom * 0.24),
                    stroke: nil
                )
            }
        }
    }

    func drawBranchBlossomSignature(rect: NSRect, palette: PlantPalette, bloom: CGFloat, count: Int) {
        for branch in 0..<3 {
            let base = NSPoint(
                x: rect.minX + rect.width * (0.30 + CGFloat(branch) * 0.16),
                y: rect.minY + rect.height * (0.38 + CGFloat(branch % 2) * 0.08)
            )
            let tip = NSPoint(
                x: base.x + rect.width * (0.20 + deterministicWave(seed: 2_061, index: branch) * 0.04),
                y: base.y - rect.height * (0.16 + abs(deterministicWave(seed: 2_077, index: branch)) * 0.05)
            )
            drawCurve(
                from: base,
                control1: NSPoint(x: base.x + rect.width * 0.06, y: base.y - rect.height * 0.08),
                control2: NSPoint(x: tip.x - rect.width * 0.06, y: tip.y + rect.height * 0.06),
                to: tip,
                color: palette.trunk.withAlphaComponent(0.30),
                width: 1.1
            )

            for blossom in 0..<(count / 3 + 1) {
                let fraction = CGFloat(blossom + 1) / CGFloat(count / 3 + 2)
                let center = NSPoint(
                    x: base.x + (tip.x - base.x) * fraction + deterministicWave(seed: 2_093 + Double(branch), index: blossom) * 6,
                    y: base.y + (tip.y - base.y) * fraction + deterministicWave(seed: 2_109 + Double(branch), index: blossom) * 4
                )
                drawLoosePetalCup(
                    center: center,
                    scale: max(0.72, rect.width * 0.0048),
                    palette: palette,
                    bloom: bloom,
                    seed: 2_121 + Double(branch * 17 + blossom)
                )
            }
        }
    }

    func drawLoosePetalCup(center: NSPoint, scale: CGFloat, palette: PlantPalette, bloom: CGFloat, seed: Double) {
        let petals = [
            (x: -7.0, y: 0.4, angle: -25.0, width: 12.0, height: 4.2),
            (x: -2.4, y: -4.0, angle: -8.0, width: 12.8, height: 4.5),
            (x: 4.4, y: -2.6, angle: 18.0, width: 11.8, height: 4.0),
            (x: 3.0, y: 2.2, angle: 41.0, width: 9.5, height: 3.4)
        ]

        for (index, petal) in petals.enumerated() {
            let jitter = deterministicWave(seed: seed, index: index) * 1.5 * scale
            drawOval(
                center: NSPoint(
                    x: center.x + CGFloat(petal.x) * scale + jitter,
                    y: center.y + CGFloat(petal.y) * scale - jitter * 0.22
                ),
                size: NSSize(
                    width: CGFloat(petal.width) * scale + bloom * 1.6,
                    height: CGFloat(petal.height) * scale + bloom * 0.8
                ),
                angle: CGFloat(petal.angle) + deterministicWave(seed: seed + 17, index: index) * 6,
                fill: (index.isMultiple(of: 2) ? palette.flowerA : palette.flowerB).withAlphaComponent(0.48 + bloom * 0.24),
                stroke: nil
            )
        }
    }

    func drawOrchidSignature(rect: NSRect, palette: PlantPalette, bloom: CGFloat) {
        let center = NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.23)
        drawOval(center: NSPoint(x: center.x - rect.width * 0.040, y: center.y), size: NSSize(width: rect.width * 0.12, height: rect.height * 0.040), angle: -23, fill: palette.flowerB.withAlphaComponent(0.58 + bloom * 0.24), stroke: palette.flowerA.withAlphaComponent(0.16))
        drawOval(center: NSPoint(x: center.x + rect.width * 0.038, y: center.y - rect.height * 0.006), size: NSSize(width: rect.width * 0.11, height: rect.height * 0.038), angle: 21, fill: palette.flowerB.withAlphaComponent(0.56 + bloom * 0.22), stroke: palette.flowerA.withAlphaComponent(0.14))
        drawOval(center: NSPoint(x: center.x - rect.width * 0.004, y: center.y + rect.height * 0.030), size: NSSize(width: rect.width * 0.10, height: rect.height * 0.046), angle: 6, fill: palette.flowerA.withAlphaComponent(0.68 + bloom * 0.20), stroke: nil)
        drawOval(center: NSPoint(x: center.x + rect.width * 0.006, y: center.y + rect.height * 0.008), size: NSSize(width: rect.width * 0.052, height: rect.height * 0.022), angle: 2, fill: palette.accent.withAlphaComponent(0.40), stroke: nil)
    }

    func drawBonsaiSignature(rect: NSRect, anchor: NSPoint, palette: PlantPalette) {
        let potRect = NSRect(x: anchor.x - rect.width * 0.18, y: anchor.y - rect.height * 0.045, width: rect.width * 0.36, height: max(9, rect.height * 0.05))
        let pot = NSBezierPath(roundedRect: potRect, xRadius: 3, yRadius: 3)
        color(red: 98, green: 65, blue: 48, alpha: 0.32).setFill()
        pot.fill()
        drawCurve(
            from: NSPoint(x: anchor.x, y: anchor.y - rect.height * 0.07),
            control1: NSPoint(x: anchor.x - rect.width * 0.14, y: rect.midY),
            control2: NSPoint(x: anchor.x + rect.width * 0.15, y: rect.midY - rect.height * 0.10),
            to: NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.30),
            color: palette.trunk.withAlphaComponent(0.62),
            width: max(2.4, rect.width * 0.020)
        )
    }

    func drawJapaneseMapleSignature(rect: NSRect, palette: PlantPalette) {
        for index in 0..<18 {
            let center = NSPoint(
                x: rect.minX + rect.width * (0.18 + abs(deterministicWave(seed: 2_101, index: index)) * 0.64),
                y: rect.minY + rect.height * (0.12 + abs(deterministicWave(seed: 2_117, index: index)) * 0.48)
            )
            drawLeaf(
                center: center,
                size: NSSize(width: rect.width * 0.065, height: rect.height * 0.018),
                angle: deterministicWave(seed: 2_133, index: index) * 120,
                fill: color(red: 155, green: 66, blue: 50, alpha: 0.48)
            )
        }
    }

    func drawWillowSignature(rect: NSRect, palette: PlantPalette) {
        for index in 0..<14 {
            let x = rect.minX + rect.width * (0.22 + CGFloat(index) / 13.0 * 0.56)
            let top = NSPoint(x: x, y: rect.minY + rect.height * 0.18)
            drawCurve(
                from: top,
                control1: NSPoint(x: x - 10, y: rect.midY),
                control2: NSPoint(x: x + 12, y: rect.maxY - rect.height * 0.22),
                to: NSPoint(x: x + deterministicWave(seed: 2_201, index: index) * 12, y: rect.maxY - rect.height * 0.04),
                color: palette.leafB.withAlphaComponent(0.34),
                width: 1.2
            )
        }
    }

    func drawBirchSignature(rect: NSRect, anchor: NSPoint) {
        let trunkX = anchor.x
        for index in 0..<7 {
            let y = anchor.y - rect.height * (0.10 + CGFloat(index) * 0.085)
            drawLine(
                from: NSPoint(x: trunkX - rect.width * 0.030, y: y),
                to: NSPoint(x: trunkX + rect.width * 0.034, y: y + deterministicWave(seed: 2_301, index: index) * 2),
                color: color(red: 236, green: 232, blue: 210, alpha: 0.28),
                width: 1.2
            )
        }
    }

    func drawMagnoliaSignature(rect: NSRect, palette: PlantPalette, bloom: CGFloat) {
        for index in 0..<5 {
            let center = NSPoint(
                x: rect.minX + rect.width * (0.30 + CGFloat(index) * 0.10),
                y: rect.minY + rect.height * (0.18 + abs(deterministicWave(seed: 2_401, index: index)) * 0.22)
            )
            let petals = [
                (x: -7.0, y: 1.0, angle: -24.0, width: 17.0),
                (x: -2.0, y: -5.5, angle: -5.0, width: 18.0),
                (x: 5.0, y: -3.0, angle: 18.0, width: 16.5),
                (x: 1.5, y: 4.8, angle: 44.0, width: 13.5)
            ]
            for (petalIndex, petal) in petals.enumerated() {
                let jitter = deterministicWave(seed: 2_419 + Double(index), index: petalIndex) * 1.6
                drawOval(
                    center: NSPoint(x: center.x + CGFloat(petal.x) + jitter, y: center.y + CGFloat(petal.y) - jitter * 0.25),
                    size: NSSize(width: CGFloat(petal.width) + bloom * 4, height: 6 + bloom * 2),
                    angle: CGFloat(petal.angle) + jitter,
                    fill: palette.flowerB.withAlphaComponent(0.48 + bloom * 0.22),
                    stroke: nil
                )
            }
        }
    }

    func drawOliveSignature(rect: NSRect, palette: PlantPalette) {
        for index in 0..<22 {
            let center = NSPoint(
                x: rect.minX + rect.width * (0.22 + abs(deterministicWave(seed: 2_501, index: index)) * 0.56),
                y: rect.minY + rect.height * (0.18 + abs(deterministicWave(seed: 2_517, index: index)) * 0.42)
            )
            drawLeaf(
                center: center,
                size: NSSize(width: rect.width * 0.075, height: rect.height * 0.014),
                angle: deterministicWave(seed: 2_533, index: index) * 90,
                fill: color(red: 145, green: 160, blue: 112, alpha: 0.45)
            )
        }
    }

    func drawCitrusSignature(rect: NSRect, palette: PlantPalette) {
        for index in 0..<12 {
            let center = NSPoint(
                x: rect.minX + rect.width * (0.26 + abs(deterministicWave(seed: 2_601, index: index)) * 0.48),
                y: rect.minY + rect.height * (0.20 + abs(deterministicWave(seed: 2_617, index: index)) * 0.40)
            )
            drawLeaf(
                center: center,
                size: NSSize(width: rect.width * 0.080, height: rect.height * 0.020),
                angle: deterministicWave(seed: 2_633, index: index) * 80,
                fill: palette.leafB.withAlphaComponent(0.50)
            )
            if index.isMultiple(of: 5) {
                drawOval(
                    center: NSPoint(x: center.x + 4, y: center.y + 3),
                    size: NSSize(width: 7, height: 5),
                    angle: -12,
                    fill: palette.flowerB.withAlphaComponent(0.42),
                    stroke: nil
                )
            }
        }
    }

    func drawHydrangeaSignature(rect: NSRect, palette: PlantPalette, bloom: CGFloat) {
        for stem in 0..<7 {
            let base = NSPoint(
                x: rect.minX + rect.width * (0.32 + CGFloat(stem % 4) * 0.095),
                y: rect.maxY - rect.height * (0.10 + CGFloat(stem / 4) * 0.04)
            )
            let tip = NSPoint(
                x: base.x + deterministicWave(seed: 2_681, index: stem) * rect.width * 0.045,
                y: rect.minY + rect.height * (0.20 + abs(deterministicWave(seed: 2_697, index: stem)) * 0.11)
            )
            drawCurve(
                from: base,
                control1: NSPoint(x: base.x - rect.width * 0.025, y: rect.midY),
                control2: NSPoint(x: tip.x + rect.width * 0.020, y: tip.y + rect.height * 0.08),
                to: tip,
                color: palette.stem.withAlphaComponent(0.24),
                width: 0.9
            )
            for floret in 0..<3 {
                let offsetX = deterministicWave(seed: 2_713 + Double(stem), index: floret) * rect.width * 0.040
                let offsetY = deterministicWave(seed: 2_729 + Double(stem), index: floret) * rect.height * 0.020
                drawOval(
                    center: NSPoint(x: tip.x + offsetX, y: tip.y + offsetY),
                    size: NSSize(width: rect.width * 0.050, height: rect.height * 0.018),
                    angle: deterministicWave(seed: 2_745 + Double(stem), index: floret) * 34,
                    fill: (floret.isMultiple(of: 2) ? palette.flowerA : palette.flowerB).withAlphaComponent(0.42 + bloom * 0.22),
                    stroke: nil
                )
            }
        }
    }

    func drawClusteredPetalSignature(rect: NSRect, palette: PlantPalette, bloom: CGFloat, density: Int) {
        let mainStemBase = NSPoint(x: rect.midX - rect.width * 0.035, y: rect.maxY - rect.height * 0.06)
        let bloomCenter = NSPoint(x: rect.midX + rect.width * 0.010, y: rect.minY + rect.height * 0.24)
        drawCurve(
            from: mainStemBase,
            control1: NSPoint(x: mainStemBase.x - rect.width * 0.04, y: rect.midY),
            control2: NSPoint(x: bloomCenter.x + rect.width * 0.03, y: bloomCenter.y + rect.height * 0.18),
            to: bloomCenter,
            color: palette.stem.withAlphaComponent(0.38),
            width: 1.2
        )

        let petalAnchors = [
            (x: -0.070, y: 0.000, angle: -22.0, scale: 1.08),
            (x: -0.035, y: -0.040, angle: -8.0, scale: 1.22),
            (x: 0.020, y: -0.050, angle: 9.0, scale: 1.18),
            (x: 0.065, y: -0.020, angle: 27.0, scale: 1.00),
            (x: -0.010, y: 0.030, angle: 42.0, scale: 0.92),
            (x: -0.052, y: 0.042, angle: -44.0, scale: 0.78),
            (x: 0.040, y: 0.038, angle: 36.0, scale: 0.82),
            (x: 0.004, y: -0.005, angle: 0.0, scale: 0.70)
        ]

        for index in 0..<density {
            let petal = petalAnchors[index % petalAnchors.count]
            let jitterX = deterministicWave(seed: 2_801, index: index) * rect.width * 0.012
            let jitterY = deterministicWave(seed: 2_817, index: index) * rect.height * 0.009
            drawOval(
                center: NSPoint(
                    x: bloomCenter.x + rect.width * CGFloat(petal.x) + jitterX,
                    y: bloomCenter.y + rect.height * CGFloat(petal.y) + jitterY
                ),
                size: NSSize(
                    width: rect.width * 0.072 * CGFloat(petal.scale) + bloom * 2.6,
                    height: rect.height * 0.023 * CGFloat(petal.scale) + bloom * 1.0
                ),
                angle: CGFloat(petal.angle) + deterministicWave(seed: 2_833, index: index) * 8,
                fill: (index.isMultiple(of: 2) ? palette.flowerA : palette.flowerB).withAlphaComponent(0.44 + bloom * 0.27),
                stroke: nil
            )
        }
    }

    func drawRoseSignature(rect: NSRect, palette: PlantPalette, bloom: CGFloat) {
        drawClusteredPetalSignature(rect: rect, palette: palette, bloom: bloom, density: 14)
        let center = NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.22)
        drawCurve(
            from: NSPoint(x: center.x - rect.width * 0.035, y: center.y),
            control1: NSPoint(x: center.x - rect.width * 0.005, y: center.y - rect.height * 0.030),
            control2: NSPoint(x: center.x + rect.width * 0.032, y: center.y + rect.height * 0.020),
            to: NSPoint(x: center.x - rect.width * 0.010, y: center.y + rect.height * 0.030),
            color: palette.accent.withAlphaComponent(0.38),
            width: 1.0
        )
    }

    func drawFoxgloveSignature(rect: NSRect, anchor: NSPoint, palette: PlantPalette, bloom: CGFloat) {
        let stemTop = NSPoint(x: anchor.x, y: rect.minY + rect.height * 0.10)
        drawLine(from: anchor, to: stemTop, color: palette.stem.withAlphaComponent(0.50), width: 1.5)
        for index in 0..<7 {
            let y = stemTop.y + CGFloat(index) * rect.height * 0.055
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            drawOval(
                center: NSPoint(x: stemTop.x + side * rect.width * 0.035, y: y),
                size: NSSize(width: rect.width * 0.070, height: rect.height * 0.026),
                angle: side * 18,
                fill: palette.flowerA.withAlphaComponent(0.42 + bloom * 0.24),
                stroke: palette.flowerB.withAlphaComponent(0.14)
            )
        }
    }

    func drawIrisSignature(rect: NSRect, anchor: NSPoint, palette: PlantPalette, bloom: CGFloat) {
        for index in 0..<5 {
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            drawLeaf(
                center: NSPoint(x: anchor.x + side * rect.width * 0.035 * CGFloat(index + 1), y: anchor.y - rect.height * 0.18 - CGFloat(index) * 6),
                size: NSSize(width: rect.width * 0.16, height: rect.height * 0.020),
                angle: side * (58 + CGFloat(index) * 5),
                fill: palette.leafA.withAlphaComponent(0.62)
            )
        }
        let center = NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.22)
        drawOval(center: NSPoint(x: center.x - rect.width * 0.030, y: center.y), size: NSSize(width: rect.width * 0.11, height: rect.height * 0.030), angle: -42, fill: palette.flowerA.withAlphaComponent(0.50 + bloom * 0.22), stroke: nil)
        drawOval(center: NSPoint(x: center.x + rect.width * 0.034, y: center.y + rect.height * 0.004), size: NSSize(width: rect.width * 0.10, height: rect.height * 0.028), angle: 38, fill: palette.flowerA.withAlphaComponent(0.48 + bloom * 0.20), stroke: nil)
        drawOval(center: NSPoint(x: center.x + rect.width * 0.002, y: center.y - rect.height * 0.028), size: NSSize(width: rect.width * 0.09, height: rect.height * 0.034), angle: -4, fill: palette.flowerB.withAlphaComponent(0.52 + bloom * 0.22), stroke: nil)
    }

    func drawLilySignature(rect: NSRect, palette: PlantPalette, bloom: CGFloat) {
        let center = NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.18)
        let petals = [
            (x: -0.052, y: 0.010, angle: -34.0),
            (x: -0.016, y: -0.036, angle: -10.0),
            (x: 0.034, y: -0.028, angle: 19.0),
            (x: 0.058, y: 0.016, angle: 43.0),
            (x: -0.004, y: 0.032, angle: 2.0)
        ]
        for (index, petal) in petals.enumerated() {
            drawOval(
                center: NSPoint(x: center.x + rect.width * CGFloat(petal.x), y: center.y + rect.height * CGFloat(petal.y)),
                size: NSSize(width: rect.width * 0.115, height: rect.height * 0.027),
                angle: CGFloat(petal.angle),
                fill: (index.isMultiple(of: 2) ? palette.flowerB : palette.flowerA).withAlphaComponent(0.48 + bloom * 0.24),
                stroke: nil
            )
        }
        drawLine(from: NSPoint(x: center.x - 4, y: center.y + 2), to: NSPoint(x: center.x + 5, y: center.y - 5), color: palette.accent.withAlphaComponent(0.22), width: 0.8)
    }

    func drawLavenderFieldSignature(anchor: NSPoint, width: CGFloat, palette: PlantPalette, bloom: CGFloat) {
        for index in 0..<18 {
            let x = anchor.x - width * 0.44 + CGFloat(index) / 17.0 * width * 0.88
            let top = NSPoint(x: x + deterministicWave(seed: 2_701, index: index) * 5, y: anchor.y - 18 - abs(deterministicWave(seed: 2_717, index: index)) * 22)
            drawLine(from: NSPoint(x: x, y: anchor.y - 3), to: top, color: palette.stem.withAlphaComponent(0.38), width: 0.9)
            drawOval(center: top, size: NSSize(width: 7, height: 18), angle: deterministicWave(seed: 2_733, index: index) * 18, fill: palette.flowerA.withAlphaComponent(0.36 + bloom * 0.22), stroke: nil)
        }
    }

    func drawHerbClusterSignature(anchor: NSPoint, height: CGFloat, palette: PlantPalette) {
        for index in 0..<14 {
            let side = deterministicWave(seed: 2_801, index: index)
            let base = NSPoint(x: anchor.x + side * height * 0.16, y: anchor.y - CGFloat(index % 3) * 2)
            let top = NSPoint(x: base.x + side * height * 0.05, y: base.y - height * (0.14 + abs(side) * 0.12))
            drawLine(from: base, to: top, color: palette.stem.withAlphaComponent(0.50), width: 1.0)
            drawLeaf(center: top, size: NSSize(width: height * 0.10, height: height * 0.030), angle: side * 48, fill: palette.leafB.withAlphaComponent(0.64))
        }
    }

    func drawBambooSignature(rect: NSRect, anchor: NSPoint, palette: PlantPalette) {
        for stalk in 0..<5 {
            let x = anchor.x - rect.width * 0.20 + CGFloat(stalk) * rect.width * 0.10
            let top = NSPoint(x: x + deterministicWave(seed: 2_901, index: stalk) * 4, y: rect.minY + rect.height * 0.16)
            drawLine(from: NSPoint(x: x, y: anchor.y), to: top, color: palette.stem.withAlphaComponent(0.60), width: 2.0)
            for node in 1..<5 {
                let y = anchor.y - CGFloat(node) * (anchor.y - top.y) / 5
                drawLine(from: NSPoint(x: x - 4, y: y), to: NSPoint(x: x + 4, y: y), color: palette.accent.withAlphaComponent(0.25), width: 0.9)
            }
            drawLeaf(center: NSPoint(x: top.x + 9, y: top.y + 12), size: NSSize(width: rect.width * 0.11, height: rect.height * 0.018), angle: 28, fill: palette.leafB.withAlphaComponent(0.56))
        }
    }

    func drawOrnamentalGrassSignature(anchor: NSPoint, height: CGFloat, width: CGFloat, palette: PlantPalette) {
        for index in 0..<24 {
            let offset = deterministicWave(seed: 3_001, index: index) * width * 0.36
            drawCurve(
                from: NSPoint(x: anchor.x + offset * 0.2, y: anchor.y),
                control1: NSPoint(x: anchor.x + offset * 0.45, y: anchor.y - height * 0.18),
                control2: NSPoint(x: anchor.x + offset * 0.88, y: anchor.y - height * 0.35),
                to: NSPoint(x: anchor.x + offset, y: anchor.y - height * (0.44 + abs(offset / max(1, width)) * 0.26)),
                color: palette.leafB.withAlphaComponent(0.42),
                width: 1.0
            )
        }
    }

    func drawCattailsSignature(anchor: NSPoint, height: CGFloat, width: CGFloat, palette: PlantPalette) {
        for index in 0..<7 {
            let x = anchor.x - width * 0.28 + CGFloat(index) / 6.0 * width * 0.56
            let top = NSPoint(x: x + deterministicWave(seed: 3_101, index: index) * 4, y: anchor.y - height * (0.38 + CGFloat(index % 3) * 0.06))
            drawLine(from: NSPoint(x: x, y: anchor.y), to: top, color: palette.stem.withAlphaComponent(0.50), width: 1.2)
            drawOval(center: NSPoint(x: top.x, y: top.y + 8), size: NSSize(width: 5, height: 20), angle: 0, fill: color(red: 105, green: 69, blue: 43, alpha: 0.48), stroke: nil)
        }
    }

    func drawMushroomSignature(anchor: NSPoint, width: CGFloat, palette: PlantPalette) {
        for index in 0..<8 {
            let x = anchor.x + deterministicWave(seed: 3_201, index: index) * width * 0.38
            let y = anchor.y - 4 + deterministicWave(seed: 3_217, index: index) * 8
            let stemHeight: CGFloat = 8 + CGFloat(index % 3) * 3
            drawLine(from: NSPoint(x: x, y: y), to: NSPoint(x: x, y: y - stemHeight), color: color(red: 214, green: 199, blue: 160, alpha: 0.38), width: 2.0)
            let cap = NSBezierPath()
            cap.move(to: NSPoint(x: x - 8, y: y - stemHeight))
            cap.curve(to: NSPoint(x: x + 8, y: y - stemHeight), controlPoint1: NSPoint(x: x - 5, y: y - stemHeight - 8), controlPoint2: NSPoint(x: x + 5, y: y - stemHeight - 8))
            cap.close()
            palette.flowerA.withAlphaComponent(0.36).setFill()
            cap.fill()
        }
    }

    func drawLichenSignature(anchor: NSPoint, width: CGFloat, palette: PlantPalette) {
        for index in 0..<14 {
            let center = NSPoint(
                x: anchor.x + deterministicWave(seed: 3_301, index: index) * width * 0.42,
                y: anchor.y - 3 + deterministicWave(seed: 3_317, index: index) * 10
            )
            drawOval(
                center: center,
                size: NSSize(width: 11 + CGFloat(index % 4) * 2, height: 3.5 + CGFloat(index % 3)),
                angle: deterministicWave(seed: 3_333, index: index) * 120,
                fill: color(red: 166, green: 184, blue: 135, alpha: 0.32),
                stroke: nil
            )
        }
    }

    func drawSucculentSignature(anchor: NSPoint, height: CGFloat, palette: PlantPalette) {
        let base = NSPoint(x: anchor.x, y: anchor.y - height * 0.08)
        let blades = [
            (x: -0.130, y: -0.070, angle: -62.0, scale: 0.88),
            (x: -0.075, y: -0.120, angle: -36.0, scale: 1.06),
            (x: -0.022, y: -0.155, angle: -12.0, scale: 1.16),
            (x: 0.040, y: -0.145, angle: 18.0, scale: 1.08),
            (x: 0.095, y: -0.098, angle: 42.0, scale: 0.96),
            (x: 0.020, y: -0.082, angle: 6.0, scale: 0.78),
            (x: -0.040, y: -0.075, angle: -20.0, scale: 0.72)
        ]
        for (index, blade) in blades.enumerated() {
            drawLeaf(
                center: NSPoint(x: base.x + height * CGFloat(blade.x), y: base.y + height * CGFloat(blade.y)),
                size: NSSize(width: height * 0.13 * CGFloat(blade.scale), height: height * 0.034 * CGFloat(blade.scale)),
                angle: CGFloat(blade.angle) + deterministicWave(seed: 3_369, index: index) * 5,
                fill: (index.isMultiple(of: 2) ? palette.leafB : palette.leafA).withAlphaComponent(0.56)
            )
        }
    }

    func drawPitcherPlantSignature(anchor: NSPoint, height: CGFloat, palette: PlantPalette) {
        for index in 0..<5 {
            let x = anchor.x - height * 0.16 + CGFloat(index) * height * 0.08
            let pitcherHeight = height * (0.20 + CGFloat(index % 3) * 0.035)
            let rect = NSRect(x: x - 5, y: anchor.y - pitcherHeight, width: 10, height: pitcherHeight)
            let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
            palette.leafA.withAlphaComponent(0.48).setFill()
            path.fill()
            drawOval(center: NSPoint(x: x, y: rect.minY), size: NSSize(width: 14, height: 5), angle: 0, fill: palette.flowerA.withAlphaComponent(0.34), stroke: nil)
        }
    }

    func drawWaterLilySignature(anchor: NSPoint, width: CGFloat, palette: PlantPalette, bloom: CGFloat) {
        for index in 0..<5 {
            let center = NSPoint(
                x: anchor.x + deterministicWave(seed: 3_401, index: index) * width * 0.34,
                y: anchor.y - 5 + deterministicWave(seed: 3_417, index: index) * 11
            )
            drawOval(center: center, size: NSSize(width: 22, height: 12), angle: deterministicWave(seed: 3_433, index: index) * 40, fill: palette.leafA.withAlphaComponent(0.42), stroke: nil)
        }
        let flowerCenter = NSPoint(x: anchor.x, y: anchor.y - 18)
        let petals = [
            (x: -7.0, y: 1.0, angle: -28.0),
            (x: -2.0, y: -4.0, angle: -6.0),
            (x: 4.5, y: -3.0, angle: 16.0),
            (x: 6.5, y: 2.0, angle: 36.0),
            (x: 0.0, y: 4.5, angle: 4.0)
        ]
        for (index, petal) in petals.enumerated() {
            drawOval(
                center: NSPoint(x: flowerCenter.x + CGFloat(petal.x), y: flowerCenter.y + CGFloat(petal.y)),
                size: NSSize(width: 14, height: 5),
                angle: CGFloat(petal.angle),
                fill: (index.isMultiple(of: 2) ? palette.flowerB : palette.flowerA).withAlphaComponent(0.45 + bloom * 0.22),
                stroke: nil
            )
        }
    }
}
