import Foundation

enum ManualWindowAction: String, CaseIterable, Codable, Identifiable {
    case center
    case almostMaximize
    case moveToNextDisplay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .center:
            return "居中"
        case .almostMaximize:
            return "几乎最大化"
        case .moveToNextDisplay:
            return "移到下一个显示器并铺满"
        }
    }

    var defaultShortcut: ShortcutBinding {
        switch self {
        case .center:
            return ShortcutBinding(key: "c", modifierFlags: [.control, .command])
        case .almostMaximize:
            return ShortcutBinding(key: "m", modifierFlags: [.control, .command])
        case .moveToNextDisplay:
            return ShortcutBinding(key: "n", modifierFlags: [.control, .command])
        }
    }
}
