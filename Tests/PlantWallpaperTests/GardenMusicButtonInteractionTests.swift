import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden radio companion interactions")
struct GardenMusicButtonInteractionTests {
    @Test("radio player exposes the Filtermusic ChillHop stream")
    func radioPlayerExposesFiltermusicChillHopStream() {
        #expect(GardenRadioPlayer.streamURLs(for: .chillHopByFluxFM).map(\.absoluteString) == [
            "https://streams.fluxfm.de/Chillhop/mp3-128/streams.fluxfm.de"
        ])
    }

    @Test("clicking radio companion starts its station")
    func clickingRadioCompanionStartsItsStation() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let player = FakeMusicPlayer()
        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.44, y: 0.62),
                    companion: .tinyRocket
                )
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: player
        )
        let hitPoint = try #require(canvasView.musicButtonHitPointForSelfTest())

        #expect(canvasView.beginGardenInteraction(at: hitPoint) == .drag)
        #expect(canvasView.endPlantDrag())
        #expect(player.toggleCount == 1)
        #expect(player.toggledStations == [.spaceDogs])
        #expect(player.playCount == 1)
        #expect(player.playedStations == [.spaceDogs])
        #expect(player.isPlaying)
    }

    @Test("clicking reassigned companion starts its custom stream")
    func clickingReassignedCompanionStartsItsCustomStream() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let customStream = GardenRadioStream(
            id: "filtermusic:custom-space",
            displayName: "Custom Space",
            streamURLStrings: ["https://example.com/custom-space.mp3"],
            filtermusicPageURLString: "https://filtermusic.net/custom-space",
            shortDescription: "Custom cosmic test stream."
        )
        let settings = try #require(
            GardenSettings.default.assigningRadioStream(customStream, to: .tinyRocket)
        )
        let player = FakeMusicPlayer()
        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.44, y: 0.62),
                    companion: .tinyRocket
                ),
                settings: settings
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: player
        )
        let hitPoint = try #require(canvasView.musicButtonHitPointForSelfTest())

        #expect(canvasView.beginGardenInteraction(at: hitPoint) == .drag)
        #expect(canvasView.endPlantDrag())

        #expect(player.toggleCount == 1)
        #expect(player.playingRadioStream?.id == customStream.id)
        #expect(player.playingRadioStation == nil)
        #expect(player.toggledStations.isEmpty)
    }

    @Test("clicking a different companion starts its associated station")
    func clickingDifferentCompanionStartsAssociatedStation() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let player = FakeMusicPlayer()
        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.44, y: 0.62),
                    companion: .moonMoth
                )
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: player
        )
        let hitPoint = try #require(canvasView.musicButtonHitPointForSelfTest())

        #expect(canvasView.beginGardenInteraction(at: hitPoint) == .drag)
        #expect(canvasView.endPlantDrag())
        #expect(player.toggleCount == 1)
        #expect(player.toggledStations == [.ambientRadio])
        #expect(player.playCount == 1)
        #expect(player.playedStations == [.ambientRadio])
    }

    @Test("clicking the playing radio companion again stops its station")
    func clickingPlayingRadioCompanionAgainStopsItsStation() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let player = FakeMusicPlayer()
        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.44, y: 0.62),
                    companion: .tinyRocket
                )
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: player
        )
        let hitPoint = try #require(canvasView.musicButtonHitPointForSelfTest())

        #expect(canvasView.beginGardenInteraction(at: hitPoint) == .drag)
        #expect(canvasView.endPlantDrag())
        #expect(player.isPlaying)
        #expect(player.playingRadioStation == .spaceDogs)

        #expect(canvasView.beginGardenInteraction(at: hitPoint) == .drag)
        #expect(canvasView.endPlantDrag())

        #expect(player.toggleCount == 2)
        #expect(player.toggledStations == [.spaceDogs, .spaceDogs])
        #expect(player.playCount == 1)
        #expect(player.stopCount == 1)
        #expect(!player.isPlaying)
        #expect(player.playingRadioStation == nil)
    }

    @Test("double-click radio activation ignores single clicks")
    func doubleClickRadioActivationIgnoresSingleClicks() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let player = FakeMusicPlayer()
        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.44, y: 0.62),
                    companion: .moonMoth
                ),
                settings: GardenSettings.default.updating(radioActivationMode: .doubleClick)
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: player
        )
        let hitPoint = try #require(canvasView.musicButtonHitPointForSelfTest())

        #expect(canvasView.beginGardenInteraction(at: hitPoint, clickCount: 1) == .drag)
        #expect(canvasView.endPlantDrag())
        #expect(player.toggleCount == 0)

        #expect(canvasView.beginGardenInteraction(at: hitPoint, clickCount: 2) == .drag)
        #expect(canvasView.endPlantDrag())
        #expect(player.toggleCount == 1)
        #expect(player.toggledStations == [.ambientRadio])
    }

    @Test("disabled radio activation suppresses companion playback")
    func disabledRadioActivationSuppressesCompanionPlayback() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let player = FakeMusicPlayer()
        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.44, y: 0.62),
                    companion: .toyDelorean
                ),
                settings: GardenSettings.default.updating(radioActivationMode: .disabled)
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: player
        )
        let hitPoint = try #require(canvasView.musicButtonHitPointForSelfTest())

        #expect(canvasView.beginGardenInteraction(at: hitPoint) == .drag)
        #expect(canvasView.endPlantDrag())
        #expect(player.toggleCount == 0)
        #expect(player.playCount == 0)
        #expect(!player.isPlaying)
    }

    @Test("clicking companion switches from the previous station")
    func clickingCompanionSwitchesFromPreviousStation() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let player = FakeMusicPlayer()
        player.playRadioStation(.ambientRadio)
        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.44, y: 0.62),
                    companion: .brassFrog
                )
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: player
        )
        let hitPoint = try #require(canvasView.musicButtonHitPointForSelfTest())

        #expect(canvasView.visibleMusicButtonCompanion() == .brassFrog)
        #expect(canvasView.beginGardenInteraction(at: hitPoint) == .drag)
        #expect(canvasView.endPlantDrag())

        #expect(player.toggleCount == 1)
        #expect(player.toggledStations == [.jazzDeVilleGroove])
        #expect(player.playedStations == [.ambientRadio, .jazzDeVilleGroove])
        #expect(player.playingRadioStation == .jazzDeVilleGroove)
        #expect(player.isPlaying)
    }

    @Test("multiple radio companions keep independent positions and stations")
    func multipleRadioCompanionsKeepIndependentPositionsAndStations() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let player = FakeMusicPlayer()
        let store = GardenStore(
            state: GardenState(
                musicButtons: [
                    GardenMusicButton(
                        screenIndex: 0,
                        position: GardenPoint(x: 0.30, y: 0.50),
                        companion: .moonMoth
                    ),
                    GardenMusicButton(
                        screenIndex: 0,
                        position: GardenPoint(x: 0.70, y: 0.50),
                        companion: .toyDelorean
                    )
                ]
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: player
        )
        let rects = canvasView.musicButtonRects()
        let secondHitPoint = try #require(rects.first { $0.index == 1 }.map { NSPoint(x: $0.rect.midX, y: $0.rect.midY) })

        #expect(canvasView.beginGardenInteraction(at: secondHitPoint) == .drag)
        #expect(canvasView.endPlantDrag())
        #expect(player.toggleCount == 1)
        #expect(player.toggledStations == [.eightiesForever])
        #expect(player.playedStations == [.eightiesForever])

        #expect(canvasView.beginGardenInteraction(at: secondHitPoint) == .drag)
        #expect(canvasView.continuePlantDrag(at: NSPoint(x: secondHitPoint.x + 90, y: secondHitPoint.y)))
        #expect(canvasView.endPlantDrag())

        #expect(store.state.musicButtons[0].position == GardenPoint(x: 0.30, y: 0.50))
        #expect(store.state.musicButtons[1].position.x > 0.75)
        #expect(store.state.musicButtons[1].companion == .toyDelorean)
    }

    @Test("radio companion size setting scales render and hit rects")
    func radioCompanionSizeSettingScalesRenderAndHitRects() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.50, y: 0.50),
                    companion: .miniUfoTerrarium
                ),
                settings: GardenSettings.default.updating(radioCompanionScale: 1.50)
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: FakeMusicPlayer()
        )

        let rect = try #require(canvasView.musicButtonRect())
        let hitRect = try #require(canvasView.musicButtonInteractionRect())
        let expectedSize = GardenCanvasView.musicButtonSize * 1.50

        #expect(abs(rect.width - expectedSize) < 0.001)
        #expect(abs(rect.height - expectedSize) < 0.001)
        #expect(hitRect.width == rect.width + GardenCanvasView.musicButtonHitOutset * 2)
        #expect(hitRect.height == rect.height + GardenCanvasView.musicButtonHitOutset * 2)
    }

    @Test("radio companion hover enlarges after sustained attention")
    func radioCompanionHoverEnlargesAfterSustainedAttention() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.50, y: 0.50),
                    companion: .moonMoth
                )
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: FakeMusicPlayer()
        )
        let hitPoint = try #require(canvasView.musicButtonHitPointForSelfTest())
        let start = Date(timeIntervalSinceReferenceDate: 100)

        canvasView.updateMusicButtonHover(at: hitPoint, now: start)
        let baseRect = try #require(canvasView.musicButtonRect())
        let earlyRect = try #require(canvasView.musicButtonVisualRects(now: start.addingTimeInterval(2.95)).first?.rect)
        let activeRect = try #require(canvasView.musicButtonVisualRects(now: start.addingTimeInterval(3.60)).first?.rect)

        #expect(abs(earlyRect.width - baseRect.width) < 0.001)
        #expect(activeRect.width > baseRect.width)
        #expect(activeRect.midX == baseRect.midX)
        #expect(activeRect.midY == baseRect.midY)
    }

    @Test("radio companion hover accepts desktop coordinate candidates")
    func radioCompanionHoverAcceptsDesktopCoordinateCandidates() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.50, y: 0.50),
                    companion: .moonMoth
                )
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: FakeMusicPlayer()
        )
        let hitPoint = try #require(canvasView.musicButtonHitPointForSelfTest())
        let missPoint = NSPoint(x: 12, y: 12)
        let start = Date(timeIntervalSinceReferenceDate: 300)

        canvasView.updateMusicButtonHover(at: [missPoint, hitPoint], now: start)
        #expect(canvasView.musicButtonHoverState?.buttonIndex == 0)

        let activeRect = try #require(canvasView.musicButtonVisualRects(now: start.addingTimeInterval(3.60)).first?.rect)
        let baseRect = try #require(canvasView.musicButtonRect())
        #expect(activeRect.width > baseRect.width)

        canvasView.updateMusicButtonHover(at: [missPoint], now: start.addingTimeInterval(3.70))
        #expect(canvasView.musicButtonHoverState == nil)
    }

    @Test("radio companion blocks cat chat routing")
    func radioCompanionBlocksCatChatRouting() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.50, y: 0.50),
                    companion: .gardenCat
                )
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: FakeMusicPlayer()
        )
        let hitPoint = try #require(canvasView.musicButtonHitPointForSelfTest())

        #expect(canvasView.containsCatChatBlockingElement(at: hitPoint))
        #expect(canvasView.containsInteractiveElement(at: hitPoint))
    }

    @Test("ordinary plant art does not block cat chat routing")
    func ordinaryPlantArtDoesNotBlockCatChatRouting() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = GardenStore(
            state: GardenState(
                plants: [
                    Plant(
                        species: .monstera,
                        screenIndex: 0,
                        position: GardenPoint(x: 0.50, y: 0.62),
                        growth: 1,
                        health: 1,
                        scale: 1.2
                    )
                ]
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: FakeMusicPlayer()
        )
        let point = NSPoint(x: 450, y: 700 * 0.62)

        #expect(!canvasView.containsCatChatBlockingElement(at: point))
    }

    @Test("radio companion hover aura requires matching playing station")
    func radioCompanionHoverAuraRequiresMatchingPlayingStation() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let player = FakeMusicPlayer()
        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.50, y: 0.50),
                    companion: .toyDelorean
                )
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: player
        )
        let hitPoint = try #require(canvasView.musicButtonHitPointForSelfTest())
        let start = Date(timeIntervalSinceReferenceDate: 200)
        let activeDate = start.addingTimeInterval(3.50)

        canvasView.updateMusicButtonHover(at: hitPoint, now: start)
        #expect(!canvasView.shouldDrawMusicButtonHoverSignal(for: 0, companion: .toyDelorean, now: activeDate))

        player.playRadioStation(.ambientRadio)
        #expect(!canvasView.shouldDrawMusicButtonHoverSignal(for: 0, companion: .toyDelorean, now: activeDate))

        player.playRadioStation(.eightiesForever)
        #expect(canvasView.shouldDrawMusicButtonHoverSignal(for: 0, companion: .toyDelorean, now: activeDate))
    }

    @Test("dragging radio companion moves without starting radio")
    func draggingRadioCompanionMovesWithoutStartingRadio() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let player = FakeMusicPlayer()
        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.44, y: 0.62),
                    companion: .brassFrog
                )
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            screenIndex: 0,
            store: store,
            musicPlayer: player
        )
        let hitPoint = try #require(canvasView.musicButtonHitPointForSelfTest())

        #expect(canvasView.beginGardenInteraction(at: hitPoint) == .drag)
        #expect(canvasView.continuePlantDrag(at: NSPoint(x: hitPoint.x + 90, y: hitPoint.y - 40)))
        #expect(canvasView.endPlantDrag())

        #expect(player.toggleCount == 0)
        let movedButton = try #require(store.state.musicButton)
        #expect(movedButton.position.x > 0.50)
        #expect(movedButton.position.y < 0.62)
        #expect(movedButton.companion == .brassFrog)
    }

    @Test("radio companion PNG renders without detached top shadow")
    func radioCompanionPNGRendersWithoutDetachedTopShadow() throws {
        let directoryURL = Self.temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let player = FakeMusicPlayer()
        let store = GardenStore(
            state: GardenState(
                musicButton: GardenMusicButton(
                    screenIndex: 0,
                    position: GardenPoint(x: 0.50, y: 0.50),
                    companion: .tinyRocket
                )
            ),
            persistence: GardenPersistence(directoryURL: directoryURL)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 180, height: 160),
            screenIndex: 0,
            store: store,
            musicPlayer: player
        )

        let image = NSImage(size: canvasView.bounds.size)
        image.lockFocusFlipped(true)
        NSColor.white.setFill()
        canvasView.bounds.fill()
        canvasView.drawMusicButtonIfNeeded()
        image.unlockFocus()

        let data = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: data))
        let rect = try #require(canvasView.musicButtonRect())
        let oldShadowBandSamples = [
            NSPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.10),
            NSPoint(x: rect.maxX - rect.width * 0.15, y: rect.minY + rect.height * 0.10)
        ]

        for point in oldShadowBandSamples {
            let color = try #require(bitmap.colorAt(x: Int(point.x.rounded()), y: Int(point.y.rounded()))?.usingColorSpace(.deviceRGB))
            let brightness = max(color.redComponent, color.greenComponent, color.blueComponent)

            #expect(brightness > 0.93, "Detached companion shadow should not darken the top band")
        }
    }

    private static func temporaryDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenMusicButtonInteractionTests-\(UUID().uuidString)", isDirectory: true)
    }
}

@MainActor
private final class FakeMusicPlayer: GardenMusicPlaybackControlling {
    private(set) var toggleCount = 0
    private(set) var playCount = 0
    private(set) var stopCount = 0
    private(set) var toggledStations: [GardenRadioStation] = []
    private(set) var playedStations: [GardenRadioStation] = []
    private(set) var openedSpotifyURLString: String?
    private(set) var isPlaying = false
    private(set) var playingRadioStation: GardenRadioStation?
    private(set) var playingRadioStream: GardenRadioStream?

    func playChillHopRadio() {
        playRadioStation(.chillHopByFluxFM)
    }

    func playRadioStation(_ station: GardenRadioStation) {
        playRadioStream(station.stream)
    }

    func playRadioStream(_ stream: GardenRadioStream) {
        playCount += 1
        if let station = stream.matchesBuiltInStation {
            playedStations.append(station)
        }
        playingRadioStation = stream.matchesBuiltInStation
        playingRadioStream = stream
        isPlaying = true
    }

    func playSpotify(using settings: GardenSettings) {
        playCount += 1
        openedSpotifyURLString = settings.spotifyLaunchURL.absoluteString
        playingRadioStation = nil
        playingRadioStream = nil
        isPlaying = true
    }

    func stop() {
        stopCount += 1
        playingRadioStation = nil
        playingRadioStream = nil
        isPlaying = false
    }

    func toggleChillHopRadio() {
        toggleRadioStation(.chillHopByFluxFM)
    }

    func toggleRadioStation(_ station: GardenRadioStation) {
        toggleRadioStream(station.stream)
    }

    func toggleRadioStream(_ stream: GardenRadioStream) {
        toggleCount += 1
        if let station = stream.matchesBuiltInStation {
            toggledStations.append(station)
        }
        if isPlaying, playingRadioStream?.id == stream.id {
            stop()
        } else {
            playRadioStream(stream)
        }
    }

    func toggleMusic(using settings: GardenSettings) {
        toggleCount += 1
        switch settings.musicSource {
        case .chillHopRadio:
            isPlaying ? stop() : playChillHopRadio()
        case .spotify:
            isPlaying ? stop() : playSpotify(using: settings)
        }
    }
}
