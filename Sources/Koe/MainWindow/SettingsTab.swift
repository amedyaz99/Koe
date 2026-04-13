import AppKit
import SwiftUI

struct SettingsTab: View {
    @AppStorage("koe.launchAtLogin") private var launchAtLogin = false
    @State private var currentConfig = HotkeyConfig.current
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Form {
            Section("Hotkey") {
                LabeledContent("Trigger") {
                    HotkeyRecorderButton(
                        config: currentConfig,
                        isRecording: isRecording,
                        onTap: toggleRecording
                    )
                }
                if isRecording {
                    Text("Press a key combination, or Escape to cancel.")
                        .font(.caption)
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
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: .hotkeyConfigChanged)) { _ in
            currentConfig = HotkeyConfig.current
        }
        .onDisappear {
            stopRecording(cancelled: true)
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording(cancelled: true)
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // Escape cancels
            if event.keyCode == 53 {
                stopRecording(cancelled: true)
                return nil
            }

            // Require at least one modifier key
            let nsModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !nsModifiers.isEmpty else { return event }

            // NSEvent.ModifierFlags bits happen to match CGEventFlags bits
            let cgModifiers = CGEventFlags(rawValue: UInt64(nsModifiers.rawValue))
            let config = HotkeyConfig(keyCode: Int64(event.keyCode), modifierFlags: cgModifiers.rawValue)
            HotkeyConfig.current = config
            stopRecording(cancelled: false)
            return nil  // consume the event
        }
    }

    private func stopRecording(cancelled: Bool) {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if !cancelled {
            currentConfig = HotkeyConfig.current
        }
    }
}

// MARK: - Recorder Button

private struct HotkeyRecorderButton: View {
    let config: HotkeyConfig
    let isRecording: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(isRecording ? "Recording…" : config.displayString)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(isRecording ? .secondary : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording
                              ? Color.accentColor.opacity(0.12)
                              : Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isRecording
                                        ? Color.accentColor.opacity(0.5)
                                        : Color(NSColor.separatorColor),
                                        lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
