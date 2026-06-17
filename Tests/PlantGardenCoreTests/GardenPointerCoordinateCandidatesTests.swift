import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden pointer coordinate candidates")
struct GardenPointerCoordinateCandidatesTests {
    @Test("pointer routing trusts the converted y coordinate")
    func pointerRoutingTrustsConvertedCoordinate() {
        let candidates = GardenPointerCoordinateCandidates.yValues(convertedY: 240, viewHeight: 1080)

        #expect(candidates == [240])
    }

    @Test("pointer routing never probes mirrored fallback coordinates")
    func pointerRoutingNeverProbesMirroredCoordinates() {
        for y in stride(from: 0.0, through: 1080.0, by: 135.0) {
            let candidates = GardenPointerCoordinateCandidates.yValues(convertedY: y, viewHeight: 1080)
            #expect(candidates == [y], "Clicking at y=\(y) must hit test only that point")
        }
    }
}
