import SwiftUI
import AppKit
import Combine
import AVFoundation

@MainActor
class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var lastTranscript: String?
    @Published var showOnboarding: Bool = false

    private var recorder: AudioRecorder
    private var transcriber: WhisperTranscriber
    private var hud: HUDWindow
    var hotkeyManager: HotkeyManager!

    @AppStorage("koe.autoPaste") private var autoPasteEnabled = true
    @AppStorage("koe.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    private var frontmostAppAtRecordStart: NSRunningApplication?
    private var onboardingController: OnboardingWindowController?

    init() {
        self.recorder = AudioRecorder()
        self.transcriber = WhisperTranscriber()
        self.hud = HUDWindow()

        self.hotkeyManager = HotkeyManager(
            onTrigger: { [weak self] in
                Task { @MainActor in
                    self?.toggleRecording()
                }
            },
            onEscape: { [weak self] in
                Task { @MainActor in
                    guard let self = self else { return }
                    if self.isRecording { self.stopAndTranscribe() }
                }
            }
        )
        self.hotkeyManager.register()

        // Show onboarding on first launch
        if !hasCompletedOnboarding {
            self.showOnboarding = true
            self.onboardingController = OnboardingWindowController(appState: self)
            DispatchQueue.main.async { [weak self] in
                self?.onboardingController?.show()
            }
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        showOnboarding = false
        onboardingController?.close()
        onboardingController = nil
    }
    
    func toggleRecording() {
        guard !isTranscribing else { return }

        // Check accessibility permission
        guard hotkeyManager.checkTrustStatus() else {
            hud.show(state: .accessibilityDenied)
            scheduleHUDHide(after: 2.0)
            return
        }

        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)

        if isRecording {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        frontmostAppAtRecordStart = NSWorkspace.shared.frontmostApplication
        recorder.start { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !granted {
                    self.hud.show(state: .error)
                    self.scheduleHUDHide(after: 1.5)
                    return
                }
                self.isRecording = true
                self.hud.show(state: .recording)
            }
        }
    }
    
    private func stopAndTranscribe() {
        isRecording = false
        isTranscribing = true
        hud.show(state: .transcribing)
        
        recorder.stop { [weak self] audioURL in
            guard let self = self else { return }
            guard let audioURL = audioURL else {
                Task { @MainActor in
                    self.failTranscription()
                }
                return
            }
            
            self.transcriber.transcribe(audioURL: audioURL) { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    defer {
                        try? FileManager.default.removeItem(at: audioURL)
                    }
                    
                    switch result {
                    case .success(let text):
                        ClipboardManager.copy(text)
                        TranscriptStore.shared.add(text)
                        self.lastTranscript = text
                        if self.autoPasteEnabled, let app = self.frontmostAppAtRecordStart {
                            PasteManager.paste(to: app)
                            self.hud.show(state: .pasted(text: text))
                        } else {
                            self.hud.show(state: .done(text: text))
                        }
                        self.frontmostAppAtRecordStart = nil
                        self.scheduleHUDHide(after: 2.0)
                    case .failure(let error):
                        if let transcriberError = error as? TranscriberError,
                           transcriberError == .binaryNotFound {
                            self.hud.show(state: .binaryNotFound)
                            self.scheduleHUDHide(after: 2.0)
                        } else {
                            self.failTranscription()
                        }
                    }
                }
            }
        }
    }
    
    private func failTranscription() {
        frontmostAppAtRecordStart = nil
        hud.show(state: .error)
        scheduleHUDHide(after: 1.5)
    }
    
    private func scheduleHUDHide(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            Task { @MainActor [weak self] in
                self?.hud.hide()
                self?.isTranscribing = false
            }
        }
    }
}
