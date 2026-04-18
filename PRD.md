# Koe — Product Requirements Document

**Version:** 1.1
**Date:** 2026-04-08
**Status:** Active

---

## 1. Problem

Typing is slow when thinking out loud. Dictation in macOS is clunky, requires focus inside a specific app, and leaves no quick way to dump a thought into whatever context you're working in — a browser field, a terminal, a Slack message, a code comment. There is no zero-friction, system-wide voice-to-clipboard tool that is private, offline, and instant.

---

## 2. Solution

**Koe** (声, Japanese for "voice") — a macOS app that:
1. Lives in the menu bar by default
2. Activates on a global hotkey from anywhere — shows a minimal HUD while you speak
3. Also opens as a real app window with a mic button, transcript history, and settings
4. Transcribes locally via whisper.cpp (no internet, no API key)
5. Copies the result directly to clipboard

---

## 3. Target User

Solo developers, writers, medical students, researchers — power users who live in the keyboard, think faster than they type, and won't accept tools that require switching context or sending audio to the cloud.

---

## 4. Three App States

### State 1 — Menu Bar (default idle)
The app runs silently. Only presence: a mic icon in the system menu bar. No Dock icon. Zero visual footprint.

### State 2 — HUD (hotkey triggered)
Press ⌥K from any app. A floating pill appears at the bottom of the screen. User speaks. Press ⌥K again. HUD transitions through Recording → Transcribing → Copied. Auto-dismisses. User presses ⌘V anywhere.

### State 3 — Main Window (on demand)
Opened by clicking the menu bar icon or via Spotlight. A standard macOS window with three tabs:
- **Record** — large mic button, inline waveform, same transcription flow as State 2 but without the floating HUD
- **History** — list of last 20 transcripts, tap to copy, swipe to delete
- **Settings** — hotkey display, model info, launch at login toggle

States 2 and 3 can coexist. Closing the window does not quit the app.

---

## 5. Core User Flows

### Flow A — Quick capture (State 2)
```
Any app → ⌥K → HUD (waveform) → speak → ⌥K → HUD (transcribing)
→ HUD (copied) → auto-dismiss → ⌘V anywhere
```

### Flow B — In-app recording (State 3)
```
Click menu bar icon → Main window opens → Record tab → tap mic button
→ inline waveform → tap again → transcribing → "Copied ✓" → ⌘V anywhere
```

### Flow C — Review history (State 3)
```
Click menu bar icon → Main window → History tab → tap any entry → copies to clipboard
```

---

## 6. Features

### 6.1 MVP (v1.0)

| Feature | State | Description |
|---|---|---|
| Menu bar icon | 1 | Mic icon, no Dock presence |
| Global hotkey | 2 | ⌥K — toggle recording system-wide |
| HUD overlay | 2 | Floating pill, bottom-center, 4 states |
| Waveform animation | 2, 3 | Animated amber bars during recording |
| Local transcription | 2, 3 | whisper.cpp subprocess, base.en model |
| Clipboard output | 2, 3 | NSPasteboard write after transcription |
| Main window | 3 | Opens via menu bar click or Spotlight |
| Record tab | 3 | Inline mic button + waveform |
| History tab | 3 | Last 20 transcripts, tap to copy, swipe to delete |
| Settings tab | 3 | Hotkey display, model info, launch at login |
| Transcript persistence | 3 | UserDefaults, max 20 entries |
| Accessibility prompt | 1 | First-launch system dialog for global hotkey |
| Microphone prompt | 2, 3 | macOS-native mic permission dialog |

### 6.2 Post-MVP (v1.1+)

| Feature | Priority |
|---|---|
| Hotkey customization in Settings | High |
| Model selector (tiny / base / small / medium) | High |
| Language selector | Medium |
| Auto-paste after transcription | Medium |
| Launch at login (functional) | High |
| Search in History | Low |
| Export history as text | Low |

---

## 7. Non-Functional Requirements

| Requirement | Target |
|---|---|
| Transcription latency (base.en, M-series) | < 3s for 30s audio |
| App memory at idle (State 1) | < 30MB |
| First keystroke → HUD visible | < 100ms |
| Fully offline | Yes — zero network calls ever |
| macOS minimum | 13.0 (Ventura) |
| Architecture | Universal binary (arm64 + x86_64) |
| Build tool | Swift Package Manager |

---

## 8. Privacy & Security

- No network requests — ever
- No audio retention — temp `.wav` deleted immediately after transcription
- No telemetry
- whisper.cpp runs as a local subprocess — audio never leaves the machine
- Transcript history stored only in `UserDefaults` on local device
- Permissions: Microphone (recording) + Accessibility (global hotkey only)

---

## 9. Technical Constraints

- Language: Swift 5.9+, SwiftUI for all UI
- Build: Swift Package Manager (no Xcode GUI required)
- Hotkey: CGEvent tap (requires Accessibility permission)
- Audio: AVAudioEngine → temp `.wav`
- Transcription: whisper.cpp binary (`whisper-cli`) as subprocess
- Model: ggml format, `~/Library/Application Support/Koe/` or bundled
- Clipboard: NSPasteboard
- Persistence: UserDefaults (no database, no Core Data)
- App mode: `LSUIElement = YES` (menu bar primary, no Dock icon)

---

## 10. Out of Scope (v1.0)

- No streaming transcription
- No cloud transcription option
- No Windows or Linux support
- No iOS companion app
- No iCloud sync
- No custom hotkey UI (hardcoded ⌥K)
- No model download UI (user installs manually)

---

## 11. Success Criteria

- Thought → clipboard in < 5 seconds total (State 2 flow)
- App does not appear in Dock
- Hotkey works system-wide (browser, terminal, Xcode, Notion, etc.)
- Main window opens via Spotlight by name "Koe"
- Audio never retained on disk after transcription
- History persists across relaunches (up to 20 entries)
- Closing window does not quit app — menu bar stays alive
- Zero crashes on happy path for 1 week of daily use
