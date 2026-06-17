import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden radio companion")
struct GardenMusicButtonTests {
    @Test("radio companion catalog maps scene objects to stations")
    func radioCompanionCatalogMapsSceneObjectsToStations() {
        #expect(GardenRadioCompanion.allCases.count == 15)
        #expect(GardenRadioCompanion.gardenCat.station == .chillHopByFluxFM)
        #expect(GardenRadioCompanion.moonMoth.station == .ambientRadio)
        #expect(GardenRadioCompanion.mushroomSpeaker.station == .loungeRadio)
        #expect(GardenRadioCompanion.brassFrog.station == .jazzDeVilleGroove)
        #expect(GardenRadioCompanion.tinyRocket.station == .spaceDogs)
        #expect(GardenRadioCompanion.toyDelorean.station == .eightiesForever)
        #expect(GardenRadioCompanion.bigfootFieldRadio.station == .planetPootwaddle)
        #expect(GardenRadioCompanion.miniUfoTerrarium.station == .oneRadioSpace)
        #expect(GardenRadioCompanion.chillGardenGnome.station == .rootsLegacy)
        #expect(GardenRadioCompanion.greyAlienGardener.station == .intergalactic)
        #expect(GardenRadioCompanion.cassetteSamurai.station == .dkfmShoegaze)
        #expect(GardenRadioCompanion.sphinxPhonograph.station == .ancientFM)
        #expect(GardenRadioCompanion.dubNinjaBonsai.station == .dubNinja)
        #expect(GardenRadioCompanion.berlinBearSynth.station == .soundOfBerlin)
        #expect(GardenRadioCompanion.cinemaProjectorFirefly.station == .cinemix)
        #expect(GardenRadioCompanion.companion(for: .intergalactic) == .greyAlienGardener)
        #expect(GardenRadioCompanion.companion(for: .cinemix) == .cinemaProjectorFirefly)
    }

    @Test("radio stations expose Filtermusic pages and playable streams")
    func radioStationsExposeFiltermusicPagesAndPlayableStreams() {
        #expect(GardenRadioStation.allCases.count == 15)
        #expect(GardenRadioStation.chillHopByFluxFM.filtermusicURL.absoluteString == "https://filtermusic.net/chillhop-by-fluxfm")
        #expect(GardenRadioStation.chillHopByFluxFM.streamURLs.first?.absoluteString == "https://streams.fluxfm.de/Chillhop/mp3-128/streams.fluxfm.de")
        #expect(GardenRadioStation.ambientRadio.streamURLs.first?.absoluteString == "https://uk2.internet-radio.com/proxy/ambientradio?mp=/;")
        #expect(GardenRadioStation.spaceDogs.displayName == "Space dogs")
        #expect(GardenRadioStation.eightiesForever.filtermusicURL.absoluteString == "https://filtermusic.net/80s-forever")
        #expect(GardenRadioStation.eightiesForever.streamURLs.first?.absoluteString == "https://premium.shoutcastsolutions.com/radio/8050/256.mp3")
        #expect(GardenRadioStation.planetPootwaddle.streamURLs.map(\.absoluteString) == [
            "https://ppw.streamguys1.com/sgplayer-aac",
            "https://ppw.streamguys1.com/sgplayer-mp3"
        ])
        #expect(GardenRadioStation.oneRadioSpace.streamURLs.first?.absoluteString == "https://c22.radioboss.fm:18118/1RADIO.SPACE")
        #expect(GardenRadioStation.rootsLegacy.streamURLs.first?.absoluteString == "https://l.rootslegacy.fr/stream")
        #expect(GardenRadioStation.intergalactic.streamURLs.first?.absoluteString == "https://radio.intergalactic.fm/1")
        #expect(GardenRadioStation.dkfmShoegaze.filtermusicURL.absoluteString == "https://filtermusic.net/dkfm-shoegaze")
        #expect(GardenRadioStation.dkfmShoegaze.streamURLs.first?.absoluteString == "https://kathy.torontocast.com:2005/stream")
        #expect(GardenRadioStation.ancientFM.filtermusicURL.absoluteString == "https://filtermusic.net/ancientfm")
        #expect(GardenRadioStation.ancientFM.streamURLs.first?.absoluteString == "https://mediaserv73.live-streams.nl:18058/stream")
        #expect(GardenRadioStation.dubNinja.streamURLs.first?.absoluteString == "https://dub.ninja/live")
        #expect(GardenRadioStation.soundOfBerlin.streamURLs.first?.absoluteString == "https://fluxmusic.api.radiosphere.io/channels/sound-of-berlin/stream.aac")
        #expect(GardenRadioStation.cinemix.streamURLs.first?.absoluteString == "https://kathy.torontocast.com:1825/stream")
    }

    @Test("radio companion can be shown moved changed and hidden")
    func radioCompanionCanBeShownMovedChangedAndHidden() {
        let date = Date(timeIntervalSince1970: 2_000)
        let state = GardenState()

        let shownState = GardenEngine.showMusicButton(
            state,
            screenIndex: 2,
            position: GardenPoint(x: 1.2, y: -0.1),
            companion: .moonMoth,
            at: date
        )

        #expect(shownState.musicButton == GardenMusicButton(
            screenIndex: 2,
            position: GardenPoint(x: 1.0, y: 0.0),
            companion: .moonMoth
        ))
        #expect(shownState.lastUpdatedAt == date)

        let movedState = GardenEngine.moveMusicButton(
            shownState,
            to: GardenPoint(x: 0.34, y: 0.72),
            screenIndex: -3,
            at: date.addingTimeInterval(10)
        )

        #expect(movedState.musicButton == GardenMusicButton(
            screenIndex: 0,
            position: GardenPoint(x: 0.34, y: 0.72),
            companion: .moonMoth
        ))

        let changedCompanionState = GardenEngine.updateMusicButtonCompanion(
            movedState,
            companion: .tinyRocket,
            at: date.addingTimeInterval(15)
        )

        #expect(changedCompanionState.musicButton == GardenMusicButton(
            screenIndex: 0,
            position: GardenPoint(x: 0.34, y: 0.72),
            companion: .tinyRocket
        ))

        let hiddenState = GardenEngine.hideMusicButton(
            changedCompanionState,
            at: date.addingTimeInterval(20)
        )

        #expect(hiddenState.musicButton == nil)
    }

    @Test("screen constraint keeps radio companion on visible display")
    func screenConstraintKeepsRadioCompanionOnVisibleDisplay() {
        let state = GardenState(
            musicButtons: [
                GardenMusicButton(
                    screenIndex: 4,
                    position: GardenPoint(x: 0.40, y: 0.66),
                    companion: .brassFrog
                ),
                GardenMusicButton(
                    screenIndex: 3,
                    position: GardenPoint(x: 0.30, y: 0.44),
                    companion: .toyDelorean
                )
            ]
        )

        let constrainedState = GardenEngine.constrainPlantsToScreenCount(
            state,
            screenCount: 2
        )

        #expect(constrainedState.musicButton?.screenIndex == 0)
        #expect(constrainedState.musicButton?.position == GardenPoint(x: 0.40, y: 0.66))
        #expect(constrainedState.musicButton?.companion == .brassFrog)
        #expect(constrainedState.musicButtons[1].screenIndex == 1)
        #expect(constrainedState.musicButtons[1].companion == .toyDelorean)
    }

    @Test("radio companions can be added independently")
    func radioCompanionsCanBeAddedIndependently() {
        let state = GardenState()
        let firstState = GardenEngine.addMusicButton(
            state,
            screenIndex: 0,
            position: GardenPoint(x: 0.25, y: 0.40),
            companion: .moonMoth
        )
        let secondState = GardenEngine.addMusicButton(
            firstState,
            screenIndex: 0,
            position: GardenPoint(x: 0.75, y: 0.40),
            companion: .toyDelorean
        )

        #expect(secondState.musicButtons.map(\.companion) == [.moonMoth, .toyDelorean])
        #expect(secondState.musicButton?.companion == .moonMoth)

        let movedState = GardenEngine.moveMusicButton(
            secondState,
            at: 1,
            to: GardenPoint(x: 0.80, y: 0.50),
            screenIndex: 0
        )

        #expect(movedState.musicButtons[0].position == GardenPoint(x: 0.25, y: 0.40))
        #expect(movedState.musicButtons[1].position == GardenPoint(x: 0.80, y: 0.50))
    }
}
