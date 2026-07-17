import AppKit
import PlantGardenCore

struct CustomPlantAssetRecord: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var prompt: String
    var userDescription: String
    var kind: PlantKind
    var baseSpecies: PlantSpecies
    var imageURL: URL
    var createdAt: Date
    var roomObjectCategory: RoomObjectCategory?

    var isRoomStudioObject: Bool {
        roomObjectCategory != nil
            || (
                prompt.contains("WallpaperGarden Room Studio")
                    && prompt.contains("Room object category:")
            )
    }

    var isAlienPlantAsset: Bool {
        roomObjectCategory == nil
            && prompt.contains("WallpaperGarden Alien/UFO mode")
    }

    var isRoomStudioPlantAsset: Bool {
        roomObjectCategory == nil
            && prompt.contains("WallpaperGarden Room Studio")
            && !prompt.contains("Room object category:")
    }

    var isRainforestPlantAsset: Bool {
        roomObjectCategory == nil
            && prompt.contains("WallpaperGarden Rainforest mode")
    }

    var isGardenPlantAsset: Bool {
        roomObjectCategory == nil
            && !isAlienPlantAsset
            && !isRoomStudioPlantAsset
            && !isRainforestPlantAsset
    }
}

struct CustomPlantAssetRequest: Equatable {
    var kind: PlantKind
    var displayName: String
    var userDescription: String
    var roomObjectCategory: RoomObjectCategory?
    var roomPerspectiveContext: RoomObjectPerspectiveContext?
    var experienceMode: GardenExperienceMode

    init(
        kind: PlantKind,
        displayName: String,
        userDescription: String,
        roomObjectCategory: RoomObjectCategory? = nil,
        roomPerspectiveContext: RoomObjectPerspectiveContext? = nil,
        experienceMode: GardenExperienceMode = .garden
    ) {
        self.kind = kind
        self.displayName = displayName
        self.userDescription = userDescription
        self.roomObjectCategory = roomObjectCategory
        self.roomPerspectiveContext = roomPerspectiveContext
        self.experienceMode = experienceMode
    }
}

enum CustomPlantAssetError: Error, LocalizedError {
    case invalidDescription
    case couldNotDecodeGeneratedImage
    case couldNotStoreImage
    case openAIError(String)

    var errorDescription: String? {
        switch self {
        case .invalidDescription:
            "Describe the plant you want to create."
        case .couldNotDecodeGeneratedImage:
            "OpenAI returned a response without a usable PNG image."
        case .couldNotStoreImage:
            "The generated plant asset could not be saved."
        case .openAIError(let message):
            message
        }
    }
}

protocol CustomPlantAssetHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: CustomPlantAssetHTTPClient {}

enum CustomPlantAssetPrompt {
    static func displayName(
        from rawName: String,
        description: String,
        fallbackKind: PlantKind
    ) -> String {
        let explicitName = cleanedSingleLine(rawName)
        if !explicitName.isEmpty {
            return String(explicitName.prefix(44))
        }

        let inferredName = cleanedSingleLine(description)
        if !inferredName.isEmpty {
            return String(inferredName.prefix(44))
        }

        return "Custom \(fallbackKind.displayName)"
    }

    static func normalizedRequest(
        kind: PlantKind,
        displayName rawName: String,
        userDescription rawDescription: String,
        experienceMode: GardenExperienceMode = .garden
    ) -> CustomPlantAssetRequest? {
        let description = cleanedMultiline(rawDescription)
        guard !description.isEmpty else {
            return nil
        }

        return CustomPlantAssetRequest(
            kind: kind,
            displayName: displayName(
                from: rawName,
                description: description,
                fallbackKind: kind
            ),
            userDescription: description,
            roomObjectCategory: nil,
            roomPerspectiveContext: nil,
            experienceMode: experienceMode
        )
    }

    static func masterPrompt(for request: CustomPlantAssetRequest) -> String {
        if let roomCategory = request.roomObjectCategory {
            return roomObjectMasterPrompt(for: request, category: roomCategory)
        }

        if request.experienceMode == .alienUFO {
            return alienPlantMasterPrompt(for: request)
        }

        if request.experienceMode == .rainforest {
            return rainforestPlantMasterPrompt(for: request)
        }

        if request.experienceMode == .roomStudio {
            return roomStudioPlantMasterPrompt(for: request)
        }

        return """
        Create a high-fidelity PNG plant asset for WallpaperGarden.
        User plant request: \(request.userDescription)

        Asset type: \(request.kind.displayName)
        Display name: \(request.displayName)
        Visual guidance: \(guidance(for: request.kind))

        Hard constraints:
        - Render the plant on a single perfectly flat pure chroma-magenta background (#FF00FF) that touches every canvas edge.
        - The #FF00FF background must be one uniform color with no shadows, gradients, texture, floor plane, reflections, lighting variation, vignette, or halo.
        - Do not use pure #FF00FF anywhere inside the plant itself; keep the subject fully separated from the chroma background with crisp edges and generous padding.
        - Do not render a checkerboard transparency pattern; the app will remove the #FF00FF background after generation.
        - no scene, no wall, no floor, no pot, no planter, no vase, no label, no UI, no text.
        - Isolated single botanical asset, centered, fully visible, with the natural root/base contact visible.
        - Realistic detailed cutout, premium app asset quality, crisp edges, soft natural internal shadows.
        - Front-facing three-quarter view that can sit convincingly on top of a wallpaper.
        - Do not include animals, insects, hands, tools, watermarks, or decorative props.
        - Keep the whole silhouette inside the canvas with padding so the app can scale and drag it cleanly.
        """
    }

    private static func roomStudioPlantMasterPrompt(for request: CustomPlantAssetRequest) -> String {
        """
        Create a high-fidelity PNG indoor plant asset for WallpaperGarden Room Studio.
        User indoor plant request: \(request.userDescription)

        Asset type: Indoor \(request.kind.displayName)
        Display name: \(request.displayName)
        Visual guidance: Bedroom, studio, apartment, lounge, or chill-room houseplant; \(guidance(for: request.kind))

        Hard constraints:
        - Render the indoor plant on a single perfectly flat pure chroma-magenta background (#FF00FF) that touches every canvas edge.
        - The #FF00FF background must be one uniform color with no shadows, gradients, texture, floor plane, reflections, lighting variation, vignette, or halo.
        - Do not use pure #FF00FF anywhere inside the plant or planter itself; keep the subject fully separated from the chroma background with crisp edges and generous padding.
        - Do not render a checkerboard transparency pattern; the app will remove the #FF00FF background after generation.
        - no full room scene, no wall, no floor, no furniture, no people, no animals, no insects, no UI, no watermark, no brand logos, no readable text.
        - A tasteful pot, planter, plant stand, or hanging planter is allowed when it helps the plant feel natural indoors.
        - Isolated single indoor botanical asset, centered, fully visible, with the planter/base contact edge visible.
        - Realistic detailed cutout, premium app asset quality, crisp edges, soft natural internal shadows.
        - Front-facing three-quarter view that can sit convincingly inside a bedroom, studio, lounge, or media-room wallpaper.
        - Keep the whole silhouette inside the canvas with padding so the app can scale and drag it cleanly.
        """
    }

    private static func alienPlantMasterPrompt(for request: CustomPlantAssetRequest) -> String {
        """
        Create a high-fidelity PNG exobiology plant asset for WallpaperGarden Alien/UFO mode.
        User alien plant request: \(request.userDescription)

        Asset type: Alien \(request.kind.displayName)
        Display name: \(request.displayName)
        Visual guidance: Speculative exobiology, coherent botanical anatomy, \(guidance(for: request.kind))

        Hard constraints:
        - Render the alien plant on a single perfectly flat pure chroma-magenta background (#FF00FF) that touches every canvas edge.
        - The #FF00FF background must be one uniform color with no shadows, gradients, texture, floor plane, reflections, lighting variation, vignette, or halo.
        - Do not use pure #FF00FF anywhere inside the alien plant itself; keep the subject fully separated from the chroma background with crisp edges and generous padding.
        - Do not render a checkerboard transparency pattern; the app will remove the #FF00FF background after generation.
        - no UFO, no alien creature, no planet scene, no wall, no floor, no pot, no planter, no label, no UI, no text.
        - Isolated single alien botanical asset, centered, fully visible, with the natural root/base/contact structure visible.
        - Bioluminescence is allowed, but it must be part of the plant anatomy, not a background glow or aura.
        - Realistic detailed cutout, premium app asset quality, crisp edges, soft natural internal shadows.
        - Front-facing three-quarter view that can sit convincingly on top of an alien garden wallpaper.
        - Keep the whole silhouette inside the canvas with padding so the app can scale and drag it cleanly.
        """
    }

    private static func rainforestPlantMasterPrompt(for request: CustomPlantAssetRequest) -> String {
        """
        Create a high-fidelity PNG rainforest collage asset for WallpaperGarden Rainforest mode.
        User rainforest asset request: \(request.userDescription)

        Asset type: Rainforest \(request.kind.displayName)
        Display name: \(request.displayName)
        Visual guidance: Lush humid rainforest understory, canopy, vines, moss, epiphytes, and layered jungle collage; \(guidance(for: request.kind))

        Hard constraints:
        - Render the rainforest asset on a single perfectly flat pure chroma-magenta background (#FF00FF) that touches every canvas edge.
        - The #FF00FF background must be one uniform color with no shadows, gradients, texture, floor plane, reflections, lighting variation, vignette, or halo.
        - Do not use pure #FF00FF anywhere inside the asset itself; keep the subject fully separated from the chroma background with crisp edges and generous padding.
        - Do not render a checkerboard transparency pattern; the app will remove the #FF00FF background after generation.
        - no full forest scene, no room, no wall, no floor, no pot, no planter, no label, no UI, no readable text.
        - Isolated single rainforest cutout, centered, fully visible, with an organic base or edge that layers naturally over other assets.
        - Realistic detailed cutout, premium app asset quality, crisp edges, soft natural internal shadows, believable leaf translucency.
        - Front-facing three-quarter view that can sit convincingly in a full-screen plant collage.
        - Keep the whole silhouette inside the canvas with padding so the app can scale and drag it cleanly.
        """
    }

    private static func roomObjectMasterPrompt(
        for request: CustomPlantAssetRequest,
        category: RoomObjectCategory
    ) -> String {
        let context = request.roomPerspectiveContext ?? .inferred(from: nil)
        return """
        Create a high-fidelity PNG room object asset for WallpaperGarden Room Studio.
        User room object request: \(request.userDescription)

        Room object category: \(category.displayName)
        Display name: \(request.displayName)
        Category guidance: \(category.promptGuidance)
        Placement surface: \(context.surfaceHint)
        Perspective guidance: \(context.perspectiveHint)

        Hard constraints:
        - Render the object on a single perfectly flat pure chroma-magenta background (#FF00FF) that touches every canvas edge.
        - The #FF00FF background must be one uniform color with no shadows, gradients, texture, floor plane, reflections, lighting variation, vignette, or halo.
        - Do not use pure #FF00FF anywhere inside the object itself; keep the subject fully separated from the chroma background with crisp edges and generous padding.
        - Do not render a checkerboard transparency pattern; the app will remove the #FF00FF background after generation.
        - no full room scene, no wall, no floor, no people, no plants, no UI, no watermark, no brand logos, no readable text.
        - Isolated single prop or coherent prop cluster, centered, fully visible, with the natural wall/floor/furniture contact edge visible.
        - Match the perspective implied by the placement guidance: angle, camera height, object plane, scale, and contact shadow should feel ready to composite into that part of the wallpaper.
        - Realistic detailed cutout, premium app asset quality, crisp edges, soft natural internal shadows.
        - Keep the whole silhouette inside the canvas with padding so the app can scale and drag it cleanly.
        """
    }

    static func baseSpecies(for request: CustomPlantAssetRequest) -> PlantSpecies {
        let searchableDescription = "\(request.displayName) \(request.userDescription)".lowercased()
        if let matchingSpecies = PlantSpecies.allCases.first(where: { species in
            guard species.kind == request.kind else {
                return false
            }

            let rawValue = species.rawValue.lowercased()
            let displayName = species.displayName.lowercased()
            return searchableDescription.contains(rawValue)
                || searchableDescription.contains(displayName)
                || displayName.split(separator: " ").contains { searchableDescription.contains(String($0)) }
        }) {
            return matchingSpecies
        }

        switch request.kind {
        case .flower:
            return .rose
        case .foliage:
            return .fern
        case .tree:
            return .japaneseMaple
        case .meadow:
            return .cloverPatch
        case .edible:
            return .determinateTomato
        }
    }

    static func example(for kind: PlantKind) -> String {
        switch kind {
        case .flower:
            "Example: a cobalt blue tulip with silver-edged petals"
        case .foliage:
            "Example: a variegated fern with pale mint leaf tips"
        case .tree:
            "Example: a miniature wind-shaped cedar with exposed roots"
        case .meadow:
            "Example: a low patch of tiny white star flowers and moss"
        case .edible:
            "Example: a compact golden tomato plant with ripe fruit"
        }
    }

    private static func guidance(for kind: PlantKind) -> String {
        switch kind {
        case .flower:
            return "clear stems, botanical bloom structure, elegant flower silhouette"
        case .foliage:
            return "leaf texture and volume are the focus, lush but not oversized"
        case .tree:
            return "complete trunk and canopy, plausible miniature ornamental tree scale"
        case .meadow:
            return "low spreading groundcover patch with a clean organic edge"
        case .edible:
            return "productive edible garden plant with visible leaves and crop detail"
        }
    }

    private static func cleanedSingleLine(_ value: String) -> String {
        cleanedMultiline(value)
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }

    private static func cleanedMultiline(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum CustomPlantAssetOpenAIConfiguration {
    static let model = OpenAIImageGenerationConfiguration.primaryModel
    static let fallbackModels = OpenAIImageGenerationConfiguration.fallbackModels
    static let generationRequestTimeout: TimeInterval = 600
    static let generatedImageDownloadTimeout: TimeInterval = 240

    static func requestBody(prompt: String, model: String = model) -> [String: Any] {
        [
            "model": model,
            "prompt": prompt,
            "size": "1024x1024",
            "quality": "high",
            "output_format": "png",
            "n": 1
        ]
    }
}

@MainActor
final class CustomPlantAssetStore {
    static let shared = CustomPlantAssetStore()
    static let imageCacheLimit = 32

    private let manifestFilename = "custom-plant-assets.json"
    private let imageDirectoryName = "Images"
    private let baseDirectoryURL: URL
    private let manifestURL: URL
    private let imageDirectoryURL: URL
    private let fileManager: FileManager
    private let httpClient: CustomPlantAssetHTTPClient
    private var loadedRecords: [CustomPlantAssetRecord]
    private var imageCache: [String: NSImage] = [:]
    private var imageCacheAccessOrder: [String] = []
    private var alphaMaskCache: [ObjectIdentifier: PlantArtworkAlphaMask?] = [:]
    private var displayableImageCache: [String: Bool] = [:]

    init(
        baseDirectoryURL: URL? = nil,
        fileManager: FileManager = .default,
        httpClient: CustomPlantAssetHTTPClient = URLSession.shared
    ) {
        self.fileManager = fileManager
        self.httpClient = httpClient
        self.baseDirectoryURL = (baseDirectoryURL ?? GardenPersistence.defaultDirectoryURL(fileManager: fileManager))
            .appendingPathComponent("CustomPlantAssets", isDirectory: true)
        self.manifestURL = self.baseDirectoryURL.appendingPathComponent(manifestFilename)
        self.imageDirectoryURL = self.baseDirectoryURL.appendingPathComponent(imageDirectoryName, isDirectory: true)
        self.loadedRecords = (try? Self.loadRecords(from: self.manifestURL)) ?? []
        repairLoadedRecordsIfNeeded()
    }

    var records: [CustomPlantAssetRecord] {
        loadedRecords
    }

    func savedPlantAssets(kind: PlantKind? = nil, mode: GardenExperienceMode) -> [CustomPlantAssetRecord] {
        loadedRecords.filter { record in
            guard record.roomObjectCategory == nil else {
                return false
            }
            if let kind, record.kind != kind {
                return false
            }

            let matchesMode = switch mode {
            case .garden:
                record.isGardenPlantAsset
            case .rainforest:
                record.isRainforestPlantAsset
            case .roomStudio:
                record.isRoomStudioPlantAsset
            case .alienUFO:
                record.isAlienPlantAsset
            }

            return matchesMode && ensureDisplayableImage(for: record)
        }
    }

    func savedRoomObjectAssets(in category: RoomObjectCategory) -> [CustomPlantAssetRecord] {
        loadedRecords.filter { record in
            record.roomObjectCategory == category
                && record.isRoomStudioObject
                && ensureDisplayableImage(for: record)
        }
    }

    var directoryURL: URL {
        baseDirectoryURL
    }

    struct InventorySummary: Equatable {
        let assetCount: Int
        let byteCount: Int64

        var storageSummary: String {
            let byteFormatter = ByteCountFormatter()
            byteFormatter.allowedUnits = [.useKB, .useMB, .useGB]
            byteFormatter.countStyle = .file
            let storage = byteFormatter.string(fromByteCount: byteCount)
            return "\(assetCount) asset\(assetCount == 1 ? "" : "s") - \(storage)"
        }
    }

    func record(id: String) -> CustomPlantAssetRecord? {
        loadedRecords.first { $0.id == id }
    }

    func imageCacheCountForSelfTest() -> Int {
        imageCache.count
    }

    func displayableImageCacheCountForSelfTest() -> Int {
        displayableImageCache.count
    }

    func isImageCachedForSelfTest(id: String) -> Bool {
        imageCache[id] != nil
    }

    func isRoomObjectAsset(forCustomAssetID id: String) -> Bool {
        record(id: id)?.isRoomStudioObject == true
    }

    func inventorySummary() -> InventorySummary {
        let byteCount = loadedRecords.reduce(Int64(0)) { total, record in
            guard let values = try? record.imageURL.resourceValues(forKeys: [.fileSizeKey]) else {
                return total
            }
            return total + Int64(values.fileSize ?? 0)
        }
        return InventorySummary(assetCount: loadedRecords.count, byteCount: byteCount)
    }

    func hasDisplayableAsset(forCustomAssetID id: String) -> Bool {
        guard let record = record(id: id) else {
            return false
        }

        if let cachedResult = displayableImageCache[id] {
            return cachedResult
        }

        return ensureDisplayableImage(for: record)
    }

    func reusableRoomObjectAsset(for request: CustomPlantAssetRequest) -> CustomPlantAssetRecord? {
        guard let category = request.roomObjectCategory else {
            return nil
        }

        let normalizedDisplayName = normalizedReuseKey(request.displayName)
        let normalizedDescription = normalizedReuseKey(request.userDescription)
        guard !normalizedDisplayName.isEmpty, !normalizedDescription.isEmpty else {
            return nil
        }

        return loadedRecords.first { record in
            record.kind == request.kind
                && normalizedReuseKey(record.displayName) == normalizedDisplayName
                && normalizedReuseKey(record.userDescription) == normalizedDescription
                && record.prompt.contains("WallpaperGarden Room Studio")
                && record.prompt.contains("Room object category: \(category.displayName)")
                && ensureDisplayableImage(for: record)
        }
    }

    func image(forCustomAssetID id: String) -> NSImage? {
        if let cachedImage = imageCache[id] {
            markImageCacheAccess(id)
            return cachedImage
        }

        guard let record = record(id: id),
              ensureDisplayableImage(for: record),
              let image = NSImage(contentsOf: record.imageURL) else {
            return nil
        }

        image.cacheMode = .always
        cacheImage(image, for: id)
        return image
    }

    func alphaMask(forCustomAssetID id: String) -> PlantArtworkAlphaMask? {
        guard let image = image(forCustomAssetID: id) else {
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

    func createAsset(request: CustomPlantAssetRequest, apiKey: String) async throws -> CustomPlantAssetRecord {
        let trimmedDescription = request.userDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else {
            throw CustomPlantAssetError.invalidDescription
        }

        let normalizedRequest = CustomPlantAssetRequest(
            kind: request.kind,
            displayName: CustomPlantAssetPrompt.displayName(
                from: request.displayName,
                description: trimmedDescription,
                fallbackKind: request.kind
            ),
            userDescription: trimmedDescription,
            roomObjectCategory: request.roomObjectCategory,
            roomPerspectiveContext: request.roomPerspectiveContext,
            experienceMode: request.experienceMode
        )
        let prompt = CustomPlantAssetPrompt.masterPrompt(for: normalizedRequest)
        let imageData = try await generateOpenAIImageData(prompt: prompt, apiKey: apiKey)
        return try storeAssetForSelfTest(
            request: normalizedRequest,
            prompt: prompt,
            imageData: imageData,
            createdAt: Date()
        )
    }

    @discardableResult
    func deleteAsset(id: String) -> Bool {
        guard let record = loadedRecords.first(where: { $0.id == id }) else {
            return false
        }

        loadedRecords.removeAll { $0.id == id }
        removeCachedImage(for: id)
        displayableImageCache.removeValue(forKey: id)
        try? fileManager.removeItem(at: record.imageURL)
        try? saveRecords()
        return true
    }

    func deleteAllAssets() {
        loadedRecords.removeAll()
        imageCache.removeAll()
        imageCacheAccessOrder.removeAll()
        alphaMaskCache.removeAll()
        displayableImageCache.removeAll()
        try? fileManager.removeItem(at: imageDirectoryURL)
        try? fileManager.removeItem(at: manifestURL)
        try? fileManager.createDirectory(at: imageDirectoryURL, withIntermediateDirectories: true)
    }

    @discardableResult
    func storeAssetForSelfTest(
        request: CustomPlantAssetRequest,
        prompt: String = "",
        imageData: Data,
        createdAt: Date = Date()
    ) throws -> CustomPlantAssetRecord {
        let processedImageData = try CustomPlantAssetPostProcessor.transparentPNGData(from: imageData)
        guard NSImage(data: processedImageData) != nil,
              CustomPlantAssetPostProcessor.isDisplayReadyPNGData(processedImageData) else {
            throw CustomPlantAssetError.couldNotDecodeGeneratedImage
        }

        try ensureDirectoriesExist()

        let id = uniqueAssetID(displayName: request.displayName, createdAt: createdAt)
        let imageURL = imageDirectoryURL.appendingPathComponent("\(id).png")
        do {
            try processedImageData.write(to: imageURL, options: [.atomic])
        } catch {
            throw CustomPlantAssetError.couldNotStoreImage
        }

        let record = CustomPlantAssetRecord(
            id: id,
            displayName: request.displayName,
            prompt: prompt.isEmpty ? CustomPlantAssetPrompt.masterPrompt(for: request) : prompt,
            userDescription: request.userDescription,
            kind: request.kind,
            baseSpecies: CustomPlantAssetPrompt.baseSpecies(for: request),
            imageURL: imageURL,
            createdAt: createdAt,
            roomObjectCategory: request.roomObjectCategory
        )
        upsert(record)
        try saveRecords()
        if let image = NSImage(data: processedImageData) {
            cacheImage(image, for: id)
        }
        displayableImageCache[id] = true
        return record
    }

    @discardableResult
    func storeRawAssetForRepairTest(
        request: CustomPlantAssetRequest,
        imageData: Data,
        createdAt: Date = Date()
    ) throws -> CustomPlantAssetRecord {
        try ensureDirectoriesExist()

        let id = uniqueAssetID(displayName: request.displayName, createdAt: createdAt)
        let imageURL = imageDirectoryURL.appendingPathComponent("\(id).png")
        try imageData.write(to: imageURL, options: [.atomic])

        let record = CustomPlantAssetRecord(
            id: id,
            displayName: request.displayName,
            prompt: CustomPlantAssetPrompt.masterPrompt(for: request),
            userDescription: request.userDescription,
            kind: request.kind,
            baseSpecies: CustomPlantAssetPrompt.baseSpecies(for: request),
            imageURL: imageURL,
            createdAt: createdAt,
            roomObjectCategory: request.roomObjectCategory
        )
        upsert(record)
        try saveRecords()
        displayableImageCache.removeValue(forKey: id)
        return record
    }

    private func generateOpenAIImageData(prompt: String, apiKey: String) async throws -> Data {
        var modelErrors: [String] = []
        for model in OpenAIImageGenerationConfiguration.modelsInFallbackOrder {
            do {
                return try await generateOpenAIImageData(prompt: prompt, apiKey: apiKey, model: model)
            } catch CustomPlantAssetError.openAIError(let message)
                where OpenAIImageGenerationConfiguration.shouldTryNextModel(afterOpenAIError: message)
                    && model != OpenAIImageGenerationConfiguration.modelsInFallbackOrder.last {
                modelErrors.append("\(model): \(message)")
                continue
            }
        }

        if let lastModelError = modelErrors.last {
            throw CustomPlantAssetError.openAIError(lastModelError)
        }

        throw CustomPlantAssetError.couldNotDecodeGeneratedImage
    }

    private func generateOpenAIImageData(prompt: String, apiKey: String, model: String) async throws -> Data {
        struct ImageResponse: Decodable {
            struct ImageItem: Decodable {
                let b64_json: String?
                let url: URL?
            }

            struct ErrorPayload: Decodable {
                let message: String?
                let type: String?
                let code: String?
            }

            let data: [ImageItem]?
            let error: ErrorPayload?
        }

        let requestURL = URL(string: "https://api.openai.com/v1/images/generations")!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = CustomPlantAssetOpenAIConfiguration.generationRequestTimeout

        let body = CustomPlantAssetOpenAIConfiguration.requestBody(prompt: prompt, model: model)
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await loadData(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decodedResponse = try? JSONDecoder().decode(ImageResponse.self, from: data)

        guard (200..<300).contains(statusCode) else {
            let decodedMessage = [
                decodedResponse?.error?.message,
                decodedResponse?.error?.type,
                decodedResponse?.error?.code
            ]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let message = decodedMessage.isEmpty
                ? nil
                : decodedMessage
            let fallbackMessage = String(data: data, encoding: .utf8)
            throw CustomPlantAssetError.openAIError(
                message
                    ?? fallbackMessage
                    ?? "OpenAI image generation failed."
            )
        }

        if let base64Image = decodedResponse?.data?.first?.b64_json,
           let imageData = Data(base64Encoded: base64Image) {
            return imageData
        }

        if let imageURL = decodedResponse?.data?.first?.url {
            var imageRequest = URLRequest(url: imageURL)
            imageRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            imageRequest.timeoutInterval = CustomPlantAssetOpenAIConfiguration.generatedImageDownloadTimeout
            let (imageData, imageResponse) = try await loadData(for: imageRequest)
            let imageStatusCode = (imageResponse as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(imageStatusCode) else {
                throw CustomPlantAssetError.couldNotDecodeGeneratedImage
            }
            return imageData
        }

        throw CustomPlantAssetError.couldNotDecodeGeneratedImage
    }

    private func loadData(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await httpClient.data(for: request)
        } catch {
            throw CustomPlantAssetError.openAIError(Self.userFacingNetworkErrorMessage(for: error))
        }
    }

    private static func userFacingNetworkErrorMessage(for error: Error) -> String {
        guard let urlError = error as? URLError else {
            return error.localizedDescription
        }

        switch urlError.code {
        case .timedOut:
            return "Image generation took longer than expected and timed out. Please try again; the placeholder was removed and no room object was saved."
        case .notConnectedToInternet:
            return "The internet connection appears to be offline. Reconnect and try generating the asset again."
        case .networkConnectionLost:
            return "The network connection dropped while generating the asset. Please try again."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "The app could not reach OpenAI right now. Please check your connection and try again."
        default:
            return urlError.localizedDescription
        }
    }

    private func ensureDirectoriesExist() throws {
        try fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imageDirectoryURL, withIntermediateDirectories: true)
    }

    private func ensureDisplayableImage(for record: CustomPlantAssetRecord) -> Bool {
        if let cachedResult = displayableImageCache[record.id] {
            return cachedResult
        }

        guard fileManager.fileExists(atPath: record.imageURL.path),
              let imageData = try? Data(contentsOf: record.imageURL) else {
            displayableImageCache[record.id] = false
            return false
        }

        if !CustomPlantAssetPostProcessor.imageNeedsTransparencyRepair(imageData),
           CustomPlantAssetPostProcessor.isDisplayReadyPNGData(imageData) {
            displayableImageCache[record.id] = true
            return true
        }

        guard let repairedData = try? CustomPlantAssetPostProcessor.transparentPNGData(from: imageData),
              CustomPlantAssetPostProcessor.isDisplayReadyPNGData(repairedData) else {
            displayableImageCache[record.id] = false
            return false
        }

        do {
            try repairedData.write(to: record.imageURL, options: [.atomic])
            removeCachedImage(for: record.id)
            displayableImageCache[record.id] = true
            return true
        } catch {
            displayableImageCache[record.id] = false
            return false
        }
    }

    private func cacheImage(_ image: NSImage, for id: String) {
        image.cacheMode = .always
        imageCache[id] = image
        markImageCacheAccess(id)
        trimImageCacheIfNeeded()
    }

    private func markImageCacheAccess(_ id: String) {
        imageCacheAccessOrder.removeAll { $0 == id }
        imageCacheAccessOrder.append(id)
    }

    private func trimImageCacheIfNeeded() {
        while imageCache.count > Self.imageCacheLimit, let evictedID = imageCacheAccessOrder.first {
            imageCacheAccessOrder.removeFirst()
            guard imageCache.removeValue(forKey: evictedID) != nil else {
                continue
            }
            alphaMaskCache.removeAll()
        }
    }

    private func removeCachedImage(for id: String) {
        imageCache.removeValue(forKey: id)
        imageCacheAccessOrder.removeAll { $0 == id }
        alphaMaskCache.removeAll()
    }

    private func repairLoadedRecordsIfNeeded() {
        for record in loadedRecords {
            _ = ensureDisplayableImage(for: record)
        }
    }

    private func upsert(_ record: CustomPlantAssetRecord) {
        loadedRecords.removeAll { $0.id == record.id }
        loadedRecords.insert(record, at: 0)
    }

    private func saveRecords() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(loadedRecords)
        try data.write(to: manifestURL, options: [.atomic])
    }

    private static func loadRecords(from url: URL) throws -> [CustomPlantAssetRecord] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try Data(contentsOf: url)
        return try decoder.decode([CustomPlantAssetRecord].self, from: data)
    }

    private func uniqueAssetID(displayName: String, createdAt: Date) -> String {
        let safeName = safeFilenameComponent(displayName)
        let namePart = safeName.isEmpty ? "plant" : String(safeName.prefix(34))
        let milliseconds = Int(createdAt.timeIntervalSince1970 * 1_000)
        let nonce = UUID().uuidString.prefix(8).lowercased()
        return "custom-plant-\(namePart)-\(milliseconds)-\(nonce)"
    }

    private func normalizedReuseKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private func safeFilenameComponent(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).map { character in
            character.isLetter || character.isNumber ? character : "-"
        }
        .reduce(into: "") { $0.append($1) }
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        .lowercased()
    }
}

@MainActor
enum PlantDisplayAssetResolver {
    static func hasDisplayableAsset(
        for plant: Plant,
        customAssets: CustomPlantAssetStore
    ) -> Bool {
        if let customAssetID = plant.customAssetID {
            if AlienPlantAssetLibrary.shared.hasDisplayableAsset(forCustomAssetID: customAssetID) {
                return true
            }

            return customAssets.hasDisplayableAsset(forCustomAssetID: customAssetID)
        }

        return PlantAssetLibrary.shared.hasDisplayableAsset(for: plant.species)
    }

    static func image(
        for plant: Plant,
        stageIndex: Int? = nil,
        customAssets: CustomPlantAssetStore
    ) -> NSImage? {
        if let customAssetID = plant.customAssetID {
            if let alienImage = AlienPlantAssetLibrary.shared.image(forCustomAssetID: customAssetID) {
                return alienImage
            }

            return customAssets.image(forCustomAssetID: customAssetID)
        }

        if let stageIndex {
            return PlantAssetLibrary.shared.image(for: plant.species, stageIndex: stageIndex)
        }

        return PlantAssetLibrary.shared.image(for: plant.species, growth: plant.growth)
    }

    static func alphaMask(
        for plant: Plant,
        customAssets: CustomPlantAssetStore
    ) -> PlantArtworkAlphaMask? {
        if let customAssetID = plant.customAssetID {
            if let alienMask = AlienPlantAssetLibrary.shared.alphaMask(forCustomAssetID: customAssetID) {
                return alienMask
            }

            return customAssets.alphaMask(forCustomAssetID: customAssetID)
        }

        return PlantAssetLibrary.shared.alphaMask(for: plant.species, growth: plant.growth)
    }
}
