import AppKit
import SwiftUI

@main
struct KoeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager!
    private var recorder: AudioRecorder!
    private var transcriber: WhisperTranscriber!
    private var hud: HUDWindow!
    private var isRecording = false
    private var isTranscribing = false
    private var mainWindowController: MainWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()

        recorder = AudioRecorder()
        transcriber = WhisperTranscriber()
        hud = HUDWindow()
        mainWindowController = MainWindowController()
        _ = TranscriptStore.shared

        hotkeyManager = HotkeyManager { [weak self] in
            self?.toggleRecording()
        }
        hotkeyManager.register()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Koe")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Koe", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let openItem = NSMenuItem(title: "Open Koe…", action: #selector(openKoe), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let hotkeyItem = NSMenuItem(title: "Hotkey: Option+K", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Koe", action: #selector(quitKoe), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc
    private func openKoe() {
        mainWindowController.showWindow()
    }

    @objc
    private func quitKoe() {
        NSApp.terminate(nil)
    }

    private func toggleRecording() {
        guard !isTranscribing else { return }

        if isRecording {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        recorder.start { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !granted {
                    self.hud.show(state: .error)
                    self.scheduleHUDHide(after: 1.5)
                    return
                }
                self.isRecording = true
                self.hud.show(state: .recording)
                self.updateStatusIcon(isRecording: true)
            }
        }
    }

    private func stopAndTranscribe() {
        isRecording = false
        isTranscribing = true
        hud.show(state: .transcribing)
        updateStatusIcon(isRecording: false)

        recorder.stop { [weak self] audioURL in
            guard let self else { return }
            guard let audioURL else {
                self.failTranscription()
                return
            }

            self.transcriber.transcribe(audioURL: audioURL) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    defer {
                        try? FileManager.default.removeItem(at: audioURL)
                    }

                    switch result {
                    case .success(let text):
                        ClipboardManager.copy(text)
                        TranscriptStore.shared.add(text)
                        self.hud.show(state: .done(text: text))
                        self.scheduleHUDHide(after: 2.0)
                    case .failure:
                        self.failTranscription()
                    }
                }
            }
        }
    }

    private func failTranscription() {
        hud.show(state: .error)
        scheduleHUDHide(after: 1.5)
    }

    private func scheduleHUDHide(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.hud.hide()
            self?.isTranscribing = false
        }
    }

    private func updateStatusIcon(isRecording: Bool) {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Koe")
        button.image?.isTemplate = !isRecording
        button.contentTintColor = isRecording ? .systemOrange : nil
    }
}
