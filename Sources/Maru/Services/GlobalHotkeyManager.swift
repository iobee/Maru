import Cocoa
import Carbon

final class GlobalHotkeyManager {
    typealias ActionHandler = (ManualWindowAction) -> Void

    private let hotKeySignature: UInt32 = 0x48475747 // "HWGG"
    private let actionHandler: ActionHandler
    private var eventHandlerRef: EventHandlerRef?
    private var registeredHotKeys: [ManualWindowAction: EventHotKeyRef?] = [:]
    private var registeredBindings: [ManualWindowAction: ShortcutBinding?] = [:]

    init(actionHandler: @escaping ActionHandler) {
        self.actionHandler = actionHandler
        installEventHandler()
    }

    deinit {
        unregisterAllHotKeys()
        removeEventHandler()
    }

    func registerCurrentBindings(center: ShortcutBinding?, almostMaximize: ShortcutBinding?, moveToNextDisplay: ShortcutBinding?) {
        register(binding: center, for: .center)
        register(binding: almostMaximize, for: .almostMaximize)
        register(binding: moveToNextDisplay, for: .moveToNextDisplay)
    }

    private func installEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData, let event else {
                    return noErr
                }

                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotKeyEvent(event)
            },
            1,
            &eventSpec,
            selfPointer,
            &eventHandlerRef
        )

        if status != noErr {
            AppLogger.shared.log("注册全局热键事件处理失败: \(status)", level: .error)
        }
    }

    private func removeEventHandler() {
        guard let eventHandlerRef else { return }
        RemoveEventHandler(eventHandlerRef)
        self.eventHandlerRef = nil
    }

    private func unregisterAllHotKeys() {
        for action in ManualWindowAction.allCases {
            unregister(action: action)
        }
    }

    private func register(binding: ShortcutBinding?, for action: ManualWindowAction) {
        guard let binding else {
            unregister(action: action)
            registeredBindings[action] = nil
            AppLogger.shared.log("快捷键已清除，跳过注册: \(action.rawValue)", level: .debug)
            return
        }

        if registeredBindings[action] == binding {
            AppLogger.shared.log("快捷键未变化，跳过重新注册: \(action.rawValue) -> \(binding.displayText)", level: .debug)
            return
        }

        guard let keyCode = carbonKeyCode(for: binding.key) else {
            unregister(action: action)
            registeredBindings[action] = nil
            AppLogger.shared.log("无法解析快捷键按键，跳过注册: \(binding.displayText)", level: .warning)
            return
        }

        let modifiers = carbonModifierFlags(from: binding.modifierFlags)
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: actionHotKeyID(for: action))
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            let previousHotKeyRef = registeredHotKeys[action] ?? nil
            if let previousHotKeyRef {
                let unregisterStatus = UnregisterEventHotKey(previousHotKeyRef)
                if unregisterStatus != noErr {
                    AppLogger.shared.log("替换旧全局热键失败: \(action.rawValue), status=\(unregisterStatus)", level: .warning)
                }
            }
            registeredHotKeys[action] = hotKeyRef
            registeredBindings[action] = binding
            AppLogger.shared.log("已注册全局热键: \(action.rawValue) -> \(binding.displayText)", level: .info)
        } else {
            AppLogger.shared.log("注册全局热键失败: \(action.rawValue) -> \(binding.displayText), status=\(status)", level: .error)
        }
    }

    private func unregister(action: ManualWindowAction) {
        guard let hotKeyRef = registeredHotKeys[action] ?? nil else {
            registeredHotKeys[action] = nil
            registeredBindings[action] = nil
            return
        }

        let status = UnregisterEventHotKey(hotKeyRef)
        if status != noErr {
            AppLogger.shared.log("注销全局热键失败: \(action.rawValue), status=\(status)", level: .warning)
        }
        registeredHotKeys[action] = nil
        registeredBindings[action] = nil
    }

    private func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = withUnsafeMutablePointer(to: &hotKeyID) { hotKeyIDPointer in
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                hotKeyIDPointer
            )
        }

        guard status == noErr else {
            AppLogger.shared.log("读取全局热键事件失败: \(status)", level: .warning)
            return status
        }

        guard hotKeyID.signature == hotKeySignature else {
            return noErr
        }

        guard let action = action(for: hotKeyID.id) else {
            return noErr
        }

        DispatchQueue.main.async { [actionHandler] in
            actionHandler(action)
        }

        return noErr
    }

    private func action(for hotKeyID: UInt32) -> ManualWindowAction? {
        ManualWindowAction.allCases.first { actionHotKeyID(for: $0) == hotKeyID }
    }

    private func actionHotKeyID(for action: ManualWindowAction) -> UInt32 {
        switch action {
        case .center:
            return 1
        case .almostMaximize:
            return 2
        case .moveToNextDisplay:
            return 3
        }
    }

    private func carbonModifierFlags(from modifierFlags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonFlags: UInt32 = 0

        if modifierFlags.contains(.control) {
            carbonFlags |= UInt32(controlKey)
        }
        if modifierFlags.contains(.option) {
            carbonFlags |= UInt32(optionKey)
        }
        if modifierFlags.contains(.shift) {
            carbonFlags |= UInt32(shiftKey)
        }
        if modifierFlags.contains(.command) {
            carbonFlags |= UInt32(cmdKey)
        }

        return carbonFlags
    }

    private func carbonKeyCode(for key: String) -> UInt32? {
        guard let character = key.lowercased().first, key.count == 1 else {
            return nil
        }

        switch character {
        case "a": return 0
        case "s": return 1
        case "d": return 2
        case "f": return 3
        case "h": return 4
        case "g": return 5
        case "z": return 6
        case "x": return 7
        case "c": return 8
        case "v": return 9
        case "b": return 11
        case "q": return 12
        case "w": return 13
        case "e": return 14
        case "r": return 15
        case "y": return 16
        case "t": return 17
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "6": return 22
        case "5": return 23
        case "=": return 24
        case "9": return 25
        case "7": return 26
        case "-": return 27
        case "8": return 28
        case "0": return 29
        case "]": return 30
        case "o": return 31
        case "u": return 32
        case "[": return 33
        case "i": return 34
        case "p": return 35
        case "l": return 37
        case "j": return 38
        case "'": return 39
        case "k": return 40
        case ";": return 41
        case "\\": return 42
        case ",": return 43
        case "/": return 44
        case "n": return 45
        case "m": return 46
        case ".": return 47
        case "`": return 50
        case " ": return 49
        default:
            return nil
        }
    }
}
