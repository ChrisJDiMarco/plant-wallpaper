import AppKit
import PlantGardenCore

struct WallpaperSnapshot: Codable, Equatable {
    var screenID: String
    var wallpaperURL: URL
}

struct CustomWallpaperRecord: Codable, Equatable {
    var key: String
    var displayName: String
    var prompt: String
    var imageURL: URL
    var createdAt: Date
    var parentSceneKey: String? = nil
    var editedFromKey: String? = nil
    var editPrompt: String? = nil
    var versionIndex: Int? = nil
    var experienceMode: GardenExperienceMode? = nil

    var isWallpaperUpdate: Bool {
        parentSceneKey != nil || versionIndex != nil || editPrompt != nil
    }

    func isAssociated(with mode: GardenExperienceMode) -> Bool {
        if let experienceMode {
            return experienceMode == mode
        }

        if let parentSceneKey,
           let parentScene = GardenWallpaperScene.scene(forKey: parentSceneKey) {
            return parentScene.experienceMode == mode
        }

        if let scene = GardenWallpaperScene.scene(forKey: key) {
            return scene.experienceMode == mode
        }

        return mode == .garden
    }
}

struct WallpaperVersionEntry: Equatable {
    var key: String
    var title: String
    var tooltip: String
    var createdAt: Date?
    var isOriginal: Bool
}

enum WallpaperEditPrompt {
    static func masterPrompt(from userPrompt: String) -> String {
        """
        Recreate the attached current WallpaperGarden desktop wallpaper as faithfully as possible.

        The attached image is the source of truth. Keep the same scene identity, camera angle, composition, architecture, hardscape, lighting direction, desktop-friendly negative space, and overall realism. Do not redesign the scene. Do not add app UI, labels, text, watermarks, people, animals, insects, or extra plants unless explicitly requested below.

        Apply only these requested updates:
        \(userPrompt)

        Output a polished Mac desktop wallpaper. Preserve the prepared blank planting areas so app-rendered plants can still be placed on top later.
        """
    }
}

enum SmartLockWallpaperPrompt {
    static func masterPrompt(at date: Date = Date(), calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let timeOfDay: String
        switch hour {
        case 5..<8:
            timeOfDay = "early morning"
        case 8..<12:
            timeOfDay = "morning"
        case 12..<17:
            timeOfDay = "midday"
        case 17..<20:
            timeOfDay = "golden hour / early evening"
        case 20..<23:
            timeOfDay = "nightfall"
        default:
            timeOfDay = "deep night"
        }

        return """
        Transform the attached screenshot exported from the WallpaperGarden desktop wallpaper app into one seamless locked-view wallpaper.

        Context: WallpaperGarden lets the user drag plants, room objects, radio companions, and other decorative PNG assets over a base wallpaper scene. In the source image, some plants or objects may look like generic composited app assets sitting on top of the background. Treat those visible assets as the user's intentional design and transform them into real, natural, physically integrated parts of the scene.

        The attached image is the source of truth. Preserve the exact camera angle, layout, plant/object placement, cat if visible, radio companions if visible, scene identity, scale, silhouettes, and composition. Keep every visible plant and object in the same place with the same approximate size. Do not add new plants, animals, insects, people, text, logos, UI, desktop icons, Dock, menu bar, labels, or watermarks.

        Render the result as if it were a real scene photographed with a great camera and lens: natural depth, believable lens softness, coherent exposure, physically plausible contact shadows, leaf translucency, pot/soil contact, reflected color, material texture, and atmosphere. Make the composited plants feel rooted, lit by the same environment, and actually present in the space. Every plant and tree must look as though it is genuinely growing out of the exact spot it sits in — show real soil displacement, mulch, root flare, or surface disturbance where each stem or trunk meets the ground, and make that base-to-ground transition more convincing and physically grounded than the reference image, with no floating, cut-off, or pasted-on look.

        Output a hyper-realistic natural Mac desktop wallpaper with accurate \(timeOfDay) lighting. Make the time-of-day lighting feel physically plausible while keeping the scene instantly recognizable as the same garden, room, or alien environment from the source snapshot.

        Important: do not bake extra flying insects into the result. WallpaperGarden will continue drawing its live animated bugs above this generated lock view.
        """
    }
}

enum WallpaperImageEditOpenAIConfiguration {
    static let model = OpenAIImageGenerationConfiguration.primaryModel

    static func requestBody(
        prompt: String,
        quality: GardenWallpaperGenerationQuality = .twoK,
        model: String = model
    ) -> [String: Any] {
        [
            "model": model,
            "prompt": prompt,
            "size": quality.openAISize,
            "quality": quality.openAIQuality,
            "output_format": "png",
            "n": 1
        ]
    }

    static func multipartFields(
        prompt: String,
        quality: GardenWallpaperGenerationQuality = .twoK
    ) -> [String: String] {
        [
            "model": model,
            "prompt": prompt,
            "size": quality.openAISize,
            "quality": quality.openAIQuality,
            "output_format": "png",
            "n": "1"
        ]
    }
}

enum WallpaperManagerError: Error, LocalizedError {
    case couldNotRenderWallpaper
    case couldNotLoadImage(URL)
    case couldNotLoadBundledSceneAsset(String)
    case couldNotDecodeGeneratedImage
    case openAIError(String)

    var errorDescription: String? {
        switch self {
        case .couldNotRenderWallpaper:
            "Could not render wallpaper."
        case .couldNotLoadImage(let url):
            "Could not load image at \(url.path)."
        case .couldNotLoadBundledSceneAsset(let sceneKey):
            "Could not load bundled scene image for \(sceneKey)."
        case .couldNotDecodeGeneratedImage:
            "OpenAI returned a response without a usable image."
        case .openAIError(let message):
            message
        }
    }
}

@MainActor
final class WallpaperManager {
    // v4 adds optional six-step day-cycle scene artwork and invalidates
    // older cached renders that only baked generic time-of-day grading.
    private let wallpaperVersion = "empty-planting-scene-v4"
    private static let appDefaultsSuiteName = "com.chrisdimarco.wallpapergarden"
    private let selectedSceneDefaultsKey = "PlantWallpaper.selectedWallpaperScene"
    private let currentWallpaperImageDefaultsKey = "PlantWallpaper.currentWallpaperImageURL"
    private let customWallpaperManifestFilename = "custom-wallpapers.json"
    private let resourceBundleName = "WallpaperGarden_PlantWallpaper.bundle"

    private enum DayPhase: String {
        case dawn
        case day
        case evening
        case night
    }

    private let directoryURL: URL
    private let snapshotURL: URL
    private let customWallpaperManifestURL: URL
    private let aiWallpaperDirectoryURL: URL
    private let customWallpaperDirectoryURL: URL
    private let smartLockWallpaperDirectoryURL: URL
    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let sharedDefaults: UserDefaults?
    /// Scene + day phase + season baked into the most recent living-scene
    /// apply; nil when a custom (untimed) wallpaper is showing.
    private var lastAppliedLivingGrade: String?

    init(
        baseDirectoryURL: URL,
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults? = UserDefaults(suiteName: WallpaperManager.appDefaultsSuiteName)
    ) {
        self.fileManager = fileManager
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
        self.directoryURL = baseDirectoryURL.appendingPathComponent("Wallpaper", isDirectory: true)
        self.snapshotURL = directoryURL.appendingPathComponent("previous-wallpapers.json")
        self.customWallpaperManifestURL = directoryURL.appendingPathComponent(customWallpaperManifestFilename)
        self.aiWallpaperDirectoryURL = directoryURL.appendingPathComponent("AIWallpapers", isDirectory: true)
        self.customWallpaperDirectoryURL = directoryURL.appendingPathComponent("CustomWallpapers", isDirectory: true)
        self.smartLockWallpaperDirectoryURL = directoryURL.appendingPathComponent("SmartLock", isDirectory: true)
        mirrorSelectedSceneToSharedDefaults(selectedWallpaperSceneKey)
        mirrorCurrentWallpaperImageToSharedDefaults()
    }

    var selectedWallpaperSceneKey: String {
        resolvedWallpaperSceneKey(defaults.string(forKey: selectedSceneDefaultsKey))
    }

    var customWallpapers: [CustomWallpaperRecord] {
        (try? loadCustomWallpaperRecords()) ?? []
    }

    var customWallpaperSceneRoots: [CustomWallpaperRecord] {
        customWallpapers.filter { !$0.isWallpaperUpdate }
    }

    func customWallpaperSceneRoots(for mode: GardenExperienceMode) -> [CustomWallpaperRecord] {
        customWallpaperSceneRoots.filter { $0.isAssociated(with: mode) }
    }

    func wallpaperVersions(forSceneKey sceneKey: String? = nil) -> [WallpaperVersionEntry] {
        let selectedKey = GardenWallpaperScene.canonicalKey(for: sceneKey ?? selectedWallpaperSceneKey)
        let rootKey = wallpaperVersionRootKey(for: selectedKey)
        let records = customWallpapers
        let editedRecords = records
            .filter { $0.parentSceneKey == rootKey }
            .sorted { lhs, rhs in
                let lhsIndex = lhs.versionIndex ?? 0
                let rhsIndex = rhs.versionIndex ?? 0
                if lhsIndex != rhsIndex {
                    return lhsIndex > rhsIndex
                }
                return lhs.createdAt > rhs.createdAt
            }

        var entries = editedRecords.map { record in
            let versionNumber = record.versionIndex ?? 1
            let update = record.editPrompt ?? record.prompt
            return WallpaperVersionEntry(
                key: record.key,
                title: "Version \(versionNumber): \(record.displayName)",
                tooltip: update.isEmpty ? record.displayName : update,
                createdAt: record.createdAt,
                isOriginal: false
            )
        }

        if let originalEntry = originalWallpaperVersionEntry(forRootKey: rootKey, records: records) {
            entries.append(originalEntry)
        }

        return entries
    }

    func wallpaperSceneRootKey(for sceneKey: String? = nil) -> String {
        wallpaperVersionRootKey(for: GardenWallpaperScene.canonicalKey(for: sceneKey ?? selectedWallpaperSceneKey))
    }

    func latestWallpaperKey(forSceneRootKey sceneKey: String) -> String {
        let rootKey = wallpaperVersionRootKey(for: GardenWallpaperScene.canonicalKey(for: sceneKey))
        let latestRecord = customWallpapers
            .filter { $0.parentSceneKey == rootKey }
            .max { lhs, rhs in
                let lhsIndex = lhs.versionIndex ?? 0
                let rhsIndex = rhs.versionIndex ?? 0
                if lhsIndex != rhsIndex {
                    return lhsIndex < rhsIndex
                }
                return lhs.createdAt < rhs.createdAt
            }
        return latestRecord?.key ?? rootKey
    }

    var wallpaperDataDirectoryURL: URL {
        directoryURL
    }

    var aiWallpaperDataDirectoryURL: URL {
        aiWallpaperDirectoryURL
    }

    var customWallpaperDataDirectoryURL: URL {
        customWallpaperDirectoryURL
    }

    var smartLockWallpaperDataDirectoryURL: URL {
        smartLockWallpaperDirectoryURL
    }

    var currentWallpaperImageURL: URL? {
        guard let path = defaults.string(forKey: currentWallpaperImageDefaultsKey), !path.isEmpty else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func applyLivingSceneWallpaper(to screens: [NSScreen] = NSScreen.screens, at date: Date = Date()) {
        applyWallpaperSceneKey(selectedWallpaperSceneKey, to: screens, at: date, persistSelection: false)
    }

    @discardableResult
    func applyWallpaperSceneKey(
        _ sceneKey: String,
        to screens: [NSScreen] = NSScreen.screens,
        at date: Date = Date(),
        persistSelection: Bool = true
    ) -> String {
        let canonicalSceneKey = GardenWallpaperScene.canonicalKey(for: sceneKey)
        if let scene = GardenWallpaperScene.scene(forKey: canonicalSceneKey) {
            guard scene.isSelectableScene else {
                let fallbackScene = GardenExperienceModeScenePolicy.defaultScene(for: scene.experienceMode)
                applyWallpaperScene(fallbackScene, to: screens, at: date, persistSelection: persistSelection)
                return fallbackScene.rawValue
            }

            applyWallpaperScene(scene, to: screens, at: date, persistSelection: persistSelection)
            return scene.rawValue
        }

        do {
            guard let record = try loadCustomWallpaperRecords().first(where: { $0.key == canonicalSceneKey }) else {
                applyWallpaperScene(.defaultScene, to: screens, at: date, persistSelection: persistSelection)
                return GardenWallpaperScene.defaultScene.rawValue
            }

            try applyCustomWallpaper(record, to: screens, persistSelection: persistSelection)
            return record.key
        } catch {
            NSLog("Plant Wallpaper could not set custom background: \(error.localizedDescription)")
            applyWallpaperScene(.defaultScene, to: screens, at: date, persistSelection: persistSelection)
            return GardenWallpaperScene.defaultScene.rawValue
        }
    }

    func applyWallpaperScene(
        _ scene: GardenWallpaperScene,
        to screens: [NSScreen] = NSScreen.screens,
        at date: Date = Date(),
        persistSelection: Bool = true
    ) {
        do {
            try ensureDirectoryExists()
            try saveCurrentWallpaperSnapshotsIfNeeded(for: screens)

            if persistSelection {
                setSelectedSceneKey(scene.rawValue)
            }

            var firstWallpaperURL: URL?
            for screen in screens {
                let wallpaperURL = try livingSceneWallpaperURL(for: screen, at: date, scene: scene)
                if firstWallpaperURL == nil {
                    firstWallpaperURL = wallpaperURL
                }
                try NSWorkspace.shared.setDesktopImageURL(wallpaperURL, for: screen, options: [:])
            }
            if let firstWallpaperURL {
                setCurrentWallpaperImageURL(firstWallpaperURL)
            }
            lastAppliedLivingGrade = livingGradeKey(for: scene, at: date)
            pruneRenderedWallpaperCache()
        } catch {
            NSLog("Plant Wallpaper could not set the \(scene.displayName) background: \(error.localizedDescription)")
        }
    }

    /// Reapplies the living scene when the baked-in time-of-day or season
    /// grade has gone stale - so the desktop shifts dawn → day → evening →
    /// night instead of keeping the grade from launch time. Cheap to call
    /// every simulation tick: it's a string compare until a phase boundary.
    func refreshLivingSceneWallpaperIfStale(to screens: [NSScreen] = NSScreen.screens, at date: Date = Date()) {
        guard let scene = GardenWallpaperScene(rawValue: selectedWallpaperSceneKey) else {
            return
        }

        guard livingGradeKey(for: scene, at: date) != lastAppliedLivingGrade else {
            return
        }

        applyWallpaperScene(scene, to: screens, at: date, persistSelection: false)
    }

    private func livingGradeKey(for scene: GardenWallpaperScene, at date: Date) -> String {
        let season = GardenSeasonCondition(at: date)
        return [
            scene.rawValue,
            GardenSceneDayCyclePhase(date: date).rawValue,
            dayPhase(for: date).rawValue,
            season.mood.rawValue
        ].joined(separator: "|")
    }

    func applyCalmWallpaper(to screens: [NSScreen] = NSScreen.screens) {
        applyLivingSceneWallpaper(to: screens)
    }

    @discardableResult
    func createChosenWallpaperScene(
        from sourceURL: URL,
        to screens: [NSScreen] = NSScreen.screens,
        experienceMode: GardenExperienceMode = .garden
    ) throws -> CustomWallpaperRecord {
        try ensureDirectoryExists()
        try ensureCustomWallpaperDirectoryExists()
        try saveCurrentWallpaperSnapshotsIfNeeded(for: screens)

        guard let image = NSImage(contentsOf: sourceURL),
              image.size.width > 0,
              image.size.height > 0 else {
            throw WallpaperManagerError.couldNotLoadImage(sourceURL)
        }

        let sourceName = sourceURL.deletingPathExtension().lastPathComponent
        let safeKey = uniqueSceneKey(prefix: "custom", source: sourceName)
        let storedImageURL = customWallpaperDirectoryURL.appendingPathComponent("\(safeKey).png")
        let largestSize = largestTargetSize(for: screens)
        try renderChosenWallpaper(image, to: storedImageURL, size: largestSize)

        let record = CustomWallpaperRecord(
            key: safeKey,
            displayName: displayName(forChosenWallpaperName: sourceName),
            prompt: "Local wallpaper image: \(sourceURL.lastPathComponent)",
            imageURL: storedImageURL,
            createdAt: Date(),
            experienceMode: experienceMode
        )
        try upsertCustomWallpaperRecord(record)
        try applyCustomWallpaper(record, to: screens, persistSelection: true)
        return record
    }

    func createAIWallpaper(
        prompt userPrompt: String,
        apiKey: String,
        to screens: [NSScreen] = NSScreen.screens,
        experienceMode: GardenExperienceMode = .garden,
        quality: GardenWallpaperGenerationQuality = .twoK
    ) async throws -> CustomWallpaperRecord {
        try ensureDirectoryExists()
        try ensureAIWallpaperDirectoryExists()
        try saveCurrentWallpaperSnapshotsIfNeeded(for: screens)

        let imageData = try await generateOpenAIImageData(
            prompt: wallpaperPrompt(from: userPrompt),
            apiKey: apiKey,
            quality: quality
        )
        guard let image = NSImage(data: imageData),
              image.size.width > 0,
              image.size.height > 0 else {
            throw WallpaperManagerError.couldNotDecodeGeneratedImage
        }

        let safeKey = uniqueSceneKey(prefix: "ai", source: userPrompt)
        let sourceURL = aiWallpaperDirectoryURL.appendingPathComponent("\(safeKey).png")
        try imageData.write(to: sourceURL, options: [.atomic])

        let record = CustomWallpaperRecord(
            key: safeKey,
            displayName: displayName(forAIPrompt: userPrompt),
            prompt: userPrompt,
            imageURL: sourceURL,
            createdAt: Date(),
            experienceMode: experienceMode
        )
        try upsertCustomWallpaperRecord(record)
        try applyCustomWallpaper(record, to: screens, persistSelection: true)
        return record
    }

    func createEditedWallpaperScene(
        updatePrompt userPrompt: String,
        apiKey: String,
        to screens: [NSScreen] = NSScreen.screens,
        at date: Date = Date(),
        quality: GardenWallpaperGenerationQuality = .twoK
    ) async throws -> CustomWallpaperRecord {
        let trimmedPrompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw WallpaperManagerError.openAIError("Describe the wallpaper change you want.")
        }

        try ensureDirectoryExists()
        try ensureCustomWallpaperDirectoryExists()
        try saveCurrentWallpaperSnapshotsIfNeeded(for: screens)

        let currentSceneKey = selectedWallpaperSceneKey
        let rootSceneKey = wallpaperVersionRootKey(for: currentSceneKey)
        let sourceImageData = try currentWallpaperReferenceImageData(
            sceneKey: currentSceneKey,
            screens: screens,
            at: date
        )
        let masterPrompt = WallpaperEditPrompt.masterPrompt(from: trimmedPrompt)
        let editedImageData = try await editOpenAIImageData(
            prompt: masterPrompt,
            imageData: sourceImageData,
            apiKey: apiKey,
            quality: quality
        )
        return try storeEditedWallpaper(
            updatePrompt: trimmedPrompt,
            prompt: masterPrompt,
            parentSceneKey: rootSceneKey,
            editedFromKey: currentSceneKey,
            imageData: editedImageData,
            screens: screens,
            persistSelection: true,
            createdAt: Date()
        )
    }

    func createProgressionWallpaperScene(
        progression: GardenSceneProgression,
        targetLevel: Int,
        experienceMode: GardenExperienceMode,
        apiKey: String,
        to screens: [NSScreen] = NSScreen.screens,
        at date: Date = Date(),
        quality: GardenWallpaperGenerationQuality = .twoK
    ) async throws -> CustomWallpaperRecord {
        let safeLevel = GardenSceneProgression.clampedLevel(targetLevel)
        guard safeLevel > 0 else {
            throw WallpaperManagerError.openAIError("Choose a progression level to generate.")
        }

        try ensureDirectoryExists()
        try ensureCustomWallpaperDirectoryExists()
        try saveCurrentWallpaperSnapshotsIfNeeded(for: screens)

        let currentSceneKey = selectedWallpaperSceneKey
        let rootSceneKey = wallpaperVersionRootKey(for: currentSceneKey)
        let sourceImageData = try currentWallpaperReferenceImageData(
            sceneKey: currentSceneKey,
            screens: screens,
            at: date
        )
        let masterPrompt = WallpaperProgressionPrompt.masterPrompt(
            progression: progression,
            targetLevel: safeLevel,
            experienceMode: experienceMode
        )
        let editedImageData = try await editOpenAIImageData(
            prompt: masterPrompt,
            imageData: sourceImageData,
            apiKey: apiKey,
            quality: quality
        )
        let updatePrompt = "Progression Level \(safeLevel): \(GardenSceneProgression.title(for: safeLevel, experienceMode: experienceMode))"
        return try storeEditedWallpaper(
            updatePrompt: updatePrompt,
            prompt: masterPrompt,
            parentSceneKey: rootSceneKey,
            editedFromKey: currentSceneKey,
            imageData: editedImageData,
            screens: screens,
            persistSelection: true,
            createdAt: Date()
        )
    }

    @discardableResult
    func createAndApplySmartLockWallpaper(
        sourceImageData: Data,
        apiKey: String,
        to screens: [NSScreen] = NSScreen.screens,
        at date: Date = Date(),
        quality: GardenWallpaperGenerationQuality = .twoK,
        sceneKey: String? = nil
    ) async throws -> URL {
        try ensureDirectoryExists()
        try fileManager.createDirectory(at: smartLockWallpaperDirectoryURL, withIntermediateDirectories: true)

        let prompt = SmartLockWallpaperPrompt.masterPrompt(at: date)
        let editedImageData = try await editOpenAIImageData(
            prompt: prompt,
            imageData: sourceImageData,
            apiKey: apiKey,
            quality: quality
        )

        guard let image = NSImage(data: editedImageData),
              image.size.width > 0,
              image.size.height > 0 else {
            throw WallpaperManagerError.couldNotDecodeGeneratedImage
        }

        let baseURL = smartLockWallpaperDirectoryURL
            .appendingPathComponent(
                "smart-lock-\(smartLockSceneFilenameComponent(sceneKey ?? selectedWallpaperSceneKey))-\(Int(date.timeIntervalSince1970))"
            )
            .appendingPathExtension("png")
        let wallpaperURL = try renderSmartLockWallpaper(image, to: baseURL, screens: screens)
        try applyTemporaryWallpaperImage(wallpaperURL, to: screens)
        return wallpaperURL
    }

    func restoreSelectedWallpaperAfterSmartLock(to screens: [NSScreen] = NSScreen.screens, at date: Date = Date()) {
        _ = applyWallpaperSceneKey(selectedWallpaperSceneKey, to: screens, at: date, persistSelection: false)
    }

    @discardableResult
    func applyLatestSmartLockWallpaper(
        to screens: [NSScreen] = NSScreen.screens,
        sceneKey: String? = nil
    ) throws -> URL? {
        guard let wallpaperURL = latestSmartLockWallpaperURL(sceneKey: sceneKey ?? selectedWallpaperSceneKey) else {
            return nil
        }

        try applyTemporaryWallpaperImage(wallpaperURL, to: screens)
        return wallpaperURL
    }

    @discardableResult
    func storeEditedWallpaperForSelfTest(
        updatePrompt: String,
        parentSceneKey: String,
        editedFromKey: String,
        imageData: Data,
        createdAt: Date = Date()
    ) throws -> CustomWallpaperRecord {
        try storeEditedWallpaper(
            updatePrompt: updatePrompt,
            prompt: WallpaperEditPrompt.masterPrompt(from: updatePrompt),
            parentSceneKey: GardenWallpaperScene.canonicalKey(for: parentSceneKey),
            editedFromKey: GardenWallpaperScene.canonicalKey(for: editedFromKey),
            imageData: imageData,
            screens: [],
            persistSelection: false,
            createdAt: createdAt
        )
    }

    private func storeEditedWallpaper(
        updatePrompt: String,
        prompt: String,
        parentSceneKey: String,
        editedFromKey: String,
        imageData: Data,
        screens: [NSScreen],
        persistSelection: Bool,
        createdAt: Date
    ) throws -> CustomWallpaperRecord {
        guard let image = NSImage(data: imageData),
              image.size.width > 0,
              image.size.height > 0 else {
            throw WallpaperManagerError.couldNotDecodeGeneratedImage
        }

        try ensureDirectoryExists()
        try ensureCustomWallpaperDirectoryExists()

        let canonicalParentKey = GardenWallpaperScene.canonicalKey(for: parentSceneKey)
        let canonicalEditedFromKey = GardenWallpaperScene.canonicalKey(for: editedFromKey)
        let versionIndex = nextWallpaperVersionIndex(forRootKey: canonicalParentKey)
        let safeKey = uniqueSceneKey(prefix: "edit", source: updatePrompt)
        let imageURL = customWallpaperDirectoryURL.appendingPathComponent("\(safeKey).png")
        try imageData.write(to: imageURL, options: [.atomic])

        let record = CustomWallpaperRecord(
            key: safeKey,
            displayName: displayName(forWallpaperUpdate: updatePrompt, versionIndex: versionIndex),
            prompt: prompt,
            imageURL: imageURL,
            createdAt: createdAt,
            parentSceneKey: canonicalParentKey,
            editedFromKey: canonicalEditedFromKey,
            editPrompt: updatePrompt,
            versionIndex: versionIndex,
            experienceMode: experienceMode(forSceneRootKey: canonicalParentKey)
        )
        try upsertCustomWallpaperRecord(record)

        if persistSelection {
            try applyCustomWallpaper(record, to: screens, persistSelection: true)
        }

        return record
    }

    private func currentWallpaperReferenceImageData(
        sceneKey: String,
        screens: [NSScreen],
        at date: Date
    ) throws -> Data {
        if let desktopImageData = currentDesktopWallpaperImageData(for: screens) {
            return try normalizedPNGDataIfNeeded(desktopImageData)
        }

        let canonicalSceneKey = GardenWallpaperScene.canonicalKey(for: sceneKey)
        if let scene = GardenWallpaperScene.scene(forKey: canonicalSceneKey) {
            return try renderedLivingSceneWallpaperData(
                size: largestTargetSize(for: screens),
                phase: dayPhase(for: date),
                cyclePhase: GardenSceneDayCyclePhase(date: date),
                season: GardenSeasonCondition(at: date),
                scene: scene
            )
        }

        guard let record = customWallpapers.first(where: { $0.key == canonicalSceneKey }) else {
            throw WallpaperManagerError.couldNotLoadImage(directoryURL.appendingPathComponent("\(canonicalSceneKey).png"))
        }

        return try normalizedPNGDataIfNeeded(Data(contentsOf: record.imageURL))
    }

    private func currentDesktopWallpaperImageData(for screens: [NSScreen]) -> Data? {
        guard let screen = screens.max(by: { lhs, rhs in
            (lhs.frame.width * lhs.frame.height) < (rhs.frame.width * rhs.frame.height)
        }),
        let currentURL = NSWorkspace.shared.desktopImageURL(for: screen),
        fileManager.fileExists(atPath: currentURL.path),
        let data = try? Data(contentsOf: currentURL),
        NSImage(data: data) != nil else {
            return nil
        }

        return data
    }

    private func normalizedPNGDataIfNeeded(_ imageData: Data) throws -> Data {
        if imageData.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return imageData
        }

        guard let image = NSImage(data: imageData) else {
            throw WallpaperManagerError.couldNotDecodeGeneratedImage
        }

        return try pngData(from: image)
    }

    private func pngData(from image: NSImage) throws -> Data {
        let pixelWidth = max(1, Int(image.size.width.rounded()))
        let pixelHeight = max(1, Int(image.size.height.rounded()))

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw WallpaperManagerError.couldNotRenderWallpaper
        }

        bitmap.size = NSSize(width: pixelWidth, height: pixelHeight)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.imageInterpolation = .high
        let rect = NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        image.draw(
            in: rect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw WallpaperManagerError.couldNotRenderWallpaper
        }
        return pngData
    }

    private func wallpaperVersionRootKey(for sceneKey: String) -> String {
        let canonicalKey = GardenWallpaperScene.canonicalKey(for: sceneKey)
        guard let record = customWallpapers.first(where: { $0.key == canonicalKey }),
              let parentSceneKey = record.parentSceneKey,
              !parentSceneKey.isEmpty else {
            return canonicalKey
        }

        return GardenWallpaperScene.canonicalKey(for: parentSceneKey)
    }

    private func experienceMode(forSceneRootKey sceneKey: String) -> GardenExperienceMode {
        let canonicalKey = GardenWallpaperScene.canonicalKey(for: sceneKey)
        if let scene = GardenWallpaperScene.scene(forKey: canonicalKey) {
            return scene.experienceMode
        }

        return customWallpapers
            .first { $0.key == canonicalKey }?
            .experienceMode ?? .garden
    }

    private func originalWallpaperVersionEntry(
        forRootKey rootKey: String,
        records: [CustomWallpaperRecord]
    ) -> WallpaperVersionEntry? {
        if let scene = GardenWallpaperScene.scene(forKey: rootKey) {
            return WallpaperVersionEntry(
                key: scene.rawValue,
                title: "Original: \(scene.displayName)",
                tooltip: "Return to the original bundled scene.",
                createdAt: nil,
                isOriginal: true
            )
        }

        guard let record = records.first(where: { $0.key == rootKey }) else {
            return nil
        }

        return WallpaperVersionEntry(
            key: record.key,
            title: "Original: \(record.displayName)",
            tooltip: record.prompt,
            createdAt: record.createdAt,
            isOriginal: true
        )
    }

    private func nextWallpaperVersionIndex(forRootKey rootKey: String) -> Int {
        let existingMax = customWallpapers
            .filter { $0.parentSceneKey == rootKey }
            .compactMap(\.versionIndex)
            .max() ?? 0
        return existingMax + 1
    }

    /// Deletes a custom or AI wallpaper scene: removes its manifest record, its
    /// source image, and any derived per-screen renders. Returns `true` when the
    /// deleted scene was the selected one, so callers can apply a fallback scene.
    @discardableResult
    func deleteCustomWallpaper(key: String) throws -> Bool {
        var records = try loadCustomWallpaperRecords()
        guard let record = records.first(where: { $0.key == key }) else {
            return false
        }

        records.removeAll { $0.key == key }
        try saveCustomWallpaperRecords(records)
        removeFiles(for: record)

        let wasSelected = defaults.string(forKey: selectedSceneDefaultsKey) == key
        if wasSelected {
            clearSelectedSceneKey()
        }
        return wasSelected
    }

    /// Deletes one generated wallpaper version from the version history.
    /// Source and cached render files move to Trash by default so the user can
    /// recover them from Finder if needed. Returns a fallback scene key when
    /// the deleted version was active.
    @discardableResult
    func deleteWallpaperVersion(key: String, moveToTrash: Bool = true) throws -> String? {
        var records = try loadCustomWallpaperRecords()
        guard let recordIndex = records.firstIndex(where: { $0.key == key }) else {
            return nil
        }

        let record = records[recordIndex]
        guard let parentSceneKey = record.parentSceneKey, record.isWallpaperUpdate else {
            return nil
        }

        let rootKey = GardenWallpaperScene.canonicalKey(for: parentSceneKey)
        let wasSelected = defaults.string(forKey: selectedSceneDefaultsKey) == key
        let remainingRecords = records.filter { $0.key != key }
        let fallbackKey = remainingRecords
            .filter { $0.parentSceneKey == rootKey }
            .max { lhs, rhs in
                let lhsIndex = lhs.versionIndex ?? 0
                let rhsIndex = rhs.versionIndex ?? 0
                if lhsIndex != rhsIndex {
                    return lhsIndex < rhsIndex
                }
                return lhs.createdAt < rhs.createdAt
            }?
            .key ?? rootKey

        try removeFiles(for: record, moveToTrash: moveToTrash)
        records.remove(at: recordIndex)
        try saveCustomWallpaperRecords(records)

        if wasSelected {
            clearSelectedSceneKey()
            return fallbackKey
        }
        return nil
    }

    private func removeFiles(for record: CustomWallpaperRecord) {
        try? fileManager.removeItem(at: record.imageURL)

        // Derived per-screen renders are named "custom-<key>-...png" in the
        // wallpaper directory; remove any file that embeds the scene key.
        let derivedFiles = (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )) ?? []
        for fileURL in derivedFiles where fileURL.lastPathComponent.contains(record.key) {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private func removeFiles(for record: CustomWallpaperRecord, moveToTrash: Bool) throws {
        if fileManager.fileExists(atPath: record.imageURL.path) {
            try removeFile(at: record.imageURL, moveToTrash: moveToTrash)
        }

        // Derived per-screen renders are named "custom-<key>-...png" in the
        // wallpaper directory; move matching cached renders out with the source.
        let derivedFiles = (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )) ?? []
        for fileURL in derivedFiles where fileURL.lastPathComponent.contains(record.key) {
            try? removeFile(at: fileURL, moveToTrash: moveToTrash)
        }
    }

    private func removeFile(at url: URL, moveToTrash: Bool) throws {
        if moveToTrash {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
        } else {
            try fileManager.removeItem(at: url)
        }
    }

    func restorePreviousWallpapers(to screens: [NSScreen] = NSScreen.screens) {
        do {
            let snapshots = try loadSnapshots()
            for screen in screens {
                let screenID = screenID(for: screen)
                guard let snapshot = snapshots.first(where: { $0.screenID == screenID }) ?? snapshots.first else {
                    continue
                }

                try NSWorkspace.shared.setDesktopImageURL(snapshot.wallpaperURL, for: screen, options: [:])
            }
        } catch {
            NSLog("Plant Wallpaper could not restore the previous desktop background: \(error.localizedDescription)")
        }
    }

    /// Derived per-screen renders (scene × screen × size × season × phase)
    /// pile up forever otherwise - each is a multi-MB PNG and every one of
    /// them regenerates on demand, so pruning is always safe. Source images
    /// (AIWallpapers/, CustomWallpapers/) and JSON manifests live elsewhere
    /// or are non-PNG and are never touched.
    func pruneRenderedWallpaperCache(keepingNewest keepCount: Int = 12) {
        // A cache-hit render keeps its old modification date while a screen
        // is actively displaying it - never delete what's on a desktop now.
        let activeWallpaperPaths = Set(NSScreen.screens.compactMap { screen in
            NSWorkspace.shared.desktopImageURL(for: screen)?.standardizedFileURL.path
        })

        let cachedRenders = ((try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey]
        )) ?? []).filter { fileURL in
            fileURL.pathExtension.lowercased() == "png"
                && (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true
                && !activeWallpaperPaths.contains(fileURL.standardizedFileURL.path)
        }

        guard cachedRenders.count > keepCount else {
            return
        }

        let sortedByNewest = cachedRenders.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        for staleRender in sortedByNewest.dropFirst(keepCount) {
            try? fileManager.removeItem(at: staleRender)
        }
    }

    private func livingSceneWallpaperURL(for screen: NSScreen, at date: Date, scene: GardenWallpaperScene) throws -> URL {
        let phase = dayPhase(for: date)
        let cyclePhase = GardenSceneDayCyclePhase(date: date)
        let season = GardenSeasonCondition(at: date)
        let targetSize = targetSize(for: screen)
        let filename = [
            wallpaperVersion,
            scene.rawValue,
            cyclePhase.rawValue,
            safeFilenameComponent(screenID(for: screen)),
            "\(Int(targetSize.width))x\(Int(targetSize.height))",
            season.mood.rawValue,
            phase.rawValue
        ].joined(separator: "-") + ".png"
        let outputURL = directoryURL.appendingPathComponent(filename)

        guard !fileManager.fileExists(atPath: outputURL.path) else {
            return outputURL
        }

        try renderLivingSceneWallpaper(
            to: outputURL,
            size: targetSize,
            phase: phase,
            cyclePhase: cyclePhase,
            season: season,
            scene: scene
        )
        return outputURL
    }

    private func targetSize(for screen: NSScreen) -> NSSize {
        let scale = max(1, screen.backingScaleFactor)
        return NSSize(
            width: max(1280, screen.frame.width * scale),
            height: max(720, screen.frame.height * scale)
        )
    }

    private func largestTargetSize(for screens: [NSScreen]) -> NSSize {
        let sizes = screens.map { targetSize(for: $0) }
        guard !sizes.isEmpty else {
            return NSSize(width: 1536, height: 1024)
        }

        return sizes.max { ($0.width * $0.height) < ($1.width * $1.height) } ?? sizes[0]
    }

    private func customWallpaperURL(from record: CustomWallpaperRecord, for screen: NSScreen) throws -> URL {
        guard let image = NSImage(contentsOf: record.imageURL),
              image.size.width > 0,
              image.size.height > 0 else {
            throw WallpaperManagerError.couldNotLoadImage(record.imageURL)
        }

        let targetSize = targetSize(for: screen)
        let filename = [
            "custom-wallpaper",
            safeFilenameComponent(record.key),
            safeFilenameComponent(screenID(for: screen)),
            "\(Int(targetSize.width))x\(Int(targetSize.height))"
        ].joined(separator: "-") + ".png"
        let outputURL = directoryURL.appendingPathComponent(filename)

        guard !fileManager.fileExists(atPath: outputURL.path) else {
            return outputURL
        }

        try renderChosenWallpaper(image, to: outputURL, size: targetSize)
        return outputURL
    }

    private func applyCustomWallpaper(
        _ record: CustomWallpaperRecord,
        to screens: [NSScreen],
        persistSelection: Bool
    ) throws {
        try ensureDirectoryExists()
        try saveCurrentWallpaperSnapshotsIfNeeded(for: screens)

        if persistSelection {
            setSelectedSceneKey(record.key)
        }

        var firstWallpaperURL: URL?
        for screen in screens {
            let wallpaperURL = try customWallpaperURL(from: record, for: screen)
            if firstWallpaperURL == nil {
                firstWallpaperURL = wallpaperURL
            }
            try NSWorkspace.shared.setDesktopImageURL(wallpaperURL, for: screen, options: [:])
        }
        setCurrentWallpaperImageURL(firstWallpaperURL ?? record.imageURL)
        lastAppliedLivingGrade = nil
        pruneRenderedWallpaperCache()
    }

    private func renderSmartLockWallpaper(_ image: NSImage, to outputURL: URL, screens: [NSScreen]) throws -> URL {
        let targetSize = largestTargetSize(for: screens)
        try renderChosenWallpaper(image, to: outputURL, size: targetSize)
        return outputURL
    }

    private func applyTemporaryWallpaperImage(_ imageURL: URL, to screens: [NSScreen]) throws {
        for screen in screens {
            try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
        }
        setCurrentWallpaperImageURL(imageURL)
        lastAppliedLivingGrade = nil
    }

    private func setSelectedSceneKey(_ sceneKey: String) {
        defaults.set(sceneKey, forKey: selectedSceneDefaultsKey)
        mirrorSelectedSceneToSharedDefaults(sceneKey)
    }

    private func clearSelectedSceneKey() {
        defaults.removeObject(forKey: selectedSceneDefaultsKey)
        defaults.removeObject(forKey: currentWallpaperImageDefaultsKey)
        sharedDefaults?.removeObject(forKey: selectedSceneDefaultsKey)
        sharedDefaults?.removeObject(forKey: currentWallpaperImageDefaultsKey)
        sharedDefaults?.synchronize()
    }

    private func mirrorSelectedSceneToSharedDefaults(_ sceneKey: String) {
        sharedDefaults?.set(sceneKey, forKey: selectedSceneDefaultsKey)
        sharedDefaults?.synchronize()
    }

    private func setCurrentWallpaperImageURL(_ url: URL) {
        defaults.set(url.path, forKey: currentWallpaperImageDefaultsKey)
        sharedDefaults?.set(url.path, forKey: currentWallpaperImageDefaultsKey)
        sharedDefaults?.synchronize()
    }

    private func mirrorCurrentWallpaperImageToSharedDefaults() {
        guard let path = defaults.string(forKey: currentWallpaperImageDefaultsKey), !path.isEmpty else {
            return
        }

        sharedDefaults?.set(path, forKey: currentWallpaperImageDefaultsKey)
        sharedDefaults?.synchronize()
    }

    private func renderLivingSceneWallpaper(
        to outputURL: URL,
        size: NSSize,
        phase: DayPhase,
        cyclePhase: GardenSceneDayCyclePhase,
        season: GardenSeasonCondition,
        scene: GardenWallpaperScene
    ) throws {
        let pngData = try renderedLivingSceneWallpaperData(
            size: size,
            phase: phase,
            cyclePhase: cyclePhase,
            season: season,
            scene: scene
        )
        try pngData.write(to: outputURL, options: [.atomic])
    }

    private func renderChosenWallpaper(_ image: NSImage, to outputURL: URL, size: NSSize) throws {
        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw WallpaperManagerError.couldNotRenderWallpaper
        }

        bitmap.size = NSSize(width: pixelWidth, height: pixelHeight)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.imageInterpolation = .high
        let rect = NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        drawSceneImage(image, into: rect)
        drawReadableDesktopVignette(in: rect)
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw WallpaperManagerError.couldNotRenderWallpaper
        }

        try pngData.write(to: outputURL, options: [.atomic])
    }

    /// Artwork for a scene key - bundled scenes or custom/AI imports - for
    /// thumbnail galleries. Returns nil when no artwork exists.
    func thumbnailImage(forSceneKey key: String) -> NSImage? {
        if let scene = GardenWallpaperScene.scene(forKey: key) {
            return sceneImage(named: scene.rawValue)
        }

        let canonicalKey = GardenWallpaperScene.canonicalKey(for: key)
        guard let record = customWallpapers.first(where: { $0.key == canonicalKey }) else {
            return nil
        }

        return NSImage(contentsOf: record.imageURL)
    }

    func renderedLivingSceneWallpaperDataForSelfTest(
        scene: GardenWallpaperScene,
        size: NSSize,
        date: Date
    ) throws -> Data {
        try renderedLivingSceneWallpaperData(
            size: size,
            phase: dayPhase(for: date),
            cyclePhase: GardenSceneDayCyclePhase(date: date),
            season: GardenSeasonCondition(at: date),
            scene: scene
        )
    }

    func sceneImageNameForSelfTest(scene: GardenWallpaperScene, date: Date) -> String {
        sceneImageName(for: scene, cyclePhase: GardenSceneDayCyclePhase(date: date))
    }

    func bundledSceneImageExistsForSelfTest(named name: String) -> Bool {
        guard let url = sceneImageURL(named: name) else {
            return false
        }

        return NSImage(contentsOf: url) != nil
    }

    private func renderedLivingSceneWallpaperData(
        size: NSSize,
        phase: DayPhase,
        cyclePhase: GardenSceneDayCyclePhase,
        season: GardenSeasonCondition,
        scene: GardenWallpaperScene
    ) throws -> Data {
        let pixelWidth = max(1, Int(size.width.rounded()))
        let pixelHeight = max(1, Int(size.height.rounded()))

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw WallpaperManagerError.couldNotRenderWallpaper
        }

        let imageName = sceneImageName(for: scene, cyclePhase: cyclePhase)
        guard let sceneImage = sceneImage(named: imageName) else {
            throw WallpaperManagerError.couldNotLoadBundledSceneAsset(scene.rawValue)
        }

        bitmap.size = NSSize(width: pixelWidth, height: pixelHeight)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.imageInterpolation = .high

        let pixelSize = NSSize(width: pixelWidth, height: pixelHeight)
        let rect = NSRect(origin: .zero, size: pixelSize)
        drawSceneImage(sceneImage, into: rect)
        drawTimeOfDayGrade(in: rect, phase: phase)
        drawSeasonalSceneGrade(in: rect, season: season)
        drawSeasonalSceneTexture(in: rect, season: season)
        drawReadableDesktopVignette(in: rect)
        drawFinePaperGrain(size: pixelSize)
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw WallpaperManagerError.couldNotRenderWallpaper
        }

        return pngData
    }

    private func sceneImageName(for scene: GardenWallpaperScene, cyclePhase: GardenSceneDayCyclePhase) -> String {
        guard let dayCycleAssetName = scene.dayCycleAssetName(for: cyclePhase),
              sceneImageURL(named: dayCycleAssetName) != nil else {
            return scene.rawValue
        }

        return dayCycleAssetName
    }

    private func sceneImage(named name: String) -> NSImage? {
        guard let url = sceneImageURL(named: name) else {
            NSLog("Plant Wallpaper missing bundled scene asset URL: \(name).png")
            return nil
        }

        guard let image = NSImage(contentsOf: url) else {
            NSLog("Plant Wallpaper could not decode bundled scene asset: \(url.path)")
            return nil
        }

        image.cacheMode = .always
        return image
    }

    private func sceneImageURL(named name: String) -> URL? {
        for resourceRoot in sceneResourceRootCandidates() {
            let directURL = resourceRoot.appendingPathComponent("\(name).png")
            if fileManager.fileExists(atPath: directURL.path) {
                return directURL
            }

            let sceneAssetsURL = resourceRoot
                .appendingPathComponent("SceneAssets", isDirectory: true)
                .appendingPathComponent("\(name).png")
            if fileManager.fileExists(atPath: sceneAssetsURL.path) {
                return sceneAssetsURL
            }
        }

        return nil
    }

    private func sceneResourceRootCandidates() -> [URL] {
        var candidates: [URL] = []

        func appendIfUnique(_ url: URL?) {
            guard let url else {
                return
            }

            let standardizedURL = url.standardizedFileURL
            guard !candidates.contains(standardizedURL) else {
                return
            }
            candidates.append(standardizedURL)
        }

        appendIfUnique(Bundle.appResources.resourceURL)
        appendIfUnique(Bundle.main.bundleURL.appendingPathComponent(resourceBundleName, isDirectory: true))
        appendIfUnique(Bundle.main.resourceURL?.appendingPathComponent(resourceBundleName, isDirectory: true))
        appendIfUnique(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(resourceBundleName)", isDirectory: true))
        appendIfUnique(URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true))

        return candidates
    }

    private func drawSceneImage(_ image: NSImage, into rect: NSRect) {
        let sourceSize = image.size
        let sourceAspect = sourceSize.width / max(1, sourceSize.height)
        let targetAspect = rect.width / max(1, rect.height)
        let sourceRect: NSRect

        if targetAspect > sourceAspect {
            let cropHeight = sourceSize.width / targetAspect
            sourceRect = NSRect(
                x: 0,
                y: (sourceSize.height - cropHeight) / 2,
                width: sourceSize.width,
                height: cropHeight
            )
        } else {
            let cropWidth = sourceSize.height * targetAspect
            sourceRect = NSRect(
                x: (sourceSize.width - cropWidth) / 2,
                y: 0,
                width: cropWidth,
                height: sourceSize.height
            )
        }

        image.draw(
            in: rect,
            from: sourceRect,
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func drawTimeOfDayGrade(in rect: NSRect, phase: DayPhase) {
        let colors: [NSColor]
        switch phase {
        case .dawn:
            colors = [
                NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.48, alpha: 0.14),
                NSColor(calibratedRed: 0.72, green: 0.86, blue: 0.78, alpha: 0.04)
            ]
        case .day:
            colors = [
                NSColor(calibratedRed: 1.00, green: 0.96, blue: 0.72, alpha: 0.07),
                NSColor(calibratedRed: 0.76, green: 0.86, blue: 0.76, alpha: 0.02)
            ]
        case .evening:
            colors = [
                NSColor(calibratedRed: 1.00, green: 0.54, blue: 0.31, alpha: 0.13),
                NSColor(calibratedRed: 0.36, green: 0.34, blue: 0.52, alpha: 0.08)
            ]
        case .night:
            colors = [
                NSColor(calibratedRed: 0.28, green: 0.40, blue: 0.56, alpha: 0.16),
                NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.12, alpha: 0.12)
            ]
        }

        NSGradient(colors: colors)?.draw(in: rect, angle: phase == .night ? -90 : 30)
    }

    private func drawSeasonalSceneGrade(in rect: NSRect, season: GardenSeasonCondition) {
        let colors: [NSColor]
        switch season.mood {
        case .spring:
            colors = [
                NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.78, alpha: 0.045),
                NSColor(calibratedRed: 0.50, green: 0.76, blue: 0.48, alpha: 0.035)
            ]
        case .summer:
            colors = [
                NSColor(calibratedRed: 0.98, green: 0.90, blue: 0.54, alpha: 0.040),
                NSColor(calibratedRed: 0.24, green: 0.55, blue: 0.34, alpha: 0.040)
            ]
        case .autumn:
            colors = [
                NSColor(calibratedRed: 0.90, green: 0.48, blue: 0.25, alpha: 0.055),
                NSColor(calibratedRed: 0.48, green: 0.36, blue: 0.18, alpha: 0.035)
            ]
        case .winter:
            colors = [
                NSColor(calibratedRed: 0.78, green: 0.90, blue: 1.00, alpha: 0.055),
                NSColor(calibratedRed: 0.72, green: 0.78, blue: 0.82, alpha: 0.038)
            ]
        }

        NSGradient(colors: colors)?.draw(in: rect, angle: -90)
    }

    private func drawSeasonalSceneTexture(in rect: NSRect, season: GardenSeasonCondition) {
        let count = max(36, Int(rect.width / 44))
        for index in 0..<count {
            let x = CGFloat((index * 137) % max(1, Int(rect.width)))
            let y = rect.height * 0.60 + CGFloat((index * 71) % max(1, Int(rect.height * 0.35)))
            let size = CGFloat(2 + index % 4)
            switch season.mood {
            case .spring:
                drawSceneDot(
                    center: NSPoint(x: x, y: y),
                    radius: size * 0.42,
                    color: NSColor(calibratedRed: 1.00, green: 0.77, blue: 0.84, alpha: 0.12)
                )
            case .summer:
                drawSceneDot(
                    center: NSPoint(x: x, y: y),
                    radius: size * 0.36,
                    color: NSColor(calibratedRed: 0.72, green: 0.89, blue: 0.50, alpha: 0.10)
                )
            case .autumn:
                drawSceneLeaf(
                    center: NSPoint(x: x, y: y),
                    size: NSSize(width: size * 2.2, height: size),
                    angle: CGFloat((index * 23) % 80) - 40,
                    color: NSColor(calibratedRed: 0.95, green: 0.52, blue: 0.24, alpha: 0.12)
                )
            case .winter:
                drawSceneFrost(
                    center: NSPoint(x: x, y: y),
                    length: size * 2.8,
                    color: NSColor(calibratedWhite: 1, alpha: 0.12)
                )
            }
        }
    }

    private func drawSceneDot(center: NSPoint, radius: CGFloat, color: NSColor) {
        let path = NSBezierPath(ovalIn: NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        color.setFill()
        path.fill()
    }

    private func drawSceneLeaf(center: NSPoint, size: NSSize, angle: CGFloat, color: NSColor) {
        let path = NSBezierPath(ovalIn: NSRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        ))
        NSGraphicsContext.current?.cgContext.saveGState()
        NSGraphicsContext.current?.cgContext.translateBy(x: center.x, y: center.y)
        NSGraphicsContext.current?.cgContext.rotate(by: angle * .pi / 180)
        NSGraphicsContext.current?.cgContext.translateBy(x: -center.x, y: -center.y)
        color.setFill()
        path.fill()
        NSGraphicsContext.current?.cgContext.restoreGState()
    }

    private func drawSceneFrost(center: NSPoint, length: CGFloat, color: NSColor) {
        color.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x - length / 2, y: center.y))
        path.line(to: NSPoint(x: center.x + length / 2, y: center.y))
        path.move(to: NSPoint(x: center.x, y: center.y - length / 2))
        path.line(to: NSPoint(x: center.x, y: center.y + length / 2))
        path.lineWidth = 0.55
        path.stroke()
    }

    private func drawReadableDesktopVignette(in rect: NSRect) {
        NSGradient(colors: [
            NSColor(calibratedWhite: 1, alpha: 0.10),
            NSColor(calibratedWhite: 1, alpha: 0.02),
            NSColor(calibratedWhite: 0, alpha: 0.08)
        ])?.draw(in: rect, angle: -90)
    }

    private func drawFinePaperGrain(size: NSSize) {
        NSColor(calibratedWhite: 1, alpha: 0.025).setStroke()
        let count = max(90, Int(size.width / 18))
        for index in 0..<count {
            let x = CGFloat((index * 97) % max(1, Int(size.width)))
            let y = CGFloat((index * 53) % max(1, Int(size.height)))
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: y))
            path.line(to: NSPoint(x: x + CGFloat(index % 7), y: y + 0.5))
            path.lineWidth = 0.5
            path.stroke()
        }
    }

    private func dayPhase(for date: Date) -> DayPhase {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<10:
            return .dawn
        case 10..<17:
            return .day
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    private func ensureAIWallpaperDirectoryExists() throws {
        if !fileManager.fileExists(atPath: aiWallpaperDirectoryURL.path) {
            try fileManager.createDirectory(at: aiWallpaperDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func ensureCustomWallpaperDirectoryExists() throws {
        if !fileManager.fileExists(atPath: customWallpaperDirectoryURL.path) {
            try fileManager.createDirectory(at: customWallpaperDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func latestSmartLockWallpaperURL(sceneKey: String) -> URL? {
        let filenamePrefix = "smart-lock-\(smartLockSceneFilenameComponent(sceneKey))-"
        let files = (try? fileManager.contentsOfDirectory(
            at: smartLockWallpaperDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey]
        )) ?? []

        return files
            .filter { fileURL in
                fileURL.pathExtension.lowercased() == "png"
                    && fileURL.deletingPathExtension().lastPathComponent.hasPrefix(filenamePrefix)
                    && (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true
            }
            .max { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate < rhsDate
            }
    }

    private func smartLockSceneFilenameComponent(_ sceneKey: String) -> String {
        let safeSceneKey = safeFilenameComponent(GardenWallpaperScene.canonicalKey(for: sceneKey))
        return safeSceneKey.isEmpty ? "scene" : safeSceneKey
    }

    private func saveCurrentWallpaperSnapshotsIfNeeded(for screens: [NSScreen]) throws {
        let snapshots = screens.compactMap { screen -> WallpaperSnapshot? in
            guard let currentURL = NSWorkspace.shared.desktopImageURL(for: screen),
                  !currentURL.path.hasPrefix(directoryURL.path) else {
                return nil
            }

            return WallpaperSnapshot(screenID: screenID(for: screen), wallpaperURL: currentURL)
        }

        if !snapshots.isEmpty {
            try saveSnapshots(snapshots)
        }
    }

    private func saveSnapshots(_ snapshots: [WallpaperSnapshot]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshots)
        try data.write(to: snapshotURL, options: [.atomic])
    }

    private func loadSnapshots() throws -> [WallpaperSnapshot] {
        guard fileManager.fileExists(atPath: snapshotURL.path) else {
            return []
        }

        let data = try Data(contentsOf: snapshotURL)
        return try JSONDecoder().decode([WallpaperSnapshot].self, from: data)
    }

    private func loadCustomWallpaperRecords() throws -> [CustomWallpaperRecord] {
        guard fileManager.fileExists(atPath: customWallpaperManifestURL.path) else {
            return []
        }

        let data = try Data(contentsOf: customWallpaperManifestURL)
        return try JSONDecoder().decode([CustomWallpaperRecord].self, from: data)
    }

    private func saveCustomWallpaperRecords(_ records: [CustomWallpaperRecord]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: customWallpaperManifestURL, options: [.atomic])
    }

    private func upsertCustomWallpaperRecord(_ record: CustomWallpaperRecord) throws {
        var records = try loadCustomWallpaperRecords()
        records.removeAll { $0.key == record.key }
        records.insert(record, at: 0)

        let keptRecords = Array(records.prefix(20))
        try saveCustomWallpaperRecords(keptRecords)

        // Remove image files for records evicted by the cap so they don't
        // accumulate invisibly on disk.
        for evictedRecord in records.dropFirst(keptRecords.count) {
            removeFiles(for: evictedRecord)
        }
    }

    private func resolvedWallpaperSceneKey(_ sceneKey: String?) -> String {
        guard let sceneKey, !sceneKey.isEmpty else {
            return GardenWallpaperScene.defaultScene.rawValue
        }

        let canonicalSceneKey = GardenWallpaperScene.canonicalKey(for: sceneKey)
        if let scene = GardenWallpaperScene(rawValue: canonicalSceneKey) {
            guard scene.isSelectableScene else {
                return GardenExperienceModeScenePolicy.defaultScene(for: scene.experienceMode).rawValue
            }

            return canonicalSceneKey
        }

        if customWallpapers.contains(where: { $0.key == canonicalSceneKey }) {
            return canonicalSceneKey
        }

        return GardenWallpaperScene.defaultScene.rawValue
    }

    private func screenID(for screen: NSScreen) -> String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        let screenNumber = screen.deviceDescription[key] as? NSNumber
        return screenNumber?.stringValue ?? "\(Int(screen.frame.origin.x))-\(Int(screen.frame.origin.y))"
    }

    private func uniqueSceneKey(prefix: String, source: String) -> String {
        let safeSource = safeFilenameComponent(source)
        let sourceComponent = safeSource.isEmpty ? "wallpaper" : String(safeSource.prefix(34))
        let milliseconds = Int(Date().timeIntervalSince1970 * 1_000)
        let nonce = UUID().uuidString.prefix(8).lowercased()
        return "\(prefix)-\(sourceComponent)-\(milliseconds)-\(nonce)"
    }

    private func safeFilenameComponent(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).map { character in
            character.isLetter || character.isNumber ? character : "-"
        }
        .reduce(into: "") { $0.append($1) }
    }

    private func displayName(forAIPrompt prompt: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "AI Wallpaper"
        }

        return "AI: " + String(trimmed.prefix(42))
    }

    private func displayName(forChosenWallpaperName name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Custom Wallpaper"
        }

        return "Custom: " + String(trimmed.prefix(38))
    }

    private func displayName(forWallpaperUpdate prompt: String, versionIndex: Int) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Update \(versionIndex)"
        }

        return "Update \(versionIndex): " + String(trimmed.prefix(34))
    }

    private func wallpaperPrompt(from userPrompt: String) -> String {
        """
        Create a beautiful empty desktop wallpaper scene for a virtual garden app.
        User scene request: \(userPrompt)

        Hard constraints:
        - No plants, no trees, no flowers, no vines, no moss, no animals, no insects, no people.
        - Include empty planting plots, planters, soil beds, terraces, shelves, or clear gardenable spaces where separate app-rendered plants can be overlaid later.
        - No text, no UI, no logos, no labels.
        - Calm, premium, realistic environmental background with open negative space and readable contrast for desktop icons.
        - Wide landscape composition suitable for a Mac wallpaper.
        """
    }

    private func generateOpenAIImageData(
        prompt: String,
        apiKey: String,
        quality: GardenWallpaperGenerationQuality
    ) async throws -> Data {
        struct ImageResponse: Decodable {
            struct ImageItem: Decodable {
                let b64_json: String?
                let url: URL?
            }

            struct ErrorPayload: Decodable {
                let message: String?
            }

            let data: [ImageItem]?
            let error: ErrorPayload?
        }

        let requestURL = URL(string: "https://api.openai.com/v1/images/generations")!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180

        let body = WallpaperImageEditOpenAIConfiguration.requestBody(prompt: prompt, quality: quality)
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decodedResponse = try? JSONDecoder().decode(ImageResponse.self, from: data)

        guard (200..<300).contains(statusCode) else {
            let message = decodedResponse?.error?.message
                ?? String(data: data, encoding: .utf8)
                ?? "OpenAI image generation failed."
            throw WallpaperManagerError.openAIError(message)
        }

        if let base64Image = decodedResponse?.data?.first?.b64_json,
           let imageData = Data(base64Encoded: base64Image) {
            return imageData
        }

        if let imageURL = decodedResponse?.data?.first?.url {
            let (imageData, imageResponse) = try await URLSession.shared.data(from: imageURL)
            let imageStatusCode = (imageResponse as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(imageStatusCode) else {
                throw WallpaperManagerError.couldNotDecodeGeneratedImage
            }
            return imageData
        }

        throw WallpaperManagerError.couldNotDecodeGeneratedImage
    }

    private func editOpenAIImageData(
        prompt: String,
        imageData: Data,
        apiKey: String,
        quality: GardenWallpaperGenerationQuality = .twoK
    ) async throws -> Data {
        struct ImageResponse: Decodable {
            struct ImageItem: Decodable {
                let b64_json: String?
                let url: URL?
            }

            struct ErrorPayload: Decodable {
                let message: String?
            }

            let data: [ImageItem]?
            let error: ErrorPayload?
        }

        let requestURL = URL(string: "https://api.openai.com/v1/images/edits")!
        let boundary = "WallpaperGardenBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180
        request.httpBody = multipartImageEditBody(
            fields: WallpaperImageEditOpenAIConfiguration.multipartFields(prompt: prompt, quality: quality),
            imageData: imageData,
            boundary: boundary
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decodedResponse = try? JSONDecoder().decode(ImageResponse.self, from: data)

        guard (200..<300).contains(statusCode) else {
            let message = decodedResponse?.error?.message
                ?? String(data: data, encoding: .utf8)
                ?? "OpenAI image editing failed."
            throw WallpaperManagerError.openAIError(message)
        }

        if let base64Image = decodedResponse?.data?.first?.b64_json,
           let editedData = Data(base64Encoded: base64Image) {
            return editedData
        }

        if let imageURL = decodedResponse?.data?.first?.url {
            let (editedData, imageResponse) = try await URLSession.shared.data(from: imageURL)
            let imageStatusCode = (imageResponse as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(imageStatusCode) else {
                throw WallpaperManagerError.couldNotDecodeGeneratedImage
            }
            return editedData
        }

        throw WallpaperManagerError.couldNotDecodeGeneratedImage
    }

    private func multipartImageEditBody(fields: [String: String], imageData: Data, boundary: String) -> Data {
        var body = Data()

        func append(_ string: String) {
            body.append(Data(string.utf8))
        }

        for key in fields.keys.sorted() {
            guard let value = fields[key] else {
                continue
            }

            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            append("\(value)\r\n")
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image[]\"; filename=\"current-wallpaper.png\"\r\n")
        append("Content-Type: image/png\r\n\r\n")
        body.append(imageData)
        append("\r\n")
        append("--\(boundary)--\r\n")

        return body
    }
}
