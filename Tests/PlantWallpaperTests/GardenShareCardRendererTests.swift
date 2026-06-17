import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden share card renderer")
struct GardenShareCardRendererTests {
    @Test("share card renders at the expected size and exports PNG data")
    func shareCardRendersAndExports() throws {
        let state = GardenState.defaultGarden(screenCount: 1)
        let card = GardenShareCardRenderer.makeCard(
            state: state,
            sceneKey: "empty-conservatory-hall"
        )

        #expect(card.size == GardenShareCardRenderer.cardSize)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("garden-share-card-\(UUID().uuidString).png")
        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        try GardenShareCardRenderer.writeCardPNG(
            state: state,
            sceneKey: "empty-conservatory-hall",
            to: outputURL
        )

        let data = try Data(contentsOf: outputURL)
        #expect(data.count > 10_000, "PNG export should contain real image data")
        #expect(NSImage(data: data) != nil)
    }
}
