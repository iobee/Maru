import SwiftUI

struct ContentView: View {
    @State private var isRunning = true
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "window.vertical.closed")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
            
            Text("窗口管理器")
                .font(.title)
                .bold()
            
            Toggle("启用窗口管理", isOn: $isRunning)
                .padding()
                .onChange(of: isRunning) { newValue in
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                        if newValue {
                            appDelegate.windowManager?.startMonitoring()
                        } else {
                            appDelegate.windowManager?.stopMonitoring()
                        }
                    }
                }
            
            HStack {
                Text("应用状态:")
                Text(isRunning ? "运行中" : "已停止")
                    .foregroundColor(isRunning ? .green : .red)
                    .bold()
            }
            
            Text("应用将自动管理窗口大小和位置")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("退出应用") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.vertical)
        }
        .frame(width: 300, height: 300)
        .padding()
    }
} 