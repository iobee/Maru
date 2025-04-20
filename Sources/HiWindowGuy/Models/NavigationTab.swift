import SwiftUI

enum NavigationTab: String, CaseIterable, Identifiable {
    case home
    case rules
    case logs
    
    var id: String { self.rawValue }
    
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