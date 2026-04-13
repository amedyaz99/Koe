import Foundation

struct TranscriptEntry: Identifiable, Codable {
    let id: UUID
    let text: String
    let date: Date
}

@MainActor
class TranscriptStore: ObservableObject {
    static let shared = TranscriptStore()
    private let maxEntries = 20
    private let defaultsKey = "koe.history"

    @Published private(set) var entries: [TranscriptEntry] = []

    private init() { load() }

    func add(_ text: String) {
        let entry = TranscriptEntry(id: UUID(), text: text, date: Date())
        entries.insert(entry, at: 0)
        if entries.count > maxEntries { entries = Array(entries.prefix(maxEntries)) }
        persist()
    }

    func delete(_ entry: TranscriptEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clear() {
        entries = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let saved = try? JSONDecoder().decode([TranscriptEntry].self, from: data)
        else { return }
        entries = saved
    }
}
