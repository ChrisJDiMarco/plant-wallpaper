import AppKit
import PlantGardenCore

/// Hand-painted soil patches: realistic dirt fill rendered under the plants,
/// plus the live brush draft while the soil tool is active, plus the
/// hit-tested sink depth that lets a plant base settle into a patch.
extension GardenCanvasView {
    private enum SoilRenderMode {
        case saved
        case draft

        var alphaScale: CGFloat {
            switch self {
            case .saved:
                1.0
            case .draft:
                0.72
            }
        }

        var detailScale: CGFloat {
            switch self {
            case .saved:
                1.0
            case .draft:
                0.42
            }
        }
    }

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
        drawSoilMaterial(points: points, seed: patch.soilSeed, mode: .saved)
    }

    private func drawSoilMaterial(points: [NSPoint], seed: Int, mode: SoilRenderMode) {
        guard !points.isEmpty else {
            return
        }

        let centerline = soilBrushStrokePath(for: points)
        let coveragePath = soilCoveragePath(for: points, centerline: centerline)
        let bbox = soilExpandedBounds(for: coveragePath, points: points)
        guard bbox.width > 1, bbox.height > 1,
              let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        drawSoilCastShadow(coveragePath, context: context, alphaScale: mode.alphaScale)

        context.saveGState()
        context.addPath(coveragePath)
        context.clip()

        drawSoilBasePlane(in: bbox, context: context, alphaScale: mode.alphaScale)
        drawSoilCompactedBrushBands(
            centerline: centerline,
            seed: seed,
            alphaScale: mode.alphaScale
        )
        drawSoilCracksAndFibers(
            seed: seed,
            in: bbox,
            detailScale: mode.detailScale,
            alphaScale: mode.alphaScale
        )
        drawSoilGranules(
            seed: seed,
            in: bbox,
            detailScale: mode.detailScale,
            alphaScale: mode.alphaScale
        )
        drawSoilClods(
            seed: seed,
            in: bbox,
            detailScale: mode.detailScale,
            alphaScale: mode.alphaScale
        )
        context.restoreGState()

        drawSoilOverspray(
            points: points,
            seed: seed,
            detailScale: mode.detailScale,
            alphaScale: mode.alphaScale
        )
        drawSoilEdgeRelief(
            coveragePath,
            context: context,
            alphaScale: mode.alphaScale
        )
    }

    private func drawSoilCastShadow(
        _ coveragePath: CGPath,
        context: CGContext,
        alphaScale: CGFloat
    ) {
        context.saveGState()
        context.addPath(coveragePath)
        context.setShadow(
            offset: CGSize(width: 2.4, height: 3.2),
            blur: 8,
            color: color(red: 20, green: 14, blue: 8, alpha: 0.26 * alphaScale).cgColor
        )
        context.setFillColor(color(red: 42, green: 29, blue: 18, alpha: 0.18 * alphaScale).cgColor)
        context.fillPath()
        context.restoreGState()
    }

    private func drawSoilBasePlane(
        in bbox: NSRect,
        context: CGContext,
        alphaScale: CGFloat
    ) {
        context.setFillColor(Self.soilBaseColor.withAlphaComponent(0.88 * alphaScale).cgColor)
        context.fill(bbox)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let center = CGPoint(x: bbox.midX - bbox.width * 0.12, y: bbox.midY - bbox.height * 0.18)
        let dryEdge = CGPoint(x: bbox.midX + bbox.width * 0.18, y: bbox.midY + bbox.height * 0.10)
        if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                color(red: 48, green: 32, blue: 19, alpha: 0.78 * alphaScale).cgColor,
                color(red: 88, green: 61, blue: 36, alpha: 0.62 * alphaScale).cgColor,
                color(red: 152, green: 116, blue: 72, alpha: 0.38 * alphaScale).cgColor
            ] as CFArray,
            locations: [0.0, 0.58, 1.0]
        ) {
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: dryEdge,
                endRadius: max(bbox.width, bbox.height) * 0.74,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }

        if let dampGradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                color(red: 34, green: 25, blue: 17, alpha: 0.30 * alphaScale).cgColor,
                color(red: 74, green: 52, blue: 33, alpha: 0.08 * alphaScale).cgColor,
                NSColor.clear.cgColor
            ] as CFArray,
            locations: [0.0, 0.48, 1.0]
        ) {
            context.drawRadialGradient(
                dampGradient,
                startCenter: CGPoint(x: bbox.midX, y: bbox.midY),
                startRadius: 0,
                endCenter: CGPoint(x: bbox.midX, y: bbox.midY),
                endRadius: min(bbox.width, bbox.height) * 0.62,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    private func drawSoilCompactedBrushBands(
        centerline: NSBezierPath,
        seed: Int,
        alphaScale: CGFloat
    ) {
        let bandCount = 6
        for index in 0..<bandCount {
            let widthNoise = soilSignedNoise(seed: seed, index: index, salt: 313)
            let toneNoise = soilSignedNoise(seed: seed, index: index, salt: 977)
            let width = soilBrushRadius * (1.92 - CGFloat(index) * 0.23 + widthNoise * 0.045)
            centerline.lineWidth = max(2, width)
            centerline.lineJoinStyle = .round
            centerline.lineCapStyle = .round
            if index.isMultiple(of: 2) {
                color(
                    red: 52 + toneNoise * 8,
                    green: 36 + toneNoise * 5,
                    blue: 23 + toneNoise * 4,
                    alpha: (0.10 + CGFloat(index) * 0.018) * alphaScale
                ).setStroke()
            } else {
                color(
                    red: 130 + toneNoise * 18,
                    green: 98 + toneNoise * 10,
                    blue: 60 + toneNoise * 8,
                    alpha: (0.075 + CGFloat(index) * 0.012) * alphaScale
                ).setStroke()
            }
            centerline.stroke()
        }
    }

    private func soilBrushStrokePath(for points: [NSPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = soilBrushRadius * 2
        path.move(to: points[0])
        guard points.count > 2 else {
            for point in points.dropFirst() {
                path.line(to: point)
            }
            return path
        }

        for index in 1..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            let midpoint = NSPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
            path.curve(to: midpoint, controlPoint1: current, controlPoint2: current)
        }
        path.curve(to: points[points.count - 1], controlPoint1: points[points.count - 2], controlPoint2: points[points.count - 2])
        return path
    }

    private func soilCoveragePath(for points: [NSPoint], centerline: NSBezierPath? = nil) -> CGPath {
        guard points.count > 1 else {
            let center = points[0]
            return CGPath(
                ellipseIn: CGRect(
                    x: center.x - soilBrushRadius,
                    y: center.y - soilBrushRadius,
                    width: soilBrushRadius * 2,
                    height: soilBrushRadius * 2
                ),
                transform: nil
            )
        }

        let line = centerline ?? soilBrushStrokePath(for: points)
        let stroked = cgPath(from: line).copy(
            strokingWithWidth: soilBrushRadius * 2.08,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: soilBrushRadius,
            transform: .identity
        )
        let coverage = CGMutablePath()
        coverage.addPath(stroked)

        if points.count >= SoilPatch.minimumPointCount,
           let first = points.first,
           let last = points.last,
           hypot(first.x - last.x, first.y - last.y) <= soilBrushRadius * 1.35 {
            let closed = soilClosedLoopPath(for: points)
            coverage.addPath(cgPath(from: closed))
        }

        return coverage.copy() ?? stroked
    }

    private func soilClosedLoopPath(for points: [NSPoint]) -> NSBezierPath {
        let polygon = NSBezierPath()
        polygon.windingRule = .nonZero
        polygon.move(to: points[0])
        guard points.count > 2 else {
            for point in points.dropFirst() {
                polygon.line(to: point)
            }
            polygon.close()
            return polygon
        }

        for index in 1..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            let midpoint = NSPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
            polygon.curve(to: midpoint, controlPoint1: current, controlPoint2: current)
        }
        polygon.curve(to: points[points.count - 1], controlPoint1: points[points.count - 2], controlPoint2: points[points.count - 2])
        polygon.close()
        return polygon
    }

    private func soilExpandedBounds(for coveragePath: CGPath, points: [NSPoint]) -> NSRect {
        let pathBounds = coveragePath.boundingBoxOfPath
        var bbox = NSRect(
            x: pathBounds.minX,
            y: pathBounds.minY,
            width: pathBounds.width,
            height: pathBounds.height
        )
        if bbox.isNull || bbox.isEmpty,
           let first = points.first {
            bbox = NSRect(x: first.x, y: first.y, width: 1, height: 1)
        }
        return bbox.insetBy(dx: -soilBrushRadius * 0.42, dy: -soilBrushRadius * 0.42)
    }

    private func drawSoilGranules(
        seed: Int,
        in bbox: NSRect,
        detailScale: CGFloat,
        alphaScale: CGFloat
    ) {
        let area = max(1, bbox.width * bbox.height)
        let count = Int(min(620, max(85, area / 46) * detailScale))
        for index in 0..<count {
            let cx = bbox.minX + soilUnitNoise(seed: seed, index: index, salt: 2_011) * bbox.width
            let cy = bbox.minY + soilUnitNoise(seed: seed, index: index, salt: 3_019) * bbox.height
            let size = 0.7 + pow(soilUnitNoise(seed: seed, index: index, salt: 4_027), 2.6) * 5.8
            let stretch = 0.58 + soilUnitNoise(seed: seed, index: index, salt: 5_039) * 0.74
            let rect = NSRect(
                x: cx - size / 2,
                y: cy - size * stretch / 2,
                width: size,
                height: size * stretch
            )

            soilGrainColor(seed: seed, index: index, alpha: (0.20 + soilUnitNoise(seed: seed, index: index, salt: 6_041) * 0.28) * alphaScale)
                .setFill()
            NSBezierPath(ovalIn: rect).fill()
        }
    }

    private func drawSoilClods(
        seed: Int,
        in bbox: NSRect,
        detailScale: CGFloat,
        alphaScale: CGFloat
    ) {
        let area = max(1, bbox.width * bbox.height)
        let count = Int(min(72, max(12, area / 1_350) * detailScale))
        for index in 0..<count {
            let cx = bbox.minX + soilUnitNoise(seed: seed, index: index, salt: 7_001) * bbox.width
            let cy = bbox.minY + soilUnitNoise(seed: seed, index: index, salt: 7_009) * bbox.height
            let width = 4.5 + pow(soilUnitNoise(seed: seed, index: index, salt: 7_021), 1.7) * soilBrushRadius * 0.34
            let height = width * (0.42 + soilUnitNoise(seed: seed, index: index, salt: 7_033) * 0.58)
            let angle = soilSignedNoise(seed: seed, index: index, salt: 7_047) * 28
            let rect = NSRect(x: -width / 2, y: -height / 2, width: width, height: height)

            guard let context = NSGraphicsContext.current?.cgContext else {
                continue
            }
            context.saveGState()
            context.translateBy(x: cx, y: cy)
            context.rotate(by: angle * .pi / 180)

            let clod = NSBezierPath(ovalIn: rect)
            let shadow = NSShadow()
            shadow.shadowColor = color(red: 19, green: 13, blue: 8, alpha: 0.22 * alphaScale)
            shadow.shadowBlurRadius = 2.4
            shadow.shadowOffset = NSSize(width: 1.2, height: 1.6)
            shadow.set()
            soilClodColor(seed: seed, index: index, alpha: (0.58 + soilUnitNoise(seed: seed, index: index, salt: 7_057) * 0.22) * alphaScale)
                .setFill()
            clod.fill()

            NSShadow().set()
            color(red: 176, green: 136, blue: 83, alpha: 0.20 * alphaScale).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: width * 0.18, dy: height * 0.22).offsetBy(dx: -width * 0.10, dy: -height * 0.14)).fill()
            context.restoreGState()
        }
    }

    private func drawSoilCracksAndFibers(
        seed: Int,
        in bbox: NSRect,
        detailScale: CGFloat,
        alphaScale: CGFloat
    ) {
        let count = Int(22 * detailScale)
        guard count > 0 else {
            return
        }

        for index in 0..<count {
            let x = bbox.minX + soilUnitNoise(seed: seed, index: index, salt: 8_011) * bbox.width
            let y = bbox.minY + soilUnitNoise(seed: seed, index: index, salt: 8_019) * bbox.height
            let length = 8 + soilUnitNoise(seed: seed, index: index, salt: 8_029) * soilBrushRadius * 0.7
            let angle = soilSignedNoise(seed: seed, index: index, salt: 8_037) * .pi
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: y))
            let bend = soilSignedNoise(seed: seed, index: index, salt: 8_041) * length * 0.38
            let end = NSPoint(x: x + cos(angle) * length, y: y + sin(angle) * length)
            let control = NSPoint(
                x: x + cos(angle + .pi / 2) * bend + cos(angle) * length * 0.46,
                y: y + sin(angle + .pi / 2) * bend + sin(angle) * length * 0.46
            )
            path.curve(to: end, controlPoint1: control, controlPoint2: control)
            path.lineCapStyle = .round
            path.lineWidth = 0.7 + soilUnitNoise(seed: seed, index: index, salt: 8_047) * 1.4

            if index.isMultiple(of: 3) {
                color(red: 189, green: 154, blue: 97, alpha: 0.18 * alphaScale).setStroke()
            } else {
                color(red: 28, green: 19, blue: 12, alpha: 0.23 * alphaScale).setStroke()
            }
            path.stroke()
        }
    }

    private func drawSoilOverspray(
        points: [NSPoint],
        seed: Int,
        detailScale: CGFloat,
        alphaScale: CGFloat
    ) {
        guard !points.isEmpty else {
            return
        }

        let count = Int(min(230, max(28, CGFloat(points.count) * 2.9) * detailScale))
        for index in 0..<count {
            let pointIndex = min(points.count - 1, Int(soilUnitNoise(seed: seed, index: index, salt: 9_013) * CGFloat(points.count)))
            let base = points[pointIndex]
            let angle = soilUnitNoise(seed: seed, index: index, salt: 9_017) * .pi * 2
            let radius = soilBrushRadius * (0.52 + pow(soilUnitNoise(seed: seed, index: index, salt: 9_023), 1.9) * 1.24)
            let size = 1.1 + soilUnitNoise(seed: seed, index: index, salt: 9_031) * 4.8
            let rect = NSRect(
                x: base.x + cos(angle) * radius - size / 2,
                y: base.y + sin(angle) * radius - size / 2,
                width: size,
                height: size * (0.58 + soilUnitNoise(seed: seed, index: index, salt: 9_047) * 0.66)
            )

            soilGrainColor(seed: seed, index: index, alpha: (0.08 + soilUnitNoise(seed: seed, index: index, salt: 9_053) * 0.17) * alphaScale)
                .setFill()
            NSBezierPath(ovalIn: rect).fill()
        }
    }

    private func drawSoilEdgeRelief(
        _ coveragePath: CGPath,
        context: CGContext,
        alphaScale: CGFloat
    ) {
        context.saveGState()
        context.addPath(coveragePath)
        context.setLineWidth(2.2)
        context.setStrokeColor(color(red: 32, green: 21, blue: 13, alpha: 0.38 * alphaScale).cgColor)
        context.setShadow(
            offset: CGSize(width: 1.8, height: 2.0),
            blur: 3.4,
            color: color(red: 14, green: 9, blue: 5, alpha: 0.22 * alphaScale).cgColor
        )
        context.strokePath()
        context.restoreGState()

        context.saveGState()
        context.translateBy(x: -1.1, y: -1.2)
        context.addPath(coveragePath)
        context.setLineWidth(1.15)
        context.setStrokeColor(color(red: 190, green: 149, blue: 93, alpha: 0.23 * alphaScale).cgColor)
        context.strokePath()
        context.restoreGState()
    }

    private func soilGrainColor(seed: Int, index: Int, alpha: CGFloat) -> NSColor {
        let tone = soilUnitNoise(seed: seed, index: index, salt: 10_001)
        if tone < 0.20 {
            return color(red: 38, green: 27, blue: 17, alpha: alpha * 0.95)
        } else if tone < 0.48 {
            return color(red: 69, green: 48, blue: 30, alpha: alpha)
        } else if tone < 0.78 {
            return color(red: 116, green: 84, blue: 52, alpha: alpha * 0.92)
        } else {
            return color(red: 171, green: 134, blue: 83, alpha: alpha * 0.74)
        }
    }

    private func soilClodColor(seed: Int, index: Int, alpha: CGFloat) -> NSColor {
        let warmth = soilSignedNoise(seed: seed, index: index, salt: 10_211)
        return color(
            red: 80 + warmth * 18,
            green: 55 + warmth * 10,
            blue: 33 + warmth * 7,
            alpha: alpha
        )
    }

    private func soilUnitNoise(seed: Int, index: Int, salt: Int) -> CGFloat {
        let mixed = Double(seed) * 12.9898
            + Double(index) * 78.233
            + Double(salt) * 37.719
        let value = sin(mixed) * 43_758.545_312_3
        return CGFloat(value - floor(value))
    }

    private func soilSignedNoise(seed: Int, index: Int, salt: Int) -> CGFloat {
        soilUnitNoise(seed: seed, index: index, salt: salt) * 2 - 1
    }

    private func cgPath(from path: NSBezierPath) -> CGPath {
        let cgPath = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)
        for index in 0..<path.elementCount {
            let type = path.element(at: index, associatedPoints: &points)
            switch type {
            case .moveTo:
                cgPath.move(to: points[0])
            case .lineTo:
                cgPath.addLine(to: points[0])
            case .curveTo, .cubicCurveTo:
                cgPath.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                cgPath.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                cgPath.closeSubpath()
            @unknown default:
                break
            }
        }
        return cgPath
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
        drawSoilMaterial(points: soilBrushDraftPoints, seed: 17_171, mode: .draft)
        if isSoilBrushMode,
           let cursor = soilBrushDraftPoints.last {
            let cursorRect = NSRect(
                x: cursor.x - soilBrushRadius,
                y: cursor.y - soilBrushRadius,
                width: soilBrushRadius * 2,
                height: soilBrushRadius * 2
            )
            color(red: 232, green: 198, blue: 123, alpha: 0.18).setFill()
            NSBezierPath(ovalIn: cursorRect).fill()
            color(red: 255, green: 226, blue: 147, alpha: 0.38).setStroke()
            let cursorPath = NSBezierPath(ovalIn: cursorRect.insetBy(dx: 1.5, dy: 1.5))
            cursorPath.lineWidth = 1.2
            cursorPath.stroke()
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
            guard !viewPoints.isEmpty else {
                continue
            }
            let coveragePath = soilCoveragePath(for: viewPoints)

            if coveragePath.contains(anchor, using: .winding, transform: .identity) {
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
            hasher.combine(patch.soilSeed)
            let bounds = patch.boundingBox
            hasher.combine(Int((bounds.minX * 10_000).rounded()))
            hasher.combine(Int((bounds.minY * 10_000).rounded()))
            hasher.combine(Int((bounds.maxX * 10_000).rounded()))
            hasher.combine(Int((bounds.maxY * 10_000).rounded()))
        }
        return hasher.finalize()
    }

    // MARK: - Self-test rendering probes

    func soilPatchMaterialStatsForSelfTest(
        _ patch: SoilPatch,
        backingScale: CGFloat = 1
    ) -> (alphaPixelCount: Int, colorBucketCount: Int, alphaBucketCount: Int, alphaBounds: NSRect)? {
        let pixelsWide = max(1, Int((bounds.width * backingScale).rounded()))
        let pixelsHigh = max(1, Int((bounds.height * backingScale).rounded()))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let base = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }
        rep.size = bounds.size

        NSGraphicsContext.saveGraphicsState()
        let flipped = NSGraphicsContext(cgContext: base.cgContext, flipped: true)
        NSGraphicsContext.current = flipped
        flipped.cgContext.translateBy(x: 0, y: bounds.height)
        flipped.cgContext.scaleBy(x: 1, y: -1)
        drawSoilPatch(patch)
        NSGraphicsContext.restoreGraphicsState()

        var minX = pixelsWide
        var minY = pixelsHigh
        var maxX = -1
        var maxY = -1
        var alphaPixelCount = 0
        var colorBuckets = Set<Int>()
        var alphaBuckets = Set<Int>()
        for y in 0..<pixelsHigh {
            for x in 0..<pixelsWide {
                guard let color = rep.colorAt(x: x, y: y),
                      color.alphaComponent > 0.03 else {
                    continue
                }
                alphaPixelCount += 1
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
                let red = Int((color.redComponent * 255).rounded()) / 12
                let green = Int((color.greenComponent * 255).rounded()) / 12
                let blue = Int((color.blueComponent * 255).rounded()) / 12
                let alpha = Int((color.alphaComponent * 255).rounded()) / 10
                colorBuckets.insert(red << 16 | green << 8 | blue)
                alphaBuckets.insert(alpha)
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        let alphaBounds = NSRect(
            x: CGFloat(minX) / backingScale,
            y: CGFloat(minY) / backingScale,
            width: CGFloat(maxX - minX + 1) / backingScale,
            height: CGFloat(maxY - minY + 1) / backingScale
        )
        return (alphaPixelCount, colorBuckets.count, alphaBuckets.count, alphaBounds)
    }

    // MARK: - Palette

    static let soilBaseColor = NSColor(red: 74 / 255, green: 51 / 255, blue: 31 / 255, alpha: 0.92)
}
