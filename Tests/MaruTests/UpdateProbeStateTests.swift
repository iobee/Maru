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
        XCTAssertEqual(AboutUpdateStatusState(probeState: noUpdateCoordinator.state), AboutUpdateStatusState(showsSpinner: false, message: nil, actionTitle: nil))

        var updateCoordinator = UpdateProbeCoordinator()
        XCTAssertTrue(updateCoordinator.startAboutProbeIfNeeded(canStart: true))

        updateCoordinator.markUpdateFound()

        XCTAssertEqual(updateCoordinator.state, .updateAvailable)
        XCTAssertEqual(AboutUpdateStatusState(probeState: updateCoordinator.state), AboutUpdateStatusState(showsSpinner: false, message: nil, actionTitle: "发现新版本，点击更新"))
    }

    func testFailureStopsSpinnerWithoutSurfacingErrorText() {
        var coordinator = UpdateProbeCoordinator()
        XCTAssertTrue(coordinator.startAboutProbeIfNeeded(canStart: true))
        XCTAssertEqual(AboutUpdateStatusState(probeState: coordinator.state), AboutUpdateStatusState(showsSpinner: true, message: nil, actionTitle: nil))

        coordinator.markFailed()

        XCTAssertEqual(coordinator.state, .failed)
        XCTAssertEqual(AboutUpdateStatusState(probeState: coordinator.state), AboutUpdateStatusState(showsSpinner: false, message: nil, actionTitle: nil))
    }

    func testTerminalTransitionsBeforeStartingProbeDoNotLeaveIdleState() {
        var updateCoordinator = UpdateProbeCoordinator()
        updateCoordinator.markUpdateFound()
        XCTAssertEqual(updateCoordinator.state, .idle)

        var noUpdateCoordinator = UpdateProbeCoordinator()
        noUpdateCoordinator.markNoUpdateFound()
        XCTAssertEqual(noUpdateCoordinator.state, .idle)

        var failedCoordinator = UpdateProbeCoordinator()
        failedCoordinator.markFailed()
        XCTAssertEqual(failedCoordinator.state, .idle)
    }

    func testPresentationKeepsUpdateAvailableCopyLowPriority() {
        let state = AboutUpdateStatusState(probeState: .updateAvailable)

        XCTAssertEqual(state.showsSpinner, false)
        XCTAssertNil(state.message)
        XCTAssertEqual(state.actionTitle, "发现新版本，点击更新")
    }

    func testPresentationOnlyExposesUpdateActionWhenUpdateIsAvailable() {
        XCTAssertNil(AboutUpdateStatusState(probeState: .idle).actionTitle)
        XCTAssertNil(AboutUpdateStatusState(probeState: .checking).actionTitle)
        XCTAssertNil(AboutUpdateStatusState(probeState: .failed).actionTitle)
        XCTAssertEqual(AboutUpdateStatusState(probeState: .updateAvailable).actionTitle, "发现新版本，点击更新")
    }
}
