import SwiftUI

struct RuleConfigView: View {
    @ObservedObject var config = AppConfig.shared
    @State private var searchText = ""
    @State private var selectedRule: AppRule?
    @State private var sortOption = SortOption.lastUsed // 默认按最近使用排序
    @Environment(\.colorScheme) private var colorScheme
    
    enum SortOption: String, CaseIterable, Identifiable {
        case lastUsed = "最近使用"
        case name = "名称"
        case useCount = "使用次数"
        
        var id: String { self.rawValue }
    }
    
    var filteredRules: [AppRule] {
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
    
    // Extract title bar
    private var titleBar: some View {
        HStack {
            Text("应用规则配置")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Spacer()
            
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
                    .padding(.vertical, 6)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(Material.bar)
    }
    
    // Extract empty state view
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            
            Text("没有找到匹配的应用规则")
                .font(.headline)
                .foregroundStyle(.secondary)
                
            Text("尝试使用不同的搜索关键词")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // Extract context menu for a rule
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
                    AppConfig.shared.updateRule(for: rule.bundleId, rule: .ignore)
                } label: {
                    Label("忽略此应用", systemImage: "eye.slash")
                }
            }
            
            if rule.rule != .center {
                Button {
                    AppConfig.shared.updateRule(for: rule.bundleId, rule: .center)
                } label: {
                    Label("设为居中", systemImage: "rectangle.center.inset.filled")
                }
            }
            
            if rule.rule != .almostMaximize {
                Button {
                    AppConfig.shared.updateRule(for: rule.bundleId, rule: .almostMaximize)
                } label: {
                    Label("设为几乎最大化", systemImage: "rectangle.inset.filled")
                }
            }
        }
    }
    
    // Extract rules list view
    private var rulesListView: some View {
        ScrollView {
            if filteredRules.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredRules) { rule in
                        RuleRow(rule: rule)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRule = rule
                            }
                            .contextMenu {
                                contextMenu(for: rule)
                            }
                            .animation(.easeOut(duration: 0.2), value: rule.rule)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.5))
        .safeAreaInset(edge: .bottom) {
            bottomStatusBar
        }
    }
    
    // Extract bottom status bar
    private var bottomStatusBar: some View {
        HStack {
            Label("\(filteredRules.count) 个应用", systemImage: "app.badge")
                .foregroundStyle(.secondary)
                .font(.footnote)
            
            Spacer()
            
            Label("右键点击可快速修改规则", systemImage: "info.circle")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
        .padding()
        .background(Material.thin)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Use extracted title bar
            titleBar
            
            // 搜索栏
            SearchBar(text: $searchText, placeholder: "搜索应用名称或包ID")
                .padding(.horizontal)
                .padding(.vertical, 12)
            
            // Use extracted rules list view
            rulesListView
        }
        .frame(minWidth: 600, idealWidth: 720, maxWidth: 900, minHeight: 450, idealHeight: 550, maxHeight: 700)
        .sheet(item: $selectedRule) { rule in
            RuleEditView(rule: rule)
                .frame(width: 500, height: 400)
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
}

struct RuleRow: View {
    let rule: AppRule
    @Environment(\.colorScheme) private var colorScheme
    
    // Extract rule tag view
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

    // Extract usage statistics view
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
                .fill(colorScheme == .dark ? 
                     Color(NSColor.controlBackgroundColor).opacity(0.3) : 
                     Color(NSColor.controlBackgroundColor).opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
    let rule: AppRule
    @State private var selectedRule: WindowHandlingRule
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    init(rule: AppRule) {
        self.rule = rule
        _selectedRule = State(initialValue: rule.rule)
    }
    
    // Extract a method to create a single rule option button
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
    
    // Simplify ruleSelectorSection to use the extracted method
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
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
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
                        // 改进图标加载，防止失败导致空白
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
                                    .frame(width: 80, height: 80)
                                    .foregroundStyle(.secondary)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                            }
                        }
                        
                        VStack(spacing: 8) {
                            Text(rule.appName)
                                .font(.title2.bold())
                                
                            Text(rule.bundleId)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Use the extracted rule selector section
                    ruleSelectorSection

                    Divider()
                        .padding(.horizontal)
                    
                    // 统计信息
                    HStack(spacing: 20) {
                        VStack(alignment: .center, spacing: 8) {
                            Text("\(rule.useCount)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            Text("使用次数")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Material.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        VStack(alignment: .center, spacing: 8) {
                            Text(formattedDate(rule.lastUsed))
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("最后使用")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Material.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 20)
            }
            
            // 底部按钮
            HStack {
                Button("取消", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button {
                    AppConfig.shared.updateRule(for: rule.bundleId, rule: selectedRule)
                    dismiss()
                } label: {
                    Text("保存")
                        .frame(width: 100)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Material.bar)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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