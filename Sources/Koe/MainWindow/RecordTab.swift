import SwiftUI

struct RecordTab: View {
    @State private var state: RecordState = .idle
    @State private var recorder = AudioRecorder()
    @State private var transcriber = WhisperTranscriber()

    enum RecordState {
        case idle
        case recording
        case transcribing
        case done(text: String)
        case error(message: String)
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Large Mic Button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(buttonColor)
                        .frame(width: 100, height: 100)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    if case .recording = state {
                        WaveformView(barWidth: 6, minHeight: 15, maxHeight: 40, color: .white)
                            .frame(width: 50)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isButtonDisabled)
            
            // Status Label
            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if case .done(let text) = state {
                    Text(text)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .lineLimit(3)
                } else if case .error(let msg) = state {
                    Text(msg)
                        .font(.body)
                        .foregroundColor(.red)
                } else {
                    Text(statusSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 100)
            
            Spacer()
        }
        .padding()
    }
    
    private var buttonColor: Color {
        switch state {
        case .idle:         return .orange
        case .recording:    return .orange
        case .transcribing: return .gray
        case .done:         return Color(hex: "#508C5A")
        case .error:        return Color(hex: "#B85A3C")
        }
    }

    private var isButtonDisabled: Bool {
        if case .transcribing = state { return true }
        return false
    }

    private var statusTitle: String {
        switch state {
        case .idle:         return "Ready to record"
        case .recording:    return "Recording..."
        case .transcribing: return "Transcribing..."
        case .done:         return "Copied!"
        case .error:        return "Error"
        }
    }

    private var statusSubtitle: String {
        switch state {
        case .idle:         return "Tap the mic to start"
        case .recording:    return "Tap again to stop"
        case .transcribing: return "Processing your voice"
        case .done:         return "Added to your history"
        case .error:        return "Something went wrong"
        }
    }

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
            if granted {
                state = .recording
            } else {
                state = .error(message: "Microphone access denied")
            }
        }
    }
    
    private func stopRecording() {
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
                        
                        // Reset after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            if case .done = state {
                                state = .idle
                            }
                        }
                    case .failure(let error):
                        state = .error(message: error.localizedDescription)
                    }
                }
            }
        }
    }
}
