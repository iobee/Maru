import SwiftUI

struct RuleConfigView: View {
    @StateObject private var config = AppConfig.shared
    @State private var searchText = ""
    @State private var selectedRule: AppRule?
    @State private var sortOption = SortOption.lastUsed // 默认按最近使用排序
    @State private var refreshTrigger = UUID() // 强制刷新触发器
    @Environment(\.colorScheme) private var colorScheme
    
    enum SortOption: String, CaseIterable, Identifiable {
        case lastUsed = "最近使用"
        case name = "名称"
        case useCount = "使用次数"
        
        var id: String { self.rawValue }
    }
    
    var filteredRules: [AppRule] {
        // 使用 refreshID 来确保视图刷新
        _ = config.refreshID
        
        let rules = config.appRules
        
        // 搜索过滤
        let filtered = searchText.isEmpty ? 
            rules : 
            rules.filter { $0.appName.localizedCaseInsensitiveContains(searchText) || $0.bundleId.localizedCaseInsensitiveContains(searchText) }
        
        // 排序
        return filtered.sorted { (lhs, rhs) in
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
    
    // 页面标题区域
    private var headerView: some View {
        HStack(spacing: 0) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
            VStack(alignment: .leading, spacing: 4) {
                Text("应用规则配置")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    
                Text("管理不同应用的窗口行为")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 12)
            
            Spacer()
            
            // 排序菜单
            Menu {
                ForEach(SortOption.allCases) { option in
                    Button {
                        sortOption = option
                    } label: {
                        Label(option.rawValue, systemImage: sortOptionIcon(option))
                    }
                }
            } label: {
                Label("排序: \(sortOption.rawValue)", systemImage: "arrow.up.arrow.down")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Material.regularMaterial)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 20)
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            
            Text("没有找到匹配的应用规则")
                .font(.headline)
                .foregroundStyle(.primary)
                
            Text("尝试使用不同的搜索关键词")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
            Button {
                searchText = ""
            } label: {
                Text("清除搜索")
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // 规则上下文菜单
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
    
    // 规则列表视图
    private var rulesListView: some View {
        ScrollView {
            if filteredRules.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(filteredRules, id: \.bundleId) { rule in
                        RuleRow(rule: rule)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRule = rule
                            }
                            .contextMenu {
                                contextMenu(for: rule)
                            }
                            .animation(.easeOut(duration: 0.2), value: rule.rule)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 16)
            }
        }
        .background(Color.clear)
        .safeAreaInset(edge: .bottom) {
            bottomStatusBar
        }
    }
    
    // 底部状态栏
    private var bottomStatusBar: some View {
        HStack {
            Label("\(filteredRules.count) 个应用", systemImage: "app.badge")
                .foregroundStyle(.secondary)
                .font(.footnote.bold())
            
            Spacer()
            
            Label("右键点击可快速修改规则", systemImage: "info.circle")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 14)
        .background(
            Rectangle()
                .fill(Material.thin)
                .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题区域
            headerView
            
            // 搜索栏
            SearchBar(text: $searchText, placeholder: "搜索应用名称或包ID")
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            
            // 规则列表
            rulesListView
        }
        .background(Color.clear)
        .sheet(item: $selectedRule) { rule in
            RuleEditView(rule: rule, config: config, onSave: forceRefresh)
                .frame(width: 500, height: 440)
        }
        .id(refreshTrigger) // 使用 ID 修饰符强制刷新整个视图
        .onReceive(config.objectWillChange) { _ in
            forceRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RuleUpdated"))) { _ in
            forceRefresh()
        }
    }
    
    private func sortOptionIcon(_ option: SortOption) -> String {
        switch option {
        case .lastUsed:
            return "clock"
        case .name:
            return "textformat"
        case .useCount:
            return "number"
        }
    }
    
    // 强制刷新视图的方法
    private func forceRefresh() {
        refreshTrigger = UUID()
    }
    
    // 更新规则并刷新
    private func updateRuleAndRefresh(for bundleId: String, rule: WindowHandlingRule) {
        // 更新规则 - AppConfig 内部会刷新 refreshID
        config.updateRule(for: bundleId, rule: rule)
        // 强制刷新视图
        forceRefresh()
    }
}

struct RuleRow: View {
    let rule: AppRule
    @Environment(\.colorScheme) private var colorScheme
    
    // 规则标签视图
    private var ruleTagView: some View {
        HStack(spacing: 6) {
            Image(systemName: ruleIcon(for: rule.rule))
            Text(rule.rule.rawValue)
        }
        .font(.subheadline.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ruleColor(for: rule.rule))
        .clipShape(Capsule())
    }

    // 使用统计视图
    private var usageStatisticsView: some View {
        HStack(spacing: 8) {
            Label("\(rule.useCount)次", systemImage: "number")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("•")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Label("\(formattedRelativeDate(rule.lastUsed))", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // 应用图标，优化加载逻辑
            Group {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: rule.bundleId).first,
                   let bundleURL = app.bundleURL {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .padding(4)
                        .foregroundStyle(.secondary)
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.appName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    
                Text(rule.bundleId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                // Use extracted views
                ruleTagView
                usageStatisticsView
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    private func formattedRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
    
    private func ruleColor(for rule: WindowHandlingRule) -> Color {
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
}

struct RuleEditView: View {
    @ObservedObject var config: AppConfig
    let rule: AppRule
    @State private var selectedRule: WindowHandlingRule
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let onSave: () -> Void
    
    init(rule: AppRule, config: AppConfig, onSave: @escaping () -> Void) {
        self.rule = rule
        self.config = config
        _selectedRule = State(initialValue: rule.rule)
        self.onSave = onSave
    }
    
    // 规则选项按钮
    private func ruleOptionButton(for ruleOption: WindowHandlingRule) -> some View {
        Button {
            selectedRule = ruleOption
        } label: {
            HStack {
                Image(systemName: ruleIcon(for: ruleOption))
                    .font(.system(size: 18))
                    .foregroundStyle(ruleColor(for: ruleOption))
                    .frame(width: 30)
                
                Text(ruleOption.rawValue)
                    .font(.body)
                
                Spacer()
                
                if selectedRule == ruleOption {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedRule == ruleOption ?
                          (colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1)) :
                          Color(nsColor: NSColor.controlBackgroundColor).opacity(0.7))
            )
        }
        .buttonStyle(.plain)
    }
    
    // 规则选择区域
    private var ruleSelectorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("窗口处理规则")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: 12) {
                // 显式列出所有规则
                ruleOptionButton(for: .center)
                ruleOptionButton(for: .almostMaximize)
                ruleOptionButton(for: .ignore)
                ruleOptionButton(for: .custom)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("编辑应用规则")
                    .font(.title3.bold())
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Material.bar)
            
            // 内容区域
            ScrollView {
                VStack(spacing: 24) {
                    // 应用信息
                    VStack(spacing: 24) {
                        // 应用图标
                        Group {
                            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: rule.bundleId).first,
                               let bundleURL = app.bundleURL {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                            } else {
                                // 备用图标
                                Image(systemName: "app.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .padding(10)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        VStack(spacing: 8) {
                            Text(rule.appName)
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                            
                            Text(rule.bundleId)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    // 规则选择区域
                    ruleSelectorSection
                    
                    // 用量统计
                    VStack(alignment: .leading, spacing: 12) {
                        Text("使用统计")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("使用次数")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                Text("\(rule.useCount)")
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("最后使用")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                Text(formattedDate(rule.lastUsed))
                                    .font(.callout)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.05))
                        )
                    }
                }
                .padding()
            }
            
            // 底部按钮区域
            HStack {
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
            }
            .padding()
            .background(Material.bar)
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
    
    private func ruleColor(for rule: WindowHandlingRule) -> Color {
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
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
} 