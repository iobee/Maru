import Foundation

struct HomeDashboardState {
    struct SummaryItem: Equatable {
        let title: String
        let count: Int
    }

    struct ManualShortcutItem: Identifiable, Equatable {
        let action: ManualWindowAction
        let title: String
        let currentBinding: ShortcutBinding?
        let defaultBinding: ShortcutBinding

        var id: ManualWindowAction { action }

        var currentBindingText: String {
            currentBinding?.displayText ?? "未设置"
        }

        var defaultBindingText: String {
            defaultBinding.displayText
        }
    }

    let appRules: [AppRule]
    let isEnabled: Bool
    let isStageManagerEnabled: Bool
    let windowScaleFactor: Double
    let manualCenterShortcut: ShortcutBinding?
    let manualAlmostMaximizeShortcut: ShortcutBinding?
    let manualMoveToNextDisplayShortcut: ShortcutBinding?

    init(
        appRules: [AppRule],
        isEnabled: Bool,
        isStageManagerEnabled: Bool = false,
        windowScaleFactor: Double,
        manualCenterShortcut: ShortcutBinding? = nil,
        manualAlmostMaximizeShortcut: ShortcutBinding? = nil,
        manualMoveToNextDisplayShortcut: ShortcutBinding? = nil
    ) {
        self.appRules = appRules
        self.isEnabled = isEnabled
        self.isStageManagerEnabled = isStageManagerEnabled
        self.windowScaleFactor = windowScaleFactor
        self.manualCenterShortcut = manualCenterShortcut
        self.manualAlmostMaximizeShortcut = manualAlmostMaximizeShortcut
        self.manualMoveToNextDisplayShortcut = manualMoveToNextDisplayShortcut
    }

    var statusTitle: String {
        isEnabled ? "已启用" : "已停用"
    }

    var headerTitle: String {
        "常规"
    }

    var headerSubtitle: String {
        "窗口自动管理的运行状态与偏好。"
    }

    var heroTitle: String {
        isEnabled ? "窗口自动管理已开启" : "窗口自动管理已暂停"
    }

    var heroDescription: String {
        "Maru 是一款 macOS 开源工具，可自动将窗口优雅地移动到屏幕中央，让桌面始终简洁、平衡、顺手。"
    }

    var heroToggleTitle: String {
        isEnabled ? "正在管理新窗口" : "启用自动管理"
    }

    var heroToggleSubtitle: String {
        isEnabled ? "当前缩放比例 \(scaleText)" : "关闭时不会自动移动或缩放窗口"
    }

    var scaleText: String {
        String(format: "%.0f%%", windowScaleFactor * 100)
    }

    var scaleTitle: String {
        "呼吸空间"
    }

    var stageManagerTitle: String {
        "Stage Manager"
    }

    var stageManagerStatusTitle: String {
        isStageManagerEnabled ? "已开启" : "未开启"
    }

    var stageManagerDescription: String {
        isStageManagerEnabled
            ? "Stage Manager 已开启。macOS 会将各应用的窗口分组收纳在屏幕一侧，Maru 则在切换应用时自动居中或展开窗口——两者配合，桌面始终整洁有序。"
            : "Stage Manager 是 macOS 内置的窗口分组功能。开启后每个应用的窗口会被自动收纳到屏幕一侧，不会互相堆叠遮挡。建议与 Maru 配合使用，一个负责分组，一个负责定位。"
    }

    var stageManagerToggleTitle: String {
        isStageManagerEnabled ? "配合使用中" : "开启 Stage Manager"
    }

    var stageManagerToggleSubtitle: String {
        isStageManagerEnabled
            ? "切换应用时 Stage Manager 负责窗口分组收纳，Maru 负责居中和呼吸窗口布局，桌面井然有序。"
            : "开启后 Maru 负责窗口位置与大小，Stage Manager 负责按应用分组，专注单个任务时桌面更清爽。"
    }

    var stageManagerErrorPrefix: String {
        "系统设置同步失败："
    }

    var scaleDescription: String {
        "呼吸窗口，是留给窗口的留白——不挤不空，美得恰到好处。"
    }

    var scaleFootnote: String {
        if almostMaximizeCount == 0 {
            return "暂无使用呼吸窗口的规则，添加后可生效。"
        }

        return "\(almostMaximizeCount) 条呼吸窗口规则会使用此间距，居中规则不受影响。"
    }

    var summaryItems: [SummaryItem] {
        [
            SummaryItem(title: "总计", count: appRules.count),
            SummaryItem(title: "居中", count: count(for: .center)),
            SummaryItem(title: "呼吸窗口", count: count(for: .almostMaximize)),
            SummaryItem(title: "忽略", count: count(for: .ignore))
        ]
    }

    var manualShortcutItems: [ManualShortcutItem] {
        [
            ManualShortcutItem(
                action: .center,
                title: ManualWindowAction.center.label,
                currentBinding: manualCenterShortcut,
                defaultBinding: ManualWindowAction.center.defaultShortcut
            ),
            ManualShortcutItem(
                action: .almostMaximize,
                title: ManualWindowAction.almostMaximize.label,
                currentBinding: manualAlmostMaximizeShortcut,
                defaultBinding: ManualWindowAction.almostMaximize.defaultShortcut
            ),
            ManualShortcutItem(
                action: .moveToNextDisplay,
                title: ManualWindowAction.moveToNextDisplay.label,
                currentBinding: manualMoveToNextDisplayShortcut,
                defaultBinding: ManualWindowAction.moveToNextDisplay.defaultShortcut
            )
        ]
    }

    func shortcutItem(for action: ManualWindowAction) -> ManualShortcutItem {
        switch action {
        case .center:
            return manualShortcutItems[0]
        case .almostMaximize:
            return manualShortcutItems[1]
        case .moveToNextDisplay:
            return manualShortcutItems[2]
        }
    }

    private var ruleOverview: String {
        if appRules.isEmpty {
            return "目前还没有应用规则。"
        }

        let centerCount = count(for: .center)
        let almostMaximizeCount = count(for: .almostMaximize)

        return "已配置 \(appRules.count) 条规则，其中 \(centerCount) 条居中、\(almostMaximizeCount) 条呼吸窗口。"
    }

    private var almostMaximizeCount: Int {
        count(for: .almostMaximize)
    }

    private func count(for rule: WindowHandlingRule) -> Int {
        appRules.filter { $0.rule == rule }.count
    }
}
