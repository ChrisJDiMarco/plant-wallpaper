import AppKit
import PlantGardenCore

/// The plant inspector panel and selection frame: drawing, smart viewport
/// placement, action buttons, and stage progress.
extension GardenCanvasView {
    func drawInspector(for plant: Plant) {
        let rect = inspectorRect(for: plant)
        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        color(red: 248, green: 243, blue: 224, alpha: 0.95).setFill()
        path.fill()
        color(red: 113, green: 133, blue: 91, alpha: 0.42).setStroke()
        path.lineWidth = 1.15
        path.stroke()

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: color(red: 38, green: 50, blue: 35, alpha: 0.98)
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: color(red: 62, green: 73, blue: 51, alpha: 0.92)
        ]

        plant.nickname.draw(in: NSRect(x: rect.minX + 14, y: rect.minY + 12, width: rect.width - 28, height: 21), withAttributes: titleAttributes)
        let sunlight = store.state.sunlightCondition()
        let microclimate = PlantMicroclimate(plant: plant, state: store.state)
        let circadianState = plant.circadianState(for: sunlight)
        let forecast = PlantGrowthForecast(
            plant: plant,
            microclimateGrowthFactor: microclimate.growthFactor,
            circadianGrowthFactor: circadianState.growthMultiplier,
            stageCount: PlantAssetLibrary.stageCount
        )
        let lifeStage = PlantLifeStage(
            species: plant.species,
            assetStage: forecast.stage,
            stageCount: PlantAssetLibrary.stageCount
        )
        let waterForecast = PlantWaterForecast(
            plant: plant,
            ambientMoisture: store.state.ambientMoisture,
            microclimateWaterUseFactor: microclimate.waterUseFactor
        )
        let moisturePreference = plant.moisturePreference
        let nutrientProfile = plant.nutrientProfile
        let groundIntegration = plant.groundIntegration
        let companionEffect = plant.companionEffect(in: store.state)
        let lines = [
            "\(lifeStage.label)  Growth \(Int(plant.growth * 100))%  Water \(Int(plant.hydration * 100))%",
            plant.growthMilestoneIntensity(at: Date()) > 0
                ? "New phase: \(lifeStage.title)  \(forecast.shortSummary)"
                : "\(forecast.shortSummary)  \(waterForecast.shortSummary)",
            "\(plant.careActionRecommendation.summary)  \(circadianState.shortSummary)  \(moisturePreference.shortSummary)",
            plant.isHarvestReady
                ? "Ready to harvest!  \(nutrientProfile.shortSummary)"
                : "\(nutrientProfile.shortSummary)  \(groundIntegration.shortSummary)",
            "\(companionEffect.shortSummary)  \(microclimate.shortSummary)"
        ]
        for (index, line) in lines.enumerated() {
            line.draw(
                in: NSRect(x: rect.minX + 14, y: rect.minY + 39 + CGFloat(index) * 15, width: rect.width - 28, height: 15),
                withAttributes: bodyAttributes
            )
        }

        drawStageProgress(for: plant, in: stageProgressRect(for: plant), attributes: bodyAttributes)

        for (action, buttonRect) in inspectorActionRects(for: plant) {
            drawInspectorAction(action, for: plant, in: buttonRect)
        }

        let hoveredActionRect = inspectorHoverAction.flatMap { hoveredAction in
            inspectorActionRects(for: plant).first { $0.0 == hoveredAction }
        }
        if let inspectorHoverAction,
           inspectorActions(for: plant).contains(inspectorHoverAction),
           let hoveredActionRect {
            drawInspectorTooltip(
                tooltip(for: inspectorHoverAction, plant: plant),
                above: hoveredActionRect.1,
                in: rect
            )
        }
    }

    func drawSelectionFrame(for plant: Plant) {
        let rect = selectionFrameRect(for: plant)
        guard !rect.isNull && !rect.isEmpty else {
            return
        }

        let framePath = NSBezierPath(rect: rect)
        color(red: 244, green: 252, blue: 226, alpha: 0.92).setStroke()
        framePath.lineWidth = 1.35
        framePath.setLineDash([5.0, 4.0], count: 2, phase: 0)
        framePath.stroke()

        color(red: 32, green: 45, blue: 30, alpha: 0.22).setStroke()
        let shadowPath = NSBezierPath(rect: rect.insetBy(dx: -1, dy: -1))
        shadowPath.lineWidth = 1.0
        shadowPath.setLineDash([5.0, 4.0], count: 2, phase: 0)
        shadowPath.stroke()

        guard !plant.placementLocked else {
            drawPlacementLockBadge(in: rect)
            return
        }

        for (_, handleRect) in resizeHandleRects(for: plant) {
            let handlePath = NSBezierPath(rect: handleRect)
            color(red: 255, green: 252, blue: 232, alpha: 0.96).setFill()
            handlePath.fill()
            color(red: 58, green: 86, blue: 49, alpha: 0.86).setStroke()
            handlePath.lineWidth = 1.25
            handlePath.stroke()
        }
    }

    func inspectorRect(for plant: Plant) -> NSRect {
        if pinnedInspectorPlantID == plant.id, let pinnedInspectorRect {
            return clampInspectorRect(pinnedInspectorRect)
        }

        let rect = clampInspectorRect(preferredInspectorRect(for: plant))
        pinnedInspectorPlantID = plant.id
        pinnedInspectorRect = rect
        return rect
    }

    /// Places the inspector on the side of the plant with enough room -
    /// above, below, right, then left - so it avoids covering the plant
    /// whenever it can and always lands fully inside the usable viewport.
    func preferredInspectorRect(for plant: Plant) -> NSRect {
        let plantRect = selectionFrameRect(for: plant)
        let viewport = inspectorViewportRect()
        let width = min(max(300, viewport.width), 390)
        let height: CGFloat = 200
        let gap: CGFloat = 14

        let centeredX = min(max(viewport.minX, plantRect.midX - width / 2), max(viewport.minX, viewport.maxX - width))
        let centeredY = min(max(viewport.minY, plantRect.midY - height / 2), max(viewport.minY, viewport.maxY - height))

        // The view is flipped, so smaller y is visually above the plant.
        let candidates = [
            NSRect(x: centeredX, y: plantRect.minY - gap - height, width: width, height: height),
            NSRect(x: centeredX, y: plantRect.maxY + gap, width: width, height: height),
            NSRect(x: plantRect.maxX + gap, y: centeredY, width: width, height: height),
            NSRect(x: plantRect.minX - gap - width, y: centeredY, width: width, height: height)
        ]

        if let fittingRect = candidates.first(where: { viewport.contains($0) }) {
            return fittingRect
        }

        // No side has room (large plant on a small screen): fall back to the
        // above-the-plant placement and let clamping pull it into view.
        return candidates[0]
    }

    /// The region the inspector may occupy: the screen's visible frame (no
    /// menu bar or Dock, where desktop clicks are blocked) with a margin.
    func inspectorViewportRect() -> NSRect {
        let margin: CGFloat = 12
        guard let window, let screen = window.screen else {
            return bounds.insetBy(dx: margin, dy: margin)
        }

        let visibleRect = convert(window.convertFromScreen(screen.visibleFrame), from: nil)
        let usableRect = visibleRect.intersection(bounds)
        guard !usableRect.isNull, usableRect.width > 120, usableRect.height > 120 else {
            return bounds.insetBy(dx: margin, dy: margin)
        }

        return usableRect.insetBy(dx: margin, dy: margin)
    }

    func clampInspectorRect(_ rect: NSRect) -> NSRect {
        let viewport = inspectorViewportRect()
        let width = min(rect.width, max(120, viewport.width))
        let height = min(rect.height, max(120, viewport.height))
        let x = min(max(viewport.minX, rect.minX), max(viewport.minX, viewport.maxX - width))
        let y = min(max(viewport.minY, rect.minY), max(viewport.minY, viewport.maxY - height))
        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// Keeps the inspector tracking its plant through a drag or resize
    /// gesture instead of staying pinned where the gesture started.
    func repinInspectorToFollowPlant(_ plantID: UUID) {
        guard store.selectedPlantID == plantID,
              let plant = store.state.plants.first(where: { $0.id == plantID }) else {
            return
        }

        pinnedInspectorPlantID = plantID
        pinnedInspectorRect = clampInspectorRect(preferredInspectorRect(for: plant))
    }

    func stageProgressRect(for plant: Plant) -> NSRect {
        let rect = inspectorRect(for: plant)
        return NSRect(x: rect.minX + 14, y: rect.minY + 120, width: rect.width - 28, height: 14)
    }

    /// A ready edible swaps Nourish for Harvest - a crop that's done growing
    /// wants picking, not feeding.
    func inspectorActions(for plant: Plant) -> [InspectorAction] {
        if plant.isHarvestReady {
            return InspectorAction.allCases.filter { $0 != .nourish }
        }

        return InspectorAction.allCases.filter { $0 != .harvest }
    }

    func inspectorActionRects(for plant: Plant) -> [(InspectorAction, NSRect)] {
        let rect = inspectorRect(for: plant)
        let actions = inspectorActions(for: plant)
        let actionCount = CGFloat(actions.count)
        let gapCount = CGFloat(max(0, actions.count - 1))
        let availableWidth = max(1, rect.width - 28)
        let defaultButtonSize: CGFloat = 40
        let defaultSpacing: CGFloat = 10
        let defaultTotalWidth = actionCount * defaultButtonSize + gapCount * defaultSpacing
        let minimumButtonSize: CGFloat = 34
        let spacing: CGFloat
        let buttonSize: CGFloat

        if defaultTotalWidth <= availableWidth {
            spacing = defaultSpacing
            buttonSize = defaultButtonSize
        } else {
            spacing = max(6, min(defaultSpacing, (availableWidth - actionCount * minimumButtonSize) / max(1, gapCount)))
            buttonSize = min(
                defaultButtonSize,
                max(minimumButtonSize, (availableWidth - gapCount * spacing) / max(1, actionCount))
            )
        }

        let totalWidth = CGFloat(actions.count) * buttonSize + CGFloat(actions.count - 1) * spacing
        let startX = rect.midX - totalWidth / 2
        let y = rect.maxY - buttonSize - 14

        return actions.enumerated().map { index, action in
            let x = startX + CGFloat(index) * (buttonSize + spacing)
            return (action, NSRect(x: x, y: y, width: buttonSize, height: buttonSize))
        }
    }

    func drawStageProgress(
        for plant: Plant,
        in rect: NSRect,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let labelWidth: CGFloat = 68
        let percentWidth: CGFloat = 42
        let railRect = NSRect(
            x: rect.minX + labelWidth + 6,
            y: rect.minY + 3,
            width: max(24, rect.width - labelWidth - percentWidth - 14),
            height: 6
        )
        let progress = stageProgress(for: plant)
        let percent = "\(Int((progress * 100).rounded()))%"

        "Next stage".draw(
            in: NSRect(x: rect.minX, y: rect.minY - 1, width: labelWidth, height: rect.height),
            withAttributes: attributes
        )
        percent.draw(
            in: NSRect(x: railRect.maxX + 8, y: rect.minY - 1, width: percentWidth, height: rect.height),
            withAttributes: attributes
        )

        let track = NSBezierPath(roundedRect: railRect, xRadius: 3, yRadius: 3)
        color(red: 128, green: 145, blue: 103, alpha: 0.18).setFill()
        track.fill()

        let fillWidth = max(progress > 0 ? 3 : 0, railRect.width * progress)
        guard fillWidth > 0 else {
            return
        }

        let fillRect = NSRect(x: railRect.minX, y: railRect.minY, width: min(railRect.width, fillWidth), height: railRect.height)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 3, yRadius: 3)
        color(red: 105, green: 151, blue: 83, alpha: 0.72).setFill()
        fill.fill()
    }

    func stageProgress(for plant: Plant) -> CGFloat {
        CGFloat(PlantAssetStage(growth: plant.growth, stageCount: PlantAssetLibrary.stageCount).progressToNext)
    }

    func inspectorAction(at point: NSPoint, for plant: Plant) -> InspectorAction? {
        inspectorActionRects(for: plant)
            .compactMap { action, rect -> (InspectorAction, CGFloat)? in
                let hitRect = rect.insetBy(dx: -8, dy: -8)
                guard hitRect.contains(point) else {
                    return nil
                }

                let distance = hypot(point.x - rect.midX, point.y - rect.midY)
                return (action, distance)
            }
            .min { lhs, rhs in lhs.1 < rhs.1 }?
            .0
    }

    func performInspectorAction(_ action: InspectorAction) {
        clearInspectorActionHover()
        switch action {
        case .care:
            store.toggleSelectedPlantFavorite()
        case .water:
            store.waterSelectedPlant()
        case .nourish:
            store.nourishSelectedPlant()
        case .harvest:
            store.harvestSelectedPlant()
        case .prune:
            store.pruneSelectedPlant()
        case .clone:
            store.cloneSelectedPlant()
            pinnedInspectorPlantID = nil
            pinnedInspectorRect = nil
            plantExplorerPlantID = nil
        case .explore:
            plantExplorerPlantID = store.selectedPlantID
            draggingPlantID = nil
            dragDidMovePlant = false
            resizeSession = nil
            musicButtonDragSession = nil
            needsDisplay = true
        case .lockPlacement:
            store.toggleSelectedPlantPlacementLock()
            draggingPlantID = nil
            dragDidMovePlant = false
            resizeSession = nil
            musicButtonDragSession = nil
            needsDisplay = true
        case .remove:
            store.removeSelectedPlant()
            pinnedInspectorPlantID = nil
            pinnedInspectorRect = nil
            plantExplorerPlantID = nil
        }
    }

    func updateInspectorActionHover(at point: NSPoint) {
        let nextAction = store.selectedPlant.flatMap { plant -> InspectorAction? in
            guard plant.screenIndex == screenIndex, canDisplay(plant) else {
                return nil
            }

            return inspectorAction(at: point, for: plant)
        }
        guard nextAction != inspectorHoverAction else {
            return
        }

        inspectorHoverAction = nextAction
        needsDisplay = true
    }

    func clearInspectorActionHover() {
        guard inspectorHoverAction != nil else {
            return
        }

        inspectorHoverAction = nil
        needsDisplay = true
    }

    func drawInspectorAction(_ action: InspectorAction, for plant: Plant, in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
        let isDestructive = action == .remove
        let isLocked = action == .lockPlacement && plant.placementLocked
        let isFavorite = action == .care && plant.isFavorite
        let isRecentlyWatered = plant.lastWateredAt.map {
            currentDateProvider().timeIntervalSince($0) < 6 * 3_600
        } ?? false
        let isWatered = action == .water && (isRecentlyWatered || plant.hydration >= 0.98)
        (isDestructive
            ? color(red: 239, green: 213, blue: 202, alpha: 0.96)
            : isLocked
                ? color(red: 52, green: 69, blue: 45, alpha: 0.96)
                : isFavorite
                    ? color(red: 255, green: 232, blue: 234, alpha: 0.98)
                    : isWatered
                        ? color(red: 224, green: 242, blue: 255, alpha: 0.98)
                        : color(red: 255, green: 252, blue: 238, alpha: 0.96)
        ).setFill()
        path.fill()
        (isDestructive
            ? color(red: 164, green: 91, blue: 72, alpha: 0.58)
            : isLocked
                ? color(red: 210, green: 227, blue: 184, alpha: 0.62)
                : isFavorite
                    ? color(red: 218, green: 69, blue: 83, alpha: 0.70)
                    : isWatered
                        ? color(red: 47, green: 132, blue: 201, alpha: 0.70)
                        : color(red: 124, green: 145, blue: 105, alpha: 0.46)
        ).setStroke()
        path.lineWidth = 1.1
        path.stroke()

        guard let image = NSImage(
            systemSymbolName: symbolName(for: action, plant: plant),
            accessibilityDescription: accessibilityLabel(for: action, plant: plant)
        ) else {
            return
        }

        let iconSize: CGFloat = 18
        let iconRect = NSRect(
            x: rect.midX - iconSize / 2,
            y: rect.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        image.isTemplate = true
        let tint = isDestructive
            ? color(red: 85, green: 44, blue: 35, alpha: 0.96)
            : isLocked
                ? color(red: 247, green: 252, blue: 232, alpha: 0.98)
                : isFavorite
                    ? color(red: 204, green: 35, blue: 54, alpha: 0.98)
                    : isWatered
                        ? color(red: 0, green: 105, blue: 190, alpha: 0.98)
                        : color(red: 35, green: 42, blue: 31, alpha: 0.96)
        tint.set()
        image.draw(
            in: iconRect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    func symbolName(for action: InspectorAction, plant: Plant) -> String {
        if action == .lockPlacement {
            return plant.placementLocked ? "lock.fill" : "lock.open.fill"
        }
        return action.symbolName
    }

    func accessibilityLabel(for action: InspectorAction, plant: Plant) -> String {
        if action == .lockPlacement {
            return plant.placementLocked ? "Unlock Placement" : "Lock Placement"
        }
        return action.accessibilityLabel
    }

    func tooltip(for action: InspectorAction, plant: Plant) -> String {
        switch action {
        case .care:
            plant.isFavorite ? "Remove from favorites" : "Add to favorites"
        case .water:
            "Water this plant"
        case .nourish:
            "Grow to next stage"
        case .harvest:
            "Harvest ready crop"
        case .prune:
            "Prune and collect seeds"
        case .clone:
            "Duplicate this plant"
        case .explore:
            "Open plant details"
        case .lockPlacement:
            plant.placementLocked ? "Unlock placement" : "Lock placement"
        case .remove:
            "Remove this plant"
        }
    }

    func drawInspectorTooltip(_ text: String, above buttonRect: NSRect, in inspectorRect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color(red: 247, green: 252, blue: 232, alpha: 0.98)
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let width = min(inspectorRect.width - 28, textSize.width + 18)
        let height: CGFloat = 26
        let x = min(
            max(inspectorRect.minX + 14, buttonRect.midX - width / 2),
            inspectorRect.maxX - 14 - width
        )
        let y = max(inspectorRect.minY + 8, buttonRect.minY - height - 8)
        let rect = NSRect(x: x, y: y, width: width, height: height)
        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        color(red: 45, green: 58, blue: 39, alpha: 0.94).setFill()
        path.fill()
        text.draw(
            in: NSRect(x: rect.minX + 9, y: rect.minY + 5, width: rect.width - 18, height: 16),
            withAttributes: attributes
        )
    }

    func drawPlacementLockBadge(in rect: NSRect) {
        guard let image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Placement locked") else {
            return
        }

        let badgeSize: CGFloat = 24
        let badgeRect = NSRect(
            x: rect.maxX - badgeSize - 7,
            y: rect.minY + 7,
            width: badgeSize,
            height: badgeSize
        )
        let badgePath = NSBezierPath(ovalIn: badgeRect)
        color(red: 52, green: 69, blue: 45, alpha: 0.94).setFill()
        badgePath.fill()
        color(red: 247, green: 252, blue: 232, alpha: 0.72).setStroke()
        badgePath.lineWidth = 1.0
        badgePath.stroke()

        let iconSize: CGFloat = 12
        let iconRect = NSRect(
            x: badgeRect.midX - iconSize / 2,
            y: badgeRect.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        image.isTemplate = true
        color(red: 247, green: 252, blue: 232, alpha: 0.98).set()
        image.draw(
            in: iconRect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }
}
