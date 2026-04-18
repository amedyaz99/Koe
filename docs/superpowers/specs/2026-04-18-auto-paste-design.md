# Auto-Paste to Active Field — Design Spec
_2026-04-18_

## Goal

After transcription completes, automatically paste the result into whatever app the user was typing in when they triggered the hotkey — eliminating the manual ⌘V step. Toggleable. On by default.

---

## User-Facing Behavior

1. User is typing in Terminal, Notes, Slack, etc.
2. User presses ⌥K — recording starts (HUD appears, red dot + waveform).
3. User presses ⌥K again — transcription runs.
4. Text is copied to clipboard **and** pasted directly into the original app.
5. HUD shows `✓ pasted` instead of `✓ copied`.

If the toggle is **off**, behavior is unchanged: text goes to clipboard, HUD shows `✓ copied`.

---

## Toggle

- Key: `@AppStorage("koe.autoPaste")` — `Bool`, default `true`
- Location: Settings tab → System section, below "Launch at login"
- Label: `Auto-paste` / Japanese: `自動ペースト`

---

## Architecture

### New file: `PasteManager.swift`

Single responsibility: post a ⌘V keystroke to a target process by PID.

```swift
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

- `virtualKey 0x09` = V key (standard HID keycode)
- Uses `postToPid()` — posts directly to the target process without stealing focus
- Requires Accessibility permission (already granted for the hotkey)
- No return value — failure is silent; clipboard fallback is already in place

### Modified: `AppState.swift`

Two additions:

1. `@AppStorage("koe.autoPaste") private var autoPasteEnabled = true`
2. `private var frontmostAppAtRecordStart: NSRunningApplication?`

In `startRecording()`, capture before anything else:
```swift
frontmostAppAtRecordStart = NSWorkspace.shared.frontmostApplication
```

In the transcription success branch, after `ClipboardManager.copy(text)`:
```swift
if autoPasteEnabled, let app = frontmostAppAtRecordStart {
    PasteManager.paste(to: app)
    self.hud.show(state: .pasted(text: text))
} else {
    self.hud.show(state: .done(text: text))
}
self.frontmostAppAtRecordStart = nil
```

### Modified: `HUDWindow.swift`

Add `.pasted(text: String)` to `HUDState`:

```swift
enum HUDState: Equatable {
    case recording
    case transcribing
    case done(text: String)
    case pasted(text: String)
    case error
}
```

`pasted` is visually identical to `done` — green `✓` glow — but label reads `pasted` instead of `copied`. Handle it alongside `.done` in all switch statements:

| Switch site | `.pasted` treatment |
|---|---|
| `leadingView` | Same as `.done` — green `✓` |
| `trailingView` | `"pasted"` instead of `"copied"` |
| `glowColor` | Same green as `.done` |
| `glowOpacity` | Same as `.done` |
| `glowRadius` | Same as `.done` |

Auto-dismiss: same 2.0s as `.done`.

### Modified: `SettingsTab.swift`

Add inside the System `settingsSection`, below the launch-at-login toggle:

```swift
Divider().background(KoeTheme.washiMuted.opacity(0.15))

HStack {
    VStack(alignment: .leading, spacing: 2) {
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

---

## Failure Modes

| Scenario | Behavior |
|---|---|
| App closed mid-recording | `postToPid` silently no-ops. Clipboard has the text. |
| User switches apps during recording | Pastes into the app active at hotkey press — expected. |
| Accessibility permission revoked | `postToPid` silently fails. Clipboard fallback still works. |
| `frontmostApp` is nil (edge case) | Skip paste, show `.done` instead. |

---

## Files Changed

| File | Change |
|---|---|
| `Sources/Koe/PasteManager.swift` | New — CGEvent paste helper |
| `Sources/Koe/AppState.swift` | Capture frontmost app, call PasteManager, read toggle |
| `Sources/Koe/HUD/HUDWindow.swift` | Add `.pasted(text:)` HUD state |
| `Sources/Koe/MainWindow/SettingsTab.swift` | Add auto-paste toggle in System section |
