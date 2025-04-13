import SwiftUI
import Foundation

struct ContentView: View {
    @State private var isRunning = true
    @State private var selectedSection = 0
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var logger: AppLogger
    
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
        NavigationSplitView {
            // 侧边栏
            sidebarView
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            NSApplication.shared.terminate(nil)
                        } label: {
                            Label("退出", systemImage: "power")
                                .foregroundStyle(.red)
                        }
                        .help("退出应用")
                    }
                }
        } detail: {
            // 主内容区域
            contentView
        }
        .navigationSplitViewStyle(.automatic)
        .navigationTitle("窗口管理器")
        .frame(minWidth: 800, idealWidth: 900, maxWidth: .infinity, 
               minHeight: 500, idealHeight: 600, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showRulesConfig"))) { _ in
            selectedSection = NavigationSection.rules.rawValue
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showLogs"))) { _ in
            selectedSection = NavigationSection.logs.rawValue
        }
    }
    
    private var sidebarView: some View {
        List(selection: $selectedSection) {
            Section("设置") {
                ForEach(NavigationSection.allCases) { section in
                    NavigationLink(value: section.rawValue) {
                        Label {
                            Text(section.title)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: section.icon)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch NavigationSection(rawValue: selectedSection) {
        case .home:
            homeView
                .navigationTitle("常规")
        case .rules:
            RuleConfigView()
                .navigationTitle("应用规则")
        case .logs:
            LogViewer()
                .navigationTitle("日志")
        case .none:
            // 默认显示主页
            homeView
                .navigationTitle("常规")
        }
    }
    
    private var homeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 标题部分
                HStack {
                    Text("窗口管理")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isRunning ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(isRunning ? "已启用" : "已停用")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                }
                .padding(.bottom, 8)
                
                Divider()
                    .padding(.bottom, 16)
                
                // 主要开关区域
                VStack(alignment: .leading, spacing: 16) {
                    Text("基本设置")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("窗口管理")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("自动调整窗口大小和位置")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $isRunning)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: isRunning) { newValue in
                                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                    if newValue {
                                        appDelegate.windowManager?.startMonitoring()
                                        AppLogger.shared.log("窗口管理已启用", level: .info)
                                    } else {
                                        appDelegate.windowManager?.stopMonitoring()
                                        AppLogger.shared.log("窗口管理已停用", level: .info)
                                    }
                                }
                            }
                    }
                    .padding()
                    .background(Material.ultraThinMaterial)
                    .cornerRadius(10)
                }
                
                Divider()
                    .padding(.vertical, 16)
                
                // 统计区域
                VStack(alignment: .leading, spacing: 16) {
                    Text("应用统计")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        statCard(title: "已记录应用", count: appConfig.appRules.count, icon: "app.badge", color: .purple)
                        
                        statCard(title: "居中处理", 
                                count: appConfig.appRules.filter { $0.rule == .center }.count,
                                icon: "rectangle.center.inset.filled", 
                                color: .blue)
                        
                        statCard(title: "几乎最大化", 
                                count: appConfig.appRules.filter { $0.rule == .almostMaximize }.count,
                                icon: "rectangle.inset.filled", 
                                color: .green)
                        
                        statCard(title: "忽略处理", 
                                count: appConfig.appRules.filter { $0.rule == .ignore }.count,
                                icon: "eye.slash.fill", 
                                color: .gray)
                    }
                }
                
                Spacer()
            }
            .padding(32)
        }
        .background(Color.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func statCard(title: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }
            
            Spacer()
        }
        .padding()
        .background(Material.ultraThinMaterial)
        .cornerRadius(10)
    }
} 