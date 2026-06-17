import AppKit
import PlantGardenCore

/// Renders a shareable snapshot card of the current garden: scene name,
/// vitality, age, focus stats, and a lineup of the most-grown plants.
@MainActor
enum GardenShareCardRenderer {
    static let cardSize = NSSize(width: 1200, height: 630)

    static func makeCard(
        state: GardenState,
        sceneKey: String?,
        at date: Date = Date()
    ) -> NSImage {
        NSImage(size: cardSize, flipped: false) { rect in
            drawBackground(in: rect)
            drawPlants(state: state, in: rect)
            drawText(state: state, sceneKey: sceneKey, at: date, in: rect)
            return true
        }
    }

    static func writeCardPNG(
        state: GardenState,
        sceneKey: String?,
        to url: URL,
        at date: Date = Date()
    ) throws {
        let image = makeCard(state: state, sceneKey: sceneKey, at: date)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try pngData.write(to: url, options: [.atomic])
    }

    private static func drawBackground(in rect: NSRect) {
        NSGradient(colors: [
            NSColor(calibratedRed: 0.075, green: 0.16, blue: 0.11, alpha: 1),
            NSColor(calibratedRed: 0.11, green: 0.24, blue: 0.15, alpha: 1),
            NSColor(calibratedRed: 0.16, green: 0.33, blue: 0.20, alpha: 1)
        ])?.draw(in: rect, angle: -68)

        // Soft vignette to frame the card.
        NSGradient(colors: [
            NSColor(calibratedWhite: 0, alpha: 0.26),
            NSColor(calibratedWhite: 0, alpha: 0)
        ])?.draw(in: rect, angle: 90)
    }

    private static func drawPlants(state: GardenState, in rect: NSRect) {
        let featuredPlants = state.plants
            .filter {
                !$0.isDead && PlantDisplayAssetResolver.hasDisplayableAsset(
                    for: $0,
                    customAssets: CustomPlantAssetStore.shared
                )
            }
            .sorted { $0.growth > $1.growth }
            .prefix(6)
        guard !featuredPlants.isEmpty else {
            return
        }

        let maxHeight = rect.height * 0.42
        let slotWidth = rect.width / CGFloat(featuredPlants.count)
        for (index, plant) in featuredPlants.enumerated() {
            guard let image = PlantDisplayAssetResolver.image(
                for: plant,
                customAssets: CustomPlantAssetStore.shared
            ),
                  image.size.width > 0,
                  image.size.height > 0 else {
                continue
            }

            let scale = min(maxHeight / image.size.height, slotWidth * 0.86 / image.size.width)
            let drawSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            let x = slotWidth * CGFloat(index) + (slotWidth - drawSize.width) / 2
            image.draw(
                in: NSRect(x: x, y: 26, width: drawSize.width, height: drawSize.height),
                from: NSRect(origin: .zero, size: image.size),
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }
    }

    private static func drawText(state: GardenState, sceneKey: String?, at date: Date, in rect: NSRect) {
        let titleColor = NSColor(calibratedRed: 0.96, green: 0.98, blue: 0.93, alpha: 1)
        let subtitleColor = NSColor(calibratedRed: 0.82, green: 0.90, blue: 0.80, alpha: 1)

        let sceneName = GardenWallpaperScene(rawValue: sceneKey ?? "")?.displayName ?? "Custom Scene"
        let vitality = state.vitality(at: date)
        let gardenAgeDays = max(1, Int(date.timeIntervalSince(state.createdAt) / 86_400) + 1)
        let livingPlantCount = state.plants.filter { !$0.isDead }.count

        var statParts = [
            "\(livingPlantCount) plants",
            "Day \(gardenAgeDays)",
            "Vitality \(vitality.percentScore)%"
        ]
        if let focusStats = state.focusStats, focusStats.completedSessions > 0 {
            statParts.append("\(focusStats.completedSessions) focus sessions")
        }

        draw(
            "My Plant Wallpaper Garden",
            at: NSPoint(x: 64, y: rect.height - 130),
            font: .systemFont(ofSize: 56, weight: .bold),
            color: titleColor
        )
        draw(
            sceneName,
            at: NSPoint(x: 64, y: rect.height - 184),
            font: .systemFont(ofSize: 30, weight: .medium),
            color: subtitleColor
        )
        draw(
            statParts.joined(separator: "   •   "),
            at: NSPoint(x: 64, y: rect.height - 240),
            font: .monospacedDigitSystemFont(ofSize: 25, weight: .semibold),
            color: titleColor.withAlphaComponent(0.92)
        )
    }

    private static func draw(_ text: String, at point: NSPoint, font: NSFont, color: NSColor) {
        (text as NSString).draw(
            at: point,
            withAttributes: [
                .font: font,
                .foregroundColor: color
            ]
        )
    }
}
