import Foundation
import Testing
@testable import PlantWallpaper

@Suite("Garden flythrough video generator")
struct GardenFlythroughVideoGeneratorTests {
    @Test("single segment request stays 1080p and loopable")
    func singleSegmentRequestStays1080pAndLoopable() throws {
        let imageURL = URL(string: "https://v3.fal.media/files/test/snapshot.png")!
        let body = GardenFlythroughVideoGenerator.imageRequestBodyForSelfTest(
            snapshotURL: imageURL,
            pathInstruction: "Follow normalized path (0.10, 0.90) -> (0.50, 0.50)."
        )

        #expect(body["image_url"] as? String == imageURL.absoluteString)
        #expect(body["end_image_url"] as? String == imageURL.absoluteString)
        #expect(body["duration"] as? String == "10")
        #expect(body["resolution"] as? String == "1080p")
        #expect(body["generate_audio"] as? Bool == false)

        let prompt = try #require(body["prompt"] as? String)
        #expect(prompt.localizedCaseInsensitiveContains("seamless"))
        #expect(prompt.localizedCaseInsensitiveContains("loop"))
        #expect(prompt.localizedCaseInsensitiveContains("no drone"))
        #expect(prompt.localizedCaseInsensitiveContains("stay inside the garden area"))
        #expect(prompt.localizedCaseInsensitiveContains("full reference image as a persistent map"))
        #expect(prompt.localizedCaseInsensitiveContains("slow, gentle forward motion"))
        #expect(prompt.contains("Follow normalized path"))
    }

    @Test("five second request sends selected fal duration")
    func fiveSecondRequestSendsSelectedFalDuration() throws {
        let imageURL = URL(string: "https://v3.fal.media/files/test/snapshot.png")!
        let body = GardenFlythroughVideoGenerator.imageRequestBodyForSelfTest(
            snapshotURL: imageURL,
            pathInstruction: nil,
            segmentDurationSeconds: 5,
            totalDurationSeconds: 5
        )

        #expect(body["duration"] as? String == "5")
        let prompt = try #require(body["prompt"] as? String)
        #expect(prompt.contains("5-second seamless"))
    }

    @Test("continuation request carries current frame and original garden map")
    func continuationRequestCarriesCurrentFrameAndOriginalGardenMap() throws {
        let startURL = URL(string: "https://v3.fal.media/files/test/segment-start.png")!
        let originalURL = URL(string: "https://v3.fal.media/files/test/original-map.png")!
        let body = GardenFlythroughVideoGenerator.referenceRequestBodyForSelfTest(
            startFrameURL: startURL,
            originalMapURL: originalURL,
            pathInstruction: nil
        )

        #expect(body["image_urls"] as? [String] == [startURL.absoluteString, originalURL.absoluteString])
        #expect(body["duration"] as? String == "10")
        #expect(body["resolution"] as? String == "1080p")
        #expect(body["generate_audio"] as? Bool == false)

        let prompt = try #require(body["prompt"] as? String)
        #expect(prompt.contains("@Image1"))
        #expect(prompt.contains("@Image2"))
        #expect(prompt.localizedCaseInsensitiveContains("persistent full-garden map"))
        #expect(prompt.localizedCaseInsensitiveContains("next segment"))
    }

    @Test("continuation prompt reflects selected total duration")
    func continuationPromptReflectsSelectedTotalDuration() throws {
        let startURL = URL(string: "https://v3.fal.media/files/test/segment-start.png")!
        let originalURL = URL(string: "https://v3.fal.media/files/test/original-map.png")!
        let body = GardenFlythroughVideoGenerator.referenceRequestBodyForSelfTest(
            startFrameURL: startURL,
            originalMapURL: originalURL,
            pathInstruction: nil,
            segmentCount: 2,
            segmentDurationSeconds: 15,
            totalDurationSeconds: 20
        )

        #expect(body["duration"] as? String == "15")
        let prompt = try #require(body["prompt"] as? String)
        #expect(prompt.contains("20-second continuous"))
        #expect(prompt.contains("15-second segment"))
        #expect(!prompt.contains("60-second continuous"))
    }

    @Test("selected duration is split into fal sized clips")
    func selectedDurationIsSplitIntoFalSizedClips() {
        #expect(GardenFlythroughVideoGenerator.segmentDurations(for: 5) == [5])
        #expect(GardenFlythroughVideoGenerator.segmentDurations(for: 20) == [10, 10])
        #expect(GardenFlythroughVideoGenerator.segmentDurations(for: 35) == [15, 10, 10])
        #expect(GardenFlythroughVideoGenerator.segmentDurations(for: 60) == [15, 15, 15, 15])
    }

    @Test("fal content policy errors are shown as a short useful message")
    func falContentPolicyErrorsAreShownAsShortUsefulMessage() throws {
        let data = Data("""
        {"detail":[{"loc":["body","generated_video"],"msg":"Output video has sensitive content.","type":"content_policy_violation","ctx":{"extra_info":{"reason":"partner_validation_failed"}}}],"input":{"prompt":"huge prompt that should not be shown"}}
        """.utf8)

        let message = GardenFlythroughVideoGenerator.errorMessageForSelfTest(from: data)

        #expect(message.contains("fal.ai rejected a generated flythrough segment"))
        #expect(!message.contains("huge prompt"))
    }

    @Test("policy fallback prompt uses safer garden-only wording")
    func policyFallbackPromptUsesSaferGardenOnlyWording() throws {
        let imageURL = URL(string: "https://v3.fal.media/files/test/snapshot.png")!
        let body = GardenFlythroughVideoGenerator.imageRequestBodyForSelfTest(
            snapshotURL: imageURL,
            pathInstruction: nil,
            segmentCount: 6,
            usesPolicyFallback: true
        )

        let prompt = try #require(body["prompt"] as? String)
        #expect(prompt.localizedCaseInsensitiveContains("harmless garden imagery"))
        #expect(!prompt.localizedCaseInsensitiveContains("drone"))
    }
}
