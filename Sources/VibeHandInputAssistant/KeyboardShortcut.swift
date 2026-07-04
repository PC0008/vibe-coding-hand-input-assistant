import AppKit
import ApplicationServices

struct KeyboardShortcut: Equatable {
    let keyCode: CGKeyCode
    let modifierFlags: CGEventFlags

    private static let modifierMask: CGEventFlags = [
        .maskCommand,
        .maskControl,
        .maskAlternate,
        .maskShift
    ]

    init(keyCode: CGKeyCode, modifierFlags: CGEventFlags) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags.intersection(Self.modifierMask)
    }

    init?(storageValue: String) {
        let parts = storageValue.split(separator: ":")
        guard parts.count == 2,
              let keyCodeValue = UInt16(parts[0]),
              let flagsValue = UInt64(parts[1]) else {
            return nil
        }
        self.init(keyCode: CGKeyCode(keyCodeValue), modifierFlags: CGEventFlags(rawValue: flagsValue))
    }

    var storageValue: String {
        "\(keyCode):\(modifierFlags.rawValue)"
    }

    var displayName: String {
        var parts: [String] = []
        if modifierFlags.contains(.maskControl) {
            parts.append("Control")
        }
        if modifierFlags.contains(.maskAlternate) {
            parts.append("Option")
        }
        if modifierFlags.contains(.maskShift) {
            parts.append("Shift")
        }
        if modifierFlags.contains(.maskCommand) {
            parts.append("Command")
        }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined(separator: " + ")
    }

    static func from(event: NSEvent) -> KeyboardShortcut? {
        let keyCode = CGKeyCode(event.keyCode)
        guard !modifierOnlyKeyCodes.contains(keyCode) else {
            return nil
        }
        return KeyboardShortcut(
            keyCode: keyCode,
            modifierFlags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
        )
    }

    private static let modifierOnlyKeyCodes: Set<CGKeyCode> = [
        54, 55, 56, 57, 58, 59, 60, 61, 62, 63
    ]

    private static func keyName(for keyCode: CGKeyCode) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Escape"
        case 65: return "."
        case 67: return "*"
        case 69: return "+"
        case 71: return "Clear"
        case 75: return "/"
        case 76: return "Enter"
        case 78: return "-"
        case 81: return "="
        case 82: return "0"
        case 83: return "1"
        case 84: return "2"
        case 85: return "3"
        case 86: return "4"
        case 87: return "5"
        case 88: return "6"
        case 89: return "7"
        case 91: return "8"
        case 92: return "9"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 107: return "F14"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 114: return "Help"
        case 115: return "Home"
        case 116: return "Page Up"
        case 117: return "Forward Delete"
        case 118: return "F4"
        case 119: return "End"
        case 120: return "F2"
        case 121: return "Page Down"
        case 122: return "F1"
        case 123: return "Left"
        case 124: return "Right"
        case 125: return "Down"
        case 126: return "Up"
        default: return "Key \(keyCode)"
        }
    }
}
