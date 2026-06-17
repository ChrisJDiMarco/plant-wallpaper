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

    func tendingIntensity(for plant: Plant, duration: TimeInterval = 12) -> CGFloat {
        let elapsed = Date().timeIntervalSince(plant.lastTendedAt)
        guard elapsed >= 0 && elapsed < duration else {
            return 0
        }

        return CGFloat(1 - elapsed / duration)
    }

    func drawWetSoilIfNeeded(for plant: Plant, anchor: NSPoint, width: CGFloat) {
        let recentTending = tendingIntensity(for: plant, duration: 18)
        let hydrationWetness = max(0, CGFloat(plant.hydration) - 0.78) / 0.22
        let wetness = min(1, max(recentTending, hydrationWetness * 0.45))
        guard wetness > 0.03 else {
            return
        }

        let shadowWidth = width * (plant.species.kind == .tree ? 0.45 : 0.70)
        let rect = NSRect(
            x: anchor.x - shadowWidth / 2,
            y: anchor.y - max(8, shadowWidth * 0.08),
            width: shadowWidth,
            height: max(16, shadowWidth * 0.16)
        )
        let path = NSBezierPath(ovalIn: rect)
        color(red: 42, green: 31, blue: 23, alpha: 0.10 + wetness * 0.14).setFill()
        path.fill()
        color(red: 116, green: 92, blue: 63, alpha: wetness * 0.12).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    func drawRootZone(for plant: Plant, anchor: NSPoint, width: CGFloat) {
        let rootZone = plant.rootZone
        let zoneWidth = width * CGFloat(rootZone.radiusMultiplier)
        let zoneHeight = max(12, zoneWidth * (plant.species.kind == .tree ? 0.16 : 0.20))
        let rect = NSRect(
            x: anchor.x - zoneWidth / 2,
            y: anchor.y - zoneHeight * 0.58,
            width: zoneWidth,
            height: zoneHeight
        )
        let soilAlpha = 0.025 + CGFloat(rootZone.soilDarkness) * 0.055
        let path = NSBezierPath(ovalIn: rect)
        color(red: 67, green: 48, blue: 32, alpha: soilAlpha).setFill()
        path.fill()

        if rootZone.moistureSheen > 0 {
            let sheen = NSBezierPath(ovalIn: rect.insetBy(dx: zoneWidth * 0.16, dy: zoneHeight * 0.24))
            color(red: 72, green: 63, blue: 46, alpha: CGFloat(rootZone.moistureSheen) * 0.030).setFill()
            sheen.fill()
        }

        drawRootZoneTexture(for: plant, in: rect, detailCount: rootZone.surfaceDetailCount)
    }

    func drawRootZoneTexture(for plant: Plant, in rect: NSRect, detailCount: Int) {
        guard detailCount > 0 else {
            return
        }

        for index in 0..<detailCount {
            let xWave = deterministicWave(seed: plant.swaySeed + 2_011, index: index)
            let yWave = deterministicWave(seed: plant.swaySeed + 2_213, index: index)
            let center = NSPoint(
                x: rect.midX + xWave * rect.width * 0.40,
                y: rect.midY + yWave * rect.height * 0.28
            )
            let angle = deterministicWave(seed: plant.swaySeed + 2_419, index: index) * 80

            let path = NSBezierPath()
            path.move(to: NSPoint(x: center.x - 2.0, y: center.y))
            path.line(to: NSPoint(
                x: center.x + cos(angle * .pi / 180) * (2.8 + CGFloat(index % 3)),
                y: center.y + sin(angle * .pi / 180) * (0.7 + CGFloat(index % 2) * 0.3)
            ))
            (index.isMultiple(of: 2)
                ? color(red: 118, green: 83, blue: 44, alpha: 0.080)
                : color(red: 67, green: 91, blue: 48, alpha: 0.055)
            ).setStroke()
            path.lineWidth = 0.55
            path.stroke()
        }
    }

    func drawBedAffinityCue(
        for plant: Plant,
        anchor: NSPoint,
        width: CGFloat,
        affinity: PlantBedAffinity
    ) {
        let cueWidth = width * (plant.species.kind == .tree ? 0.50 : 0.72)
        let cueHeight = max(12, cueWidth * 0.14)
        let cueRect = NSRect(
            x: anchor.x - cueWidth / 2,
            y: anchor.y - cueHeight * 0.62,
            width: cueWidth,
            height: cueHeight
        )

        switch affinity.fit {
        case .rooted:
            guard plant.health > 0.45 else {
                return
            }
            let path = NSBezierPath(ovalIn: cueRect.insetBy(dx: cueWidth * 0.18, dy: cueHeight * 0.24))
            color(red: 128, green: 166, blue: 84, alpha: 0.050).setFill()
            path.fill()
        case .edge:
            let path = NSBezierPath(ovalIn: cueRect.insetBy(dx: cueWidth * 0.08, dy: cueHeight * 0.16))
            color(red: 193, green: 145, blue: 72, alpha: 0.090).setStroke()
            path.lineWidth = 1.0
            path.stroke()
        case .support:
            guard plant.health > 0.36 else {
                return
            }
            let path = NSBezierPath(ovalIn: cueRect.insetBy(dx: cueWidth * 0.24, dy: cueHeight * 0.32))
            color(red: 96, green: 151, blue: 91, alpha: 0.045).setStroke()
            path.lineWidth = 0.9
            path.stroke()
        case .exposed:
            let path = NSBezierPath(ovalIn: cueRect.insetBy(dx: -cueWidth * 0.02, dy: -cueHeight * 0.04))
            color(red: 112, green: 74, blue: 43, alpha: 0.115).setFill()
            path.fill()
            color(red: 83, green: 52, blue: 32, alpha: 0.155).setStroke()
            path.lineWidth = 0.9
            path.stroke()

            for index in 0..<5 {
                let x = cueRect.midX + deterministicWave(seed: plant.swaySeed + 10_103, index: index) * cueRect.width * 0.36
                let y = cueRect.midY + deterministicWave(seed: plant.swaySeed + 10_307, index: index) * cueRect.height * 0.22
                drawCurve(
                    from: NSPoint(x: x - cueRect.width * 0.030, y: y - cueRect.height * 0.02),
                    control1: NSPoint(x: x - cueRect.width * 0.010, y: y - cueRect.height * 0.20),
                    control2: NSPoint(x: x + cueRect.width * 0.010, y: y + cueRect.height * 0.20),
                    to: NSPoint(x: x + cueRect.width * 0.030, y: y + cueRect.height * 0.02),
                    color: color(red: 64, green: 40, blue: 25, alpha: 0.19),
                    width: 0.85
                )
            }
        }
    }

    func drawMoisturePreferenceCue(
        for plant: Plant,
        anchor: NSPoint,
        width: CGFloat,
        moisture: PlantMoisturePreference
    ) {
        guard moisture.fit != .ideal else {
            return
        }

        let cueWidth = width * (plant.species.kind == .tree ? 0.46 : 0.66)
        let cueHeight = max(12, cueWidth * 0.13)
        let cueRect = NSRect(
            x: anchor.x - cueWidth / 2,
            y: anchor.y - cueHeight * 0.60,
            width: cueWidth,
            height: cueHeight
        )

        switch moisture.fit {
        case .parched, .dry:
            let crackCount = moisture.fit == .parched ? 6 : 3
            let alpha: CGFloat = moisture.fit == .parched ? 0.26 : 0.15
            for index in 0..<crackCount {
                let x = cueRect.midX + deterministicWave(seed: plant.swaySeed + 11_011, index: index) * cueRect.width * 0.35
                let y = cueRect.midY + deterministicWave(seed: plant.swaySeed + 11_233, index: index) * cueRect.height * 0.20
                drawCurve(
                    from: NSPoint(x: x - cueRect.width * 0.034, y: y),
                    control1: NSPoint(x: x - cueRect.width * 0.010, y: y - cueRect.height * 0.22),
                    control2: NSPoint(x: x + cueRect.width * 0.012, y: y + cueRect.height * 0.22),
                    to: NSPoint(x: x + cueRect.width * 0.036, y: y + cueRect.height * 0.02),
                    color: color(red: 78, green: 48, blue: 30, alpha: alpha),
                    width: 0.9
                )
            }
        case .damp, .saturated:
            let path = NSBezierPath(ovalIn: cueRect.insetBy(dx: cueRect.width * 0.08, dy: cueRect.height * 0.16))
            let wetAlpha: CGFloat = moisture.fit == .saturated ? 0.15 : 0.075
            color(red: 44, green: 55, blue: 47, alpha: wetAlpha).setFill()
            path.fill()
            color(red: 134, green: 154, blue: 125, alpha: wetAlpha * 0.70).setStroke()
            path.lineWidth = 0.9
            path.stroke()
        case .ideal:
            return
        }
    }

    func circadianAssetOpacityMultiplier(for circadianState: PlantCircadianState, plant: Plant) -> Double {
        switch circadianState.phase {
        case .nightRest:
            plant.species.kind == .flower || plant.species.kind == .meadow ? 0.86 : 0.92
        case .morningRecovery:
            0.96
        case .photosynthesizing, .goldenBloom:
            1.0
        }
    }
}
