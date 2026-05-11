import Foundation

struct CurrentAppRuleMenuState: Equatable {
    let target: CurrentAppRuleTarget?
    let title: String
    let selectedRule: WindowHandlingRule?
    let ruleOptions: [WindowHandlingRule]

    init(target: CurrentAppRuleTarget?, appRules: [AppRule]) {
        self.target = target
        self.ruleOptions = [.almostMaximize, .center, .ignore]

        guard let target else {
            self.title = "当前应用不可用"
            self.selectedRule = nil
            return
        }

        self.title = "配置当前应用：\(target.appName)"
        self.selectedRule = appRules.first(where: { $0.bundleId == target.bundleId })?.rule ?? .almostMaximize
    }
}

extension WindowHandlingRule {
    var currentAppRuleMenuTitle: String {
        switch self {
        case .almostMaximize:
            return "呼吸窗口"
        case .center:
            return "居中窗口"
        case .ignore:
            return "忽略此应用"
        }
    }
}
