import AVFoundation
import Foundation
import PlantGardenCore

@MainActor
protocol GardenMusicPlaybackControlling: AnyObject {
    var isPlaying: Bool { get }
    var playingRadioStation: GardenRadioStation? { get }
    var playingRadioStream: GardenRadioStream? { get }
    func playChillHopRadio()
    func playRadioStation(_ station: GardenRadioStation)
    func playRadioStream(_ stream: GardenRadioStream)
    func playSpotify(using settings: GardenSettings)
    func stop()
    func toggleChillHopRadio()
    func toggleRadioStation(_ station: GardenRadioStation)
    func toggleRadioStream(_ stream: GardenRadioStream)
    func toggleMusic(using settings: GardenSettings)
}

@MainActor
final class GardenRadioPlayer: GardenMusicPlaybackControlling {
    static let shared = GardenRadioPlayer()

    static func streamURLs(for station: GardenRadioStation) -> [URL] {
        station.streamURLs
    }

    static func streamURLs(for stream: GardenRadioStream) -> [URL] {
        stream.streamURLs
    }

    /// How long a stream may sit in buffering before we try the next one.
    /// Live streams normally reach playback within ~3 seconds.
    static let playbackStartGracePeriod: TimeInterval = 8.0

    /// Upper bound on stream (re)start attempts per play request, so a dead
    /// network doesn't leave a silent retry loop running forever.
    static let maxStreamStartAttempts = 4

    private var player: AVPlayer?
    private var playerItemStatusObservation: NSKeyValueObservation?
    private var playerTimeControlObservation: NSKeyValueObservation?
    private var fallbackTimer: Timer?
    private var currentStreamIndex = 0
    private var currentStation: GardenRadioStation = .chillHopByFluxFM
    private var currentRadioStream: GardenRadioStream = GardenRadioStation.chillHopByFluxFM.stream
    private var streamStartAttempts = 0
    private var volume: Float = 1.0
    private var isRadioPlaying = false

    var isPlaying: Bool {
        isRadioPlaying || GardenSpotifyLauncher.shared.isPlaying
    }

    var playingRadioStation: GardenRadioStation? {
        isRadioPlaying ? currentRadioStream.matchesBuiltInStation : nil
    }

    var playingRadioStream: GardenRadioStream? {
        isRadioPlaying ? currentRadioStream : nil
    }

    func playChillHopRadio() {
        playRadioStation(.chillHopByFluxFM)
    }

    func playRadioStation(_ station: GardenRadioStation) {
        playRadioStream(station.stream)
    }

    func playRadioStream(_ stream: GardenRadioStream) {
        GardenSpotifyLauncher.shared.stop()
        let shouldReplaceCurrentStream = currentRadioStream.id != stream.id
        currentRadioStream = stream
        currentStation = stream.matchesBuiltInStation ?? currentStation
        streamStartAttempts = 0
        if shouldReplaceCurrentStream || player == nil || player?.currentItem?.status == .failed {
            startStream(at: 0)
        } else {
            startPlayback()
        }
    }

    func playSpotify(using settings: GardenSettings) {
        stopChillHopRadio()
        GardenSpotifyLauncher.shared.play(url: settings.spotifyLaunchURL)
    }

    func stop() {
        stopChillHopRadio()
        GardenSpotifyLauncher.shared.stop()
    }

    func toggleChillHopRadio() {
        toggleRadioStation(.chillHopByFluxFM)
    }

    func toggleRadioStation(_ station: GardenRadioStation) {
        toggleRadioStream(station.stream)
    }

    func toggleRadioStream(_ stream: GardenRadioStream) {
        if isRadioPlaying, currentRadioStream.id == stream.id {
            stopChillHopRadio()
        } else {
            playRadioStream(stream)
        }
    }

    func toggleMusic(using settings: GardenSettings) {
        switch settings.musicSource {
        case .chillHopRadio:
            toggleChillHopRadio()
        case .spotify:
            GardenSpotifyLauncher.shared.isPlaying ? GardenSpotifyLauncher.shared.stop() : playSpotify(using: settings)
        }
    }

    func setVolume(_ volume: Double) {
        let resolvedVolume = Float(min(1, max(0, volume)))
        self.volume = resolvedVolume
        player?.volume = resolvedVolume
        player?.isMuted = resolvedVolume <= 0.001
    }

    private func stopChillHopRadio() {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        playerItemStatusObservation = nil
        playerTimeControlObservation = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        isRadioPlaying = false
    }

    private func startStream(at index: Int) {
        let streamURLs = Self.streamURLs(for: currentRadioStream)
        guard !streamURLs.isEmpty else {
            stopChillHopRadio()
            return
        }

        let safeIndex = min(max(0, index), streamURLs.count - 1)
        currentStreamIndex = safeIndex
        streamStartAttempts += 1

        fallbackTimer?.invalidate()
        fallbackTimer = nil
        playerItemStatusObservation = nil
        playerTimeControlObservation = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)

        let streamURL = streamURLs[safeIndex]
        NSLog("Plant Wallpaper \(currentRadioStream.displayName) starting stream: \(streamURL.absoluteString)")

        let playerItem = AVPlayerItem(url: streamURL)
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        // Live radio needs AVPlayer's automatic stall management. Forcing an
        // immediate playback rate with a near-empty buffer
        // (automaticallyWaitsToMinimizeStalling = false + playImmediately)
        // stalls the player at rate 0 the moment it opens the stream, and it
        // never recovers - the bug that made the old desktop radio control silent.
        let player = AVPlayer(playerItem: playerItem)
        player.volume = volume
        player.isMuted = volume <= 0.001
        self.player = player

        playerItemStatusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            Task { @MainActor [weak self] in
                self?.handlePlayerItemStatus(status)
            }
        }
        playerTimeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in
                self?.handleTimeControlStatus(status)
            }
        }

        startPlayback()
    }

    private func startPlayback() {
        player?.volume = volume
        player?.isMuted = volume <= 0.001
        player?.play()
        isRadioPlaying = true
        scheduleFallbackIfNeeded()
    }

    private func scheduleFallbackIfNeeded() {
        fallbackTimer?.invalidate()
        fallbackTimer = Timer.scheduledTimer(
            withTimeInterval: Self.playbackStartGracePeriod,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fallbackIfPlaybackDidNotStart()
            }
        }
    }

    private func handlePlayerItemStatus(_ status: AVPlayerItem.Status) {
        guard isRadioPlaying else {
            return
        }

        if status == .failed {
            NSLog("Plant Wallpaper \(currentRadioStream.displayName) stream failed; trying fallback.")
            startNextStreamIfAvailable()
        }
    }

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        if status == .playing {
            fallbackTimer?.invalidate()
            fallbackTimer = nil
            // Playback succeeded; give any future mid-stream failure a fresh
            // retry budget.
            streamStartAttempts = 0
        }
    }

    private func fallbackIfPlaybackDidNotStart() {
        guard isRadioPlaying,
              let player,
              player.timeControlStatus != .playing else {
            return
        }

        NSLog("Plant Wallpaper \(currentRadioStream.displayName) stream did not enter playback quickly; trying fallback.")
        startNextStreamIfAvailable()
    }

    private func startNextStreamIfAvailable() {
        guard streamStartAttempts < Self.maxStreamStartAttempts else {
            NSLog("Plant Wallpaper \(currentRadioStream.displayName) gave up after \(streamStartAttempts) stream attempts.")
            stopChillHopRadio()
            return
        }

        // Cycle through the stream list so transient failures on the last
        // entry retry from the first, bounded by maxStreamStartAttempts.
        let streamURLs = Self.streamURLs(for: currentRadioStream)
        guard !streamURLs.isEmpty else {
            stopChillHopRadio()
            return
        }
        let nextIndex = (currentStreamIndex + 1) % streamURLs.count
        startStream(at: nextIndex)
    }
}
