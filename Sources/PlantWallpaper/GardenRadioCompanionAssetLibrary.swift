import AppKit
import PlantGardenCore

@MainActor
final class GardenRadioCompanionAssetLibrary {
    static let shared = GardenRadioCompanionAssetLibrary()

    private var cache: [String: NSImage] = [:]

    func image(for companion: GardenRadioCompanion) -> NSImage? {
        imageIfAvailable(named: assetName(for: companion))
    }

    func hasAsset(for companion: GardenRadioCompanion) -> Bool {
        imageURL(named: assetName(for: companion)) != nil
    }

    private func imageIfAvailable(named name: String) -> NSImage? {
        if let cachedImage = cache[name] {
            return cachedImage
        }

        guard let url = imageURL(named: name) else {
            return nil
        }
        guard let image = NSImage(contentsOf: url) else {
            NSLog("Plant Wallpaper missing bundled radio companion asset: \(name).png")
            return nil
        }

        image.cacheMode = .always
        cache[name] = image
        return image
    }

    private func imageURL(named name: String) -> URL? {
        Bundle.appResources.url(forResource: name, withExtension: "png")
            ?? Bundle.appResources.url(
                forResource: name,
                withExtension: "png",
                subdirectory: "RadioCompanionAssets"
            )
    }

    private func assetName(for companion: GardenRadioCompanion) -> String {
        companion.rawValue.kebabCasedRadioCompanionAssetName
    }
}

private extension String {
    var kebabCasedRadioCompanionAssetName: String {
        reduce(into: "") { result, character in
            if character.isUppercase {
                if !result.isEmpty {
                    result.append("-")
                }
                result.append(character.lowercased())
            } else {
                result.append(character)
            }
        }
    }
}
