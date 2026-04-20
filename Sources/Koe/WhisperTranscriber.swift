import Foundation

enum TranscriberError: Error {
    case binaryNotFound
    case modelNotFound
    case whisperFailed(String)
    case emptyResult
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
        if let url = Bundle.main.url(forResource: "whisper-cli", withExtension: nil) {
            return url
        }
        let candidates = [
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli",
        ]
        return candidates
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func resolveModel() -> URL? {
        if let url = Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin") {
            return url
        }
        let support = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Koe/ggml-base.en.bin")
        return FileManager.default.fileExists(atPath: support.path) ? support : nil
    }
}
