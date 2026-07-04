import Foundation

struct TargetAppPreset: Equatable {
    let id: String
    let displayName: String
    let appName: String
    let bundleIdentifier: String
    let defaultSendMode: SendMode
}

enum SendMode: String, CaseIterable {
    case returnKey
    case commandReturn

    var displayName: String {
        switch self {
        case .returnKey:
            return "Return"
        case .commandReturn:
            return "Command + Return"
        }
    }
}

enum VoiceMode: String, CaseIterable {
    case fn
    case shortcut

    var displayName: String {
        switch self {
        case .fn:
            return "按住 Fn"
        case .shortcut:
            return "自定义快捷键"
        }
    }
}

@MainActor
final class SettingsStore {
    static let shared = SettingsStore()

    static let targetPresets: [TargetAppPreset] = [
        TargetAppPreset(
            id: "codex",
            displayName: "Codex",
            appName: "Codex",
            bundleIdentifier: "com.openai.codex",
            defaultSendMode: .returnKey
        ),
        TargetAppPreset(
            id: "claude",
            displayName: "Claude",
            appName: "Claude",
            bundleIdentifier: "com.anthropic.claudefordesktop",
            defaultSendMode: .returnKey
        ),
        TargetAppPreset(
            id: "claude-code",
            displayName: "Claude Code",
            appName: "Claude Code",
            bundleIdentifier: "",
            defaultSendMode: .returnKey
        ),
        TargetAppPreset(
            id: "kimi",
            displayName: "Kimi",
            appName: "Kimi",
            bundleIdentifier: "",
            defaultSendMode: .returnKey
        ),
        TargetAppPreset(
            id: "custom",
            displayName: "自定义 App",
            appName: "",
            bundleIdentifier: "",
            defaultSendMode: .returnKey
        )
    ]

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let targetPresetID = "targetPresetID"
        static let customAppName = "customAppName"
        static let customBundleIdentifier = "customBundleIdentifier"
        static let sendMode = "sendMode"
        static let voiceMode = "voiceMode"
        static let customVoiceShortcut = "customVoiceShortcut"
    }

    private init() {
        if defaults.string(forKey: Keys.targetPresetID) == nil {
            defaults.set("codex", forKey: Keys.targetPresetID)
        }
        if defaults.string(forKey: Keys.sendMode) == nil {
            defaults.set(SendMode.returnKey.rawValue, forKey: Keys.sendMode)
        }
        if defaults.string(forKey: Keys.voiceMode) == nil {
            defaults.set(VoiceMode.fn.rawValue, forKey: Keys.voiceMode)
        }
    }

    var targetPresetID: String {
        get { defaults.string(forKey: Keys.targetPresetID) ?? "codex" }
        set { defaults.set(newValue, forKey: Keys.targetPresetID) }
    }

    var customAppName: String {
        get { defaults.string(forKey: Keys.customAppName) ?? "" }
        set { defaults.set(newValue, forKey: Keys.customAppName) }
    }

    var customBundleIdentifier: String {
        get { defaults.string(forKey: Keys.customBundleIdentifier) ?? "" }
        set { defaults.set(newValue, forKey: Keys.customBundleIdentifier) }
    }

    var sendMode: SendMode {
        get { SendMode(rawValue: defaults.string(forKey: Keys.sendMode) ?? "") ?? .returnKey }
        set { defaults.set(newValue.rawValue, forKey: Keys.sendMode) }
    }

    var voiceMode: VoiceMode {
        get { VoiceMode(rawValue: defaults.string(forKey: Keys.voiceMode) ?? "") ?? .fn }
        set { defaults.set(newValue.rawValue, forKey: Keys.voiceMode) }
    }

    var customVoiceShortcut: KeyboardShortcut? {
        get {
            guard let rawValue = defaults.string(forKey: Keys.customVoiceShortcut) else {
                return nil
            }
            return KeyboardShortcut(storageValue: rawValue)
        }
        set {
            defaults.set(newValue?.storageValue, forKey: Keys.customVoiceShortcut)
        }
    }

    var selectedTarget: TargetAppPreset {
        guard targetPresetID == "custom" else {
            return SettingsStore.targetPresets.first { $0.id == targetPresetID } ?? SettingsStore.targetPresets[0]
        }

        return TargetAppPreset(
            id: "custom",
            displayName: customAppName.isEmpty ? "自定义 App" : customAppName,
            appName: customAppName,
            bundleIdentifier: customBundleIdentifier,
            defaultSendMode: sendMode
        )
    }
}
