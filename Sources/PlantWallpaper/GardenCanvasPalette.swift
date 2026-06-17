import AppKit
import PlantGardenCore

struct PlantPalette {
    let stem: NSColor
    let trunk: NSColor
    let leafA: NSColor
    let leafB: NSColor
    let flowerA: NSColor
    let flowerB: NSColor
    let accent: NSColor
}

extension GardenCanvasView {
    func deterministicWave(seed: Double, index: Int) -> CGFloat {
        CGFloat(sin(seed * 0.017 + Double(index) * 2.399963))
    }

    func color(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> NSColor {
        NSColor(
            calibratedRed: red / 255.0,
            green: green / 255.0,
            blue: blue / 255.0,
            alpha: alpha
        )
    }

    func palette(for species: PlantSpecies, health: Double) -> PlantPalette {
        if health <= Plant.deathHealthThreshold {
            let stem = color(red: 98, green: 79, blue: 48, alpha: 0.52)
            let trunk = color(red: 76, green: 59, blue: 39, alpha: 0.58)
            let leafA = color(red: 118, green: 101, blue: 65, alpha: 0.46)
            let leafB = color(red: 143, green: 122, blue: 77, alpha: 0.42)
            let flowerA = color(red: 137, green: 105, blue: 82, alpha: 0.34)
            let flowerB = color(red: 116, green: 93, blue: 72, alpha: 0.30)
            let accent = color(red: 74, green: 57, blue: 38, alpha: 0.48)
            return PlantPalette(stem: stem, trunk: trunk, leafA: leafA, leafB: leafB, flowerA: flowerA, flowerB: flowerB, accent: accent)
        }

        let vitality = CGFloat(0.78 + health * 0.22)
        func vital(_ color: NSColor) -> NSColor {
            color.withAlphaComponent(vitality)
        }

        switch species {
        case .fern, .mossCarpet, .cloverPatch, .creepingThyme, .lichens, .blueStarCreeper, .silverFallsDichondra, .corsicanMint, .redVeinSorrelPatch, .alpineEdelweissMat:
            return PlantPalette(
                stem: vital(color(red: 76, green: 132, blue: 79, alpha: 1)),
                trunk: vital(color(red: 90, green: 80, blue: 55, alpha: 1)),
                leafA: vital(color(red: 69, green: 151, blue: 88, alpha: 1)),
                leafB: vital(color(red: 131, green: 184, blue: 94, alpha: 1)),
                flowerA: vital(color(red: 226, green: 220, blue: 130, alpha: 1)),
                flowerB: vital(color(red: 185, green: 220, blue: 147, alpha: 1)),
                accent: vital(color(red: 38, green: 75, blue: 45, alpha: 1))
            )
        case .lavender, .lavenderField, .wisteria, .ghostOrchid, .jadeVine, .queenOfTheNight, .chocolateCosmos:
            return PlantPalette(
                stem: vital(color(red: 82, green: 128, blue: 83, alpha: 1)),
                trunk: vital(color(red: 101, green: 78, blue: 61, alpha: 1)),
                leafA: vital(color(red: 104, green: 160, blue: 107, alpha: 1)),
                leafB: vital(color(red: 147, green: 178, blue: 124, alpha: 1)),
                flowerA: vital(color(red: 156, green: 119, blue: 216, alpha: 1)),
                flowerB: vital(color(red: 213, green: 182, blue: 244, alpha: 1)),
                accent: vital(color(red: 74, green: 48, blue: 113, alpha: 1))
            )
        case .tulip, .poppy, .peony, .rose, .corpseFlower:
            return PlantPalette(
                stem: vital(color(red: 78, green: 139, blue: 80, alpha: 1)),
                trunk: vital(color(red: 105, green: 75, blue: 54, alpha: 1)),
                leafA: vital(color(red: 91, green: 164, blue: 83, alpha: 1)),
                leafB: vital(color(red: 141, green: 188, blue: 84, alpha: 1)),
                flowerA: vital(color(red: 236, green: 87, blue: 118, alpha: 1)),
                flowerB: vital(color(red: 255, green: 170, blue: 112, alpha: 1)),
                accent: vital(color(red: 249, green: 220, blue: 91, alpha: 1))
            )
        case .sunflower, .dwarfCitrus, .waterLily, .saffronCrocus, .glassGemCorn:
            return PlantPalette(
                stem: vital(color(red: 91, green: 139, blue: 71, alpha: 1)),
                trunk: vital(color(red: 115, green: 77, blue: 43, alpha: 1)),
                leafA: vital(color(red: 74, green: 145, blue: 71, alpha: 1)),
                leafB: vital(color(red: 126, green: 174, blue: 74, alpha: 1)),
                flowerA: vital(color(red: 247, green: 204, blue: 54, alpha: 1)),
                flowerB: vital(color(red: 255, green: 155, blue: 49, alpha: 1)),
                accent: vital(color(red: 91, green: 58, blue: 32, alpha: 1))
            )
        case .cherryTree, .dogwood, .magnolia, .jasmine, .orchid, .lily, .silkFlossTree:
            return PlantPalette(
                stem: vital(color(red: 86, green: 134, blue: 76, alpha: 1)),
                trunk: vital(color(red: 102, green: 73, blue: 58, alpha: 1)),
                leafA: vital(color(red: 76, green: 145, blue: 88, alpha: 1)),
                leafB: vital(color(red: 141, green: 181, blue: 103, alpha: 1)),
                flowerA: vital(color(red: 255, green: 184, blue: 206, alpha: 1)),
                flowerB: vital(color(red: 247, green: 223, blue: 221, alpha: 1)),
                accent: vital(color(red: 109, green: 70, blue: 74, alpha: 1))
            )
        case .mapleTree, .japaneseMaple, .bonsai, .birch, .rainbowEucalyptus:
            return PlantPalette(
                stem: vital(color(red: 94, green: 125, blue: 77, alpha: 1)),
                trunk: vital(color(red: 101, green: 75, blue: 55, alpha: 1)),
                leafA: vital(color(red: 76, green: 138, blue: 82, alpha: 1)),
                leafB: vital(color(red: 188, green: 139, blue: 70, alpha: 1)),
                flowerA: vital(color(red: 213, green: 91, blue: 69, alpha: 1)),
                flowerB: vital(color(red: 247, green: 181, blue: 76, alpha: 1)),
                accent: vital(color(red: 87, green: 54, blue: 36, alpha: 1))
            )
        case .pineTree, .willow, .oliveTree, .bamboo, .ivy, .baobab, .dragonBloodTree, .monkeyPuzzleTree:
            return PlantPalette(
                stem: vital(color(red: 50, green: 112, blue: 77, alpha: 1)),
                trunk: vital(color(red: 97, green: 73, blue: 49, alpha: 1)),
                leafA: vital(color(red: 45, green: 111, blue: 82, alpha: 1)),
                leafB: vital(color(red: 71, green: 146, blue: 91, alpha: 1)),
                flowerA: vital(color(red: 185, green: 214, blue: 131, alpha: 1)),
                flowerB: vital(color(red: 146, green: 183, blue: 116, alpha: 1)),
                accent: vital(color(red: 23, green: 65, blue: 51, alpha: 1))
            )
        case .monstera, .herbCluster, .succulent, .pitcherPlant, .determinateTomato, .sweetPepper, .peaVines, .stringBeans, .cucumberVine, .rosemary, .thyme, .oregano, .sage, .alocasiaDragonScale, .ravenZZPlant, .prayerPlant, .staghornFern, .blackCoralColocasia, .dragonFruitCactus, .purpleBasil, .shiso, .wasabi, .alpineStrawberry, .cucamelon:
            return PlantPalette(
                stem: vital(color(red: 61, green: 126, blue: 80, alpha: 1)),
                trunk: vital(color(red: 94, green: 76, blue: 54, alpha: 1)),
                leafA: vital(color(red: 39, green: 128, blue: 86, alpha: 1)),
                leafB: vital(color(red: 88, green: 169, blue: 96, alpha: 1)),
                flowerA: vital(color(red: 239, green: 220, blue: 166, alpha: 1)),
                flowerB: vital(color(red: 226, green: 242, blue: 183, alpha: 1)),
                accent: vital(color(red: 22, green: 82, blue: 55, alpha: 1))
            )
        case .wildflowerMeadow, .hydrangea, .foxglove, .iris, .ornamentalGrass, .cattails, .mushrooms:
            return PlantPalette(
                stem: vital(color(red: 83, green: 143, blue: 83, alpha: 1)),
                trunk: vital(color(red: 97, green: 75, blue: 52, alpha: 1)),
                leafA: vital(color(red: 77, green: 151, blue: 83, alpha: 1)),
                leafB: vital(color(red: 140, green: 185, blue: 91, alpha: 1)),
                flowerA: vital(color(red: 241, green: 128, blue: 149, alpha: 1)),
                flowerB: vital(color(red: 255, green: 217, blue: 92, alpha: 1)),
                accent: vital(color(red: 122, green: 90, blue: 178, alpha: 1))
            )
        }
    }

    func drawLeafVein(center: NSPoint, size: NSSize, angle: CGFloat, color: NSColor) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: angle * .pi / 180)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: -size.width / 2, y: 0))
        path.line(to: NSPoint(x: size.width / 2, y: 0))
        color.setStroke()
        path.lineWidth = max(0.7, size.height)
        path.lineCapStyle = .round
        path.stroke()
        context.restoreGState()
    }
}
