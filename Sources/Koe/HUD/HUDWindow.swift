import AppKit
import SwiftUI

// MARK: - State

enum HUDState {
    case recording
    case transcribing
    case done(text: String)
    case error
}

// MARK: - Waveform

struct WaveformView: View {
    var barWidth: CGFloat = 3
    var minHeight: CGFloat = 8
    var maxHeight: CGFloat = 22
    var color: Color = Color(hex: "#C47D3A")

    @State private var phase: Double = 0
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(
                        width: barWidth,
                        height: minHeight + (maxHeight - minHeight) * abs(sin(phase + Double(i) * 0.8))
                    )
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .onReceive(timer) { _ in
            phase += 0.3
        }
    }
}

// MARK: - HUD View

struct HUDView: View {
    let state: HUDState

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)

            // Tint overlay
            if let tint = tintColor {
                RoundedRectangle(cornerRadius: 22)
                    .fill(tint.opacity(tintOpacity))
            }

            // Border
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(borderColor, lineWidth: 0.5)

            // Content
            HStack(spacing: 14) {
                iconView
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
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
            WaveformView()
                .frame(width: 28)
        case .transcribing:
            ProgressView()
                .scaleEffect(0.8)
                .tint(Color(hex: "#4B6BC8"))
        case .done:
            Circle()
                .fill(Color(hex: "#508C5A"))
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                )
        case .error:
            Circle()
                .fill(Color(hex: "#B85A3C"))
                .overlay(
                    Text("!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }

    private var title: String {
        switch state {
        case .recording:    return "Recording…"
        case .transcribing: return "Transcribing…"
        case .done:         return "Copied to clipboard"
        case .error:        return "Transcription failed"
        }
    }

    private var subtitle: String {
        switch state {
        case .recording:         return "Press ⌥Space to stop"
        case .transcribing:      return "Processing audio"
        case .done(let text):    return text
        case .error:             return "Check whisper-cli is installed"
        }
    }

    private var tintColor: Color? {
        switch state {
        case .recording:    return Color(hex: "#C47D3A")
        case .transcribing: return nil
        case .done:         return Color(hex: "#508C5A")
        case .error:        return Color(hex: "#B85A3C")
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
        case .recording:    return Color(hex: "#C47D3A").opacity(0.2)
        case .transcribing: return Color.black.opacity(0.08)
        case .done:         return Color(hex: "#508C5A").opacity(0.2)
        case .error:        return Color(hex: "#B85A3C").opacity(0.15)
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

// MARK: - Color hex helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
