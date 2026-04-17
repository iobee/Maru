import Foundation

struct HomeDashboardState {
    struct SummaryItem: Equatable {
        let title: String
        let count: Int
    }

    let appRules: [AppRule]
    let isEnabled: Bool
    let windowScaleFactor: Double

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
