import CoreGraphics
import Foundation

struct HotkeyConfig: Codable {
    var keyCode: Int64
    var modifierFlags: UInt64  // CGEventFlags raw value

    static let `default` = HotkeyConfig(
        keyCode: 40,  // K
        modifierFlags: CGEventFlags.maskAlternate.rawValue
    )

    static var current: HotkeyConfig {
        get {
            guard let data = UserDefaults.standard.data(forKey: "koe.hotkey"),
                  let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data)
            else { return .default }
            return config
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "koe.hotkey")
                NotificationCenter.default.post(name: .hotkeyConfigChanged, object: nil)
            }
        }
    }

    var displayString: String {
        var parts: [String] = []
        let flags = CGEventFlags(rawValue: modifierFlags)
        if flags.contains(.maskControl)   { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift)     { parts.append("⇧") }
        if flags.contains(.maskCommand)   { parts.append("⌘") }
        parts.append(keyName)
        return parts.joined()
    }

    private var keyName: String {
        let names: [Int64: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
            50: "`", 51: "⌫", 53: "⎋", 123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return names[keyCode] ?? "Key\(keyCode)"
    }
}

extension Notification.Name {
    static let hotkeyConfigChanged = Notification.Name("koe.hotkeyConfigChanged")
}
