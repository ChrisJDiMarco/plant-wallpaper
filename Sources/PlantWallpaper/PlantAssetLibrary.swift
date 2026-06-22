import AppKit
import PlantGardenCore

@MainActor
final class PlantAssetLibrary {
    static let shared = PlantAssetLibrary()
    static let stageCount = 10

    private var cache: [String: NSImage] = [:]
    private var alphaMaskCache: [ObjectIdentifier: PlantArtworkAlphaMask?] = [:]
    private var stageIndicesCache: [PlantSpecies: [Int]] = [:]

    private struct ResampledImageKey: Hashable {
        let source: ObjectIdentifier
        let pixelHeight: Int
    }

    private var resampledImageCache: [ResampledImageKey: NSImage] = [:]
    private static let resampledCacheLimit = 256

    /// Pixel-alpha mask for the artwork currently shown for the species at the
    /// given growth, used for click hit testing. Cached per resolved image.
    func alphaMask(for species: PlantSpecies, growth: Double) -> PlantArtworkAlphaMask? {
        guard let image = image(for: species, growth: growth) else {
            return nil
        }

        let key = ObjectIdentifier(image)
        if let cachedMask = alphaMaskCache[key] {
            return cachedMask
        }

        let mask = PlantArtworkAlphaMask(image: image)
        alphaMaskCache[key] = mask
        return mask
    }

    func image(for species: PlantSpecies) -> NSImage? {
        imageIfAvailable(named: assetName(for: species))
    }

    func image(for species: PlantSpecies, growth: Double) -> NSImage? {
        image(for: species, stageIndex: stageIndex(for: growth))
    }

    func image(for species: PlantSpecies, stageIndex: Int) -> NSImage? {
        let safeIndex = min(PlantAssetStage.defaultStageCount - 1, max(0, stageIndex))
        if let exactStage = imageIfAvailable(named: stageAssetName(for: species, index: safeIndex)) {
            return exactStage
        }

        if let nearestStageAssetName = nearestStageAssetName(for: species, index: safeIndex),
           let nearestStage = imageIfAvailable(named: nearestStageAssetName) {
            return nearestStage
        }

        return image(for: species)
    }

    func stageIndex(for growth: Double) -> Int {
        PlantAssetStage(growth: growth, stageCount: Self.stageCount).index
    }

    /// A copy of `image` pre-resampled close to the requested on-screen
    /// height, cached per source image and size bucket. Drawing the
    /// full-resolution stage asset scaled down with high interpolation costs
    /// a Lanczos resample (vImage) per plant per repaint — with the garden
    /// repainting twice a second that was the app's single biggest steady
    /// CPU cost. Heights bucket to 32pt steps so slow growth doesn't mint a
    /// new bitmap every repaint; the final ≤32pt adjustment at draw time is
    /// a cheap near-1:1 blit.
    func resampledImage(for image: NSImage, targetHeight: CGFloat, backingScale: CGFloat) -> NSImage {
        guard image.size.height > 0, image.size.width > 0, targetHeight > 0 else {
            return image
        }
        let bucketHeight = ceil(max(16, targetHeight) / 32) * 32
        let pixelHeight = Int(bucketHeight * max(1, backingScale))
        // Resampling only pays off shrinking; at or above source resolution
        // just use the original.
        guard CGFloat(pixelHeight) < image.size.height else {
            return image
        }

        let key = ResampledImageKey(source: ObjectIdentifier(image), pixelHeight: pixelHeight)
        if let cached = resampledImageCache[key] {
            return cached
        }

        let aspect = image.size.width / image.size.height
        let pixelWidth = max(1, Int((CGFloat(pixelHeight) * aspect).rounded()))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return image
        }
        rep.size = NSSize(width: bucketHeight * aspect, height: bucketHeight)

        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = context
            context.imageInterpolation = .high
            image.draw(
                in: NSRect(origin: .zero, size: rep.size),
                from: NSRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1
            )
            context.flushGraphics()
        }
        NSGraphicsContext.restoreGraphicsState()

        let resampled = NSImage(size: rep.size)
        resampled.addRepresentation(rep)
        resampled.cacheMode = .always
        if resampledImageCache.count >= Self.resampledCacheLimit {
            resampledImageCache.removeAll(keepingCapacity: true)
        }
        resampledImageCache[key] = resampled
        return resampled
    }

    func hasDisplayableAsset(for species: PlantSpecies) -> Bool {
        !availableStageIndices(for: species).isEmpty
    }

    func hasCompleteGrowthAssetSet(for species: PlantSpecies) -> Bool {
        (0..<Self.stageCount).allSatisfy { index in
            imageURL(named: stageAssetName(for: species, index: index)) != nil
        }
    }

    func initialGrowth(for species: PlantSpecies) -> Double {
        availableStageIndices(for: species).contains(0) ? 0.08 : 1.0
    }

    func nextGrowthMilestone(for species: PlantSpecies, growth: Double) -> Double? {
        let currentIndex = stageIndex(for: growth)
        guard let nextIndex = availableStageIndices(for: species)
            .sorted()
            .first(where: { $0 > currentIndex }) else {
            return nil
        }

        return nextIndex == Self.stageCount - 1
            ? 1.0
            : Double(nextIndex) / Double(Self.stageCount)
    }

    func displayableSpecies(in kind: PlantKind? = nil) -> [PlantSpecies] {
        PlantSpecies.allCases.filter { species in
            if let kind, species.kind != kind {
                return false
            }

            return hasDisplayableAsset(for: species)
        }
    }

    private func imageIfAvailable(named name: String) -> NSImage? {
        if let cachedImage = cache[name] {
            return cachedImage
        }

        guard let url = imageURL(named: name) else {
            return nil
        }
        guard let image = NSImage(contentsOf: url) else {
            NSLog("Plant Wallpaper missing bundled plant asset: \(name).png")
            return nil
        }

        image.cacheMode = .always
        cache[name] = image
        return image
    }

    private func imageURL(named name: String) -> URL? {
        Bundle.appResources.url(forResource: name, withExtension: "png")
            ?? Bundle.appResources.url(
                forResource: name,
                withExtension: "png",
                subdirectory: "PlantAssets"
            )
    }

    private func nearestStageAssetName(for species: PlantSpecies, index: Int) -> String? {
        availableStageIndices(for: species)
            .sorted { left, right in
                abs(left - index) < abs(right - index)
            }
            .map { stageAssetName(for: species, index: $0) }
            .first
    }

    private func availableStageIndices(for species: PlantSpecies) -> [Int] {
        // Cached: this runs on every plant draw and each uncached pass costs
        // a bundle URL lookup per stage. The bundle never changes at runtime.
        if let cached = stageIndicesCache[species] {
            return cached
        }
        let indices = (0..<Self.stageCount).filter { index in
            imageURL(named: stageAssetName(for: species, index: index)) != nil
        }
        stageIndicesCache[species] = indices
        return indices
    }

    private func assetName(for species: PlantSpecies) -> String {
        species.rawValue.kebabCasedPlantAssetName
    }

    private func stageAssetName(for species: PlantSpecies, index: Int) -> String {
        "\(assetName(for: species))-stage-\(String(format: "%02d", index))"
    }
}

private extension String {
    var kebabCasedPlantAssetName: String {
        reduce(into: "") { result, character in
            if character.isUppercase {
                if !result.isEmpty {
                    result.append("-")
                }
                result.append(character.lowercased())
            } else {
                result.append(character)
            }
        }
    }
}
