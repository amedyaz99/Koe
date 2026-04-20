# Auto-Paste to Active Field — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After transcription, automatically paste the result into the app that was active when the user triggered the hotkey, with a Settings toggle to enable/disable.

**Architecture:** Four files touched. `PasteManager` posts a ⌘V `CGEvent` directly to a target PID using `postToPid()` — no focus stealing. `AppState` captures the frontmost app at recording start and calls `PasteManager` after clipboard copy. `HUDWindow` gains a `.pasted` state (visually identical to `.done`, different label). `SettingsTab` gets a toggle persisted to `UserDefaults`.

**Tech Stack:** Swift 5.9+, AppKit (`NSWorkspace`, `CGEvent`), SwiftUI (`@AppStorage`)

---

### Task 1: Create PasteManager done

**Files:**
- Create: `Sources/Koe/PasteManager.swift
- [ ] **Step 1: Create the file**

```swift
import AppKit
import CoreGraphics

enum PasteManager {
    static func paste(to app: NSRunningApplication) {
        let pid = app.processIdentifier
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        up?.flags = .maskCommand
        down?.postToPid(pid)
        up?.postToPid(pid)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
cd /Users/imad/Documents/Koe && swift build 2>&1
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/Koe/PasteManager.swift
git commit -m "Add PasteManager: post cmd+V CGEvent to target PID"
```

---
enod 
### Task 2: Add `.pasted` state to HUDWindow done

**Files:**
- Modify: `Sources/Koe/HUD/HUDWindow.swift`

The current `HUDState` enum is:
```swift
enum HUDState: Equatable {
    case recording
    case transcribing
    case done(text: String)
    case error
}
```

There are four switch statements in `HUDView` that need updating: `leadingView`, `trailingView`, `glowColor`, and the `RecordingGlowModifier` initializer call.

- [ ] **Step 1: Add `.pasted(text: String)` to the enum**

Find:
```swift
enum HUDState: Equatable {
    case recording
    case transcribing
    case done(text: String)
    case error
}
```

Replace with:
```swift
enum HUDState: Equatable {
    case recording
    case transcribing
    case done(text: String)
    case pasted(text: String)
    case error
}
```

- [ ] **Step 2: Handle `.pasted` in `leadingView`**

Find:
```swift
case .done:
    Text("✓")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color(red: 0.235, green: 0.722, blue: 0.353))
        .transition(.scale.combined(with: .opacity))
case .error:
```

Replace with:
```swift
case .done, .pasted:
    Text("✓")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color(red: 0.235, green: 0.722, blue: 0.353))
        .transition(.scale.combined(with: .opacity))
case .error:
```

- [ ] **Step 3: Handle `.pasted` in `trailingView`**

Find:
```swift
case .done:
    Text("copied")
        .font(.system(size: 11, weight: .regular, design: .monospaced))
        .foregroundStyle(Color.white)
case .error:
```

Replace with:
```swift
case .done:
    Text("copied")
        .font(.system(size: 11, weight: .regular, design: .monospaced))
        .foregroundStyle(Color.white)
case .pasted:
    Text("pasted")
        .font(.system(size: 11, weight: .regular, design: .monospaced))
        .foregroundStyle(Color.white)
case .error:
```

- [ ] **Step 4: Handle `.pasted` in `glowColor`**

Find:
```swift
case .done:         return Color(red: 0.235, green: 0.722, blue: 0.353)
case .error:        return Color(red: 0.863, green: 0.2, blue: 0.2)
```

Replace with:
```swift
case .done, .pasted: return Color(red: 0.235, green: 0.722, blue: 0.353)
case .error:         return Color(red: 0.863, green: 0.2, blue: 0.2)
```

- [ ] **Step 5: Build to verify no missing cases**

```bash
cd /Users/imad/Documents/Koe && swift build 2>&1
```

Expected: `Build complete!` with no warnings about non-exhaustive switches.

- [ ] **Step 6: Commit**

```bash
git add Sources/Koe/HUD/HUDWindow.swift
git commit -m "Add .pasted HUD state: green check + 'pasted' label"
```

---

### Task 3: Wire auto-paste into AppState done

**Files:**
- Modify: `Sources/Koe/AppState.swift`

Current `AppState` has `private var recorder`, `transcriber`, `hud`, `hotkeyManager`. The `startRecording()` and transcription success branch need updating.

- [ ] **Step 1: Add the toggle and frontmost app storage**

Find the private properties block:
```swift
private var recorder: AudioRecorder
private var transcriber: WhisperTranscriber
private var hud: HUDWindow
private var hotkeyManager: HotkeyManager!
```

Replace with:
```swift
private var recorder: AudioRecorder
private var transcriber: WhisperTranscriber
private var hud: HUDWindow
private var hotkeyManager: HotkeyManager!

@AppStorage("koe.autoPaste") private var autoPasteEnabled = true
private var frontmostAppAtRecordStart: NSRunningApplication?
```

- [ ] **Step 2: Capture frontmost app at recording start**

Find the beginning of `startRecording()`:
```swift
private func startRecording() {
    recorder.start { [weak self] granted in
```

Replace with:
```swift
private func startRecording() {
    frontmostAppAtRecordStart = NSWorkspace.shared.frontmostApplication
    recorder.start { [weak self] granted in
```

- [ ] **Step 3: Use PasteManager in the transcription success branch**

Find:
```swift
case .success(let text):
    ClipboardManager.copy(text)
    TranscriptStore.shared.add(text)
    self.lastTranscript = text
    self.hud.show(state: .done(text: text))
    self.scheduleHUDHide(after: 2.0)
```

Replace with:
```swift
case .success(let text):
    ClipboardManager.copy(text)
    TranscriptStore.shared.add(text)
    self.lastTranscript = text
    if self.autoPasteEnabled, let app = self.frontmostAppAtRecordStart {
        PasteManager.paste(to: app)
        self.hud.show(state: .pasted(text: text))
    } else {
        self.hud.show(state: .done(text: text))
    }
    self.frontmostAppAtRecordStart = nil
    self.scheduleHUDHide(after: 2.0)
```

- [ ] **Step 4: Clear frontmostApp on failure too**

Find:
```swift
private func failTranscription() {
    hud.show(state: .error)
    scheduleHUDHide(after: 1.5)
}
```

Replace with:
```swift
private func failTranscription() {
    frontmostAppAtRecordStart = nil
    hud.show(state: .error)
    scheduleHUDHide(after: 1.5)
}
```

- [ ] **Step 5: Build**

```bash
cd /Users/imad/Documents/Koe && swift build 2>&1
```

Expected: `Build complete!`

- [ ] **Step 6: Commit**

```bash
git add Sources/Koe/AppState.swift
git commit -m "Wire auto-paste: capture frontmost app at hotkey, paste after transcription"
```

---

### Task 4: Add toggle to Settings tab

**Files:**
- Modify: `Sources/Koe/MainWindow/SettingsTab.swift`

- [ ] **Step 1: Add `@AppStorage` binding at the top of `SettingsTab`**

Find:
```swift
struct SettingsTab: View {
    @AppStorage("koe.launchAtLogin") private var launchAtLogin = false
```

Replace with:
```swift
struct SettingsTab: View {
    @AppStorage("koe.launchAtLogin") private var launchAtLogin = false
    @AppStorage("koe.autoPaste") private var autoPasteEnabled = true
```

- [ ] **Step 2: Add the toggle row inside the System section**

Find the launch-at-login `HStack` inside the System `settingsSection`:
```swift
HStack {
    Text("Launch at login")
        .font(KoeTheme.monoSmall)
        .foregroundColor(KoeTheme.washiPaper)
    
    Spacer()
    
    Toggle("", isOn: $launchAtLogin)
        .toggleStyle(.switch)
        .tint(KoeTheme.vermilion)
}
```

Replace with:
```swift
HStack {
    Text("Launch at login")
        .font(KoeTheme.monoSmall)
        .foregroundColor(KoeTheme.washiPaper)
    
    Spacer()
    
    Toggle("", isOn: $launchAtLogin)
        .toggleStyle(.switch)
        .tint(KoeTheme.vermilion)
}

Divider()
    .background(KoeTheme.washiMuted.opacity(0.15))

HStack(alignment: .top) {
    VStack(alignment: .leading, spacing: 3) {
        Text("Auto-paste")
            .font(KoeTheme.monoSmall)
            .foregroundColor(KoeTheme.washiPaper)
        Text("Paste into active field after transcription")
            .font(KoeTheme.monoTiny)
            .foregroundColor(KoeTheme.washiMuted)
    }
    Spacer()
    Toggle("", isOn: $autoPasteEnabled)
        .toggleStyle(.switch)
        .tint(KoeTheme.vermilion)
}
```

- [ ] **Step 3: Build**

```bash
cd /Users/imad/Documents/Koe && swift build 2>&1
```

Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/Koe/MainWindow/SettingsTab.swift
git commit -m "Add auto-paste toggle to Settings — System section"
```

---

### Task 5: Manual verification

- [ ] **Step 1: Run the app**

```bash
cd /Users/imad/Documents/Koe && swift run &
```

- [ ] **Step 2: Test auto-paste ON (default)**

  - Open TextEdit or Notes, click into a text field
  - Press ⌥K, speak a sentence, press ⌥K again
  - Verify: text appears directly in the field without pressing ⌘V
  - Verify: HUD shows `✓ pasted` (green glow)

- [ ] **Step 3: Test auto-paste OFF**

  - Open Settings → System → toggle "Auto-paste" off
  - Press ⌥K in the same text field, speak, press ⌥K again
  - Verify: text does NOT auto-paste — HUD shows `✓ copied`
  - Verify: manually pressing ⌘V pastes the text (clipboard still populated)

- [ ] **(Step 4: Test app-switch edge case**

  - Focus TextEdit, press ⌥K to start recording
  - Switch to a different app during recording
  - Press ⌥K to stop
  - Verify: text pastes into TextEdit (the app active at hotkey press), not the app you switched to
)
- [ ] **Step 5: Kill the app**

```bash
pkill -f "Koe"
```
