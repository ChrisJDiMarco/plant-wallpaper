import Foundation
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden flythrough video library")
struct GardenFlythroughVideoLibraryTests {
    @Test("saved flythrough videos persist and keep newest first")
    func savedFlythroughVideosPersistAndKeepNewestFirst() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenFlythroughVideoLibraryTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let firstVideoURL = directoryURL.appendingPathComponent("first.mp4")
        let secondVideoURL = directoryURL.appendingPathComponent("second.mp4")
        FileManager.default.createFile(atPath: firstVideoURL.path, contents: Data([0x01]))
        FileManager.default.createFile(atPath: secondVideoURL.path, contents: Data([0x02]))

        let library = GardenFlythroughVideoLibrary(directoryURL: directoryURL, importsExistingVideos: false)
        library.add(videoURL: firstVideoURL, sceneKey: "empty-conservatory-hall", durationSeconds: 10)
        library.add(videoURL: secondVideoURL, sceneKey: "room-modern-bedroom-canvas", durationSeconds: 60)

        let reloadedLibrary = GardenFlythroughVideoLibrary(directoryURL: directoryURL, importsExistingVideos: false)
        let records = reloadedLibrary.recordsForDisplay()

        #expect(records.map(\.videoURL) == [secondVideoURL.standardizedFileURL, firstVideoURL.standardizedFileURL])
        #expect(records.first?.sceneKey == "room-modern-bedroom-canvas")
        #expect(records.first?.durationSeconds == 60)
    }
}
