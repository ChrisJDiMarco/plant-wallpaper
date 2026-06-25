import AppKit
import AVFoundation

@MainActor
final class GardenVideoWallpaperController {
    private var windows: [GardenVideoWallpaperWindow] = []
    private var players: [AVQueuePlayer] = []
    private var loopers: [AVPlayerLooper] = []
    private var activeVideoURL: URL?
    private var loops = true

    var isActive: Bool {
        !windows.isEmpty
    }

    func show(videoURL: URL, loops: Bool = true, autoPlay: Bool = true) {
        close()
        activeVideoURL = videoURL
        self.loops = loops

        for screen in NSScreen.screens {
            let window = GardenVideoWallpaperWindow(screen: screen)
            let playerItem = AVPlayerItem(url: videoURL)
            let player = AVQueuePlayer(playerItem: playerItem)
            player.isMuted = true
            player.actionAtItemEnd = loops ? .none : .pause

            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspectFill
            layer.frame = NSRect(origin: .zero, size: screen.frame.size)

            let view = GardenVideoWallpaperView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.black.cgColor
            view.layer?.addSublayer(layer)
            view.playerLayer = layer

            window.contentView = view
            window.orderFrontRegardless()

            if loops {
                let looper = AVPlayerLooper(player: player, templateItem: playerItem)
                loopers.append(looper)
            } else {
                player.seek(to: .zero)
            }
            if autoPlay {
                player.play()
            }

            windows.append(window)
            players.append(player)
        }
    }

    func setLooping(_ shouldLoop: Bool) {
        guard loops != shouldLoop else {
            return
        }
        loops = shouldLoop
        guard let activeVideoURL else {
            return
        }
        show(videoURL: activeVideoURL, loops: shouldLoop, autoPlay: shouldLoop)
    }

    @discardableResult
    func playOnceFromStart() -> Bool {
        guard !loops, let activeVideoURL, !players.isEmpty else {
            return false
        }
        for player in players {
            player.pause()
            player.removeAllItems()
            player.insert(AVPlayerItem(url: activeVideoURL), after: nil)
            player.seek(to: .zero)
            player.play()
        }
        return true
    }

    func close() {
        players.forEach { $0.pause() }
        windows.forEach { $0.close() }
        players = []
        loopers = []
        windows = []
        activeVideoURL = nil
    }
}

private final class GardenVideoWallpaperWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: true)
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: GardenDesktopWindowLevels.plantSpotlight.rawValue + 10)
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class GardenVideoWallpaperView: NSView {
    weak var playerLayer: AVPlayerLayer?

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }
}
