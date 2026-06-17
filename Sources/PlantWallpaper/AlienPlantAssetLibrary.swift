import AppKit
import PlantGardenCore

@MainActor
final class AlienPlantAssetLibrary {
    static let shared = AlienPlantAssetLibrary()

    private var imageCache: [String: NSImage] = [:]
    private var alphaMaskCache: [ObjectIdentifier: PlantArtworkAlphaMask?] = [:]

    func hasDisplayableAsset(for specimen: AlienPlantMenuSpecimen) -> Bool {
        imageURL(for: specimen) != nil
    }

    func hasDisplayableAsset(forCustomAssetID customAssetID: String) -> Bool {
        guard let specimen = AlienPlantMenuCatalog.specimen(forCustomAssetID: customAssetID) else {
            return false
        }

        return hasDisplayableAsset(for: specimen)
    }

    func enabledSpecimens(in kind: PlantKind) -> [AlienPlantMenuSpecimen] {
        AlienPlantMenuCatalog.specimens(in: kind)
            .filter { hasDisplayableAsset(for: $0) }
    }

    func image(for specimen: AlienPlantMenuSpecimen) -> NSImage? {
        image(named: specimen.assetName)
    }

    func image(forCustomAssetID customAssetID: String) -> NSImage? {
        guard let specimen = AlienPlantMenuCatalog.specimen(forCustomAssetID: customAssetID) else {
            return nil
        }

        return image(for: specimen)
    }

    func alphaMask(forCustomAssetID customAssetID: String) -> PlantArtworkAlphaMask? {
        guard let image = image(forCustomAssetID: customAssetID) else {
            return nil
        }

        let key = ObjectIdentifier(image)
        if let cachedMask = alphaMaskCache[key] {
            return cachedMask
        }

        let mask = PlantArtworkAlphaMask(image: image)
        alphaMaskCache[key] = mask
        return mask
    }

    func record(for specimen: AlienPlantMenuSpecimen) -> CustomPlantAssetRecord? {
        guard let imageURL = imageURL(for: specimen) else {
            return nil
        }

        let request = CustomPlantAssetRequest(
            kind: specimen.kind,
            displayName: specimen.title,
            userDescription: specimen.promptSeed,
            experienceMode: .alienUFO
        )
        return CustomPlantAssetRecord(
            id: specimen.customAssetID,
            displayName: specimen.title,
            prompt: CustomPlantAssetPrompt.masterPrompt(for: request),
            userDescription: specimen.promptSeed,
            kind: specimen.kind,
            baseSpecies: CustomPlantAssetPrompt.baseSpecies(for: request),
            imageURL: imageURL,
            createdAt: Date(timeIntervalSince1970: 0),
            roomObjectCategory: nil
        )
    }

    func record(forCustomAssetID customAssetID: String) -> CustomPlantAssetRecord? {
        guard let specimen = AlienPlantMenuCatalog.specimen(forCustomAssetID: customAssetID) else {
            return nil
        }

        return record(for: specimen)
    }

    private func image(named name: String) -> NSImage? {
        if let cachedImage = imageCache[name] {
            return cachedImage
        }

        guard let url = imageURL(named: name),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.cacheMode = .always
        imageCache[name] = image
        return image
    }

    private func imageURL(for specimen: AlienPlantMenuSpecimen) -> URL? {
        imageURL(named: specimen.assetName)
    }

    private func imageURL(named name: String) -> URL? {
        Bundle.appResources.url(forResource: name, withExtension: "png")
            ?? Bundle.appResources.url(
                forResource: name,
                withExtension: "png",
                subdirectory: "AlienPlantAssets"
            )
    }
}
