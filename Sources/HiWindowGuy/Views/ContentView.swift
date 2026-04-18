import SwiftUI

struct ContentView: View {
    @Binding var selectedTab: NavigationTab
    @Binding var isWindowManagementEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    // 定义导航项
    enum NavigationSection: Int, CaseIterable, Identifiable {
        case home = 0
        case manualControl
        case rules
        case logs
        case about
        
        var id: Int { self.rawValue }
        
        var title: String {
            switch self {
            case .home: return "常规"
            case .manualControl: return "手动控制"
            case .rules: return "应用规则"
            case .logs: return "日志"
            case .about: return "关于"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .manualControl: return "keyboard.fill"
            case .rules: return "gearshape.fill"
            case .logs: return "doc.text.fill"
            case .about: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 侧边栏导航
            sidebarView
                .frame(width: sidebarWidth)
            
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
            selectedTab = .rules
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showLogs"))) { _ in
            selectedTab = .logs
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
            sidebarBrandIcon

            Text("Hi Window Guy")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var sidebarDivider: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }

    private var sidebarNavigationContent: some View {
        VStack(spacing: 6) {
            ForEach(NavigationSection.allCases) { section in
                sidebarRow(for: section)
            }
        }
        .padding(.top, 8)
    }

    private var sidebarStatusFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isWindowManagementEnabled ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 8, height: 8)

            Text(isWindowManagementEnabled ? "已启用" : "已停用")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
    }

    private var sidebarBrandIcon: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.12))
            .overlay(
                Image(systemName: "window.vertical.closed")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            )
            .frame(width: 38, height: 38)
    }

    private var sidebarContainerBackground: some View {
        SidebarVisualEffectBackground()
            .overlay(
                HStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Rectangle()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.16))
                        .frame(width: 1)
                }
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.06),
                radius: 14,
                x: 0,
                y: 0
            )
    }

    private func sidebarRow(for section: NavigationSection) -> some View {
        Button {
            selectedSectionBinding.wrappedValue = section.rawValue
        } label: {
            HStack(spacing: 12) {
                sidebarRowIcon(for: section)

                Text(section.title)
                    .font(.system(size: 15, weight: currentSection == section ? .semibold : .medium))
                    .foregroundStyle(currentSection == section ? Color.white : Color.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 46, maxHeight: 46, alignment: .leading)
            .background(sidebarSelectionBackground(for: section))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func sidebarRowIcon(for section: NavigationSection) -> some View {
        Image(systemName: section.icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(currentSection == section ? Color.white : Color.secondary)
            .frame(width: 24, height: 24)
            .background(sidebarRowIconPlate(for: section))
    }

    private func sidebarRowIconPlate(for section: NavigationSection) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(currentSection == section ? Color.white.opacity(0.18) : Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45))
    }

    private func sidebarSelectionBackground(for section: NavigationSection) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(currentSection == section ? Color(nsColor: .systemBlue) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(currentSection == section ? 0.12 : 0), lineWidth: 0.8)
            )
    }

    private var sidebarWidth: CGFloat { 248 }
    private var sidebarHorizontalPadding: CGFloat { 14 }
    private var sidebarTopPadding: CGFloat { 20 }
    private var sidebarBottomPadding: CGFloat { 14 }

    // 主内容区域
    private var mainContentView: some View {
            Group {
                switch selectedTab {
                case .home:
                    HomeDashboardView(isWindowManagementEnabled: $isWindowManagementEnabled)
                case .manualControl:
                    ManualControlView()
                case .rules:
                    RuleConfigView()
                case .logs:
                    LogViewer()
                case .about:
                    AboutView()
                }
            }
        }

    private var currentSection: NavigationSection {
        NavigationSection(tab: selectedTab)
    }

    private var selectedSectionBinding: Binding<Int> {
        Binding(
            get: { currentSection.rawValue },
            set: { newValue in
                guard let section = NavigationSection(rawValue: newValue) else {
                    return
                }

                selectedTab = section.tab
            }
        )
    }
}

private extension ContentView.NavigationSection {
    init(tab: NavigationTab) {
        switch tab {
        case .home:
            self = .home
        case .manualControl:
            self = .manualControl
        case .rules:
            self = .rules
        case .logs:
            self = .logs
        case .about:
            self = .about
        }
    }

    var tab: NavigationTab {
        switch self {
        case .home:
            return .home
        case .manualControl:
            return .manualControl
        case .rules:
            return .rules
        case .logs:
            return .logs
        case .about:
            return .about
        }
    }
} 
