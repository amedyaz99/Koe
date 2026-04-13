@preconcurrency import ApplicationServices
import Foundation

final class HotkeyManager {
    private let onTrigger: () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    deinit {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
    }

    func register() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            createEventTap()
        } else {
            // Poll until the user grants access, then create the tap
            pollUntilTrusted()
        }
    }

    private func pollUntilTrusted() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            while !AXIsProcessTrusted() {
                Thread.sleep(forTimeInterval: 1.0)
            }
            DispatchQueue.main.async { [weak self] in
                self?.createEventTap()
            }
        }
    }

    private func createEventTap() {
        guard eventTap == nil else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let modifiers = event.flags.intersection([.maskAlternate, .maskCommand, .maskControl, .maskShift])

            guard keyCode == 40, modifiers == .maskAlternate else {
                return Unmanaged.passUnretained(event)
            }

            manager.onTrigger()
            return nil
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}
