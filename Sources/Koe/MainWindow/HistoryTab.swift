import SwiftUI

struct HistoryTab: View {
    @ObservedObject var store = TranscriptStore.shared

    var body: some View {
        VStack(spacing: 0) {
            if store.entries.isEmpty {
                emptyState
            } else {
                logHeader
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                            ArchivalEntryRow(
                                index: index + 1,
                                entry: entry,
                                onDelete: { store.delete(entry) }
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KoeTheme.ivory)
    }

    // MARK: Sub-views

    private var logHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Transcript Log")
                .font(KoeTheme.serifSmall)
                .foregroundColor(KoeTheme.stone)
                .textCase(.uppercase)
                .tracking(1.2)

            Spacer()

            Text(String(format: "%02d entries", store.entries.count))
                .font(KoeTheme.monoTiny)
                .foregroundColor(KoeTheme.vermilion.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .overlay(
            Rectangle()
                .fill(KoeTheme.ink.opacity(0.07))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("— No entries —")
                .font(KoeTheme.serifTitle)
                .foregroundColor(KoeTheme.stone)

            Text("Press ⌥ Space anywhere to begin recording.")
                .font(KoeTheme.monoTiny)
                .foregroundColor(KoeTheme.stoneL)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Archival Entry Row

private struct ArchivalEntryRow: View {
    let index: Int
    let entry: TranscriptEntry
    let onDelete: () -> Void

    @State private var isHovered   = false
    @State private var showCopied  = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Index number
            Text(String(format: "%02d.", index))
                .font(KoeTheme.monoTiny)
                .foregroundColor(KoeTheme.vermilion.opacity(0.4))
                .frame(width: 28, alignment: .leading)
                .padding(.top, 1)

            // Transcript text
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.text)
                    .font(KoeTheme.serifSmall)
                    .foregroundColor(KoeTheme.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 0) {
                    Text(entry.date, style: .relative)
                        .font(KoeTheme.monoTiny)
                        .foregroundColor(KoeTheme.stone)

                    // Dotted rule
                    GeometryReader { geo in
                        Path { path in
                            let y = geo.size.height / 2
                            var x: CGFloat = 0
                            while x < geo.size.width {
                                path.move(to: CGPoint(x: x, y: y))
                                path.addLine(to: CGPoint(x: x + 2, y: y))
                                x += 5
                            }
                        }
                        .stroke(KoeTheme.vermilion.opacity(0.18), lineWidth: 0.8)
                    }
                    .frame(height: 1)
                    .padding(.horizontal, 8)

                    if showCopied {
                        Text("copied")
                            .font(KoeTheme.monoTiny)
                            .foregroundColor(KoeTheme.doneColor)
                            .transition(.opacity)
                    } else if isHovered {
                        Text("copy")
                            .font(KoeTheme.monoTiny)
                            .foregroundColor(KoeTheme.vermilion)
                            .transition(.opacity)
                    }
                }
            }

            // Delete button (on hover)
            if isHovered {
                Button(action: onDelete) {
                    Text("×")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(KoeTheme.stone)
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)
                .padding(.top, 1)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
        .background(isHovered ? KoeTheme.ivoryDeep : KoeTheme.ivory)
        .overlay(
            Rectangle()
                .fill(KoeTheme.ink.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { copyEntry() }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .animation(.easeInOut(duration: 0.12), value: showCopied)
    }

    private func copyEntry() {
        ClipboardManager.copy(entry.text)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }
}
