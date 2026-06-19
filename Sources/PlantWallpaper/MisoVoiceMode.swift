import AppKit
import AVFoundation
import Foundation
import Security

enum ElevenLabsAPIKeyStoreError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain returned status \(status)."
        }
    }
}

enum ElevenLabsAPIKeyStore {
    static let keyFieldPlaceholder = "Paste your ElevenLabs API key"

    private static let service = "com.chrisdimarco.wallpapergarden.elevenlabs"
    private static let account = "elevenlabs-api-key"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return key
    }

    static func save(_ apiKey: String) throws {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            delete()
            return
        }

        let data = Data(trimmedKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let update: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw ElevenLabsAPIKeyStoreError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw ElevenLabsAPIKeyStoreError.unexpectedStatus(addStatus)
        }
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum MisoVoiceModeCopy {
    static let setupNeededMessage = """
    Voice mode needs an ElevenLabs API key first. I will store it in macOS Keychain and only use the microphone when you click the voice button.
    """

    static let microphoneUsageDescription = "Plant Wallpaper uses the microphone only when you start Miso voice mode, so you can talk to the cat companion."
    static let recordingStatus = "Listening... click the mic again when you are done talking to Miso."
    static let transcribingStatus = "Transcribing that for Miso..."
    static let speakingStatus = "Miso is speaking..."
    static let emptyTranscriptMessage = "I did not catch that. Try again with your face slightly closer to the invisible microphone ceremony."
    static let cancelledMessage = "Voice mode stopped."
}

enum MisoVoiceModeState: Equatable {
    case idle
    case recording
    case transcribing
    case speaking
}

enum MisoVoiceModeError: Error, LocalizedError {
    case missingAPIKey
    case emptyInput
    case emptyTranscript
    case invalidHTTPResponse
    case elevenLabsError(String)
    case audioUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            MisoVoiceModeCopy.setupNeededMessage
        case .emptyInput:
            "Miso voice mode needs something to say."
        case .emptyTranscript:
            MisoVoiceModeCopy.emptyTranscriptMessage
        case .invalidHTTPResponse:
            "Miso could not read the ElevenLabs response. Please try again."
        case .elevenLabsError(let message):
            message
        case .audioUnavailable(let message):
            message
        }
    }
}

enum MisoVoiceModeErrorPresenter {
    static func userMessage(for error: Error) -> String {
        let rawMessage = (error as? LocalizedError)?.errorDescription
            ?? error.localizedDescription
        let sanitized = sanitizedMessage(rawMessage)
        return sanitized.isEmpty
            ? "Miso voice mode could not complete that request. Please try again."
            : sanitized
    }

    static func sanitizedMessage(_ rawMessage: String) -> String {
        var message = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return ""
        }

        let replacements = [
            (#"(?i)xi-api-key\s*[:=]\s*[^\s,;)>\]]+"#, "[redacted ElevenLabs key]"),
            (#"(?i)Authorization\s*[:=]\s*(?:Bearer\s+)?[^\s,;)>\]]+"#, "Authorization: [redacted authorization header]"),
            (#"(?i)\b[A-Za-z0-9_]*(?:api[_-]?key|access[_-]?token|refresh[_-]?token|secret)\s*[:=]\s*["']?[^\s,;"')>]+"#, "[redacted secret assignment]"),
            (#"/Users/[^\s,;:)>\]]+"#, "[redacted local path]")
        ]

        for (pattern, replacement) in replacements {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            message = regex.stringByReplacingMatches(
                in: message,
                range: NSRange(message.startIndex..., in: message),
                withTemplate: replacement
            )
        }
        return message
    }
}

enum ElevenLabsMisoVoiceConfiguration {
    static let speechToTextEndpoint = URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!
    static let textToSpeechBaseEndpoint = URL(string: "https://api.elevenlabs.io/v1/text-to-speech")!
    static let speechToTextModel = "scribe_v1"
    static let textToSpeechModel = "eleven_flash_v2_5"
    static let defaultVoiceID = "21m00Tcm4TlvDq8ikWAM"
    static let maxTextToSpeechCharacters = 2_200

    static func textToSpeechRequest(
        text: String,
        apiKey: String,
        voiceID: String = defaultVoiceID
    ) throws -> URLRequest {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let boundedText = boundedSpeechText(text)
        let sanitizedVoiceID = voiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw MisoVoiceModeError.missingAPIKey
        }
        guard !boundedText.isEmpty else {
            throw MisoVoiceModeError.emptyInput
        }
        guard !sanitizedVoiceID.isEmpty,
              let encodedVoiceID = sanitizedVoiceID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let endpoint = URL(string: "\(textToSpeechBaseEndpoint.absoluteString)/\(encodedVoiceID)") else {
            throw MisoVoiceModeError.audioUnavailable("Miso voice mode does not have a valid ElevenLabs voice selected.")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue(trimmedKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": boundedText,
            "model_id": textToSpeechModel,
            "voice_settings": [
                "stability": 0.58,
                "similarity_boost": 0.78,
                "style": 0.18,
                "use_speaker_boost": true
            ]
        ], options: [])
        return request
    }

    static func speechToTextRequest(
        audioData: Data,
        fileName: String,
        mimeType: String,
        apiKey: String,
        boundary: String = "miso-voice-\(UUID().uuidString)"
    ) throws -> URLRequest {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw MisoVoiceModeError.missingAPIKey
        }
        guard !audioData.isEmpty else {
            throw MisoVoiceModeError.audioUnavailable("Miso did not record any audio.")
        }

        var body = Data()
        appendMultipartField(name: "model_id", value: speechToTextModel, boundary: boundary, to: &body)
        appendMultipartFile(
            name: "file",
            fileName: fileName,
            mimeType: mimeType,
            fileData: audioData,
            boundary: boundary,
            to: &body
        )
        body.append("--\(boundary)--\r\n".data(using: .utf8) ?? Data())

        var request = URLRequest(url: speechToTextEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue(trimmedKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    static func transcriptText(from data: Data) throws -> String {
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let text = payload?["text"] as? String,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let errorMessage = errorMessage(from: payload) {
            throw MisoVoiceModeError.elevenLabsError(errorMessage)
        }
        throw MisoVoiceModeError.emptyTranscript
    }

    static func elevenLabsErrorMessage(from data: Data) -> String {
        let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return errorMessage(from: payload)
            ?? String(data: data, encoding: .utf8)
            ?? "ElevenLabs returned an error."
    }

    private static func boundedSpeechText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxTextToSpeechCharacters else {
            return trimmed
        }
        return String(trimmed.prefix(maxTextToSpeechCharacters))
    }

    private static func appendMultipartField(name: String, value: String, boundary: String, to body: inout Data) {
        body.append("--\(boundary)\r\n".data(using: .utf8) ?? Data())
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8) ?? Data())
        body.append("\(value)\r\n".data(using: .utf8) ?? Data())
    }

    private static func appendMultipartFile(
        name: String,
        fileName: String,
        mimeType: String,
        fileData: Data,
        boundary: String,
        to body: inout Data
    ) {
        body.append("--\(boundary)\r\n".data(using: .utf8) ?? Data())
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8) ?? Data())
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8) ?? Data())
        body.append(fileData)
        body.append("\r\n".data(using: .utf8) ?? Data())
    }

    private static func errorMessage(from payload: [String: Any]?) -> String? {
        guard let error = payload?["error"] as? [String: Any] else {
            return nil
        }
        return [
            error["message"] as? String,
            error["type"] as? String,
            error["code"] as? String
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

protocol ElevenLabsVoiceHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: ElevenLabsVoiceHTTPClient {}

final class ElevenLabsMisoVoiceClient: @unchecked Sendable {
    private let httpClient: ElevenLabsVoiceHTTPClient

    init(httpClient: ElevenLabsVoiceHTTPClient = URLSession.shared) {
        self.httpClient = httpClient
    }

    func transcribe(audioData: Data, fileName: String, mimeType: String, apiKey: String) async throws -> String {
        let request = try ElevenLabsMisoVoiceConfiguration.speechToTextRequest(
            audioData: audioData,
            fileName: fileName,
            mimeType: mimeType,
            apiKey: apiKey
        )
        let (data, response) = try await httpClient.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MisoVoiceModeError.invalidHTTPResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MisoVoiceModeError.elevenLabsError(
                ElevenLabsMisoVoiceConfiguration.elevenLabsErrorMessage(from: data)
            )
        }
        return try ElevenLabsMisoVoiceConfiguration.transcriptText(from: data)
    }

    func speechAudio(text: String, apiKey: String, voiceID: String = ElevenLabsMisoVoiceConfiguration.defaultVoiceID) async throws -> Data {
        let request = try ElevenLabsMisoVoiceConfiguration.textToSpeechRequest(
            text: text,
            apiKey: apiKey,
            voiceID: voiceID
        )
        let (data, response) = try await httpClient.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MisoVoiceModeError.invalidHTTPResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MisoVoiceModeError.elevenLabsError(
                ElevenLabsMisoVoiceConfiguration.elevenLabsErrorMessage(from: data)
            )
        }
        guard !data.isEmpty else {
            throw MisoVoiceModeError.audioUnavailable("ElevenLabs returned empty audio.")
        }
        return data
    }
}

@MainActor
final class MisoVoiceModeAudioController: NSObject {
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private(set) var recordingURL: URL?

    static func requestMicrophoneAccess(completion: @escaping @MainActor (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            Task { @MainActor in completion(true) }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { allowed in
                Task { @MainActor in completion(allowed) }
            }
        default:
            Task { @MainActor in completion(false) }
        }
    }

    func startRecording() throws {
        stopPlayback()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("miso-voice-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.record()
        self.recorder = recorder
        recordingURL = url
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        recorder = nil
        return recordingURL
    }

    func cancelRecording() {
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
    }

    func play(_ audioData: Data) throws {
        stopPlayback()
        let player = try AVAudioPlayer(data: audioData)
        player.prepareToPlay()
        player.play()
        self.player = player
    }

    func stopPlayback() {
        player?.stop()
        player = nil
    }
}

@MainActor
enum ElevenLabsAPIKeySettingsPresenter {
    @discardableResult
    static func present() -> Bool {
        let alert = NSAlert()
        alert.messageText = "ElevenLabs API Key"
        alert.informativeText = "Miso voice mode stores your key in macOS Keychain and uses it only after you click the voice button."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Remove Key")
        alert.addButton(withTitle: "Cancel")

        let keyField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 430, height: 26))
        keyField.placeholderString = ElevenLabsAPIKeyStore.keyFieldPlaceholder
        keyField.stringValue = ElevenLabsAPIKeyStore.load() ?? ""
        alert.accessoryView = keyField

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            do {
                try ElevenLabsAPIKeyStore.save(keyField.stringValue)
                return true
            } catch {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Could not save ElevenLabs key"
                errorAlert.informativeText = MisoVoiceModeErrorPresenter.userMessage(for: error)
                errorAlert.alertStyle = .warning
                errorAlert.runModal()
                return false
            }
        case .alertSecondButtonReturn:
            ElevenLabsAPIKeyStore.delete()
            return true
        default:
            return false
        }
    }
}
