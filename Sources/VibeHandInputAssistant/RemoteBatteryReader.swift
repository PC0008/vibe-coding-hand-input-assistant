import CoreBluetooth
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
        if isDevicePresent {
            if ["CoreBluetooth", "IORegistry", "蓝牙系统信息"].contains(source) {
                return "已发现设备，正在等待电量服务"
            }
            return source
        }
        return source == "未找到设备" ? "请先连接 Vibe Coding Remote" : source
    }
}

enum RemoteBatteryReader {
    private static let deviceName = "Vibe Coding Remote"

    static func read() -> RemoteBatteryState {
        var detectedDevice = false

        if let ioregOutput = run("/usr/sbin/ioreg", arguments: ["-r", "-l", "-w", "0", "-c", "IOHIDDevice"], timeout: 2.0) {
            let result = parseIORegistry(ioregOutput)
            if let percentage = result.percentage {
                return RemoteBatteryState(
                    percentage: percentage,
                    isDevicePresent: true,
                    source: "来自蓝牙 HID"
                )
            }
            detectedDevice = detectedDevice || result.isDevicePresent
        }

        if let bluetoothOutput = run("/usr/sbin/system_profiler", arguments: ["SPBluetoothDataType", "-json"], timeout: 2.0) {
            let result = parseSystemProfiler(bluetoothOutput)
            if let percentage = result.percentage {
                return RemoteBatteryState(
                    percentage: percentage,
                    isDevicePresent: true,
                    source: "来自蓝牙系统信息"
                )
            }
            detectedDevice = detectedDevice || result.isDevicePresent
        }

        let bluetoothResult = BluetoothBatteryReader.readBattery(deviceName: deviceName, timeout: detectedDevice ? 3.0 : 2.0)
        if let percentage = bluetoothResult.percentage {
            return RemoteBatteryState(
                percentage: percentage,
                isDevicePresent: true,
                source: "来自蓝牙电池服务"
            )
        }

        if bluetoothResult.isDevicePresent || detectedDevice {
            return RemoteBatteryState(
                percentage: nil,
                isDevicePresent: true,
                source: bluetoothResult.source ?? "CoreBluetooth"
            )
        }

        return RemoteBatteryState(percentage: nil, isDevicePresent: false, source: "未找到设备")
    }

    private static func run(_ executable: String, arguments: [String], timeout: TimeInterval) -> String? {
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

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.03)
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
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

private final class BluetoothBatteryReader: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, @unchecked Sendable {
    private let deviceName: String
    private let timeout: TimeInterval
    private let queue = DispatchQueue(label: "com.zhiduoxing.vibe-coding-hand-input-assistant.bluetooth-battery")
    private let semaphore = DispatchSemaphore(value: 0)
    private let vibeBatteryServiceUUID = CBUUID(string: "7A8B0001-6D3B-4C1A-8D4F-9E2B5C7A1000")
    private let vibeBatteryLevelUUID = CBUUID(string: "7A8B0002-6D3B-4C1A-8D4F-9E2B5C7A1000")
    private let batteryServiceUUID = CBUUID(string: "180F")
    private let batteryLevelUUID = CBUUID(string: "2A19")
    private let hidServiceUUID = CBUUID(string: "1812")

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var result: (percentage: Int?, isDevicePresent: Bool, source: String?) = (nil, false, nil)
    private var isFinished = false

    static func readBattery(deviceName: String, timeout: TimeInterval) -> (percentage: Int?, isDevicePresent: Bool, source: String?) {
        let reader = BluetoothBatteryReader(deviceName: deviceName, timeout: timeout)
        return reader.read()
    }

    private init(deviceName: String, timeout: TimeInterval) {
        self.deviceName = deviceName
        self.timeout = timeout
        super.init()
    }

    private func read() -> (percentage: Int?, isDevicePresent: Bool, source: String?) {
        queue.async {
            self.central = CBCentralManager(delegate: self, queue: self.queue)
        }

        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            queue.sync {
                self.central?.stopScan()
                if let peripheral = self.peripheral {
                    self.central?.cancelPeripheralConnection(peripheral)
                }
                if !self.isFinished {
                    self.result = (
                        percentage: nil,
                        isDevicePresent: self.result.isDevicePresent,
                        source: self.result.isDevicePresent ? "读取电量超时" : "未发现蓝牙电池服务"
                    )
                    self.isFinished = true
                }
            }
        }

        return result
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectToKnownPeripheral(using: central)
        case .unauthorized:
            finish(percentage: nil, isDevicePresent: false, source: "需要允许蓝牙权限")
        case .poweredOff:
            finish(percentage: nil, isDevicePresent: false, source: "蓝牙未开启")
        default:
            break
        }
    }

    private func connectToKnownPeripheral(using central: CBCentralManager) {
        let vibeCandidates = central.retrieveConnectedPeripherals(withServices: [vibeBatteryServiceUUID])
        if let match = firstMatchingPeripheral(vibeCandidates) ?? vibeCandidates.first {
            connect(match, using: central)
            return
        }

        let candidates = central.retrieveConnectedPeripherals(withServices: [batteryServiceUUID])
            + central.retrieveConnectedPeripherals(withServices: [hidServiceUUID])

        if let match = firstMatchingPeripheral(candidates) {
            connect(match, using: central)
            return
        }

        central.scanForPeripherals(
            withServices: [vibeBatteryServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func firstMatchingPeripheral(_ peripherals: [CBPeripheral]) -> CBPeripheral? {
        var seen = Set<UUID>()
        for peripheral in peripherals where seen.insert(peripheral.identifier).inserted {
            if peripheralMatches(peripheral) {
                return peripheral
            }
        }
        return nil
    }

    private func peripheralMatches(_ peripheral: CBPeripheral) -> Bool {
        guard let name = peripheral.name else {
            return false
        }
        return name.localizedCaseInsensitiveContains(deviceName)
    }

    private func connect(_ peripheral: CBPeripheral, using central: CBCentralManager) {
        result.isDevicePresent = true
        self.peripheral = peripheral
        peripheral.delegate = self
        central.stopScan()
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let matchesAdvertisement = advertisedName?.localizedCaseInsensitiveContains(deviceName) ?? false
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let hasVibeBatteryService = serviceUUIDs.contains(vibeBatteryServiceUUID)
        if hasVibeBatteryService || matchesAdvertisement || peripheralMatches(peripheral) {
            connect(peripheral, using: central)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([vibeBatteryServiceUUID, batteryServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        finish(percentage: nil, isDevicePresent: true, source: "蓝牙连接失败")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let services = peripheral.services else {
            finish(percentage: nil, isDevicePresent: true, source: "未找到电池服务")
            return
        }

        if let vibeService = services.first(where: { $0.uuid == vibeBatteryServiceUUID }) {
            peripheral.discoverCharacteristics([vibeBatteryLevelUUID], for: vibeService)
            return
        }

        guard let service = services.first(where: { $0.uuid == batteryServiceUUID }) else {
            finish(percentage: nil, isDevicePresent: true, source: "未找到电池服务")
            return
        }
        peripheral.discoverCharacteristics([batteryLevelUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let targetUUID = service.uuid == vibeBatteryServiceUUID ? vibeBatteryLevelUUID : batteryLevelUUID
        guard error == nil,
              let characteristic = service.characteristics?.first(where: { $0.uuid == targetUUID }) else {
            finish(percentage: nil, isDevicePresent: true, source: "未找到电量字段")
            return
        }
        peripheral.readValue(for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              (characteristic.uuid == vibeBatteryLevelUUID || characteristic.uuid == batteryLevelUUID),
              let byte = characteristic.value?.first else {
            finish(percentage: nil, isDevicePresent: true, source: "读取电量失败")
            return
        }
        let source = characteristic.uuid == vibeBatteryLevelUUID ? "来自 Vibe 电量服务" : "来自蓝牙电池服务"
        finish(percentage: Int(min(byte, 100)), isDevicePresent: true, source: source)
    }

    private func finish(percentage: Int?, isDevicePresent: Bool, source: String?) {
        guard !isFinished else {
            return
        }
        isFinished = true
        result = (percentage, isDevicePresent, source)
        central?.stopScan()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        semaphore.signal()
    }
}
