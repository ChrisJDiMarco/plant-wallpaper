import Foundation
import PlantGardenCore

/// The garden's diary on disk: an append-only log of plantings, milestones,
/// harvests, focus sessions, weather, and rare moments. Capped so years of
/// gardening stay a small JSON file.
@MainActor
final class GardenJournalStore {
    static let maximumEntries = 400

    private let fileURL: URL
    private let fileManager: FileManager
    private(set) var entries: [GardenJournalEntry]

    init(directoryURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = directoryURL.appendingPathComponent("garden-journal.json")
        if let data = try? Data(contentsOf: fileURL),
           let decodedEntries = try? JSONDecoder.gardenJournal.decode([GardenJournalEntry].self, from: data) {
            entries = decodedEntries
        } else {
            entries = []
        }
    }

    func append(_ kind: GardenJournalEntry.Kind, _ text: String, at date: Date = Date()) {
        entries.append(GardenJournalEntry(date: date, kind: kind, text: text))
        if entries.count > Self.maximumEntries {
            entries.removeFirst(entries.count - Self.maximumEntries)
        }
        save()
    }

    func recentEntries(limit: Int = 8) -> [GardenJournalEntry] {
        Array(entries.suffix(limit).reversed())
    }

    private func save() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.gardenJournal.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("Plant Wallpaper could not save the garden journal: \(error.localizedDescription)")
        }
    }
}

private extension JSONDecoder {
    static let gardenJournal: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private extension JSONEncoder {
    static let gardenJournal: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}
