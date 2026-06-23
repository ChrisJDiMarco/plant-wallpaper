import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden canvas render cache")
struct GardenCanvasRenderCacheTests {
    @Test("steady plant layer cache preserves live plant geometry")
    func steadyPlantLayerCachePreservesLivePlantGeometry() throws {
        let plant = Plant(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            species: .japaneseMaple,
            screenIndex: 0,
            position: GardenPoint(x: 0.68, y: 0.78),
            growth: 1,
            hydration: 0.82,
            health: 0.9,
            bloomProgress: 0,
            swaySeed: 42,
            scale: 1.0
        )
        let store = GardenStore(
            state: GardenState(plants: [plant]),
            persistence: GardenPersistence(
                directoryURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("garden-cache-test-\(UUID().uuidString)", isDirectory: true)
            ),
            activeSceneKey: "brazilian-rooftop-garden"
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 960, height: 540),
            screenIndex: 0,
            store: store
        )
        let morning = try #require(DateComponents(
            calendar: Calendar.current,
            timeZone: Calendar.current.timeZone,
            year: 2026,
            month: 6,
            day: 12,
            hour: 9
        ).date)
        canvasView.currentDateProvider = { morning }

        let liveBounds = try #require(canvasView.plantLayerAlphaBoundsForSelfTest(useCachedLayer: false))
        let cachedBounds = try #require(canvasView.plantLayerAlphaBoundsForSelfTest(useCachedLayer: true))

        #expect(abs(liveBounds.midX - cachedBounds.midX) <= 4)
        #expect(abs(liveBounds.midY - cachedBounds.midY) <= 4)
        #expect(abs(liveBounds.width - cachedBounds.width) <= 5)
        #expect(abs(liveBounds.height - cachedBounds.height) <= 5)
    }

    @Test("plant layer darkens at night")
    func plantLayerDarkensAtNight() throws {
        let plant = Plant(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            species: .japaneseMaple,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.80),
            growth: 1,
            hydration: 0.90,
            health: 0.92,
            bloomProgress: 0,
            swaySeed: 72,
            scale: 1.0
        )
        let store = GardenStore(
            state: GardenState(plants: [plant], isAmbientWildlifeEnabled: false),
            persistence: GardenPersistence(
                directoryURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("garden-light-test-\(UUID().uuidString)", isDirectory: true)
            ),
            activeSceneKey: "brazilian-rooftop-garden"
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 720, height: 420),
            screenIndex: 0,
            store: store
        )
        let calendar = Calendar.current
        let noon = try #require(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 11,
            hour: 12
        ).date)
        let night = try #require(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 11,
            hour: 23
        ).date)

        let noonBrightness = try #require(canvasView.plantLayerAverageBrightnessForSelfTest(
            useCachedLayer: true,
            date: noon,
            backingScale: 1
        ))
        let nightBrightness = try #require(canvasView.plantLayerAverageBrightnessForSelfTest(
            useCachedLayer: true,
            date: night,
            backingScale: 1
        ))

        #expect(nightBrightness < noonBrightness * 0.86)
    }

    @Test("manual plant darkening reduces daytime plant brightness")
    func manualPlantDarkeningReducesDaytimePlantBrightness() throws {
        let plant = Plant(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            species: .japaneseMaple,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.80),
            growth: 1,
            hydration: 0.90,
            health: 0.92,
            bloomProgress: 0,
            swaySeed: 84,
            scale: 1.0
        )
        let store = GardenStore(
            state: GardenState(plants: [plant], isAmbientWildlifeEnabled: false),
            persistence: GardenPersistence(
                directoryURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("garden-manual-light-test-\(UUID().uuidString)", isDirectory: true)
            ),
            activeSceneKey: "brazilian-rooftop-garden"
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 720, height: 420),
            screenIndex: 0,
            store: store
        )
        let noon = try #require(DateComponents(
            calendar: Calendar.current,
            timeZone: Calendar.current.timeZone,
            year: 2026,
            month: 6,
            day: 11,
            hour: 12
        ).date)

        let baseBrightness = try #require(canvasView.plantLayerAverageBrightnessForSelfTest(
            useCachedLayer: true,
            date: noon,
            backingScale: 1
        ))

        store.setManualPlantDarkening(0.38)

        let shadedBrightness = try #require(canvasView.plantLayerAverageBrightnessForSelfTest(
            useCachedLayer: true,
            date: noon,
            backingScale: 1
        ))

        #expect(shadedBrightness < baseBrightness * 0.78)
    }

    @Test("oversized Room Studio objects bypass the composite plant layer cache")
    func oversizedRoomStudioObjectsBypassCompositePlantLayerCache() throws {
        let fixture = try RoomStudioCacheFixture()
        let customAssets = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        let record = try customAssets.storeAssetForSelfTest(
            request: CustomPlantAssetRequest(
                kind: .foliage,
                displayName: "Oversized Room Shelf",
                userDescription: "a very large room shelf",
                roomObjectCategory: .collectibles,
                experienceMode: .roomStudio
            ),
            imageData: try fixture.pngData(size: 96)
        )
        let prop = Plant(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            species: .fern,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.90),
            growth: 1,
            hydration: 0.90,
            health: 0.94,
            bloomProgress: 0,
            swaySeed: 88,
            scale: 8.0,
            customAssetID: record.id
        )
        let store = GardenStore(
            state: GardenState(
                plants: [prop],
                settings: GardenSettings.default.updating(experienceMode: .roomStudio)
            ),
            persistence: GardenPersistence(
                directoryURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("room-cache-test-\(UUID().uuidString)", isDirectory: true)
            ),
            activeSceneKey: "room-modern-bedroom-canvas",
            customPlantAssets: customAssets
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 1920, height: 1200),
            screenIndex: 0,
            store: store
        )

        let plan = try #require(canvasView.plantLayerCachePlanForSelfTest(backingScale: 2))

        #expect(plan.pixelCount > 6_000_000)
        #expect(!plan.shouldUseCompositeCache)
    }

    @Test("only Garden mode draws garden atmosphere canvas effects")
    func onlyGardenModeDrawsGardenAtmosphereCanvasEffects() {
        let gardenCanvas = canvas(for: .garden)
        let roomCanvas = canvas(for: .roomStudio)
        let alienCanvas = canvas(for: .alienUFO)

        #expect(gardenCanvas.drawsGardenAtmosphericCanvasEffectsForSelfTest())
        #expect(!roomCanvas.drawsGardenAtmosphericCanvasEffectsForSelfTest())
        #expect(!alienCanvas.drawsGardenAtmosphericCanvasEffectsForSelfTest())
    }

    @Test("progression level zero draws the waiting overlay")
    func progressionLevelZeroDrawsTheWaitingOverlay() {
        let profile = GardenProgressionProfile(
            lifestyleFantasy: "quiet artist life",
            placeInWorld: "misty lakeside",
            ageBracket: "starter",
            vibe: "calm"
        )
        let waitingCanvas = canvas(
            for: .garden,
            progression: GardenSceneProgression(isEnabled: true, level: 0, profile: profile)
        )
        let generatedCanvas = canvas(
            for: .garden,
            progression: GardenSceneProgression(isEnabled: true, level: 1, profile: profile)
        )
        let pausedCanvas = canvas(
            for: .garden,
            progression: GardenSceneProgression(isEnabled: false, level: 0, profile: profile)
        )

        #expect(waitingCanvas.drawsProgressionWaitingOverlayForSelfTest())
        #expect(!generatedCanvas.drawsProgressionWaitingOverlayForSelfTest())
        #expect(!pausedCanvas.drawsProgressionWaitingOverlayForSelfTest())
    }

    private func canvas(
        for mode: GardenExperienceMode,
        progression: GardenSceneProgression? = nil
    ) -> GardenCanvasView {
        GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 960, height: 540),
            screenIndex: 0,
            store: GardenStore(
                state: GardenState(
                    settings: .default.updating(experienceMode: mode),
                    progression: progression
                ),
                persistence: GardenPersistence(
                    directoryURL: FileManager.default.temporaryDirectory
                        .appendingPathComponent("garden-atmosphere-test-\(UUID().uuidString)", isDirectory: true)
                ),
                activeSceneKey: GardenExperienceModeScenePolicy.defaultScene(for: mode).rawValue
            )
        )
    }
}

private final class RoomStudioCacheFixture {
    let directoryURL: URL

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoomStudioCacheFixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func pngData(size: Int) throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw CocoaError(.fileWriteUnknown)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
        NSColor(calibratedRed: 0.25, green: 0.22, blue: 0.18, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(
            x: size / 5,
            y: size / 6,
            width: size * 3 / 5,
            height: size * 2 / 3
        ), xRadius: 6, yRadius: 6).fill()
        NSGraphicsContext.restoreGraphicsState()

        return try #require(bitmap.representation(using: .png, properties: [:]))
    }
}
