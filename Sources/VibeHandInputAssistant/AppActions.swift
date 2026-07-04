import AppKit
import Foundation

@MainActor
final class AppActions {
    private let settings: SettingsStore

    init(settings: SettingsStore = .shared) {
        self.settings = settings
    }

    func openTargetApp() {
        let target = settings.selectedTarget

        if !target.bundleIdentifier.isEmpty {
            if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleIdentifier).first {
                runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                return
            }

            if runOpen(arguments: ["-b", target.bundleIdentifier]) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleIdentifier)
                        .first?
                        .activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                }
                return
            }
        }

        if !target.appName.isEmpty {
            _ = runOpen(arguments: ["-a", target.appName])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == target.appName }) {
                    runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                }
            }
        }
    }

    func voiceDown() {
        switch settings.voiceMode {
        case .fn:
            InputSimulator.functionDown()
        case .shortcut:
            // Placeholder for the next milestone. Keep Fn as the safe default.
            InputSimulator.functionDown()
        }
    }

    func voiceUp() {
        switch settings.voiceMode {
        case .fn:
            InputSimulator.functionUp()
        case .shortcut:
            InputSimulator.functionUp()
        }
    }

    func sendMessage() {
        switch settings.sendMode {
        case .returnKey:
            InputSimulator.tapKey(KeyCodes.returnKey)
        case .commandReturn:
            InputSimulator.tapKey(KeyCodes.returnKey, flags: .maskCommand)
        }
    }

    private func runOpen(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
