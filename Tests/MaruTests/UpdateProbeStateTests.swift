import XCTest
@testable import Maru

final class UpdateProbeStateTests: XCTestCase {
    func testAboutProbeStartsOnlyOncePerAppSession() {
        var coordinator = UpdateProbeCoordinator()

        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertTrue(coordinator.startAboutProbeIfNeeded(canStart: true))
        XCTAssertEqual(coordinator.state, .checking)

        coordinator.markNoUpdateFound()

        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertFalse(coordinator.startAboutProbeIfNeeded(canStart: true))
        XCTAssertEqual(coordinator.state, .idle)
    }

    func testDoesNotStartWhenSparkleSessionCannotStart() {
        var coordinator = UpdateProbeCoordinator()

        XCTAssertFalse(coordinator.startAboutProbeIfNeeded(canStart: false))
        XCTAssertEqual(coordinator.state, .idle)

        XCTAssertTrue(coordinator.startAboutProbeIfNeeded(canStart: true))
        XCTAssertEqual(coordinator.state, .checking)
    }

    func testTransitionsForNoUpdateAndAvailableUpdate() {
        var noUpdateCoordinator = UpdateProbeCoordinator()
        XCTAssertTrue(noUpdateCoordinator.startAboutProbeIfNeeded(canStart: true))

        noUpdateCoordinator.markNoUpdateFound()

        XCTAssertEqual(noUpdateCoordinator.state, .idle)
        XCTAssertEqual(AboutUpdateStatusState(probeState: noUpdateCoordinator.state), AboutUpdateStatusState(showsSpinner: false, message: nil))

        var updateCoordinator = UpdateProbeCoordinator()
        XCTAssertTrue(updateCoordinator.startAboutProbeIfNeeded(canStart: true))

        updateCoordinator.markUpdateFound()

        XCTAssertEqual(updateCoordinator.state, .updateAvailable)
        XCTAssertEqual(AboutUpdateStatusState(probeState: updateCoordinator.state), AboutUpdateStatusState(showsSpinner: false, message: "发现新版本"))
    }

    func testFailureStopsSpinnerWithoutSurfacingErrorText() {
        var coordinator = UpdateProbeCoordinator()
        XCTAssertTrue(coordinator.startAboutProbeIfNeeded(canStart: true))
        XCTAssertEqual(AboutUpdateStatusState(probeState: coordinator.state), AboutUpdateStatusState(showsSpinner: true, message: nil))

        coordinator.markFailed()

        XCTAssertEqual(coordinator.state, .failed)
        XCTAssertEqual(AboutUpdateStatusState(probeState: coordinator.state), AboutUpdateStatusState(showsSpinner: false, message: nil))
    }

    func testPresentationKeepsUpdateAvailableCopyLowPriority() {
        let state = AboutUpdateStatusState(probeState: .updateAvailable)
        let fieldLabels = reflectedFieldLabels(in: state)

        XCTAssertEqual(state.showsSpinner, false)
        XCTAssertEqual(state.message, "发现新版本")
        XCTAssertEqual(fieldLabels, ["showsSpinner", "message"])
    }

    private func reflectedFieldLabels(in state: AboutUpdateStatusState) -> Set<String> {
        Set(Mirror(reflecting: state).children.compactMap(\.label))
    }
}
