import AppKit
import CoreGraphics
import Darwin

enum CustomPlantAssetPostProcessor {
    private struct RGB {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
    }

    private static let chromaKeyMagenta = RGB(red: 255, green: 0, blue: 255)

    private struct AlphaProfile {
        let pixelCount: Int
        let transparentCount: Int
        let visibleCount: Int

        var hasUsefulTransparency: Bool {
            guard pixelCount > 0 else {
                return false
            }

            let transparentRatio = Double(transparentCount) / Double(pixelCount)
            let visibleRatio = Double(visibleCount) / Double(pixelCount)
            return transparentRatio > 0.04 && visibleRatio > 0.006
        }
    }

    static func transparentPNGData(from imageData: Data) throws -> Data {
        let raster = try rgbaRaster(from: imageData)
        if alphaProfile(in: raster.buffer).hasUsefulTransparency {
            var alphaReadyBuffer = raster.buffer
            if hasResidualChromaKeyPixels(in: alphaReadyBuffer) {
                removeChromaKeyPixelsAnywhere(in: &alphaReadyBuffer)
            }
            clearFullyTransparentRGB(in: &alphaReadyBuffer)
            return try pngData(width: raster.width, height: raster.height, buffer: alphaReadyBuffer)
        }

        var buffer = raster.buffer
        let chromaCoverage = chromaKeyBorderCoverage(in: buffer, width: raster.width, height: raster.height)
        let isChromaKeyed = chromaCoverage > 0.18
        let dominantColors = dominantBorderColors(in: buffer, width: raster.width, height: raster.height)
        let backgroundColors = isChromaKeyed
            ? [chromaKeyMagenta] + dominantColors
            : dominantColors
        guard !backgroundColors.isEmpty else {
            throw CustomPlantAssetError.couldNotDecodeGeneratedImage
        }

        let backgroundMask = floodFillBackground(
            in: buffer,
            width: raster.width,
            height: raster.height,
            backgroundColors: backgroundColors,
            distanceThreshold: isChromaKeyed ? 96 : 54
        )
        applyAlphaCutout(
            to: &buffer,
            backgroundMask: backgroundMask,
            backgroundColors: backgroundColors,
            hardDistance: isChromaKeyed ? 24 : 18,
            softDistance: isChromaKeyed ? 56 : 36
        )
        if isChromaKeyed {
            removeChromaKeyPixelsAnywhere(in: &buffer)
            despillChromaMagentaEdges(in: &buffer)
        }
        clearFullyTransparentRGB(in: &buffer)

        let profile = alphaProfile(in: buffer)
        guard profile.hasUsefulTransparency else {
            throw CustomPlantAssetError.couldNotDecodeGeneratedImage
        }

        return try pngData(width: raster.width, height: raster.height, buffer: buffer)
    }

    static func isDisplayReadyPNGData(_ imageData: Data) -> Bool {
        guard let raster = try? rgbaRaster(from: imageData) else {
            return false
        }

        return alphaProfile(in: raster.buffer).hasUsefulTransparency
    }

    static func imageNeedsTransparencyRepair(_ imageData: Data) -> Bool {
        guard let raster = try? rgbaRaster(from: imageData) else {
            return true
        }

        return !alphaProfile(in: raster.buffer).hasUsefulTransparency
            || hasResidualChromaKeyPixels(in: raster.buffer)
    }

    private static func rgbaRaster(from imageData: Data) throws -> (width: Int, height: Int, buffer: [UInt8]) {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cgImage.width > 0,
              cgImage.height > 0 else {
            throw CustomPlantAssetError.couldNotDecodeGeneratedImage
        }

        let width = cgImage.width
        let height = cgImage.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = buffer.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress,
                  let context = CGContext(
                      data: baseAddress,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: width * 4,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }

            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else {
            throw CustomPlantAssetError.couldNotDecodeGeneratedImage
        }

        return (width, height, buffer)
    }

    private static func alphaProfile(in buffer: [UInt8]) -> AlphaProfile {
        let pixelCount = buffer.count / 4
        var transparentCount = 0
        var visibleCount = 0
        for pixelIndex in 0..<pixelCount {
            let alpha = buffer[pixelIndex * 4 + 3]
            if alpha < 16 {
                transparentCount += 1
            }
            if alpha > 26 {
                visibleCount += 1
            }
        }

        return AlphaProfile(
            pixelCount: pixelCount,
            transparentCount: transparentCount,
            visibleCount: visibleCount
        )
    }

    private static func chromaKeyBorderCoverage(in buffer: [UInt8], width: Int, height: Int) -> Double {
        guard width > 0, height > 0 else {
            return 0
        }

        let inset = min(18, max(1, min(width, height) / 24))
        var sampleCount = 0
        var chromaCount = 0

        func samplePixel(x: Int, y: Int) {
            let index = y * width + x
            sampleCount += 1
            if isChromaMagentaPixel(at: index, in: buffer, tolerance: 72) {
                chromaCount += 1
            }
        }

        for y in 0..<height {
            for x in 0..<inset {
                samplePixel(x: x, y: y)
                samplePixel(x: width - 1 - x, y: y)
            }
        }
        for x in 0..<width {
            for y in 0..<inset {
                samplePixel(x: x, y: y)
                samplePixel(x: x, y: height - 1 - y)
            }
        }

        return sampleCount == 0 ? 0 : Double(chromaCount) / Double(sampleCount)
    }

    private static func dominantBorderColors(in buffer: [UInt8], width: Int, height: Int) -> [RGB] {
        guard width > 0, height > 0 else {
            return []
        }

        var histogram: [Int: Int] = [:]
        let inset = min(18, max(1, min(width, height) / 24))
        func addPixel(x: Int, y: Int) {
            let offset = (y * width + x) * 4
            let redBin = Int(buffer[offset]) / 8
            let greenBin = Int(buffer[offset + 1]) / 8
            let blueBin = Int(buffer[offset + 2]) / 8
            let key = (redBin << 10) | (greenBin << 5) | blueBin
            histogram[key, default: 0] += 1
        }

        for y in 0..<height {
            for x in 0..<inset {
                addPixel(x: x, y: y)
                addPixel(x: width - 1 - x, y: y)
            }
        }
        for x in 0..<width {
            for y in 0..<inset {
                addPixel(x: x, y: y)
                addPixel(x: x, y: height - 1 - y)
            }
        }

        return histogram
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { key, _ in
                RGB(
                    red: UInt8(((key >> 10) & 31) * 8 + 4),
                    green: UInt8(((key >> 5) & 31) * 8 + 4),
                    blue: UInt8((key & 31) * 8 + 4)
                )
            }
    }

    private static func floodFillBackground(
        in buffer: [UInt8],
        width: Int,
        height: Int,
        backgroundColors: [RGB],
        distanceThreshold: Int
    ) -> [Bool] {
        let pixelCount = width * height
        var visited = [Bool](repeating: false, count: pixelCount)
        var queue: [Int] = []
        queue.reserveCapacity(min(pixelCount, 65_536))

        func enqueueIfBackground(x: Int, y: Int) {
            guard x >= 0, x < width, y >= 0, y < height else {
                return
            }

            let index = y * width + x
            guard !visited[index],
                  colorDistanceSquared(at: index, in: buffer, to: backgroundColors) <= distanceThreshold * distanceThreshold else {
                return
            }

            visited[index] = true
            queue.append(index)
        }

        for x in 0..<width {
            enqueueIfBackground(x: x, y: 0)
            enqueueIfBackground(x: x, y: height - 1)
        }
        for y in 0..<height {
            enqueueIfBackground(x: 0, y: y)
            enqueueIfBackground(x: width - 1, y: y)
        }

        var cursor = 0
        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1

            let x = index % width
            let y = index / width
            enqueueIfBackground(x: x - 1, y: y)
            enqueueIfBackground(x: x + 1, y: y)
            enqueueIfBackground(x: x, y: y - 1)
            enqueueIfBackground(x: x, y: y + 1)
        }

        return visited
    }

    private static func applyAlphaCutout(
        to buffer: inout [UInt8],
        backgroundMask: [Bool],
        backgroundColors: [RGB],
        hardDistance: Double,
        softDistance: Double
    ) {
        for pixelIndex in 0..<backgroundMask.count where backgroundMask[pixelIndex] {
            let distance = sqrt(Double(colorDistanceSquared(at: pixelIndex, in: buffer, to: backgroundColors)))
            let alpha: UInt8
            if distance <= hardDistance {
                alpha = 0
            } else {
                let fade = min(1, max(0, (distance - hardDistance) / softDistance))
                alpha = UInt8((fade * 255).rounded())
            }

            buffer[pixelIndex * 4 + 3] = alpha
        }
    }

    private static func removeChromaKeyPixelsAnywhere(in buffer: inout [UInt8]) {
        let pixelCount = buffer.count / 4
        for pixelIndex in 0..<pixelCount {
            let offset = pixelIndex * 4
            guard buffer[offset + 3] > 0 else {
                continue
            }

            guard isChromaMagentaPixel(at: pixelIndex, in: buffer, tolerance: 104)
                    || isSaturatedChromaMagentaLikePixel(at: pixelIndex, in: buffer) else {
                continue
            }

            let distance = sqrt(Double(colorDistanceSquared(at: pixelIndex, in: buffer, to: [chromaKeyMagenta])))
            if distance <= 88 {
                buffer[offset + 3] = 0
            } else {
                let fade = min(1, max(0, (distance - 88) / 52))
                buffer[offset + 3] = min(buffer[offset + 3], UInt8((fade * 255).rounded()))
            }
        }
    }

    private static func hasResidualChromaKeyPixels(in buffer: [UInt8]) -> Bool {
        let pixelCount = buffer.count / 4
        guard pixelCount > 0 else {
            return false
        }

        var residualCount = 0
        for pixelIndex in 0..<pixelCount {
            let alpha = buffer[pixelIndex * 4 + 3]
            guard alpha > 24 else {
                continue
            }

            if isChromaMagentaPixel(at: pixelIndex, in: buffer, tolerance: 104)
                || isSaturatedChromaMagentaLikePixel(at: pixelIndex, in: buffer) {
                residualCount += 1
            }
        }

        return residualCount >= max(24, pixelCount / 220)
    }

    private static func despillChromaMagentaEdges(in buffer: inout [UInt8]) {
        let pixelCount = buffer.count / 4
        for pixelIndex in 0..<pixelCount {
            let offset = pixelIndex * 4
            let alpha = buffer[offset + 3]
            guard alpha > 0 else {
                continue
            }

            let red = Int(buffer[offset])
            let green = Int(buffer[offset + 1])
            let blue = Int(buffer[offset + 2])
            let magentaSpill = max(0, min(red, blue) - green - 8)
            guard alpha < 250 || magentaSpill > 18 else {
                continue
            }

            let correction = min(magentaSpill, 120)
            buffer[offset] = UInt8(max(0, red - correction))
            buffer[offset + 1] = UInt8(min(255, green + correction / 5))
            buffer[offset + 2] = UInt8(max(0, blue - correction))
        }
    }

    private static func clearFullyTransparentRGB(in buffer: inout [UInt8]) {
        let pixelCount = buffer.count / 4
        for pixelIndex in 0..<pixelCount where buffer[pixelIndex * 4 + 3] == 0 {
            let offset = pixelIndex * 4
            buffer[offset] = 0
            buffer[offset + 1] = 0
            buffer[offset + 2] = 0
        }
    }

    private static func isChromaMagentaPixel(at pixelIndex: Int, in buffer: [UInt8], tolerance: Int) -> Bool {
        colorDistanceSquared(at: pixelIndex, in: buffer, to: [chromaKeyMagenta]) <= tolerance * tolerance
    }

    private static func isSaturatedChromaMagentaLikePixel(at pixelIndex: Int, in buffer: [UInt8]) -> Bool {
        let offset = pixelIndex * 4
        let red = Int(buffer[offset])
        let green = Int(buffer[offset + 1])
        let blue = Int(buffer[offset + 2])
        return red >= 150
            && blue >= 150
            && green <= 72
            && abs(red - blue) <= 82
    }

    private static func colorDistanceSquared(
        at pixelIndex: Int,
        in buffer: [UInt8],
        to colors: [RGB]
    ) -> Int {
        let offset = pixelIndex * 4
        let red = Int(buffer[offset])
        let green = Int(buffer[offset + 1])
        let blue = Int(buffer[offset + 2])

        return colors.reduce(Int.max) { currentBest, color in
            let redDelta = red - Int(color.red)
            let greenDelta = green - Int(color.green)
            let blueDelta = blue - Int(color.blue)
            let distance = redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta
            return min(currentBest, distance)
        }
    }

    private static func pngData(width: Int, height: Int, buffer: [UInt8]) throws -> Data {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ),
        let bitmapData = rep.bitmapData else {
            throw CustomPlantAssetError.couldNotDecodeGeneratedImage
        }

        buffer.withUnsafeBytes { source in
            if let baseAddress = source.baseAddress {
                memcpy(bitmapData, baseAddress, buffer.count)
            }
        }

        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw CustomPlantAssetError.couldNotDecodeGeneratedImage
        }

        return data
    }
}
