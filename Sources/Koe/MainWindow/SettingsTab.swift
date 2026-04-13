import SwiftUI

struct SettingsTab: View {
    @AppStorage("koe.launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        Form {
            Section("Hotkey") {
                LabeledContent("Trigger") {
                    Text("⌥ K")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Transcription") {
                LabeledContent("Model") {
                    Text("base.en")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Engine", value: "whisper.cpp")
            }
            
            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        // SMAppService.mainApp.register/unregister would go here
                        // For now we just persist the intent
                    }
            }
            
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Built with", value: "SwiftUI")
            }
        }
        .formStyle(.grouped)
    }
}
