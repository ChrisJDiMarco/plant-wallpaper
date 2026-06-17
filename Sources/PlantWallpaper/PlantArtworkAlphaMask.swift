import AppKit

/// A low-resolution alpha grid sampled from a plant's PNG artwork, used for
/// pixel-accurate hit testing. Clicks count as "on the plant" only when they
/// land on (or within a small slop of) actually visible pixels, instead of
/// anywhere inside a padded bounding rectangle.
struct PlantArtworkAlphaMask {
    /// Alpha values above this are treated as visible for hit testing.
    static let hitAlphaThreshold: UInt8 = 26 // ~10%

    /// Grid dimensions. Rows are stored bottom-up (CoreGraphics context order),
    /// matching the view's y-up coordinate mapping of the drawn artwork.
    let width: Int
    let height: Int
    private let alphas: [UInt8]

    /// Normalized centroid (u from left, v from bottom) of clearly visible
    /// pixels - a guaranteed-clickable spot near the plant's visual mass.
    let opaqueCentroid: (u: Double, v: Double)

    init?(image: NSImage, maxDimension: Int = 96) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cgImage.width > 0,
              cgImage.height > 0 else {
            return nil
        }

        let scale = min(1, Double(maxDimension) / Double(max(cgImage.width, cgImage.height)))
        let gridWidth = max(1, Int((Double(cgImage.width) * scale).rounded()))
        let gridHeight = max(1, Int((Double(cgImage.height) * scale).rounded()))

        var rgbaBuffer = [UInt8](repeating: 0, count: gridWidth * gridHeight * 4)
        let drawn = rgbaBuffer.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress,
                  let context = CGContext(
                      data: baseAddress,
                      width: gridWidth,
                      height: gridHeight,
                      bitsPerComponent: 8,
                      bytesPerRow: gridWidth * 4,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }

            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: gridWidth, height: gridHeight))
            return true
        }
        guard drawn else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: gridWidth * gridHeight)
        for index in 0..<(gridWidth * gridHeight) {
            buffer[index] = rgbaBuffer[index * 4 + 3]
        }

        width = gridWidth
        height = gridHeight
        alphas = buffer

        var sumU = 0.0
        var sumV = 0.0
        var visibleCount = 0
        for row in 0..<gridHeight {
            for column in 0..<gridWidth where buffer[row * gridWidth + column] > 64 {
                sumU += Double(column)
                sumV += Double(row)
                visibleCount += 1
            }
        }
        if visibleCount > 0 {
            // The raw centroid of a concave sprite (split canopies, forked
            // stems) can land on a transparent gap; snap it to the nearest
            // clearly visible cell so it is always a clickable point.
            let centroidColumn = sumU / Double(visibleCount)
            let centroidRow = sumV / Double(visibleCount)
            var bestColumn = Int(centroidColumn)
            var bestRow = Int(centroidRow)
            var bestDistance = Double.greatestFiniteMagnitude
            for row in 0..<gridHeight {
                for column in 0..<gridWidth where buffer[row * gridWidth + column] > 64 {
                    let distance = pow(Double(column) - centroidColumn, 2)
                        + pow(Double(row) - centroidRow, 2)
                    if distance < bestDistance {
                        bestDistance = distance
                        bestColumn = column
                        bestRow = row
                    }
                }
            }
            opaqueCentroid = (
                u: (Double(bestColumn) + 0.5) / Double(gridWidth),
                v: (Double(bestRow) + 0.5) / Double(gridHeight)
            )
        } else {
            opaqueCentroid = (u: 0.5, v: 0.5)
        }
    }

    /// Whether the pixel at normalized coordinates is visible.
    /// `u` runs left-to-right, `v` runs bottom-to-top, both in [0, 1].
    func isVisible(u: Double, v: Double) -> Bool {
        guard u >= 0, u <= 1, v >= 0, v <= 1 else {
            return false
        }

        let column = min(width - 1, max(0, Int(u * Double(width))))
        let row = min(height - 1, max(0, Int(v * Double(height))))
        return alphas[row * width + column] > Self.hitAlphaThreshold
    }

    /// Whether any visible pixel exists within a normalized slop window
    /// around (u, v). Scans at most ~9x9 samples regardless of slop size.
    func hasVisiblePixel(nearU u: Double, v: Double, slopU: Double, slopV: Double) -> Bool {
        let safeSlopU = max(0, slopU)
        let safeSlopV = max(0, slopV)
        let steps = 4
        for rowStep in -steps...steps {
            for columnStep in -steps...steps {
                let sampleU = u + safeSlopU * Double(columnStep) / Double(steps)
                let sampleV = v + safeSlopV * Double(rowStep) / Double(steps)
                if isVisible(u: sampleU, v: sampleV) {
                    return true
                }
            }
        }
        return false
    }
}
