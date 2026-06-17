import AppKit
import CoreLocation
import PlantGardenCore

/// Fetches local weather from Open-Meteo (no API key required) using
/// CoreLocation, and feeds it into the garden simulation. Fully optional:
/// when the user keeps weather sync off, or location is unavailable, the
/// garden simply runs without real-world weather.
@MainActor
final class GardenWeatherService: NSObject, CLLocationManagerDelegate {
    private static let refreshInterval: TimeInterval = 30 * 60
    static let privacySummary = "Uses approximate location only for local weather via Open-Meteo. No account, API key, or garden data is sent."

    private let store: GardenStore
    private var locationManager: CLLocationManager?
    private var refreshTimer: Timer?
    private var lastKnownLocation: CLLocation?
    private var lastFetchedCondition: GardenWeatherCondition?
    private(set) var statusDescription = "Off"

    init(store: GardenStore) {
        self.store = store
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: .gardenStoreDidChange,
            object: store
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        syncWithSettings()
    }

    @objc private func storeDidChange() {
        syncWithSettings()

        // Scene switches load a different garden file; re-apply the latest
        // fetched condition so the new scene shares the same sky.
        if store.state.settings.isWeatherSyncEnabled,
           let lastFetchedCondition,
           !lastFetchedCondition.isStale(),
           store.state.weather != lastFetchedCondition {
            store.setWeather(lastFetchedCondition)
        }
    }

    @objc private func systemDidWake() {
        refreshIfEnabled()
    }

    private func syncWithSettings() {
        if store.state.settings.isWeatherSyncEnabled {
            startIfNeeded()
        } else {
            stopIfNeeded()
        }
    }

    private func startIfNeeded() {
        guard refreshTimer == nil else {
            return
        }

        // CoreLocation needs a real app bundle (Info.plist usage string);
        // the bare debug binary and self-test run without one.
        guard Bundle.main.bundleIdentifier != nil else {
            statusDescription = "Unavailable outside the app bundle"
            return
        }

        statusDescription = "Waiting for location"
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        locationManager = manager
        requestLocationIfAuthorized(manager)

        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: Self.refreshInterval,
            repeats: true
        ) { _ in
            Task { @MainActor [weak self] in
                self?.refreshIfEnabled()
            }
        }
        refreshTimer?.tolerance = 120
    }

    private func stopIfNeeded() {
        guard refreshTimer != nil || locationManager != nil else {
            return
        }

        refreshTimer?.invalidate()
        refreshTimer = nil
        locationManager?.delegate = nil
        locationManager = nil
        statusDescription = "Off"
        if store.state.weather != nil {
            store.setWeather(nil)
        }
    }

    private func refreshIfEnabled() {
        guard store.state.settings.isWeatherSyncEnabled else {
            return
        }

        if let lastKnownLocation {
            fetchWeather(for: lastKnownLocation)
        } else if let locationManager {
            requestLocationIfAuthorized(locationManager)
        }
    }

    private func requestLocationIfAuthorized(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorized, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            statusDescription = "Location access denied - enable it in System Settings > Privacy"
        @unknown default:
            statusDescription = "Location unavailable"
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self, let locationManager = self.locationManager else {
                return
            }

            self.requestLocationIfAuthorized(locationManager)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.lastKnownLocation = location
            self.fetchWeather(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.statusDescription = "Location lookup failed"
        }
    }

    private struct OpenMeteoResponse: Decodable {
        struct CurrentWeather: Decodable {
            let temperature: Double
            let weathercode: Int
        }

        let currentWeather: CurrentWeather

        private enum CodingKeys: String, CodingKey {
            case currentWeather = "current_weather"
        }
    }

    private func fetchWeather(for location: CLLocation) {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        guard let url = URL(string: String(
            format: "https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&current_weather=true",
            latitude,
            longitude
        )) else {
            return
        }

        Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                let kind = GardenWeatherKind.fromWMOCode(response.currentWeather.weathercode)
                let temperature = response.currentWeather.temperature
                await MainActor.run { [weak self] in
                    guard let self else {
                        return
                    }

                    // Track when rain stops so the garden can hang a rainbow
                    // in the clearing sky for a few minutes afterwards.
                    let previousWeather = self.store.state.weather
                    let now = Date()
                    let freshCondition = GardenWeatherCondition(kind: kind, temperatureCelsius: temperature, fetchedAt: now)
                    let precipitationEndedAt: Date?
                    if let previousWeather, previousWeather.isPrecipitating, !freshCondition.isPrecipitating {
                        precipitationEndedAt = now
                    } else {
                        precipitationEndedAt = previousWeather?.precipitationEndedAt
                    }

                    let condition = GardenWeatherCondition(
                        kind: kind,
                        temperatureCelsius: temperature,
                        fetchedAt: now,
                        precipitationEndedAt: precipitationEndedAt
                    )
                    self.lastFetchedCondition = condition
                    self.statusDescription = condition.summary
                    self.store.setWeather(condition)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.statusDescription = "Weather fetch failed"
                }
            }
        }
    }
}
