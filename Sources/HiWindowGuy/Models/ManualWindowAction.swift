import Foundation

enum ManualWindowAction: String, CaseIterable, Codable, Identifiable {
    case center
    case almostMaximize

    var id: String { rawValue }

    var label: String {
        switch self {
        case .center:
            return "居中"
        case .almostMaximize:
            return "几乎最大化"
        }
    }

    var defaultShortcut: ShortcutBinding {
        switch self {
        case .center:
            return ShortcutBinding(key: "c", modifierFlags: [.control, .command])
        case .almostMaximize:
            return ShortcutBinding(key: "m", modifierFlags: [.control, .command])
        }
    }
}
