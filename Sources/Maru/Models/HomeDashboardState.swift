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

    enum CompanionStatus: Equatable {
        case disabled
        case partial
        case enabled
    }

    struct CompanionChangePlan: Equatable {
        let stageManagerTarget: Bool?
        let dockAutohideTarget: Bool?
    }

    let appRules: [AppRule]
    let isEnabled: Bool
    let isStageManagerEnabled: Bool
    let isDockAutohideEnabled: Bool
    let windowScaleFactor: Double
    let manualCenterShortcut: ShortcutBinding?
    let manualAlmostMaximizeShortcut: ShortcutBinding?
    let manualMoveToNextDisplayShortcut: ShortcutBinding?

    init(
        appRules: [AppRule],
        isEnabled: Bool,
        isStageManagerEnabled: Bool = false,
        isDockAutohideEnabled: Bool = false,
        windowScaleFactor: Double,
        manualCenterShortcut: ShortcutBinding? = nil,
        manualAlmostMaximizeShortcut: ShortcutBinding? = nil,
        manualMoveToNextDisplayShortcut: ShortcutBinding? = nil
    ) {
        self.appRules = appRules
        self.isEnabled = isEnabled
        self.isStageManagerEnabled = isStageManagerEnabled
        self.isDockAutohideEnabled = isDockAutohideEnabled
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

    var companionStatus: CompanionStatus {
        switch (isStageManagerEnabled, isDockAutohideEnabled) {
        case (true, true):
            return .enabled
        case (false, false):
            return .disabled
        default:
            return .partial
        }
    }

    var isCompanionEnabled: Bool {
        companionStatus == .enabled
    }

    var companionTitle: String {
        "Maru 风格好搭子"
    }

    var companionStatusTitle: String {
        switch companionStatus {
        case .enabled:
            return "搭配已就绪"
        case .partial:
            return "部分开启"
        case .disabled:
            return "推荐开启"
        }
    }

    var companionDescription: String {
        "一键开启 Stage Manager 和 Dock 自动隐藏，让窗口分组、居中与呼吸留白自然配合。"
    }

    var companionToggleTitle: String {
        switch companionStatus {
        case .enabled:
            return "推荐搭配正在使用"
        case .partial:
            return "补齐推荐搭配"
        case .disabled:
            return "一键开启推荐搭配"
        }
    }

    var companionToggleSubtitle: String {
        switch companionStatus {
        case .enabled:
            return "Stage Manager 负责窗口分组，Dock 自动隐藏留出更多桌面空间。"
        case .partial where isStageManagerEnabled:
            return "Stage Manager 已开启；打开组合开关即可同时补上 Dock 自动隐藏。"
        case .partial:
            return "Dock 自动隐藏已开启；打开组合开关即可同时补上 Stage Manager。"
        case .disabled:
            return "一个开关同时配置两项系统功能，减少单独理解和设置的成本。"
        }
    }

    var individualSettingsTitle: String {
        "单独设置"
    }

    var individualSettingsSubtitle: String {
        "需要时分别调整这两项系统功能"
    }

    func companionChangePlan(targetEnabled: Bool) -> CompanionChangePlan {
        CompanionChangePlan(
            stageManagerTarget: isStageManagerEnabled == targetEnabled ? nil : targetEnabled,
            dockAutohideTarget: isDockAutohideEnabled == targetEnabled ? nil : targetEnabled
        )
    }

    var stageManagerTitle: String {
        "Stage Manager"
    }

    var stageManagerStatusTitle: String {
        isStageManagerEnabled ? "已开启" : "未开启"
    }

    var stageManagerToggleSubtitle: String {
        isStageManagerEnabled
            ? "窗口正在按应用分组收纳。"
            : "按应用分组收纳窗口，减少桌面堆叠。"
    }

    var stageManagerErrorPrefix: String {
        "系统设置同步失败："
    }

    var dockAutohideTitle: String {
        "自动隐藏 Dock"
    }

    var dockAutohideStatusTitle: String {
        isDockAutohideEnabled ? "已开启" : "未开启"
    }

    var dockAutohideToggleSubtitle: String {
        isDockAutohideEnabled
            ? "Dock 平时收起，需要时从屏幕边缘滑出。"
            : "收起常驻 Dock，为窗口留出更多空间。"
    }

    var dockAutohideErrorPrefix: String {
        "Dock 设置同步失败："
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
