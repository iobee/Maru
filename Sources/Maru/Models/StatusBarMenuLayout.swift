enum StatusBarMenuItem: Equatable, Identifiable {
    case currentAppRuleMenu
    case windowManagementToggle
    case manualAction(ManualWindowAction)
    case appConfiguration
    case appRules
    case checkForUpdates
    case quit

    var id: String {
        switch self {
        case .currentAppRuleMenu:
            return "currentAppRuleMenu"
        case .windowManagementToggle:
            return "windowManagementToggle"
        case .manualAction(let action):
            return "manualAction.\(action.rawValue)"
        case .appConfiguration:
            return "appConfiguration"
        case .appRules:
            return "appRules"
        case .checkForUpdates:
            return "checkForUpdates"
        case .quit:
            return "quit"
        }
    }

    var title: String {
        switch self {
        case .currentAppRuleMenu:
            return "配置当前应用"
        case .windowManagementToggle:
            return "窗口自动管理"
        case .manualAction(let action):
            return action.menuTitle
        case .appConfiguration:
            return "应用配置"
        case .appRules:
            return "应用规则"
        case .checkForUpdates:
            return "检查更新…"
        case .quit:
            return "退出"
        }
    }
}

enum StatusBarMenuLayout {
    static let groups: [[StatusBarMenuItem]] = [
        [.currentAppRuleMenu],
        [.windowManagementToggle, .manualAction(.center), .manualAction(.almostMaximize), .manualAction(.moveToNextDisplay)],
        [.appConfiguration, .appRules, .checkForUpdates],
        [.quit]
    ]
}

extension ManualWindowAction {
    var menuTitle: String {
        switch self {
        case .center:
            return "居中窗口"
        case .almostMaximize:
            return "呼吸窗口"
        case .moveToNextDisplay:
            return "移到下一显示器"
        }
    }
}
