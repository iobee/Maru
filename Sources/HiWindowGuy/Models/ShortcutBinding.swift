import Foundation
import AppKit

struct ShortcutBinding: Codable, Equatable {
    let key: String
    private let modifierFlagsRawValue: UInt

    init(key: String, modifierFlags: NSEvent.ModifierFlags) {
        self.key = key.lowercased()
        self.modifierFlagsRawValue = modifierFlags.rawValue
    }

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue)
    }

    var displayText: String {
        var components: [String] = []

        if modifierFlags.contains(.control) {
            components.append("Ctrl")
        }
        if modifierFlags.contains(.command) {
            components.append("Cmd")
        }
        if modifierFlags.contains(.option) {
            components.append("Opt")
        }
        if modifierFlags.contains(.shift) {
            components.append("Shift")
        }

        components.append(key.uppercased())
        return components.joined(separator: "+")
    }

    func asJSONObject() -> [String: Any] {
        [
            "key": key,
            "modifierFlagsRawValue": Int(modifierFlagsRawValue)
        ]
    }

    init?(jsonObject: [String: Any]) {
        guard let key = jsonObject["key"] as? String else {
            return nil
        }

        if let rawValue = jsonObject["modifierFlagsRawValue"] as? Int {
            self.init(key: key, modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(rawValue)))
        } else if let rawValue = jsonObject["modifierFlagsRawValue"] as? UInt {
            self.init(key: key, modifierFlags: NSEvent.ModifierFlags(rawValue: rawValue))
        } else if let rawValue = jsonObject["modifierFlagsRawValue"] as? NSNumber {
            self.init(key: key, modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(rawValue.uintValue)))
        } else {
            return nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case modifierFlagsRawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key).lowercased()
        modifierFlagsRawValue = try container.decode(UInt.self, forKey: .modifierFlagsRawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(modifierFlagsRawValue, forKey: .modifierFlagsRawValue)
    }
}
