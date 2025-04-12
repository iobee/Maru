import SwiftUI

struct RuleConfigView: View {
    @ObservedObject var config = AppConfig.shared
    @State private var searchText = ""
    @State private var selectedRule: AppRule?
    @State private var sortOption = SortOption.lastUsed // 默认按最近使用排序
    
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("应用规则配置")
                    .font(.title2.weight(.semibold))
                
                Spacer()
                
                Picker("排序", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 120)
            }
            .padding()
            
            SearchBar(text: $searchText, placeholder: "搜索应用名称或包ID")
                .padding(.horizontal)
                .padding(.bottom, 10)
            
            Divider()
            
            List {
                ForEach(filteredRules) { rule in
                    RuleRow(rule: rule)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRule = rule
                        }
                        .contextMenu { // 添加右键菜单
                            Button {
                                selectedRule = rule
                            } label: {
                                Label("编辑规则", systemImage: "pencil")
                            }
                            
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
            }
            .listStyle(PlainListStyle())
            
            Divider()
            
            HStack {
                Text("共 \(filteredRules.count) 个应用")
                    .foregroundColor(.secondary)
                    .font(.footnote)
                
                Spacer()
                
                Text("右键点击可快速修改规则")
                    .foregroundColor(.secondary)
                    .font(.footnote)
            }
            .padding()
        }
        .frame(minWidth: 500, idealWidth: 600, maxWidth: 800, minHeight: 350, idealHeight: 450, maxHeight: 600)
        .sheet(item: $selectedRule) { rule in
            RuleEditView(rule: rule)
                .frame(minWidth: 400, idealWidth: 450, maxWidth: 500, minHeight: 300, idealHeight: 350, maxHeight: 400)
        }
    }
}

struct RuleRow: View {
    let rule: AppRule
    
    var body: some View {
        HStack(spacing: 15) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: NSRunningApplication.runningApplications(withBundleIdentifier: rule.bundleId).first?.bundleURL?.path ?? ""))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.appName)
                    .font(.headline)
                    
                Text(rule.bundleId)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: ruleIcon(for: rule.rule))
                    Text(rule.rule.rawValue)
                }
                .font(.subheadline)
                .foregroundColor(ruleColor(for: rule.rule))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(ruleColor(for: rule.rule).opacity(0.15))
                .clipShape(Capsule())
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("\(formattedRelativeDate(rule.lastUsed))")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
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
    @Environment(\.presentationMode) var presentationMode // 使用旧的 presentationMode
    
    init(rule: AppRule) {
        self.rule = rule
        _selectedRule = State(initialValue: rule.rule)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("编辑应用规则: \(rule.appName)")
                .font(.title3.weight(.semibold))
                .padding(.top)
                
            Divider()
            
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: NSRunningApplication.runningApplications(withBundleIdentifier: rule.bundleId).first?.bundleURL?.path ?? ""))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading) {
                        Text(rule.appName)
                            .font(.title2)
                            
                        Text(rule.bundleId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("窗口处理规则")
                        .font(.headline)
                    
                    Picker("窗口处理规则", selection: $selectedRule) {
                        ForEach(WindowHandlingRule.allCases) { rule in
                            HStack {
                                Image(systemName: ruleIcon(for: rule))
                                Text(rule.rawValue)
                            }
                            .tag(rule)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .labelsHidden()
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("最后使用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(formattedDate(rule.lastUsed))")
                            .font(.subheadline)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("使用次数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(rule.useCount)")
                            .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            HStack {
                Button("取消") { // 移除 role 参数
                    presentationMode.wrappedValue.dismiss()
                }
                
                Spacer()
                
                Button("保存") {
                    AppConfig.shared.updateRule(for: rule.bundleId, rule: selectedRule)
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.bordered) // 使用 bordered 样式
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
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
} 