# HUD Compact Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current 340×72pt frosted-glass HUD pill with a compact 210×34pt dark pill that uses animation and glow instead of size to grab attention.

**Architecture:** All changes are contained in `HUDWindow.swift`. The `HUDState` enum, window flags, dismiss timing, and audio pipeline are untouched. Only `HUDView`, the window's `contentRect`, and `position()` change.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (`NSWindow`)

---

### Task 1: Replace HUDView with compact dark layout

**Files:**
- Modify: `Sources/Koe/HUD/HUDWindow.swift`

- [ ] **Step 1: Replace the entire `HUDView` struct** with the new implementation below. Keep everything outside `HUDView` (the `HUDState` enum, `HUDWindow` class) untouched for now.

```swift
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
```

- [ ] **Step 2: Add the `BlinkingDot` view** immediately after the closing brace of `HUDView`:

```swift
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
```

- [ ] **Step 3: Add `BouncingDots`** after `BlinkingDot`:

```swift
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
```

- [ ] **Step 4: Add `CompactWaveformView`** after `BouncingDots`:

```swift
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
```

- [ ] **Step 5: Add `RecordingGlowModifier`** after `CompactWaveformView`:

```swift
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
```

- [ ] **Step 6: Build and verify it compiles**

```bash
cd /Users/imad/Documents/Koe && swift build 2>&1
```

Expected: `Build complete!` with no errors.

- [ ] **Step 7: Commit**

```bash
git add Sources/Koe/HUD/HUDWindow.swift
git commit -m "Redesign HUD pill: compact dark layout with animated waveform and glow"
```

---

### Task 2: Update window size and position

**Files:**
- Modify: `Sources/Koe/HUD/HUDWindow.swift` — `HUDWindow.init()` and `position()`

- [ ] **Step 1: Update `contentRect` in `HUDWindow.init()`**

Find:
```swift
contentRect: NSRect(x: 0, y: 0, width: 340, height: 72),
```
Replace with:
```swift
contentRect: NSRect(x: 0, y: 0, width: 210, height: 34),
```

- [ ] **Step 2: Replace `position()`**

Find:
```swift
private func position() {
    guard let screen = NSScreen.main else { return }
    let frame = screen.visibleFrame
    let x = frame.midX - 170
    let y = max(frame.minY + 60, frame.minY + 20)
    setFrameOrigin(NSPoint(x: x, y: y))
}
```
Replace with:
```swift
private func position() {
    guard let screen = NSScreen.main else { return }
    let frame = screen.visibleFrame
    let x = frame.maxX - 210 - 16
    let y = frame.maxY - 34 - 16
    setFrameOrigin(NSPoint(x: x, y: y))
}
```

- [ ] **Step 3: Build and verify**

```bash
cd /Users/imad/Documents/Koe && swift build 2>&1
```

Expected: `Build complete!`

- [ ] **Step 4: Remove old `WaveformView` if it's only used by HUD**

Check whether `WaveformView` is still referenced anywhere (it may be used in `RecordTab`):

```bash
grep -r "WaveformView" /Users/imad/Documents/Koe/Sources/
```

If the only result is inside `RecordTab.swift`, leave it alone. If `HUDWindow.swift` still references it, remove that reference. Do not delete the struct itself.

- [ ] **Step 5: Commit**

```bash
git add Sources/Koe/HUD/HUDWindow.swift
git commit -m "Move HUD pill to top-right, shrink to 210x34pt"
```

---

### Task 3: Visual verification

- [ ] **Step 1: Run the app**

```bash
cd /Users/imad/Documents/Koe && swift run &
```

- [ ] **Step 2: Trigger the HUD** with ⌥Space and verify:
  - Pill appears top-right, just below the clock
  - Dark background, no frosted glass
  - Blinking red dot visible on left
  - Amber waveform bars animating on right
  - Red glow pulses around the pill

- [ ] **Step 3: Let it finish transcribing** and verify:
  - Transcribing: 3 bouncing indigo dots + `processing` label
  - Done: `✓` + `copied` label with green glow
  - Auto-dismisses after 2s

- [ ] **Step 4: Kill the app when done**

```bash
pkill -f "Koe"
```
