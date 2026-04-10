# MASTER_SPEC — Koe

Phased build order for Claude Code. Work phases in order. Never skip ahead.
Each step has: what, why, inputs → outputs, verification method.

---

## Pre-flight (Before Any Code)

Run these manually in Warp before starting Phase 1:

```bash
# 1. Xcode CLI tools
xcode-select --install
swift --version   # must be 5.9+

# 2. whisper.cpp
/usr/local/bin/whisper-cli --version

# 3. Model in place
mkdir -p ~/Library/Application\ Support/Koe
ls ~/Library/Application\ Support/Koe/ggml-base.en.bin

# 4. Create project directory
mkdir -p ~/Developer/Koe
cd ~/Developer/Koe
```

---

## Phase 1 — SPM Scaffold

**Goal:** Valid Swift Package that compiles to a macOS app. No Xcode project file.

### Step 1.1 — Create Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Koe",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Koe",
            path: "Sources/Koe",
            resources: [.process("Resources")]
        )
    ]
)
```

### Step 1.2 — Create directory structure

```bash
mkdir -p Sources/Koe/HUD
mkdir -p Sources/Koe/MainWindow
mkdir -p Sources/Koe/Resources
```

### Step 1.3 — Create Info.plist

`Sources/Koe/Resources/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Koe needs microphone access to record your voice for transcription.</string>
    <key>CFBundleName</key>
    <string>Koe</string>
    <key>CFBundleIdentifier</key>
    <string>com.yourname.koe</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
```

### Step 1.4 — Create minimal KoeApp.swift

Just enough to compile:
```swift
import SwiftUI

@main
struct KoeApp: App {
    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

### Step 1.5 — Verify

```bash
swift build
# Must compile with zero errors
```

---

## Phase 2 — ClipboardManager

**Goal:** Simplest real feature first. Proves the feedback loop works.

### Step 2.1 — Implement ClipboardManager.swift

```swift
import AppKit

enum ClipboardManager {
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
```

**Input:** `String`
**Output:** Text on `NSPasteboard.general`
**Failure mode:** None — NSPasteboard never throws

**Verification:**
- Temporarily call `ClipboardManager.copy("koe test")` in `KoeApp.init`
- `swift run` → open TextEdit → ⌘V → "koe test" should paste
- Remove the test call

---

## Phase 3 — TranscriptStore

**Goal:** Shared history model used by both HUD completion and main window History tab.

### Step 3.1 — Implement TranscriptStore.swift

```swift
import Foundation

struct TranscriptEntry: Identifiable, Codable {
    let id: UUID
    let text: String
    let date: Date
}

class TranscriptStore: ObservableObject {
    static let shared = TranscriptStore()
    private let maxEntries = 20
    private let defaultsKey = "koe.history"

    @Published private(set) var entries: [TranscriptEntry] = []

    private init() { load() }

    func add(_ text: String) {
        let entry = TranscriptEntry(id: UUID(), text: text, date: Date())
        entries.insert(entry, at: 0)
        if entries.count > maxEntries { entries = Array(entries.prefix(maxEntries)) }
        persist()
    }

    func delete(_ entry: TranscriptEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clear() {
        entries = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let saved = try? JSONDecoder().decode([TranscriptEntry].self, from: data)
        else { return }
        entries = saved
    }
}
```

**Verification:**
- Call `TranscriptStore.shared.add("test entry")`
- Confirm `TranscriptStore.shared.entries.count == 1`
- Relaunch app — entry should persist (loaded from UserDefaults)

---

## Phase 4 — HUD Window (State 2)

**Goal:** Floating pill that cycles through all 4 states. No recording yet — hardcoded test states.

### Step 4.1 — HUDState enum

In `HUD/HUDWindow.swift`:
```swift
enum HUDState {
    case recording
    case transcribing
    case done(text: String)
    case error
}
```

### Step 4.2 — WaveformView

5 bars, amber `#C47D3A`, Timer at 0.05s:
- Bar spec: 3pt wide, 2pt corner radius
- Height: `8 + 14 * abs(sin(phase + Double(index) * 0.8))`
- Phase increments 0.3 per tick
- Animation: `.easeInOut(duration: 0.3)` on height changes

### Step 4.3 — HUDView

SwiftUI `View` struct. Layout: `ZStack` (material bg) → `HStack(spacing: 14)` → [28pt icon] + [VStack title/subtitle] + Spacer.

Size: `340 × 72pt`. Corner radius: `22pt`. Padding: `.horizontal, 18`.
Background: `RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial)` + tint overlay.

State mapping:

| State | Icon | Title | Subtitle | Tint |
|---|---|---|---|---|
| `.recording` | `WaveformView` | "Recording…" | "Press ⌥Space to stop" | amber 0.06 |
| `.transcribing` | `ProgressView` indigo | "Transcribing…" | "Processing audio" | none |
| `.done(text)` | moss filled circle + checkmark | "Copied to clipboard" | transcript text (1 line) | moss 0.06 |
| `.error` | terracotta filled circle + ! | "Transcription failed" | "Check whisper-cli" | terracotta 0.05 |

Colors: amber `#C47D3A`, indigo `#4B6BC8`, moss `#508C5A`, terracotta `#B85A3C`

### Step 4.4 — HUDWindow class

`NSWindow` subclass:
```swift
styleMask: [.borderless]
isOpaque = false
backgroundColor = .clear
level = .floating
ignoresMouseEvents = true
collectionBehavior = [.canJoinAllSpaces, .stationary]
```

Position: `x = screen.visibleFrame.midX - 170`, `y = max(screen.visibleFrame.minY + 60, screen.visibleFrame.minY + 20)`

Public API:
```swift
func show(state: HUDState)   // dispatch to main, rebuild NSHostingView, makeKeyAndOrderFront
func hide()                   // dispatch to main, orderOut(nil)
```

**Verification:**
- Call `hud.show(state: .recording)` in `applicationDidFinishLaunching`
- `swift run` — amber waveform pill appears bottom-center
- Cycle through all 4 states manually in code
- Confirm `hud.hide()` removes the window
- Remove test calls

---

## Phase 5 — AudioRecorder

**Goal:** Capture mic to temp `.wav`, return URL on stop.

### Step 5.1 — Implement AudioRecorder.swift

**`start() → Bool`:**
1. Check `AVCaptureDevice.authorizationStatus(for: .audio)`
2. `.notDetermined` → request, then `beginRecording()` in granted completion
3. `.authorized` → `beginRecording()` immediately
4. Denied → return false

**`beginRecording()`:**
1. `AVAudioEngine()` → `inputNode.outputFormat(forBus: 0)` as format
2. Temp URL: `FileManager.default.temporaryDirectory + UUID() + ".wav"`
3. `AVAudioFile(forWriting: url, settings: format.settings)`
4. `inputNode.installTap(onBus: 0, bufferSize: 4096, format: format)` → write buffer
5. `engine.start()`

**`stop(completion: (URL?) → Void)`:**
1. `inputNode.removeTap(onBus: 0)`
2. `engine.stop()`
3. `outputFile = nil` — critical: flushes/closes before URL is valid
4. `completion(tempURL)` then nil out both

**Verification:**
- Start, speak for 5s, stop
- Confirm `.wav` in `/tmp`, open in QuickTime, plays back voice
- Confirm file is removed after `try? FileManager.default.removeItem(at: url)`

---

## Phase 6 — WhisperTranscriber

**Goal:** Subprocess runner. Returns cleaned transcript string.

### Step 6.1 — Implement WhisperTranscriber.swift

Binary resolution (in order):
1. `Bundle.main.url(forResource: "whisper-cli", withExtension: nil)`
2. `/usr/local/bin/whisper-cli`

Model resolution (in order):
1. `Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin")`
2. `~/Library/Application Support/Koe/ggml-base.en.bin`

**`transcribe(audioURL:, completion: (Result<String, Error>) → Void)`:**

Run on `DispatchQueue.global(qos: .userInitiated)`:
1. `Process()` with arguments: `-m modelPath -f audioPath -nt -l auto --no-prints --output-txt`
2. Attach stdout + stderr `Pipe`
3. `process.run()` → `process.waitUntilExit()`
4. Read `.txt` file at `audioURL.deletingPathExtension().appendingPathExtension("txt")`
5. If found: clean text → `completion(.success(cleaned))`; delete `.txt`
6. Fallback: read stdout pipe
7. Both empty → `completion(.failure(TranscriberError.whisperFailed(stderrString)))`

Text cleaning:
```swift
text
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .components(separatedBy: "\n")
    .map { $0.trimmingCharacters(in: .whitespaces) }
    .filter { !$0.isEmpty }
    .joined(separator: " ")
```

**Verification:**
- Pass a test `.wav` from Phase 5
- Confirm transcript prints in console
- Confirm `.txt` temp file deleted after reading

---

## Phase 7 — HotkeyManager

**Goal:** Global ⌥Space hotkey via CGEvent tap. Works in any app.

### Step 7.1 — Implement HotkeyManager.swift

```swift
class HotkeyManager {
    private let onTrigger: () -> Void
    private var eventTap: CFMachPort?

    init(onTrigger: @escaping () -> Void) { self.onTrigger = onTrigger }
```

**`register()`:**
1. `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` — triggers system dialog if needed
2. Create CGEvent tap: `.cgSessionEventTap`, `.headInsertEventTap`, `.defaultTap`, keyDown only
3. Callback (C function pointer — use `Unmanaged.passUnretained(self).toOpaque()` as userInfo):
   - Check `keyCode == 49` (Space) AND `flags.intersection([.maskAlternate, .maskCommand, .maskControl, .maskShift]) == .maskAlternate`
   - Match: call `onTrigger()`, return `nil` (consume event)
   - No match: return `Unmanaged.passUnretained(event)`
4. `CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)`
5. `CGEvent.tapEnable(tap: tap, enable: true)`

**Critical:** Never capture `self` directly in the C callback. Always use `Unmanaged`.

**Verification:**
- Grant Accessibility in System Settings when prompted
- Press ⌥Space → console logs the trigger
- Press Space alone → no trigger, normal typing
- Press ⌘Space → Spotlight opens normally (event not consumed)

---

## Phase 8 — State 2 Orchestration (HUD recording flow)

**Goal:** Full hotkey → record → transcribe → clipboard → HUD flow working end-to-end.

### Step 8.1 — Update KoeApp.swift / AppDelegate

Add `NSApplicationDelegateAdaptor`. Replace minimal KoeApp with full AppDelegate.

**AppDelegate properties:**
```swift
private var statusItem: NSStatusItem!
private var hotkeyManager: HotkeyManager!
private var recorder: AudioRecorder!
private var transcriber: WhisperTranscriber!
private var hud: HUDWindow!
private var isRecording = false
private var isTranscribing = false   // guard against double-tap during transcription
```

**`applicationDidFinishLaunching`:**
1. `NSApp.setActivationPolicy(.accessory)`
2. `setupMenuBar()`
3. Instantiate `recorder`, `transcriber`, `hud`, `TranscriptStore.shared`
4. `HotkeyManager { [weak self] in self?.toggleRecording() }` → `register()`

**`setupMenuBar()`:**
- `NSStatusItem` with `.squareLength`
- Button image: `mic.fill` SF Symbol, template image
- Left-click action: open main window (Phase 9)
- Right-click menu: "Koe" (disabled), "Open Koe…", separator, "Hotkey: ⌥Space" (disabled), separator, "Quit Koe"

**`toggleRecording()`:**
- Dispatch to main
- Guard: if `isTranscribing` → return (ignore hotkey during transcription)
- `isRecording == false` → `startRecording()`
- `isRecording == true` → `stopAndTranscribe()`

**`startRecording()`:**
1. `recorder.start()` → if false, show HUD error + return
2. `isRecording = true`
3. `hud.show(state: .recording)`
4. Menu bar icon: `mic.fill` with amber tint (or `mic.fill.badge.plus`)

**`stopAndTranscribe()`:**
1. `isRecording = false`, `isTranscribing = true`
2. `hud.show(state: .transcribing)`
3. Reset menu bar icon to idle
4. `recorder.stop { audioURL in ... }`
5. `transcriber.transcribe(audioURL:) { result in ... }` (dispatch to main in completion)
6. On `.success(text)`:
   - `ClipboardManager.copy(text)`
   - `TranscriptStore.shared.add(text)`
   - `hud.show(state: .done(text: text))`
   - After 2.0s: `hud.hide()`, `isTranscribing = false`
7. On `.failure`:
   - `hud.show(state: .error)`
   - After 1.5s: `hud.hide()`, `isTranscribing = false`
8. Always: `try? FileManager.default.removeItem(at: audioURL)`

**Verification (State 2 end-to-end):**
- [ ] ⌥Space → amber waveform HUD appears
- [ ] Speak 5–10 seconds
- [ ] ⌥Space → "Transcribing…" HUD
- [ ] "Copied" HUD with text preview
- [ ] ⌘V in any app → correct text
- [ ] HUD dismisses after 2s
- [ ] No temp files in `/tmp`
- [ ] App not in Dock

---

## Phase 9 — State 3 Main Window

**Goal:** Real app window with three tabs, opened via menu bar or Spotlight.

### Step 9.1 — MainWindowController.swift

```swift
class MainWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Koe"
        window.minSize = NSSize(width: 480, height: 400)
        window.center()
        self.init(window: window)
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

`windowShouldClose` → return `false`, call `window?.orderOut(nil)` instead. Never deallocate.

AppDelegate holds: `private var mainWindowController: MainWindowController!` — instantiate in `applicationDidFinishLaunching`.

### Step 9.2 — MainView.swift

Root SwiftUI view injected as `NSHostingView` into the window:

```swift
struct MainView: View {
    @StateObject private var store = TranscriptStore.shared

    var body: some View {
        TabView {
            RecordTab()
                .tabItem { Label("Record", systemImage: "mic.fill") }
            HistoryTab()
                .tabItem { Label("History", systemImage: "clock") }
            SettingsTab()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
```

### Step 9.3 — RecordTab.swift

State machine: `.idle`, `.recording`, `.transcribing`, `.done(text:)`, `.error`

Layout (centered vertically and horizontally):
- Large mic button — 80pt circle, amber background, `mic.fill` SF Symbol 32pt white
- While recording: `WaveformView` replaces icon (reuse the same component from HUD)
- Status label below button: reflects current state
- Does NOT show the floating HUD — all feedback is inline

Recording flow: same logic as State 2 but calls `recorder`/`transcriber` directly.
On success: `ClipboardManager.copy(text)` + `TranscriptStore.shared.add(text)`.

### Step 9.4 — HistoryTab.swift

```swift
struct HistoryTab: View {
    @ObservedObject var store = TranscriptStore.shared

    var body: some View {
        List {
            ForEach(store.entries) { entry in
                HistoryRow(entry: entry)
                    .onTapGesture { ClipboardManager.copy(entry.text) }
            }
            .onDelete { indexSet in
                indexSet.forEach { store.delete(store.entries[$0]) }
            }
        }
        .overlay {
            if store.entries.isEmpty {
                EmptyHistoryView()
            }
        }
    }
}
```

`HistoryRow`: transcript text (`.lineLimit(2)`) + relative date in muted monospace.
`EmptyHistoryView`: centered text, muted, "No transcripts yet.\nPress ⌥Space anywhere to start."

### Step 9.5 — SettingsTab.swift

```swift
struct SettingsTab: View {
    @AppStorage("koe.launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Hotkey") {
                LabeledContent("Trigger") {
                    Text("⌥ Space")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Section("Transcription") {
                LabeledContent("Model") {
                    Text("base.en")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        // SMAppService.mainApp.register/unregister
                    }
            }
            Section("About") {
                LabeledContent("Version", value: "1.0")
            }
        }
        .formStyle(.grouped)
    }
}
```

**Verification (State 3):**
- [ ] Menu bar click → window opens centered on screen
- [ ] Spotlight "Koe" → window opens
- [ ] Record tab: mic button works, inline waveform shows, transcript added to History
- [ ] History tab: new entry appears after recording, tap copies, swipe deletes
- [ ] Settings tab: renders without error, launch at login toggle visible
- [ ] Closing window: app stays alive, menu bar icon remains, ⌥Space still works

---

## Phase 10 — Polish & Edge Cases

### Step 10.1 — Rapid hotkey guard
`isTranscribing` flag in AppDelegate already blocks this. Verify it works: tap ⌥Space rapidly during transcription — only first press fires.

### Step 10.2 — Very short recordings
If `.wav` file < 8KB, whisper.cpp may return empty. Detect in transcriber — empty cleaned string → treat as `.failure`.

### Step 10.3 — Mic permission denied flow
If `recorder.start()` returns false:
- In State 2: show HUD `.error` briefly
- In State 3 RecordTab: show inline error message with link to System Settings

### Step 10.4 — Screen edge safety
Already handled by clamping HUD y position. Also handle: if `NSScreen.main` is nil (very rare), log and abort HUD show.

### Step 10.5 — Window restore on relaunch
When app relaunches, main window should NOT auto-open — user opens it intentionally. `isRestorable = false` on the window.

---

## Phase 11 — Distribution Prep (Optional v1.0)

### Step 11.1 — Bundle whisper-cli
Add to `Sources/Koe/Resources/`. SPM `.process("Resources")` will copy it into the bundle.
Confirm `WhisperTranscriber` checks `Bundle.main` first (already does).

### Step 11.2 — Bundle model
Add `ggml-base.en.bin` to `Sources/Koe/Resources/`. Warning: ~150MB. Consider first-launch download instead.

### Step 11.3 — Create .app bundle manually
SPM builds a binary, not a `.app` bundle with Info.plist by default. Use a Makefile:
```makefile
build:
	swift build -c release

bundle:
	mkdir -p Koe.app/Contents/MacOS
	mkdir -p Koe.app/Contents/Resources
	cp .build/release/Koe Koe.app/Contents/MacOS/Koe
	cp Sources/Koe/Resources/Info.plist Koe.app/Contents/Info.plist

run: build bundle
	open Koe.app
```

### Step 11.4 — Notarization
Requires Xcode `xcodebuild` archive or manual `codesign` + `xcrun notarytool`.

---

## Build Order Summary

```
Phase 1   Scaffold — Package.swift, Info.plist, directory structure
Phase 2   ClipboardManager — simplest piece, verifiable immediately
Phase 3   TranscriptStore — shared history model
Phase 4   HUD Window — State 2 visual shell, all 4 states, no recording yet
Phase 5   AudioRecorder — mic capture to .wav
Phase 6   WhisperTranscriber — subprocess, returns cleaned text
Phase 7   HotkeyManager — global ⌥Space
Phase 8   State 2 orchestration — full HUD recording flow end-to-end
Phase 9   State 3 main window — three tabs (Record, History, Settings)
Phase 10  Polish — edge cases, guards, error flows
Phase 11  Distribution prep (optional)
```

Never start Phase N+1 until Phase N verification passes.

---

## Known Gotchas

| Gotcha | Detail |
|---|---|
| CGEvent tap C callback | Never capture `self`. Use `Unmanaged.passUnretained(self).toOpaque()` as userInfo. |
| AVAudioFile flush | Must set `outputFile = nil` before the file URL is safe to read. |
| whisper-cli --output-txt | Writes `.txt` next to input `.wav`, not to stdout. Check for file first. |
| NSWindow on background thread | Any `makeKeyAndOrderFront` / `orderOut` must dispatch to main. |
| LSUIElement + SwiftUI @main | Use `NSApplicationDelegateAdaptor` + `NSApp.setActivationPolicy(.accessory)` in delegate. |
| Event tap run loop | `CFRunLoopAddSource` must be called on the main run loop — use `CFRunLoopGetCurrent()` from main thread. |
| SPM + Info.plist | Use `.process("Resources")` in Package.swift so Info.plist lands in the bundle. |
| MainWindowController lifetime | Must be held as a strong reference in AppDelegate. If weak/local, window deallocates when it closes. |
| RecordTab recorder ownership | RecordTab needs access to the shared `AudioRecorder` instance. Inject from AppDelegate via environment or pass as `@ObservedObject`. |
