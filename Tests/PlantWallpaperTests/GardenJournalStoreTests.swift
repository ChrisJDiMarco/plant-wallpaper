import Foundation
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden journal store")
struct GardenJournalStoreTests {
    @Test("journal append creates its directory before saving")
    func journalAppendCreatesDirectoryBeforeSaving() {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenJournal-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let journal = GardenJournalStore(directoryURL: directoryURL)
        journal.append(.planted, "Planted a tulip", at: Date(timeIntervalSince1970: 1_000))

        let reloadedJournal = GardenJournalStore(directoryURL: directoryURL)

        #expect(reloadedJournal.recentEntries().first?.text == "Planted a tulip")
    }
}
