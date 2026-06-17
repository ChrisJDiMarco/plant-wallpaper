import AppKit
import PlantGardenCore

/// Hit testing and gesture sessions: plant/artwork hit resolution, dirty-
/// rect invalidation, resize handles, and drag/resize/music interactions.
extension GardenCanvasView {
    func plantID(at point: NSPoint, hitSlop: CGFloat = 0) -> UUID? {
        let diagonal = max(1, hypot(bounds.width, bounds.height))
        let candidates = store.state.plants
            .filter { $0.screenIndex == screenIndex }
            .filter { canDisplay($0) }
            .compactMap { plant -> PlantSelectionHitCandidate? in
                guard pointIsOnPlantArtwork(point, plant: plant, slop: hitSlop) else {
                    return nil
                }

                let rect = artworkRect(for: plant)
                let focusPoint = hitFocusPoint(for: plant, rect: rect)
                let distance = hypot(point.x - focusPoint.x, point.y - focusPoint.y) / diagonal
                return PlantSelectionHitCandidate(
                    id: plant.id,
                    distanceFromClick: Double(distance),
                    depth: plant.position.y,
                    isSelected: store.selectedPlantID == plant.id
                )
            }
        return PlantSelectionHitResolver.preferredPlantID(from: candidates)
    }

    /// Pixel-accurate hit test: the point must land on visible artwork pixels
    /// (within `slop`), not merely inside a padded bounding box. This is what
    /// keeps clicks on empty desktop from activating a nearby plant.
    func pointIsOnPlantArtwork(_ point: NSPoint, plant: Plant, slop: CGFloat) -> Bool {
        let rect = artworkRect(for: plant)
        guard !rect.isNull, !rect.isEmpty, rect.width > 0, rect.height > 0 else {
            return false
        }

        // Small artwork (seedlings) gets a slightly friendlier slop so tiny
        // sprites remain comfortable to click.
        let smallArtworkBoost: CGFloat = min(rect.width, rect.height) < 56 ? 6 : 0
        let effectiveSlop = slop + smallArtworkBoost
        guard rect.insetBy(dx: -effectiveSlop, dy: -effectiveSlop).contains(point) else {
            return false
        }

        guard let mask = PlantDisplayAssetResolver.alphaMask(for: plant, customAssets: store.customPlantAssets) else {
            // No mask available: fall back to a conservative core of the
            // artwork box rather than the old padded rectangle.
            return rect.insetBy(dx: rect.width * 0.16, dy: rect.height * 0.08).contains(point)
        }

        let clampedX = min(max(point.x, rect.minX), rect.maxX)
        let clampedY = min(max(point.y, rect.minY), rect.maxY)
        let u = Double((clampedX - rect.minX) / rect.width)
        let v = Double((clampedY - rect.minY) / rect.height)
        return mask.hasVisiblePixel(
            nearU: u,
            v: v,
            slopU: Double((effectiveSlop + 5) / rect.width),
            slopV: Double((effectiveSlop + 5) / rect.height)
        )
    }

    /// The screen region that must repaint when this plant moves or rescales:
    /// artwork plus margins for shadow, shine, sway, selection chrome, and the
    /// pinned inspector. Used for targeted dirty-rect redraws during drags so
    /// a drag never forces a full-screen repaint per mouse event.
    func redrawRect(for plant: Plant) -> NSRect {
        let artwork = artworkRect(for: plant)
        guard !artwork.isNull, !artwork.isEmpty else {
            return .zero
        }

        var rect = artwork.insetBy(
            dx: -(artwork.width * 0.55 + 48),
            dy: -(artwork.height * 0.30 + 48)
        )

        let profile = sceneVisualProfile()
        let projection = profile.lightProjection(from: store.state.lightProjection(at: currentDateProvider()))
        let castShadow = plant.castShadow(projection: projection)
        if castShadow.isVisible {
            let depthScale = CGFloat(0.78 + plant.depthProfile.depth * 0.30)
            let shadowLength = max(18, artwork.width * CGFloat(castShadow.lengthMultiplier) * depthScale)
            let shadowSpread = max(
                12,
                artwork.width
                    * CGFloat(castShadow.widthMultiplier)
                    * (0.42 + CGFloat(profile.contactSoftness) * 0.20)
            )
            let horizontalReach = shadowLength
                + shadowSpread
                + abs(artwork.width * CGFloat(castShadow.offsetXMultiplier))
                + 32
            let verticalReach = shadowLength * 0.24
                + shadowSpread * 0.55
                + abs(artwork.width * CGFloat(castShadow.offsetYMultiplier))
                + 32
            rect = rect.insetBy(dx: -horizontalReach, dy: -verticalReach)
        }

        if store.selectedPlantID == plant.id {
            rect = rect.union(selectionFrameRect(for: plant).insetBy(dx: -26, dy: -26))
            if pinnedInspectorPlantID == plant.id, let pinnedInspectorRect {
                rect = rect.union(clampInspectorRect(pinnedInspectorRect).insetBy(dx: -10, dy: -10))
            }
        }

        return rect
    }

    func invalidatePlantRegion(plantID: UUID?, around work: () -> Void) {
        let plantBefore = plantID.flatMap { id in store.state.plants.first { $0.id == id } }
        let rectBefore = plantBefore.map { redrawRect(for: $0) } ?? .zero
        work()
        let plantAfter = plantID.flatMap { id in store.state.plants.first { $0.id == id } }
        let rectAfter = plantAfter.map { redrawRect(for: $0) } ?? .zero
        let combined = rectBefore.union(rectAfter).intersection(bounds)
        if !combined.isNull, !combined.isEmpty {
            setNeedsDisplay(combined)
        }
    }

    /// The plant's visible artwork rect, exposed for the interaction self-test.
    func plantArtworkRectForSelfTest(for plantID: UUID) -> NSRect? {
        guard let plant = store.state.plants.first(where: { $0.id == plantID }),
              plant.screenIndex == screenIndex,
              canDisplay(plant) else {
            return nil
        }

        let rect = artworkRect(for: plant)
        return rect.isNull || rect.isEmpty ? nil : rect
    }

    /// A view point guaranteed to sit on the plant's visible pixels (the alpha
    /// centroid of its current artwork). Used by the interaction self-test.
    func plantBodyHitPoint(for plantID: UUID) -> NSPoint? {
        guard let plant = store.state.plants.first(where: { $0.id == plantID }),
              plant.screenIndex == screenIndex,
              canDisplay(plant) else {
            return nil
        }

        let rect = artworkRect(for: plant)
        guard !rect.isNull, !rect.isEmpty else {
            return nil
        }

        guard let mask = PlantDisplayAssetResolver.alphaMask(for: plant, customAssets: store.customPlantAssets) else {
            return NSPoint(x: rect.midX, y: rect.midY)
        }

        return NSPoint(
            x: rect.minX + rect.width * CGFloat(mask.opaqueCentroid.u),
            y: rect.minY + rect.height * CGFloat(mask.opaqueCentroid.v)
        )
    }

    func artworkRect(for plant: Plant) -> NSRect {
        let anchor = anchorPoint(for: plant)
        let plantHeight = height(for: plant)
        guard let image = PlantDisplayAssetResolver.image(for: plant, customAssets: store.customPlantAssets),
              image.size.height > 0 else {
            return .zero
        }

        let targetHeight = realisticHeight(for: plant, baseHeight: plantHeight)
        let targetWidth = targetHeight * image.size.width / image.size.height * youngPlantWidthFactor(for: plant)
        let stress = stressLevel(for: plant)
        let droop = stress * targetHeight * (plant.isDead ? 0.095 : 0.055)
        return NSRect(
            x: anchor.x - targetWidth / 2,
            y: anchor.y - targetHeight + droop,
            width: targetWidth,
            height: targetHeight
        )
    }

    func selectionFrameRect(for plant: Plant) -> NSRect {
        let artworkRect = artworkRect(for: plant)
        guard !artworkRect.isNull && !artworkRect.isEmpty else {
            return .zero
        }

        return artworkRect.insetBy(dx: -Self.selectionFrameOutset, dy: -Self.selectionFrameOutset)
    }

    func resizeHandleRects(for plant: Plant) -> [(ResizeHandle, NSRect)] {
        guard !plant.placementLocked else {
            return []
        }

        let frame = selectionFrameRect(for: plant)
        guard !frame.isNull && !frame.isEmpty else {
            return []
        }

        return ResizeHandle.allCases.map { handle in
            let corner = handle.cornerPoint(in: frame)
            let rect = NSRect(
                x: corner.x - Self.resizeHandleSize / 2,
                y: corner.y - Self.resizeHandleSize / 2,
                width: Self.resizeHandleSize,
                height: Self.resizeHandleSize
            )
            return (handle, rect)
        }
    }

    func resizeHandle(at point: NSPoint, for plant: Plant) -> ResizeHandle? {
        resizeHandleRects(for: plant)
            .compactMap { handle, rect -> (ResizeHandle, CGFloat)? in
                let hitRect = rect.insetBy(dx: -Self.resizeHandleHitOutset, dy: -Self.resizeHandleHitOutset)
                guard hitRect.contains(point) else {
                    return nil
                }

                return (handle, hypot(point.x - rect.midX, point.y - rect.midY))
            }
            .min { lhs, rhs in lhs.1 < rhs.1 }?
            .0
    }

    func selectionFrameEdgeRects(for plant: Plant) -> [NSRect] {
        let frame = selectionFrameRect(for: plant)
        guard !frame.isNull && !frame.isEmpty else {
            return []
        }

        let width = Self.selectionFrameLineHitWidth
        return [
            NSRect(x: frame.minX - width / 2, y: frame.minY - width / 2, width: frame.width + width, height: width),
            NSRect(x: frame.minX - width / 2, y: frame.maxY - width / 2, width: frame.width + width, height: width),
            NSRect(x: frame.minX - width / 2, y: frame.minY - width / 2, width: width, height: frame.height + width),
            NSRect(x: frame.maxX - width / 2, y: frame.minY - width / 2, width: width, height: frame.height + width)
        ]
    }

    func selectionFrameEdgeContains(_ point: NSPoint, for plant: Plant) -> Bool {
        selectionFrameEdgeRects(for: plant).contains { $0.contains(point) }
    }

    func selectedPlantResizeSurfaceContains(_ point: NSPoint, for plant: Plant) -> Bool {
        resizeHandle(at: point, for: plant) != nil || selectionFrameEdgeContains(point, for: plant)
    }

    func hitFocusPoint(for plant: Plant, rect: NSRect) -> NSPoint {
        switch plant.species.kind {
        case .tree:
            NSPoint(x: rect.midX, y: rect.minY + rect.height * 0.52)
        case .foliage, .flower, .meadow, .edible:
            NSPoint(x: rect.midX, y: rect.midY)
        }
    }

    func beginPlantInteraction(plantID: UUID, at point: NSPoint, clickCount: Int) {
        pinnedInspectorPlantID = nil
        pinnedInspectorRect = nil
        resizeSession = nil
        musicButtonDragSession = nil
        store.setSelectedPlant(plantID)

        if clickCount >= 2 {
            store.waterPlant(id: plantID)
            return
        }

        guard store.selectedPlant?.placementLocked != true else {
            draggingPlantID = nil
            dragDidMovePlant = false
            return
        }

        draggingPlantID = plantID
        dragStartPoint = point
        dragDidMovePlant = false
        if let plant = store.state.plants.first(where: { $0.id == plantID }) {
            let anchor = anchorPoint(for: plant)
            dragOffset = NSPoint(x: anchor.x - point.x, y: anchor.y - point.y)
        }
    }

    func beginMusicButtonInteraction(at point: NSPoint, clickCount: Int) {
        guard let hit = musicButtonHit(at: point) else {
            return
        }

        pinnedInspectorPlantID = nil
        pinnedInspectorRect = nil
        draggingPlantID = nil
        resizeSession = nil
        clearMusicButtonHover()
        store.setSelectedPlant(nil)

        let center = NSPoint(x: hit.rect.midX, y: hit.rect.midY)
        musicButtonDragSession = MusicButtonDragSession(
            buttonIndex: hit.index,
            initialCenter: center,
            dragOffset: NSPoint(x: center.x - point.x, y: center.y - point.y),
            clickCount: clickCount,
            didMove: false
        )
    }

    func beginPlantResize(plant: Plant, handle: ResizeHandle) {
        guard !plant.placementLocked else {
            resizeSession = nil
            return
        }

        pinnedInspectorPlantID = nil
        pinnedInspectorRect = nil
        draggingPlantID = nil
        musicButtonDragSession = nil
        store.setSelectedPlant(plant.id)

        let frame = selectionFrameRect(for: plant)
        let center = NSPoint(x: frame.midX, y: frame.midY)
        let corner = handle.cornerPoint(in: frame)
        let initialDistance = max(12, hypot(corner.x - center.x, corner.y - center.y))
        resizeSession = PlantResizeSession(
            plantID: plant.id,
            frameCenter: center,
            initialScale: plant.scale,
            initialDistanceFromCenter: initialDistance
        )
    }

    func continuePlantResize(at point: NSPoint) -> Bool {
        guard let resizeSession else {
            return false
        }

        store.setSelectedPlant(resizeSession.plantID)
        let distance = max(4, hypot(point.x - resizeSession.frameCenter.x, point.y - resizeSession.frameCenter.y))
        let scaleFactor = Double(distance / resizeSession.initialDistanceFromCenter)
        invalidatePlantRegion(plantID: resizeSession.plantID) {
            store.resizeSelectedPlant(toScale: resizeSession.initialScale * scaleFactor)
            repinInspectorToFollowPlant(resizeSession.plantID)
        }
        return true
    }

    func continueMusicButtonDrag(at point: NSPoint) -> Bool {
        guard var session = musicButtonDragSession else {
            return false
        }

        let adjustedCenter = NSPoint(
            x: point.x + session.dragOffset.x,
            y: point.y + session.dragOffset.y
        )
        if hypot(adjustedCenter.x - session.initialCenter.x, adjustedCenter.y - session.initialCenter.y) > 3 {
            session.didMove = true
        }
        musicButtonDragSession = session
        let rectBefore = musicButtonInteractionRects()
            .first { $0.index == session.buttonIndex }?
            .rect
            .insetBy(dx: -16, dy: -16) ?? .zero
        store.moveMusicButton(
            at: session.buttonIndex,
            to: GardenPoint(
                x: Double(adjustedCenter.x / max(1, bounds.width)),
                y: Double(adjustedCenter.y / max(1, bounds.height))
            ),
            screenIndex: screenIndex
        )
        let rectAfter = musicButtonInteractionRects()
            .first { $0.index == session.buttonIndex }?
            .rect
            .insetBy(dx: -16, dy: -16) ?? .zero
        let combined = rectBefore.union(rectAfter).intersection(bounds)
        if !combined.isNull, !combined.isEmpty {
            setNeedsDisplay(combined)
        }
        return true
    }

    func endPlantResize() -> Bool {
        guard resizeSession != nil else {
            return false
        }

        resizeSession = nil
        store.save()
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
        return true
    }

    func endMusicButtonInteraction() -> Bool {
        guard let session = musicButtonDragSession else {
            return false
        }

        musicButtonDragSession = nil
        if session.didMove {
            store.save()
            needsDisplay = true
        } else {
            switch store.state.settings.radioActivationMode {
            case .disabled:
                needsDisplay = true
                return true
            case .doubleClick where session.clickCount < 2:
                needsDisplay = true
                return true
            case .singleClick, .doubleClick:
                break
            }
            let stream = store.state.musicButtons.indices.contains(session.buttonIndex)
                ? store.state.musicButtons[session.buttonIndex].companion.stationStream(in: store.state.settings)
                : GardenRadioStation.chillHopByFluxFM.stream
            musicPlayer.toggleRadioStream(stream)
            needsDisplay = true
        }
        return true
    }
}
