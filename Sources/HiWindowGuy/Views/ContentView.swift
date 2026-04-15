import SwiftUI

struct ContentView: View {
    @Binding var selectedTab: NavigationTab
    @Binding var isWindowManagementEnabled: Bool
    @State private var selectedSection = 0
    @Environment(\.colorScheme) private var colorScheme
    
    // 定义导航项
    enum NavigationSection: Int, CaseIterable, Identifiable {
        case home = 0
        case rules
        case logs
        
        var id: Int { self.rawValue }
        
        var title: String {
            switch self {
            case .home: return "常规"
            case .rules: return "应用规则"
            case .logs: return "日志"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .rules: return "gearshape.fill"
            case .logs: return "doc.text.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏导航
            sidebarView
                .frame(width: 220)
            
            // 主内容区域
            mainContentView
        }
        .frame(minWidth: 800, idealWidth: 900, maxWidth: .infinity, 
               minHeight: 500, idealHeight: 600, maxHeight: .infinity)
        .background(
            colorScheme == .dark ? 
                Color(NSColor.windowBackgroundColor).opacity(0.8) : 
                Color(NSColor.windowBackgroundColor)
        )
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showRulesConfig"))) { _ in
            selectedSection = NavigationSection.rules.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showLogs"))) { _ in
            selectedSection = NavigationSection.logs.rawValue
        }
    }
    
    // 侧边栏视图
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // 应用标题和图标
            HStack {
                Image(systemName: "window.vertical.closed")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Hi Window Guy")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
            Divider()
                .padding(.horizontal, 20)
            
            // 导航菜单
            List(selection: $selectedSection) {
                    ForEach(NavigationSection.allCases) { section in
                    navigationLink(for: section)
                        .listRowBackground(selectedSection == section.rawValue ? 
                                          AnyView(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.blue.opacity(0.2))
                                          ) : 
                                          AnyView(Color.clear))
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            
            Spacer()
            
            // 底部状态指示器
            HStack {
                Circle()
                    .fill(isWindowManagementEnabled ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(isWindowManagementEnabled ? "已启用" : "已停用")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            colorScheme == .dark ? 
                Color(NSColor.controlBackgroundColor).opacity(0.7) : 
                Color(NSColor.controlBackgroundColor).opacity(0.5)
        )
            .onChange(of: selectedSection) { newValue in
                // 根据选择的部分更新标签
                switch newValue {
                case NavigationSection.home.rawValue:
                    selectedTab = .home
                case NavigationSection.rules.rawValue:
                    selectedTab = .rules
                case NavigationSection.logs.rawValue:
                    selectedTab = .logs
                default:
                    break
                }
        }
    }
    
    // 导航链接项
    private func navigationLink(for section: NavigationSection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: section.icon)
                .font(.system(size: 14))
                .foregroundStyle(selectedSection == section.rawValue ? .blue : .secondary)
                .frame(width: 20, height: 20)
            
            Text(section.title)
                .font(.subheadline)
                .foregroundStyle(selectedSection == section.rawValue ? .primary : .secondary)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .tag(section.rawValue)
            }
            
            // 主内容区域
    private var mainContentView: some View {
            Group {
                switch selectedTab {
                case .home:
                    HomeDashboardView(isWindowManagementEnabled: $isWindowManagementEnabled)
                case .rules:
                    RuleConfigView()
                case .logs:
                    LogViewer()
                }
            }
        }
}
