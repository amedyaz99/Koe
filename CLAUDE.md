# CLAUDE.md — Koe

Project-local instructions for Claude Code. Read this entire file before touching anything.

---

## What This Project Is

**Koe** (声, Japanese for "voice") is a macOS menu bar app that records voice on a global hotkey, transcribes locally using whisper.cpp, and copies the result to clipboard. No network calls. No cloud. Primarily lives in the menu bar.

The app has **three states**:

| State | What it is |
|---|---|
| **1 — Menu bar** | App is running but invisible. Just a mic icon in the menu bar. Default idle state. |
| **2 — HUD** | Triggered by ⌥Space hotkey. Floating pill at bottom of screen — waveform → transcribing → copied. Auto-dismisses. |
| **3 — Main window** | Opened by clicking the menu bar icon or via Spotlight. Real app window with three tabs: Record, History, Settings. |

See `MASTER_SPEC.md` for the full phased build order.
See `PRD.md` for product requirements and non-goals.
See `DESIGN.md` for all visual specs — colors, type, spacing, HUD dimensions.

---

## Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+, strict concurrency warnings enabled |
| UI | SwiftUI — HUD (State 2) + Main window (State 3) |
| Audio | AVAudioEngine |
| Transcription | whisper.cpp binary subprocess |
| Clipboard | NSPasteboard |
| Hotkey | CGEvent tap (Carbon) |
| Persistence | UserDefaults — settings + transcript history (max 20 entries) |
| App style | LSUIElement = YES — menu bar primary, main window on demand |
| Min target | macOS 13.0 (Ventura) |
| Build tool | Swift Package Manager — no Xcode GUI required |
| Editor | VS Code + Warp terminal |

---

## Project File Structure

```
Koe/
├── Package.swift
├── Sources/
│   └── Koe/
│       ├── KoeApp.swift                     # @main, AppDelegate, orchestration
│       ├── HotkeyManager.swift              # CGEvent tap, ⌥Space global hotkey
│       ├── AudioRecorder.swift              # AVAudioEngine → temp .wav
│       ├── WhisperTranscriber.swift         # whisper-cli subprocess runner
│       ├── ClipboardManager.swift           # NSPasteboard write
│       ├── TranscriptStore.swift            # In-memory + UserDefaults history
│       ├── HUD/
│       │   └── HUDWindow.swift              # State 2 — floating pill + SwiftUI view
│       ├── MainWindow/
│       │   ├── MainWindowController.swift   # NSWindowController for State 3
│       │   ├── MainView.swift               # Root TabView
│       │   ├── RecordTab.swift              # Tab 1 — mic button + inline waveform
│       │   ├── HistoryTab.swift             # Tab 2 — transcript list
│       │   └── SettingsTab.swift            # Tab 3 — hotkey, model, launch at login
│       └── Resources/
│           └── Info.plist
├── PRD.md
├── MASTER_SPEC.md
├── DESIGN.md
└── CLAUDE.md  ← you are here
```

---

## App State Model

```
State 1: Menu bar idle
  ├── ⌥Space pressed anywhere → State 2 (HUD recording flow)
  └── Menu bar icon clicked   → State 3 (Main window opens)

State 2: HUD active
  ├── recording → transcribing → done (auto-dismiss 2s) → State 1
  └── error (auto-dismiss 1.5s) → State 1

State 3: Main window open
  ├── Tab 1 — Record: mic button triggers same recording flow as State 2
  │     but waveform is inline in the window (no floating HUD)
  ├── Tab 2 — History: list of last 20 transcripts, tap to copy
  └── Tab 3 — Settings: hotkey display, model name, launch at login toggle
```

State 2 and State 3 can coexist — hotkey works while window is open.
Closing State 3 window does NOT quit the app — hides window, State 1 resumes.

---

## Coding Conventions

### General
- One responsibility per file. No cross-contamination.
- No force unwraps (`!`) except `Bundle.main` guaranteed values.
- No `DispatchQueue.main.sync` — always `.async`.
- All UI updates must be on main thread.
- Errors always surface to user. Never silently swallow.

### Swift specifics
- `[weak self]` in all closures with async dispatch.
- `guard let` over `if let` for early exits.
- All `Process` calls on `DispatchQueue.global(qos: .userInitiated)`.
- `AVAudioFile` for recording — never raw buffer writes to disk.

### Naming conventions
- HUD state enum: `HUDState` with cases `.recording`, `.transcribing`, `.done(text:)`, `.error`
- Transcript model: `TranscriptEntry` — `struct { id: UUID, text: String, date: Date }`
- All managers are classes (reference semantics for callbacks + lifetime)
- SwiftUI views are structs: `RecordTab`, `HistoryTab`, `SettingsTab`, `MainView`
- `MainWindowController` owns the `NSWindow` for State 3

---

## Permissions

Three macOS permissions. Never bypass or fake any of them.

### Microphone
- `AVCaptureDevice.requestAccess(for: .audio)`
- `Info.plist` must have `NSMicrophoneUsageDescription`
- If denied: HUD `.error` state + inline error in RecordTab

### Accessibility (for global hotkey)
- `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt: true`
- macOS shows its own system dialog — do not build custom UI
- If not trusted: log warning, hotkey silently fails

### Launch at login (optional, Settings tab)
- `SMAppService.mainApp.register()` — macOS 13+ only
- Only called if user enables toggle in SettingsTab

---

## whisper.cpp Integration

### Binary path (checked in order)
1. `Bundle.main.url(forResource: "whisper-cli", withExtension: nil)`
2. `/usr/local/bin/whisper-cli`

### Model path (checked in order)
1. `Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin")`
2. `~/Library/Application Support/Koe/ggml-base.en.bin`

### Subprocess arguments
```swift
process.arguments = [
    "-m", modelURL.path,
    "-f", audioURL.path,
    "-nt",           // no timestamps
    "-l", "auto",    // auto language detection
    "--no-prints",   // suppress progress bars
    "--output-txt",  // writes .txt next to input file
]
```

### Output parsing
- Read `.txt` file written next to `.wav` after `process.waitUntilExit()`
- Clean: trim whitespace, collapse newlines, filter empty lines, join with space
- Delete both `.wav` and `.txt` temp files after reading
- Empty result after cleaning → treat as error, not empty success

---

## HUD Design (State 2)

Full visual spec in `DESIGN.md`. Implementation summary:

- Window: borderless, `isOpaque = false`, `backgroundColor = .clear`, `level = .floating`, `ignoresMouseEvents = true`, `collectionBehavior = [.canJoinAllSpaces, .stationary]`
- Size: **340 × 72pt**, cornerRadius **22pt**
- Position: bottom-center of main screen, 60pt above Dock. Clamp min-y to `visibleFrame.minY + 20`
- Background: `.ultraThinMaterial` + per-state tint overlay
- Waveform: 5 bars, 3pt wide, amber `#C47D3A`, Timer at 0.05s interval
- State colors: amber (recording), indigo `#4B6BC8` (transcribing), moss `#508C5A` (done), terracotta `#B85A3C` (error)
- Auto-dismiss: 2.0s after done, 1.5s after error

---

## Main Window Design (State 3)

Standard macOS window. Opened by menu bar icon click or Spotlight.

### Window properties
```swift
styleMask: [.titled, .closable, .miniaturizable, .resizable]
title: "Koe"
minSize: NSSize(width: 480, height: 400)
defaultSize: NSSize(width: 520, height: 500)
```

Closing the window: hide it (`orderOut(nil)`), do not deallocate, do not quit app.
`MainWindowController` must be held as a strong reference in AppDelegate.

### Tab 1 — Record
- Large centered mic button — SF Symbol `mic.fill`, 52pt, amber tint
- Tap to start, tap again to stop
- While recording: mic icon replaced by inline `WaveformView`
- Status text below: "Tap to record" / "Recording…" / "Transcribing…" / "Copied ✓"
- Does NOT trigger the floating HUD — feedback is entirely inline in the window

### Tab 2 — History
- List of last 20 `TranscriptEntry` items, newest first
- Each row: transcript text (2 lines, truncated) + relative date
- Tap row → copy to clipboard + brief "Copied" confirmation
- Swipe-to-delete or delete button
- Empty state: "No transcripts yet.\nPress ⌥Space anywhere to start."

### Tab 3 — Settings
- Hotkey: static label "⌥ Space" in monospace (non-editable in v1.0)
- Model: static label showing model name e.g. "base.en"
- Launch at login: Toggle — calls `SMAppService` on change
- About: app name "Koe" in serif, version string

### Design language in the window
- Background: `Color(NSColor.windowBackgroundColor)` — system default
- Accent: amber `#C47D3A` for mic button and active/done states
- TabView: standard SwiftUI `.tabViewStyle(.automatic)`
- Typography: follows DESIGN.md (sans UI copy, mono for hotkey labels)
- No decorative chrome — editorial, warm, minimal

---

## TranscriptStore

```swift
class TranscriptStore: ObservableObject {
    @Published var entries: [TranscriptEntry] = []

    func add(_ text: String)             // prepend, trim to 20, persist
    func delete(_ entry: TranscriptEntry)
    func clear()
    private func persist()               // encode to UserDefaults "koe.history"
    private func load()                  // decode on init
}

struct TranscriptEntry: Identifiable, Codable {
    let id: UUID
    let text: String
    let date: Date
}
```

Inject `TranscriptStore` as an `@EnvironmentObject` from AppDelegate into both HUD completion handler and MainView.

---

## Menu Bar

Left-click on icon → open State 3 main window.
Right-click → show menu:

```
Koe
─────────────
Open Koe...        ← opens main window
─────────────
Hotkey: ⌥Space     ← disabled label
─────────────
Quit Koe
```

---

## What Claude Code Must Never Do

- Never make HTTP/network calls
- Never retain audio files after transcription completes
- Never store more than 20 transcript entries
- Never add Swift Package dependencies without asking
- Never use `DispatchQueue.main.sync`
- Never quit the app when main window is closed — hide the window only
- Never show the Dock icon — `LSUIElement = YES` always

---

## Build & Run (Warp, no Xcode GUI)

### Prerequisites
```bash
xcode-select --install        # Xcode CLI tools
swift --version               # confirm 5.9+
/usr/local/bin/whisper-cli --version
ls ~/Library/Application\ Support/Koe/ggml-base.en.bin
```

### Commands
```bash
cd ~/Developer/Koe
swift build                   # debug build
swift run                     # run
swift build -c release        # release build
```

### Common issues

| Symptom | Cause | Fix |
|---|---|---|
| Hotkey does nothing | Accessibility not granted | System Settings → Privacy → Accessibility |
| HUD never appears | Event tap failed | Check Console.app for `Koe` logs |
| Transcription errors | whisper-cli not found | Confirm binary at `/usr/local/bin/whisper-cli` |
| Empty transcription | Model not found | Confirm model at `~/Library/Application Support/Koe/` |
| App shows in Dock | `LSUIElement` missing | Add `LSUIElement = YES` to Info.plist |
| Window won't open | Weak reference released | Confirm AppDelegate holds strong ref to `MainWindowController` |

---

## Testing Checklist (manual, pre-commit)

**State 2 — HUD:**
- [ ] ⌥Space starts recording — amber waveform HUD appears
- [ ] ⌥Space stops — transitions to "Transcribing…"
- [ ] Done state shows text preview — ⌘V pastes correctly
- [ ] HUD dismisses after 2s
- [ ] No temp files in `/tmp`

**State 3 — Main window:**
- [ ] Menu bar click opens window
- [ ] Spotlight search "Koe" opens window
- [ ] Record tab mic button records + inline waveform shows
- [ ] History tab shows new entry after each recording
- [ ] Tapping history row copies to clipboard
- [ ] Settings tab renders correctly
- [ ] Closing window does NOT quit — menu bar icon remains

**Always:**
- [ ] App not in Dock
- [ ] Quit from menu bar works

---

## Handoff Notes

Paste this entire file at the start of every Claude Code session. Update it when: files are added or removed, whisper.cpp integration changes, HUD state machine changes, window tabs change, or new permissions are added. This file is the single source of truth for Claude Code.
