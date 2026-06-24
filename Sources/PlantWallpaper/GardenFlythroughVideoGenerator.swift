import Foundation

protocol GardenFlythroughVideoHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: GardenFlythroughVideoHTTPClient {}

enum GardenFlythroughVideoError: Error, LocalizedError {
    case invalidAPIKey
    case requestFailed(String)
    case invalidResponse(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Add a fal.ai API key before generating a flythrough video."
        case .requestFailed(let message):
            return message
        case .invalidResponse(let message):
            return message
        case .timedOut:
            return "fal.ai did not finish the video before the app stopped waiting. Check your fal dashboard for the request."
        }
    }
}

struct GardenFlythroughVideoGenerator: Sendable {
    private static let endpointID = "bytedance/seedance-2.0/fast/image-to-video"
    private static let restAPIBaseURL = URL(string: "https://rest.fal.ai")!
    private static let queueBaseURL = URL(string: "https://queue.fal.run")!

    private let httpClient: GardenFlythroughVideoHTTPClient
    private let pollDelayNanoseconds: UInt64
    private let maxPollAttempts: Int

    init(
        httpClient: GardenFlythroughVideoHTTPClient = URLSession.shared,
        pollDelayNanoseconds: UInt64 = 5_000_000_000,
        maxPollAttempts: Int = 120
    ) {
        self.httpClient = httpClient
        self.pollDelayNanoseconds = pollDelayNanoseconds
        self.maxPollAttempts = max(1, maxPollAttempts)
    }

    func generate(snapshotPNGData: Data, apiKey: String) async throws -> URL {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw GardenFlythroughVideoError.invalidAPIKey
        }

        let snapshotURL = try await uploadSnapshot(snapshotPNGData, apiKey: trimmedKey)
        let submission = try await submitGeneration(snapshotURL: snapshotURL, apiKey: trimmedKey)

        for _ in 0..<maxPollAttempts {
            try Task.checkCancellation()
            let status = try await fetchStatus(submission: submission, apiKey: trimmedKey)
            if let error = status.error, !error.isEmpty {
                throw GardenFlythroughVideoError.requestFailed(error)
            }
            if status.status == "COMPLETED" {
                return try await fetchResult(
                    requestID: submission.requestID,
                    responseURL: status.responseURL ?? submission.responseURL,
                    apiKey: trimmedKey
                )
            }
            if pollDelayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: pollDelayNanoseconds)
            }
        }

        throw GardenFlythroughVideoError.timedOut
    }

    private func uploadSnapshot(_ data: Data, apiKey: String) async throws -> URL {
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
                "file_name": "wallpaper-garden-snapshot.png"
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

    private func submitGeneration(snapshotURL: URL, apiKey: String) async throws -> QueueSubmission {
        var request = try jsonRequest(
            url: Self.queueBaseURL.appendingPathComponent(Self.endpointID),
            apiKey: apiKey,
            body: Self.requestBody(snapshotURL: snapshotURL)
        )
        request.setValue("normal", forHTTPHeaderField: "x-fal-queue-priority")
        request.timeoutInterval = 120

        let data = try await loadData(for: request)
        return try JSONDecoder().decode(QueueSubmission.self, from: data)
    }

    private func fetchStatus(submission: QueueSubmission, apiKey: String) async throws -> QueueStatus {
        let url = submission.statusURL ?? Self.queueBaseURL
            .appendingPathComponent(Self.endpointID)
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

    private func fetchResult(requestID: String, responseURL: URL?, apiKey: String) async throws -> URL {
        let url = responseURL ?? Self.queueBaseURL
            .appendingPathComponent(Self.endpointID)
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

    private static func requestBody(snapshotURL: URL) -> [String: Any] {
        [
            "prompt": loopPrompt,
            "image_url": snapshotURL.absoluteString,
            "end_image_url": snapshotURL.absoluteString,
            "resolution": "720p",
            "duration": "10",
            "aspect_ratio": "auto",
            "generate_audio": false,
            "bitrate_mode": "standard"
        ]
    }

    private static let loopPrompt = """
    Create a photorealistic 10-second seamless looping flythrough of this exact WallpaperGarden scene.
    The camera feels like stabilized tiny-drone footage flying through the garden at plant scale, but no drone, propellers, operator, UI, text, labels, logos, or watermark is visible.
    Preserve the scene identity, lighting, plant and object placement, scale, silhouettes, and overall composition from the reference image.
    Move in one continuous closed camera path with gentle forward motion, subtle parallax, natural depth of field, and realistic physical scale, gliding between and around visible plants or room objects without collisions.
    The last frame must match the first frame as closely as possible: same camera position, orientation, framing, exposure, and scene state, so playback can loop like a perfect GIF with no jump, cut, speed ramp, flash, or lighting shift.
    """

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
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
            if let detail = object["detail"] as? String, !detail.isEmpty {
                return detail
            }
            if let error = object["error"] as? [String: Any],
               let message = error["message"] as? String,
               !message.isEmpty {
                return message
            }
        }

        let fallback = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback?.isEmpty == false
            ? fallback!
            : "fal.ai request failed with HTTP \(statusCode)."
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
