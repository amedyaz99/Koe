import SwiftUI

struct RecordTab: View {
    @State private var state: RecordState = .idle
    @State private var recorder    = AudioRecorder()
    @State private var transcriber = WhisperTranscriber()
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?

    enum RecordState {
        case idle
        case recording
        case transcribing
        case done(text: String)
        case error(message: String)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // ── Recording Pill ──
                RecordingPill(state: state, elapsed: elapsedSeconds)

                ArchivalDivider()
                    .frame(width: 280)

                // ── Terminal metadata ──
                terminalBlock

                ArchivalDivider()
                    .frame(width: 280)

                // ── Mic button ──
                micButton
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KoeTheme.ivory)
    }

    // MARK: Terminal metadata

    private var terminalBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            TerminalRow(key: "Sample Rate", value: "16kHz",      valueColor: KoeTheme.stone)
            TerminalRow(key: "Channels",    value: "1 (mono)",   valueColor: KoeTheme.stone)
            TerminalRow(key: "Model",       value: "base.en",    valueColor: KoeTheme.ink)
            TerminalRow(key: "Engine",      value: "whisper.cpp",valueColor: KoeTheme.ink)
            TerminalRow(key: "Status",      value: statusValue,  valueColor: statusColor)
        }
        .padding(12)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(KoeTheme.ivoryDeep)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(KoeTheme.ink.opacity(0.07), lineWidth: 1)
                )
        )
    }

    private var statusValue: String {
        switch state {
        case .idle:         return "Idle"
        case .recording:    return "Recording"
        case .transcribing: return "Processing"
        case .done:         return "Copied"
        case .error:        return "Error"
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle:         return KoeTheme.stone
        case .recording:    return KoeTheme.vermilion
        case .transcribing: return KoeTheme.transcribingColor
        case .done:         return KoeTheme.doneColor
        case .error:        return KoeTheme.errorColor
        }
    }

    // MARK: Mic button

    private var micButton: some View {
        VStack(spacing: 7) {
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(micButtonFill)
                        .frame(width: 48, height: 48)

                    if case .recording = state {
                        WaveformView(barWidth: 3, minHeight: 8, maxHeight: 18, color: KoeTheme.ivory)
                            .frame(width: 28)
                    } else if case .transcribing = state {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(KoeTheme.ivory)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 18))
                            .foregroundColor(KoeTheme.ivory)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            Text(micLabel)
                .font(KoeTheme.monoTiny)
                .foregroundColor(KoeTheme.stone)
                .animation(.none, value: micLabel)
        }
    }

    private var micButtonFill: Color {
        switch state {
        case .idle:         return KoeTheme.ink
        case .recording:    return KoeTheme.vermilion
        case .transcribing: return KoeTheme.transcribingColor
        case .done:         return KoeTheme.doneColor
        case .error:        return KoeTheme.errorColor
        }
    }

    private var micLabel: String {
        switch state {
        case .idle:         return "tap to record"
        case .recording:    return "tap to stop"
        case .transcribing: return "processing…"
        case .done:         return "copied ✓"
        case .error:        return "try again"
        }
    }

    private var isDisabled: Bool {
        if case .transcribing = state { return true }
        return false
    }

    // MARK: Actions

    private func toggleRecording() {
        switch state {
        case .idle, .done, .error:
            startRecording()
        case .recording:
            stopRecording()
        case .transcribing:
            break
        }
    }

    private func startRecording() {
        recorder.start { granted in
            DispatchQueue.main.async {
                if granted {
                    state = .recording
                    elapsedSeconds = 0
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        DispatchQueue.main.async { elapsedSeconds += 1 }
                    }
                } else {
                    state = .error(message: "Microphone access denied")
                }
            }
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        state = .transcribing
        recorder.stop { url in
            guard let url = url else {
                state = .error(message: "Failed to save audio")
                return
            }
            transcriber.transcribe(audioURL: url) { result in
                DispatchQueue.main.async {
                    defer { try? FileManager.default.removeItem(at: url) }
                    switch result {
                    case .success(let text):
                        ClipboardManager.copy(text)
                        TranscriptStore.shared.add(text)
                        state = .done(text: text)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            if case .done = state { state = .idle }
                        }
                    case .failure(let error):
                        state = .error(message: error.localizedDescription)
                    }
                }
            }
        }
    }
}

// MARK: - Recording Pill

private struct RecordingPill: View {
    let state: RecordTab.RecordState
    let elapsed: Int

    private var elapsedString: String {
        let m = elapsed / 60
        let s = elapsed % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Left: waveform or static indicator
            Group {
                if case .recording = state {
                    WaveformView(barWidth: 2.5, minHeight: 5, maxHeight: 20, color: KoeTheme.ink)
                        .frame(width: 36, height: 24)
                } else if case .transcribing = state {
                    ProgressView()
                        .scaleEffect(0.65)
                        .tint(KoeTheme.transcribingColor)
                        .frame(width: 36, height: 24)
                } else {
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { i in
                            Rectangle()
                                .fill(KoeTheme.ink.opacity(0.15))
                                .frame(width: 2.5, height: CGFloat([6,10,7,12,5,9,6][i]))
                                .cornerRadius(1)
                        }
                    }
                    .frame(width: 36, height: 24)
                }
            }

            // Right: status text
            VStack(alignment: .leading, spacing: 2) {
                Text(pillTitle)
                    .font(KoeTheme.monoSmall)
                    .foregroundColor(KoeTheme.ink)

                Text(pillSub)
                    .font(KoeTheme.monoTiny)
                    .foregroundColor(pillSubColor)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(KoeTheme.ivory)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(pillBorderColor, lineWidth: 1)
                )
        )
    }

    private var pillTitle: String {
        switch state {
        case .idle:         return "Buffer: Idle"
        case .recording:    return "Buffer: Active"
        case .transcribing: return "Buffer: Processing"
        case .done:         return "Copied to clipboard"
        case .error:        return "Error"
        }
    }

    private var pillSub: String {
        switch state {
        case .idle:         return "■  STANDBY"
        case .recording:    return "●  REC — \(elapsedString)"
        case .transcribing: return "◌  PROCESSING"
        case .done(let t):  return t.prefix(32).description + (t.count > 32 ? "…" : "")
        case .error(let m): return m
        }
    }

    private var pillSubColor: Color {
        switch state {
        case .idle:         return KoeTheme.stone
        case .recording:    return KoeTheme.vermilion
        case .transcribing: return KoeTheme.transcribingColor
        case .done:         return KoeTheme.doneColor
        case .error:        return KoeTheme.errorColor
        }
    }

    private var pillBorderColor: Color {
        switch state {
        case .idle:         return KoeTheme.ink.opacity(0.1)
        case .recording:    return KoeTheme.vermilion.opacity(0.3)
        case .transcribing: return KoeTheme.transcribingColor.opacity(0.2)
        case .done:         return KoeTheme.doneColor.opacity(0.2)
        case .error:        return KoeTheme.errorColor.opacity(0.2)
        }
    }
}
