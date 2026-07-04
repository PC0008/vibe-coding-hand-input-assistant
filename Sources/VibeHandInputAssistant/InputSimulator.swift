import ApplicationServices

enum InputSimulator {
    private static let leftCommand: CGKeyCode = 55
    private static let leftShift: CGKeyCode = 56
    private static let leftOption: CGKeyCode = 58
    private static let leftControl: CGKeyCode = 59

    static func tapKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        keyDown(keyCode, flags: flags)
        usleep(20_000)
        keyUp(keyCode, flags: flags)
    }

    static func keyDown(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        postKey(keyCode, keyDown: true, flags: flags)
    }

    static func keyUp(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        postKey(keyCode, keyDown: false, flags: flags)
    }

    static func shortcutDown(_ shortcut: KeyboardShortcut) {
        for modifier in modifierKeyCodes(for: shortcut.modifierFlags) {
            postKey(modifier, keyDown: true, flags: shortcut.modifierFlags)
        }
        postKey(shortcut.keyCode, keyDown: true, flags: shortcut.modifierFlags)
    }

    static func shortcutUp(_ shortcut: KeyboardShortcut) {
        postKey(shortcut.keyCode, keyDown: false, flags: shortcut.modifierFlags)
        for modifier in modifierKeyCodes(for: shortcut.modifierFlags).reversed() {
            postKey(modifier, keyDown: false, flags: [])
        }
    }

    static func functionDown() {
        postKey(KeyCodes.function, keyDown: true, flags: .maskSecondaryFn)
    }

    static func functionUp() {
        postKey(KeyCodes.function, keyDown: false, flags: [])
    }

    static func releaseSafetyKeys() {
        let keyCodes = [
            KeyCodes.function,
            leftCommand,
            leftShift,
            leftOption,
            leftControl,
            KeyCodes.returnKey
        ]
        for keyCode in keyCodes {
            postKey(keyCode, keyDown: false, flags: [])
        }
    }

    private static func modifierKeyCodes(for flags: CGEventFlags) -> [CGKeyCode] {
        var keyCodes: [CGKeyCode] = []
        if flags.contains(.maskControl) {
            keyCodes.append(leftControl)
        }
        if flags.contains(.maskAlternate) {
            keyCodes.append(leftOption)
        }
        if flags.contains(.maskShift) {
            keyCodes.append(leftShift)
        }
        if flags.contains(.maskCommand) {
            keyCodes.append(leftCommand)
        }
        return keyCodes
    }

    private static func postKey(_ keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else {
            return
        }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
}
