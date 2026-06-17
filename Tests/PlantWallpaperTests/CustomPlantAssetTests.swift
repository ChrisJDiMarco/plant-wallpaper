import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Custom plant assets")
struct CustomPlantAssetTests {
    @Test("prompt keeps user description inside cutout asset constraints")
    func promptKeepsUserDescriptionInsideCutoutAssetConstraints() {
        let request = CustomPlantAssetRequest(
            kind: .flower,
            displayName: "Moon Tulip",
            userDescription: "a moonlit white tulip with glassy petals"
        )

        let prompt = CustomPlantAssetPrompt.masterPrompt(for: request)

        #expect(prompt.contains("User plant request: a moonlit white tulip with glassy petals"))
        #expect(prompt.contains("pure chroma-magenta background (#FF00FF)"))
        #expect(prompt.contains("#FF00FF background must be one uniform color"))
        #expect(prompt.contains("app will remove the #FF00FF background"))
        #expect(prompt.contains("Do not render a checkerboard"))
        #expect(prompt.contains("no pot"))
        #expect(prompt.contains("no scene"))
        #expect(CustomPlantAssetPrompt.baseSpecies(for: request) == .tulip)
    }

    @Test("alien UFO prompt uses exobiology asset constraints")
    func alienUFOPromptUsesExobiologyAssetConstraints() {
        let request = CustomPlantAssetRequest(
            kind: .foliage,
            displayName: "Plasma Fern",
            userDescription: "a translucent alien fern with cyan veins and floating seed nodules",
            experienceMode: .alienUFO
        )

        let prompt = CustomPlantAssetPrompt.masterPrompt(for: request)

        #expect(prompt.contains("WallpaperGarden Alien/UFO mode"))
        #expect(prompt.contains("User alien plant request: a translucent alien fern with cyan veins and floating seed nodules"))
        #expect(prompt.contains("Speculative exobiology"))
        #expect(prompt.contains("pure chroma-magenta background (#FF00FF)"))
        #expect(prompt.contains("no UFO, no alien creature, no planet scene"))
        #expect(prompt.contains("Bioluminescence is allowed"))
        #expect(CustomPlantAssetPrompt.baseSpecies(for: request) == .fern)
    }

    @Test("Room Studio plant prompt allows indoor planters")
    func roomStudioPlantPromptAllowsIndoorPlanters() {
        let request = CustomPlantAssetRequest(
            kind: .foliage,
            displayName: "Reading Nook Monstera",
            userDescription: "a lush monstera in a matte ceramic pot for a cozy bedroom corner",
            experienceMode: .roomStudio
        )

        let prompt = CustomPlantAssetPrompt.masterPrompt(for: request)

        #expect(prompt.contains("WallpaperGarden Room Studio"))
        #expect(prompt.contains("User indoor plant request: a lush monstera in a matte ceramic pot for a cozy bedroom corner"))
        #expect(prompt.contains("pure chroma-magenta background (#FF00FF)"))
        #expect(prompt.contains("A tasteful pot, planter, plant stand, or hanging planter is allowed"))
        #expect(prompt.contains("no full room scene"))
        #expect(!prompt.contains("no pot, no planter"))
        #expect(CustomPlantAssetPrompt.baseSpecies(for: request) == .monstera)
    }

    @Test("plant category menus put add new before random")
    func plantCategoryMenusPutAddNewBeforeRandom() {
        for kind in GardenPlantSpecificMenuCatalog.categoryOrder {
            #expect(GardenPlantCategoryMenuTitle.leadingTitles(for: kind) == [
                GardenPlantCategoryMenuTitle.addNewTitle(for: kind),
                GardenPlantCategoryMenuTitle.randomTitle(for: kind)
            ])
        }

        #expect(GardenPlantCategoryMenuTitle.leadingTitles(for: .tree) == [
            "Add New Tree...",
            "Random Tree Here"
        ])
        #expect(RoomStudioPlantMenuCatalog.leadingTitles == [
            "Add New Indoor Plant...",
            "Random Indoor Plant Here"
        ])
    }

    @Test("alien plant menus expose exobiology categories and specimen list")
    func alienPlantMenusExposeExobiologyCategoriesAndSpecimenList() {
        #expect(AlienPlantMenuCatalog.categoryOrder == [
            .flower,
            .tree,
            .foliage,
            .meadow,
            .edible
        ])
        #expect(AlienPlantMenuCatalog.title(for: .flower) == "Plant Alien Flower Here")
        #expect(AlienPlantMenuCatalog.addNewTitle(for: .tree) == "Add New Alien Tree...")
        #expect(AlienPlantMenuCatalog.specimens(in: .flower).map(\.title) == [
            "Nebula Orchid",
            "Ion Lily",
            "Pulsar Bloom",
            "Zero-G Glass Tulip",
            "Venusian Bellflower"
        ])
        #expect(AlienPlantMenuCatalog.specimens(in: .tree).contains {
            $0.title == "Saturn Ring Willow" && $0.promptSeed.contains("ringed canopy")
        })
        #expect(AlienPlantMenuCatalog.specimens(in: .edible).contains {
            $0.title == "Moon Melon Vine"
        })
    }

    @Test("bundled alien specimen assets are live custom plant assets")
    func bundledAlienSpecimenAssetsAreLiveCustomPlantAssets() {
        let library = AlienPlantAssetLibrary.shared
        let customAssets = CustomPlantAssetStore(baseDirectoryURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true))
        var seenIDs: Set<String> = []

        for specimen in AlienPlantMenuCatalog.specimens {
            let id = specimen.customAssetID
            #expect(id.hasPrefix(AlienPlantMenuCatalog.customAssetIDPrefix))
            #expect(seenIDs.insert(id).inserted)
            #expect(AlienPlantMenuCatalog.specimen(forCustomAssetID: id) == specimen)
            #expect(library.hasDisplayableAsset(for: specimen))
            #expect(library.image(for: specimen) != nil)
            #expect(library.record(for: specimen)?.id == id)

            guard let record = library.record(for: specimen) else {
                continue
            }
            let plant = Plant(
                species: record.baseSpecies,
                screenIndex: 0,
                position: GardenPoint(x: 0.5, y: 0.75),
                growth: 1,
                customAssetID: record.id
            )
            #expect(PlantDisplayAssetResolver.hasDisplayableAsset(for: plant, customAssets: customAssets))
            #expect(PlantDisplayAssetResolver.image(for: plant, customAssets: customAssets) != nil)
            #expect(PlantDisplayAssetResolver.alphaMask(for: plant, customAssets: customAssets) != nil)
        }

        #expect(seenIDs.count == AlienPlantMenuCatalog.specimens.count)
    }

    @Test("alien plant menu titles stay separate from terrestrial titles")
    func alienPlantMenuTitlesStaySeparateFromTerrestrialTitles() {
        #expect(GardenPlantCategoryMenuTitle.addNewTitle(for: .flower) == "Add New Flower...")
        #expect(AlienPlantMenuCatalog.addNewTitle(for: .flower) == "Add New Alien Flower...")
        #expect(AlienPlantMenuCatalog.randomTitle(for: .meadow) == "Random Alien Groundcover Here")
    }

    @Test("custom plant generation uses current OpenAI PNG configuration")
    func customPlantGenerationUsesCurrentOpenAIPNGConfiguration() throws {
        let body = CustomPlantAssetOpenAIConfiguration.requestBody(prompt: "a silver fern")

        #expect(body["model"] as? String == OpenAIImageGenerationConfiguration.primaryModel)
        #expect(body["model"] as? String == "gpt-image-2")
        #expect(body["prompt"] as? String == "a silver fern")
        #expect(body["output_format"] as? String == "png")
        #expect(body["background"] == nil)

        let encodedBody = try JSONSerialization.data(withJSONObject: body)
        let decodedBody = try #require(JSONSerialization.jsonObject(with: encodedBody) as? [String: Any])
        #expect(decodedBody["model"] as? String == "gpt-image-2")
        #expect(CustomPlantAssetOpenAIConfiguration.fallbackModels == ["gpt-image-1.5", "gpt-image-1", "gpt-image-1-mini"])
        #expect(OpenAIImageGenerationConfiguration.shouldTryNextModel(afterOpenAIError: "The model gpt-image-2 does not exist or you do not have access to it."))
        #expect(!OpenAIImageGenerationConfiguration.shouldTryNextModel(afterOpenAIError: "Your request was rejected by the safety system."))
        #expect(CustomPlantAssetOpenAIConfiguration.generationRequestTimeout >= 600)
        #expect(CustomPlantAssetOpenAIConfiguration.generatedImageDownloadTimeout >= 240)
    }

    @Test("custom room object generation uses generous OpenAI and download timeouts")
    func customRoomObjectGenerationUsesGenerousOpenAIAndDownloadTimeouts() async throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let imageURL = URL(string: "https://example.com/generated-room-object.png")!
        let httpClient = ScriptedCustomAssetHTTPClient(steps: [
            .response(
                statusCode: 200,
                url: URL(string: "https://api.openai.com/v1/images/generations")!,
                data: Data(#"{"data":[{"url":"\#(imageURL.absoluteString)"}]}"#.utf8)
            ),
            .response(statusCode: 200, url: imageURL, data: try fixture.pngData())
        ])
        let store = CustomPlantAssetStore(
            baseDirectoryURL: fixture.directoryURL,
            httpClient: httpClient
        )
        let request = CustomPlantAssetRequest(
            kind: .foliage,
            displayName: "Toy Shelf Cluster",
            userDescription: "a shelf cluster of vinyl toys, model cars, figures, and small display lamps",
            roomObjectCategory: .collectibles,
            roomPerspectiveContext: .inferred(from: GardenPoint(x: 0.50, y: 0.45)),
            experienceMode: .roomStudio
        )

        let record = try await store.createAsset(request: request, apiKey: "sk-test")
        let requests = await httpClient.capturedRequests()
        let generationRequest = try #require(requests.first)
        let downloadRequest = try #require(requests.dropFirst().first)
        let generationBodyData = try #require(generationRequest.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: generationBodyData) as? [String: Any])

        #expect(record.displayName == "Toy Shelf Cluster")
        #expect(record.roomObjectCategory == .collectibles)
        #expect(generationRequest.timeoutInterval == CustomPlantAssetOpenAIConfiguration.generationRequestTimeout)
        #expect(downloadRequest.url == imageURL)
        #expect(downloadRequest.timeoutInterval == CustomPlantAssetOpenAIConfiguration.generatedImageDownloadTimeout)
        #expect(body["model"] as? String == OpenAIImageGenerationConfiguration.primaryModel)
        #expect((body["prompt"] as? String)?.contains("WallpaperGarden Room Studio") == true)
        #expect((body["prompt"] as? String)?.contains("Room object category: Collectibles & Toys") == true)
    }

    @Test("custom asset timeout reports actionable generation failure")
    func customAssetTimeoutReportsActionableGenerationFailure() async throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let httpClient = ScriptedCustomAssetHTTPClient(steps: [
            .throwing(URLError(.timedOut))
        ])
        let store = CustomPlantAssetStore(
            baseDirectoryURL: fixture.directoryURL,
            httpClient: httpClient
        )
        let request = CustomPlantAssetRequest(
            kind: .foliage,
            displayName: "Low Record Shelf",
            userDescription: "a low walnut record shelf with stacked albums and a small lamp",
            roomObjectCategory: .mediaTech,
            roomPerspectiveContext: .inferred(from: GardenPoint(x: 0.42, y: 0.70)),
            experienceMode: .roomStudio
        )

        do {
            _ = try await store.createAsset(request: request, apiKey: "sk-test")
            Issue.record("Expected timeout to be surfaced as an actionable asset-generation error.")
        } catch CustomPlantAssetError.openAIError(let message) {
            #expect(message.localizedCaseInsensitiveContains("timed out"))
            #expect(message.localizedCaseInsensitiveContains("try again"))
            #expect(!message.localizedCaseInsensitiveContains("request timed out"))
        }

        #expect(await httpClient.requestCount() == 1)
        #expect(store.records.isEmpty)
    }

    @Test("room studio prompt injects category and perspective guidance")
    func roomStudioPromptInjectsCategoryAndPerspectiveGuidance() {
        let context = RoomObjectPerspectiveContext.inferred(from: GardenPoint(x: 0.18, y: 0.74))
        let request = CustomPlantAssetRequest(
            kind: .meadow,
            displayName: "Laundry Chair Pile",
            userDescription: "a messy chair covered in hoodies and jeans",
            roomObjectCategory: .softGoods,
            roomPerspectiveContext: context
        )

        let prompt = CustomPlantAssetPrompt.masterPrompt(for: request)

        #expect(prompt.contains("WallpaperGarden Room Studio"))
        #expect(prompt.contains("User room object request: a messy chair covered in hoodies and jeans"))
        #expect(prompt.contains("Room object category: Clothes & Soft Stuff"))
        #expect(prompt.contains("x 0.18, y 0.74"))
        #expect(prompt.contains("floor or low furniture zone"))
        #expect(prompt.contains("no full room scene"))
        #expect(prompt.contains("pure chroma-magenta background (#FF00FF)"))
        #expect(prompt.contains("#FF00FF background must be one uniform color"))
        #expect(prompt.contains("Match the perspective implied by the placement guidance"))
    }

    @Test("room studio catalog exposes object categories and starter templates")
    func roomStudioCatalogExposesObjectCategoriesAndStarterTemplates() {
        #expect(RoomStudioMenuCatalog.categoryOrder == [
            .wallDecor,
            .softGoods,
            .wardrobe,
            .mediaTech,
            .collectibles,
            .loungeGear
        ])
        #expect(RoomStudioMenuCatalog.templates(in: .wallDecor).contains { $0.title == "Gig Poster Wall Frame" })
        #expect(RoomStudioMenuCatalog.templates(in: .mediaTech).contains { $0.title == "Retro Console Stack" })
        #expect(RoomObjectCategory.loungeGear.starterDescription.contains("adult"))
        #expect(RoomObjectCategory.wallDecor.fallbackPlantKind == .foliage)
    }

    @Test("custom plant studio provides prompt helpers and button hover help")
    func customPlantStudioProvidesPromptHelpersAndButtonHoverHelp() {
        #expect(CustomPlantAssetPromptStudio.primaryButtonTooltip.contains("OpenAI PNG"))
        #expect(!CustomPlantAssetPromptStudio.cancelButtonTooltip.isEmpty)
        #expect(!CustomPlantAssetPromptStudio.useExampleTooltip.isEmpty)
        #expect(CustomPlantAssetPromptStudio.assetRules == [
            "PNG",
            "No pot",
            "No scene",
            "Centered"
        ])

        for kind in PlantKind.allCases {
            let starter = CustomPlantAssetPromptStudio.starterDescription(for: kind)
            let fragments = CustomPlantAssetPromptStudio.fragments(for: kind)

            #expect(starter.count > 40)
            #expect(fragments.count == 5)
            #expect(fragments.allSatisfy { !$0.title.isEmpty && !$0.insertion.isEmpty && !$0.tooltip.isEmpty })
            #expect(fragments.contains { $0.title == "Base" && $0.insertion.contains("no pot") })
        }
    }

    @Test("custom plant store persists generated PNG records")
    func customPlantStorePersistsGeneratedPNGRecords() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let store = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        let request = CustomPlantAssetRequest(
            kind: .foliage,
            displayName: "Mint Fern",
            userDescription: "a compact fern with pale mint leaf tips"
        )

        let record = try store.storeAssetForSelfTest(
            request: request,
            imageData: try fixture.pngData(),
            createdAt: Date(timeIntervalSince1970: 1_776_000_000)
        )

        #expect(store.records == [record])
        #expect(store.hasDisplayableAsset(forCustomAssetID: record.id))
        #expect(store.image(forCustomAssetID: record.id) != nil)
        #expect(store.alphaMask(forCustomAssetID: record.id) != nil)
        #expect(record.baseSpecies == .fern)

        let reloadedStore = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        #expect(reloadedStore.records == [record])
        #expect(reloadedStore.image(forCustomAssetID: record.id) != nil)
    }

    @Test("custom asset image cache evicts old decoded PNGs without losing records")
    func customAssetImageCacheEvictsOldDecodedPNGsWithoutLosingRecords() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let store = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        let imageData = try fixture.pngData()
        var records: [CustomPlantAssetRecord] = []

        for index in 0..<(CustomPlantAssetStore.imageCacheLimit + 4) {
            let request = CustomPlantAssetRequest(
                kind: .foliage,
                displayName: "Room Object \(index)",
                userDescription: "a generated room studio object \(index)",
                roomObjectCategory: .collectibles,
                experienceMode: .roomStudio
            )
            let record = try store.storeAssetForSelfTest(
                request: request,
                imageData: imageData,
                createdAt: Date(timeIntervalSince1970: 1_776_100_000 + Double(index))
            )
            records.append(record)
        }

        let firstRecord = try #require(records.first)
        #expect(store.records.count == CustomPlantAssetStore.imageCacheLimit + 4)
        #expect(store.imageCacheCountForSelfTest() == CustomPlantAssetStore.imageCacheLimit)
        #expect(!store.isImageCachedForSelfTest(id: firstRecord.id))
        #expect(store.image(forCustomAssetID: firstRecord.id) != nil)
        #expect(store.isImageCachedForSelfTest(id: firstRecord.id))
        #expect(store.imageCacheCountForSelfTest() == CustomPlantAssetStore.imageCacheLimit)
    }

    @Test("custom asset display readiness is cached for repeated render checks")
    func customAssetDisplayReadinessIsCachedForRepeatedRenderChecks() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let store = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        let request = CustomPlantAssetRequest(
            kind: .foliage,
            displayName: "Room Prop",
            userDescription: "a generated room studio prop",
            roomObjectCategory: .collectibles,
            experienceMode: .roomStudio
        )
        let record = try store.storeRawAssetForRepairTest(
            request: request,
            imageData: try fixture.transparentShelfWithEnclosedChromaPNGData()
        )

        #expect(store.displayableImageCacheCountForSelfTest() == 0)
        #expect(store.hasDisplayableAsset(forCustomAssetID: record.id))
        #expect(store.displayableImageCacheCountForSelfTest() == 1)

        for _ in 0..<12 {
            #expect(store.hasDisplayableAsset(forCustomAssetID: record.id))
        }

        #expect(store.displayableImageCacheCountForSelfTest() == 1)
        let repairedData = try Data(contentsOf: record.imageURL)
        #expect(!CustomPlantAssetPostProcessor.imageNeedsTransparencyRepair(repairedData))
    }

    @Test("custom plant store cuts out opaque checkerboard generations")
    func customPlantStoreCutsOutOpaqueCheckerboardGenerations() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let store = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        let request = CustomPlantAssetRequest(
            kind: .flower,
            displayName: "Alien Flower",
            userDescription: "an alien flower with violet tendrils"
        )

        let record = try store.storeAssetForSelfTest(
            request: request,
            imageData: try fixture.opaqueCheckerboardPNGData()
        )
        let storedData = try Data(contentsOf: record.imageURL)

        #expect(CustomPlantAssetPostProcessor.isDisplayReadyPNGData(storedData))
        #expect(NSImage(contentsOf: record.imageURL)?.representations.first?.hasAlpha == true)
        #expect(store.alphaMask(forCustomAssetID: record.id) != nil)
    }

    @Test("custom plant store cuts out chroma key generations")
    func customPlantStoreCutsOutChromaKeyGenerations() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let store = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        let request = CustomPlantAssetRequest(
            kind: .flower,
            displayName: "Neon Orchid",
            userDescription: "a green orchid generated on the required chroma key background"
        )

        let record = try store.storeAssetForSelfTest(
            request: request,
            imageData: try fixture.opaqueChromaMagentaPNGData()
        )
        let storedData = try Data(contentsOf: record.imageURL)
        let topLeft = try fixture.rgbaPixel(in: storedData, x: 2, y: 2)
        let center = try fixture.rgbaPixel(in: storedData, x: 80, y: 80)

        #expect(CustomPlantAssetPostProcessor.isDisplayReadyPNGData(storedData))
        #expect(topLeft.alpha == 0)
        #expect(topLeft.red == 0)
        #expect(topLeft.green == 0)
        #expect(topLeft.blue == 0)
        #expect(center.alpha > 200)
        #expect(center.green > center.red)
        #expect(center.green > center.blue)
        #expect(store.alphaMask(forCustomAssetID: record.id) != nil)
    }

    @Test("custom plant store cuts out enclosed chroma key holes")
    func customPlantStoreCutsOutEnclosedChromaKeyHoles() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let store = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        let request = CustomPlantAssetRequest(
            kind: .foliage,
            displayName: "Collectible Shelf",
            userDescription: "a wooden room shelf with open cubbies",
            roomObjectCategory: .collectibles,
            experienceMode: .roomStudio
        )

        let record = try store.storeAssetForSelfTest(
            request: request,
            imageData: try fixture.enclosedChromaShelfPNGData()
        )
        let storedData = try Data(contentsOf: record.imageURL)
        let outside = try fixture.rgbaPixel(in: storedData, x: 2, y: 2)
        let enclosedHole = try fixture.rgbaPixel(in: storedData, x: 82, y: 64)
        let shelfRail = try fixture.rgbaPixel(in: storedData, x: 82, y: 80)
        let purpleCollectible = try fixture.rgbaPixel(in: storedData, x: 34, y: 130)

        #expect(CustomPlantAssetPostProcessor.isDisplayReadyPNGData(storedData))
        #expect(outside.alpha == 0)
        #expect(enclosedHole.alpha == 0)
        #expect(enclosedHole.red == 0)
        #expect(enclosedHole.green == 0)
        #expect(enclosedHole.blue == 0)
        #expect(shelfRail.alpha > 220)
        #expect(purpleCollectible.alpha > 220)
    }

    @Test("custom plant store repairs existing opaque records when loaded")
    func customPlantStoreRepairsExistingOpaqueRecordsWhenLoaded() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let store = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        let request = CustomPlantAssetRequest(
            kind: .flower,
            displayName: "Alien Flower",
            userDescription: "an alien flower with violet tendrils"
        )
        let record = try store.storeRawAssetForRepairTest(
            request: request,
            imageData: try fixture.opaqueCheckerboardPNGData()
        )
        let reloadedStore = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)

        #expect(reloadedStore.hasDisplayableAsset(forCustomAssetID: record.id))
        let repairedData = try Data(contentsOf: record.imageURL)
        #expect(CustomPlantAssetPostProcessor.isDisplayReadyPNGData(repairedData))
    }

    @Test("custom plant store repairs display ready records with enclosed chroma")
    func customPlantStoreRepairsDisplayReadyRecordsWithEnclosedChroma() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let store = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        let request = CustomPlantAssetRequest(
            kind: .foliage,
            displayName: "Open Shelf",
            userDescription: "a shelf with open cubbies",
            roomObjectCategory: .collectibles,
            experienceMode: .roomStudio
        )
        let record = try store.storeRawAssetForRepairTest(
            request: request,
            imageData: try fixture.transparentShelfWithEnclosedChromaPNGData()
        )

        let unrepairedData = try Data(contentsOf: record.imageURL)
        #expect(CustomPlantAssetPostProcessor.isDisplayReadyPNGData(unrepairedData))
        #expect(CustomPlantAssetPostProcessor.imageNeedsTransparencyRepair(unrepairedData))

        let reloadedStore = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        #expect(reloadedStore.hasDisplayableAsset(forCustomAssetID: record.id))
        let repairedData = try Data(contentsOf: record.imageURL)
        let enclosedHole = try fixture.rgbaPixel(in: repairedData, x: 82, y: 64)
        let shelfRail = try fixture.rgbaPixel(in: repairedData, x: 82, y: 80)

        #expect(!CustomPlantAssetPostProcessor.imageNeedsTransparencyRepair(repairedData))
        #expect(enclosedHole.alpha == 0)
        #expect(shelfRail.alpha > 220)
    }

    @Test("custom plant records can be planted and survive display cleanup")
    func customPlantRecordsCanBePlantedAndSurviveDisplayCleanup() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let customAssets = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        let request = CustomPlantAssetRequest(
            kind: .edible,
            displayName: "Golden Tomato",
            userDescription: "a compact golden tomato plant with ripe fruit"
        )
        let record = try customAssets.storeAssetForSelfTest(
            request: request,
            imageData: try fixture.pngData()
        )
        let store = GardenStore(
            state: GardenState(plants: []),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL),
            activeSceneKey: "empty-conservatory-hall",
            customPlantAssets: customAssets
        )

        store.addCustomPlant(
            record,
            screenIndex: 0,
            position: GardenPoint(x: 0.42, y: 0.76)
        )
        let plant = try #require(store.state.plants.first)

        #expect(plant.customAssetID == record.id)
        #expect(plant.species == record.baseSpecies)
        #expect(plant.nickname == "Golden Tomato")
        #expect(store.selectedPlantID == plant.id)
        #expect(PlantDisplayAssetResolver.image(for: plant, customAssets: customAssets) != nil)

        store.removePlantsWithoutDisplayableAssets()
        #expect(store.state.plants.map(\.id) == [plant.id])
    }

    @Test("custom plant storage summary and cleanup remove generated files")
    func customPlantStorageSummaryAndCleanupRemoveGeneratedFiles() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let store = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        let request = CustomPlantAssetRequest(
            kind: .tree,
            displayName: "Glass Bonsai",
            userDescription: "a tiny translucent bonsai with crystalline leaves"
        )
        let record = try store.storeAssetForSelfTest(
            request: request,
            imageData: try fixture.pngData()
        )

        let summary = store.inventorySummary()
        #expect(summary.assetCount == 1)
        #expect(summary.byteCount > 0)
        #expect(FileManager.default.fileExists(atPath: record.imageURL.path))

        #expect(store.deleteAsset(id: record.id))
        #expect(store.records.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: record.imageURL.path))

        _ = try store.storeAssetForSelfTest(request: request, imageData: try fixture.pngData())
        store.deleteAllAssets()
        #expect(store.records.isEmpty)
        #expect(store.inventorySummary().assetCount == 0)
    }

    @Test("pending custom plant placeholders are transient")
    func pendingCustomPlantPlaceholdersAreTransient() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let store = GardenStore(
            state: GardenState(plants: []),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL),
            activeSceneKey: "empty-conservatory-hall"
        )
        let pendingID = store.beginPendingCustomPlantAsset(
            displayName: "Moon Fern",
            kind: .foliage,
            screenIndex: 0,
            position: GardenPoint(x: 0.45, y: 0.72),
            startedAt: Date(timeIntervalSince1970: 1_776_000_000)
        )

        #expect(store.hasPendingCustomPlantAssets)
        #expect(store.pendingCustomPlantAssets.count == 1)
        #expect(store.state.plants.isEmpty)
        store.save()

        let reloadedState = try #require(try store.persistence.load(sceneKey: "empty-conservatory-hall"))
        #expect(reloadedState.plants.isEmpty)

        store.finishPendingCustomPlantAsset(id: pendingID)
        #expect(!store.hasPendingCustomPlantAssets)
    }

    @Test("pending custom asset placeholders can be repositioned before completion")
    func pendingCustomAssetPlaceholdersCanBeRepositionedBeforeCompletion() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let store = GardenStore(
            state: GardenState(plants: []),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL),
            activeSceneKey: "empty-conservatory-hall"
        )
        let pendingID = store.beginPendingCustomPlantAsset(
            displayName: "Hologram Fern",
            kind: .foliage,
            screenIndex: 0,
            position: GardenPoint(x: 0.40, y: 0.70)
        )

        store.movePendingCustomPlantAsset(
            id: pendingID,
            to: GardenPoint(x: 0.68, y: 0.42),
            screenIndex: 1
        )

        let pending = try #require(store.pendingCustomPlantAsset(id: pendingID))
        #expect(pending.position == GardenPoint(x: 0.68, y: 0.42))
        #expect(pending.screenIndex == 1)
    }

    @Test("Room Studio template assets are reused after generation")
    func roomStudioTemplateAssetsAreReusedAfterGeneration() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let assetStore = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        let originalRequest = CustomPlantAssetRequest(
            kind: .foliage,
            displayName: "Retro Console Stack",
            userDescription: "stacked retro game consoles, controllers, cartridges, and coiled cables",
            roomObjectCategory: .mediaTech,
            roomPerspectiveContext: .inferred(from: GardenPoint(x: 0.20, y: 0.74)),
            experienceMode: .roomStudio
        )
        let record = try assetStore.storeAssetForSelfTest(
            request: originalRequest,
            imageData: try fixture.pngData()
        )
        let nextPlacementRequest = CustomPlantAssetRequest(
            kind: .foliage,
            displayName: "Retro Console Stack",
            userDescription: "stacked retro game consoles, controllers, cartridges, and coiled cables",
            roomObjectCategory: .mediaTech,
            roomPerspectiveContext: .inferred(from: GardenPoint(x: 0.80, y: 0.45)),
            experienceMode: .roomStudio
        )

        let reusableRecord = try #require(assetStore.reusableRoomObjectAsset(for: nextPlacementRequest))
        #expect(reusableRecord.id == record.id)
        #expect(record.roomObjectCategory == .mediaTech)
        #expect(assetStore.isRoomObjectAsset(forCustomAssetID: record.id))
    }

    @Test("Room Studio objects can resize much larger than garden plants")
    func roomStudioObjectsCanResizeMuchLargerThanGardenPlants() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let assetStore = CustomPlantAssetStore(baseDirectoryURL: fixture.directoryURL)
        let request = CustomPlantAssetRequest(
            kind: .foliage,
            displayName: "Toy Shelf Cluster",
            userDescription: "a shelf cluster of vinyl toys, model cars, figures, and small display lamps",
            roomObjectCategory: .collectibles,
            roomPerspectiveContext: .inferred(from: GardenPoint(x: 0.50, y: 0.45)),
            experienceMode: .roomStudio
        )
        let record = try assetStore.storeAssetForSelfTest(
            request: request,
            imageData: try fixture.pngData()
        )
        let plant = Plant(
            species: .monstera,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.60),
            growth: 1.0,
            hydration: 0.82,
            health: 0.88,
            scale: 1.0,
            customAssetID: record.id
        )
        let store = GardenStore(
            state: GardenState(plants: [plant], settings: .default.updating(experienceMode: .roomStudio)),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL),
            activeSceneKey: GardenWallpaperScene.roomModernBedroomCanvas.rawValue,
            customPlantAssets: assetStore
        )
        store.setSelectedPlant(plant.id)

        store.resizeSelectedPlant(toScale: 7.25)

        let resized = try #require(store.state.plants.first)
        #expect(resized.scale == 7.25)
    }

    @Test("pending custom asset animation targets 60fps")
    func pendingCustomAssetAnimationTargets60FPS() {
        #expect(GardenCanvasView.pendingCustomAssetAnimationInterval == 1.0 / 60.0)
    }

    @Test("pending custom asset placeholders drag through canvas interactions")
    func pendingCustomAssetPlaceholdersDragThroughCanvasInteractions() throws {
        let fixture = try TemporaryCustomPlantFixture()
        defer { fixture.cleanup() }
        let store = GardenStore(
            state: GardenState(plants: []),
            persistence: GardenPersistence(directoryURL: fixture.directoryURL),
            activeSceneKey: "empty-conservatory-hall"
        )
        let pendingID = store.beginPendingCustomPlantAsset(
            displayName: "Loading Lamp",
            kind: .foliage,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.70)
        )
        let canvasView = GardenCanvasView(
            frame: NSRect(x: 0, y: 0, width: 1_000, height: 800),
            screenIndex: 0,
            store: store
        )
        let startPoint = NSPoint(x: 500, y: 560)

        #expect(canvasView.containsInteractiveElement(at: startPoint))
        #expect(canvasView.beginGardenInteraction(at: startPoint) == .drag)
        #expect(canvasView.continuePlantDrag(at: NSPoint(x: 650, y: 500)))
        #expect(canvasView.endPlantDrag())

        let pending = try #require(store.pendingCustomPlantAsset(id: pendingID))
        #expect(abs(pending.position.x - 0.65) < 0.001)
        #expect(abs(pending.position.y - 0.625) < 0.001)
    }
}

private final class TemporaryCustomPlantFixture {
    let directoryURL: URL

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CustomPlantAssetTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func pngData() throws -> Data {
        let size = NSSize(width: 40, height: 40)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw CocoaError(.fileWriteUnknown)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor(calibratedRed: 0.30, green: 0.68, blue: 0.42, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 8, y: 6, width: 24, height: 28)).fill()
        NSGraphicsContext.restoreGraphicsState()

        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    func opaqueCheckerboardPNGData() throws -> Data {
        let size = NSSize(width: 160, height: 160)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw CocoaError(.fileWriteUnknown)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        for y in stride(from: 0, to: Int(size.height), by: 16) {
            for x in stride(from: 0, to: Int(size.width), by: 16) {
                let isLight = ((x / 16) + (y / 16)).isMultiple(of: 2)
                (isLight ? NSColor(calibratedWhite: 0.96, alpha: 1) : NSColor(calibratedWhite: 0.82, alpha: 1)).setFill()
                NSRect(x: x, y: y, width: 16, height: 16).fill()
            }
        }
        NSColor(calibratedRed: 0.34, green: 0.73, blue: 0.42, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 54, y: 28, width: 52, height: 102)).fill()
        NSColor(calibratedRed: 0.46, green: 0.20, blue: 0.70, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 38, y: 92, width: 84, height: 42)).fill()
        NSGraphicsContext.restoreGraphicsState()

        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    func opaqueChromaMagentaPNGData() throws -> Data {
        let size = NSSize(width: 160, height: 160)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw CocoaError(.fileWriteUnknown)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor(calibratedRed: 1, green: 0, blue: 1, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        NSColor(calibratedRed: 0.24, green: 0.78, blue: 0.36, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 54, y: 28, width: 52, height: 104)).fill()
        NSColor(calibratedRed: 0.72, green: 0.92, blue: 0.48, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 34, y: 92, width: 92, height: 42)).fill()
        NSGraphicsContext.restoreGraphicsState()

        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    func enclosedChromaShelfPNGData() throws -> Data {
        let size = NSSize(width: 180, height: 160)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw CocoaError(.fileWriteUnknown)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor(calibratedRed: 1, green: 0, blue: 1, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()

        NSColor(calibratedRed: 0.24, green: 0.12, blue: 0.07, alpha: 1).setFill()
        NSRect(x: 18, y: 28, width: 144, height: 10).fill()
        NSRect(x: 18, y: 76, width: 144, height: 10).fill()
        NSRect(x: 18, y: 124, width: 144, height: 10).fill()
        NSRect(x: 18, y: 28, width: 10, height: 106).fill()
        NSRect(x: 152, y: 28, width: 10, height: 106).fill()
        NSRect(x: 86, y: 28, width: 8, height: 106).fill()

        NSColor(calibratedRed: 0.34, green: 0.18, blue: 0.10, alpha: 1).setFill()
        NSRect(x: 10, y: 22, width: 160, height: 8).fill()

        NSColor(calibratedRed: 0.38, green: 0.18, blue: 0.70, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 28, y: 120, width: 18, height: 18)).fill()
        NSGraphicsContext.restoreGraphicsState()

        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    func transparentShelfWithEnclosedChromaPNGData() throws -> Data {
        let size = NSSize(width: 180, height: 160)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw CocoaError(.fileWriteUnknown)
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        NSColor(calibratedRed: 1, green: 0, blue: 1, alpha: 1).setFill()
        NSRect(x: 28, y: 38, width: 58, height: 38).fill()
        NSRect(x: 94, y: 38, width: 58, height: 38).fill()
        NSRect(x: 28, y: 86, width: 58, height: 38).fill()
        NSRect(x: 94, y: 86, width: 58, height: 38).fill()

        NSColor(calibratedRed: 0.24, green: 0.12, blue: 0.07, alpha: 1).setFill()
        NSRect(x: 18, y: 28, width: 144, height: 10).fill()
        NSRect(x: 18, y: 76, width: 144, height: 10).fill()
        NSRect(x: 18, y: 124, width: 144, height: 10).fill()
        NSRect(x: 18, y: 28, width: 10, height: 106).fill()
        NSRect(x: 152, y: 28, width: 10, height: 106).fill()
        NSRect(x: 86, y: 28, width: 8, height: 106).fill()
        NSGraphicsContext.restoreGraphicsState()

        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    func rgbaPixel(in imageData: Data, x: Int, y: Int) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              x >= 0,
              y >= 0,
              x < cgImage.width,
              y < cgImage.height else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let width = cgImage.width
        let height = cgImage.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = buffer.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress,
                  let context = CGContext(
                      data: baseAddress,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: width * 4,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let offset = (y * width + x) * 4
        return (buffer[offset], buffer[offset + 1], buffer[offset + 2], buffer[offset + 3])
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

private actor ScriptedCustomAssetHTTPClient: CustomPlantAssetHTTPClient {
    enum Step {
        case response(statusCode: Int, url: URL, data: Data)
        case throwing(Error)
    }

    private var steps: [Step]
    private var requests: [URLRequest] = []

    init(steps: [Step]) {
        self.steps = steps
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !steps.isEmpty else {
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(#"{"error":{"message":"No scripted custom asset response."}}"#.utf8), response)
        }

        let step = steps.removeFirst()
        switch step {
        case .response(let statusCode, let url, let data):
            let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        case .throwing(let error):
            throw error
        }
    }

    func capturedRequests() -> [URLRequest] {
        requests
    }

    func requestCount() -> Int {
        requests.count
    }
}
