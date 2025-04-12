import SwiftUI

struct ContentView: View {
    @State private var isRunning = true
    @State private var selectedTab = 0
    @EnvironmentObject var appConfig: AppConfig
    @EnvironmentObject var logger: AppLogger
    
    var body: some View {
        VStack {
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
                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                .cornerRadius(10)
                .padding(.horizontal)
            
            Text("应用将自动管理窗口大小和位置")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                
            Spacer()
            
            HStack {
                Button {
                    selectedTab = 1
                } label: {
                    Label("规则配置", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                
                Button {
                    selectedTab = 2
                } label: {
                    Label("查看日志", systemImage: "doc.text")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("退出应用", systemImage: "power")
                }
                .accentColor(.red)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 400, minHeight: 400, idealHeight: 450, maxHeight: 500)
    }
    
    private var statsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("应用统计")
                .font(.headline)
                .padding(.bottom, 4)
            
            Divider()
            
            HStack {
                Label("已记录应用", systemImage: "app.badge")
                Spacer()
                Text("\(appConfig.appRules.count)")
                    .fontWeight(.semibold)
            }
            
            HStack {
                Label("居中处理", systemImage: "rectangle.center.inset.filled")
                    .foregroundColor(.blue)
                Spacer()
                Text("\(appConfig.appRules.filter { $0.rule == .center }.count)")
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            HStack {
                Label("几乎最大化", systemImage: "rectangle.inset.filled")
                    .foregroundColor(.green)
                Spacer()
                Text("\(appConfig.appRules.filter { $0.rule == .almostMaximize }.count)")
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            HStack {
                Label("忽略处理", systemImage: "eye.slash.fill")
                    .foregroundColor(.gray)
                Spacer()
                Text("\(appConfig.appRules.filter { $0.rule == .ignore }.count)")
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            }
        }
        .font(.subheadline)
    }
} 