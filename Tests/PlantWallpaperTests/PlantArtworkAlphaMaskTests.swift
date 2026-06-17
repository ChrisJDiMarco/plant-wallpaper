import AppKit
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Plant artwork alpha mask")
struct PlantArtworkAlphaMaskTests {
    /// An image whose right half is opaque and left half fully transparent.
    private static func makeHalfOpaqueImage(size: NSSize = NSSize(width: 64, height: 64)) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            NSColor.green.setFill()
            NSRect(
                x: rect.midX,
                y: rect.minY,
                width: rect.width / 2,
                height: rect.height
            ).fill()
            return true
        }
    }

    @Test("visible pixels hit and transparent pixels miss")
    func visiblePixelsHitAndTransparentPixelsMiss() throws {
        let mask = try #require(PlantArtworkAlphaMask(image: Self.makeHalfOpaqueImage()))

        #expect(mask.isVisible(u: 0.75, v: 0.5))
        #expect(!mask.isVisible(u: 0.25, v: 0.5))
        #expect(!mask.isVisible(u: -0.2, v: 0.5))
        #expect(!mask.isVisible(u: 0.25, v: 1.4))
    }

    @Test("slop window finds nearby visible pixels without reaching far ones")
    func slopWindowFindsNearbyVisiblePixels() throws {
        let mask = try #require(PlantArtworkAlphaMask(image: Self.makeHalfOpaqueImage()))

        // Just left of the opaque half: reachable with a small slop.
        #expect(mask.hasVisiblePixel(nearU: 0.46, v: 0.5, slopU: 0.06, slopV: 0.06))
        // Far left: not reachable with the same slop.
        #expect(!mask.hasVisiblePixel(nearU: 0.10, v: 0.5, slopU: 0.06, slopV: 0.06))
    }

    @Test("opaque centroid sits inside the visible half")
    func opaqueCentroidSitsInsideVisibleHalf() throws {
        let mask = try #require(PlantArtworkAlphaMask(image: Self.makeHalfOpaqueImage()))

        #expect(mask.opaqueCentroid.u > 0.6)
        #expect(mask.opaqueCentroid.u < 0.9)
        #expect(mask.isVisible(u: mask.opaqueCentroid.u, v: mask.opaqueCentroid.v))
    }

    @Test("bundled plant artwork produces masks with clickable centroids")
    func bundledPlantArtworkProducesMasksWithClickableCentroids() {
        for species in PlantAssetLibrary.shared.displayableSpecies() {
            guard let mask = PlantAssetLibrary.shared.alphaMask(for: species, growth: 0.5) else {
                Issue.record("No alpha mask for \(species.displayName)")
                continue
            }

            #expect(
                mask.isVisible(u: mask.opaqueCentroid.u, v: mask.opaqueCentroid.v),
                "\(species.displayName) centroid should land on visible pixels"
            )
        }
    }
}
