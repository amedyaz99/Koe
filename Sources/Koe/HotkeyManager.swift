@preconcurrency import ApplicationServices
import AppKit
import Foundation

@MainActor
final class HotkeyManager: ObservableObject {
    @Published private(set) var isAccessibilityTrusted = false

    private let onTrigger: () -> Void
    private let onEscape: (() -> Void)?
    private let onRelease: (() -> Void)?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(onTrigger: @escaping () -> Void, onEscape: (() -> Void)? = nil, onRelease: (() -> Void)? = nil) {
        self.onTrigger = onTrigger
        self.onEscape = onEscape
        self.onRelease = onRelease

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyConfigChanged),
            name: .hotkeyConfigChanged,
            object: nil
        )
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        NotificationCenter.default.removeObserver(self)
    }

    func register() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        isAccessibilityTrusted = trusted

        if trusted {
            createEventTap()
        } else {
            pollUntilTrusted()
        }
    }

    func checkTrustStatus() -> Bool {
        let trusted = AXIsProcessTrusted()
        isAccessibilityTrusted = trusted
        return trusted
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func hotkeyConfigChanged() {
        tearDown()
        createEventTap()
    }

    private func pollUntilTrusted() {
        Task.detached { [weak self] in
            while !AXIsProcessTrusted() {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            await self?.onAccessibilityGranted()
        }
    }

    @MainActor
    private func onAccessibilityGranted() {
        isAccessibilityTrusted = true
        createEventTap()
    }

    private func tearDown() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func createEventTap() {
        guard eventTap == nil else { return }

        let config = HotkeyConfig.current
        let targetKeyCode = config.keyCode
        let targetModifiers = CGEventFlags(rawValue: config.modifierFlags)

        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)
        )
        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

            // macOS disables taps that appear slow — re-enable immediately
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let modifiers = event.flags.intersection([.maskAlternate, .maskCommand, .maskControl, .maskShift])

            if type == .keyUp {
                guard keyCode == manager.targetKeyCode, modifiers == manager.targetModifiers else {
                    return Unmanaged.passUnretained(event)
                }
                manager.onRelease?()
                return nil
            }

            guard type == .keyDown else { return Unmanaged.passUnretained(event) }

            if keyCode == 53 { // Escape
                manager.onEscape?()
                return Unmanaged.passUnretained(event)
            }

            guard keyCode == manager.targetKeyCode, modifiers == manager.targetModifiers else {
                return Unmanaged.passUnretained(event)
            }

            manager.onTrigger()
            return nil
        }

        self.targetKeyCode = targetKeyCode
        self.targetModifiers = targetModifiers

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // Stored so the C callback can read them off self
    private var targetKeyCode: Int64 = HotkeyConfig.default.keyCode
    private var targetModifiers: CGEventFlags = CGEventFlags(rawValue: HotkeyConfig.default.modifierFlags)
}
