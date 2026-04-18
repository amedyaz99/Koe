import AppKit
import SwiftUI

struct SettingsTab: View {
    @AppStorage("koe.launchAtLogin") private var launchAtLogin = false
    @State private var currentConfig = HotkeyConfig.current
    @State private var isRecordingHotkey = false
    @State private var monitor: Any?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                settingsSection(
                    heading: "Hotkey",
                    japanese: "ショートカット"
                ) {
                    HStack {
                        Text("Trigger")
                            .font(KoeTheme.monoSmall)
                            .foregroundColor(KoeTheme.washiPaper)
                        
                        Spacer()
                        
                        HotkeyBadge(
                            config: currentConfig,
                            isRecording: isRecordingHotkey,
                            onTap: toggleHotkeyRecording
                        )
                    }
                    
                    if isRecordingHotkey {
                        Text("Press a key combination, or Escape to cancel.")
                            .font(KoeTheme.monoTiny)
                            .foregroundColor(KoeTheme.washiMuted)
                            .padding(.top, 4)
                    }
                }

                settingsSection(
                    heading: "Transcription",
                    japanese: "文字起こし"
                ) {
                    VStack(spacing: 12) {
                        settingsRow(label: "Model", value: "base.en", valueColor: KoeTheme.vermilion)
                        settingsRow(label: "Engine", value: "whisper.cpp")
                        settingsRow(label: "Language", value: "auto")
                    }
                }

                settingsSection(
                    heading: "System",
                    japanese: "システム"
                ) {
                    HStack {
                        Text("Launch at login")
                            .font(KoeTheme.monoSmall)
                            .foregroundColor(KoeTheme.washiPaper)
                        
                        Spacer()
                        
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .tint(KoeTheme.vermilion)
                    }
                }

                settingsSection(
                    heading: "About",
                    japanese: "について"
                ) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("Koe")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(KoeTheme.washiPaper)
                                Text(".")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(KoeTheme.vermilion)
                            }
                            Text("voice → clipboard")
                                .font(KoeTheme.monoTiny)
                                .foregroundColor(KoeTheme.washiMuted)
                                .tracking(1.0)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            Text("v1.0.0")
                                .font(KoeTheme.monoTiny)
                                .foregroundColor(KoeTheme.washiMuted)

                            InkanStamp(size: 32)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KoeTheme.sumiInk)
        .onReceive(NotificationCenter.default.publisher(for: .hotkeyConfigChanged)) { _ in
            currentConfig = HotkeyConfig.current
        }
        .onDisappear {
            stopHotkeyRecording(cancelled: true)
        }
    }

    private func settingsRow(label: String, value: String, valueColor: Color = KoeTheme.washiMuted) -> some View {
        HStack {
            Text(label)
                .font(KoeTheme.monoSmall)
                .foregroundColor(KoeTheme.washiPaper)
            Spacer()
            Text(value)
                .font(KoeTheme.monoSmall)
                .foregroundColor(valueColor)
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        heading: String,
        japanese: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(heading.uppercased())
                    .font(KoeTheme.monoTiny)
                    .foregroundColor(KoeTheme.washiMuted)
                    .tracking(2.0)

                Text("— \(japanese)")
                    .font(.system(size: 10))
                    .foregroundColor(KoeTheme.vermilion.opacity(0.6))
                
                Spacer()
            }

            content()
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }

    private func toggleHotkeyRecording() {
        isRecordingHotkey ? stopHotkeyRecording(cancelled: true) : startHotkeyRecording()
    }

    private func startHotkeyRecording() {
        isRecordingHotkey = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopHotkeyRecording(cancelled: true)
                return nil
            }
            let nsModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !nsModifiers.isEmpty else { return event }
            let cgModifiers = CGEventFlags(rawValue: UInt64(nsModifiers.rawValue))
            let config = HotkeyConfig(keyCode: Int64(event.keyCode), modifierFlags: cgModifiers.rawValue)
            HotkeyConfig.current = config
            stopHotkeyRecording(cancelled: false)
            return nil
        }
    }

    private func stopHotkeyRecording(cancelled: Bool) {
        isRecordingHotkey = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        if !cancelled { currentConfig = HotkeyConfig.current }
    }
}

private struct HotkeyBadge: View {
    let config: HotkeyConfig
    let isRecording: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(isRecording ? "RECORDING…" : config.displayString.uppercased())
                .font(KoeTheme.monoSmall)
                .foregroundColor(isRecording ? KoeTheme.vermilion : KoeTheme.washiPaper)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    ContinuousRoundedRectangle(cornerRadius: 6)
                        .fill(KoeTheme.sumiInkLight)
                        .overlay(
                            ContinuousRoundedRectangle(cornerRadius: 6)
                                .stroke(isRecording ? KoeTheme.vermilion : KoeTheme.washiMuted.opacity(0.3), lineWidth: 1)

                        )
                )
        }
        .buttonStyle(.plain)
    }
}
