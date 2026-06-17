import AppKit
import PlantGardenCore

/// A temporary, in-canvas presentation for a selected plant. This keeps the
/// garden layout untouched while letting the plant come forward as a larger
/// specimen with a future video exploration panel.
extension GardenCanvasView {
    func drawPlantExplorerIfNeeded() {
        guard let plant = plantExplorerPlant() else {
            return
        }

        let rect = plantExplorerRect(for: plant)
        drawPlantExplorerBackdrop(excluding: rect)
        drawPlantExplorerPanel(in: rect, plant: plant)
    }

    func plantExplorerContains(_ point: NSPoint) -> Bool {
        plantExplorerRectIfVisible()?.contains(point) == true
    }

    func plantExplorerRectIfVisible() -> NSRect? {
        plantExplorerPlant().map { plantExplorerRect(for: $0) }
    }

    func plantExplorerCloseRectIfVisible() -> NSRect? {
        plantExplorerRectIfVisible().map(plantExplorerCloseRect(in:))
    }

    func plantExplorerCloseHitPointForSelfTest() -> NSPoint? {
        plantExplorerCloseRectIfVisible().map { NSPoint(x: $0.midX, y: $0.midY) }
    }

    func isPlantExplorerVisibleForSelfTest() -> Bool {
        plantExplorerPlant() != nil
    }

    private func plantExplorerPlant() -> Plant? {
        guard let plantExplorerPlantID,
              let plant = store.state.plants.first(where: { $0.id == plantExplorerPlantID }),
              plant.screenIndex == screenIndex,
              canDisplay(plant) else {
            return nil
        }

        return plant
    }

    private func plantExplorerRect(for _: Plant) -> NSRect {
        let viewport = inspectorViewportRect()
        let width = min(viewport.width, max(560, min(1080, viewport.width * 0.88)))
        let height = min(viewport.height, max(420, min(680, viewport.height * 0.84)))
        return NSRect(
            x: viewport.midX - width / 2,
            y: viewport.midY - height / 2,
            width: width,
            height: height
        ).integral
    }

    private func plantExplorerCloseRect(in rect: NSRect) -> NSRect {
        NSRect(x: rect.maxX - 48, y: rect.minY + 16, width: 30, height: 30)
    }

    private func drawPlantExplorerBackdrop(excluding rect: NSRect) {
        color(red: 9, green: 15, blue: 12, alpha: 0.30).setFill()
        bounds.fill()

        let glowRect = rect.insetBy(dx: -20, dy: -20)
        let glow = NSBezierPath(roundedRect: glowRect, xRadius: 32, yRadius: 32)
        color(red: 246, green: 239, blue: 205, alpha: 0.10).setFill()
        glow.fill()
    }

    private func drawPlantExplorerPanel(in rect: NSRect, plant: Plant) {
        let panel = NSBezierPath(roundedRect: rect, xRadius: 22, yRadius: 22)
        color(red: 250, green: 247, blue: 235, alpha: 0.97).setFill()
        panel.fill()
        color(red: 82, green: 104, blue: 78, alpha: 0.28).setStroke()
        panel.lineWidth = 1.2
        panel.stroke()

        drawPlantExplorerCloseButton(in: plantExplorerCloseRect(in: rect))

        let content = rect.insetBy(dx: 30, dy: 30)
        let isWide = content.width >= 740
        if isWide {
            let plantWidth = content.width * 0.44
            let gap: CGFloat = 26
            let plantRect = NSRect(x: content.minX, y: content.minY + 16, width: plantWidth, height: content.height - 18)
            let videoRect = NSRect(
                x: plantRect.maxX + gap,
                y: content.minY + 16,
                width: content.maxX - plantRect.maxX - gap,
                height: content.height - 18
            )
            drawPlantExplorerSpecimen(plant, in: plantRect)
            drawPlantExplorerVideoPlaceholder(in: videoRect, plant: plant)
        } else {
            let plantRect = NSRect(x: content.minX, y: content.minY + 10, width: content.width, height: content.height * 0.50)
            let videoRect = NSRect(x: content.minX, y: plantRect.maxY + 14, width: content.width, height: content.maxY - plantRect.maxY - 14)
            drawPlantExplorerSpecimen(plant, in: plantRect)
            drawPlantExplorerVideoPlaceholder(in: videoRect, plant: plant)
        }
    }

    private func drawPlantExplorerCloseButton(in rect: NSRect) {
        let path = NSBezierPath(ovalIn: rect)
        color(red: 244, green: 239, blue: 221, alpha: 0.98).setFill()
        path.fill()
        color(red: 113, green: 126, blue: 102, alpha: 0.34).setStroke()
        path.lineWidth = 1
        path.stroke()

        guard let image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close") else {
            return
        }

        image.isTemplate = true
        color(red: 48, green: 56, blue: 45, alpha: 0.94).set()
        let iconRect = rect.insetBy(dx: 8, dy: 8)
        image.draw(
            in: iconRect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func drawPlantExplorerSpecimen(_ plant: Plant, in rect: NSRect) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: color(red: 84, green: 98, blue: 75, alpha: 0.78)
        ]
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: color(red: 27, green: 42, blue: 31, alpha: 0.98)
        ]

        "PLANT SPOTLIGHT".draw(in: NSRect(x: rect.minX, y: rect.minY, width: rect.width - 12, height: 18), withAttributes: titleAttributes)
        plant.nickname.draw(in: NSRect(x: rect.minX, y: rect.minY + 24, width: rect.width - 12, height: 36), withAttributes: nameAttributes)

        let stage = PlantAssetStage(growth: plant.growth, stageCount: PlantAssetLibrary.stageCount)
        let imageRect = NSRect(x: rect.minX, y: rect.minY + 74, width: rect.width, height: rect.height - 150)
        drawPlantExplorerImage(plant, stage: stage, in: imageRect)
        drawPlantExplorerStats(plant, stage: stage, in: NSRect(x: rect.minX, y: rect.maxY - 58, width: rect.width, height: 48))
    }

    private func drawPlantExplorerImage(_ plant: Plant, stage: PlantAssetStage, in rect: NSRect) {
        guard let image = PlantDisplayAssetResolver.image(
            for: plant,
            stageIndex: stage.index,
            customAssets: store.customPlantAssets
        ),
              image.size.height > 0 else {
            return
        }

        let maxHeight = rect.height * 0.92
        let maxWidth = rect.width * 0.88
        let aspect = image.size.width / max(1, image.size.height)
        let imageHeight = min(maxHeight, maxWidth / aspect)
        let imageWidth = imageHeight * aspect
        let drawRect = NSRect(
            x: rect.midX - imageWidth / 2,
            y: rect.maxY - imageHeight,
            width: imageWidth,
            height: imageHeight
        )

        let shadowRect = NSRect(
            x: drawRect.midX - drawRect.width * 0.36,
            y: drawRect.maxY - max(16, drawRect.height * 0.035),
            width: drawRect.width * 0.72,
            height: max(18, drawRect.height * 0.08)
        )
        let shadow = NSBezierPath(ovalIn: shadowRect)
        color(red: 32, green: 38, blue: 27, alpha: 0.16).setFill()
        shadow.fill()

        drawRealisticAsset(image, in: drawRect, opacity: 1)
    }

    private func drawPlantExplorerStats(_ plant: Plant, stage: PlantAssetStage, in rect: NSRect) {
        let stats = [
            ("Stage", "\(stage.index + 1)/\(PlantAssetLibrary.stageCount)"),
            ("Growth", "\(Int((plant.growth * 100).rounded()))%"),
            ("Water", "\(Int((plant.hydration * 100).rounded()))%"),
            ("Type", plant.species.kind.displayName)
        ]

        let gap: CGFloat = 8
        let chipWidth = max(68, (rect.width - gap * CGFloat(stats.count - 1)) / CGFloat(stats.count))
        for (index, stat) in stats.enumerated() {
            let chip = NSRect(
                x: rect.minX + CGFloat(index) * (chipWidth + gap),
                y: rect.minY,
                width: chipWidth,
                height: rect.height
            )
            drawPlantExplorerStatChip(label: stat.0, value: stat.1, in: chip)
        }
    }

    private func drawPlantExplorerStatChip(label: String, value: String, in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        color(red: 241, green: 235, blue: 216, alpha: 0.90).setFill()
        path.fill()
        color(red: 116, green: 136, blue: 101, alpha: 0.20).setStroke()
        path.lineWidth = 1
        path.stroke()

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: color(red: 96, green: 107, blue: 86, alpha: 0.76)
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: color(red: 35, green: 49, blue: 35, alpha: 0.96)
        ]

        label.uppercased().draw(in: NSRect(x: rect.minX + 10, y: rect.minY + 7, width: rect.width - 20, height: 13), withAttributes: labelAttributes)
        value.draw(in: NSRect(x: rect.minX + 10, y: rect.minY + 24, width: rect.width - 20, height: 18), withAttributes: valueAttributes)
    }

    private func drawPlantExplorerVideoPlaceholder(in rect: NSRect, plant: Plant) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: color(red: 86, green: 98, blue: 78, alpha: 0.78)
        ]
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 25, weight: .semibold),
            .foregroundColor: color(red: 29, green: 40, blue: 33, alpha: 0.98)
        ]
        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = 3
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: color(red: 62, green: 74, blue: 57, alpha: 0.84),
            .paragraphStyle: bodyStyle
        ]

        "AI FLY-THROUGH".draw(in: NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: 18), withAttributes: titleAttributes)
        "Immersive exploration".draw(in: NSRect(x: rect.minX, y: rect.minY + 24, width: rect.width, height: 32), withAttributes: headingAttributes)

        let videoRect = NSRect(x: rect.minX, y: rect.minY + 72, width: rect.width, height: min(310, rect.height * 0.58))
        drawVideoComingSoonImage(in: videoRect)

        let copy = "A generated macro fly-through of \(plant.nickname) will live here: stem-level passes, leaf detail, bloom close-ups, and growth-story narration."
        copy.draw(in: NSRect(x: rect.minX + 2, y: videoRect.maxY + 18, width: rect.width - 4, height: 60), withAttributes: bodyAttributes)

        drawPlantExplorerTimelinePreview(in: NSRect(x: rect.minX, y: rect.maxY - 58, width: rect.width, height: 44))
    }

    private func drawVideoComingSoonImage(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16)
        color(red: 29, green: 39, blue: 34, alpha: 0.98).setFill()
        path.fill()

        let gradient = NSGradient(colors: [
            color(red: 79, green: 121, blue: 94, alpha: 0.36),
            color(red: 17, green: 25, blue: 23, alpha: 0.02)
        ])
        gradient?.draw(in: path, angle: -34)

        color(red: 230, green: 239, blue: 213, alpha: 0.10).setStroke()
        path.lineWidth = 1.2
        path.stroke()

        for index in 0..<5 {
            let y = rect.minY + rect.height * (0.20 + CGFloat(index) * 0.14)
            drawLine(
                from: NSPoint(x: rect.minX + 22, y: y),
                to: NSPoint(x: rect.maxX - 22, y: y + CGFloat(index % 2 == 0 ? -10 : 8)),
                color: color(red: 212, green: 238, blue: 200, alpha: 0.055),
                width: 1
            )
        }

        let playRect = NSRect(x: rect.midX - 35, y: rect.midY - 35, width: 70, height: 70)
        color(red: 238, green: 246, blue: 225, alpha: 0.16).setFill()
        NSBezierPath(ovalIn: playRect).fill()
        color(red: 238, green: 246, blue: 225, alpha: 0.82).setStroke()
        NSBezierPath(ovalIn: playRect.insetBy(dx: 1, dy: 1)).stroke()

        let triangle = NSBezierPath()
        triangle.move(to: NSPoint(x: playRect.midX - 8, y: playRect.midY - 15))
        triangle.line(to: NSPoint(x: playRect.midX - 8, y: playRect.midY + 15))
        triangle.line(to: NSPoint(x: playRect.midX + 16, y: playRect.midY))
        triangle.close()
        color(red: 244, green: 250, blue: 232, alpha: 0.92).setFill()
        triangle.fill()

        let textStyle = NSMutableParagraphStyle()
        textStyle.alignment = .center
        let comingSoonAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: color(red: 232, green: 243, blue: 218, alpha: 0.86),
            .paragraphStyle: textStyle
        ]
        "VIDEO COMING SOON".draw(
            in: NSRect(x: rect.minX + 20, y: rect.maxY - 40, width: rect.width - 40, height: 18),
            withAttributes: comingSoonAttributes
        )
    }

    private func drawPlantExplorerTimelinePreview(in rect: NSRect) {
        let dotCount = 5
        let railY = rect.midY
        drawLine(
            from: NSPoint(x: rect.minX + 13, y: railY),
            to: NSPoint(x: rect.maxX - 13, y: railY),
            color: color(red: 116, green: 139, blue: 103, alpha: 0.22),
            width: 2
        )

        for index in 0..<dotCount {
            let fraction = CGFloat(index) / CGFloat(dotCount - 1)
            let center = NSPoint(x: rect.minX + 13 + (rect.width - 26) * fraction, y: railY)
            let dot = NSRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
            color(red: 96, green: 133, blue: 88, alpha: index == 0 ? 0.82 : 0.34).setFill()
            NSBezierPath(ovalIn: dot).fill()
        }
    }
}
