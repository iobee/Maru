enum StatusBarMenuItem: Equatable {
    case windowManagementToggle
    case manualAction(ManualWindowAction)
    case appConfiguration
    case appRules
    case checkForUpdates
    case quit

    var title: String {
        switch self {
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
        [.windowManagementToggle],
        [.manualAction(.center), .manualAction(.almostMaximize), .manualAction(.moveToNextDisplay)],
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
