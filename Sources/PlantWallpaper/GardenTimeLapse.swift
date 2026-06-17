import AppKit
import AVFoundation
import PlantGardenCore

/// The garden's photo diary: one frame per day, captured automatically, so
/// the operator can export a time-lapse of their garden growing.
@MainActor
final class GardenTimeLapseRecorder {
    static let maximumStoredFrames = 730
    /// Diary frames are capped to this width - a daily 4K PNG would burn
    /// gigabytes a year; a 1920-wide JPEG keeps a year under ~200 MB.
    static let frameWidth: CGFloat = 1920

    private let directoryURL: URL
    private let fileManager: FileManager

    init(baseDirectoryURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directoryURL = baseDirectoryURL.appendingPathComponent("Timelapse", isDirectory: true)
    }

    var frameDirectoryURL: URL {
        directoryURL
    }

    struct InventorySummary: Equatable {
        let frameCount: Int
        let byteCount: Int64

        var storageSummary: String {
            let byteFormatter = ByteCountFormatter()
            byteFormatter.allowedUnits = [.useKB, .useMB, .useGB]
            byteFormatter.countStyle = .file
            let storage = byteFormatter.string(fromByteCount: byteCount)
            return "\(frameCount) frame\(frameCount == 1 ? "" : "s") - \(storage)"
        }
    }

    func frameURLs() -> [URL] {
        ((try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "jpg" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func inventorySummary() -> InventorySummary {
        let byteCount = frameURLs().reduce(Int64(0)) { total, frameURL in
            let values = try? frameURL.resourceValues(forKeys: [.fileSizeKey])
            return total + Int64(values?.fileSize ?? 0)
        }
        return InventorySummary(frameCount: frameURLs().count, byteCount: byteCount)
    }

    /// Captures a frame if the user's selected cadence says one is due.
    func captureFrameIfNeeded(store: GardenStore, at date: Date = Date()) {
        switch store.state.settings.timeLapseCadence {
        case .off:
            return
        case .daily:
            captureDailyFrameIfNeeded(store: store, at: date)
        case .weekly:
            captureWeeklyFrameIfNeeded(store: store, at: date)
        }
    }

    /// Captures today's frame if it doesn't exist yet. Cheap to call often.
    func captureDailyFrameIfNeeded(store: GardenStore, at date: Date = Date()) {
        let frameURL = directoryURL.appendingPathComponent("garden-\(Self.dayStamp(for: date)).jpg")
        captureFrame(store: store, frameURL: frameURL)
    }

    func captureWeeklyFrameIfNeeded(store: GardenStore, at date: Date = Date()) {
        let frameURL = directoryURL.appendingPathComponent("garden-\(Self.weekStamp(for: date)).jpg")
        captureFrame(store: store, frameURL: frameURL)
    }

    func deleteAllFrames() {
        for frameURL in frameURLs() {
            try? fileManager.removeItem(at: frameURL)
        }
    }

    private func captureFrame(store: GardenStore, frameURL: URL) {
        guard !fileManager.fileExists(atPath: frameURL.path) else {
            return
        }

        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let bitmap = try GardenDesktopSnapshotRenderer.makeSnapshotBitmap(
                store: store,
                screen: screen,
                screenIndex: NSScreen.screens.firstIndex(of: screen) ?? 0
            )
            let frameData = try Self.scaledJPEGData(from: bitmap, targetWidth: Self.frameWidth)
            try frameData.write(to: frameURL, options: [.atomic])
            pruneOldFrames()
        } catch {
            NSLog("Plant Wallpaper could not capture today's time-lapse frame: \(error.localizedDescription)")
        }
    }

    private func pruneOldFrames() {
        let frames = frameURLs()
        guard frames.count > Self.maximumStoredFrames else {
            return
        }

        for staleFrame in frames.prefix(frames.count - Self.maximumStoredFrames) {
            try? fileManager.removeItem(at: staleFrame)
        }
    }

    static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func weekStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "YYYY-'W'ww"
        return formatter.string(from: date)
    }

    private static func scaledJPEGData(from bitmap: NSBitmapImageRep, targetWidth: CGFloat) throws -> Data {
        let sourceWidth = CGFloat(bitmap.pixelsWide)
        let sourceHeight = CGFloat(bitmap.pixelsHigh)
        guard sourceWidth > 0, sourceHeight > 0 else {
            throw GardenDesktopSnapshotRenderer.SnapshotError.couldNotRenderSnapshot
        }

        let scale = min(1, targetWidth / sourceWidth)
        let pixelWidth = max(1, Int((sourceWidth * scale).rounded()))
        let pixelHeight = max(1, Int((sourceHeight * scale).rounded()))

        guard let scaledBitmap = NSBitmapImageRep(
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
        let context = NSGraphicsContext(bitmapImageRep: scaledBitmap) else {
            throw GardenDesktopSnapshotRenderer.SnapshotError.couldNotRenderSnapshot
        }

        scaledBitmap.size = NSSize(width: pixelWidth, height: pixelHeight)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let sourceImage = NSImage(size: NSSize(width: sourceWidth, height: sourceHeight))
        sourceImage.addRepresentation(bitmap)
        sourceImage.draw(
            in: NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight),
            from: NSRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight),
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let jpegData = scaledBitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
            throw GardenDesktopSnapshotRenderer.SnapshotError.couldNotRenderSnapshot
        }

        return jpegData
    }
}

/// Assembles the daily diary frames into an H.264 time-lapse movie.
@MainActor
final class GardenTimeLapseExporter {
    static let shared = GardenTimeLapseExporter()

    var recorder: GardenTimeLapseRecorder?
    private var isExporting = false

    func exportInteractively(store: GardenStore) {
        guard let recorder, !isExporting else {
            return
        }

        // Make sure today is in the film before exporting.
        recorder.captureFrameIfNeeded(store: store)
        let frameURLs = recorder.frameURLs()

        guard frameURLs.count >= 2 else {
            let alert = NSAlert()
            alert.messageText = "Your time-lapse is just getting started"
            alert.informativeText = "The garden saves one frame per day. Today's frame is captured - come back after a few more days and the export will turn them into a movie."
            alert.alertStyle = .informational
            NSApplication.shared.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Garden Time-Lapse"
        panel.nameFieldStringValue = "My Garden Time-Lapse.mov"
        panel.allowedContentTypes = [.quickTimeMovie]
        NSApplication.shared.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK, let outputURL = panel.url else {
            return
        }

        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                try await Self.writeMovie(frameURLs: frameURLs, to: outputURL)
                NSWorkspace.shared.activateFileViewerSelecting([outputURL])
            } catch {
                let alert = NSAlert()
                alert.messageText = "Could not export time-lapse"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    private static func writeMovie(frameURLs: [URL], to outputURL: URL) async throws {
        guard let firstImage = NSImage(contentsOf: frameURLs[0]),
              let firstFrame = firstImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw GardenDesktopSnapshotRenderer.SnapshotError.couldNotRenderSnapshot
        }

        // Even dimensions are required by H.264.
        let width = firstFrame.width - (firstFrame.width % 2)
        let height = firstFrame.height - (firstFrame.height % 2)

        try? FileManager.default.removeItem(at: outputURL)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? GardenDesktopSnapshotRenderer.SnapshotError.couldNotRenderSnapshot
        }
        writer.startSession(atSourceTime: .zero)

        // Short diaries play slowly, long ones speed up - clips stay 5-30 s.
        let framesPerSecond = min(12, max(2, frameURLs.count / 10))
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(framesPerSecond))

        for (index, frameURL) in frameURLs.enumerated() {
            guard let image = NSImage(contentsOf: frameURL),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let pixelBuffer = makePixelBuffer(from: cgImage, width: width, height: height, pool: adaptor.pixelBufferPool) else {
                continue
            }

            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 8_000_000)
            }
            adaptor.append(pixelBuffer, withPresentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(index)))
        }

        input.markAsFinished()
        await writer.finishWriting()
        if writer.status == .failed {
            throw writer.error ?? GardenDesktopSnapshotRenderer.SnapshotError.couldNotRenderSnapshot
        }
    }

    private static func makePixelBuffer(
        from cgImage: CGImage,
        width: Int,
        height: Int,
        pool: CVPixelBufferPool?
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        if let pool {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        }
        if pixelBuffer == nil {
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32ARGB,
                nil,
                &pixelBuffer
            )
        }
        guard let pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }
}
