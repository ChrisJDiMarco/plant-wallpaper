import Foundation
import PlantGardenCore

enum GardenAIPromptFeature: String, Codable, CaseIterable, Sendable {
    case newWallpaper
    case wallpaperEdit
    case wallpaperProgression
    case customPlant

    var displayName: String {
        switch self {
        case .newWallpaper:
            "New Wallpaper"
        case .wallpaperEdit:
            "Wallpaper Edit"
        case .wallpaperProgression:
            "Wallpaper Progression"
        case .customPlant:
            "Custom Plant"
        }
    }
}

struct GardenAIPromptHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var feature: GardenAIPromptFeature
    var title: String
    var prompt: String
    var createdAt: Date
}

final class GardenAIPromptHistoryStore {
    static let maximumStoredEntries = 50

    private let fileURL: URL
    private let fileManager: FileManager

    init(directoryURL: URL, fileManager: FileManager = .default) {
        self.fileURL = directoryURL.appendingPathComponent("ai-prompt-history.json")
        self.fileManager = fileManager
    }

    func entries() -> [GardenAIPromptHistoryEntry] {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([GardenAIPromptHistoryEntry].self, from: data)) ?? []
    }

    func recentPrompt(for feature: GardenAIPromptFeature) -> String? {
        entries().first { $0.feature == feature }?.prompt
    }

    func record(
        feature: GardenAIPromptFeature,
        title: String,
        prompt: String,
        createdAt: Date = Date()
    ) {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            return
        }

        var nextEntries = entries()
        nextEntries.removeAll {
            $0.feature == feature
                && $0.prompt.caseInsensitiveCompare(trimmedPrompt) == .orderedSame
        }
        nextEntries.insert(
            GardenAIPromptHistoryEntry(
                id: UUID(),
                feature: feature,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                prompt: trimmedPrompt,
                createdAt: createdAt
            ),
            at: 0
        )
        if nextEntries.count > Self.maximumStoredEntries {
            nextEntries = Array(nextEntries.prefix(Self.maximumStoredEntries))
        }

        save(nextEntries)
    }

    func deleteAll() {
        try? fileManager.removeItem(at: fileURL)
    }

    private func save(_ entries: [GardenAIPromptHistoryEntry]) {
        do {
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("Plant Wallpaper could not save AI prompt history: \(error.localizedDescription)")
        }
    }
}
