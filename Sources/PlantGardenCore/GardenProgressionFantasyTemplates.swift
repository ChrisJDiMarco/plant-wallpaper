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

/// Curated, intentionally over-the-top fantasy starting points. Mode-agnostic:
/// Progression Mode steers the generated wallpaper toward whatever fantasy is
/// described, so the same catalog works in Garden, Room Studio, and Alien modes.
public enum GardenProgressionFantasyTemplateCatalog {
    public static let all: [GardenProgressionFantasyTemplate] = [
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
}
