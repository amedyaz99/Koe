import AppKit
import SwiftUI

class MainWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Koe"
        window.minSize = NSSize(width: 480, height: 400)
        window.center()
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
        
        window.contentView = NSHostingView(rootView: MainView())
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
