import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden progression mode")
struct GardenProgressionModeTests {
    private func sampleProfile() -> GardenProgressionProfile {
        GardenProgressionProfile(
            lifestyleFantasy: "eccentric founder estate",
            placeInWorld: "coastal Brazil",
            ageBracket: "30s",
            vibe: "warm cinematic",
            avoidList: ""
        )
    }

    @Test("pausing preserves level and profile but blocks advancement")
    func pausingPreservesProgress() {
        let active = GardenSceneProgression(
            isEnabled: true,
            level: 7,
            profile: sampleProfile(),
            startedAt: Date(timeIntervalSince1970: 1_000),
            lastAdvancedAt: Date(timeIntervalSince1970: 2_000)
        )

        let paused = active.settingEnabled(false)

        #expect(paused.isEnabled == false)
        #expect(paused.level == 7)
        #expect(paused.profile == active.profile)
        #expect(paused.startedAt == active.startedAt)
        #expect(paused.lastAdvancedAt == active.lastAdvancedAt)
        #expect(paused.canAdvance == false)
    }

    @Test("resuming a paused ladder re-enables advancement")
    func resumingReenablesAdvancement() {
        let paused = GardenSceneProgression(
            isEnabled: false,
            level: 3,
            profile: sampleProfile()
        )

        let resumed = paused.settingEnabled(true)

        #expect(resumed.isEnabled)
        #expect(resumed.level == 3)
        #expect(resumed.canAdvance)
    }

    @Test("base scene key survives encoding and every level mutation")
    func baseSceneKeySurvivesEncodingAndMutations() throws {
        let original = GardenSceneProgression(
            isEnabled: true,
            level: 3,
            profile: sampleProfile(),
            autoAdvanceCadence: .weekly,
            baseSceneKey: "modern-bedroom-canvas"
        )

        // Carried through generate / pause / cadence changes.
        #expect(original.advanced().baseSceneKey == "modern-bedroom-canvas")
        #expect(original.settingEnabled(false).baseSceneKey == "modern-bedroom-canvas")
        #expect(original.settingAutoAdvanceCadence(.daily).baseSceneKey == "modern-bedroom-canvas")

        // Round-trips through persistence.
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GardenSceneProgression.self, from: data)
        #expect(decoded.baseSceneKey == "modern-bedroom-canvas")

        // Older saved profiles without the key still decode (defaults to nil).
        let legacyJSON = """
        {"isEnabled":true,"level":2,"startedAt":0,"profile":{"lifestyleFantasy":"x","placeInWorld":"y","ageBracket":"z","vibe":"w","avoidList":""}}
        """
        let legacy = try JSONDecoder().decode(
            GardenSceneProgression.self,
            from: Data(legacyJSON.utf8)
        )
        #expect(legacy.baseSceneKey == nil)
    }

    @Test("a maxed-out ladder cannot advance even when enabled")
    func maxedLadderCannotAdvance() {
        let maxed = GardenSceneProgression(
            isEnabled: true,
            level: GardenSceneProgression.maximumLevel,
            profile: sampleProfile()
        )

        #expect(maxed.canAdvance == false)
        #expect(maxed.nextLevel == GardenSceneProgression.maximumLevel)
    }

    @Test("auto-advance is due only after the cadence interval elapses")
    func autoAdvanceTiming() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let weekly = GardenSceneProgression(
            isEnabled: true,
            level: 2,
            profile: sampleProfile(),
            startedAt: start,
            lastAdvancedAt: start,
            autoAdvanceCadence: .weekly
        )

        #expect(weekly.isAutoAdvanceDue(now: start.addingTimeInterval(6 * 24 * 60 * 60)) == false)
        #expect(weekly.isAutoAdvanceDue(now: start.addingTimeInterval(8 * 24 * 60 * 60)))
    }

    @Test("off cadence and paused ladders never auto-advance")
    func autoAdvanceGuards() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let later = start.addingTimeInterval(30 * 24 * 60 * 60)

        let manual = GardenSceneProgression(
            isEnabled: true,
            level: 2,
            profile: sampleProfile(),
            startedAt: start,
            lastAdvancedAt: start,
            autoAdvanceCadence: .off
        )
        #expect(manual.isAutoAdvanceDue(now: later) == false)

        let paused = manual.settingAutoAdvanceCadence(.daily).settingEnabled(false)
        #expect(paused.isAutoAdvanceDue(now: later) == false)

        let maxed = GardenSceneProgression(
            isEnabled: true,
            level: GardenSceneProgression.maximumLevel,
            profile: sampleProfile(),
            startedAt: start,
            lastAdvancedAt: start,
            autoAdvanceCadence: .daily
        )
        #expect(maxed.isAutoAdvanceDue(now: later) == false)
    }

    @Test("cadence survives advancing, pausing, and re-rolling")
    func cadenceIsPreserved() {
        let progression = GardenSceneProgression(
            isEnabled: true,
            level: 1,
            profile: sampleProfile(),
            autoAdvanceCadence: .weekly
        )

        #expect(progression.advanced().autoAdvanceCadence == .weekly)
        #expect(progression.settingEnabled(false).autoAdvanceCadence == .weekly)
        #expect(progression.settingAutoAdvanceCadence(.daily).autoAdvanceCadence == .daily)
    }

    @Test("progression decodes from JSON saved before auto-advance existed")
    func legacyDecodeDefaultsToOff() throws {
        // A profile persisted by an older build has no autoAdvanceCadence key.
        let legacyJSON = """
        {
          "isEnabled": true,
          "level": 4,
          "profile": {
            "lifestyleFantasy": "founder estate",
            "placeInWorld": "coastal Brazil",
            "ageBracket": "30s",
            "vibe": "warm cinematic",
            "avoidList": ""
          },
          "startedAt": 12000
        }
        """
        let decoded = try JSONDecoder().decode(
            GardenSceneProgression.self,
            from: Data(legacyJSON.utf8)
        )

        #expect(decoded.level == 4)
        #expect(decoded.autoAdvanceCadence == .off)
        #expect(decoded.lastAdvancedAt == nil)
    }
}
