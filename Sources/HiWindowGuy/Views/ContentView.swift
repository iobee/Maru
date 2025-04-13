import SwiftUI
import Foundation

struct ContentView: View {
    @State private var isRunning = true
    @State private var selectedTab = 0
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var logger: AppLogger
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                // 主界面
                mainView
                    .tabItem {
                        Label("主页", systemImage: "house.fill")
                    }
                    .tag(0)
                
                // 规则配置界面
                RuleConfigView()
                    .tabItem {
                        Label("规则配置", systemImage: "gearshape.fill")
                    }
                    .tag(1)
                
                // 日志查看界面
                LogViewer()
                    .tabItem {
                        Label("日志", systemImage: "doc.text.fill")
                    }
                    .tag(2)
            }
        }
        // 在整个视图上应用毛玻璃效果
        .background(Material.ultraThinMaterial)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showRulesConfig"))) { _ in
            selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showLogs"))) { _ in
            selectedTab = 2
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 15) {
            Spacer()
            
            Image(systemName: "window.vertical.closed")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .foregroundColor(.accentColor)
            
            Text("窗口管理器")
                .font(.title2)
                .fontWeight(.semibold)
            
            Toggle("启用窗口管理", isOn: $isRunning)
                .toggleStyle(.switch)
                .padding(.horizontal, 30)
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
            
            HStack {
                Circle()
                    .fill(isRunning ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(isRunning ? "运行中" : "已停止")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 应用统计信息
            statsView
                .padding()
                .background(Color.primary.opacity(0.05)) // 替换毛玻璃效果为轻微背景色
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .padding(.horizontal)
            
            Text("应用将自动管理窗口大小和位置")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                
            Spacer()
        }
        .padding()
        .background(Color.clear) // 移除背景
        .cornerRadius(16)
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 400, minHeight: 400, idealHeight: 450, maxHeight: 500)
    }
    
    private var statsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("应用统计")
                .font(.headline)
                .padding(.bottom, 4)
            
            Divider()
            
            HStack {
                Label {
                    Text("已记录应用")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "app.badge")
                        .foregroundStyle(.purple)
                }
                Spacer()
                Text("\(appConfig.appRules.count)")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(6)
            }
            
            HStack {
                Label {
                    Text("居中处理")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "rectangle.center.inset.filled")
                        .foregroundStyle(.blue)
                }
                Spacer()
                Text("\(appConfig.appRules.filter { $0.rule == .center }.count)")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)
            }
            
            HStack {
                Label {
                    Text("几乎最大化")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "rectangle.inset.filled")
                        .foregroundStyle(.green)
                }
                Spacer()
                Text("\(appConfig.appRules.filter { $0.rule == .almostMaximize }.count)")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(6)
            }
            
            HStack {
                Label {
                    Text("忽略处理")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "eye.slash.fill")
                        .foregroundStyle(.gray)
                }
                Spacer()
                Text("\(appConfig.appRules.filter { $0.rule == .ignore }.count)")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
            }
        }
        .font(.subheadline)
    }
} 