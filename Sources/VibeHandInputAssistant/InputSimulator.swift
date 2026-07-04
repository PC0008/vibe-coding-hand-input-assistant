import ApplicationServices

enum InputSimulator {
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

    static func functionDown() {
        postKey(KeyCodes.function, keyDown: true, flags: .maskSecondaryFn)
    }

    static func functionUp() {
        postKey(KeyCodes.function, keyDown: false, flags: [])
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

