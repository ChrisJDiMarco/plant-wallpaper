import Foundation
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden moment notifier")
struct GardenMomentNotifierTests {
    @Test("first rain celebration is remembered across notifier restarts")
    func firstRainCelebrationIsRememberedAcrossNotifierRestarts() {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenMomentNotifier-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        let defaultsName = "GardenMomentNotifierTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let store = GardenStore(
            state: GardenState(),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let delivered = NotificationDeliveryRecorder()
        var notifier: GardenMomentNotifier? = GardenMomentNotifier(
            store: store,
            defaults: defaults,
            isAvailable: true,
            notificationAuthorizer: { completion in completion(true) },
            notificationDeliverer: { title, body in delivered.append(title: title, body: body) }
        )

        store.setWeather(GardenWeatherCondition(kind: .rain, temperatureCelsius: 14, fetchedAt: Date()))
        #expect(delivered.titles.contains("It's raining outside"))

        store.setWeather(GardenWeatherCondition(kind: .clear, temperatureCelsius: 19, fetchedAt: Date()))
        notifier = nil
        _ = GardenMomentNotifier(
            store: store,
            defaults: defaults,
            isAvailable: true,
            notificationAuthorizer: { completion in completion(true) },
            notificationDeliverer: { title, body in delivered.append(title: title, body: body) }
        )

        store.setWeather(GardenWeatherCondition(kind: .rain, temperatureCelsius: 14, fetchedAt: Date()))

        #expect(delivered.titles.filter { $0 == "It's raining outside" }.count == 1)
        _ = notifier
    }

    @Test("focus completion celebrates lifetime milestones")
    func focusCompletionCelebratesLifetimeMilestones() {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenMomentNotifier-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        let start = Date()
        let store = GardenStore(
            state: GardenState(
                lastUpdatedAt: start,
                plants: [
                    Plant(
                        species: .sunflower,
                        screenIndex: 0,
                        position: GardenPoint(x: 0.5, y: 0.76),
                        growth: 0.42,
                        hydration: 0.9,
                        health: 0.92
                    )
                ],
                focusStats: GardenFocusStats(completedSessions: 3, totalFocusSeconds: 75 * 60)
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let delivered = NotificationDeliveryRecorder()
        let notifier = GardenMomentNotifier(
            store: store,
            isAvailable: true,
            notificationAuthorizer: { completion in completion(true) },
            notificationDeliverer: { title, body in delivered.append(title: title, body: body) }
        )

        store.startFocusSession(duration: 25 * 60)
        store.advance(to: Date().addingTimeInterval(26 * 60))

        #expect(delivered.titles.contains("Focus session complete"))
        #expect(delivered.bodies.contains { $0.contains("100 minutes") })
        _ = notifier
    }
}

private final class NotificationDeliveryRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [(String, String)] = []

    var titles: [String] {
        lock.lock()
        defer { lock.unlock() }
        return values.map(\.0)
    }

    var bodies: [String] {
        lock.lock()
        defer { lock.unlock() }
        return values.map(\.1)
    }

    func append(title: String, body: String) {
        lock.lock()
        values.append((title, body))
        lock.unlock()
    }
}
