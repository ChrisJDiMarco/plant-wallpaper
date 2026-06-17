import AppKit
import PlantGardenCore

/// Renders a snapshot of the live garden desktop: the active wallpaper scene
/// with plants and placed companion objects composited on top, exactly as
/// they appear on screen - no desktop icons, files, or Dock.
@MainActor
enum GardenDesktopSnapshotRenderer {
    enum SnapshotError: Error, LocalizedError {
        case noScreenAvailable
        case couldNotLoadWallpaper
        case couldNotRenderSnapshot

        var errorDescription: String? {
            switch self {
            case .noScreenAvailable:
                "No screen is available to snapshot."
            case .couldNotLoadWallpaper:
                "Could not load the current wallpaper image."
            case .couldNotRenderSnapshot:
                "Could not render the garden snapshot."
            }
        }
    }

    /// Writes one snapshot per attached display. The first (primary) screen
    /// gets the chosen filename; additional displays get a " - Display N"
    /// suffix. Returns the written file URLs.
    @discardableResult
    static func writeSnapshotPNGs(store: GardenStore, to baseURL: URL) throws -> [URL] {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            throw SnapshotError.noScreenAvailable
        }

        return try screens.enumerated().map { screenIndex, screen in
            let outputURL = screenIndex == 0 ? baseURL : displayNumberedURL(baseURL, displayNumber: screenIndex + 1)
            try writeSnapshotPNG(store: store, screen: screen, screenIndex: screenIndex, to: outputURL)
            return outputURL
        }
    }

    static func writeSnapshotPNG(store: GardenStore, to url: URL) throws {
        let screens = NSScreen.screens
        guard let screen = NSScreen.main ?? screens.first else {
            throw SnapshotError.noScreenAvailable
        }

        try writeSnapshotPNG(
            store: store,
            screen: screen,
            screenIndex: screens.firstIndex(of: screen) ?? 0,
            to: url
        )
    }

    private static func displayNumberedURL(_ baseURL: URL, displayNumber: Int) -> URL {
        let fileExtension = baseURL.pathExtension
        let baseName = baseURL.deletingPathExtension().lastPathComponent
        return baseURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(baseName) - Display \(displayNumber)")
            .appendingPathExtension(fileExtension.isEmpty ? "png" : fileExtension)
    }

    private static func writeSnapshotPNG(
        store: GardenStore,
        screen: NSScreen,
        screenIndex: Int,
        to url: URL
    ) throws {
        let pngData = try snapshotPNGData(store: store, screen: screen, screenIndex: screenIndex)
        try pngData.write(to: url, options: [.atomic])
    }

    /// The exact PNG payload produced by "Save Garden Snapshot", shared with
    /// AI Lock View so the image sent to OpenAI is the same clean composition:
    /// wallpaper plus app-placed plants, without desktop UI.
    static func snapshotPNGData(
        store: GardenStore,
        screen: NSScreen,
        screenIndex: Int
    ) throws -> Data {
        let bitmap = try makeSnapshotBitmap(store: store, screen: screen, screenIndex: screenIndex)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw SnapshotError.couldNotRenderSnapshot
        }
        return pngData
    }

    /// The composited desktop garden (wallpaper + plants) for one screen, as
    /// a bitmap. Shared by the snapshot menu action and the time-lapse diary.
    static func makeSnapshotBitmap(
        store: GardenStore,
        screen: NSScreen,
        screenIndex: Int
    ) throws -> NSBitmapImageRep {
        let pointSize = screen.frame.size
        let scale = max(1, screen.backingScaleFactor)
        let pixelWidth = max(1, Int((pointSize.width * scale).rounded()))
        let pixelHeight = max(1, Int((pointSize.height * scale).rounded()))

        guard let wallpaperImage = currentWallpaperImage(for: screen, store: store) else {
            throw SnapshotError.couldNotLoadWallpaper
        }

        let plantsImage = try renderPlantsImage(
            store: store,
            screenIndex: screenIndex,
            pointSize: pointSize,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        )

        guard let bitmap = NSBitmapImageRep(
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
        ),
        let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw SnapshotError.couldNotRenderSnapshot
        }

        bitmap.size = NSSize(width: pixelWidth, height: pixelHeight)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.imageInterpolation = .high
        let rect = NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        drawAspectFill(wallpaperImage, into: rect)
        plantsImage.draw(
            in: rect,
            from: NSRect(origin: .zero, size: plantsImage.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    /// Draws the garden overlay offscreen at the screen's point size into a
    /// bitmap with the screen's pixel density, so plant geometry matches the
    /// live canvas exactly while staying crisp on Retina displays.
    private static func renderPlantsImage(
        store: GardenStore,
        screenIndex: Int,
        pointSize: NSSize,
        pixelWidth: Int,
        pixelHeight: Int
    ) throws -> NSImage {
        let canvasView = GardenCanvasView(
            frame: NSRect(origin: .zero, size: pointSize),
            screenIndex: screenIndex,
            store: store
        )
        canvasView.drawsInteractiveChrome = false
        canvasView.drawsSceneObjectsWhenChromeHidden = true

        guard let canvasBitmap = NSBitmapImageRep(
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
            throw SnapshotError.couldNotRenderSnapshot
        }

        canvasBitmap.size = pointSize
        canvasView.cacheDisplay(in: canvasView.bounds, to: canvasBitmap)

        let image = NSImage(size: pointSize)
        image.addRepresentation(canvasBitmap)
        return image
    }

    private static func currentWallpaperImage(for screen: NSScreen, store: GardenStore) -> NSImage? {
        if let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen),
           let wallpaperImage = NSImage(contentsOf: wallpaperURL),
           wallpaperImage.size.width > 0,
           wallpaperImage.size.height > 0 {
            return wallpaperImage
        }

        let scene = store.activeSceneKey
            .flatMap(GardenWallpaperScene.scene(forKey:))
            ?? GardenWallpaperScene.defaultScene
        let cyclePhase = GardenSceneDayCyclePhase(date: Date())
        let assetName = scene.dayCycleAssetName(for: cyclePhase)
            .flatMap { bundledSceneImageURL(named: $0) != nil ? $0 : nil }
            ?? scene.rawValue

        guard let fallbackURL = bundledSceneImageURL(named: assetName),
              let fallbackImage = NSImage(contentsOf: fallbackURL),
              fallbackImage.size.width > 0,
              fallbackImage.size.height > 0 else {
            return nil
        }

        fallbackImage.cacheMode = .always
        return fallbackImage
    }

    private static func bundledSceneImageURL(named name: String) -> URL? {
        for resourceRoot in sceneResourceRootCandidates() {
            let directURL = resourceRoot.appendingPathComponent("\(name).png")
            if FileManager.default.fileExists(atPath: directURL.path) {
                return directURL
            }

            let nestedURL = resourceRoot
                .appendingPathComponent("SceneAssets", isDirectory: true)
                .appendingPathComponent("\(name).png")
            if FileManager.default.fileExists(atPath: nestedURL.path) {
                return nestedURL
            }
        }

        return nil
    }

    private static func sceneResourceRootCandidates() -> [URL] {
        var candidates: [URL] = []

        func appendIfUnique(_ url: URL?) {
            guard let url else {
                return
            }

            let standardizedURL = url.standardizedFileURL
            guard !candidates.contains(standardizedURL) else {
                return
            }
            candidates.append(standardizedURL)
        }

        appendIfUnique(Bundle.appResources.resourceURL)
        appendIfUnique(Bundle.main.bundleURL.appendingPathComponent("WallpaperGarden_PlantWallpaper.bundle", isDirectory: true))
        appendIfUnique(Bundle.main.resourceURL?.appendingPathComponent("WallpaperGarden_PlantWallpaper.bundle", isDirectory: true))
        appendIfUnique(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/WallpaperGarden_PlantWallpaper.bundle", isDirectory: true))
        appendIfUnique(URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true))

        return candidates
    }

    private static func drawAspectFill(_ image: NSImage, into rect: NSRect) {
        let sourceSize = image.size
        let sourceAspect = sourceSize.width / max(1, sourceSize.height)
        let targetAspect = rect.width / max(1, rect.height)
        let sourceRect: NSRect

        if targetAspect > sourceAspect {
            let cropHeight = sourceSize.width / targetAspect
            sourceRect = NSRect(
                x: 0,
                y: (sourceSize.height - cropHeight) / 2,
                width: sourceSize.width,
                height: cropHeight
            )
        } else {
            let cropWidth = sourceSize.height * targetAspect
            sourceRect = NSRect(
                x: (sourceSize.width - cropWidth) / 2,
                y: 0,
                width: cropWidth,
                height: sourceSize.height
            )
        }

        image.draw(
            in: rect,
            from: sourceRect,
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }
}
