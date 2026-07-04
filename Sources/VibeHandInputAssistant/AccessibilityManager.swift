import ApplicationServices
import AppKit

@MainActor
enum AccessibilityManager {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestPermissionPrompt() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
