import Foundation
import Testing
@testable import PlantWallpaper

@Suite("AI prompt history")
struct GardenAIPromptHistoryStoreTests {
    @Test("prompt history records latest prompts and de-duplicates repeats")
    func promptHistoryRecordsLatestPromptsAndDeduplicatesRepeats() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenAIPromptHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = GardenAIPromptHistoryStore(directoryURL: directoryURL)
        store.record(
            feature: .wallpaperEdit,
            title: "Warm light",
            prompt: "make the stone warmer",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        store.record(
            feature: .customPlant,
            title: "Glass Bonsai",
            prompt: "a tiny translucent bonsai",
            createdAt: Date(timeIntervalSince1970: 101)
        )
        store.record(
            feature: .wallpaperEdit,
            title: "Warm light again",
            prompt: " make the stone warmer ",
            createdAt: Date(timeIntervalSince1970: 102)
        )

        #expect(store.entries().count == 2)
        #expect(store.recentPrompt(for: .wallpaperEdit) == "make the stone warmer")
        #expect(store.recentPrompt(for: .customPlant) == "a tiny translucent bonsai")
        #expect(store.entries().first?.title == "Warm light again")
    }

    @Test("prompt history caps saved entries")
    func promptHistoryCapsSavedEntries() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenAIPromptHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = GardenAIPromptHistoryStore(directoryURL: directoryURL)
        for index in 0..<(GardenAIPromptHistoryStore.maximumStoredEntries + 8) {
            store.record(
                feature: .newWallpaper,
                title: "Scene \(index)",
                prompt: "wallpaper prompt \(index)",
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        #expect(store.entries().count == GardenAIPromptHistoryStore.maximumStoredEntries)
        #expect(store.recentPrompt(for: .newWallpaper) == "wallpaper prompt \(GardenAIPromptHistoryStore.maximumStoredEntries + 7)")

        store.deleteAll()
        #expect(store.entries().isEmpty)
    }
}
