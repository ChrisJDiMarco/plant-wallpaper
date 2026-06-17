import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden pointer routing cadence")
struct GardenPointerRoutingCadenceTests {
    @Test("pointer routing refreshes fast enough to arm desktop plant dragging")
    func pointerRoutingRefreshesFastEnoughToArmDesktopPlantDragging() {
        #expect(GardenPointerRoutingCadence.refreshInterval < GardenDisplayCadence.activeRefreshInterval)
        #expect(GardenPointerRoutingCadence.refreshInterval <= 0.05)
    }

    @Test("pointer routing stays separate from visual display cadence")
    func pointerRoutingStaysSeparateFromVisualDisplayCadence() {
        #expect(GardenPointerRoutingCadence.refreshInterval > 1.0 / 60.0)
        #expect(GardenDisplayCadence.calmRefreshInterval > GardenPointerRoutingCadence.refreshInterval)
    }

    @Test("stationary passive pointer polling reuses the current routing")
    func stationaryPassivePointerPollingReusesCurrentRouting() {
        #expect(!GardenPointerRoutingCadence.shouldUpdateMouseRouting(
            previousX: 120,
            previousY: 240,
            currentX: 120.4,
            currentY: 240.3,
            isMouseButtonDown: false,
            hasActiveDrag: false,
            hasActivePress: false,
            isPollingDragActive: false
        ))
    }

    @Test("click and drag states keep pointer routing active")
    func clickAndDragStatesKeepPointerRoutingActive() {
        #expect(GardenPointerRoutingCadence.shouldUpdateMouseRouting(
            previousX: 120,
            previousY: 240,
            currentX: 120,
            currentY: 240,
            isMouseButtonDown: true,
            hasActiveDrag: false,
            hasActivePress: false,
            isPollingDragActive: false
        ))
        #expect(GardenPointerRoutingCadence.shouldUpdateMouseRouting(
            previousX: 120,
            previousY: 240,
            currentX: 120,
            currentY: 240,
            isMouseButtonDown: false,
            hasActiveDrag: true,
            hasActivePress: false,
            isPollingDragActive: false
        ))
    }

    @Test("first pointer routing sample and visible movement update routing")
    func firstPointerRoutingSampleAndVisibleMovementUpdateRouting() {
        #expect(GardenPointerRoutingCadence.shouldUpdateMouseRouting(
            previousX: nil,
            previousY: nil,
            currentX: 120,
            currentY: 240,
            isMouseButtonDown: false,
            hasActiveDrag: false,
            hasActivePress: false,
            isPollingDragActive: false
        ))
        #expect(GardenPointerRoutingCadence.shouldUpdateMouseRouting(
            previousX: 120,
            previousY: 240,
            currentX: 123,
            currentY: 240,
            isMouseButtonDown: false,
            hasActiveDrag: false,
            hasActivePress: false,
            isPollingDragActive: false
        ))
    }
}
