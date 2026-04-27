import AppKit
import SwiftUI
import ServiceManagement

struct SettingsTab: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("koe.launchAtLogin") private var launchAtLogin = false
    @AppStorage("koe.autoPaste") private var autoPasteEnabled = true
    @AppStorage("koe.recordingMode") private var recordingModeRaw: String = "toggle"
    @AppStorage("koe.microphoneUID") private var selectedMicUID: String = ""
    @State private var currentConfig = HotkeyConfig.current
    @State private var isRecordingHotkey = false
    @State private var monitor: Any?
    @State private var availableDevices: [MicrophoneDevice] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                settingsSection(
                    heading: "Hotkey",
                    japanese: "ショートカット"
                ) {
                    VStack(spacing: 12) {
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
                        }

                        Divider()
                            .background(KoeTheme.washiMuted.opacity(0.15))

                        HStack {
                            Text("Mode")
                                .font(KoeTheme.monoSmall)
                                .foregroundColor(KoeTheme.washiPaper)
                            Spacer()
                            ModeControl(selection: $recordingModeRaw)
                        }

                        if recordingModeRaw == "pushToTalk" {
                            Text("Hold the hotkey while speaking — release to transcribe.")
                                .font(KoeTheme.monoTiny)
                                .foregroundColor(KoeTheme.washiMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                settingsSection(
                    heading: "Input",
                    japanese: "入力"
                ) {
                    HStack {
                        Text("Microphone")
                            .font(KoeTheme.monoSmall)
                            .foregroundColor(KoeTheme.washiPaper)
                        Spacer()
                        Picker("", selection: $selectedMicUID) {
                            ForEach(availableDevices) { device in
                                Text(device.name).tag(device.uid)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 180)
                        .labelsHidden()
                        .tint(KoeTheme.washiPaper)
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
                    VStack(spacing: 12) {
                        HStack {
                            Text("Launch at login")
                                .font(KoeTheme.monoSmall)
                                .foregroundColor(KoeTheme.washiPaper)

                            Spacer()

                            Toggle("", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                                .tint(KoeTheme.vermilion)
                                .onChange(of: launchAtLogin) { newValue in
                                    updateLaunchAtLogin(enabled: newValue)
                                }
                        }
                        Divider()
                            .background(KoeTheme.washiMuted.opacity(0.15))

                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Auto-paste")
                                    .font(KoeTheme.monoSmall)
                                    .foregroundColor(KoeTheme.washiPaper)
                                Text("Paste into active field after transcription")
                                    .font(KoeTheme.monoTiny)
                                    .foregroundColor(KoeTheme.washiMuted)
                            }
                            Spacer()
                            Toggle("", isOn: $autoPasteEnabled)
                                .toggleStyle(.switch)
                                .tint(KoeTheme.vermilion)
                        }
                    }
                }

                settingsSection(
                    heading: "Permissions",
                    japanese: "権限"
                ) {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Accessibility")
                                    .font(KoeTheme.monoSmall)
                                    .foregroundColor(KoeTheme.washiPaper)
                                Text("Required for global hotkey")
                                    .font(KoeTheme.monoTiny)
                                    .foregroundColor(KoeTheme.washiMuted)
                            }

                            Spacer()

                            if appState.hotkeyManager?.isAccessibilityTrusted ?? false {
                                Text("Granted")
                                    .font(KoeTheme.monoTiny)
                                    .foregroundColor(KoeTheme.washiMuted)
                            } else {
                                Button("Grant Access →") {
                                    appState.hotkeyManager?.openAccessibilitySettings()
                                }
                                .font(KoeTheme.monoSmall)
                                .foregroundColor(KoeTheme.vermilion)
                                .buttonStyle(.plain)
                            }
                        }
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
        .onAppear {
            availableDevices = MicrophoneDevice.allInputDevices()
        }
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
                .padding(16)
                .background(
                    ContinuousRoundedRectangle(cornerRadius: 12)
                        .fill(KoeTheme.sumiInkLight.opacity(0.8))
                        .overlay(
                            ContinuousRoundedRectangle(cornerRadius: 12)
                                .stroke(KoeTheme.washiMuted.opacity(0.18), lineWidth: 1)
                        )
                )
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

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
}

private struct ModeControl: View {
    @Binding var selection: String

    private let options: [(label: String, tag: String)] = [
        ("Toggle", "toggle"),
        ("Push to talk", "pushToTalk"),
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.tag) { option in
                segment(option.label, tag: option.tag)
            }
        }
        .padding(3)
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
        .clipShape(ContinuousRoundedRectangle(cornerRadius: 9))
        .overlay(
            ContinuousRoundedRectangle(cornerRadius: 9)
                .stroke(KoeTheme.washiMuted.opacity(0.18), lineWidth: 1)
        )
    }

    private func segment(_ label: String, tag: String) -> some View {
        let isSelected = selection == tag
        return Button(action: {
            withAnimation(KoeTheme.ease) { selection = tag }
        }) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular, design: .monospaced))
                .foregroundColor(isSelected ? KoeTheme.washiPaper : KoeTheme.washiMuted.opacity(0.75))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    ContinuousRoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? KoeTheme.sumiInkLight : Color.clear)
                        .overlay(
                            ContinuousRoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? KoeTheme.washiMuted.opacity(0.22) : Color.clear, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
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
