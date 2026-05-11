import Foundation

enum CurrentAppRuleMenuSelection {
    static func apply(
        rule: WindowHandlingRule,
        to target: CurrentAppRuleTarget,
        saveRule: (CurrentAppRuleTarget, WindowHandlingRule) -> Void,
        performManualAction: (ManualWindowAction?, CurrentAppRuleTarget) -> Void
    ) {
        saveRule(target, rule)
        performManualAction(manualAction(for: rule), target)
    }

    private static func manualAction(for rule: WindowHandlingRule) -> ManualWindowAction? {
        switch rule {
        case .center:
            return .center
        case .almostMaximize:
            return .almostMaximize
        case .ignore:
            return nil
        }
    }
}
