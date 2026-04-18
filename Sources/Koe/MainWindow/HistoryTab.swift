import SwiftUI

struct HistoryTab: View {
    @ObservedObject var store = TranscriptStore.shared
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            
            if store.entries.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 24) { // Generous vertical padding (Ma)
                        ForEach(store.entries) { entry in
                            HistoryEntryRow(entry: entry) {
                                store.delete(entry)
                            }
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KoeTheme.sumiInk)
    }

    private var header: some View {
        HStack {
            Text("履歴") // History in Japanese
                .font(KoeTheme.monoSmall)
                .foregroundColor(KoeTheme.vermilion)
            
            Spacer()
            
            if !store.entries.isEmpty {
                Button(action: { store.clear() }) {
                    Text("CLEAR ALL")
                        .font(KoeTheme.monoTiny)
                        .foregroundColor(KoeTheme.washiMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        HStack {
            InkanStamp(size: 24)
            
            Spacer()
            
            Button(action: {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(KoeTheme.washiMuted)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(KoeTheme.sumiInk.opacity(0.8))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("空") // Empty in Japanese
                .font(.system(size: 40, weight: .thin))
                .foregroundColor(KoeTheme.washiMuted.opacity(0.3))
            
            Text("No transcripts yet")
                .font(KoeTheme.mainSmall)
                .foregroundColor(KoeTheme.washiMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HistoryEntryRow: View {
    let entry: TranscriptEntry
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var showCopied = false
    @State private var isTapped = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.date, style: .time)
                    .font(KoeTheme.monoTiny)
                    .foregroundColor(KoeTheme.washiMuted)
                
                Spacer()
                
                if isHovered {
                    HStack(spacing: 12) {
                        Text(showCopied ? "COPIED" : "COPY")
                            .font(KoeTheme.monoTiny)
                            .foregroundColor(showCopied ? KoeTheme.gold : KoeTheme.vermilion)
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(KoeTheme.vermilion.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            
            Text(entry.text)
                .font(KoeTheme.mainText)
                .foregroundColor(KoeTheme.washiPaper)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            ContinuousRoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? KoeTheme.sumiInkLight : Color.clear)
        )
        .overlay(
            ContinuousRoundedRectangle(cornerRadius: 12)
                .stroke(isTapped ? KoeTheme.vermilion : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { copyEntry() }
        .animation(KoeTheme.spring, value: isHovered)
        .animation(KoeTheme.ease, value: isTapped)
    }
    
    private func copyEntry() {
        ClipboardManager.copy(entry.text)
        withAnimation {
            isTapped = true
            showCopied = true
        }
        
        // Reset tapped state after a brief moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                isTapped = false
            }
        }
        
        // Reset copied label after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopied = false
            }
        }
    }
}
