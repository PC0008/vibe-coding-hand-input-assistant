import ApplicationServices
import Foundation

final class HotkeyController {
    private let actions: AppActions
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var f14IsDown = false

    init(actions: AppActions) {
        self.actions = actions
    }

    func start() -> Bool {
        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)
        )

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }

            let controller = Unmanaged<HotkeyController>.fromOpaque(refcon).takeUnretainedValue()
            return controller.handle(proxy: proxy, type: type, event: event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            return false
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: eventTap, enable: true)
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isDown = type == .keyDown
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        switch keyCode {
        case KeyCodes.f13:
            if isDown && !isRepeat {
                DispatchQueue.main.async { [actions] in actions.openTargetApp() }
            }
            return Unmanaged.passUnretained(event)

        case KeyCodes.f14:
            if isDown && !isRepeat && !f14IsDown {
                f14IsDown = true
                DispatchQueue.main.async { [actions] in actions.voiceDown() }
            } else if !isDown && f14IsDown {
                f14IsDown = false
                DispatchQueue.main.async { [actions] in actions.voiceUp() }
            }
            return Unmanaged.passUnretained(event)

        case KeyCodes.f15:
            if isDown && !isRepeat {
                DispatchQueue.main.async { [actions] in actions.sendMessage() }
            }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
