import SwiftUI
import AppKit

@MainActor
class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsTab()
            .environmentObject(appState)
            .frame(width: 450, height: 550)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 550),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
