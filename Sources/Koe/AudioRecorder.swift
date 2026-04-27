import AudioToolbox
import AVFoundation
import CoreAudio

@MainActor
class AudioRecorder {
    private var engine: AVAudioEngine?
    private var outputFile: AVAudioFile?
    private var tempURL: URL?

    /// Returns false if mic permission is denied.
    func start(completion: @escaping @Sendable (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            beginRecording()
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    Task { @MainActor [weak self] in
                        if granted { self?.beginRecording() }
                        completion(granted)
                    }
                }
            }
        default:
            completion(false)
        }
    }

    func stop(completion: @escaping (URL?) -> Void) {
        guard let engine, let tempURL else {
            completion(nil)
            return
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        outputFile = nil  // flushes and closes before URL is safe to read
        completion(tempURL)
        self.engine = nil
        self.tempURL = nil
    }

    func cancel() {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        outputFile = nil
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        self.engine = nil
        self.tempURL = nil
    }

    private func beginRecording() {
        let newEngine = AVAudioEngine()

        // Apply selected microphone before querying format (format can differ per device)
        let input = newEngine.inputNode
        let selectedUID = UserDefaults.standard.string(forKey: "koe.microphoneUID") ?? ""
        if !selectedUID.isEmpty,
           let device = MicrophoneDevice.allInputDevices().first(where: { $0.uid == selectedUID }),
           device.id != 0,
           let audioUnit = input.audioUnit {
            var deviceID = device.id
            AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
        }

        let format = input.outputFormat(forBus: 0)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        guard let file = try? AVAudioFile(forWriting: url, settings: format.settings) else {
            return
        }

        outputFile = file
        tempURL = url
        engine = newEngine

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            try? self?.outputFile?.write(from: buffer)
        }

        try? newEngine.start()
    }
}
