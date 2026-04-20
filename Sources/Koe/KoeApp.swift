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
                    .background(KoeTheme.washiMuted.opacity(0.1))

                HStack(spacing: 24) {
                    Button(action: {
                        if settingsController == nil {
                            settingsController = SettingsWindowController(appState: appState)
                        }
                        settingsController?.show()
                    }) {
                        Text("SETTINGS")
                            .font(KoeTheme.monoTiny)
                            .foregroundColor(KoeTheme.washiMuted)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Text("QUIT")
                            .font(KoeTheme.monoTiny)
                            .foregroundColor(KoeTheme.vermilion.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(KoeTheme.sumiInk)
            }
        } label: {
            Image(systemName: appState.isRecording ? "mic.fill" : "mic")
                .foregroundColor(appState.isRecording ? KoeTheme.vermilion : .primary)
        }
        .menuBarExtraStyle(.window)
    }
}
