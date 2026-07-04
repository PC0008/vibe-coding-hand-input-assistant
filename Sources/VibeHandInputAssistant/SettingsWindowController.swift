import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let settings: SettingsStore
    private let onSave: () -> Void
    private let firmwareFlasher = FirmwareFlasher()

    private let targetPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let customAppNameField = NSTextField(frame: .zero)
    private let customBundleIDField = NSTextField(frame: .zero)
    private let sendModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let voiceModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let shortcutLabel = NSTextField(labelWithString: "未设置")
    private let shortcutButton = NSButton(title: "录制快捷键", target: nil, action: nil)
    private let permissionLabel = NSTextField(labelWithString: "")
    private let portPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let flashStatusLabel = NSTextField(labelWithString: "未检测")
    private let flashLogTextView = NSTextView(frame: .zero)
    private let flashButton = NSButton(title: "一键烧录", target: nil, action: nil)
    private let refreshPortsButton = NSButton(title: "刷新设备", target: nil, action: nil)

    private var permissionRefreshTimer: Timer?
    private var shortcutMonitor: Any?
    private var recordedShortcut: KeyboardShortcut?

    init(settings: SettingsStore, onSave: @escaping () -> Void) {
        self.settings = settings
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vibe Coding手持输入助手"
        window.minSize = NSSize(width: 620, height: 620)
        window.center()

        super.init(window: window)
        window.delegate = self
        window.contentView = buildContentView()
        loadValues()
        refreshSerialPorts()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        refreshPermissionStatus()
        refreshSerialPorts()
        startPermissionRefreshTimer()
    }

    func windowWillClose(_ notification: Notification) {
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = nil
        stopShortcutRecording()
    }

    private func buildContentView() -> NSView {
        let container = NSView()

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(headerView())
        stack.addArrangedSubview(separator(width: 600))
        stack.addArrangedSubview(sectionTitle("基础设置"))
        stack.addArrangedSubview(row(label: "辅助功能", control: permissionRow()))
        stack.addArrangedSubview(row(label: "目标软件", control: targetPopup))
        stack.addArrangedSubview(row(label: "自定义名称", control: customAppNameField))
        stack.addArrangedSubview(row(label: "Bundle ID", control: customBundleIDField))
        stack.addArrangedSubview(row(label: "发送方式", control: sendModePopup))
        stack.addArrangedSubview(row(label: "语音输入", control: voiceModeRow()))
        stack.addArrangedSubview(separator(width: 600))
        stack.addArrangedSubview(helpText())
        stack.addArrangedSubview(buttonRow())
        stack.addArrangedSubview(separator(width: 600))
        stack.addArrangedSubview(sectionTitle("设备烧录"))
        stack.addArrangedSubview(flashIntroText())
        stack.addArrangedSubview(row(label: "连接设备", control: flashDeviceRow()))
        stack.addArrangedSubview(flashLogView())
        stack.addArrangedSubview(separator(width: 600))
        stack.addArrangedSubview(authorText())

        documentView.addSubview(stack)
        scrollView.documentView = documentView
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(lessThanOrEqualTo: documentView.widthAnchor, constant: -64)
        ])

        configureControls()
        return container
    }

    private func headerView() -> NSView {
        let logoView = NSImageView()
        if let logoURL = Bundle.main.url(forResource: "Logo", withExtension: "png") {
            logoView.image = NSImage(contentsOf: logoURL)
        } else if let logo = NSImage(named: "Logo") {
            logoView.image = logo
        }
        logoView.imageScaling = .scaleProportionallyUpOrDown
        logoView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logoView.widthAnchor.constraint(equalToConstant: 72),
            logoView.heightAnchor.constraint(equalToConstant: 72)
        ])

        let title = NSTextField(labelWithString: "Vibe Coding手持输入助手")
        title.font = .systemFont(ofSize: 24, weight: .semibold)

        let subtitle = NSTextField(labelWithString: "配合 StickS3 手持硬件，打开 AI 编程工具、按住语音输入、双击发送。")
        subtitle.textColor = .secondaryLabelColor
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.maximumNumberOfLines = 2

        let textStack = NSStackView(views: [title, subtitle])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6

        let stack = NSStackView(views: [logoView, textStack])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 16
        return stack
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
        voiceModePopup.target = self
        voiceModePopup.action = #selector(voiceModeChanged)

        shortcutButton.target = self
        shortcutButton.action = #selector(startShortcutRecording)

        customAppNameField.placeholderString = "例如 Kimi"
        customBundleIDField.placeholderString = "可选，例如 com.example.app"

        refreshPortsButton.target = self
        refreshPortsButton.action = #selector(refreshSerialPorts)
        flashButton.target = self
        flashButton.action = #selector(startFlash)

        flashLogTextView.isEditable = false
        flashLogTextView.isSelectable = true
        flashLogTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        flashLogTextView.textColor = .secondaryLabelColor
    }

    private func loadValues() {
        selectPopup(targetPopup, representedObject: settings.targetPresetID)
        customAppNameField.stringValue = settings.customAppName
        customBundleIDField.stringValue = settings.customBundleIdentifier
        selectPopup(sendModePopup, representedObject: settings.sendMode.rawValue)
        selectPopup(voiceModePopup, representedObject: settings.voiceMode.rawValue)
        recordedShortcut = settings.customVoiceShortcut
        updateShortcutLabel()
        updateCustomFields()
        updateVoiceControls()
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

        settings.customVoiceShortcut = recordedShortcut
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

    @objc private func voiceModeChanged() {
        updateVoiceControls()
    }

    private func updateCustomFields() {
        let isCustom = (targetPopup.selectedItem?.representedObject as? String) == "custom"
        customAppNameField.isEnabled = isCustom
        customBundleIDField.isEnabled = isCustom
    }

    private func updateVoiceControls() {
        let isShortcut = (voiceModePopup.selectedItem?.representedObject as? String) == VoiceMode.shortcut.rawValue
        shortcutButton.isEnabled = isShortcut
        shortcutLabel.textColor = isShortcut ? .labelColor : .secondaryLabelColor
    }

    private func updateShortcutLabel() {
        shortcutLabel.stringValue = recordedShortcut?.displayName ?? "未设置"
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

    @objc private func startShortcutRecording() {
        stopShortcutRecording()
        shortcutLabel.stringValue = "请按下要录制的组合键..."
        shortcutLabel.textColor = .systemBlue
        window?.makeFirstResponder(nil)
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            Task { @MainActor in
                self.captureShortcut(from: event)
            }
            return nil
        }
    }

    private func captureShortcut(from event: NSEvent) {
        guard let shortcut = KeyboardShortcut.from(event: event) else {
            shortcutLabel.stringValue = "请按一个非修饰键，例如 Space 或 D"
            return
        }
        recordedShortcut = shortcut
        updateShortcutLabel()
        stopShortcutRecording()
    }

    private func stopShortcutRecording() {
        if let shortcutMonitor {
            NSEvent.removeMonitor(shortcutMonitor)
        }
        shortcutMonitor = nil
    }

    @objc private func refreshSerialPorts() {
        let previousSelection = portPopup.selectedItem?.title
        let ports = FirmwareFlasher.availableSerialPorts()
        portPopup.removeAllItems()
        if ports.isEmpty {
            portPopup.addItem(withTitle: "未检测到设备")
            portPopup.isEnabled = false
            flashButton.isEnabled = false
            flashStatusLabel.stringValue = "请用 USB 线连接 StickS3"
            flashStatusLabel.textColor = .systemOrange
            return
        }

        for port in ports {
            portPopup.addItem(withTitle: port)
        }
        if let previousSelection,
           ports.contains(previousSelection) {
            portPopup.selectItem(withTitle: previousSelection)
        }
        portPopup.isEnabled = true
        flashButton.isEnabled = true
        flashStatusLabel.stringValue = "已检测到 \(ports.count) 个串口"
        flashStatusLabel.textColor = .systemGreen
    }

    @objc private func startFlash() {
        guard portPopup.isEnabled, let port = portPopup.selectedItem?.title, port.hasPrefix("/dev/") else {
            appendFlashLog("未检测到可烧录设备。请插入 StickS3 后点“刷新设备”。\n")
            return
        }

        flashButton.isEnabled = false
        refreshPortsButton.isEnabled = false
        portPopup.isEnabled = false
        flashStatusLabel.stringValue = "正在烧录..."
        flashStatusLabel.textColor = .systemBlue
        flashLogTextView.string = ""

        firmwareFlasher.flash(port: port) { [weak self] text in
            self?.appendFlashLog(text)
        } onComplete: { [weak self] success in
            self?.refreshPortsButton.isEnabled = true
            self?.refreshSerialPorts()
            self?.flashStatusLabel.stringValue = success ? "烧录完成" : "烧录失败"
            self?.flashStatusLabel.textColor = success ? .systemGreen : .systemRed
        }
    }

    private func appendFlashLog(_ text: String) {
        flashLogTextView.textStorage?.append(NSAttributedString(string: text))
        flashLogTextView.scrollToEndOfDocument(nil)
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

    private func voiceModeRow() -> NSView {
        let stack = NSStackView(views: [voiceModePopup, shortcutLabel, shortcutButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        shortcutLabel.widthAnchor.constraint(equalToConstant: 170).isActive = true
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

    private func flashDeviceRow() -> NSView {
        let stack = NSStackView(views: [portPopup, refreshPortsButton, flashButton, flashStatusLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        portPopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
        flashStatusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        return stack
    }

    private func flashLogView() -> NSView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = flashLogTextView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalToConstant: 600),
            scrollView.heightAnchor.constraint(equalToConstant: 150)
        ])
        return scrollView
    }

    private func row(label: String, control: NSView) -> NSView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 13, weight: .medium)
        labelView.widthAnchor.constraint(equalToConstant: 96).isActive = true

        control.widthAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true

        let stack = NSStackView(views: [labelView, control])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        return stack
    }

    private func sectionTitle(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        return label
    }

    private func separator(width: CGFloat) -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: width).isActive = true
        return box
    }

    private func helpText() -> NSView {
        let text = NSTextField(labelWithString: "StickS3 按键映射：右侧按钮打开目标软件，蓝色按钮按住语音，蓝色按钮双击发送。")
        text.textColor = .secondaryLabelColor
        text.font = .systemFont(ofSize: 12)
        text.maximumNumberOfLines = 2
        return text
    }

    private func flashIntroText() -> NSView {
        let text = NSTextField(labelWithString: "插上 USB 线后点“刷新设备”，检测到串口后点“一键烧录”。烧录完成后到蓝牙里连接 Vibe Coding Remote。")
        text.textColor = .secondaryLabelColor
        text.font = .systemFont(ofSize: 12)
        text.maximumNumberOfLines = 3
        return text
    }

    private func authorText() -> NSView {
        let text = NSTextField(labelWithString: "作者：智多星｜个人微信：369076317")
        text.textColor = .secondaryLabelColor
        text.font = .systemFont(ofSize: 12)
        return text
    }
}
