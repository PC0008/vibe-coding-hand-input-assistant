import AppKit
import Foundation

@MainActor
final class AppActions {
    private let settings: SettingsStore
    private var activeVoiceShortcut: KeyboardShortcut?

    init(settings: SettingsStore = .shared) {
        self.settings = settings
    }

    func openTargetApp() {
        let target = settings.selectedTarget

        if !target.bundleIdentifier.isEmpty {
            activateTarget(bundleIdentifier: target.bundleIdentifier, appName: target.appName)
            return
        }

        if !target.appName.isEmpty {
            activateTarget(bundleIdentifier: nil, appName: target.appName)
        }
    }

    func voiceDown() {
        switch settings.voiceMode {
        case .fn:
            InputSimulator.functionDown()
        case .shortcut:
            if let shortcut = settings.customVoiceShortcut {
                activeVoiceShortcut = shortcut
                InputSimulator.shortcutDown(shortcut)
            }
        }
    }

    func voiceUp() {
        switch settings.voiceMode {
        case .fn:
            InputSimulator.functionUp()
        case .shortcut:
            if let shortcut = activeVoiceShortcut ?? settings.customVoiceShortcut {
                InputSimulator.shortcutUp(shortcut)
            }
            activeVoiceShortcut = nil
        }
    }

    func releaseKeys() {
        if let activeVoiceShortcut {
            InputSimulator.shortcutUp(activeVoiceShortcut)
            self.activeVoiceShortcut = nil
        }
        InputSimulator.releaseSafetyKeys()
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

    private func activateTarget(bundleIdentifier: String?, appName: String?) {
        if let bundleIdentifier,
           !bundleIdentifier.isEmpty {
            _ = runOpen(arguments: ["-b", bundleIdentifier])
            _ = runAppleScript(lines: [
                #"tell application id "\#(bundleIdentifier)" to activate"#,
                #"tell application "System Events" to set frontmost of first process whose bundle identifier is "\#(bundleIdentifier)" to true"#
            ])
            _ = activateRunningApp(bundleIdentifier: bundleIdentifier)

            if !openApplication(bundleIdentifier: bundleIdentifier) {
                activateAfterDelay(bundleIdentifier: bundleIdentifier, appName: appName)
            }
            return
        }

        if let appName,
           !appName.isEmpty {
            _ = runOpen(arguments: ["-a", appName])
            _ = runAppleScript(lines: [
                #"tell application "\#(appName)" to activate"#,
                #"tell application "System Events" to set frontmost of first process whose name is "\#(appName)" to true"#
            ])
            _ = activateRunningApp(appName: appName)

            if !openApplication(appName: appName) {
                activateAfterDelay(bundleIdentifier: bundleIdentifier, appName: appName)
            }
        }
    }

    private func runAppleScript(lines: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = lines.flatMap { ["-e", $0] }
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func openApplication(bundleIdentifier: String) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return false
        }
        return openApplication(at: url, bundleIdentifier: bundleIdentifier, appName: nil)
    }

    private func openApplication(appName: String) -> Bool {
        guard let url = applicationURL(appName: appName) else {
            return false
        }
        return openApplication(at: url, bundleIdentifier: nil, appName: appName)
    }

    private func applicationURL(appName: String) -> URL? {
        let appBundleName = appName.hasSuffix(".app") ? appName : "\(appName).app"
        let homeApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
            .appendingPathComponent(appBundleName)

        let candidates = [
            URL(fileURLWithPath: "/Applications").appendingPathComponent(appBundleName),
            homeApplications,
            URL(fileURLWithPath: "/System/Applications").appendingPathComponent(appBundleName)
        ]

        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func openApplication(at url: URL, bundleIdentifier: String?, appName: String?) -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { runningApp, _ in
            Task { @MainActor in
                if let runningApp {
                    runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                } else {
                    self.activateAfterDelay(bundleIdentifier: bundleIdentifier, appName: appName)
                }
            }
        }
        return true
    }

    private func activateRunningApp(bundleIdentifier: String) -> Bool {
        guard let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            return false
        }
        runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        return true
    }

    private func activateRunningApp(appName: String) -> Bool {
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) else {
            return false
        }
        runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        return true
    }

    private func activateAfterDelay(bundleIdentifier: String?, appName: String?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            if let bundleIdentifier,
               let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                return
            }

            if let appName,
               let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) {
                runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            }
        }
    }
}
