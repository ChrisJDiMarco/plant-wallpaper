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
}
