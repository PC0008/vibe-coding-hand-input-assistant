import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore.shared
    private lazy var actions = AppActions(settings: settings)
    private lazy var hotkeyController = HotkeyController(actions: actions)

    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private var hotkeyTapStarted = false
    private var permissionPollTimer: Timer?
    private var wasAccessibilityTrusted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        wasAccessibilityTrusted = AccessibilityManager.isTrusted
        startHotkeys()
        startPermissionMonitor()

        if !AccessibilityManager.isTrusted {
            AccessibilityManager.requestPermissionPrompt()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.openSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionPollTimer?.invalidate()
        hotkeyController.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "V"
        statusItem?.button?.toolTip = "Vibe 手持输入助手"
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let statusTitle = AccessibilityManager.isTrusted
            ? (hotkeyTapStarted ? "状态：已就绪" : "状态：监听未启动")
            : "状态：需要辅助功能权限"
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        let target = settings.selectedTarget
        let targetItem = NSMenuItem(title: "目标软件：\(target.displayName)", action: nil, keyEquivalent: "")
        targetItem.isEnabled = false
        menu.addItem(targetItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "打开设置...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "重新启动按键监听", action: #selector(restartHotkeys), keyEquivalent: "r"))

        if !AccessibilityManager.isTrusted {
            menu.addItem(NSMenuItem(title: "开启辅助功能权限...", action: #selector(requestAccessibility), keyEquivalent: ""))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "测试：打开目标软件", action: #selector(testOpenTarget), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "测试：发送", action: #selector(testSend), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "测试：语音 1 秒", action: #selector(testVoice), keyEquivalent: ""))

        menu.addItem(.separator())
        let firmwareItem = NSMenuItem(title: "刷入遥控器固件（下一阶段）", action: nil, keyEquivalent: "")
        firmwareItem.isEnabled = false
        menu.addItem(firmwareItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        self.statusItem?.menu = menu
    }

    private func startHotkeys() {
        hotkeyController.stop()
        hotkeyTapStarted = hotkeyController.start()
        rebuildMenu()
    }

    private func startPermissionMonitor() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissionAndHotkeys()
            }
        }
    }

    private func refreshPermissionAndHotkeys() {
        let trusted = AccessibilityManager.isTrusted
        if trusted != wasAccessibilityTrusted {
            wasAccessibilityTrusted = trusted
            if trusted {
                startHotkeys()
            } else {
                hotkeyController.stop()
                hotkeyTapStarted = false
                rebuildMenu()
            }
            return
        }

        if trusted && !hotkeyTapStarted {
            startHotkeys()
        }
    }

    @objc private func restartHotkeys() {
        hotkeyController.stop()
        startHotkeys()
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settings: settings) { [weak self] in
                self?.rebuildMenu()
            }
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func requestAccessibility() {
        AccessibilityManager.requestPermissionPrompt()
        AccessibilityManager.openAccessibilitySettings()
        rebuildMenu()
    }

    @objc private func testOpenTarget() {
        actions.openTargetApp()
    }

    @objc private func testSend() {
        actions.sendMessage()
    }

    @objc private func testVoice() {
        actions.voiceDown()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [actions] in
            actions.voiceUp()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
