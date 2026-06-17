import Foundation
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden health check report")
struct GardenHealthCheckReportTests {
    @Test("health check report summarizes diagnostics without dumping full state")
    func healthCheckReportSummarizesDiagnostics() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenHealthCheck-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let store = GardenStore(
            state: GardenState.defaultGarden(screenCount: 1, now: Date(timeIntervalSince1970: 1_000)),
            persistence: GardenPersistence(directoryURL: directoryURL),
            activeSceneKey: "empty-conservatory-hall"
        )
        store.journal = GardenJournalStore(directoryURL: directoryURL)
        store.journal?.append(.planted, "Planted a test flower", at: Date(timeIntervalSince1970: 1_100))
        let recorder = GardenTimeLapseRecorder(baseDirectoryURL: directoryURL)

        let data = try GardenHealthCheckReport.makeJSONData(
            store: store,
            activeSceneName: "Conservatory Hall",
            weatherStatus: "Weather sync off",
            timeLapseRecorder: recorder,
            at: Date(timeIntervalSince1970: 1_200)
        )
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["app"] as? String == "Plant Wallpaper")
        #expect(object["activeScene"] as? String == "Conservatory Hall")
        #expect(object["weatherStatus"] as? String == "Weather sync off")
        #expect(object["rawGardenState"] == nil)

        let garden = try #require(object["garden"] as? [String: Any])
        #expect(garden["plants"] as? Int == store.state.plants.count)

        let diary = try #require(object["recentDiary"] as? [[String: Any]])
        #expect(diary.first?["message"] as? String == "Planted a test flower")
    }
}
