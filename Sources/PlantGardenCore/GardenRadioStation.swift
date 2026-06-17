import Foundation

public enum GardenRadioStation: String, Codable, CaseIterable, Sendable {
    case chillHopByFluxFM
    case ambientRadio
    case loungeRadio
    case jazzDeVilleGroove
    case spaceDogs
    case eightiesForever
    case planetPootwaddle
    case oneRadioSpace
    case rootsLegacy
    case intergalactic
    case dkfmShoegaze
    case ancientFM
    case dubNinja
    case soundOfBerlin
    case cinemix

    public var displayName: String {
        switch self {
        case .chillHopByFluxFM:
            "ChillHop by FluxFM"
        case .ambientRadio:
            "Ambient Radio"
        case .loungeRadio:
            "Lounge Radio"
        case .jazzDeVilleGroove:
            "Jazz de Ville Groove"
        case .spaceDogs:
            "Space dogs"
        case .eightiesForever:
            "80s Forever"
        case .planetPootwaddle:
            "Planet Pootwaddle"
        case .oneRadioSpace:
            "1 Radio Space"
        case .rootsLegacy:
            "Roots Legacy"
        case .intergalactic:
            "Intergalactic"
        case .dkfmShoegaze:
            "DKFM Shoegaze"
        case .ancientFM:
            "AncientFM"
        case .dubNinja:
            "Dub Ninja"
        case .soundOfBerlin:
            "Sound of Berlin"
        case .cinemix:
            "Cinemix"
        }
    }

    public var filtermusicSlug: String {
        switch self {
        case .chillHopByFluxFM:
            "chillhop-by-fluxfm"
        case .ambientRadio:
            "ambient-radio"
        case .loungeRadio:
            "lounge-radio"
        case .jazzDeVilleGroove:
            "jazz-de-ville-groove"
        case .spaceDogs:
            "space-dogs"
        case .eightiesForever:
            "80s-forever"
        case .planetPootwaddle:
            "planet-pootwaddle"
        case .oneRadioSpace:
            "1-radio-space"
        case .rootsLegacy:
            "roots-legacy"
        case .intergalactic:
            "intergalactic"
        case .dkfmShoegaze:
            "dkfm-shoegaze"
        case .ancientFM:
            "ancientfm"
        case .dubNinja:
            "dub-ninja"
        case .soundOfBerlin:
            "sound-of-berlin"
        case .cinemix:
            "cinemix"
        }
    }

    public var filtermusicURL: URL {
        URL(string: "https://filtermusic.net/\(filtermusicSlug)")!
    }

    public var streamURLs: [URL] {
        switch self {
        case .chillHopByFluxFM:
            [
                URL(string: "https://streams.fluxfm.de/Chillhop/mp3-128/streams.fluxfm.de")!
            ]
        case .ambientRadio:
            [
                URL(string: "https://uk2.internet-radio.com/proxy/ambientradio?mp=/;")!
            ]
        case .loungeRadio:
            [
                URL(string: "https://nl1.streamhosting.ch/lounge128.mp3")!
            ]
        case .jazzDeVilleGroove:
            [
                URL(string: "https://onair22.xdevel.com/proxy/xautocloud_1kha_423?mp=/stream")!
            ]
        case .spaceDogs:
            [
                URL(string: "https://listen2.streamaudio.co:8042/stream")!
            ]
        case .eightiesForever:
            [
                URL(string: "https://premium.shoutcastsolutions.com/radio/8050/256.mp3")!
            ]
        case .planetPootwaddle:
            [
                URL(string: "https://ppw.streamguys1.com/sgplayer-aac")!,
                URL(string: "https://ppw.streamguys1.com/sgplayer-mp3")!
            ]
        case .oneRadioSpace:
            [
                URL(string: "https://c22.radioboss.fm:18118/1RADIO.SPACE")!
            ]
        case .rootsLegacy:
            [
                URL(string: "https://l.rootslegacy.fr/stream")!
            ]
        case .intergalactic:
            [
                URL(string: "https://radio.intergalactic.fm/1")!
            ]
        case .dkfmShoegaze:
            [
                URL(string: "https://kathy.torontocast.com:2005/stream")!
            ]
        case .ancientFM:
            [
                URL(string: "https://mediaserv73.live-streams.nl:18058/stream")!
            ]
        case .dubNinja:
            [
                URL(string: "https://dub.ninja/live")!
            ]
        case .soundOfBerlin:
            [
                URL(string: "https://fluxmusic.api.radiosphere.io/channels/sound-of-berlin/stream.aac")!
            ]
        case .cinemix:
            [
                URL(string: "https://kathy.torontocast.com:1825/stream")!
            ]
        }
    }

    public var shortDescription: String {
        switch self {
        case .chillHopByFluxFM:
            "Neo-soul, lounge, trip-hop, and jazz at a relaxed pace."
        case .ambientRadio:
            "Deep, beautiful chillout and ambient sound."
        case .loungeRadio:
            "Downtempo, nujazz, and warm lounge beats."
        case .jazzDeVilleGroove:
            "Groove jazz with a relaxed garden pulse."
        case .spaceDogs:
            "Sci-fi pop, indie, disco, poptronica, and chilled vibes."
        case .eightiesForever:
            "Rare 1979-1990 synthpop and new wave with a time-machine glow."
        case .planetPootwaddle:
            "Classic rock and grown-up ear candy from a playful woodland signal."
        case .oneRadioSpace:
            "Deep, dub, tech, psy, and cosmic electronic focus music."
        case .rootsLegacy:
            "Quality dub and roots reggae for a mellow garden pulse."
        case .intergalactic:
            "Electro, minimal wave, and acid from a weird-smart orbit."
        case .dkfmShoegaze:
            "Shoegaze, dream pop, and hazy guitar clouds for soft-focus garden time."
        case .ancientFM:
            "Medieval, renaissance, and early music with candlelit courtyard calm."
        case .dubNinja:
            "Dub techno and deep echo pulses for a stealthy late-night garden."
        case .soundOfBerlin:
            "Berlin electronic culture: modern, kinetic, and polished."
        case .cinemix:
            "Cinematic scores and sweeping instrumental drama for a storybook garden."
        }
    }
}

public struct GardenRadioStream: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var streamURLStrings: [String]
    public var filtermusicPageURLString: String?
    public var shortDescription: String
    public var isBuiltIn: Bool

    public init(
        id: String,
        displayName: String,
        streamURLStrings: [String],
        filtermusicPageURLString: String? = nil,
        shortDescription: String = "",
        isBuiltIn: Bool = false
    ) {
        self.id = Self.normalizedID(id: id, displayName: displayName, streamURLStrings: streamURLStrings)
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.streamURLStrings = streamURLStrings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.filtermusicPageURLString = filtermusicPageURLString?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.shortDescription = shortDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isBuiltIn = isBuiltIn
    }

    public var streamURLs: [URL] {
        streamURLStrings.compactMap(URL.init(string:))
    }

    public var filtermusicPageURL: URL? {
        filtermusicPageURLString.flatMap(URL.init(string:))
    }

    public var matchesBuiltInStation: GardenRadioStation? {
        GardenRadioStation.allCases.first { $0.stream.id == id }
    }

    public static func filtermusic(
        slug: String,
        title: String,
        listenURLString: String,
        category: String = "",
        summary: String = ""
    ) -> GardenRadioStream {
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = [category, summary]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
        return GardenRadioStream(
            id: "filtermusic:\(trimmedSlug)",
            displayName: title,
            streamURLStrings: [listenURLString],
            filtermusicPageURLString: "https://filtermusic.net/\(trimmedSlug)",
            shortDescription: description,
            isBuiltIn: false
        )
    }

    private static func normalizedID(id: String, displayName: String, streamURLStrings: [String]) -> String {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedID.isEmpty {
            return trimmedID.lowercased()
        }

        if let firstStream = streamURLStrings.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           !firstStream.isEmpty {
            return "custom:\(firstStream.lowercased())"
        }

        let slug = displayName
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return "custom:\(slug)"
    }
}

public extension GardenRadioStation {
    var stream: GardenRadioStream {
        GardenRadioStream(
            id: "built-in:\(rawValue)",
            displayName: displayName,
            streamURLStrings: streamURLs.map(\.absoluteString),
            filtermusicPageURLString: filtermusicURL.absoluteString,
            shortDescription: shortDescription,
            isBuiltIn: true
        )
    }
}

public enum GardenRadioCompanion: String, Codable, CaseIterable, Sendable {
    case gardenCat
    case moonMoth
    case mushroomSpeaker
    case brassFrog
    case tinyRocket
    case toyDelorean
    case bigfootFieldRadio
    case miniUfoTerrarium
    case chillGardenGnome
    case greyAlienGardener
    case cassetteSamurai
    case sphinxPhonograph
    case dubNinjaBonsai
    case berlinBearSynth
    case cinemaProjectorFirefly

    public var displayName: String {
        switch self {
        case .gardenCat:
            "Garden Cat"
        case .moonMoth:
            "Moon Moth"
        case .mushroomSpeaker:
            "Mushroom Speaker"
        case .brassFrog:
            "Brass Frog"
        case .tinyRocket:
            "Tiny Rocket"
        case .toyDelorean:
            "Toy DeLorean"
        case .bigfootFieldRadio:
            "Bigfoot Field Radio"
        case .miniUfoTerrarium:
            "Mini UFO Terrarium"
        case .chillGardenGnome:
            "Chill Garden Gnome"
        case .greyAlienGardener:
            "Grey Alien Gardener"
        case .cassetteSamurai:
            "Cassette Samurai"
        case .sphinxPhonograph:
            "Sphinx Phonograph"
        case .dubNinjaBonsai:
            "Dub Ninja Bonsai"
        case .berlinBearSynth:
            "Berlin Bear Synth"
        case .cinemaProjectorFirefly:
            "Cinema Projector Firefly"
        }
    }

    public var station: GardenRadioStation {
        switch self {
        case .gardenCat:
            .chillHopByFluxFM
        case .moonMoth:
            .ambientRadio
        case .mushroomSpeaker:
            .loungeRadio
        case .brassFrog:
            .jazzDeVilleGroove
        case .tinyRocket:
            .spaceDogs
        case .toyDelorean:
            .eightiesForever
        case .bigfootFieldRadio:
            .planetPootwaddle
        case .miniUfoTerrarium:
            .oneRadioSpace
        case .chillGardenGnome:
            .rootsLegacy
        case .greyAlienGardener:
            .intergalactic
        case .cassetteSamurai:
            .dkfmShoegaze
        case .sphinxPhonograph:
            .ancientFM
        case .dubNinjaBonsai:
            .dubNinja
        case .berlinBearSynth:
            .soundOfBerlin
        case .cinemaProjectorFirefly:
            .cinemix
        }
    }

    public static func companion(for station: GardenRadioStation) -> GardenRadioCompanion {
        allCases.first { $0.station == station } ?? .gardenCat
    }

    public func stationStream(in settings: GardenSettings) -> GardenRadioStream {
        settings.radioCompanionStationOverrides[rawValue] ?? station.stream
    }

    public var menuTitle: String {
        "\(displayName) - \(station.displayName)"
    }

    public var placementSummary: String {
        "Click \(displayName) to play \(station.displayName). Drag to place it in the scene."
    }
}
