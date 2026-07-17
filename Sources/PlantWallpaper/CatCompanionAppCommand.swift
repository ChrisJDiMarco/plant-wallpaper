import Foundation
import PlantGardenCore

enum CatCompanionAppAction: Equatable {
    case waterAll
    case waterThirstyPlants
    case waterSelectedPlant
    case performRecommendedCare
    case harvestReadyCrops
    case startFocus(minutes: Int)
    case cancelFocus
    case setGrowthPaused(Bool)
    case setInteractionLocked(Bool)
    case setAILockView(Bool)
    case setAmbientSounds(Bool)
    case setAnimatedBugs(Bool)
    case setGnomesHidden(Bool)
    case setCozyMode(Bool)
    case setNewPlantsAtMaturity(Bool)
    case setCatCompanionVisible(Bool)
    case setCatChatOnClick(Bool)
    case setTimeLapseCadence(GardenTimeLapseCadence)
    case setPerformanceMode(GardenPerformanceMode)
    case switchExperienceMode(GardenExperienceMode)
    case applyNextScene
    case applyPreviousScene
    case reapplyCurrentScene
    case restorePreviousWallpaper
    case openSettings
    case openCatSettings
    case openPrivacyStorage
    case showToday
    case showPricing
    case showWelcomeTour
    case showUninstallGuide
    case openGardenData
    case toggleJarvisAssistant
    case openAPIKeySettings
    case updateCurrentWallpaper
    case createAIWallpaper
    case saveGardenSnapshot
    case saveShareCard
    case exportTimeLapse
    case drawGnomeSettlementAreas
    case adjustGnomePerspective
    case removeAllGnomeZones
    case resetPlantsToSeedlings
    case removeAllPlantsInScene
    case resetGarden
}

struct CatCompanionCommand: Equatable {
    let action: CatCompanionAppAction
    let title: String
    let successMessage: String
    let requiresConfirmation: Bool
    let confirmationPrompt: String

    init(
        action: CatCompanionAppAction,
        title: String,
        successMessage: String,
        requiresConfirmation: Bool = false,
        confirmationPrompt: String? = nil
    ) {
        self.action = action
        self.title = title
        self.successMessage = successMessage
        self.requiresConfirmation = requiresConfirmation
        self.confirmationPrompt = confirmationPrompt ?? "I can \(title.lowercased()). Reply “yes” to confirm, or “cancel” to leave it alone."
    }
}

struct CatCompanionCommandExecution: Equatable {
    let didExecute: Bool
    let message: String

    static func success(_ message: String) -> CatCompanionCommandExecution {
        CatCompanionCommandExecution(didExecute: true, message: message)
    }

    static func unavailable(_ message: String) -> CatCompanionCommandExecution {
        CatCompanionCommandExecution(didExecute: false, message: message)
    }
}

enum CatCompanionConfirmationDecision: Equatable {
    case confirmed
    case cancelled
}

enum CatCompanionCommandRouter {
    static func command(for rawMessage: String) -> CatCompanionCommand? {
        let prompt = normalized(rawMessage)
        guard !prompt.isEmpty else {
            return nil
        }

        if wantsDeleteAllPlants(prompt) {
            return CatCompanionCommand(
                action: .removeAllPlantsInScene,
                title: "delete all plants in this scene",
                successMessage: "Done. I cleared the scene. Tiny paws away from the danger button now.",
                requiresConfirmation: true,
                confirmationPrompt: "That will remove every plant/object in this scene. Reply “yes” to delete them, or “cancel” to keep the scene as-is."
            )
        }

        if containsAny(prompt, ["reset whole garden", "reset the whole garden", "reset garden", "start over"]) {
            return CatCompanionCommand(
                action: .resetGarden,
                title: "reset the garden",
                successMessage: "Done. The scene has been reset.",
                requiresConfirmation: true,
                confirmationPrompt: "Resetting clears this scene back to a starter state. Reply “yes” to reset, or “cancel” to keep everything."
            )
        }

        if containsAny(prompt, ["seedling", "seedlings", "nascent", "beginning form", "beginning forms", "start plants from"]) {
            return CatCompanionCommand(
                action: .resetPlantsToSeedlings,
                title: "start plants from seedlings",
                successMessage: "Done. The plants are back at their beginning forms, ready to grow.",
                requiresConfirmation: true,
                confirmationPrompt: "I can turn the current scene’s plants back into their beginning forms. Reply “yes” to do it, or “cancel” to keep them mature."
            )
        }

        if containsAll(prompt, ["ai", "lock"]) || containsAll(prompt, ["generated", "lock"]) {
            let enabled = requestedEnabledState(prompt) ?? true
            return CatCompanionCommand(
                action: .setAILockView(enabled),
                title: enabled ? "turn on AI Lock View" : "turn off AI Lock View",
                successMessage: enabled ? "AI Lock View is on. It will use the generated lock snapshot path when interactions are locked." : "AI Lock View is off.",
                requiresConfirmation: enabled,
                confirmationPrompt: "AI Lock View can send a garden snapshot to OpenAI and may use credits or API cost. Reply “yes” to turn it on, or “cancel” to leave it off."
            )
        }

        if containsAny(prompt, ["water thirsty", "water dry", "water plants that need", "water the thirsty"]) {
            return CatCompanionCommand(
                action: .waterThirstyPlants,
                title: "water thirsty plants",
                successMessage: "Done. I watered the thirsty plants. Hydration achieved, with dignity."
            )
        }

        if containsAny(prompt, ["water all", "water everything", "water the garden", "water every plant"]) {
            return CatCompanionCommand(
                action: .waterAll,
                title: "water all plants",
                successMessage: "Done. Everything got a drink."
            )
        }

        if containsAny(prompt, ["water selected", "water this plant", "water this object"]) {
            return CatCompanionCommand(
                action: .waterSelectedPlant,
                title: "water the selected plant",
                successMessage: "Done. I watered the selected plant."
            )
        }

        if containsAny(prompt, ["recommended care", "do care", "take care", "fix garden health"]) {
            return CatCompanionCommand(
                action: .performRecommendedCare,
                title: "do recommended care",
                successMessage: "Done. I followed the current recommended care."
            )
        }

        if containsAny(prompt, ["harvest", "ready crops", "collect crops", "pick crops"]) {
            return CatCompanionCommand(
                action: .harvestReadyCrops,
                title: "harvest ready crops",
                successMessage: "Done. I harvested the ready crops and tucked away the seeds."
            )
        }

        if containsAny(prompt, ["cancel focus", "stop focus", "end focus"]) {
            return CatCompanionCommand(
                action: .cancelFocus,
                title: "cancel the focus session",
                successMessage: "Focus session cancelled."
            )
        }

        if containsAny(prompt, ["focus session", "start focus", "focus timer", "pomodoro"]) {
            let minutes = focusMinutes(from: prompt)
            return CatCompanionCommand(
                action: .startFocus(minutes: minutes),
                title: "start a \(minutes)-minute focus session",
                successMessage: "Focus session started for \(minutes) minutes. I will supervise from a loaf-adjacent position."
            )
        }

        if containsAny(prompt, ["unpause growth", "resume growth", "continue growth"]) {
            return CatCompanionCommand(
                action: .setGrowthPaused(false),
                title: "resume growth",
                successMessage: "Growth is running again."
            )
        }

        if containsAny(prompt, ["pause growth", "stop growth", "freeze growth"]) {
            return CatCompanionCommand(
                action: .setGrowthPaused(true),
                title: "pause growth",
                successMessage: "Growth is paused."
            )
        }

        if containsAny(prompt, ["unlock interactions", "unlock garden", "unlock room", "let me click the garden"]) {
            return CatCompanionCommand(
                action: .setInteractionLocked(false),
                title: "unlock interactions",
                successMessage: "Interactions are unlocked."
            )
        }

        if containsAny(prompt, ["lock interactions", "lock garden", "lock room", "click through", "normal mac clicks"]) {
            return CatCompanionCommand(
                action: .setInteractionLocked(true),
                title: "lock interactions",
                successMessage: "Interactions are locked. Your desktop clicks should behave like normal macOS clicks."
            )
        }

        if containsAny(prompt, ["environmental sounds", "ambient sounds", "garden sounds", "soundscape"]) {
            let enabled = requestedEnabledState(prompt) ?? !containsAny(prompt, ["silent", "mute", "quiet"])
            return CatCompanionCommand(
                action: .setAmbientSounds(enabled),
                title: enabled ? "turn on environmental sounds" : "turn off environmental sounds",
                successMessage: enabled ? "Environmental sounds are on." : "Environmental sounds are off."
            )
        }

        if containsAny(prompt, ["animated bugs", "butterflies", "flies", "insects", "bugs"]) {
            let enabled = requestedEnabledState(prompt) ?? !containsAny(prompt, ["hide", "stop", "disable"])
            return CatCompanionCommand(
                action: .setAnimatedBugs(enabled),
                title: enabled ? "show animated bugs" : "hide animated bugs",
                successMessage: enabled ? "Animated bugs are on." : "Animated bugs are hidden."
            )
        }

        if containsAny(prompt, ["gnome", "gnomes"]) {
            if containsAny(prompt, ["draw gnome", "gnome area", "gnome zone", "settlement area", "settlement zone"]) {
                return CatCompanionCommand(
                    action: .drawGnomeSettlementAreas,
                    title: "draw gnome settlement areas",
                    successMessage: "Gnome settlement drawing is ready."
                )
            }
            if containsAny(prompt, ["perspective", "angle", "rotate", "3d view"]) {
                return CatCompanionCommand(
                    action: .adjustGnomePerspective,
                    title: "adjust gnome perspective",
                    successMessage: "Gnome perspective adjustment is ready."
                )
            }
            if containsAny(prompt, ["remove all", "clear all", "delete all"]) {
                return CatCompanionCommand(
                    action: .removeAllGnomeZones,
                    title: "remove all gnomes from this scene",
                    successMessage: "Done. The gnome tribes packed up their little camps.",
                    requiresConfirmation: true,
                    confirmationPrompt: "That will remove every gnome settlement area in this scene. Reply “yes” to remove them, or “cancel” to keep them."
                )
            }
            if containsAny(prompt, ["show", "bring back", "turn on", "unhide"]) {
                return CatCompanionCommand(
                    action: .setGnomesHidden(false),
                    title: "show gnomes",
                    successMessage: "Gnomes are visible again."
                )
            }
            if containsAny(prompt, ["hide", "turn off", "disable", "stop showing"]) {
                return CatCompanionCommand(
                    action: .setGnomesHidden(true),
                    title: "hide gnomes",
                    successMessage: "Gnomes are hidden for now."
                )
            }
        }

        if containsAny(prompt, ["cozy mode", "no dying", "no chores"]) {
            let enabled = requestedEnabledState(prompt) ?? true
            return CatCompanionCommand(
                action: .setCozyMode(enabled),
                title: enabled ? "turn on Cozy Mode" : "turn off Cozy Mode",
                successMessage: enabled ? "Cozy Mode is on. The garden will feel gentler." : "Cozy Mode is off."
            )
        }

        if containsAny(prompt, ["mature plants", "plant at maturity", "fully mature"]) {
            let enabled = requestedEnabledState(prompt) ?? true
            return CatCompanionCommand(
                action: .setNewPlantsAtMaturity(enabled),
                title: enabled ? "plant new items at maturity" : "plant new items from the beginning",
                successMessage: enabled ? "New plants will be placed at their mature stage." : "New plants will start from their beginning stage."
            )
        }

        if containsAny(prompt, ["cat chat", "miso chat", "click cat"]) {
            let enabled = requestedEnabledState(prompt) ?? !containsAny(prompt, ["dont open", "don t open", "don't open", "no chat"])
            return CatCompanionCommand(
                action: .setCatChatOnClick(enabled),
                title: enabled ? "turn on cat chat on click" : "turn off cat chat on click",
                successMessage: enabled ? "Clicking Miso will open the chat window." : "Clicking Miso will no longer open the chat window."
            )
        }

        if containsAny(prompt, ["show cat", "hide cat", "cat companion"]) {
            if containsAny(prompt, ["show", "turn on", "enable", "bring back"]) {
                return CatCompanionCommand(
                    action: .setCatCompanionVisible(true),
                    title: "show cat companion",
                    successMessage: "Miso is visible again."
                )
            }
            if containsAny(prompt, ["hide", "turn off", "disable"]) {
                return CatCompanionCommand(
                    action: .setCatCompanionVisible(false),
                    title: "hide cat companion",
                    successMessage: "Miso is hidden for now."
                )
            }
        }

        if containsAny(prompt, ["time lapse", "timelapse"]) {
            if containsAny(prompt, ["weekly"]) {
                return CatCompanionCommand(action: .setTimeLapseCadence(.weekly), title: "set time-lapse to weekly", successMessage: "Time-lapse capture is set to weekly.")
            }
            if containsAny(prompt, ["daily"]) {
                return CatCompanionCommand(action: .setTimeLapseCadence(.daily), title: "set time-lapse to daily", successMessage: "Time-lapse capture is set to daily.")
            }
            if containsAny(prompt, ["off", "disable", "stop"]) {
                return CatCompanionCommand(action: .setTimeLapseCadence(.off), title: "turn off time-lapse", successMessage: "Time-lapse capture is off.")
            }
        }

        if containsAny(prompt, ["performance", "framerate", "frame rate", "battery", "low power"]) {
            if containsAny(prompt, ["still", "calm", "battery", "low power"]) {
                return CatCompanionCommand(action: .setPerformanceMode(.still), title: "set performance to Still", successMessage: "Performance mode is set to Still.")
            }
            if containsAny(prompt, ["lively", "fast", "smooth"]) {
                return CatCompanionCommand(action: .setPerformanceMode(.lively), title: "set performance to Lively", successMessage: "Performance mode is set to Lively.")
            }
            if containsAny(prompt, ["balanced", "normal"]) {
                return CatCompanionCommand(action: .setPerformanceMode(.balanced), title: "set performance to Balanced", successMessage: "Performance mode is set to Balanced.")
            }
        }

        if containsAny(prompt, ["room studio", "bedroom mode", "room mode"]) {
            return CatCompanionCommand(
                action: .switchExperienceMode(.roomStudio),
                title: "switch to Room Studio",
                successMessage: "Switched to Room Studio."
            )
        }

        if containsAny(prompt, ["alien ufo", "alien/ufo", "alien mode", "ufo mode"]) {
            return CatCompanionCommand(
                action: .switchExperienceMode(.alienUFO),
                title: "switch to Alien/UFO Garden",
                successMessage: "Switched to Alien/UFO Garden."
            )
        }

        if containsAny(prompt, ["rainforest mode", "jungle mode", "rainforest canvas"]) {
            return CatCompanionCommand(
                action: .switchExperienceMode(.rainforest),
                title: "switch to Rainforest mode",
                successMessage: "Switched to Rainforest mode."
            )
        }

        if containsAny(prompt, ["garden mode", "switch to garden", "back to garden"]) {
            return CatCompanionCommand(
                action: .switchExperienceMode(.garden),
                title: "switch to Garden mode",
                successMessage: "Switched to Garden mode."
            )
        }

        if containsAny(prompt, ["next scene", "next wallpaper", "go forward", "cycle forward"]) {
            return CatCompanionCommand(
                action: .applyNextScene,
                title: "switch to the next scene",
                successMessage: "Switched to the next scene."
            )
        }

        if containsAny(prompt, ["restore previous wallpaper", "undo wallpaper", "go back to previous wallpaper"]) {
            return CatCompanionCommand(
                action: .restorePreviousWallpaper,
                title: "restore the previous wallpaper",
                successMessage: "Restored the previous wallpaper."
            )
        }

        if containsAny(prompt, ["previous scene", "prev scene", "last scene", "previous wallpaper", "cycle backward", "go back a scene"]) {
            return CatCompanionCommand(
                action: .applyPreviousScene,
                title: "switch to the previous scene",
                successMessage: "Switched to the previous scene."
            )
        }

        if containsAny(prompt, ["cat settings", "miso settings"]) {
            return CatCompanionCommand(action: .openCatSettings, title: "open cat settings", successMessage: "Opened Cat Companion Settings.")
        }

        if containsAny(prompt, ["pricing", "pro plan", "subscription", "paywall"]) {
            return CatCompanionCommand(action: .showPricing, title: "open pricing", successMessage: "Opened Pricing & Pro.")
        }

        if containsAny(prompt, ["api key", "openai key"]) {
            return CatCompanionCommand(action: .openAPIKeySettings, title: "open API key settings", successMessage: "Opened OpenAI API Key Settings.")
        }

        if containsAny(prompt, ["privacy storage", "privacy and storage", "storage settings", "privacy settings"]) {
            return CatCompanionCommand(action: .openPrivacyStorage, title: "open Privacy & Storage", successMessage: "Opened Privacy & Storage.")
        }

        if containsAny(prompt, ["welcome tour", "welcome modal", "show onboarding", "open onboarding"]) {
            return CatCompanionCommand(action: .showWelcomeTour, title: "open the welcome tour", successMessage: "Opened the welcome tour.")
        }

        if containsAny(prompt, ["uninstall guide", "cleanup guide", "clean up guide", "remove app files"]) {
            return CatCompanionCommand(action: .showUninstallGuide, title: "open the uninstall cleanup guide", successMessage: "Opened the uninstall cleanup guide.")
        }

        if containsAny(prompt, ["open garden data", "show garden data", "reveal garden data", "data folder"]) {
            return CatCompanionCommand(action: .openGardenData, title: "open garden data", successMessage: "Opened Garden Data in Finder.")
        }

        if containsAny(prompt, ["open jarvis", "show jarvis", "jarvis assistant", "command center"]) {
            return CatCompanionCommand(action: .toggleJarvisAssistant, title: "toggle Jarvis Assistant", successMessage: "Toggled Jarvis Assistant.")
        }

        if containsAny(prompt, ["settings", "dashboard"]) {
            return CatCompanionCommand(action: .openSettings, title: "open settings", successMessage: "Opened Settings & Dashboard.")
        }

        if containsAny(prompt, ["today in garden", "today in room", "today in alien", "what should i do next"]) {
            return CatCompanionCommand(action: .showToday, title: "open today panel", successMessage: "Opened the Today panel.")
        }

        if containsAny(prompt, ["reapply current scene", "reapply scene", "refresh scene"]) {
            return CatCompanionCommand(
                action: .reapplyCurrentScene,
                title: "reapply the current scene",
                successMessage: "Reapplied the current scene."
            )
        }

        if containsAny(prompt, ["update current wallpaper", "edit current wallpaper", "change wallpaper"]) {
            return CatCompanionCommand(
                action: .updateCurrentWallpaper,
                title: "open wallpaper update",
                successMessage: "Opened the wallpaper update prompt."
            )
        }

        if containsAny(prompt, ["create ai wallpaper", "generate wallpaper", "new ai wallpaper"]) {
            return CatCompanionCommand(
                action: .createAIWallpaper,
                title: "create an AI wallpaper",
                successMessage: "Opened AI wallpaper creation.",
                requiresConfirmation: true,
                confirmationPrompt: "Creating AI wallpaper can send prompts to OpenAI and may use credits or API cost. Reply “yes” to continue, or “cancel” to skip it."
            )
        }

        if containsAny(prompt, ["save garden snapshot", "garden snapshot", "save snapshot"]) {
            return CatCompanionCommand(
                action: .saveGardenSnapshot,
                title: "save a garden snapshot",
                successMessage: "Opened the save snapshot panel."
            )
        }

        if containsAny(prompt, ["save share card", "share card"]) {
            return CatCompanionCommand(
                action: .saveShareCard,
                title: "save a share card",
                successMessage: "Opened the share card save panel."
            )
        }

        if containsAny(prompt, ["export time lapse", "export timelapse", "make time lapse", "make timelapse"]) {
            return CatCompanionCommand(
                action: .exportTimeLapse,
                title: "export a time-lapse",
                successMessage: "Opened time-lapse export."
            )
        }

        return nil
    }

    static func confirmationDecision(for rawMessage: String) -> CatCompanionConfirmationDecision? {
        let prompt = normalized(rawMessage)
        if containsAny(prompt, ["no", "cancel", "stop", "never mind", "nevermind", "do not", "dont", "don t", "don't", "nope"]) {
            return .cancelled
        }
        if containsAny(prompt, ["yes", "confirm", "do it", "go ahead", "proceed", "yep", "okay", "ok", "sure", "yes please", "please do"]) {
            return .confirmed
        }
        return nil
    }

    static func normalized(_ raw: String) -> String {
        raw
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined(separator: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }

    private static func wantsDeleteAllPlants(_ prompt: String) -> Bool {
        containsAll(prompt, ["all", "plants"])
            && containsAny(prompt, ["delete", "remove", "clear"])
    }

    private static func focusMinutes(from prompt: String) -> Int {
        let numbers = prompt
            .split(separator: " ")
            .compactMap { Int($0) }
            .filter { (5...180).contains($0) }
        if let first = numbers.first {
            return first
        }
        if containsAny(prompt, ["50", "deep"]) {
            return 50
        }
        return 25
    }

    private static func requestedEnabledState(_ prompt: String) -> Bool? {
        if containsAny(prompt, ["turn on", "enable", "show", "start", "resume", "unmute", "activate"]) {
            return true
        }
        if containsAny(prompt, ["turn off", "disable", "hide", "stop", "mute", "deactivate", "off"]) {
            return false
        }
        return nil
    }

    private static func containsAll(_ prompt: String, _ tokens: [String]) -> Bool {
        tokens.allSatisfy { prompt.contains($0) }
    }

    private static func containsAny(_ prompt: String, _ tokens: [String]) -> Bool {
        tokens.contains { prompt.contains($0) }
    }
}
