import XCTest
@testable import Maru

final class CurrentAppRuleMenuSelectionTests: XCTestCase {
    private let target = CurrentAppRuleTarget(
        appName: "Codex",
        bundleId: "com.openai.codex",
        processIdentifier: 123
    )

    func testCenterRuleSavesAndPerformsCenterAction() {
        let result = apply(rule: .center)

        XCTAssertEqual(result.savedRule, .center)
        XCTAssertEqual(result.savedTarget, target)
        XCTAssertEqual(result.performedAction, .center)
        XCTAssertEqual(result.performedTarget, target)
    }

    func testAlmostMaximizeRuleSavesAndPerformsAlmostMaximizeAction() {
        let result = apply(rule: .almostMaximize)

        XCTAssertEqual(result.savedRule, .almostMaximize)
        XCTAssertEqual(result.performedAction, .almostMaximize)
    }

    func testIgnoreRuleSavesAndDoesNotPerformManualAction() {
        let result = apply(rule: .ignore)

        XCTAssertEqual(result.savedRule, .ignore)
        XCTAssertNil(result.performedAction)
        XCTAssertEqual(result.performedTarget, target)
    }

    private func apply(rule: WindowHandlingRule) -> (
        savedRule: WindowHandlingRule?,
        savedTarget: CurrentAppRuleTarget?,
        performedAction: ManualWindowAction?,
        performedTarget: CurrentAppRuleTarget?
    ) {
        var savedRule: WindowHandlingRule?
        var savedTarget: CurrentAppRuleTarget?
        var performedAction: ManualWindowAction?
        var performedTarget: CurrentAppRuleTarget?

        CurrentAppRuleMenuSelection.apply(
            rule: rule,
            to: target,
            saveRule: { target, rule in
                savedTarget = target
                savedRule = rule
            },
            performManualAction: { action, target in
                performedAction = action
                performedTarget = target
            }
        )

        return (savedRule, savedTarget, performedAction, performedTarget)
    }
}
