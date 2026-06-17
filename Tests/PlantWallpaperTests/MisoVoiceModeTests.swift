import Foundation
import XCTest
@testable import PlantWallpaper

final class MisoVoiceModeTests: XCTestCase {
    func testVoiceModeCopyIsExplicitFriendlyAndPrivacyAware() {
        XCTAssertEqual(CatCompanionChatCopy.voiceModeButtonAccessibility, "Talk to Miso")
        XCTAssertTrue(MisoVoiceModeCopy.setupNeededMessage.contains("ElevenLabs"))
        XCTAssertTrue(MisoVoiceModeCopy.setupNeededMessage.contains("Keychain"))
        XCTAssertTrue(MisoVoiceModeCopy.microphoneUsageDescription.contains("only when you start Miso voice mode"))
        XCTAssertTrue(MisoVoiceModeCopy.recordingStatus.localizedCaseInsensitiveContains("listening"))
    }

    func testTextToSpeechRequestUsesElevenLabsVoiceEndpointAndJsonBody() throws {
        let request = try ElevenLabsMisoVoiceConfiguration.textToSpeechRequest(
            text: "Tell me a tiny garden secret.",
            apiKey: "eleven-secret-key",
            voiceID: "miso-voice"
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.elevenlabs.io/v1/text-to-speech/miso-voice"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "xi-api-key"), "eleven-secret-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "audio/mpeg")

        let body = try XCTUnwrap(request.httpBody)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(payload["text"] as? String, "Tell me a tiny garden secret.")
        XCTAssertEqual(payload["model_id"] as? String, ElevenLabsMisoVoiceConfiguration.textToSpeechModel)
        XCTAssertNotNil(payload["voice_settings"] as? [String: Any])
    }

    func testSpeechToTextRequestUsesMultipartWithoutEmbeddingAPIKeyInBody() throws {
        let request = try ElevenLabsMisoVoiceConfiguration.speechToTextRequest(
            audioData: Data("MISOAUDIO".utf8),
            fileName: "miso-voice.m4a",
            mimeType: "audio/mp4",
            apiKey: "eleven-secret-key",
            boundary: "miso-boundary"
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, ElevenLabsMisoVoiceConfiguration.speechToTextEndpoint)
        XCTAssertEqual(request.value(forHTTPHeaderField: "xi-api-key"), "eleven-secret-key")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "multipart/form-data; boundary=miso-boundary"
        )

        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains(#"name="model_id""#))
        XCTAssertTrue(body.contains(ElevenLabsMisoVoiceConfiguration.speechToTextModel))
        XCTAssertTrue(body.contains(#"filename="miso-voice.m4a""#))
        XCTAssertTrue(body.contains("MISOAUDIO"))
        XCTAssertFalse(body.contains("eleven-secret-key"))
    }

    func testVoiceErrorPresenterRedactsSecretsAndLocalPaths() {
        let raw = "xi-api-key=eleven-secret-key failed while reading /Users/chrisdimarco/Desktop/test.m4a"
        let message = MisoVoiceModeErrorPresenter.sanitizedMessage(raw)

        XCTAssertFalse(message.contains("eleven-secret-key"))
        XCTAssertFalse(message.contains("/Users/chrisdimarco"))
        XCTAssertTrue(message.contains("[redacted"))
    }
}
