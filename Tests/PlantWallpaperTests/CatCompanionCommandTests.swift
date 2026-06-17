import PlantGardenCore
import Testing
@testable import PlantWallpaper

@MainActor
@Suite("Miso app command router")
struct CatCompanionCommandTests {
    @Test("Miso recognizes direct safe app commands")
    func recognizesSafeCommands() throws {
        #expect(CatCompanionCommandRouter.command(for: "water thirsty plants")?.action == .waterThirstyPlants)
        #expect(CatCompanionCommandRouter.command(for: "harvest all ready crops please")?.action == .harvestReadyCrops)
        #expect(CatCompanionCommandRouter.command(for: "pause growth")?.action == .setGrowthPaused(true))
        #expect(CatCompanionCommandRouter.command(for: "unpause growth")?.action == .setGrowthPaused(false))
        #expect(CatCompanionCommandRouter.command(for: "unlock interactions")?.action == .setInteractionLocked(false))
        #expect(CatCompanionCommandRouter.command(for: "lock garden interactions")?.action == .setInteractionLocked(true))
        #expect(CatCompanionCommandRouter.command(for: "start a 50 minute focus session")?.action == .startFocus(minutes: 50))
        #expect(CatCompanionCommandRouter.command(for: "switch to Room Studio")?.action == .switchExperienceMode(.roomStudio))
        #expect(CatCompanionCommandRouter.command(for: "go to alien ufo mode")?.action == .switchExperienceMode(.alienUFO))
    }

    @Test("Miso recognizes settings and visibility commands")
    func recognizesSettingsCommands() throws {
        #expect(CatCompanionCommandRouter.command(for: "turn environmental sounds off")?.action == .setAmbientSounds(false))
        #expect(CatCompanionCommandRouter.command(for: "turn on animated bugs")?.action == .setAnimatedBugs(true))
        #expect(CatCompanionCommandRouter.command(for: "hide the gnomes")?.action == .setGnomesHidden(true))
        #expect(CatCompanionCommandRouter.command(for: "unhide the gnomes")?.action == .setGnomesHidden(false))
        #expect(CatCompanionCommandRouter.command(for: "show gnomes again")?.action == .setGnomesHidden(false))
        #expect(CatCompanionCommandRouter.command(for: "hide cat companion")?.action == .setCatCompanionVisible(false))
        #expect(CatCompanionCommandRouter.command(for: "turn off cat chat")?.action == .setCatChatOnClick(false))
        #expect(CatCompanionCommandRouter.command(for: "open cat settings")?.action == .openCatSettings)
        #expect(CatCompanionCommandRouter.command(for: "open pricing")?.action == .showPricing)
    }

    @Test("Miso recognizes navigation and utility commands")
    func recognizesNavigationAndUtilityCommands() throws {
        #expect(CatCompanionCommandRouter.command(for: "next scene please")?.action == .applyNextScene)
        #expect(CatCompanionCommandRouter.command(for: "previous wallpaper")?.action == .applyPreviousScene)
        #expect(CatCompanionCommandRouter.command(for: "reapply current scene")?.action == .reapplyCurrentScene)
        #expect(CatCompanionCommandRouter.command(for: "restore previous wallpaper")?.action == .restorePreviousWallpaper)
        #expect(CatCompanionCommandRouter.command(for: "open privacy and storage")?.action == .openPrivacyStorage)
        #expect(CatCompanionCommandRouter.command(for: "show welcome tour")?.action == .showWelcomeTour)
        #expect(CatCompanionCommandRouter.command(for: "open garden data")?.action == .openGardenData)
        #expect(CatCompanionCommandRouter.command(for: "save garden snapshot")?.action == .saveGardenSnapshot)
        #expect(CatCompanionCommandRouter.command(for: "export time lapse")?.action == .exportTimeLapse)
    }

    @Test("Miso recognizes gnome setup commands")
    func recognizesGnomeSetupCommands() throws {
        #expect(CatCompanionCommandRouter.command(for: "draw gnome settlement areas")?.action == .drawGnomeSettlementAreas)
        #expect(CatCompanionCommandRouter.command(for: "adjust gnome perspective")?.action == .adjustGnomePerspective)

        let remove = try #require(CatCompanionCommandRouter.command(for: "remove all gnomes from this scene"))
        #expect(remove.action == .removeAllGnomeZones)
        #expect(remove.requiresConfirmation)
    }

    @Test("Miso requires confirmation for destructive or expensive commands")
    func requiresConfirmationForSensitiveCommands() throws {
        let delete = try #require(CatCompanionCommandRouter.command(for: "delete all plants in this scene"))
        #expect(delete.action == .removeAllPlantsInScene)
        #expect(delete.requiresConfirmation)

        let reset = try #require(CatCompanionCommandRouter.command(for: "reset the whole garden"))
        #expect(reset.action == .resetGarden)
        #expect(reset.requiresConfirmation)

        let aiLock = try #require(CatCompanionCommandRouter.command(for: "turn on AI lock view"))
        #expect(aiLock.action == .setAILockView(true))
        #expect(aiLock.requiresConfirmation)
    }

    @Test("Miso confirmation parser handles common approval and rejection phrasing")
    func confirmationParserHandlesCommonPhrasing() {
        #expect(CatCompanionCommandRouter.confirmationDecision(for: "yes do it") == .confirmed)
        #expect(CatCompanionCommandRouter.confirmationDecision(for: "confirm") == .confirmed)
        #expect(CatCompanionCommandRouter.confirmationDecision(for: "sure please") == .confirmed)
        #expect(CatCompanionCommandRouter.confirmationDecision(for: "no cancel that") == .cancelled)
        #expect(CatCompanionCommandRouter.confirmationDecision(for: "nope") == .cancelled)
        #expect(CatCompanionCommandRouter.confirmationDecision(for: "never mind") == .cancelled)
        #expect(CatCompanionCommandRouter.confirmationDecision(for: "maybe later") == nil)
    }

    @Test("Miso app commands are injected into OpenAI instructions as an allowlist")
    func commandAllowlistIsInjectedIntoInstructions() {
        #expect(CatCompanionConversationRules.systemInstructions.contains("allowlisted app commands"))
        #expect(CatCompanionConversationRules.systemInstructions.contains("water thirsty plants"))
        #expect(CatCompanionConversationRules.systemInstructions.contains("switch modes"))
        #expect(CatCompanionConversationRules.systemInstructions.contains("next/previous/reapply/restore wallpaper scenes"))
        #expect(CatCompanionConversationRules.systemInstructions.contains("Never invent private file access"))
    }
}
