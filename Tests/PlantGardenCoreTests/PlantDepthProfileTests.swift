import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant depth profile")
struct PlantDepthProfileTests {
    @Test("depth profile assigns background midground and foreground bands")
    func depthProfileAssignsBands() {
        let background = PlantDepthProfile(positionY: 0.56)
        let midground = PlantDepthProfile(positionY: 0.74)
        let foreground = PlantDepthProfile(positionY: 0.91)

        #expect(background.band == .background)
        #expect(midground.band == .midground)
        #expect(foreground.band == .foreground)

        #expect(background.heightScale < midground.heightScale)
        #expect(midground.heightScale < foreground.heightScale)
        #expect(background.shadowOpacityMultiplier < midground.shadowOpacityMultiplier)
        #expect(midground.shadowOpacityMultiplier < foreground.shadowOpacityMultiplier)
    }

    @Test("depth profile clamps out of range positions")
    func depthProfileClampsPositions() {
        let aboveScene = PlantDepthProfile(positionY: -0.5)
        let belowScene = PlantDepthProfile(positionY: 1.5)

        #expect(aboveScene.band == .background)
        #expect(belowScene.band == .foreground)
        #expect(aboveScene.heightScale >= 0.82)
        #expect(belowScene.heightScale <= 1.18)
    }

    @Test("plant exposes its depth profile")
    func plantExposesDepthProfile() {
        let plant = Plant(
            species: .mapleTree,
            screenIndex: 0,
            position: GardenPoint(x: 0.5, y: 0.88)
        )

        #expect(plant.depthProfile.band == .foreground)
        #expect(plant.depthProfile.shadowScale > 1)
    }
}
