import Foundation
import PlantGardenCore

enum RoomObjectCategory: String, CaseIterable, Codable, Equatable {
    case wallDecor
    case softGoods
    case wardrobe
    case mediaTech
    case collectibles
    case loungeGear

    var displayName: String {
        switch self {
        case .wallDecor:
            "Wall Decor"
        case .softGoods:
            "Clothes & Soft Stuff"
        case .wardrobe:
            "Wardrobe"
        case .mediaTech:
            "Games & Tech"
        case .collectibles:
            "Collectibles & Toys"
        case .loungeGear:
            "Lounge Gear"
        }
    }

    var menuTitle: String {
        "Add \(displayName) Here"
    }

    var addNewTitle: String {
        "Add New \(displayName)..."
    }

    var symbolName: String {
        switch self {
        case .wallDecor:
            "photo.artframe"
        case .softGoods:
            "tshirt.fill"
        case .wardrobe:
            "hanger"
        case .mediaTech:
            "gamecontroller.fill"
        case .collectibles:
            "cube.transparent.fill"
        case .loungeGear:
            "sofa.fill"
        }
    }

    var fallbackPlantKind: PlantKind {
        switch self {
        case .wallDecor:
            .foliage
        case .softGoods, .loungeGear:
            .meadow
        case .wardrobe, .mediaTech, .collectibles:
            .foliage
        }
    }

    var starterDescription: String {
        switch self {
        case .wallDecor:
            "a framed concert poster, slightly glossy paper, designed to sit on a bedroom wall"
        case .softGoods:
            "a realistic casual pile of hoodies, jeans, and socks with believable fabric folds"
        case .wardrobe:
            "a compact open clothing rack with jackets, sneakers, and a few hanging shirts"
        case .mediaTech:
            "a retro game console stack with controllers, cartridges, cables, and soft LED glow"
        case .collectibles:
            "a shelf cluster of vinyl toys, action figures, model cars, and tiny display lights"
        case .loungeGear:
            "a cozy beanbag corner with a side table, lamp, ashtray, and adult chill-room accessories"
        }
    }

    var promptGuidance: String {
        switch self {
        case .wallDecor:
            "flat or shallow wall-mounted object; preserve poster/frame plane, edge thickness, and wall contact"
        case .softGoods:
            "floor-level fabric object; emphasize cloth folds, gravity, soft contact shadows, and believable mess"
        case .wardrobe:
            "standing furniture-scale object; clear legs/base, fabric drape, and vertical silhouette"
        case .mediaTech:
            "floor, desk, or shelf tech prop; include readable forms without text or logos"
        case .collectibles:
            "small shelf or desk collectibles; clustered but clean silhouette, no copyrighted characters"
        case .loungeGear:
            "adult hangout-room prop; tasteful, object-focused, no people, no smoke, no brand logos"
        }
    }
}

struct RoomObjectTemplate: Equatable {
    var category: RoomObjectCategory
    var title: String
    var promptSeed: String
}

enum RoomStudioMenuCatalog {
    static let categoryOrder: [RoomObjectCategory] = [
        .wallDecor,
        .softGoods,
        .wardrobe,
        .mediaTech,
        .collectibles,
        .loungeGear
    ]

    static let templates: [RoomObjectTemplate] = [
        RoomObjectTemplate(category: .wallDecor, title: "Gig Poster Wall Frame", promptSeed: "a framed indie concert poster with aged black frame and subtle glossy paper"),
        RoomObjectTemplate(category: .wallDecor, title: "Skate Deck Wall Mount", promptSeed: "three mounted skateboard decks as wall decor, worn graphics, no readable brand text"),
        RoomObjectTemplate(category: .softGoods, title: "Laundry Chair Pile", promptSeed: "a chair almost buried under hoodies, jeans, and soft laundry folds"),
        RoomObjectTemplate(category: .softGoods, title: "Sneaker Spill", promptSeed: "a casual pile of sneakers, socks, and a gym bag on the floor"),
        RoomObjectTemplate(category: .wardrobe, title: "Open Clothing Rack", promptSeed: "a compact open clothes rack with jackets, shirts, sneakers, and a cap"),
        RoomObjectTemplate(category: .wardrobe, title: "Closet Cubby Stack", promptSeed: "stacked closet cubbies with folded clothes, shoes, and storage bins"),
        RoomObjectTemplate(category: .mediaTech, title: "Retro Console Stack", promptSeed: "stacked retro game consoles, controllers, cartridges, and coiled cables"),
        RoomObjectTemplate(category: .mediaTech, title: "Streaming Desk Setup", promptSeed: "a compact monitor, controller, keyboard, microphone, and LED desk clutter"),
        RoomObjectTemplate(category: .collectibles, title: "Toy Shelf Cluster", promptSeed: "a shelf cluster of vinyl toys, model cars, figures, and small display lamps"),
        RoomObjectTemplate(category: .collectibles, title: "Tabletop Game Hoard", promptSeed: "dice, cards, miniatures, and a half-built model kit arranged as a desk prop"),
        RoomObjectTemplate(category: .loungeGear, title: "Beanbag Chill Corner", promptSeed: "a cozy beanbag corner with side table, lamp, headphones, and snacks"),
        RoomObjectTemplate(category: .loungeGear, title: "Glass Lounge Rig", promptSeed: "a tasteful adult glass water pipe on a small tray with lighter and ashtray")
    ]

    static func templates(in category: RoomObjectCategory) -> [RoomObjectTemplate] {
        templates.filter { $0.category == category }
    }
}

struct RoomObjectPerspectiveContext: Codable, Equatable {
    var screenPosition: GardenPoint
    var surfaceHint: String
    var perspectiveHint: String

    static func inferred(from position: GardenPoint?) -> RoomObjectPerspectiveContext {
        let point = position ?? GardenPoint(x: 0.5, y: 0.70)
        let surfaceHint: String
        if point.y < 0.38 {
            surfaceHint = "upper wall or shelf zone"
        } else if point.y < 0.68 {
            surfaceHint = "mid-wall, desk, dresser, or bed-height zone"
        } else {
            surfaceHint = "floor or low furniture zone"
        }

        let horizontal = point.x < 0.33 ? "left side" : point.x > 0.67 ? "right side" : "center"
        let perspectiveHint = "Match the clicked placement area at normalized image point x \(String(format: "%.2f", point.x)), y \(String(format: "%.2f", point.y)); infer \(horizontal) room perspective, local wall/floor angle, horizon, scale, and contact shadows from the provided/current wallpaper."

        return RoomObjectPerspectiveContext(
            screenPosition: point,
            surfaceHint: surfaceHint,
            perspectiveHint: perspectiveHint
        )
    }
}

