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
        "首页"
    }

    var headerSubtitle: String {
        isEnabled
            ? "像 macOS 控制面板一样集中管理窗口行为。\(ruleOverview)"
            : "窗口自动管理当前已暂停。开启后会按既有规则接管窗口布局。"
    }

    var heroTitle: String {
        isEnabled ? "窗口自动管理已开启" : "窗口自动管理已暂停"
    }

    var heroDescription: String {
        isEnabled
            ? "新的前台窗口会按既有规则自动调整位置和尺寸。\(ruleOverview)"
            : "开启后，新的前台窗口会按既有规则自动调整位置和尺寸。\(ruleOverview)"
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
        "几乎最大化缩放"
    }

    var stageManagerTitle: String {
        "Stage Manager（推荐）"
    }

    var stageManagerStatusTitle: String {
        isStageManagerEnabled ? "已开启" : "未开启"
    }

    var stageManagerDescription: String {
        isStageManagerEnabled
            ? "macOS 系统级窗口分组已开启，可直接配合 HiWindowGuy 的自动布局使用。"
            : "直接切换 macOS 的 Stage Manager，让系统分组与自动窗口布局协同工作。"
    }

    var stageManagerToggleTitle: String {
        isStageManagerEnabled ? "保持推荐工作区模式" : "开启推荐工作区模式"
    }

    var stageManagerToggleSubtitle: String {
        isStageManagerEnabled
            ? "HiWindowGuy 会继续按应用规则整理窗口，Stage Manager 负责保留清晰的系统分组。"
            : "建议与 HiWindowGuy 一起开启，在专注单个任务时更容易保持桌面整洁。"
    }

    var stageManagerErrorPrefix: String {
        "系统设置同步失败："
    }

    var scaleDescription: String {
        "调整常规应用的窗口留白，当前为 \(scaleText)。"
    }

    var scaleFootnote: String {
        if almostMaximizeCount == 0 {
            return "当前还没有使用“几乎最大化”的规则，调整后会在你添加相关规则时生效。"
        }

        return "共有 \(almostMaximizeCount) 条规则会使用这个比例，消息类应用的居中规则不会受影响。"
    }

    var summaryItems: [SummaryItem] {
        [
            SummaryItem(title: "总计", count: appRules.count),
            SummaryItem(title: "居中", count: count(for: .center)),
            SummaryItem(title: "几乎最大化", count: count(for: .almostMaximize)),
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

        return "已配置 \(appRules.count) 条规则，其中 \(centerCount) 条居中、\(almostMaximizeCount) 条几乎最大化。"
    }

    private var almostMaximizeCount: Int {
        count(for: .almostMaximize)
    }

    private func count(for rule: WindowHandlingRule) -> Int {
        appRules.filter { $0.rule == rule }.count
    }
}
