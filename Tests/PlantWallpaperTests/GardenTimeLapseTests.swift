import Foundation
import Testing
@testable import PlantGardenCore
@testable import PlantWallpaper

@MainActor
@Suite("Garden time-lapse")
struct GardenTimeLapseTests {
    @Test("time lapse inventory reports frame count and estimated storage")
    func timeLapseInventoryReportsFrameCountAndEstimatedStorage() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenTimeLapse-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let recorder = GardenTimeLapseRecorder(baseDirectoryURL: directoryURL)
        try FileManager.default.createDirectory(at: recorder.frameDirectoryURL, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 10).write(to: recorder.frameDirectoryURL.appendingPathComponent("garden-2026-06-10.jpg"))
        try Data(repeating: 1, count: 20).write(to: recorder.frameDirectoryURL.appendingPathComponent("garden-2026-06-11.jpg"))
        try Data(repeating: 1, count: 30).write(to: recorder.frameDirectoryURL.appendingPathComponent("notes.txt"))

        let inventory = recorder.inventorySummary()

        #expect(inventory.frameCount == 2)
        #expect(inventory.byteCount == 30)
        #expect(inventory.storageSummary.contains("2 frames"))
    }

    @Test("time lapse cleanup deletes stored frames only")
    func timeLapseCleanupDeletesStoredFramesOnly() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenTimeLapseCleanup-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let recorder = GardenTimeLapseRecorder(baseDirectoryURL: directoryURL)
        try FileManager.default.createDirectory(at: recorder.frameDirectoryURL, withIntermediateDirectories: true)
        let frameURL = recorder.frameDirectoryURL.appendingPathComponent("garden-2026-06-10.jpg")
        let noteURL = recorder.frameDirectoryURL.appendingPathComponent("notes.txt")
        try Data(repeating: 1, count: 10).write(to: frameURL)
        try Data(repeating: 2, count: 10).write(to: noteURL)

        recorder.deleteAllFrames()

        #expect(!FileManager.default.fileExists(atPath: frameURL.path))
        #expect(FileManager.default.fileExists(atPath: noteURL.path))
        #expect(recorder.inventorySummary().frameCount == 0)
    }

    @Test("weekly time lapse frames use a stable week stamp")
    func weeklyTimeLapseFramesUseStableWeekStamp() throws {
        let formatter = ISO8601DateFormatter()
        let first = try #require(formatter.date(from: "2026-06-08T12:00:00Z"))
        let second = try #require(formatter.date(from: "2026-06-12T12:00:00Z"))

        #expect(GardenTimeLapseRecorder.weekStamp(for: first) == GardenTimeLapseRecorder.weekStamp(for: second))
    }

    @Test("off cadence does not create time lapse frames")
    func offCadenceDoesNotCreateTimeLapseFrames() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenTimeLapseOff-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let recorder = GardenTimeLapseRecorder(baseDirectoryURL: directoryURL)
        let store = GardenStore(
            state: GardenState(settings: GardenSettings.default.updating(timeLapseCadence: .off)),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )

        recorder.captureFrameIfNeeded(store: store, at: Date(timeIntervalSince1970: 1_780_000_000))

        #expect(!FileManager.default.fileExists(atPath: recorder.frameDirectoryURL.path))
        #expect(recorder.inventorySummary().frameCount == 0)
    }
}
