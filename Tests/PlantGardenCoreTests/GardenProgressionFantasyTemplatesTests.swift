import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden progression fantasy templates")
struct GardenProgressionFantasyTemplatesTests {
    @Test("catalog is non-empty with unique ids")
    func catalogHasUniqueIds() {
        let all = GardenProgressionFantasyTemplateCatalog.all
        #expect(!all.isEmpty)
        let ids = Set(all.map(\.id))
        #expect(ids.count == all.count)
    }

    @Test("every template is immediately usable so save works without edits")
    func everyTemplateIsUsable() {
        for template in GardenProgressionFantasyTemplateCatalog.all {
            #expect(template.profile.isUsable, "\(template.id) should be usable")
            #expect(!template.profile.lifestyleFantasy.isEmpty)
            #expect(!template.profile.placeInWorld.isEmpty)
            #expect(!template.profile.ageBracket.isEmpty)
            #expect(!template.profile.vibe.isEmpty)
        }
    }

    @Test("chip label combines emoji and title")
    func chipLabelCombinesEmojiAndTitle() {
        for template in GardenProgressionFantasyTemplateCatalog.all {
            #expect(!template.emoji.isEmpty)
            #expect(!template.title.isEmpty)
            #expect(template.chipLabel == "\(template.emoji) \(template.title)")
        }
    }

    @Test("catalog includes the headline fantasy starting points")
    func catalogIncludesHeadlineTemplates() {
        let ids = Set(GardenProgressionFantasyTemplateCatalog.all.map(\.id))
        let expected = [
            "tech-millionaire-nyc",
            "intergalactic-warlord",
            "amazon-tribal-chief",
            "modern-finance-bro",
            "80s-rock-star",
            "1920s-gangster"
        ]
        for id in expected {
            #expect(ids.contains(id), "catalog should include \(id)")
        }
    }

    @Test("garden mode uses botanist and garden-lover templates")
    func gardenModeUsesPlantPersonTemplates() {
        let gardenIDs = Set(GardenProgressionFantasyTemplateCatalog.templates(for: .garden).map(\.id))

        #expect(gardenIDs.contains("rooftop-botanist-nyc"))
        #expect(gardenIDs.contains("neon-rooftop-plant-hacker"))
        #expect(!gardenIDs.contains("modern-finance-bro"))
        #expect(!gardenIDs.contains("tokyo-cyberpunk"))
    }

    @Test("room studio keeps persona lifestyle templates")
    func roomStudioKeepsPersonaTemplates() {
        let roomIDs = Set(GardenProgressionFantasyTemplateCatalog.templates(for: .roomStudio).map(\.id))

        #expect(roomIDs.contains("tokyo-cyberpunk"))
        #expect(roomIDs.contains("modern-finance-bro"))
        #expect(!roomIDs.contains("rooftop-botanist-nyc"))
    }
}
