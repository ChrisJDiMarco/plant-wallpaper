import Foundation
import PlantGardenCore

/// Small deterministic PRNG so a generation can be seeded for tests yet fully
/// random in production. SplitMix64 — fast, good distribution, no dependencies.
struct ProgressionPromptRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Builds the master prompt sent to OpenAI for each Progression Mode level.
///
/// Two things matter and the old prompt missed both: (1) every concrete detail
/// must bend to the chosen fantasy profile — the level only sets *how grand*,
/// the fantasy sets *what it looks like* — and (2) each generation must be a
/// fresh, clever interpretation rather than the same boilerplate every time.
/// A per-call random seed rotates a distinct set of creative beats so re-rolls
/// and new levels never feel like the same prompt twice.
enum WallpaperProgressionPrompt {
    static func masterPrompt(
        progression: GardenSceneProgression,
        targetLevel: Int,
        experienceMode: GardenExperienceMode,
        seed: UInt64 = .random(in: UInt64.min ... UInt64.max)
    ) -> String {
        let safeLevel = GardenSceneProgression.clampedLevel(targetLevel)
        let title = GardenSceneProgression.title(for: safeLevel, experienceMode: experienceMode)
        let profile = progression.profile
        let stageScale = stageScale(for: safeLevel, experienceMode: experienceMode)
        let placementRule = placementRule(for: experienceMode)
        var rng = ProgressionPromptRNG(seed: seed)
        let creativeDirection = creativeDirection(forLevel: safeLevel, using: &rng)

        return """
        Recreate the attached current WallpaperGarden scene as the next chapter of a personal fantasy that levels up across 20 stages.

        The attached image is the source of truth. Keep the same camera angle, broad composition, perspective, scene identity, and desktop-wallpaper readability. Evolve the scene to Level \(safeLevel) of 20: \(title).

        The fantasy this scene is growing into:
        - Lifestyle direction: \(profile.lifestyleFantasy)
        - Place in the world / climate / culture: \(profile.placeInWorld)
        - Age bracket or life stage: \(profile.ageBracket)
        - Vibe and taste: \(profile.vibe)
        - Avoid: \(profile.avoidList.isEmpty ? "nothing extra specified" : profile.avoidList)

        Theme is everything: reinterpret every surface, material, structure, prop, plant, and color so it authentically belongs to this exact fantasy, place, culture, era, and vibe. The level only sets how grand things are; the fantasy sets what they look like. Reject anything generic — commit fully to the world above.

        Level scale (use only as a luxury/grandeur gauge, then translate it entirely into the fantasy):
        \(stageScale)

        \(creativeDirection)

        Progression rules:
        - Make this feel like a natural next stage from the current image, not an unrelated replacement — but make THIS pass a distinct, clever, fresh interpretation, never the same formulaic upgrade.
        - Increase quality, scale, materials, comfort, architecture, lighting polish, and aspirational lifestyle detail only as much as Level \(safeLevel) warrants.
        - Level 1 should feel bare-bones and beginner; Level 20 should feel almost absurdly luxurious — a legendary, billionaire/sultan/lord-scale version of this specific fantasy.
        - Do not add text, labels, logos, watermarks, app UI, people, desktop icons, Dock, menu bar, or visible computer interface artifacts.
        - \(placementRule)

        Output a polished, realistic Mac desktop wallpaper that still works as an interactive WallpaperGarden/Room Studio canvas.
        """
    }

    /// One unique set of creative beats per generation. Drawn with the seeded
    /// RNG so the same seed reproduces the prompt (testable) while production's
    /// random seed makes every level and every re-roll its own interpretation.
    private static func creativeDirection(
        forLevel level: Int,
        using rng: inout ProgressionPromptRNG
    ) -> String {
        let signature = signatureMoves.randomElement(using: &rng) ?? signatureMoves[0]
        let lighting = lightingMoods.randomElement(using: &rng) ?? lightingMoods[0]
        let atmosphere = atmospheres.randomElement(using: &rng) ?? atmospheres[0]
        let material = materialMotifs.randomElement(using: &rng) ?? materialMotifs[0]
        let composition = compositions.randomElement(using: &rng) ?? compositions[0]

        return """
        Creative direction for THIS generation (a one-of-a-kind take — never a rote repeat of the last level):
        - Signature move for Level \(level): \(signature)
        - Lighting & time of day: \(lighting)
        - Atmosphere: \(atmosphere)
        - Material & texture focus: \(material)
        - Composition emphasis: \(composition)
        Lean into these choices boldly and let them, plus the fantasy above, make this level visibly its own moment.
        """
    }

    private static let signatureMoves = [
        "introduce one bold new centerpiece that becomes the unmistakable focal point",
        "add a prized status object the owner would show off at this exact stage",
        "work in a striking architectural upgrade that reshapes the scene's silhouette",
        "feature a dramatic water, fire, or light element as the hero detail",
        "add an inviting gathering or lounge spot that hints at how they live here",
        "reveal a rare collected treasure that signals how far they have climbed",
        "hint at a prized vehicle, vessel, or mount resting somewhere in the scene",
        "showcase an exotic, hard-to-source material or specimen as the showpiece",
        "carve out a private signature ritual space unique to this fantasy",
        "stage a seasonal or ceremonial moment that fits the world and era"
    ]

    private static let lightingMoods = [
        "golden-hour warmth with long cinematic shadows",
        "moody blue-hour dusk with glowing accent lighting",
        "crisp bright early morning with fresh, clean light",
        "a dramatic night scene lit by designed artificial light",
        "soft overcast light with gentle, diffused atmosphere",
        "post-rain glow with wet, reflective surfaces",
        "misty dawn with low fog and rising light",
        "high-noon clarity with bold, confident contrast"
    ]

    private static let atmospheres = [
        "serene and quietly confident",
        "bold, powerful, and commanding",
        "opulent, indulgent, and lavish",
        "mysterious, dramatic, and moody",
        "vibrant, alive, and energetic",
        "refined, understated, and tasteful",
        "warm, welcoming, and lived-in",
        "epic, awe-inspiring, and cinematic"
    ]

    private static let materialMotifs = [
        "reflective glass and polished metal",
        "natural stone and richly aged wood",
        "lush layered greenery and organic texture",
        "sumptuous fabrics and warm textiles",
        "mirror-like water and reflective pools",
        "precious metals and gemstone-like accents",
        "weathered, characterful patina and craft detail",
        "sleek engineered surfaces and clean lines"
    ]

    private static let compositions = [
        "a powerful foreground centerpiece with deep layered space behind it",
        "a sweeping, layered background vista that adds grandeur",
        "an elegant symmetrical, formal arrangement",
        "an inviting diagonal path that leads the eye inward",
        "a cozy, intimate focal nook within the wider scene",
        "a grand wide establishing view that shows off the scale"
    ]

    private static func placementRule(for experienceMode: GardenExperienceMode) -> String {
        switch experienceMode {
        case .garden:
            "Preserve clean, believable planting zones where WallpaperGarden can overlay separate plants later. Do not fill every pot, bed, soil patch, planter, or open garden area with baked-in plants."
        case .roomStudio:
            "Preserve open walls, shelves, tabletops, floor corners, and usable negative space where Room Studio can overlay separate objects later. Do not clutter every surface with baked-in props."
        case .alienUFO:
            "Preserve strange but readable empty alien planting zones where Alien/UFO Garden can overlay separate exobiology plants later. Leave glowing planters, crater beds, hydroponic pods, and xenosoil basins empty."
        }
    }

    private static func stageScale(for level: Int, experienceMode: GardenExperienceMode) -> String {
        switch (experienceMode, level) {
        case (.garden, 1):
            "A humble beginner garden: small patch of prepared soil, simple borders, basic path, modest fence or wall, almost no luxury, quiet optimism."
        case (.garden, 2...4):
            "Early progress: tidier beds, a few better planters, simple irrigation details, nicer path materials, still modest and achievable."
        case (.garden, 5...8):
            "Designed garden: intentional hardscape, better lighting, custom planters, tasteful seating, improved architecture, still approachable."
        case (.garden, 9...12):
            "Private estate garden: stonework, water feature, pergola/orangery/terrace elements, richer materials, broader grounds, refined landscaping structure."
        case (.garden, 13...16):
            "Grand botanical grounds: layered terraces, greenhouse or pavilion, sculptural hardscape, estate-scale views, premium materials and dramatic lighting."
        case (.garden, 17...19):
            "Legendary estate: sprawling acreage, formal axes, rare materials, cinematic water and stonework, private garden wings, almost royal scale."
        case (.garden, 20):
            "Absurd endgame paradise: $50M+ world-class estate garden, palace-level terraces, sprawling grounds, sultan/lord fantasy scale, breathtaking but still realistic."
        case (.roomStudio, 1):
            "A bare beginner room: small dorm-like bedroom or first apartment room, plain walls, simple bed or seating, basic lighting, sparse but not depressing."
        case (.roomStudio, 2...4):
            "Cozy starter room: better bedding, a few personal touches, simple desk or lounge corner, more warmth, still budget-conscious."
        case (.roomStudio, 5...8):
            "Curated hangout: intentional furniture, better media setup, wall zones, texture, storage, soft lighting, confident personal style."
        case (.roomStudio, 9...12):
            "Designer apartment room: premium materials, built-ins, statement lighting, high-end media or wardrobe zones, more space and polish."
        case (.roomStudio, 13...16):
            "Luxury residence: expansive suite or lounge, custom millwork, artful surfaces, dramatic windows, refined furniture, sophisticated lighting."
        case (.roomStudio, 17...19):
            "Dream compound interior: mansion-scale hang room, private cinema/game/lounge wings implied, extravagant finishes, collector-level details."
        case (.roomStudio, 20):
            "Absurd endgame palace suite: billionaire/sultan-level bedroom/lounge, vast scale, astonishing materials, cinematic luxury, fantastical but coherent."
        case (.alienUFO, 1):
            "A bare crater plot: simple xenosoil patch, a few empty pod planters, low-tech field equipment, quiet first-contact botany energy."
        case (.alienUFO, 2...4):
            "First alien habitat: tidier crater beds, glowing irrigation conduits, small specimen stations, still modest and exploratory."
        case (.alienUFO, 5...8):
            "UFO botany lab: hovering lights, translucent grow pods, polished alien hardscape, more intentional planting chambers."
        case (.alienUFO, 9...12):
            "Exoplanet oasis: wider alien terrain, elegant biodome architecture, atmospheric sky detail, refined empty garden terraces."
        case (.alienUFO, 13...16):
            "Interstellar conservatory: grand glassy dome, exotic materials, layered xenogarden platforms, cinematic atmospheric lighting."
        case (.alienUFO, 17...19):
            "Galactic bio-dome estate: enormous alien botanical campus, luxury spacecraft architecture, planetary vistas, rare-material planters."
        case (.alienUFO, 20):
            "Supreme cosmic garden: absurdly lavish interstellar palace greenhouse, impossible-but-coherent alien estate scale, museum-grade bioarchitecture."
        default:
            "Balanced progression: make the scene slightly more polished, more spacious, more intentional, and more aspirational than the previous level."
        }
    }
}
