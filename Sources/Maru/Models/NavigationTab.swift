import SwiftUI

enum NavigationTab: String, CaseIterable, Identifiable {
    case home
    case manualControl
    case rules
    case logs
    case about
    
    var id: String { self.rawValue }
    
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
