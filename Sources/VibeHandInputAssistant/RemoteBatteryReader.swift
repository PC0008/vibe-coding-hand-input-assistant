import Foundation

struct RemoteBatteryState: Equatable {
    let percentage: Int?
    let isDevicePresent: Bool
    let source: String

    var displayText: String {
        if let percentage {
            return "\(percentage)%"
        }
        return isDevicePresent ? "等待上报" : "未检测到"
    }

    var detailText: String {
        if percentage != nil {
            return source
        }
        return isDevicePresent ? "已发现设备，但 macOS 暂未提供电量" : "请先连接 Vibe Coding Remote"
    }
}

enum RemoteBatteryReader {
    private static let deviceName = "Vibe Coding Remote"

    static func read() -> RemoteBatteryState {
        if let ioregOutput = run("/usr/sbin/ioreg", arguments: ["-r", "-l", "-w", "0", "-c", "IOHIDDevice"]) {
            let result = parseIORegistry(ioregOutput)
            if result.isDevicePresent {
                return RemoteBatteryState(
                    percentage: result.percentage,
                    isDevicePresent: true,
                    source: result.percentage == nil ? "IORegistry" : "来自蓝牙 HID"
                )
            }
        }

        if let bluetoothOutput = run("/usr/sbin/system_profiler", arguments: ["SPBluetoothDataType", "-json"]) {
            let result = parseSystemProfiler(bluetoothOutput)
            if result.isDevicePresent {
                return RemoteBatteryState(
                    percentage: result.percentage,
                    isDevicePresent: true,
                    source: result.percentage == nil ? "蓝牙系统信息" : "来自蓝牙系统信息"
                )
            }
        }

        return RemoteBatteryState(percentage: nil, isDevicePresent: false, source: "未找到设备")
    }

    private static func run(_ executable: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private static func parseIORegistry(_ output: String) -> (percentage: Int?, isDevicePresent: Bool) {
        let chunks = output.components(separatedBy: "\n+-o ")
        for chunk in chunks where containsDeviceName(chunk) {
            return (firstBatteryPercentage(in: chunk), true)
        }

        let lines = output.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() where containsDeviceName(line) {
            let lowerBound = max(0, index - 50)
            let upperBound = min(lines.count, index + 80)
            let nearby = lines[lowerBound..<upperBound].joined(separator: "\n")
            return (firstBatteryPercentage(in: nearby), true)
        }

        return (nil, false)
    }

    private static func parseSystemProfiler(_ output: String) -> (percentage: Int?, isDevicePresent: Bool) {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return (nil, false)
        }

        return walkProfilerJSON(json, inDeviceContext: false)
    }

    private static func walkProfilerJSON(_ value: Any, inDeviceContext: Bool) -> (percentage: Int?, isDevicePresent: Bool) {
        if let dictionary = value as? [String: Any] {
            let currentContext = inDeviceContext || dictionary.values.contains { candidate in
                guard let text = candidate as? String else { return false }
                return containsDeviceName(text)
            }

            if currentContext {
                for (key, value) in dictionary where key.localizedCaseInsensitiveContains("battery") {
                    if let percentage = parsePercentage(value) {
                        return (percentage, true)
                    }
                }
            }

            var foundDevice = currentContext
            for child in dictionary.values {
                let result = walkProfilerJSON(child, inDeviceContext: currentContext)
                if let percentage = result.percentage {
                    return (percentage, true)
                }
                foundDevice = foundDevice || result.isDevicePresent
            }
            return (nil, foundDevice)
        }

        if let array = value as? [Any] {
            var foundDevice = false
            for child in array {
                let result = walkProfilerJSON(child, inDeviceContext: inDeviceContext)
                if let percentage = result.percentage {
                    return (percentage, true)
                }
                foundDevice = foundDevice || result.isDevicePresent
            }
            return (nil, foundDevice)
        }

        return (nil, false)
    }

    private static func firstBatteryPercentage(in text: String) -> Int? {
        let patterns = [
            "\"BatteryPercent\"\\s*=\\s*\"?(\\d{1,3})%?\"?",
            "\"Battery Level\"\\s*=\\s*\"?(\\d{1,3})%?\"?",
            "\"BatteryLevel\"\\s*=\\s*\"?(\\d{1,3})%?\"?",
            "\"Battery Current Capacity\"\\s*=\\s*\"?(\\d{1,3})%?\"?",
            "\"device_batteryPercent\"\\s*=\\s*\"?(\\d{1,3})%?\"?"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: text),
                  let value = Int(text[valueRange]) else {
                continue
            }
            return max(0, min(100, value))
        }

        return nil
    }

    private static func parsePercentage(_ value: Any) -> Int? {
        if let intValue = value as? Int {
            return max(0, min(100, intValue))
        }

        if let doubleValue = value as? Double {
            return max(0, min(100, Int(doubleValue.rounded())))
        }

        if let text = value as? String {
            return firstIntegerPercentage(in: text)
        }

        return nil
    }

    private static func firstIntegerPercentage(in text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{1,3})"#) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text),
              let value = Int(text[valueRange]) else {
            return nil
        }
        return max(0, min(100, value))
    }

    private static func containsDeviceName(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains(deviceName)
    }
}
