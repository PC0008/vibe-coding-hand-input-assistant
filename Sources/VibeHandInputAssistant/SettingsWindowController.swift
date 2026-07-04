import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let settings: SettingsStore
    private let onSave: () -> Void

    private let targetPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let customAppNameField = NSTextField(frame: .zero)
    private let customBundleIDField = NSTextField(frame: .zero)
    private let sendModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let voiceModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let permissionLabel = NSTextField(labelWithString: "")
    private var permissionRefreshTimer: Timer?

    init(settings: SettingsStore, onSave: @escaping () -> Void) {
        self.settings = settings
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vibe 手持输入助手"
        window.center()

        super.init(window: window)
        window.delegate = self
        window.contentView = buildContentView()
        loadValues()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        refreshPermissionStatus()
        startPermissionRefreshTimer()
    }

    func windowWillClose(_ notification: Notification) {
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = nil
    }

    private func buildContentView() -> NSView {
        let container = NSView()

        let title = NSTextField(labelWithString: "Vibe 手持输入助手")
        title.font = .systemFont(ofSize: 22, weight: .semibold)

        let subtitle = NSTextField(labelWithString: "选择目标软件和发送方式，然后用 StickS3 控制你的输入流程。")
        subtitle.textColor = .secondaryLabelColor
        subtitle.font = .systemFont(ofSize: 13)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(row(label: "辅助功能", control: permissionRow()))
        stack.addArrangedSubview(row(label: "目标软件", control: targetPopup))
        stack.addArrangedSubview(row(label: "自定义名称", control: customAppNameField))
        stack.addArrangedSubview(row(label: "Bundle ID", control: customBundleIDField))
        stack.addArrangedSubview(row(label: "发送方式", control: sendModePopup))
        stack.addArrangedSubview(row(label: "语音输入", control: voiceModePopup))
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(helpText())
        stack.addArrangedSubview(buttonRow())

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24)
        ])

        configureControls()
        return container
    }

    private func configureControls() {
        targetPopup.removeAllItems()
        for preset in SettingsStore.targetPresets {
            targetPopup.addItem(withTitle: preset.displayName)
            targetPopup.lastItem?.representedObject = preset.id
        }
        targetPopup.target = self
        targetPopup.action = #selector(targetChanged)

        sendModePopup.removeAllItems()
        for mode in SendMode.allCases {
            sendModePopup.addItem(withTitle: mode.displayName)
            sendModePopup.lastItem?.representedObject = mode.rawValue
        }

        voiceModePopup.removeAllItems()
        for mode in VoiceMode.allCases {
            voiceModePopup.addItem(withTitle: mode.displayName)
            voiceModePopup.lastItem?.representedObject = mode.rawValue
        }

        customAppNameField.placeholderString = "例如 Kimi"
        customBundleIDField.placeholderString = "可选，例如 com.example.app"
    }

    private func loadValues() {
        selectPopup(targetPopup, representedObject: settings.targetPresetID)
        customAppNameField.stringValue = settings.customAppName
        customBundleIDField.stringValue = settings.customBundleIdentifier
        selectPopup(sendModePopup, representedObject: settings.sendMode.rawValue)
        selectPopup(voiceModePopup, representedObject: settings.voiceMode.rawValue)
        updateCustomFields()
        refreshPermissionStatus()
    }

    private func saveValues() {
        settings.targetPresetID = targetPopup.selectedItem?.representedObject as? String ?? "codex"
        settings.customAppName = customAppNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.customBundleIdentifier = customBundleIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let rawSendMode = sendModePopup.selectedItem?.representedObject as? String,
           let sendMode = SendMode(rawValue: rawSendMode) {
            settings.sendMode = sendMode
        }

        if let rawVoiceMode = voiceModePopup.selectedItem?.representedObject as? String,
           let voiceMode = VoiceMode(rawValue: rawVoiceMode) {
            settings.voiceMode = voiceMode
        }

        onSave()
    }

    private func selectPopup(_ popup: NSPopUpButton, representedObject: String) {
        for item in popup.itemArray where item.representedObject as? String == representedObject {
            popup.select(item)
            return
        }
    }

    @objc private func targetChanged() {
        updateCustomFields()
    }

    private func updateCustomFields() {
        let isCustom = (targetPopup.selectedItem?.representedObject as? String) == "custom"
        customAppNameField.isEnabled = isCustom
        customBundleIDField.isEnabled = isCustom
    }

    func refreshPermissionStatus() {
        permissionLabel.stringValue = AccessibilityManager.isTrusted ? "已开启" : "未开启"
        permissionLabel.textColor = AccessibilityManager.isTrusted ? .systemGreen : .systemRed
    }

    private func startPermissionRefreshTimer() {
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissionStatus()
            }
        }
    }

    @objc private func openPermissionSettings() {
        AccessibilityManager.requestPermissionPrompt()
        AccessibilityManager.openAccessibilitySettings()
        refreshPermissionStatus()
    }

    @objc private func saveAndClose() {
        saveValues()
        window?.close()
    }

    @objc private func testTarget() {
        saveValues()
        AppActions(settings: settings).openTargetApp()
    }

    @objc private func testSend() {
        saveValues()
        AppActions(settings: settings).sendMessage()
    }

    @objc private func testVoice() {
        saveValues()
        let actions = AppActions(settings: settings)
        actions.voiceDown()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            actions.voiceUp()
        }
    }

    private func permissionRow() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10

        let button = NSButton(title: "打开权限设置", target: self, action: #selector(openPermissionSettings))
        stack.addArrangedSubview(permissionLabel)
        stack.addArrangedSubview(button)
        return stack
    }

    private func buttonRow() -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10

        let testButton = NSButton(title: "测试目标软件", target: self, action: #selector(testTarget))
        let sendButton = NSButton(title: "测试发送", target: self, action: #selector(testSend))
        let voiceButton = NSButton(title: "测试语音", target: self, action: #selector(testVoice))
        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveAndClose))
        saveButton.keyEquivalent = "\r"

        stack.addArrangedSubview(testButton)
        stack.addArrangedSubview(sendButton)
        stack.addArrangedSubview(voiceButton)
        stack.addArrangedSubview(saveButton)
        return stack
    }

    private func row(label: String, control: NSView) -> NSView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 13, weight: .medium)
        labelView.widthAnchor.constraint(equalToConstant: 96).isActive = true

        control.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true

        let stack = NSStackView(views: [labelView, control])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        return stack
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: 480).isActive = true
        return box
    }

    private func helpText() -> NSView {
        let text = NSTextField(labelWithString: "StickS3 按键映射：右侧按钮打开目标软件，蓝色按钮按住语音，蓝色按钮双击发送。")
        text.textColor = .secondaryLabelColor
        text.font = .systemFont(ofSize: 12)
        text.maximumNumberOfLines = 2
        return text
    }
}
