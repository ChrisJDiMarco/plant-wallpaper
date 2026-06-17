import Foundation

enum OpenAIImageGenerationConfiguration {
    static let primaryModel = "gpt-image-2"
    static let fallbackModels = ["gpt-image-1.5", "gpt-image-1", "gpt-image-1-mini"]

    static var modelsInFallbackOrder: [String] {
        [primaryModel] + fallbackModels
    }

    static func shouldTryNextModel(afterOpenAIError message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("model")
            && (
                normalized.contains("does not exist")
                    || normalized.contains("not found")
                    || normalized.contains("not supported")
                    || normalized.contains("unsupported")
                    || normalized.contains("invalid")
                    || normalized.contains("access")
            )
    }
}
