import Foundation
import Testing
@testable import PlantWallpaper

@Suite("Garden flythrough video generator")
struct GardenFlythroughVideoGeneratorTests {
    @Test("uploads one snapshot and submits it as start and end frame")
    func uploadsSnapshotAndSubmitsLoopableSeedanceRequest() async throws {
        let uploadURL = URL(string: "https://upload.example.com/snapshot")!
        let fileURL = URL(string: "https://v3.fal.media/files/test/snapshot.png")!
        let statusURL = URL(string: "https://queue.fal.run/bytedance/seedance-2.0/fast/image-to-video/requests/req_1/status")!
        let responseURL = URL(string: "https://queue.fal.run/bytedance/seedance-2.0/fast/image-to-video/requests/req_1/response")!
        let videoURL = URL(string: "https://v3.fal.media/files/test/flythrough.mp4")!
        let client = ScriptedFlythroughHTTPClient(steps: [
            .response(
                statusCode: 200,
                url: URL(string: "https://rest.fal.ai/storage/upload/initiate")!,
                data: Data(#"{"upload_url":"\#(uploadURL.absoluteString)","file_url":"\#(fileURL.absoluteString)"}"#.utf8)
            ),
            .response(statusCode: 200, url: uploadURL, data: Data()),
            .response(
                statusCode: 200,
                url: URL(string: "https://queue.fal.run/bytedance/seedance-2.0/fast/image-to-video")!,
                data: Data(#"{"request_id":"req_1","status_url":"\#(statusURL.absoluteString)","response_url":"\#(responseURL.absoluteString)","queue_position":0}"#.utf8)
            ),
            .response(
                statusCode: 200,
                url: statusURL,
                data: Data(#"{"status":"COMPLETED","request_id":"req_1","response_url":"\#(responseURL.absoluteString)"}"#.utf8)
            ),
            .response(
                statusCode: 200,
                url: responseURL,
                data: Data(#"{"video":{"url":"\#(videoURL.absoluteString)"},"seed":42}"#.utf8)
            )
        ])
        let generator = GardenFlythroughVideoGenerator(
            httpClient: client,
            pollDelayNanoseconds: 0,
            maxPollAttempts: 2
        )

        let resultURL = try await generator.generate(
            snapshotPNGData: Data([1, 2, 3]),
            apiKey: " fal-test "
        )

        #expect(resultURL == videoURL)
        let requests = await client.capturedRequests()
        #expect(requests.count == 5)
        #expect(requests[0].url?.absoluteString == "https://rest.fal.ai/storage/upload/initiate?storage_type=fal-cdn-v3")
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Key fal-test")
        #expect(requests[1].httpMethod == "PUT")
        #expect(requests[1].httpBody == Data([1, 2, 3]))

        let requestBody = try #require(requests[2].httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
        #expect(body["image_url"] as? String == fileURL.absoluteString)
        #expect(body["end_image_url"] as? String == fileURL.absoluteString)
        #expect(body["duration"] as? String == "10")
        #expect(body["resolution"] as? String == "720p")
        #expect(body["generate_audio"] as? Bool == false)

        let prompt = try #require(body["prompt"] as? String)
        #expect(prompt.localizedCaseInsensitiveContains("seamless"))
        #expect(prompt.localizedCaseInsensitiveContains("loop"))
        #expect(prompt.localizedCaseInsensitiveContains("no drone"))
    }
}

private actor ScriptedFlythroughHTTPClient: GardenFlythroughVideoHTTPClient {
    enum Step {
        case response(statusCode: Int, url: URL, data: Data)
    }

    private var steps: [Step]
    private var requests: [URLRequest] = []

    init(steps: [Step]) {
        self.steps = steps
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !steps.isEmpty else {
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }

        let step = steps.removeFirst()
        switch step {
        case .response(let statusCode, let url, let data):
            let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        }
    }

    func capturedRequests() -> [URLRequest] {
        requests
    }
}
