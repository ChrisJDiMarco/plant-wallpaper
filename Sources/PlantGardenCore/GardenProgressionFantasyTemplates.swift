import Foundation

/// A one-click starting point for Progression Mode. Clicking a template fills
/// every fantasy-profile field at once so people can launch a scene's 20-level
/// ladder without having to write an answer for each prompt themselves.
public struct GardenProgressionFantasyTemplate: Equatable, Sendable, Identifiable {
    public let id: String
    public let emoji: String
    public let title: String
    public let profile: GardenProgressionProfile

    public init(
        id: String,
        emoji: String,
        title: String,
        profile: GardenProgressionProfile
    ) {
        self.id = id
        self.emoji = emoji
        self.title = title
        self.profile = profile
    }

    /// "💻 Tech Millionaire" — emoji + short name for a clickable chip button.
    public var chipLabel: String {
        "\(emoji) \(title)"
    }
}

/// Curated, intentionally over-the-top fantasy starting points. Garden mode gets
/// plant-person personas; non-garden modes keep the broader lifestyle catalog.
public enum GardenProgressionFantasyTemplateCatalog {
    public static func templates(for mode: GardenExperienceMode) -> [GardenProgressionFantasyTemplate] {
        switch mode {
        case .garden, .rainforest:
            gardenTemplates
        case .roomStudio, .alienUFO:
            personaTemplates
        }
    }

    public static let gardenTemplates: [GardenProgressionFantasyTemplate] = [
        GardenProgressionFantasyTemplate(
            id: "rooftop-botanist-nyc",
            emoji: "🌱",
            title: "Rooftop Botanist",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Obsessive rooftop botanist building a rare-plant sky garden from scavenged planters into a glassy penthouse conservatory",
                placeInWorld: "Dense New York City rooftop, windy and sunlit between brick towers",
                ageBracket: "Early 30s, self-taught plant obsessive",
                vibe: "Urban, clever, handmade, then increasingly sleek and architectural",
                avoidList: "Suburban lawns, generic flower beds, fake plastic plants"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "cottage-herbalist",
            emoji: "🌿",
            title: "Cottage Herbalist",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Village herbalist growing medicinal beds, drying racks, and a storybook apothecary garden",
                placeInWorld: "Mossy cottage edge in the English Cotswolds",
                ageBracket: "Late 40s, practical and wise",
                vibe: "Handmade, earthy, fragrant, misty morning calm",
                avoidList: "Modern luxury, neon, sterile minimalism"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "orchid-collector-singapore",
            emoji: "🌺",
            title: "Orchid Collector",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "World-class orchid collector growing from cheap shade cloth benches to a museum-grade tropical orchid house",
                placeInWorld: "Humid Singapore garden terrace",
                ageBracket: "50s, patient collector with elite taste",
                vibe: "Tropical, precise, lush, jewel-toned, humid greenhouse glow",
                avoidList: "Dry desert plants, rustic farm clutter"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "desert-xeriscape-artist",
            emoji: "🏜️",
            title: "Desert Xeriscaper",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Desert garden artist turning a rough gravel patch into a sculptural cactus and agave estate",
                placeInWorld: "Sonoran Desert outside Tucson, Arizona",
                ageBracket: "Late 30s, minimalist maker",
                vibe: "Sun-baked, sculptural, quiet, stone-and-shadow luxury",
                avoidList: "Lush lawns, tropical humidity, fussy flowers"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "bonsai-master-kyoto",
            emoji: "🍃",
            title: "Bonsai Master",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Bonsai master raising a humble bench of saplings into a serene private collection garden",
                placeInWorld: "Quiet Kyoto courtyard near old temple lanes",
                ageBracket: "Timeless elder, disciplined and serene",
                vibe: "Raked gravel, aged wood, moss, restraint, soft dawn light",
                avoidList: "Clutter, loud colors, futuristic technology"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "community-garden-founder",
            emoji: "🥕",
            title: "Garden Founder",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Community garden founder growing a neglected lot into a thriving edible neighborhood oasis",
                placeInWorld: "Brooklyn side street between brownstones",
                ageBracket: "Mid 20s, scrappy organizer",
                vibe: "Hopeful, colorful, handmade, social, practical abundance",
                avoidList: "Private palace vibes, sterile perfection"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "tropical-food-forest-grower",
            emoji: "🥭",
            title: "Food Forest Grower",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Permaculture grower turning bare tropical soil into a layered food forest retreat",
                placeInWorld: "Rainy hillside in Costa Rica",
                ageBracket: "Early 40s, off-grid experimenter",
                vibe: "Abundant, steamy, practical, wild-edged, sun after rain",
                avoidList: "Manicured lawns, cold climates, sterile hardscape"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "old-money-rosarian",
            emoji: "🌹",
            title: "Old-Money Rosarian",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Old-money rosarian restoring a forgotten rose walk into an aristocratic bloom garden",
                placeInWorld: "Hamptons coastal manor grounds",
                ageBracket: "60s, elegant and unhurried",
                vibe: "Romantic, restrained, fragrant, pale stone, soft coastal light",
                avoidList: "Neon, synthetic materials, messy vegetable plots"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "rainforest-ethnobotanist",
            emoji: "🌳",
            title: "Ethnobotanist",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Rainforest ethnobotanist cultivating medicinal specimens beside a remote research hut",
                placeInWorld: "Upper Amazon rainforest research station",
                ageBracket: "Mid 30s, field scientist",
                vibe: "Dense, humid, scientific, respectful, firefly-and-mist atmosphere",
                avoidList: "Concrete city settings, flashy wealth"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "alpine-wildflower-keeper",
            emoji: "🏔️",
            title: "Alpine Wildflower",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Alpine wildflower keeper growing a tiny mountain plot into a rare high-altitude botanical refuge",
                placeInWorld: "Swiss alpine village above a glacier valley",
                ageBracket: "Late 50s, quiet mountain expert",
                vibe: "Crisp air, stone paths, meadow color, snow peaks, clean morning light",
                avoidList: "Tropical plants, urban grit, dark interiors"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "mediterranean-patio-gardener",
            emoji: "🫒",
            title: "Patio Gardener",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Mediterranean patio gardener turning cracked pots into a terraced citrus, olive, and herb sanctuary",
                placeInWorld: "Whitewashed hillside village on the Amalfi Coast",
                ageBracket: "30s, sun-loving host",
                vibe: "Terracotta, citrus leaves, sea air, linen, warm evening meals",
                avoidList: "Cold grey weather, corporate modernism"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "neon-rooftop-plant-hacker",
            emoji: "🌃",
            title: "Plant Hacker",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Cyberpunk plant hacker growing illegal bioluminescent seedlings from a cardboard rooftop setup into a neon botanical lab",
                placeInWorld: "Rain-slick Neo-Tokyo rooftop above a dense megacity",
                ageBracket: "Mid 20s, broke but brilliant",
                vibe: "Improvised, rain-glowing, neon pink-and-cyan, botanical street tech",
                avoidList: "Pastoral countryside, daylight softness, polished corporate labs"
            )
        )
    ]

    public static let personaTemplates: [GardenProgressionFantasyTemplate] = [
        GardenProgressionFantasyTemplate(
            id: "tech-millionaire-nyc",
            emoji: "💻",
            title: "Tech Millionaire",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Self-made software millionaire with a sleek penthouse terrace garden full of rare imported plants",
                placeInWorld: "Downtown Manhattan, New York City",
                ageBracket: "Early 30s, just exited a startup",
                vibe: "Warm minimal, smart-home tech, floor-to-ceiling glass, golden-hour city light",
                avoidList: "Clutter, anything cheap or dated"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "modern-finance-bro",
            emoji: "📈",
            title: "Finance Bro",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "High-rolling hedge-fund trader flexing a rooftop garden with imported palms and a champagne lounge",
                placeInWorld: "Miami waterfront high-rise, South Beach",
                ageBracket: "Late 20s, aggressively ambitious",
                vibe: "Glossy luxury, marble, neon sunset, exotic supercar energy",
                avoidList: "Anything modest, rustic, or understated"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "intergalactic-warlord",
            emoji: "🛸",
            title: "Galactic Warlord",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Feared galactic warlord cultivating a bio-engineered war garden aboard a conquered mothership",
                placeInWorld: "Orbiting a ringed gas giant in deep space",
                ageBracket: "Ageless, centuries-old conqueror",
                vibe: "Dark chrome, bioluminescent alien flora, ominous purple nebula light",
                avoidList: "Earth plants, soft pastels, anything peaceful"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "amazon-tribal-chief",
            emoji: "🌿",
            title: "Amazon Chief",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Powerful tribal chief whose sacred jungle garden overflows with medicinal plants and ancient totems",
                placeInWorld: "Deep in the ancient Amazon rainforest",
                ageBracket: "Wise elder, decades of leadership",
                vibe: "Lush emerald canopy, carved wood, fire-lit ceremony, mist and birdsong",
                avoidList: "Modern technology, concrete, anything industrial"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "80s-rock-star",
            emoji: "🎸",
            title: "'80s Rock Star",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Stadium-filling rock legend with a wild backstage garden of neon cacti and a tour-bus jungle",
                placeInWorld: "The Sunset Strip, Los Angeles",
                ageBracket: "Late 20s at the peak of fame",
                vibe: "Neon lights, leather, hairspray excess, smoky magenta-and-teal glow",
                avoidList: "Anything quiet, corporate, or wholesome"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "1920s-gangster",
            emoji: "🕴️",
            title: "1920s Gangster",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Prohibition-era crime boss with a hidden speakeasy courtyard garden behind the jazz club",
                placeInWorld: "Chicago, 1920s",
                ageBracket: "Mid 40s, ruthless and established",
                vibe: "Art deco, dim gold light, cigar smoke, pinstripe noir glamour",
                avoidList: "Modern items, bright daylight, anything cheerful"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "old-money-heir",
            emoji: "🏰",
            title: "Old-Money Heir",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Heir to a centuries-old fortune tending a manicured manor garden with hedge mazes and fountains",
                placeInWorld: "The English Cotswolds countryside",
                ageBracket: "50s, old-money and unhurried",
                vibe: "Quiet aristocratic elegance, topiary, stone, misty morning light",
                avoidList: "Anything flashy, new-money, or loud"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "tokyo-cyberpunk",
            emoji: "🌃",
            title: "Tokyo Cyberpunk",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Underground netrunner with a rooftop garden of glowing synthetic plants above the neon megacity",
                placeInWorld: "Neo-Tokyo, Japan",
                ageBracket: "Mid 20s, street-smart hacker",
                vibe: "Rain-slick neon, holograms, synthwave pink-and-cyan, dense urban night",
                avoidList: "Natural daylight, rural settings, anything analog"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "dubai-oil-billionaire",
            emoji: "🏜️",
            title: "Oil Billionaire",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Desert oil magnate with an opulent palace oasis garden, private falcons, and gold everywhere",
                placeInWorld: "Dubai, United Arab Emirates",
                ageBracket: "40s, dynastic wealth",
                vibe: "Gold and marble luxury, palm oasis, supercars, blazing desert sun",
                avoidList: "Anything modest, cold-climate, or run-down"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "golden-age-pirate",
            emoji: "☠️",
            title: "Pirate Captain",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Legendary pirate captain with a hidden island cove garden guarding buried treasure",
                placeInWorld: "A secret Caribbean cove, 1700s",
                ageBracket: "Late 30s, weathered and bold",
                vibe: "Tropical palms, shipwreck timber, golden treasure, sea-spray and torchlight",
                avoidList: "Modern boats, clean luxury, anything tidy or corporate"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "zen-mountain-monk",
            emoji: "⛩️",
            title: "Zen Monk",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Solitary monk cultivating a perfect meditation garden at a remote mountaintop temple",
                placeInWorld: "Misty peaks of the Japanese highlands",
                ageBracket: "Timeless, serene elder",
                vibe: "Raked gravel, moss, cherry blossom, soft dawn silence",
                avoidList: "Technology, bright colors, clutter, noise"
            )
        ),
        GardenProgressionFantasyTemplate(
            id: "viking-warlord",
            emoji: "🪓",
            title: "Viking Warlord",
            profile: GardenProgressionProfile(
                lifestyleFantasy: "Battle-hardened Norse warlord with a rugged longhouse garden of hardy herbs and runestones",
                placeInWorld: "A fjord in ancient Scandinavia",
                ageBracket: "40s, scarred and commanding",
                vibe: "Cold stone, furs, iron, storm-grey skies and firelight",
                avoidList: "Tropical plants, delicate decor, warm sunny ease"
            )
        )
    ]

    public static let all: [GardenProgressionFantasyTemplate] = gardenTemplates + personaTemplates
}
