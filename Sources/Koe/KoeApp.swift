import SwiftUI

@main
struct KoeApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // AppKit needs to be initialized before the application starts for this to work
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            HistoryTab()
                .environmentObject(appState)
                .frame(width: 320, height: 450)
        } label: {
            Image(systemName: appState.isRecording ? "mic.fill" : "mic")
                .foregroundColor(appState.isRecording ? KoeTheme.vermilion : .primary)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsTab()
                .frame(width: 450, height: 550)
        }
    }
}
