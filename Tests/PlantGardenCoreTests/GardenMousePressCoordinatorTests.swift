import Foundation
import Testing
@testable import PlantGardenCore

@Suite("Garden mouse press coordinator")
struct GardenMousePressCoordinatorTests {
    @Test("handled presses stay active until mouse up")
    func handledPressesStayActiveUntilMouseUp() {
        var coordinator = GardenMousePressCoordinator()

        coordinator.markHandled()

        #expect(coordinator.isPressActive)
    }

    @Test("near duplicate mouse downs are suppressed")
    func nearDuplicateMouseDownsAreSuppressed() {
        let pressDate = Date(timeIntervalSince1970: 1_000)
        var coordinator = GardenMousePressCoordinator()

        coordinator.markHandled(at: pressDate)

        let shouldSuppress = coordinator.shouldSuppressMouseDown(
            at: pressDate.addingTimeInterval(GardenMousePressCoordinator.duplicateSuppressionInterval * 0.5)
        )
        #expect(shouldSuppress)
        #expect(coordinator.isPressActive)
    }

    @Test("stale handled press does not block next mouse down")
    func staleHandledPressDoesNotBlockNextMouseDown() {
        let pressDate = Date(timeIntervalSince1970: 1_000)
        var coordinator = GardenMousePressCoordinator()

        coordinator.markHandled(at: pressDate)

        let shouldSuppress = coordinator.shouldSuppressMouseDown(
            at: pressDate.addingTimeInterval(GardenMousePressCoordinator.duplicateSuppressionInterval + 0.01)
        )
        #expect(!shouldSuppress)
        #expect(!coordinator.isPressActive)
    }

    @Test("mouse up resets duplicate press protection")
    func mouseUpResetsDuplicatePressProtection() {
        var coordinator = GardenMousePressCoordinator(isPressActive: true)

        coordinator.endPress()

        #expect(!coordinator.isPressActive)
    }
}
