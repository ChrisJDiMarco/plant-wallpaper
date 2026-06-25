import Foundation

struct GardenFlythroughVideoRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let videoURL: URL
    let sceneKey: String?
    let createdAt: Date
    let durationSeconds: Int
}

@MainActor
final class GardenFlythroughVideoLibrary {
    private let manifestURL: URL
    private let fileManager: FileManager
    private(set) var records: [GardenFlythroughVideoRecord] = []

    init(
        directoryURL: URL,
        fileManager: FileManager = .default,
        importsExistingVideos: Bool = true
    ) {
        self.manifestURL = directoryURL.appendingPathComponent("flythrough-videos.json")
        self.fileManager = fileManager
        load()
        if importsExistingVideos {
            importExistingFlythroughVideos()
        }
    }

    func recordsForDisplay() -> [GardenFlythroughVideoRecord] {
        records.filter { fileManager.fileExists(atPath: $0.videoURL.path) }
    }

    @discardableResult
    func add(
        videoURL: URL,
        sceneKey: String?,
        durationSeconds: Int,
        createdAt: Date = Date()
    ) -> GardenFlythroughVideoRecord {
        let standardizedURL = videoURL.standardizedFileURL
        if let existingIndex = records.firstIndex(where: { $0.videoURL.standardizedFileURL == standardizedURL }) {
            let existing = records.remove(at: existingIndex)
            records.insert(existing, at: 0)
            save()
            return existing
        }

        let record = GardenFlythroughVideoRecord(
            id: UUID(),
            videoURL: standardizedURL,
            sceneKey: sceneKey,
            createdAt: createdAt,
            durationSeconds: durationSeconds
        )
        records.insert(record, at: 0)
        save()
        return record
    }

    private func load() {
        guard let data = try? Data(contentsOf: manifestURL),
              let decoded = try? JSONDecoder().decode([GardenFlythroughVideoRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded
    }

    private func importExistingFlythroughVideos() {
        guard let directoryURL = fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Plant Wallpaper Flythroughs", isDirectory: true),
              let videoURLs = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else {
            return
        }

        let knownPaths = Set(records.map { $0.videoURL.standardizedFileURL.path })
        let importedRecords = videoURLs
            .filter { $0.pathExtension.lowercased() == "mp4" }
            .map(\.standardizedFileURL)
            .filter { !knownPaths.contains($0.path) }
            .map { videoURL in
                let values = try? videoURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                return GardenFlythroughVideoRecord(
                    id: UUID(),
                    videoURL: videoURL,
                    sceneKey: nil,
                    createdAt: values?.creationDate ?? values?.contentModificationDate ?? Date(),
                    durationSeconds: 0
                )
            }
        guard !importedRecords.isEmpty else {
            return
        }

        records.append(contentsOf: importedRecords)
        records.sort { $0.createdAt > $1.createdAt }
        save()
    }

    private func save() {
        do {
            try fileManager.createDirectory(
                at: manifestURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(records)
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            NSLog("Plant Wallpaper could not save flythrough video library: \(error.localizedDescription)")
        }
    }
}
