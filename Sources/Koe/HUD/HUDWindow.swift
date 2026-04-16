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
            // Base material
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)

            // State tint
            if let tint = tintColor {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(tint.opacity(tintOpacity))
            }

            // Border
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.5)

            // Content
            HStack(spacing: 14) {
                iconView
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()
            }
            .padding(.horizontal, 18)
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
            Circle()
                .fill(KoeTheme.doneColor)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                )
        case .error:
            Circle()
                .fill(KoeTheme.errorColor)
                .overlay(
                    Text("!")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }

    private var title: String {
        switch state {
        case .recording:    return "Buffer: Active"
        case .transcribing: return "Buffer: Processing"
        case .done:         return "Copied to clipboard"
        case .error:        return "Transcription failed"
        }
    }

    private var subtitle: String {
        switch state {
        case .recording:         return "● REC  — press ⌥Space to stop"
        case .transcribing:      return "◌  Processing audio"
        case .done(let text):    return text
        case .error:             return "Check whisper-cli is installed"
        }
    }

    private var tintColor: Color? {
        switch state {
        case .recording:    return KoeTheme.vermilion
        case .transcribing: return nil
        case .done:         return KoeTheme.doneColor
        case .error:        return KoeTheme.errorColor
        }
    }

    private var tintOpacity: Double {
        switch state {
        case .recording:    return 0.06
        case .transcribing: return 0
        case .done:         return 0.06
        case .error:        return 0.05
        }
    }

    private var borderColor: Color {
        switch state {
        case .recording:    return KoeTheme.vermilion.opacity(0.25)
        case .transcribing: return Color.black.opacity(0.08)
        case .done:         return KoeTheme.doneColor.opacity(0.2)
        case .error:        return KoeTheme.errorColor.opacity(0.15)
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
            guard let self else { return }
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
        let y = max(frame.minY + 60, frame.minY + 20)
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
