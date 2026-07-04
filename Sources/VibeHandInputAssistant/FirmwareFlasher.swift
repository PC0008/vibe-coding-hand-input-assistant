import Foundation

@MainActor
final class FirmwareFlasher {
    private var process: Process?

    var isRunning: Bool {
        process?.isRunning == true
    }

    static func availableSerialPorts() -> [String] {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: "/dev") else {
            return []
        }

        let prefixes = [
            "cu.usbmodem",
            "cu.usbserial",
            "cu.wchusbserial",
            "cu.SLAB_USBtoUART"
        ]

        return entries
            .filter { entry in prefixes.contains { entry.hasPrefix($0) } }
            .sorted { lhs, rhs in
                scoreSerialPort(lhs) > scoreSerialPort(rhs)
            }
            .map { "/dev/\($0)" }
    }

    static func pythonPath() -> String? {
        let candidates = [
            "/usr/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func flash(
        port: String,
        onLog: @escaping @MainActor (String) -> Void,
        onComplete: @escaping @MainActor (Bool) -> Void
    ) {
        guard !isRunning else {
            onLog("已有烧录任务正在运行。")
            onComplete(false)
            return
        }

        guard let pythonPath = Self.pythonPath() else {
            onLog("未找到 python3。请先安装 Apple Command Line Tools 后再试。")
            onComplete(false)
            return
        }

        guard let resourcesURL = Bundle.main.resourceURL else {
            onLog("未找到 App 资源目录。")
            onComplete(false)
            return
        }

        let firmwareURL = resourcesURL.appendingPathComponent("Firmware", isDirectory: true)
        let flashToolsURL = resourcesURL.appendingPathComponent("FlashTools", isDirectory: true)
        let esptoolURL = flashToolsURL.appendingPathComponent("esptoolpy/esptool.py")
        let pythonLibsURL = flashToolsURL.appendingPathComponent("python-libs", isDirectory: true)

        let requiredFiles = [
            esptoolURL.path,
            firmwareURL.appendingPathComponent("bootloader.bin").path,
            firmwareURL.appendingPathComponent("partitions.bin").path,
            firmwareURL.appendingPathComponent("boot_app0.bin").path,
            firmwareURL.appendingPathComponent("firmware.bin").path
        ]

        for file in requiredFiles where !FileManager.default.fileExists(atPath: file) {
            onLog("缺少烧录资源：\(file)")
            onComplete(false)
            return
        }

        let process = Process()
        let pipe = Pipe()
        self.process = process

        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.currentDirectoryURL = firmwareURL
        process.arguments = [
            esptoolURL.path,
            "--chip", "esp32s3",
            "--port", port,
            "--baud", "921600",
            "--before", "default_reset",
            "--after", "hard_reset",
            "write_flash",
            "-z",
            "--flash_mode", "dio",
            "--flash_freq", "80m",
            "--flash_size", "8MB",
            "0x0", "bootloader.bin",
            "0x8000", "partitions.bin",
            "0xe000", "boot_app0.bin",
            "0x10000", "firmware.bin"
        ]
        process.environment = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin",
            "PYTHONPATH": [
                flashToolsURL.appendingPathComponent("esptoolpy").path,
                pythonLibsURL.path
            ].joined(separator: ":")
        ]
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else {
                return
            }
            Task { @MainActor in
                onLog(text)
            }
        }

        process.terminationHandler = { [weak self] finishedProcess in
            pipe.fileHandleForReading.readabilityHandler = nil
            let success = finishedProcess.terminationStatus == 0
            Task { @MainActor in
                self?.process = nil
                onLog(success ? "\n烧录完成。请拔掉 USB 线，打开蓝牙连接 Vibe Coding Remote。\n" : "\n烧录失败，请检查 USB 线和设备状态。\n")
                onComplete(success)
            }
        }

        do {
            onLog("开始烧录：\(port)\n")
            try process.run()
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            self.process = nil
            onLog("启动烧录失败：\(error.localizedDescription)")
            onComplete(false)
        }
    }

    func cancel() {
        process?.terminate()
        process = nil
    }

    private static func scoreSerialPort(_ entry: String) -> Int {
        if entry.hasPrefix("cu.usbmodem") { return 4 }
        if entry.hasPrefix("cu.usbserial") { return 3 }
        if entry.hasPrefix("cu.wchusbserial") { return 2 }
        if entry.hasPrefix("cu.SLAB_USBtoUART") { return 1 }
        return 0
    }
}
