import AppKit
import PlantGardenCore

enum PlantRenderPosture {
    static func rotationDegrees(for plant: Plant) -> CGFloat {
        0
    }
}

/// Per-plant rendering: stage-asset drawing, root zones, soil cues, and the
/// realistic-plant composition pipeline.
extension GardenCanvasView {
    func drawPlant(_ plant: Plant, profile: GardenSceneVisualProfile) {
        guard canDisplay(plant) else {
            return
        }

        let anchor = anchorPoint(for: plant)
        let plantHeight = height(for: plant)
        let selected = store.selectedPlantID == plant.id

        if drawRealisticPlant(
            plant,
            anchor: anchor,
            height: plantHeight,
            selected: selected,
            profile: profile
        ) {
            return
        }
    }

    func drawRealisticPlant(
        _ plant: Plant,
        anchor: NSPoint,
        height: CGFloat,
        selected: Bool,
        profile: GardenSceneVisualProfile
    ) -> Bool {
        let assetStage = PlantAssetStage(growth: plant.growth, stageCount: PlantAssetLibrary.stageCount)
        guard let image = PlantDisplayAssetResolver.image(
            for: plant,
            stageIndex: assetStage.index,
            customAssets: store.customPlantAssets
        ),
              image.size.height > 0 else {
            return false
        }

        let targetHeight = realisticHeight(for: plant, baseHeight: height)
        let widthFactor = youngPlantWidthFactor(for: plant)
        let targetWidth = targetHeight * image.size.width / image.size.height * widthFactor
        let stress = stressLevel(for: plant)
        let droop = stress * targetHeight * (plant.isDead ? 0.095 : 0.055)
        let rotationDegrees = PlantRenderPosture.rotationDegrees(for: plant)
        // When the plant sits on a hand-painted soil patch, sink its base into
        // the dirt. The view is flipped, so a positive offset moves the anchor
        // downward. The contact shadow and root tuck stay at the original
        // ground plane so the depression reads.
        let soilSink = soilSinkDepth(for: plant)
        let sunkAnchor = NSPoint(x: anchor.x, y: anchor.y + soilSink)
        let rect = NSRect(
            x: sunkAnchor.x - targetWidth / 2,
            y: sunkAnchor.y - targetHeight + droop,
            width: targetWidth,
            height: targetHeight
        )
        let nextImage = plant.customAssetID == nil
            ? assetStage.nextIndex.flatMap {
                PlantDisplayAssetResolver.image(
                    for: plant,
                    stageIndex: $0,
                    customAssets: store.customPlantAssets
                )
            }
            : nil
        let assetComposite = PlantAssetRenderComposite(plant: plant, assetStage: assetStage)
        let hasNextImage = (nextImage?.size.height ?? 0) > 0
        let nextBlendOpacity = hasNextImage
            ? CGFloat(assetComposite.nextStageOverlayOpacity)
            : 0
        let currentStageOpacity = CGFloat(assetComposite.currentStageOpacity)
        let projection = profile.lightProjection(from: store.state.lightProjection(at: currentDateProvider()))
        drawSceneDirectionalShadow(
            for: plant,
            anchor: anchor,
            width: targetWidth,
            height: targetHeight,
            selected: selected,
            projection: projection,
            profile: profile
        )
        drawRootContactIntegration(for: plant, anchor: anchor, width: targetWidth, profile: profile)
        guard let context = NSGraphicsContext.current?.cgContext else {
            drawRealisticAsset(image, in: rect, opacity: currentStageOpacity)
            if let nextImage, nextBlendOpacity > 0 {
                drawRealisticAsset(
                    nextImage,
                    in: realisticAssetRect(
                        for: nextImage,
                        anchor: sunkAnchor,
                        targetHeight: targetHeight,
                        widthFactor: widthFactor,
                        droop: droop
                    ),
                    opacity: nextBlendOpacity
                )
            }
            drawForegroundOcclusion(for: plant, rect: rect, anchor: sunkAnchor, profile: profile)
            return true
        }

        context.saveGState()
        let shadow = NSShadow()
        shadow.shadowColor = color(red: 20, green: 28, blue: 21, alpha: selected ? 0.34 : 0.24)
        shadow.shadowBlurRadius = plant.species.kind == .tree ? 18 : 12
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        shadow.set()
        drawRealisticAssetTransformed(
            image,
            rect: rect,
            anchor: sunkAnchor,
            rotationDegrees: rotationDegrees,
            opacity: currentStageOpacity
        )
        if let nextImage, nextBlendOpacity > 0 {
            drawRealisticAssetTransformed(
                nextImage,
                rect: realisticAssetRect(
                    for: nextImage,
                    anchor: sunkAnchor,
                    targetHeight: targetHeight,
                    widthFactor: widthFactor,
                    droop: droop
                ),
                anchor: sunkAnchor,
                rotationDegrees: rotationDegrees,
                opacity: nextBlendOpacity
            )
        }
        context.restoreGState()
        drawPlantLightReductionOverlayIfNeeded(
            image,
            rect: rect,
            anchor: sunkAnchor,
            rotationDegrees: rotationDegrees,
            opacity: currentStageOpacity
        )
        if let nextImage, nextBlendOpacity > 0 {
            drawPlantLightReductionOverlayIfNeeded(
                nextImage,
                rect: realisticAssetRect(
                    for: nextImage,
                    anchor: sunkAnchor,
                    targetHeight: targetHeight,
                    widthFactor: widthFactor,
                    droop: droop
                ),
                anchor: sunkAnchor,
                rotationDegrees: rotationDegrees,
                opacity: nextBlendOpacity
            )
        }
        drawForegroundOcclusion(for: plant, rect: rect, anchor: sunkAnchor, profile: profile)

        return true
    }

    func realisticAssetRect(
        for image: NSImage,
        anchor: NSPoint,
        targetHeight: CGFloat,
        widthFactor: CGFloat,
        droop: CGFloat
    ) -> NSRect {
        let targetWidth = targetHeight * image.size.width / max(1, image.size.height) * widthFactor
        return NSRect(
            x: anchor.x - targetWidth / 2,
            y: anchor.y - targetHeight + droop,
            width: targetWidth,
            height: targetHeight
        )
    }

    func drawRealisticAssetTransformed(
        _ image: NSImage,
        rect: NSRect,
        anchor: NSPoint,
        rotationDegrees: CGFloat,
        opacity: CGFloat
    ) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            drawRealisticAsset(image, in: rect, opacity: opacity)
            return
        }

        context.saveGState()
        context.translateBy(x: anchor.x, y: anchor.y)
        context.rotate(by: rotationDegrees * .pi / 180)
        let localRect = NSRect(
            x: rect.minX - anchor.x,
            y: rect.minY - anchor.y,
            width: rect.width,
            height: rect.height
        )
        drawRealisticAsset(image, in: localRect, opacity: opacity)
        context.restoreGState()
    }

    func drawRealisticAsset(_ image: NSImage, in rect: NSRect, opacity: CGFloat) {
        // Draw from a cached pre-shrunk copy; the remaining size delta is
        // ≤32pt so medium interpolation is visually identical to running
        // high-quality Lanczos against the full-resolution source.
        let resampled = PlantAssetLibrary.shared.resampledImage(
            for: image,
            targetHeight: rect.height,
            backingScale: window?.backingScaleFactor ?? 2
        )
        resampled.draw(
            in: rect,
            from: NSRect(origin: .zero, size: resampled.size),
            operation: .sourceOver,
            fraction: opacity,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.medium]
        )
    }

    func drawPlantLightReductionOverlayIfNeeded(
        _ image: NSImage,
        rect: NSRect,
        anchor: NSPoint,
        rotationDegrees: CGFloat,
        opacity: CGFloat
    ) {
        let overlay = store.state.plantLightOverlay(at: currentDateProvider())
        let overlayOpacity = CGFloat(overlay.opacity) * opacity
        guard overlayOpacity > 0.001,
              let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.saveGState()
        context.translateBy(x: anchor.x, y: anchor.y)
        context.rotate(by: rotationDegrees * .pi / 180)
        let localRect = NSRect(
            x: rect.minX - anchor.x,
            y: rect.minY - anchor.y,
            width: rect.width,
            height: rect.height
        )
        drawPlantLightReductionOverlay(image, in: localRect, opacity: overlayOpacity)
        context.restoreGState()
    }

    func drawPlantLightReductionOverlay(_ image: NSImage, in rect: NSRect, opacity: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let resampled = PlantAssetLibrary.shared.resampledImage(
            for: image,
            targetHeight: rect.height,
            backingScale: window?.backingScaleFactor ?? 2
        )

        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        color(red: 5, green: 7, blue: 13, alpha: opacity).setFill()
        rect.fill()
        resampled.draw(
            in: rect,
            from: NSRect(origin: .zero, size: resampled.size),
            operation: .destinationIn,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.medium]
        )
        context.endTransparencyLayer()
        context.restoreGState()
    }

    func youngPlantWidthFactor(for plant: Plant) -> CGFloat {
        switch plant.growthStage {
        case .dead:
            return 0.82
        case .seedling:
            return 0.54
        case .sprout:
            return 0.72
        case .young:
            return 0.88
        case .mature, .blooming:
            return 1.0
        }
    }

    func stressLevel(for plant: Plant) -> CGFloat {
        if plant.isDead {
            return 1
        }

        let vitality = min(plant.health, plant.hydration)
        return CGFloat(max(0, min(1, 1 - vitality)))
    }

}
