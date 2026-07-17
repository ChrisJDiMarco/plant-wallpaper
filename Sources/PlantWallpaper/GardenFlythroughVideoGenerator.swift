import AppKit
@preconcurrency import AVFoundation
import Foundation

protocol GardenFlythroughVideoHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: GardenFlythroughVideoHTTPClient {}

private final class GardenFlythroughExportSessionBox: @unchecked Sendable {
    let exporter: AVAssetExportSession

    init(_ exporter: AVAssetExportSession) {
        self.exporter = exporter
    }
}

enum GardenFlythroughVideoError: Error, LocalizedError {
    case invalidAPIKey
    case requestFailed(String)
    case invalidResponse(String)
    case mediaProcessingFailed(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Add a fal.ai API key before generating a flythrough video."
        case .requestFailed(let message):
            return message
        case .invalidResponse(let message):
            return message
        case .mediaProcessingFailed(let message):
            return message
        case .timedOut:
            return "fal.ai did not finish the video before the app stopped waiting. Check your fal dashboard for the request."
        }
    }
}

struct GardenFlythroughVideoGenerator: Sendable {
    private static let imageEndpointID = "bytedance/seedance-2.0/image-to-video"
    private static let referenceEndpointID = "bytedance/seedance-2.0/reference-to-video"
    private static let restAPIBaseURL = URL(string: "https://rest.fal.ai")!
    private static let queueBaseURL = URL(string: "https://queue.fal.run")!
    private static let contentPolicyMessage = "fal.ai rejected a generated flythrough segment as sensitive content. The app retried with a safer garden-only prompt when possible. Try a shorter video or a simpler path."

    private let httpClient: GardenFlythroughVideoHTTPClient
    private let pollDelayNanoseconds: UInt64
    private let maxPollAttempts: Int
    private let segmentDurations: [Int]

    private var segmentCount: Int {
        segmentDurations.count
    }

    private var totalDurationSeconds: Int {
        segmentDurations.reduce(0, +)
    }

    init(
        httpClient: GardenFlythroughVideoHTTPClient = URLSession.shared,
        pollDelayNanoseconds: UInt64 = 5_000_000_000,
        maxPollAttempts: Int = 120,
        durationSeconds: Int = 60
    ) {
        self.httpClient = httpClient
        self.pollDelayNanoseconds = pollDelayNanoseconds
        self.maxPollAttempts = max(1, maxPollAttempts)
        self.segmentDurations = Self.segmentDurations(for: durationSeconds)
    }

    func generate(snapshotPNGData: Data, apiKey: String, pathInstruction: String? = nil) async throws -> URL {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw GardenFlythroughVideoError.invalidAPIKey
        }

        let workingDirectory = try Self.makeWorkingDirectory()
        defer {
            Self.removeWorkingDirectory(workingDirectory)
        }
        let outputURL = try Self.makeOutputURL()
        let originalMapURL = try await uploadSnapshot(
            snapshotPNGData,
            apiKey: trimmedKey,
            fileName: "wallpaper-garden-full-map.png"
        )
        var startFrameData = snapshotPNGData
        var localSegmentURLs: [URL] = []

        for (segmentIndex, segmentDurationSeconds) in segmentDurations.enumerated() {
            try Task.checkCancellation()
            let startFrameURL = segmentIndex == 0
                ? originalMapURL
                : try await uploadSnapshot(
                    startFrameData,
                    apiKey: trimmedKey,
                    fileName: "wallpaper-garden-segment-\(segmentIndex + 1)-start.png"
                )
            let remoteVideoURL = try await generateSegment(
                startFrameURL: startFrameURL,
                originalMapURL: originalMapURL,
                segmentIndex: segmentIndex,
                segmentDurationSeconds: segmentDurationSeconds,
                apiKey: trimmedKey,
                pathInstruction: pathInstruction
            )
            let localSegmentURL = try await downloadVideo(
                remoteVideoURL,
                to: workingDirectory.appendingPathComponent(String(format: "segment-%02d.mp4", segmentIndex + 1))
            )
            localSegmentURLs.append(localSegmentURL)

            if segmentIndex < segmentCount - 1 {
                startFrameData = try await Self.lastFramePNGData(from: localSegmentURL)
            }
        }

        try await Self.stitchVideos(localSegmentURLs, to: outputURL)
        return outputURL
    }

    static func imageRequestBodyForSelfTest(
        snapshotURL: URL,
        pathInstruction: String?,
        segmentCount: Int = 1,
        segmentDurationSeconds: Int = 10,
        totalDurationSeconds: Int? = nil,
        usesPolicyFallback: Bool = false
    ) -> [String: Any] {
        imageRequestBody(
            startFrameURL: snapshotURL,
            endFrameURL: snapshotURL,
            segmentIndex: 0,
            segmentCount: max(1, segmentCount),
            segmentDurationSeconds: segmentDurationSeconds,
            totalDurationSeconds: totalDurationSeconds ?? max(1, segmentCount) * segmentDurationSeconds,
            pathInstruction: pathInstruction,
            usesPolicyFallback: usesPolicyFallback
        )
    }

    static func referenceRequestBodyForSelfTest(
        startFrameURL: URL,
        originalMapURL: URL,
        pathInstruction: String?,
        segmentCount: Int = 6,
        segmentDurationSeconds: Int = 10,
        totalDurationSeconds: Int? = nil
    ) -> [String: Any] {
        referenceRequestBody(
            startFrameURL: startFrameURL,
            originalMapURL: originalMapURL,
            segmentIndex: 1,
            segmentCount: max(2, segmentCount),
            segmentDurationSeconds: segmentDurationSeconds,
            totalDurationSeconds: totalDurationSeconds ?? max(2, segmentCount) * segmentDurationSeconds,
            pathInstruction: pathInstruction,
            usesPolicyFallback: false
        )
    }

    static func errorMessageForSelfTest(from data: Data, statusCode: Int = 400) -> String {
        errorMessage(from: data, statusCode: statusCode)
    }

    private func generateSegment(
        startFrameURL: URL,
        originalMapURL: URL,
        segmentIndex: Int,
        segmentDurationSeconds: Int,
        apiKey: String,
        pathInstruction: String?
    ) async throws -> URL {
        let isFinalSegment = segmentIndex == segmentCount - 1
        let endpointID = isFinalSegment ? Self.imageEndpointID : Self.referenceEndpointID
        for usesPolicyFallback in [false, true] {
            let body = isFinalSegment
                ? Self.imageRequestBody(
                    startFrameURL: startFrameURL,
                    endFrameURL: originalMapURL,
                    segmentIndex: segmentIndex,
                    segmentCount: segmentCount,
                    segmentDurationSeconds: segmentDurationSeconds,
                    totalDurationSeconds: totalDurationSeconds,
                    pathInstruction: pathInstruction,
                    usesPolicyFallback: usesPolicyFallback
                )
                : Self.referenceRequestBody(
                    startFrameURL: startFrameURL,
                    originalMapURL: originalMapURL,
                    segmentIndex: segmentIndex,
                    segmentCount: segmentCount,
                    segmentDurationSeconds: segmentDurationSeconds,
                    totalDurationSeconds: totalDurationSeconds,
                    pathInstruction: pathInstruction,
                    usesPolicyFallback: usesPolicyFallback
                )

            do {
                return try await generateSegmentOnce(endpointID: endpointID, body: body, apiKey: apiKey)
            } catch GardenFlythroughVideoError.requestFailed(let message)
                where !usesPolicyFallback && Self.isContentPolicyMessage(message) {
                continue
            }
        }

        throw GardenFlythroughVideoError.requestFailed(Self.contentPolicyMessage)
    }

    private func generateSegmentOnce(endpointID: String, body: [String: Any], apiKey: String) async throws -> URL {
        let submission = try await submitGeneration(endpointID: endpointID, body: body, apiKey: apiKey)

        for _ in 0..<maxPollAttempts {
            try Task.checkCancellation()
            let status = try await fetchStatus(endpointID: endpointID, submission: submission, apiKey: apiKey)
            if let error = status.error, !error.isEmpty {
                throw GardenFlythroughVideoError.requestFailed(Self.cleanFalErrorMessage(error))
            }
            if status.status == "COMPLETED" {
                return try await fetchResult(
                    endpointID: endpointID,
                    requestID: submission.requestID,
                    responseURL: status.responseURL ?? submission.responseURL,
                    apiKey: apiKey
                )
            }
            if pollDelayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: pollDelayNanoseconds)
            }
        }

        throw GardenFlythroughVideoError.timedOut
    }

    private func uploadSnapshot(_ data: Data, apiKey: String, fileName: String) async throws -> URL {
        struct UploadResponse: Decodable {
            let uploadURL: URL
            let fileURL: URL

            enum CodingKeys: String, CodingKey {
                case uploadURL = "upload_url"
                case fileURL = "file_url"
            }
        }

        let initiateURL = Self.restAPIBaseURL
            .appendingPathComponent("storage/upload/initiate")
            .appending(queryItems: [URLQueryItem(name: "storage_type", value: "fal-cdn-v3")])
        var request = try jsonRequest(
            url: initiateURL,
            apiKey: apiKey,
            body: [
                "content_type": "image/png",
                "file_name": fileName
            ]
        )
        request.timeoutInterval = 60

        let responseData = try await loadData(for: request)
        let upload = try JSONDecoder().decode(UploadResponse.self, from: responseData)

        var uploadRequest = URLRequest(url: upload.uploadURL)
        uploadRequest.httpMethod = "PUT"
        uploadRequest.setValue("image/png", forHTTPHeaderField: "Content-Type")
        uploadRequest.timeoutInterval = 180
        uploadRequest.httpBody = data
        _ = try await loadData(for: uploadRequest)
        return upload.fileURL
    }

    private func submitGeneration(endpointID: String, body: [String: Any], apiKey: String) async throws -> QueueSubmission {
        var request = try jsonRequest(
            url: Self.queueBaseURL.appendingPathComponent(endpointID),
            apiKey: apiKey,
            body: body
        )
        request.setValue("normal", forHTTPHeaderField: "x-fal-queue-priority")
        request.timeoutInterval = 120

        let data = try await loadData(for: request)
        return try JSONDecoder().decode(QueueSubmission.self, from: data)
    }

    private func fetchStatus(endpointID: String, submission: QueueSubmission, apiKey: String) async throws -> QueueStatus {
        let url = submission.statusURL ?? Self.queueBaseURL
            .appendingPathComponent(endpointID)
            .appendingPathComponent("requests")
            .appendingPathComponent(submission.requestID)
            .appendingPathComponent("status")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60

        let data = try await loadData(for: request)
        return try JSONDecoder().decode(QueueStatus.self, from: data)
    }

    private func fetchResult(endpointID: String, requestID: String, responseURL: URL?, apiKey: String) async throws -> URL {
        let url = responseURL ?? Self.queueBaseURL
            .appendingPathComponent(endpointID)
            .appendingPathComponent("requests")
            .appendingPathComponent(requestID)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60

        let data = try await loadData(for: request)
        let result = try JSONDecoder().decode(SeedanceResultEnvelope.self, from: data)
        guard let videoURL = result.video?.url ?? result.data?.video.url else {
            throw GardenFlythroughVideoError.invalidResponse("fal.ai finished the request without returning a video URL.")
        }
        return videoURL
    }

    private func downloadVideo(_ url: URL, to outputURL: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 300
        let data = try await loadData(for: request)
        try data.write(to: outputURL, options: [.atomic])
        return outputURL
    }

    private static func imageRequestBody(
        startFrameURL: URL,
        endFrameURL: URL,
        segmentIndex: Int,
        segmentCount: Int,
        segmentDurationSeconds: Int,
        totalDurationSeconds: Int,
        pathInstruction: String?,
        usesPolicyFallback: Bool = false
    ) -> [String: Any] {
        [
            "prompt": imagePrompt(
                segmentIndex: segmentIndex,
                segmentCount: segmentCount,
                segmentDurationSeconds: segmentDurationSeconds,
                totalDurationSeconds: totalDurationSeconds,
                pathInstruction: pathInstruction,
                usesPolicyFallback: usesPolicyFallback
            ),
            "image_url": startFrameURL.absoluteString,
            "end_image_url": endFrameURL.absoluteString,
            "resolution": "1080p",
            "duration": "\(segmentDurationSeconds)",
            "aspect_ratio": "auto",
            "generate_audio": false,
            "bitrate_mode": "standard"
        ]
    }

    private static func referenceRequestBody(
        startFrameURL: URL,
        originalMapURL: URL,
        segmentIndex: Int,
        segmentCount: Int,
        segmentDurationSeconds: Int,
        totalDurationSeconds: Int,
        pathInstruction: String?,
        usesPolicyFallback: Bool = false
    ) -> [String: Any] {
        [
            "prompt": referencePrompt(
                segmentIndex: segmentIndex,
                segmentCount: segmentCount,
                segmentDurationSeconds: segmentDurationSeconds,
                totalDurationSeconds: totalDurationSeconds,
                pathInstruction: pathInstruction,
                usesPolicyFallback: usesPolicyFallback
            ),
            "image_urls": [startFrameURL.absoluteString, originalMapURL.absoluteString],
            "resolution": "1080p",
            "duration": "\(segmentDurationSeconds)",
            "aspect_ratio": "auto",
            "generate_audio": false,
            "bitrate_mode": "standard"
        ]
    }

    private static func imagePrompt(
        segmentIndex: Int,
        segmentCount: Int,
        segmentDurationSeconds: Int,
        totalDurationSeconds: Int,
        pathInstruction: String?,
        usesPolicyFallback: Bool = false
    ) -> String {
        if usesPolicyFallback {
            return appendPathInstruction(
                to: policyFallbackPrompt(
                    segmentIndex: segmentIndex,
                    segmentCount: segmentCount,
                    totalDurationSeconds: totalDurationSeconds,
                    isFinalSegment: true
                ),
                pathInstruction: pathInstruction
            )
        }
        if segmentCount <= 1 {
            return appendPathInstruction(
                to: loopPrompt(durationSeconds: segmentDurationSeconds),
                pathInstruction: pathInstruction
            )
        }

        let prompt = """
        Create segment \(segmentIndex + 1) of \(segmentCount) for a photorealistic \(totalDurationSeconds)-second seamless WallpaperGarden flythrough.
        Use the provided image as the exact first frame for this \(segmentDurationSeconds)-second segment.
        This is the final segment: gently return toward the original opening garden viewpoint and end frame so the finished stitched \(totalDurationSeconds)-second video can loop back to the beginning without a jump.
        \(sharedContinuityPrompt)
        """
        return appendPathInstruction(to: prompt, pathInstruction: pathInstruction)
    }

    private static func referencePrompt(
        segmentIndex: Int,
        segmentCount: Int,
        segmentDurationSeconds: Int,
        totalDurationSeconds: Int,
        pathInstruction: String?,
        usesPolicyFallback: Bool = false
    ) -> String {
        if usesPolicyFallback {
            return appendPathInstruction(
                to: policyFallbackPrompt(
                    segmentIndex: segmentIndex,
                    segmentCount: segmentCount,
                    totalDurationSeconds: totalDurationSeconds,
                    isFinalSegment: false
                ),
                pathInstruction: pathInstruction
            )
        }
        let prompt = """
        Create segment \(segmentIndex + 1) of \(segmentCount) for a photorealistic \(totalDurationSeconds)-second continuous WallpaperGarden flythrough.
        Use @Image1 as the exact first frame for this \(segmentDurationSeconds)-second segment. Use @Image2 as the persistent full-garden map and continuity reference for the entire scene.
        Continue slowly from @Image1, advancing only a small part of the route. Do not rush, do not jump ahead, and do not return to the opening frame yet.
        Make the final frame a stable natural continuation that can become the first frame of the next segment.
        \(sharedContinuityPrompt)
        """
        return appendPathInstruction(to: prompt, pathInstruction: pathInstruction)
    }

    private static func policyFallbackPrompt(
        segmentIndex: Int,
        segmentCount: Int,
        totalDurationSeconds: Int,
        isFinalSegment: Bool
    ) -> String {
        let ending = isFinalSegment
            ? "End by easing back toward the opening viewpoint so the stitched \(totalDurationSeconds)-second video can loop cleanly."
            : "End on a stable garden frame that can continue into the next segment."
        return """
        Create segment \(segmentIndex + 1) of \(segmentCount) for a calm photorealistic \(totalDurationSeconds)-second WallpaperGarden walkthrough.
        Use only harmless garden imagery from the reference frames: plants, soil, pots, stones, furniture, and existing background surfaces.
        Keep the camera inside the visible garden area with slow stable motion and natural depth of field.
        Preserve the exact layout, lighting, plant placement, object placement, scale, and scene identity. Do not add new subjects, signs, labels, logos, UI, or dramatic events.
        \(ending)
        """
    }

    private static func appendPathInstruction(to prompt: String, pathInstruction: String?) -> String {
        let trimmedPath = pathInstruction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedPath.isEmpty else {
            return prompt
        }
        return "\(prompt)\n\n\(trimmedPath)"
    }

    private static func loopPrompt(durationSeconds: Int) -> String {
        """
        Create a photorealistic \(durationSeconds)-second seamless looping flythrough of this exact WallpaperGarden scene.
        The camera feels like stabilized tiny-drone footage flying through the garden at plant scale, but no drone, propellers, operator, UI, text, labels, logos, or watermark is visible.
        Preserve the scene identity, lighting, plant and object placement, scale, silhouettes, and overall composition from the reference image.
        Stay inside the garden area for the entire shot. Do not fly into the distant background, walls, sky, windows, wallpaper horizon, or any non-garden scenery; treat those areas only as background behind the garden.
        Use the full reference image as a persistent map of the garden layout. Do not invent new unseen spaces, new paths, new plants, or new objects outside the visible garden; continue respecting the same spatial arrangement throughout the shot.
        Move in one continuous closed camera path with slow, gentle forward motion, subtle parallax, natural depth of field, and realistic physical scale, gliding between and around visible plants or room objects without collisions.
        The last frame must match the first frame as closely as possible: same camera position, orientation, framing, exposure, and scene state, so playback can loop like a perfect GIF with no jump, cut, speed ramp, flash, or lighting shift.
        """
    }

    private static let sharedContinuityPrompt = """
    The camera feels like stabilized tiny-drone footage flying through the garden at plant scale, but no drone, propellers, operator, UI, text, labels, logos, or watermark is visible.
    Stay inside the garden area for the entire shot. Do not fly into the distant background, walls, sky, windows, wallpaper horizon, or any non-garden scenery; treat those areas only as background behind the garden.
    Preserve the same garden identity, lighting, plant and object placement, scale, silhouettes, and spatial arrangement. Do not invent new unseen spaces, new paths, new plants, or new objects outside the visible garden.
    Move slowly with gentle forward motion, subtle parallax, natural depth of field, and realistic physical scale, gliding between and around visible plants or room objects without collisions.
    """

    static func segmentDurations(for durationSeconds: Int) -> [Int] {
        var remaining = max(5, durationSeconds)
        var durations: [Int] = []
        while remaining > 0 {
            let duration: Int
            if remaining > 15, remaining - 15 == 5 {
                duration = 10
            } else if remaining > 15, remaining - 15 < 5 {
                duration = remaining - 5
            } else {
                duration = min(15, remaining)
            }
            durations.append(duration)
            remaining -= duration
        }
        return durations
    }

    private static func makeWorkingDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("wallpaper-garden-flythrough-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func removeWorkingDirectory(_ directory: URL) {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            Task.detached(priority: .utility) {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                try? FileManager.default.removeItem(at: directory)
            }
        }
    }

    private static func makeOutputURL(date: Date = Date()) throws -> URL {
        let baseDirectory = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = baseDirectory.appendingPathComponent("Plant Wallpaper Flythroughs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Plant Wallpaper Flythrough \(Int(date.timeIntervalSince1970)).mp4")
    }

    private static func lastFramePNGData(from videoURL: URL) async throws -> Data {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let seconds = duration.seconds
        let captureTime = CMTime(
            seconds: seconds.isFinite ? max(seconds - 0.1, 0) : 0,
            preferredTimescale: 600
        )
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let image = try generator.copyCGImage(at: captureTime, actualTime: nil)
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw GardenFlythroughVideoError.mediaProcessingFailed("Could not extract the next flythrough frame.")
        }
        return data
    }

    private static func stitchVideos(_ urls: [URL], to outputURL: URL) async throws {
        guard !urls.isEmpty else {
            throw GardenFlythroughVideoError.mediaProcessingFailed("No flythrough video segments were generated.")
        }

        if urls.count == 1 {
            try? FileManager.default.removeItem(at: outputURL)
            try FileManager.default.copyItem(at: urls[0], to: outputURL)
            return
        }

        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid)
        ) else {
            throw GardenFlythroughVideoError.mediaProcessingFailed("Could not prepare the stitched flythrough video.")
        }

        var cursor = CMTime.zero
        for url in urls {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw GardenFlythroughVideoError.mediaProcessingFailed("A flythrough segment did not contain video.")
            }
            if cursor == .zero {
                compositionTrack.preferredTransform = try await videoTrack.load(.preferredTransform)
            }
            try compositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: videoTrack,
                at: cursor
            )
            cursor = cursor + duration
        }

        try? FileManager.default.removeItem(at: outputURL)
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw GardenFlythroughVideoError.mediaProcessingFailed("Could not create the stitched flythrough exporter.")
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true

        let exporterBox = GardenFlythroughExportSessionBox(exporter)
        try await withCheckedThrowingContinuation { continuation in
            exporter.exportAsynchronously {
                let exporter = exporterBox.exporter
                switch exporter.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: exporter.error ?? GardenFlythroughVideoError.mediaProcessingFailed("Could not stitch the flythrough video."))
                default:
                    continuation.resume(throwing: GardenFlythroughVideoError.mediaProcessingFailed("Could not stitch the flythrough video."))
                }
            }
        }
    }

    private func jsonRequest(url: URL, apiKey: String, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return request
    }

    private func loadData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await httpClient.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(statusCode) else {
            throw GardenFlythroughVideoError.requestFailed(Self.errorMessage(from: data, statusCode: statusCode))
        }
        return data
    }

    private static func errorMessage(from data: Data, statusCode: Int) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if isContentPolicyObject(object) {
                return contentPolicyMessage
            }
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
            if let detail = object["detail"] as? String, !detail.isEmpty {
                return detail
            }
            if let details = object["detail"] as? [[String: Any]] {
                let messages = details.compactMap { $0["msg"] as? String }.filter { !$0.isEmpty }
                if !messages.isEmpty {
                    return messages.joined(separator: "\n")
                }
            }
            if let error = object["error"] as? [String: Any],
               let message = error["message"] as? String,
               !message.isEmpty {
                return message
            }
        }

        let fallback = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let fallback, isContentPolicyMessage(fallback) {
            return contentPolicyMessage
        }
        return fallback?.isEmpty == false
            ? fallback!
            : "fal.ai request failed with HTTP \(statusCode)."
    }

    private static func cleanFalErrorMessage(_ message: String) -> String {
        guard let data = message.data(using: .utf8) else {
            return isContentPolicyMessage(message) ? contentPolicyMessage : message
        }
        return errorMessage(from: data, statusCode: 400)
    }

    private static func isContentPolicyObject(_ object: [String: Any]) -> Bool {
        isContentPolicyMessage(String(describing: object))
    }

    private static func isContentPolicyMessage(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("content_policy_violation")
            || lowercased.contains("sensitive content")
            || lowercased.contains("partner_validation_failed")
    }
}

private struct QueueSubmission: Decodable {
    let requestID: String
    let responseURL: URL?
    let statusURL: URL?

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case responseURL = "response_url"
        case statusURL = "status_url"
    }
}

private struct QueueStatus: Decodable {
    let status: String
    let responseURL: URL?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case status
        case responseURL = "response_url"
        case error
    }
}

private struct SeedanceResultEnvelope: Decodable {
    let video: FalFile?
    let data: SeedanceResultData?
}

private struct SeedanceResultData: Decodable {
    let video: FalFile
}

private struct FalFile: Decodable {
    let url: URL
}
