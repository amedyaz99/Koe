import AppKit
import SwiftUI

// MARK: - State

enum HUDState {
    case recording
    case transcribing
    case done(text: String)
    case error
}

// MARK: - HUD View

struct HUDView: View {
    let state: HUDState

    var body: some View {
        ZStack {
            // Background
            ContinuousRoundedRectangle(cornerRadius: 18)
                .fill(KoeTheme.sumiInk)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)

            // Accent Glow
            if let tint = tintColor {
                ContinuousRoundedRectangle(cornerRadius: 18)
                    .stroke(tint.opacity(0.3), lineWidth: 1)
            }

            // Content
            HStack(spacing: 16) {
                iconView
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(KoeTheme.monoSmall)
                        .foregroundColor(KoeTheme.washiPaper)

                    Text(subtitle)
                        .font(KoeTheme.mainSmall)
                        .foregroundColor(KoeTheme.washiMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .frame(width: 340, height: 72)
    }

    @ViewBuilder
    private var iconView: some View {
        switch state {
        case .recording:
            WaveformView(barWidth: 3, minHeight: 8, maxHeight: 22, color: KoeTheme.vermilion)
                .frame(width: 28)
        case .transcribing:
            ProgressView()
                .scaleEffect(0.8)
                .tint(KoeTheme.transcribingColor)
        case .done:
            InkanStamp(size: 28)
        case .error:
            Circle()
                .fill(KoeTheme.errorColor)
                .overlay(
                    Text("!")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }

    private var title: String {
        switch state {
        case .recording:    return "RECORDING"
        case .transcribing: return "PROCESSING"
        case .done:         return "COPIED"
        case .error:        return "ERROR"
        }
    }

    private var subtitle: String {
        switch state {
        case .recording:         return "Listening for voice..."
        case .transcribing:      return "Converting to text..."
        case .done(let text):    return text
        case .error:             return "Transcription failed"
        }
    }

    private var tintColor: Color? {
        switch state {
        case .recording:    return KoeTheme.vermilion
        case .transcribing: return KoeTheme.transcribingColor
        case .done:         return KoeTheme.gold
        case .error:        return KoeTheme.errorColor
        }
    }
}

// MARK: - HUD Window

class HUDWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 72),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isReleasedWhenClosed = false
    }

    func show(state: HUDState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.contentView = NSHostingView(rootView: HUDView(state: state))
            self.position()
            self.makeKeyAndOrderFront(nil)
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.orderOut(nil)
        }
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let x = frame.midX - 170
        let y = frame.minY + 80
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
