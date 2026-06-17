import AppKit
import PlantGardenCore

/// Hand-painted soil patches: realistic dirt fill rendered under the plants,
/// plus the live brush draft while the soil tool is active, plus the
/// hit-tested sink depth that lets a plant base settle into a patch.
extension GardenCanvasView {
    // MARK: - Saved patches (rendered under plants)

    func drawSoilPatchesIfNeeded() {
        let patches = store.state.soilPatches.filter { $0.screenIndex == screenIndex }
        guard !patches.isEmpty else {
            return
        }

        NSGraphicsContext.saveGraphicsState()
        for patch in patches {
            drawSoilPatch(patch)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawSoilPatch(_ patch: SoilPatch) {
        let points = patch.points.map { point in
            NSPoint(x: bounds.width * CGFloat(point.x), y: bounds.height * CGFloat(point.y))
        }
        guard points.count >= 2 else {
            return
        }

        // A thick round-nibbed stroke gives a single drag real brush width,
        // and the closed polygon fills wider gestures solid. Both are painted
        // in the base earth tone first so the patch has coverage everywhere
        // the operator dragged.
        let brushStroke = soilBrushStrokePath(for: points)
        let polygon = points.count >= SoilPatch.minimumPointCount ? soilPolygonPath(for: points) : nil

        Self.soilBaseColor.setFill()
        if let polygon {
            polygon.fill()
        }
        Self.soilBaseColor.setStroke()
        brushStroke.stroke()

        let bbox = brushStroke.bounds.union(polygon?.bounds ?? .zero)
        guard bbox.width > 1, bbox.height > 1 else {
            return
        }

        // Lay a soft radial earth gradient + speckle texture over the painted
        // area. Clip to the painted shape: the polygon when present, otherwise
        // the brush stroke's bounding box (thin single strokes).
        if let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            if let polygon {
                polygon.addClip()
            } else {
                NSBezierPath(rect: bbox).addClip()
            }

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradientColors = [
                Self.soilBaseColor.cgColor,
                Self.soilDryHighlight.cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: gradientColors,
                locations: [0.0, 1.0]
            ) {
                let center = CGPoint(x: bbox.midX, y: bbox.midY)
                let radius = max(bbox.width, bbox.height) * 0.62
                context.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: radius,
                    options: [.drawsAfterEndLocation]
                )
            }
            drawSoilSpeckles(seed: patch.soilSeed, in: bbox)
            context.restoreGState()
        }

        // A soft dark occlusion border so the patch sits into the ground.
        Self.soilBorderColor.setStroke()
        if let polygon {
            polygon.lineWidth = 2.4
            polygon.lineJoinStyle = .round
            polygon.stroke()
        }
    }

    private func soilBrushStrokePath(for points: [NSPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = soilBrushRadius * 2
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.line(to: point)
        }
        return path
    }

    private func soilPolygonPath(for points: [NSPoint]) -> NSBezierPath {
        let polygon = NSBezierPath()
        polygon.windingRule = .nonZero
        polygon.move(to: points[0])
        for point in points.dropFirst() {
            polygon.line(to: point)
        }
        polygon.close()
        return polygon
    }

    private func drawSoilSpeckles(seed: Int, in bbox: NSRect) {
        let speckleCount = 12 + abs(seed) % 19
        for index in 0..<speckleCount {
            let xWave = Double(deterministicWave(seed: Double(seed) + 3_011, index: index))
            let yWave = Double(deterministicWave(seed: Double(seed) + 5_209, index: index))
            let sizeWave = Double(deterministicWave(seed: Double(seed) + 7_417, index: index))
            let toneWave = deterministicWave(seed: Double(seed) + 9_623, index: index)

            let cx = bbox.midX + CGFloat(xWave) * bbox.width * 0.42
            let cy = bbox.midY + CGFloat(yWave) * bbox.height * 0.42
            let w = 2.0 + CGFloat(abs(sizeWave)) * 6.0
            let h = w * (0.5 + CGFloat(abs(yWave)) * 0.4)
            let rect = NSRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)

            let speckle = NSBezierPath(ovalIn: rect)
            if toneWave >= 0 {
                color(red: 64, green: 44, blue: 26, alpha: 0.34).setFill()
            } else {
                color(red: 124, green: 96, blue: 60, alpha: 0.30).setFill()
            }
            speckle.fill()
        }
    }

    // MARK: - Live draft (rendered over plants while painting)

    func drawSoilBrushDraftIfNeeded() {
        guard isSoilBrushMode || !soilBrushDraftPoints.isEmpty else {
            return
        }
        guard soilBrushDraftPoints.count >= 1 else {
            return
        }

        NSGraphicsContext.saveGraphicsState()
        if soilBrushDraftPoints.count >= 2 {
            // Preview the painted dirt so the operator sees the patch forming.
            let preview = soilBrushStrokePath(for: soilBrushDraftPoints)
            color(red: 96, green: 68, blue: 42, alpha: 0.45).setStroke()
            preview.stroke()

            // Bright centre-line outline marks exactly where the patch lands.
            let outline = NSBezierPath()
            outline.lineJoinStyle = .round
            outline.lineCapStyle = .round
            outline.move(to: soilBrushDraftPoints[0])
            for point in soilBrushDraftPoints.dropFirst() {
                outline.line(to: point)
            }
            NSColor.systemYellow.withAlphaComponent(0.55).setStroke()
            outline.lineWidth = 2
            outline.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: - Plant sinking

    /// How far (in points) a plant anchored over a soil patch should sink into
    /// the dirt. Cached per plant id; recomputed when the patch set or view
    /// geometry / backing scale changes.
    func soilSinkDepth(for plant: Plant) -> CGFloat {
        let patches = store.state.soilPatches.filter { $0.screenIndex == screenIndex }
        guard !patches.isEmpty else {
            if !soilSinkDepthCache.isEmpty {
                soilSinkDepthCache = [:]
            }
            return 0
        }

        let backingScale = window?.backingScaleFactor ?? 2
        let signature = Self.soilSinkSignature(patches: patches, backingScale: backingScale)
        if signature != soilSinkCacheSignature || bounds != soilSinkCacheBounds {
            soilSinkDepthCache = [:]
            soilSinkCacheSignature = signature
            soilSinkCacheBounds = bounds
        }

        if let cached = soilSinkDepthCache[plant.id] {
            return cached
        }

        let anchor = anchorPoint(for: plant)
        var depth: CGFloat = 0
        for patch in patches {
            let viewPoints = patch.points.map { point in
                NSPoint(x: bounds.width * CGFloat(point.x), y: bounds.height * CGFloat(point.y))
            }
            guard let first = viewPoints.first else {
                continue
            }
            let path = NSBezierPath()
            path.move(to: first)
            for point in viewPoints.dropFirst() {
                path.line(to: point)
            }
            path.close()

            if path.contains(anchor) {
                let plantHeight = realisticHeight(for: plant, baseHeight: height(for: plant))
                depth = min(16, CGFloat(plant.scale) * 0.028 * plantHeight)
                break
            }
        }

        soilSinkDepthCache[plant.id] = depth
        return depth
    }

    private static func soilSinkSignature(patches: [SoilPatch], backingScale: CGFloat) -> Int {
        var hasher = Hasher()
        hasher.combine(Int((backingScale * 100).rounded()))
        for patch in patches {
            hasher.combine(patch.id)
            hasher.combine(patch.points.count)
        }
        return hasher.finalize()
    }

    // MARK: - Palette

    static let soilBaseColor = NSColor(red: 88 / 255, green: 61 / 255, blue: 36 / 255, alpha: 0.82)
    static let soilDryHighlight = NSColor(red: 148 / 255, green: 114 / 255, blue: 72 / 255, alpha: 0.48)
    static let soilBorderColor = NSColor(red: 45 / 255, green: 30 / 255, blue: 18 / 255, alpha: 0.55)
}
