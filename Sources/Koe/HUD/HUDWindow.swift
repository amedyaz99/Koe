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
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color(red: 0.067, green: 0.067, blue: 0.067))

            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(glowColor.opacity(0.35), lineWidth: 1)

            HStack(spacing: 10) {
                leadingView
                trailingView
            }
            .padding(.horizontal, 14)
        }
        .frame(width: 210, height: 34)
        .shadow(color: glowColor.opacity(glowOpacity), radius: glowRadius)
        .modifier(RecordingGlowModifier(isRecording: {
            if case .recording = state { return true }
            return false
        }()))
    }

    @ViewBuilder
    private var leadingView: some View {
        switch state {
        case .recording:
            BlinkingDot()
        case .transcribing:
            BouncingDots()
        case .done:
            Text("✓")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.235, green: 0.722, blue: 0.353))
                .transition(.scale.combined(with: .opacity))
        case .error:
            Text("✗")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.91, green: 0.2, blue: 0.2))
        }
    }

    @ViewBuilder
    private var trailingView: some View {
        switch state {
        case .recording:
            CompactWaveformView()
        case .transcribing:
            Text("processing")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35))
        case .done:
            Text("copied")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.6))
        case .error:
            Text("error")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.6))
        }
    }

    private var glowColor: Color {
        switch state {
        case .recording:    return Color(red: 0.863, green: 0.2, blue: 0.2)
        case .transcribing: return Color(red: 0.392, green: 0.471, blue: 0.878)
        case .done:         return Color(red: 0.235, green: 0.722, blue: 0.353)
        case .error:        return Color(red: 0.863, green: 0.2, blue: 0.2)
        }
    }

    private var glowOpacity: Double {
        switch state {
        case .recording:    return 0   // handled by RecordingGlowModifier
        case .transcribing: return 0.3
        case .done:         return 0.3
        case .error:        return 0.3
        }
    }

    private var glowRadius: CGFloat {
        switch state {
        case .recording:    return 0
        case .transcribing: return 10
        case .done:         return 10
        case .error:        return 10
        }
    }
}

struct BlinkingDot: View {
    @State private var visible = true

    var body: some View {
        Circle()
            .fill(Color(red: 0.91, green: 0.2, blue: 0.2))
            .frame(width: 7, height: 7)
            .opacity(visible ? 1 : 0.15)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    visible.toggle()
                }
            }
    }
}

struct BouncingDots: View {
    @State private var activeIndex = 0
    private let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(red: 0.482, green: 0.561, blue: 0.878))
                    .frame(width: 5, height: 5)
                    .opacity(activeIndex == i ? 0.9 : 0.2)
                    .animation(.easeInOut(duration: 0.2), value: activeIndex)
            }
        }
        .onReceive(timer) { _ in
            activeIndex = (activeIndex + 1) % 3
        }
    }
}

struct CompactWaveformView: View {
    private let barCount = 12
    private let delays: [Double] = [0, 0.06, 0.12, 0.18, 0.24, 0.30, 0.36, 0.42, 0.48, 0.54, 0.60, 0.66]
    private let maxHeights: [CGFloat] = [5, 13, 20, 9, 16, 7, 18, 11, 15, 6, 19, 8]

    @State private var animate = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(red: 0.91, green: 0.627, blue: 0.125))
                    .frame(width: 2.5, height: animate ? maxHeights[i] : maxHeights[i] * 0.3)
                    .animation(
                        .easeInOut(duration: 0.48)
                        .repeatForever(autoreverses: true)
                        .delay(delays[i]),
                        value: animate
                    )
            }
        }
        .frame(height: 20)
        .onAppear { animate = true }
    }
}

// HUD is recreated fresh per state, so onAppear is sufficient — no onChange needed
struct RecordingGlowModifier: ViewModifier {
    let isRecording: Bool
    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color: isRecording
                    ? Color(red: 0.863, green: 0.2, blue: 0.2).opacity(glowing ? 0.55 : 0.3)
                    : .clear,
                radius: glowing ? 14 : 8
            )
            .onAppear {
                guard isRecording else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    glowing = true
                }
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
