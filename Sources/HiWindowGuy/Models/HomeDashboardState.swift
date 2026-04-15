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

    var scaleText: String {
        String(format: "%.0f%%", windowScaleFactor * 100)
    }

    var summaryItems: [SummaryItem] {
        [
            SummaryItem(title: "总计", count: appRules.count),
            SummaryItem(title: "居中", count: count(for: .center)),
            SummaryItem(title: "几乎最大化", count: count(for: .almostMaximize)),
            SummaryItem(title: "忽略", count: count(for: .ignore))
        ]
    }

    private func count(for rule: WindowHandlingRule) -> Int {
        appRules.filter { $0.rule == rule }.count
    }
}
