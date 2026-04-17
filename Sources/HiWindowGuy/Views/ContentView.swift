import SwiftUI
import Foundation
import AppKit
import OSLog

struct ContentView: View {
    @Binding var selectedTab: NavigationTab
    @EnvironmentObject var appConfig: AppConfig
    @State private var isRunning = true
    @State private var selectedSection = 0
    @EnvironmentObject var appLogger: AppLogger
    @StateObject private var windowManager = WindowManager()
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
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 侧边栏导航
                sidebarView
                    .frame(width: 220)
                
                // 主内容区域
                mainContentView
            }
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
            sidebarBrandHeader
            sidebarDivider
            sidebarNavigationContent
            Spacer()
            sidebarStatusFooter
        }
        .padding(.vertical, sidebarVerticalPadding)
        .padding(.horizontal, sidebarHorizontalPadding)
        .background(sidebarContainerBackground)
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

    private var sidebarBrandHeader: some View {
        HStack(spacing: 10) {
            sidebarBrandIcon

            VStack(alignment: .leading, spacing: 2) {
                Text("Hi Window Guy")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Window rules")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private var sidebarDivider: some View {
        Divider()
            .padding(.vertical, 10)
            .opacity(0.7)
    }

    private var sidebarBrandIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.95),
                            Color.cyan.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "window.vertical.closed")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 30, height: 30)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private var sidebarContainerBackground: some View {
        let fillColor = colorScheme == .dark
            ? Color(NSColor.controlBackgroundColor).opacity(0.88)
            : Color(NSColor.controlBackgroundColor).opacity(0.72)

        return RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08),
                radius: 18,
                x: 0,
                y: 8
            )
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
                    homeView
                case .rules:
                    RuleConfigView()
                case .logs:
                    LogViewer()
                }
            }
        }
    
    // 主页内容
    private var homeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // 标题部分
                HStack(spacing: 0) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                    VStack(alignment: .leading, spacing: 4) {
                    Text("窗口管理")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.primary)
                            
                        Text("管理和控制窗口尺寸和位置")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 12)
                    
                    Spacer()
                }
                .padding(.bottom, 10)
                
                // 设置卡片
                settingsCard
                
                // 窗口缩放设置卡片
                scaleFactorCard
                
                // 统计卡片
                statsView
                
                Spacer()
                }
            .padding(30)
        }
        .background(Color.clear)
    }
    
    // 开关设置卡片
    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("窗口管理")
                        .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("自动调整窗口大小和位置")
                                .font(.subheadline)
                        .foregroundStyle(.secondary)
                        }
                .padding(.leading, 4)
                        
                        Spacer()
                        
                        Toggle("", isOn: $isRunning)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    .scaleEffect(1.1)
                            .onChange(of: isRunning) { newValue in
                                if newValue {
                                    appLogger.log("窗口管理已启用", level: .info)
                                } else {
                                    appLogger.log("窗口管理已停用", level: .info)
                                }
                            }
                    }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.regularMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    // 窗口缩放设置卡片
    private var scaleFactorCard: some View {
        VStack(alignment: .leading, spacing: 20) {
                        HStack {
                VStack(alignment: .leading, spacing: 6) {
                                Text("窗口缩放比例")
                        .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("控制「几乎最大化」时窗口的大小")
                                    .font(.subheadline)
                        .foregroundStyle(.secondary)
                            }
                .padding(.leading, 4)
                            
                            Spacer()
                            
                            Text("\(Int(appConfig.windowScaleFactor * 100))%")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.blue)
                                .monospacedDigit()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                        }
                        
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "rectangle.compress.vertical")
                        .foregroundStyle(.secondary)
                    
                            Slider(
                                value: $appConfig.windowScaleFactor,
                                in: 0.7...0.97,
                                step: 0.01
                            )
                    .tint(.blue)
                    
                    Image(systemName: "rectangle.expand.vertical")
                        .foregroundStyle(.secondary)
                }
                            
                            HStack {
                                Text("更紧凑")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text("更宽敞")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 4)
                        }
                    }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.regularMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
                }
                
    // 统计数据视图
    private var statsView: some View {
        VStack(alignment: .leading, spacing: 20) {
                    Text("应用统计")
                        .font(.headline)
                .fontWeight(.semibold)
                .padding(.leading, 4)
                    
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
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.regularMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    // 统计卡片
    private func statCard(title: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("\(count)")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Material.ultraThinMaterial)
        )
    }
} 
