import SwiftUI

struct HistoryTab: View {
    @ObservedObject var store = TranscriptStore.shared
    @State private var showingCopiedLabel = false
    
    var body: some View {
        VStack(spacing: 0) {
            if store.entries.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "clock")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No transcripts yet")
                        .font(.headline)
                    Text("Press ⌥K anywhere to start recording.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.entries) { entry in
                        HistoryRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                ClipboardManager.copy(entry.text)
                                showCopiedFeedback()
                            }
                    }
                    .onDelete(perform: deleteEntries)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            
            if showingCopiedLabel {
                Text("Copied to clipboard")
                    .font(.caption)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        offsets.forEach { index in
            store.delete(store.entries[index])
        }
    }
    
    private func showCopiedFeedback() {
        withAnimation {
            showingCopiedLabel = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showingCopiedLabel = false
            }
        }
    }
}

struct HistoryRow: View {
    let entry: TranscriptEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.text)
                .font(.body)
                .lineLimit(2)
            
            Text(entry.date, style: .relative)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
