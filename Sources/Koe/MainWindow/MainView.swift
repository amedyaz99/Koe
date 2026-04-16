import SwiftUI

// MARK: - Tab Enum

enum KoeTab: Hashable {
    case record, history, settings
}

// MARK: - MainView

struct MainView: View {
    @State private var selectedTab: KoeTab = .record

    var body: some View {
        ZStack {
            // Ivory ground
            KoeTheme.ivory.ignoresSafeArea()
            // Dot grid overlay
            DotGridBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // Tape marks at top edge
                TapeMarks()

                // Custom tab bar
                KoeTabBar(selected: $selectedTab)

                Divider()
                    .overlay(KoeTheme.ink.opacity(0.08))

                // Tab content
                Group {
                    switch selectedTab {
                    case .record:   RecordTab()
                    case .history:  HistoryTab()
                    case .settings: SettingsTab()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KoeTheme.ivory)
            }
        }
        .frame(minWidth: 480, minHeight: 400)
    }
}

// MARK: - Tab Bar

struct KoeTabBar: View {
    @Binding var selected: KoeTab

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            tabButton(.record,   label: "Record")
            tabButton(.history,  label: "History")
            tabButton(.settings, label: "Settings")

            Spacer()

            InkanStamp(size: 28)
                .padding(.trailing, 14)
                .padding(.bottom, 5)
        }
        .padding(.leading, 14)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func tabButton(_ tab: KoeTab, label: String) -> some View {
        let isActive = selected == tab
        Button(action: { selected = tab }) {
            Text(label)
                .font(KoeTheme.serifTitle)
                .foregroundColor(isActive ? KoeTheme.ink : KoeTheme.stone)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    isActive
                        ? RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(KoeTheme.ivory)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(KoeTheme.ink.opacity(0.1), lineWidth: 1)
                            )
                        : nil
                )
        }
        .buttonStyle(.plain)
    }
}
