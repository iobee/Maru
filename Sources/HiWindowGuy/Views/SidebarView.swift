import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: NavigationTab
    
    var body: some View {
        List(selection: $selectedTab) {
            Section("设置") {
                ForEach(NavigationTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(tab)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, maxWidth: 300)
    }
} 