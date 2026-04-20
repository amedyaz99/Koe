import SwiftUI

@main
struct KoeApp: App {
    @StateObject private var appState = AppState()
    @State private var settingsController: SettingsWindowController?

    init() {
        // AppKit needs to be initialized before the application starts for this to work
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 0) {
                HistoryTab()
                    .environmentObject(appState)
                    .frame(width: 320, height: 450)

                Divider()

                Button("Settings...") {
                    if settingsController == nil {
                        settingsController = SettingsWindowController(appState: appState)
                    }
                    settingsController?.show()
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
        } label: {
            Image(systemName: appState.isRecording ? "mic.fill" : "mic")
                .foregroundColor(appState.isRecording ? KoeTheme.vermilion : .primary)
        }
        .menuBarExtraStyle(.window)
    }
}
