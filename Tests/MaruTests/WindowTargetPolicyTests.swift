import XCTest
@testable import Maru

final class WindowTargetPolicyTests: XCTestCase {
    func testClickingNonStandardAuxiliaryWindowSkipsWithoutPromotingMainWindow() {
        let candidates = [
            candidate(index: 0, isMain: true),
            candidate(index: 1, subrole: "AXDialog", isMain: false, isFocused: true)
        ]

        let result = WindowTargetPolicy.resolve(
            candidates: candidates,
            clickedIndex: 1,
            pointerHitTargetApplication: true,
            focusedIndex: 1,
            mainIndex: 0
        )

        XCTAssertEqual(result, .skip(reason: .auxiliaryWindow))
    }

    func testClickingStandardAuxiliaryWindowWithMainFalseSkips() {
        let candidates = [
            candidate(index: 0, isMain: true),
            candidate(index: 1, isMain: false, isFocused: true)
        ]

        let result = WindowTargetPolicy.resolve(
            candidates: candidates,
            clickedIndex: 1,
            pointerHitTargetApplication: true,
            focusedIndex: 1,
            mainIndex: 0
        )

        XCTAssertEqual(result, .skip(reason: .auxiliaryWindow))
    }

    func testClickedStandardWindowWithoutMainOrFocusEvidenceSkipsConservatively() {
        let candidates = [candidate(index: 0, isMain: nil)]

        let result = WindowTargetPolicy.resolve(
            candidates: candidates,
            clickedIndex: 0,
            pointerHitTargetApplication: true,
            focusedIndex: nil,
            mainIndex: nil
        )

        XCTAssertEqual(result, .skip(reason: .auxiliaryWindow))
    }

    func testClickingIndependentSiblingSelectsOnlyThatWindow() {
        let candidates = [
            candidate(index: 0, isMain: false),
            candidate(index: 1, isMain: true, isFocused: true)
        ]

        let result = WindowTargetPolicy.resolve(
            candidates: candidates,
            clickedIndex: 1,
            pointerHitTargetApplication: true,
            focusedIndex: 1,
            mainIndex: 1
        )

        XCTAssertEqual(result, .select(index: 1))
    }

    func testFocusedAuxiliaryWindowStopsNonPointerResolution() {
        let candidates = [
            candidate(index: 0, isMain: true),
            candidate(index: 1, subrole: "AXFloatingWindow", isMain: false, isFocused: true)
        ]

        let result = WindowTargetPolicy.resolve(
            candidates: candidates,
            clickedIndex: nil,
            pointerHitTargetApplication: false,
            focusedIndex: 1,
            mainIndex: 0
        )

        XCTAssertEqual(result, .skip(reason: .auxiliaryWindow))
    }

    func testNonPointerActivationSelectsFocusedBusinessWindow() {
        let candidates = [candidate(index: 0, isMain: true, isFocused: true)]

        let result = WindowTargetPolicy.resolve(
            candidates: candidates,
            clickedIndex: nil,
            pointerHitTargetApplication: false,
            focusedIndex: 0,
            mainIndex: 0
        )

        XCTAssertEqual(result, .select(index: 0))
    }

    func testFixedSizeMainWindowRemainsEligibleTarget() {
        let candidates = [candidate(index: 0, isMain: true, isFocused: true, isSizeSettable: false)]

        let result = WindowTargetPolicy.resolve(
            candidates: candidates,
            clickedIndex: nil,
            pointerHitTargetApplication: false,
            focusedIndex: 0,
            mainIndex: 0
        )

        XCTAssertEqual(result, .select(index: 0))
    }

    func testAmbiguousBusinessWindowsDoNotBatchOrPickFirst() {
        let candidates = [
            candidate(index: 0, isMain: true),
            candidate(index: 1, isMain: true)
        ]

        let result = WindowTargetPolicy.resolve(
            candidates: candidates,
            clickedIndex: nil,
            pointerHitTargetApplication: false,
            focusedIndex: nil,
            mainIndex: nil
        )

        XCTAssertEqual(result, .skip(reason: .ambiguousWindow))
    }

    func testEmptyCandidateListRequestsRetry() {
        let result = WindowTargetPolicy.resolve(
            candidates: [],
            clickedIndex: nil,
            pointerHitTargetApplication: false,
            focusedIndex: nil,
            mainIndex: nil
        )

        XCTAssertEqual(result, .retry)
    }

    func testStandardWindowAwaitingMainAndFocusRelationshipsRequestsRetry() {
        let candidates = [candidate(index: 0, isMain: false)]

        let result = WindowTargetPolicy.resolve(
            candidates: candidates,
            clickedIndex: nil,
            pointerHitTargetApplication: false,
            focusedIndex: nil,
            mainIndex: nil
        )

        XCTAssertEqual(result, .retry)
    }

    func testObviousAuxiliaryCandidateWithoutFocusDoesNotEnterRetryLoop() {
        let candidates = [candidate(index: 0, subrole: "AXDialog", isMain: false)]

        let result = WindowTargetPolicy.resolve(
            candidates: candidates,
            clickedIndex: nil,
            pointerHitTargetApplication: false,
            focusedIndex: nil,
            mainIndex: nil
        )

        XCTAssertEqual(result, .skip(reason: .noManageableWindow))
    }

    private func candidate(
        index: Int,
        subrole: String? = "AXStandardWindow",
        isMain: Bool?,
        isFocused: Bool = false,
        isSizeSettable: Bool = true
    ) -> WindowTargetCandidate {
        WindowTargetCandidate(
            index: index,
            role: "AXWindow",
            subrole: subrole,
            isMinimized: false,
            isModal: false,
            isMain: isMain,
            isFocused: isFocused,
            parentRole: "AXApplication",
            isPositionSettable: true,
            isSizeSettable: isSizeSettable,
            hasReadableFrame: true
        )
    }
}
