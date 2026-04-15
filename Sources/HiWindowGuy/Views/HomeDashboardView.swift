import SwiftUI

struct HomeDashboardView: View {
    @Binding var isWindowManagementEnabled: Bool
    @EnvironmentObject private var appConfig: AppConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("首页")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("新版首页控制面板将在这里实现。")
                .font(.body)
                .foregroundStyle(.secondary)

            Toggle("启用窗口管理", isOn: $isWindowManagementEnabled)
                .toggleStyle(.switch)

            Spacer()
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
    }
}
