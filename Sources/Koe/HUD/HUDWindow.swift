import AppKit
import SwiftUI

// MARK: - State

enum HUDState: Equatable {
    case recording
    case transcribing
    case done(text: String)
    case pasted(text: String)
    case error
}

// MARK: - State Holder

class HUDStateHolder: ObservableObject {
    @Published var hudState: HUDState = .recording
}

// MARK: - HUD View

struct HUDView: View {
    @ObservedObject var holder: HUDStateHolder

    var body: some View {
        ZStack {
            Color.clear // fills the 300x44 window transparently
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.black)

                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(glowColor, lineWidth: 2)

                HStack(spacing: 10) {
                    leadingView
                    trailingView
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .fixedSize()
        }
    }

    @ViewBuilder
    private var leadingView: some View {
        switch holder.hudState {
        case .recording:
            BlinkingDot()
        case .transcribing:
            BouncingDots()
        case .done, .pasted:
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
        switch holder.hudState {
        case .recording:
            CompactWaveformView()
        case .transcribing:
            Text("processing")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white)
        case .done:
            Text("copied")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white)
        case .pasted:
            Text("pasted")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white)
        case .error:
            Text("error")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white)
        }
    }

    private var glowColor: Color {
        switch holder.hudState {
        case .recording:    return Color(red: 0.863, green: 0.2, blue: 0.2)
        case .transcribing: return Color(red: 0.392, green: 0.471, blue: 0.878)
        case .done, .pasted: return Color(red: 0.235, green: 0.722, blue: 0.353)
        case .error:        return Color(red: 0.863, green: 0.2, blue: 0.2)
        }
    }
}

struct BlinkingDot: View {
    @State private var visible = true

    var body: some View {
        Circle()
            .fill(Color(red: 1.0, green: 0.18, blue: 0.18))
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
                    .fill(Color(red: 1.0, green: 0.58, blue: 0.0))
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

// MARK: - HUD Window

class HUDWindow: NSWindow {
    private let stateHolder = HUDStateHolder()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 44),
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
        contentView = NSHostingView(rootView: HUDView(holder: stateHolder))
    }

    func show(state: HUDState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                self.stateHolder.hudState = state
            }
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
        let x = frame.midX - 150  // center the 300pt window
        let y = frame.minY + 60
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
