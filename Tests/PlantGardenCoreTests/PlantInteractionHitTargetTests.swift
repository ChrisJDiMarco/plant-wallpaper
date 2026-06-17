import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Plant interaction hit target")
struct PlantInteractionHitTargetTests {
    @Test("every species has a generous minimum click target")
    func everySpeciesHasGenerousMinimumClickTarget() {
        for species in PlantSpecies.allCases {
            let plant = Plant(
                species: species,
                screenIndex: 0,
                position: GardenPoint(x: 0.50, y: 0.78),
                growth: 0.16
            )

            let target = PlantInteractionHitTarget(plant: plant)

            #expect(target.minimumWidth >= 124)
            #expect(target.minimumHeight >= 136)
            #expect(target.horizontalPaddingRatio >= 0.28)
            #expect(target.bottomPaddingRatio >= 0.28)
        }
    }

    @Test("young flowers get extra grab padding around skinny stems")
    func youngFlowersGetExtraGrabPaddingAroundSkinnyStems() {
        let youngTulip = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.78),
            growth: 0.08
        )
        let matureTulip = Plant(
            species: .tulip,
            screenIndex: 0,
            position: GardenPoint(x: 0.50, y: 0.78),
            growth: 0.88
        )

        let youngTarget = PlantInteractionHitTarget(plant: youngTulip)
        let matureTarget = PlantInteractionHitTarget(plant: matureTulip)

        #expect(youngTarget.minimumWidth > matureTarget.minimumWidth)
        #expect(youngTarget.minimumHeight > matureTarget.minimumHeight)
        #expect(youngTarget.horizontalPaddingRatio >= matureTarget.horizontalPaddingRatio)
    }
}
