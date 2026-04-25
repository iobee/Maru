import SwiftUI

enum RuleConfigSortOption: String, CaseIterable, Identifiable {
    case lastUsed = "最近使用"
    case name = "名称"
    case useCount = "使用次数"

    var id: String { self.rawValue }
}

struct RuleConfigSearchTransition: Equatable {
    let isSearchActive: Bool
    let searchText: String
    let shouldActivateApplication: Bool
    let shouldFocusSearchField: Bool
}

struct RuleConfigState {
    static func visibleRules(
        from rules: [AppRule],
        searchText: String,
        sortOption: RuleConfigSortOption
    ) -> [AppRule] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filteredRules: [AppRule]
        if query.isEmpty {
            filteredRules = rules
        } else {
            filteredRules = rules.filter { rule in
                rule.appName.localizedCaseInsensitiveContains(query) ||
                rule.bundleId.localizedCaseInsensitiveContains(query)
            }
        }

        return filteredRules.sorted { lhs, rhs in
            switch sortOption {
            case .name:
                return lhs.appName.localizedCompare(rhs.appName) == .orderedAscending
            case .lastUsed:
                return lhs.lastUsed > rhs.lastUsed
            case .useCount:
                return lhs.useCount > rhs.useCount
            }
        }
    }

    static func searchTransition(isActive: Bool, searchText: String) -> RuleConfigSearchTransition {
        if isActive {
            return RuleConfigSearchTransition(
                isSearchActive: false,
                searchText: "",
                shouldActivateApplication: false,
                shouldFocusSearchField: false
            )
        }

        return RuleConfigSearchTransition(
            isSearchActive: true,
            searchText: searchText,
            shouldActivateApplication: true,
            shouldFocusSearchField: true
        )
    }
}

struct RuleConfigView: View {
    @StateObject private var config = AppConfig.shared
    @State private var selectedRule: AppRule?
    @State private var sortOption = RuleConfigSortOption.lastUsed
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var refreshTrigger = UUID()
    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var visibleRules: [AppRule] {
        _ = config.refreshID

        return RuleConfigState.visibleRules(
            from: config.appRules,
            searchText: searchText,
            sortOption: sortOption
        )
    }

    private var isFilteringRules: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var ruleCountText: String {
        if isFilteringRules {
            return "\(visibleRules.count) / \(config.appRules.count) 条规则"
        }

        return "\(visibleRules.count) 条规则"
    }

    private var subtitleText: String {
        guard !config.appRules.isEmpty else {
            return "集中管理不同应用的窗口行为规则，后续页面也会沿用这套工具面板风格。"
        }

        let centerCount = config.appRules.filter { $0.rule == .center }.count
        let almostMaximizeCount = config.appRules.filter { $0.rule == .almostMaximize }.count

        return "当前共 \(config.appRules.count) 条规则，其中 \(centerCount) 条居中、\(almostMaximizeCount) 条几乎最大化。"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader
                toolRow
                rulesSurface
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 34)
            .padding(.vertical, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .sheet(item: $selectedRule) { rule in
            RuleEditView(rule: rule, config: config, onSave: forceRefresh)
                .frame(width: 520, height: 500)
        }
        .id(refreshTrigger)
        .onReceive(config.objectWillChange) { _ in
            forceRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RuleUpdated"))) { _ in
            forceRefresh()
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("应用规则")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(subtitleText)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var toolRow: some View {
        HStack(spacing: 12) {
            Label(ruleCountText, systemImage: "square.stack.3d.up")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            if isSearchActive {
                searchField
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            Button {
                toggleSearch()
            } label: {
                Image(systemName: isSearchActive ? "xmark" : "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSearchActive ? .blue : .primary)
                    .frame(width: 34, height: 34)
                    .background(toolButtonBackground)
            }
            .buttonStyle(.plain)
            .help(isSearchActive ? "关闭搜索" : "搜索应用规则")

            Menu {
                ForEach(RuleConfigSortOption.allCases) { option in
                    Button {
                        sortOption = option
                    } label: {
                        Label(option.rawValue, systemImage: sortOption == option ? "checkmark" : sortOptionIcon(option))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                    Text("排序：\(sortOption.rawValue)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(toolButtonBackground)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(secondarySurfaceBackground(cornerRadius: 18))
        .animation(.easeInOut(duration: 0.18), value: isSearchActive)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("搜索应用或 Bundle ID", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .focused($isSearchFieldFocused)
                .frame(width: 220)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFieldFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清除搜索")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSearchFieldFocused ? Color.blue.opacity(0.45) : Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12), lineWidth: 1)
        )
    }

    private var rulesSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            if visibleRules.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(visibleRules, id: \.bundleId) { rule in
                        RuleRow(rule: rule)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRule = rule
                            }
                            .contextMenu {
                                contextMenu(for: rule)
                            }
                    }
                }
                .padding(18)
            }

            Divider()
                .overlay(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12))

            bottomStatusBar
        }
        .background(primarySurfaceBackground(cornerRadius: 22))
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: isFilteringRules ? "magnifyingglass" : "square.stack.3d.up.slash")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            Text(isFilteringRules ? "没有匹配的应用规则" : "还没有应用规则")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(isFilteringRules ? "换一个应用名称或 Bundle ID 试试。" : "当应用被记录后，这里会集中显示每个应用的窗口处理方式。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
    }

    private var bottomStatusBar: some View {
        HStack(spacing: 12) {
            Label("\(visibleRules.count) 个应用", systemImage: "app.badge")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            Label("点按编辑，右键快速切换规则", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func contextMenu(for rule: AppRule) -> some View {
        Group {
            Button {
                selectedRule = rule
            } label: {
                Label("编辑规则", systemImage: "pencil")
            }

            Divider()

            if rule.rule != .ignore {
                Button {
                    updateRuleAndRefresh(for: rule.bundleId, rule: .ignore)
                } label: {
                    Label("忽略此应用", systemImage: "eye.slash")
                }
            }

            if rule.rule != .center {
                Button {
                    updateRuleAndRefresh(for: rule.bundleId, rule: .center)
                } label: {
                    Label("设为居中", systemImage: "rectangle.center.inset.filled")
                }
            }

            if rule.rule != .almostMaximize {
                Button {
                    updateRuleAndRefresh(for: rule.bundleId, rule: .almostMaximize)
                } label: {
                    Label("设为几乎最大化", systemImage: "rectangle.inset.filled")
                }
            }
        }
    }

    private func primarySurfaceBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.blue.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.10), lineWidth: 1)
            )
    }

    private func secondarySurfaceBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.02 : 0.38))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12), lineWidth: 1)
            )
    }

    private var toolButtonBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.55))
    }

    private func sortOptionIcon(_ option: RuleConfigSortOption) -> String {
        switch option {
        case .lastUsed:
            return "clock"
        case .name:
            return "textformat"
        case .useCount:
            return "number"
        }
    }

    private func toggleSearch() {
        let transition = RuleConfigState.searchTransition(
            isActive: isSearchActive,
            searchText: searchText
        )

        searchText = transition.searchText
        isSearchActive = transition.isSearchActive
        isSearchFieldFocused = false

        if transition.shouldActivateApplication {
            MaruApplicationActivation.activateForTextInput()
        }

        if transition.shouldFocusSearchField {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFieldFocused = true
            }
        }
    }

    private func forceRefresh() {
        refreshTrigger = UUID()
    }

    private func updateRuleAndRefresh(for bundleId: String, rule: WindowHandlingRule) {
        config.updateRule(for: bundleId, rule: rule)
        forceRefresh()
    }
}

struct RuleRow: View {
    let rule: AppRule
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            appIconView

            VStack(alignment: .leading, spacing: 5) {
                Text(rule.appName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(rule.bundleId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 8) {
                ruleTagView
                usageStatisticsView
            }
        }
        .padding(16)
        .background(rowBackground)
    }

    private var appIconView: some View {
        Group {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: rule.bundleId).first,
               let bundleURL = app.bundleURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 44)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.45))
        )
    }

    private var ruleTagView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ruleSemanticColor.opacity(rule.rule == .center ? 1 : 0.85))
                .frame(width: 6, height: 6)

            Text(ruleLabelText)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .foregroundStyle(rule.rule == .center ? .blue : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(rule.rule == .center ? Color.blue.opacity(0.12) : Color.white.opacity(colorScheme == .dark ? 0.06 : 0.45))
        )
    }

    private var usageStatisticsView: some View {
        HStack(spacing: 8) {
            Label("\(rule.useCount)次", systemImage: "number")
            Text("•")
            Label(formattedRelativeDate(rule.lastUsed), systemImage: "clock")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.34 : 0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.10), lineWidth: 1)
            )
    }

    private var ruleLabelText: String {
        switch rule.rule {
        case .center:
            return "居中"
        case .almostMaximize:
            return "几乎最大化"
        case .ignore:
            return "忽略"
        case .custom:
            return "自定义"
        }
    }

    private var ruleSemanticColor: Color {
        switch rule.rule {
        case .center:
            return .blue
        case .almostMaximize:
            return .green
        case .ignore:
            return .gray
        case .custom:
            return .orange
        }
    }

    private func formattedRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct RuleEditView: View {
    @ObservedObject var config: AppConfig
    let rule: AppRule
    @State private var selectedRule: WindowHandlingRule
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let onSave: () -> Void

    init(rule: AppRule, config: AppConfig, onSave: @escaping () -> Void) {
        self.rule = rule
        self.config = config
        _selectedRule = State(initialValue: rule.rule)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    appSummaryCard
                    ruleSelectorSection
                    usageCard
                }
                .padding(24)
            }

            sheetActions
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("编辑应用规则")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("调整这个应用的窗口处理方式。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            Rectangle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(Rectangle().fill(Color.white.opacity(colorScheme == .dark ? 0.04 : 0.10)))
        )
    }

    private var appSummaryCard: some View {
        HStack(spacing: 16) {
            appIcon

            VStack(alignment: .leading, spacing: 6) {
                Text(rule.appName)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(rule.bundleId)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(cardSurfaceBackground)
    }

    private var appIcon: some View {
        Group {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: rule.bundleId).first,
               let bundleURL = app.bundleURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 60, height: 60)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.45))
        )
    }

    private var ruleSelectorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("窗口处理规则")
                .font(.headline)

            VStack(spacing: 10) {
                ruleOptionButton(for: .center, subtitle: "消息类应用更适合保持居中。")
                ruleOptionButton(for: .almostMaximize, subtitle: "常规应用会按全局缩放比例接近最大化。")
                ruleOptionButton(for: .ignore, subtitle: "不会自动移动或缩放这个应用。")
                ruleOptionButton(for: .custom, subtitle: "为后续扩展保留入口。")
            }
        }
        .padding(20)
        .background(cardSurfaceBackground)
    }

    private func ruleOptionButton(for ruleOption: WindowHandlingRule, subtitle: String) -> some View {
        Button {
            selectedRule = ruleOption
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ruleSemanticColor(for: ruleOption).opacity(selectedRule == ruleOption ? 0.18 : 0.10))
                    Image(systemName: ruleIcon(for: ruleOption))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedRule == ruleOption ? .blue : .secondary)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ruleOption.rawValue)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                if selectedRule == ruleOption {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.22), lineWidth: 1)
                        .frame(width: 18, height: 18)
                }
            }
            .padding(14)
            .background(ruleOptionBackground(isSelected: selectedRule == ruleOption))
        }
        .buttonStyle(.plain)
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("使用统计")
                .font(.headline)

            HStack(spacing: 16) {
                statBlock(title: "使用次数", value: "\(rule.useCount)", alignment: .leading)

                Divider()
                    .overlay(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12))

                statBlock(title: "最后使用", value: formattedDate(rule.lastUsed), alignment: .trailing)
            }
        }
        .padding(20)
        .background(cardSurfaceBackground)
    }

    private func statBlock(title: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var sheetActions: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Text("取消")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                config.updateRule(for: rule.bundleId, rule: selectedRule)
                onSave()
                dismiss()
            } label: {
                Text("保存修改")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            Rectangle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(Rectangle().fill(Color.white.opacity(colorScheme == .dark ? 0.04 : 0.10)))
        )
    }

    private var cardSurfaceBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.blue.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.10), lineWidth: 1)
            )
    }

    private func ruleOptionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isSelected ? Color.blue.opacity(0.10) : Color.white.opacity(colorScheme == .dark ? 0.03 : 0.42))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.blue.opacity(0.18) : Color.white.opacity(colorScheme == .dark ? 0.05 : 0.10), lineWidth: 1)
            )
    }

    private func ruleSemanticColor(for rule: WindowHandlingRule) -> Color {
        switch rule {
        case .center:
            return .blue
        case .almostMaximize:
            return .green
        case .ignore:
            return .gray
        case .custom:
            return .orange
        }
    }

    private func ruleIcon(for rule: WindowHandlingRule) -> String {
        switch rule {
        case .center:
            return "rectangle.center.inset.filled"
        case .almostMaximize:
            return "rectangle.inset.filled"
        case .ignore:
            return "eye.slash.fill"
        case .custom:
            return "slider.horizontal.3"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
