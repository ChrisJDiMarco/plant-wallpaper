import AppKit
import Foundation

@MainActor
final class GardenSpotifyLauncher {
    static let shared = GardenSpotifyLauncher()

    private(set) var isPlaying = false

    private init() {}

    func play(url: URL) {
        NSWorkspace.shared.open(url)
        isPlaying = true
        schedulePlaybackNudge()
    }

    func stop() {
        guard isPlaying else {
            return
        }

        runSpotifyScript("""
        if application "Spotify" is running then
            tell application "Spotify" to pause
        end if
        """)
        isPlaying = false
    }

    private func schedulePlaybackNudge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self,
                  self.isPlaying else {
                return
            }

            self.runSpotifyScript("""
            if application "Spotify" is running then
                tell application "Spotify" to play
            end if
            """)
        }
    }

    private func runSpotifyScript(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            NSLog("Plant Wallpaper Spotify control failed: \(error)")
        }
    }
}
