import Foundation

enum TranscriberError: Error, Equatable {
    case binaryNotFound
    case modelNotFound
    case whisperFailed(String)
    case emptyResult

    static func == (lhs: TranscriberError, rhs: TranscriberError) -> Bool {
        switch (lhs, rhs) {
        case (.binaryNotFound, .binaryNotFound),
             (.modelNotFound, .modelNotFound),
             (.emptyResult, .emptyResult):
            return true
        case (.whisperFailed(let lhsMsg), .whisperFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

class WhisperTranscriber: @unchecked Sendable {
    func transcribe(audioURL: URL, completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try self.run(audioURL: audioURL)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func run(audioURL: URL) throws -> String {
        guard let binaryURL = resolveBinary() else { throw TranscriberError.binaryNotFound }
        guard FileManager.default.fileExists(atPath: binaryURL.path) else {
            throw TranscriberError.binaryNotFound
        }
        guard let modelURL = resolveModel() else { throw TranscriberError.modelNotFound }

        // Ensure bundled binary has executable permissions
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: binaryURL.path
        )

        let process = Process()
        process.executableURL = binaryURL
        process.arguments = [
            "-m", modelURL.path,
            "-f", audioURL.path,
            "-nt",
            "-l", "auto",
            "--no-prints",
            "--output-txt",
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        // Primary: read .txt file written next to .wav
        let txtURL = audioURL.deletingPathExtension().appendingPathExtension("txt")
        if let data = try? Data(contentsOf: txtURL),
           let raw = String(data: data, encoding: .utf8) {
            try? FileManager.default.removeItem(at: txtURL)
            let cleaned = clean(raw)
            guard !cleaned.isEmpty else { throw TranscriberError.emptyResult }
            return cleaned
        }

        // Fallback: stdout
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        if let raw = String(data: stdoutData, encoding: .utf8) {
            let cleaned = clean(raw)
            guard !cleaned.isEmpty else { throw TranscriberError.emptyResult }
            return cleaned
        }

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrString = String(data: stderrData, encoding: .utf8) ?? ""
        throw TranscriberError.whisperFailed(stderrString)
    }

    private func clean(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func resolveBinary() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli",
        ]
        if let systemBinary = candidates
            .map({ URL(fileURLWithPath: $0) })
            .first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return systemBinary
        }
        
        return Bundle.main.url(forResource: "whisper-cli", withExtension: nil)
    }

    private func resolveModel() -> URL? {
        let support = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Koe/ggml-base.en.bin")
        if FileManager.default.fileExists(atPath: support.path) {
            return support
        }
        
        return Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin")
    }
}
