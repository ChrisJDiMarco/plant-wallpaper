import AppKit
import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Garden assistant command center")
struct GardenAssistantCommandCenterTests {
    @Test("assistant copy matches the Jarvis desktop command layer")
    func assistantCopyMatchesJarvisCommandLayer() {
        #expect(GardenAssistantCopy.windowTitle == "Jarvis Assistant")
        #expect(GardenAssistantCopy.projectTitle == "Life Command")
        #expect(GardenAssistantCopy.commandPlaceholder == "Give Jarvis a task...")
        #expect(GardenAssistantCopy.quickPrompts.count == 4)
        #expect(GardenAssistantCopy.quickPrompts.contains("Summarize my day"))
        #expect(GardenAssistantCopy.quickPrompts.contains("Draft a reply"))
        #expect(!GardenAssistantCopy.quickPrompts.contains("Improve my current garden"))
        #expect(GardenAssistantCopy.sidebarSteps.first?.title == "Capture")
        #expect(GardenAssistantCopy.sidebarSteps.count == 4)
        #expect(!GardenAssistantCopy.sidebarSteps.contains { $0.state == .pending })
        #expect(!GardenAssistantCopy.footerNote.localizedCaseInsensitiveContains("garden"))
    }

    @Test("assistant view model routes common commands to useful workspaces")
    func assistantViewModelRoutesCommonCommands() {
        #expect(GardenAssistantWorkspace.route(for: "research sustainable gardening") == .research)
        #expect(GardenAssistantWorkspace.route(for: "fix this Swift bug with codex") == .coding)
        #expect(GardenAssistantWorkspace.route(for: "check my important emails") == .inbox)
        #expect(GardenAssistantWorkspace.route(for: "what is on my calendar today") == .day)
        #expect(GardenAssistantWorkspace.route(for: "hello") == .overview)
    }

    @Test("assistant local responder gives context aware next actions without API")
    func assistantLocalResponderGivesContextAwareNextActionsWithoutAPI() throws {
        let state = GardenState(
            plants: [
                Plant(
                    species: .determinateTomato,
                    screenIndex: 0,
                    position: GardenPoint(x: 0.45, y: 0.82),
                    growth: 1,
                    hydration: 0.66,
                    health: 0.84
                )
            ],
            settings: GardenSettings(experienceMode: .garden),
            seedInventory: ["rose": 2],
            harvestTally: ["determinate-tomato": 3]
        )
        let context = GardenAssistantRuntimeContext(
            state: state,
            activeSceneDisplayName: "Cottage Backyard Garden",
            activeSceneKey: GardenWallpaperScene.cottageBackyardGarden.rawValue,
            selectedPlant: state.plants[0]
        )

        let response = try #require(GardenAssistantLocalResponder.response(
            for: "what should I do next?",
            context: context
        ))

        #expect(response.localizedCaseInsensitiveContains("Miso"))
        #expect(response.localizedCaseInsensitiveContains("life move"))
        #expect(response.localizedCaseInsensitiveContains("desktop has 1 ready"))
        #expect(response.localizedCaseInsensitiveContains("no api call"))
    }

    @Test("assistant local responder explains controls and privacy honestly")
    func assistantLocalResponderRoutesAppHelpToCatAndExplainsPrivacyHonestly() throws {
        let controls = try #require(GardenAssistantLocalResponder.response(
            for: "explain this app's controls",
            context: nil
        ))
        let privacy = try #require(GardenAssistantLocalResponder.response(
            for: "what about privacy and api costs?",
            context: nil
        ))

        #expect(controls.contains("Miso"))
        #expect(controls.localizedCaseInsensitiveContains("cat"))
        #expect(controls.localizedCaseInsensitiveContains("WallpaperGarden"))
        #expect(privacy.contains("Keychain"))
        #expect(privacy.contains("OpenAI"))
        #expect(!privacy.localizedCaseInsensitiveContains("gmail"))
        #expect(!controls.localizedCaseInsensitiveContains("calendar"))
    }

    @Test("assistant local responder explains capabilities without API")
    func assistantLocalResponderExplainsCapabilitiesWithoutAPI() throws {
        let response = try #require(GardenAssistantLocalResponder.response(
            for: "what can you do?",
            context: nil
        ))

        #expect(response.localizedCaseInsensitiveContains("without an API call"))
        #expect(response.localizedCaseInsensitiveContains("plan"))
        #expect(response.localizedCaseInsensitiveContains("draft"))
        #expect(response.localizedCaseInsensitiveContains("privacy"))
        #expect(response.localizedCaseInsensitiveContains("OpenAI"))
        #expect(!response.localizedCaseInsensitiveContains("gmail"))
        #expect(!response.localizedCaseInsensitiveContains("calendar"))
    }

    @Test("assistant local responder is honest about unavailable external connectors")
    func assistantLocalResponderIsHonestAboutUnavailableExternalConnectors() throws {
        let response = try #require(GardenAssistantLocalResponder.response(
            for: "check my Gmail and Slack and tell me what's on my calendar",
            context: nil
        ))

        #expect(response.localizedCaseInsensitiveContains("cannot access"))
        #expect(response.localizedCaseInsensitiveContains("external accounts"))
        #expect(response.localizedCaseInsensitiveContains("not connected"))
        #expect(response.localizedCaseInsensitiveContains("without an API call"))
        #expect(response.contains("Gmail"))
        #expect(response.contains("Slack"))
        #expect(response.contains("calendar"))
        #expect(!response.localizedCaseInsensitiveContains("I checked"))
    }

    @Test("assistant local responder does not treat ordinary click bug reports as controls")
    func assistantLocalResponderDoesNotTreatOrdinaryClickBugReportsAsControls() {
        let response = GardenAssistantLocalResponder.response(
            for: "when I click the plant behind the cat it selects the wrong thing",
            context: nil
        )

        #expect(response == nil)
    }

    @Test("assistant local responder does not intercept open ended creative prompts")
    func assistantLocalResponderDoesNotInterceptOpenEndedCreativePrompts() {
        #expect(GardenAssistantLocalResponder.response(
            for: "write a poetic concept for a neon greenhouse world",
            context: nil
        ) == nil)
    }

    @Test("assistant request body uses the Responses API shape")
    func assistantRequestBodyUsesResponsesAPIShape() throws {
        let messages = [
            GardenAssistantMessage(role: .user, text: "Help me plan this garden."),
            GardenAssistantMessage(role: .assistant, text: "Start with light and scale."),
            GardenAssistantMessage(role: .user, text: "Now make it calmer.")
        ]

        let body = GardenAssistantOpenAIConfiguration.requestBody(
            messages: messages,
            model: GardenAssistantOpenAIConfiguration.primaryModel
        )

        #expect(body["model"] as? String == "gpt-5.5")
        #expect(body["store"] as? Bool == false)
        #expect(body["instructions"] as? String != nil)
        #expect((body["instructions"] as? String)?.contains("personal AI command center") == true)
        #expect((body["instructions"] as? String)?.contains("Miso") == true)
        let input = try #require(body["input"] as? [[String: String]])
        #expect(input.map { $0["role"] } == ["user", "assistant", "user"])
        #expect(input.last?["content"] == "Now make it calmer.")
        let reasoning = try #require(body["reasoning"] as? [String: String])
        #expect(reasoning["effort"] == "low")
    }

    @Test("assistant request input is bounded for responsiveness and API cost")
    func assistantRequestInputIsBoundedForResponsivenessAndAPICost() throws {
        let maximumShippedMessageCharacters = 6_000
        let oversizedText = String(repeating: "A", count: 8_000)
        let messages = (0..<16).map { index in
            GardenAssistantMessage(
                role: index.isMultiple(of: 2) ? .user : .assistant,
                text: "message-\(index) \(oversizedText) tail-\(index)"
            )
        }

        let body = GardenAssistantOpenAIConfiguration.requestBody(
            messages: messages,
            model: GardenAssistantOpenAIConfiguration.primaryModel
        )
        let input = try #require(body["input"] as? [[String: String]])

        #expect(input.count == 12)
        #expect(input.first?["content"]?.contains("message-4") == true)
        #expect(input.first?["content"]?.contains("message-3") == false)
        for item in input {
            #expect((item["content"]?.count ?? Int.max) <= maximumShippedMessageCharacters)
        }
        #expect(input.last?["content"]?.contains("message-15") == true)
        #expect(input.last?["content"]?.contains("tail-15") == true)
        #expect(input.last?["content"]?.localizedCaseInsensitiveContains("shortened") == true)
    }

    @Test("assistant request injects sanitized live app context")
    func assistantRequestInjectsSanitizedLiveAppContext() throws {
        let state = GardenState(
            plants: [
                Plant(
                    species: .rose,
                    screenIndex: 0,
                    position: GardenPoint(x: 0.2, y: 0.7),
                    growth: 0.92,
                    hydration: 0.31,
                    health: 0.82
                ),
                Plant(
                    species: .determinateTomato,
                    screenIndex: 0,
                    position: GardenPoint(x: 0.7, y: 0.8),
                    growth: 0.98,
                    hydration: 0.76,
                    health: 0.44
                )
            ],
            ambientMoisture: 0.41,
            windStrength: 0.16,
            manualPlantDarkening: 0.22,
            isPaused: true,
            settings: GardenSettings(
                isGardenInteractionLocked: true,
                experienceMode: .roomStudio,
                timeLapseCadence: .weekly,
                performanceMode: .still
            ),
            focusSession: GardenFocusSession(startedAt: Date(timeIntervalSince1970: 100), duration: 25 * 60),
            seedInventory: ["rose": 3],
            harvestTally: ["determinate-tomato": 4]
        )
        let context = GardenAssistantRuntimeContext(
            state: state,
            activeSceneDisplayName: "Cozy Apartment Studio",
            activeSceneKey: "/Users/chrisdimarco/sk-proj-secret-scene",
            selectedPlant: state.plants[0],
            now: Date(timeIntervalSince1970: 600)
        )

        let body = GardenAssistantOpenAIConfiguration.requestBody(
            messages: [GardenAssistantMessage(role: .user, text: "What should I improve?")],
            model: GardenAssistantOpenAIConfiguration.primaryModel,
            context: context
        )
        let instructions = try #require(body["instructions"] as? String)

        #expect(instructions.contains("Current desktop context"))
        #expect(instructions.contains("Mode: Room Studio"))
        #expect(instructions.contains("Scene: Cozy Apartment Studio"))
        #expect(instructions.contains("Plants/objects: 2 total"))
        #expect(instructions.contains("Selected: Rose"))
        #expect(instructions.contains("Growth paused: yes"))
        #expect(instructions.contains("Interactions locked: yes"))
        #expect(instructions.contains("Ready harvests: 1"))
        #expect(instructions.contains("Seeds available: 3"))
        #expect(!instructions.contains("/Users/"))
        #expect(!instructions.contains("sk-proj-secret"))
        #expect(!instructions.contains(state.plants[0].id.uuidString))
    }

    @Test("assistant default request keeps context optional")
    func assistantDefaultRequestKeepsContextOptional() throws {
        let body = GardenAssistantOpenAIConfiguration.requestBody(
            messages: [GardenAssistantMessage(role: .user, text: "Hello")],
            model: GardenAssistantOpenAIConfiguration.primaryModel
        )
        let instructions = try #require(body["instructions"] as? String)
        #expect(!instructions.contains("Current desktop context"))
    }

    @Test("assistant client sends context without leaking key into JSON body")
    func assistantClientSendsContextWithoutLeakingKeyIntoJSONBody() async throws {
        let httpClient = CapturingAssistantHTTPClient()
        let client = GardenAssistantOpenAIClient(httpClient: httpClient)
        let state = GardenState(
            plants: [
                Plant(species: .monstera, screenIndex: 0, position: GardenPoint(x: 0.5, y: 0.8))
            ],
            settings: GardenSettings(experienceMode: .garden)
        )
        let context = GardenAssistantRuntimeContext(
            state: state,
            activeSceneDisplayName: "Cottage Backyard Garden",
            activeSceneKey: GardenWallpaperScene.cottageBackyardGarden.rawValue,
            selectedPlant: nil
        )

        let response = try await client.send(
            messages: [GardenAssistantMessage(role: .user, text: "How should I arrange this?")],
            apiKey: "  sk-test-redacted  ",
            context: context
        )
        let request = try #require(await httpClient.capturedRequest())
        let bodyData = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let instructions = try #require(body["instructions"] as? String)

        #expect(response.text == "Use the current scene context.")
        #expect(response.model == GardenAssistantOpenAIConfiguration.primaryModel)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-redacted")
        #expect(instructions.contains("Scene: Cottage Backyard Garden"))
        #expect(!String(data: bodyData, encoding: .utf8)!.contains("sk-test-redacted"))
    }

    @Test("assistant client retries one transient OpenAI failure before succeeding")
    func assistantClientRetriesOneTransientOpenAIFailureBeforeSucceeding() async throws {
        let httpClient = ScriptedAssistantHTTPClient(steps: [
            .response(
                statusCode: 503,
                body: #"{"error":{"message":"OpenAI is temporarily unavailable.","type":"server_error"}}"#
            ),
            .response(statusCode: 200, body: #"{"output_text":"Recovered cleanly."}"#)
        ])
        let client = GardenAssistantOpenAIClient(httpClient: httpClient)

        let response = try await client.send(
            messages: [GardenAssistantMessage(role: .user, text: "Help me tune the garden.")],
            apiKey: "sk-test-redacted"
        )

        #expect(response.text == "Recovered cleanly.")
        #expect(response.model == GardenAssistantOpenAIConfiguration.primaryModel)
        #expect(await httpClient.requestCount() == 2)
    }

    @Test("assistant client does not retry non transient OpenAI errors")
    func assistantClientDoesNotRetryNonTransientOpenAIErrors() async throws {
        let httpClient = ScriptedAssistantHTTPClient(steps: [
            .response(
                statusCode: 400,
                body: #"{"error":{"message":"The prompt is invalid.","type":"invalid_request_error"}}"#
            ),
            .response(statusCode: 200, body: #"{"output_text":"Should not happen."}"#)
        ])
        let client = GardenAssistantOpenAIClient(httpClient: httpClient)

        do {
            _ = try await client.send(
                messages: [GardenAssistantMessage(role: .user, text: "bad request")],
                apiKey: "sk-test-redacted"
            )
            Issue.record("Expected non-transient OpenAI error")
        } catch GardenAssistantError.openAIError(let message) {
            #expect(message.contains("The prompt is invalid."))
        }

        #expect(await httpClient.requestCount() == 1)
    }

    @Test("assistant client does not retry cancellation")
    func assistantClientDoesNotRetryCancellation() async throws {
        let httpClient = ScriptedAssistantHTTPClient(steps: [
            .throwing(CancellationError()),
            .response(statusCode: 200, body: #"{"output_text":"Should not happen."}"#)
        ])
        let client = GardenAssistantOpenAIClient(httpClient: httpClient)

        do {
            _ = try await client.send(
                messages: [GardenAssistantMessage(role: .user, text: "stop")],
                apiKey: "sk-test-redacted"
            )
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            // Expected path.
        }

        #expect(await httpClient.requestCount() == 1)
    }

    @Test("assistant extracts output text from common Responses payloads")
    func assistantExtractsOutputTextFromCommonResponsesPayloads() throws {
        let direct = Data(#"{"output_text":"A calmer path would use fewer large props."}"#.utf8)
        #expect(try GardenAssistantOpenAIConfiguration.outputText(from: direct) == "A calmer path would use fewer large props.")

        let nested = Data(
            """
            {
              "output": [
                {
                  "type": "message",
                  "content": [
                    { "type": "output_text", "text": "Try one strong focal plant." },
                    { "type": "output_text", "text": "Leave breathing room around it." }
                  ]
                }
              ]
            }
            """.utf8
        )
        #expect(try GardenAssistantOpenAIConfiguration.outputText(from: nested) == "Try one strong focal plant.\n\nLeave breathing room around it.")
    }

    @Test("assistant reports OpenAI errors without leaking request data")
    func assistantReportsOpenAIErrorsWithoutLeakingRequestData() {
        let data = Data(
            """
            {
              "error": {
                "message": "The model gpt-5.5 does not exist or you do not have access to it.",
                "type": "invalid_request_error",
                "code": "model_not_found"
              }
            }
            """.utf8
        )
        let message = GardenAssistantOpenAIConfiguration.openAIErrorMessage(from: data)
        #expect(message.contains("model gpt-5.5"))
        #expect(!message.contains("Authorization"))
        #expect(GardenAssistantOpenAIConfiguration.shouldTryNextModel(afterOpenAIError: message))
    }

    @Test("assistant presents sanitized user facing errors")
    func assistantPresentsSanitizedUserFacingErrors() {
        let raw = """
        Authorization failed for Bearer service-session-token while using OpenAI key sk-test-secret-value and reading /Users/chrisdimarco/Desktop/private.png.
        """
        let message = GardenAssistantErrorPresenter.sanitizedMessage(raw)

        #expect(message.contains("[redacted authorization header]"))
        #expect(message.contains("[redacted OpenAI key]"))
        #expect(message.contains("[redacted local path]"))
        #expect(!message.contains("sk-test-secret-value"))
        #expect(!message.contains("Bearer "))
        #expect(!message.contains("/Users/chrisdimarco"))
    }

    @Test("assistant sanitizes common integration secrets from errors")
    func assistantSanitizesCommonIntegrationSecretsFromErrors() {
        let raw = """
        Failed request Authorization: Bearer ghp_1234567890abcdefghijklmnop; Slack token xoxb-123456789012-abcdefghijklmnopqrstuv;
        OPENAI_API_KEY=sk-proj-redactedexample and refresh_token=r1-example-secret.
        """
        let message = GardenAssistantErrorPresenter.sanitizedMessage(raw)

        #expect(message.contains("[redacted authorization header]"))
        #expect(message.contains("[redacted Slack token]"))
        #expect(message.contains("[redacted secret assignment]"))
        #expect(!message.contains("ghp_1234567890"))
        #expect(!message.contains("xoxb-123456789012"))
        #expect(!message.contains("sk-proj-redactedexample"))
        #expect(!message.contains("r1-example-secret"))
        #expect(!message.contains("Bearer ghp_"))
    }

    @Test("assistant API key entry copy avoids secret shaped placeholders")
    func assistantAPIKeyEntryCopyAvoidsSecretShapedPlaceholders() {
        #expect(OpenAIAPIKeyStore.keyFieldPlaceholder == "Paste your OpenAI API key")
        #expect(!OpenAIAPIKeyStore.keyFieldPlaceholder.contains("sk-"))
    }

    @Test("assistant missing key guidance is user actionable")
    func assistantMissingKeyGuidanceIsUserActionable() {
        let guidance = GardenAssistantConversationRules.missingAPIKeyMessage
        #expect(guidance.contains("OpenAI API key"))
        #expect(guidance.contains("Keychain"))
        #expect(!guidance.localizedCaseInsensitiveContains("fake"))
    }

    @Test("assistant cancellation copy is appended once")
    func assistantCancellationCopyIsAppendedOnce() {
        let existing = [
            GardenAssistantMessage(role: .user, text: "Stop this"),
            GardenAssistantMessage(role: .assistant, text: GardenAssistantConversationRules.cancelledMessage)
        ]
        let active = [
            GardenAssistantMessage(role: .user, text: "Stop this")
        ]

        #expect(!GardenAssistantConversationRules.shouldAppendCancellationMessage(after: existing))
        #expect(GardenAssistantConversationRules.shouldAppendCancellationMessage(after: active))
        #expect(GardenAssistantConversationRules.shouldAppendCancellationMessage(after: []))
    }

    @Test("assistant frame fits large and small screens")
    func assistantFrameFitsVisibleScreens() {
        let large = GardenAssistantWindowController.frameForTesting(
            visibleFrame: NSRect(x: 0, y: 0, width: 1600, height: 950),
            preferredSize: NSSize(width: 1360, height: 790)
        )
        #expect(large.width == 1360)
        #expect(large.height == 790)
        #expect(large.minX >= 48)
        #expect(large.maxY <= 902)

        let small = GardenAssistantWindowController.frameForTesting(
            visibleFrame: NSRect(x: 0, y: 0, width: 900, height: 650),
            preferredSize: NSSize(width: 1360, height: 790)
        )
        #expect(small.width <= 804)
        #expect(small.height <= 554)
        #expect(small.minX >= 48)
        #expect(small.minY >= 48)
    }

    @Test("assistant style uses clean high contrast command center surfaces")
    func assistantStyleUsesCleanHighContrastCommandCenterSurfaces() {
        #expect(GardenAssistantStyle.surfaceFill.alphaComponent >= 0.94)
        #expect(GardenAssistantStyle.surfaceFill.brightnessComponent < 0.12)
        #expect(GardenAssistantStyle.cardFill.alphaComponent >= 0.82)
        #expect(GardenAssistantStyle.cardFill.brightnessComponent < 0.20)
        #expect(GardenAssistantStyle.primaryText.brightnessComponent > 0.90)
        #expect(GardenAssistantStyle.secondaryText.brightnessComponent > 0.62)
    }

    @Test("status menu exposes the assistant quick toggle near the top")
    func statusMenuExposesAssistantQuickToggle() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenAssistantStatusMenuTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let persistence = GardenPersistence(directoryURL: directoryURL)
        let store = GardenStore(state: GardenState(), persistence: persistence, activeSceneKey: "empty-conservatory-hall")
        let wallpaperManager = WallpaperManager(baseDirectoryURL: directoryURL)
        let menu = GardenStatusMenu(store: store, wallpaperManager: wallpaperManager)
        let titles = menu.menuTitlesForSelfTest()

        let assistantIndex = try #require(titles.firstIndex(of: "Jarvis Assistant..."))
        let settingsIndex = try #require(titles.firstIndex(of: "Settings & Dashboard..."))
        #expect(assistantIndex < settingsIndex)
    }

    @Test("status menu exposes pricing beside settings")
    func statusMenuExposesPricingBesideSettings() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenPricingStatusMenuTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let persistence = GardenPersistence(directoryURL: directoryURL)
        let store = GardenStore(state: GardenState(), persistence: persistence, activeSceneKey: "empty-conservatory-hall")
        let wallpaperManager = WallpaperManager(baseDirectoryURL: directoryURL)
        let menu = GardenStatusMenu(store: store, wallpaperManager: wallpaperManager)
        let titles = menu.menuTitlesForSelfTest()

        let settingsIndex = try #require(titles.firstIndex(of: "Settings & Dashboard..."))
        let pricingIndex = try #require(titles.firstIndex(of: GardenPricingCatalog.menuTitle))
        // Settings and Pricing sit together in the "App & account" section.
        #expect(pricingIndex == settingsIndex + 1)
    }

    @Test("pricing catalog offers launch-ready free and pro tiers")
    func pricingCatalogOffersLaunchReadyFreeAndProTiers() {
        #expect(GardenPricingCatalog.free.name == "Free")
        #expect(GardenPricingCatalog.free.price == "$0")
        #expect(GardenPricingCatalog.free.features.contains { $0.contains("Core Garden mode") })
        #expect(GardenPricingCatalog.free.features.contains { $0.contains("own OpenAI API key") })
        #expect(GardenPricingCatalog.pro.name == "Pro")
        #expect(GardenPricingCatalog.pro.price == "$8/mo or $60/yr")
        #expect(GardenPricingCatalog.pro.badge == "Recommended")
        #expect(GardenPricingCatalog.pro.features.contains { $0.contains("Room Studio") })
        #expect(GardenPricingCatalog.pro.features.contains { $0.contains("hosted AI credits") })
        #expect(GardenPricingCatalog.footer.contains("own OpenAI API key"))
        #expect(GardenPricingCatalog.footer.contains("credit packs"))
        #expect(!GardenPricingCatalog.footer.localizedCaseInsensitiveContains("preview"))
        #expect(!GardenPricingCatalog.footer.localizedCaseInsensitiveContains("planned"))
    }

    @Test("status menu exposes wallpaper scenes near the top with the picker inside")
    func statusMenuExposesWallpaperScenesNearTheTop() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GardenSceneMainMenuTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let persistence = GardenPersistence(directoryURL: directoryURL)
        let store = GardenStore(state: GardenState(), persistence: persistence, activeSceneKey: "empty-conservatory-hall")
        let wallpaperManager = WallpaperManager(baseDirectoryURL: directoryURL)
        let menu = GardenStatusMenu(store: store, wallpaperManager: wallpaperManager)
        let titles = menu.menuTitlesForSelfTest()

        // The two wallpaper menus were merged into one "Wallpaper & Scenes"
        // entry that sits above the mode switch and holds the scene picker.
        let wallpaperIndex = try #require(titles.firstIndex(of: "Wallpaper & Scenes"))
        let modeIndex = try #require(titles.firstIndex(of: "Mode: Garden"))
        #expect(wallpaperIndex < modeIndex)
        #expect(!titles.contains("Wallpaper Scene"))
        #expect(menu.wallpaperToolsTitlesForSelfTest().contains("Wallpaper Scene"))
        #expect(menu.primaryWallpaperSceneTitlesForSelfTest().contains("Empty Conservatory Hall"))
    }
}

private actor CapturingAssistantHTTPClient: GardenAssistantHTTPClient {
    private var request: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request
        let data = Data(#"{"output_text":"Use the current scene context."}"#.utf8)
        let response = HTTPURLResponse(
            url: GardenAssistantOpenAIConfiguration.endpoint,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }

    func capturedRequest() -> URLRequest? {
        request
    }
}

private actor ScriptedAssistantHTTPClient: GardenAssistantHTTPClient {
    enum Step {
        case response(statusCode: Int, body: String)
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
                url: GardenAssistantOpenAIConfiguration.endpoint,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(#"{"error":{"message":"No scripted response."}}"#.utf8), response)
        }

        let step = steps.removeFirst()
        switch step {
        case .response(let statusCode, let body):
            let response = HTTPURLResponse(
                url: GardenAssistantOpenAIConfiguration.endpoint,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(body.utf8), response)
        case .throwing(let error):
            throw error
        }
    }

    func requestCount() -> Int {
        requests.count
    }
}
