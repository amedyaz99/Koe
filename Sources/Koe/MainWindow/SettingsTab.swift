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
                archivalSection(
                    heading: "Hotkey",
                    japanese: "ショートカット"
                ) {
                    DottedLeaderRow(label: "Trigger") {
                        HotkeyBadge(
                            config: currentConfig,
                            isRecording: isRecordingHotkey,
                            onTap: toggleHotkeyRecording
                        )
                    }
                    if isRecordingHotkey {
                        Text("Press a key combination, or Escape to cancel.")
                            .font(KoeTheme.monoTiny)
                            .foregroundColor(KoeTheme.stone)
                            .padding(.top, 4)
                    }
                }

                archivalSection(
                    heading: "Transcription",
                    japanese: "文字起こし"
                ) {
                    DottedLeaderRow(label: "Model") {
                        Text("base.en")
                            .font(KoeTheme.monoSmall)
                            .foregroundColor(KoeTheme.vermilion)
                    }
                    DottedLeaderRow(label: "Engine") {
                        Text("whisper.cpp")
                            .font(KoeTheme.monoSmall)
                            .foregroundColor(KoeTheme.stone)
                    }
                    DottedLeaderRow(label: "Language") {
                        Text("auto")
                            .font(KoeTheme.monoSmall)
                            .foregroundColor(KoeTheme.stone)
                    }
                }

                archivalSection(
                    heading: "System",
                    japanese: "システム"
                ) {
                    DottedLeaderRow(label: "Launch at login") {
                        ArchivalToggle(isOn: $launchAtLogin)
                    }
                }

                archivalSection(
                    heading: "About",
                    japanese: "について"
                ) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .lastTextBaseline, spacing: 1) {
                                Text("koe")
                                    .font(.custom("HiraMinProN-W3", size: 32))
                                    .foregroundColor(KoeTheme.ink)
                                    .tracking(-0.5)
                                Text(".")
                                    .font(.custom("HiraMinProN-W3", size: 32))
                                    .foregroundColor(KoeTheme.vermilion)
                                    .tracking(-0.5)
                            }
                            Text("voice → clipboard")
                                .font(KoeTheme.monoTiny)
                                .foregroundColor(KoeTheme.stone)
                                .tracking(0.8)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text("v1.0.0")
                                .font(KoeTheme.monoTiny)
                                .foregroundColor(KoeTheme.stoneL)

                            InkanStamp(size: 34)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KoeTheme.ivory)
        .onReceive(NotificationCenter.default.publisher(for: .hotkeyConfigChanged)) { _ in
            currentConfig = HotkeyConfig.current
        }
        .onDisappear {
            stopHotkeyRecording(cancelled: true)
        }
    }

    // MARK: Section builder

    @ViewBuilder
    private func archivalSection<Content: View>(
        heading: String,
        japanese: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section heading
            HStack(spacing: 8) {
                Text(heading.uppercased())
                    .font(KoeTheme.serifTiny)
                    .foregroundColor(KoeTheme.stone)
                    .tracking(1.4)

                Text("— \(japanese)")
                    .font(KoeTheme.serifTiny)
                    .foregroundColor(KoeTheme.vermilion.opacity(0.4))

                // Gradient rule after heading
                ArchivalDivider()
            }

            content()
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 4)
        .overlay(
            Rectangle()
                .fill(KoeTheme.ink.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: Hotkey recording

    private func toggleHotkeyRecording() {
        isRecordingHotkey ? stopHotkeyRecording(cancelled: true) : startHotkeyRecording()
    }

    private func startHotkeyRecording() {
        isRecordingHotkey = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
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

// MARK: - Hotkey Badge

private struct HotkeyBadge: View {
    let config: HotkeyConfig
    let isRecording: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(isRecording ? "recording…" : config.displayString)
                .font(KoeTheme.monoSmall)
                .foregroundColor(isRecording ? KoeTheme.stone : KoeTheme.vermilion)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(KoeTheme.ivoryDeep)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(
                                    isRecording
                                        ? KoeTheme.stone.opacity(0.3)
                                        : KoeTheme.vermilion.opacity(0.25),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Archival Toggle

private struct ArchivalToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 6) {
                // Track
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? KoeTheme.ink : KoeTheme.stoneL.opacity(0.4))
                        .frame(width: 32, height: 18)
                    Circle()
                        .fill(KoeTheme.ivory)
                        .frame(width: 13, height: 13)
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .padding(2.5)
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isOn)
            }
        }
        .buttonStyle(.plain)
    }
}
