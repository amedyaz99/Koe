x# Koe — Design System

**Version:** 1.1
**App:** Koe (声) — voice to clipboard, macOS
**Design model:** warm minimalism / editorial / transient UI

---

## Design Philosophy

Koe has one job. It appears, listens, transcribes, disappears. When it is present, it should feel warm and intentional — not clinical, not loud. The design must serve that loop.

Four principles:

**Transient, not permanent** — State 2 (HUD) exists only while it needs to. Every decision should serve disappearing cleanly. State 3 (main window) is calm and unhurried — it doesn't need to demand attention.

**Warm minimalism** — Parchment and amber over cold grays and blues. Soft but not weak. Contrast is present, just not harsh. Feels like paper, not glass.

**Editorial type** — Serif for the wordmark, monospace for hotkey labels and meta information, sans-serif for UI copy. Three faces, each earning its place. No decorative mixing.

**Motion is information** — The only continuous animation is the waveform during recording. All other transitions: 150–200ms. Nothing animates for decoration.

---

## Three App States

| State | Surface | Design character |
|---|---|---|
| **1 — Menu bar** | System menu bar icon only | Invisible — just a 16pt mic icon |
| **2 — HUD** | Floating pill, bottom-center of screen | Transient, warm, high contrast |
| **3 — Main window** | Standard macOS window, 520 × 500pt default | Editorial, calm, tabbed |

---

## Identity

### Wordmark

```
koe.
```

- Serif, weight 400, tracking -0.03em, lowercase
- The trailing dot is amber `#C47D3A` — the only color in the wordmark
- Used in: About section of SettingsTab, splash/marketing
- Never used inside the HUD

### Tagline

```
voice → clipboard
```

- 13px, letter-spacing 0.04em, muted
- Settings tab About section only

---

## Color

### Palette

| Name | Hex | Role |
|---|---|---|
| Ink | `#1A1410` | Primary text (light mode) |
| Parchment | `#F5F0E8` | Background warmth reference |
| Amber | `#C47D3A` | Brand / recording state / waveform / mic button |
| Stone | `#8C7B6A` | Secondary text, muted UI |
| Indigo | `#4B6BC8` | Transcribing spinner |
| Moss | `#508C5A` | Done / success state |
| Terracotta | `#B85A3C` | Error state |

### Semantic mapping

| State | Color | Applied to |
|---|---|---|
| Recording | Amber `#C47D3A` | Waveform bars, HUD tint, menu bar icon tint, RecordTab mic button |
| Transcribing | Indigo `#4B6BC8` | Spinner stroke in HUD + RecordTab |
| Done | Moss `#508C5A` | Check icon background in HUD, "Copied ✓" text in RecordTab |
| Error | Terracotta `#B85A3C` | Error icon background, error text |
| Idle | — | No color — system defaults |

### HUD background tints (layered over .ultraThinMaterial)

| State | Tint color | Opacity |
|---|---|---|
| Recording | Amber | 0.06 |
| Transcribing | None | — |
| Done | Moss | 0.06 |
| Error | Terracotta | 0.05 |

### Dark mode

`.ultraThinMaterial` handles dark mode automatically for the HUD. Main window uses `Color(NSColor.windowBackgroundColor)` — also automatic. Only the custom tint overlays and icon colors are explicitly set.

---

## Typography

| Role | Face | Size | Weight | Tracking |
|---|---|---|---|---|
| Wordmark | Serif | 52px | 400 | -0.03em |
| HUD title | Sans | 13px | 500 | default |
| HUD subtitle | Sans | 11px | 400 | default |
| RecordTab status | Sans | 14px | 400 | default |
| HistoryTab text | Sans | 13px | 400 | default |
| HistoryTab date | Mono | 11px | 400 | default |
| Hotkey labels | Mono | 13px | 400 | 0.04em |
| Settings labels | Sans | 13px | 400 | default |

SwiftUI font calls:
```swift
.font(.system(size: 13, weight: .medium))                          // HUD title
.font(.system(size: 11, weight: .regular))                         // HUD subtitle
.font(.system(size: 11, weight: .regular, design: .monospaced))    // dates, hotkey
.font(.system(size: 52, weight: .regular, design: .serif))         // wordmark
```

---

## State 2 — HUD

### Window

```swift
styleMask: [.borderless]
isOpaque = false
backgroundColor = .clear
level = .floating
ignoresMouseEvents = true
collectionBehavior = [.canJoinAllSpaces, .stationary]
```

### Dimensions

| Property | Value |
|---|---|
| Width | 340pt |
| Height | 72pt |
| Corner radius | 22pt |
| Horizontal padding | 18pt |
| Icon column | 28pt |
| Icon → text gap | 14pt |

### Position

```swift
let x = screen.visibleFrame.midX - 170
let y = max(screen.visibleFrame.minY + 60, screen.visibleFrame.minY + 20)
```

### Border

0.5px, varies by state:
- Idle / transcribing: `rgba(0,0,0,0.08)` / dark: `rgba(255,255,255,0.08)`
- Recording: `rgba(196,125,58,0.2)`
- Done: `rgba(80,140,90,0.2)`
- Error: `rgba(184,90,60,0.15)`

### State content

| State | Icon | Title | Subtitle |
|---|---|---|---|
| `.recording` | WaveformView (amber bars) | "Recording…" | "Press ⌥Space to stop" |
| `.transcribing` | ProgressView (indigo, scale 0.8) | "Transcribing…" | "Processing audio" |
| `.done(text)` | Moss filled circle + white checkmark | "Copied to clipboard" | transcript (1 line, truncated) |
| `.error` | Terracotta filled circle + white `!` | "Transcription failed" | "Check whisper-cli is installed" |

### Auto-dismiss timing

| State | Delay |
|---|---|
| Done | 2.0s |
| Error | 1.5s |

---

## State 3 — Main Window

### Window

```swift
styleMask: [.titled, .closable, .miniaturizable, .resizable]
title: "Koe"
minSize: NSSize(width: 480, height: 400)
defaultSize: NSSize(width: 520, height: 500)
```

Standard macOS window chrome — title bar, traffic lights. No borderless, no custom chrome.
Background: `Color(NSColor.windowBackgroundColor)` — system default, adapts to dark mode.

### Tab bar

Standard SwiftUI `TabView` with `.tabViewStyle(.automatic)`. Three tabs:

| # | Label | SF Symbol |
|---|---|---|
| 1 | Record | `mic.fill` |
| 2 | History | `clock` |
| 3 | Settings | `gearshape` |

### Tab 1 — Record

Layout: vertically and horizontally centered content stack.

**Mic button:**
- 80pt circle
- Background: amber `#C47D3A`
- Icon: `mic.fill` SF Symbol, 32pt, white
- While recording: `WaveformView` replaces icon (same component as HUD, bars scaled up)
- Tap to start, tap again to stop
- No floating HUD — all feedback is inline

**Status label (below button, 14px, muted):**
- Idle: "Tap to record"
- Recording: "Recording…"
- Transcribing: "Transcribing…"
- Done: "Copied ✓" in moss
- Error: "Something went wrong" in terracotta

### Tab 2 — History

Standard `List`. Newest entry first.

**Each row:**
- Transcript text, `.lineLimit(2)`, 13px
- Date in monospace 11px muted, relative format ("2 minutes ago", "Yesterday")
- Tap → copy to clipboard + brief "Copied" flash on the row

**Empty state (centered):**
```
No transcripts yet.
Press ⌥Space anywhere to start.
```
Muted, 14px, centered vertically.

**Delete:** swipe-to-delete gesture on each row.

### Tab 3 — Settings

SwiftUI `Form` with `.formStyle(.grouped)`.

Sections:
1. **Hotkey** — `LabeledContent("Trigger") { Text("⌥ Space").monospaced() }`
2. **Transcription** — `LabeledContent("Model") { Text("base.en").monospaced() }`
3. **System** — `Toggle("Launch at login", isOn: $launchAtLogin)`
4. **About** — version string + wordmark `koe.` in serif + amber dot

---

## Waveform Animation

Shared component used in both HUD (State 2) and RecordTab (State 3).

```swift
// Shared WaveformView — configurable size
struct WaveformView: View {
    var barWidth: CGFloat = 3
    var minHeight: CGFloat = 8
    var maxHeight: CGFloat = 22
    var color: Color = Color(hex: "#C47D3A")
}

// HUD usage (default)
WaveformView()

// RecordTab usage (slightly larger)
WaveformView(barWidth: 4, minHeight: 10, maxHeight: 30)
```

5 bars. Timer at 0.05s. Phase += 0.3 per tick. `.easeInOut(duration: 0.3)` on height.
Height formula: `minHeight + (maxHeight - minHeight) * abs(sin(phase + Double(i) * 0.8))`

---

## Menu Bar Icon

| State | Symbol | Tint |
|---|---|---|
| Idle | `mic.fill` template | None (system) |
| Recording | `mic.fill` | Amber `#C47D3A` |

Template images adapt to system dark/light automatically. Apply amber tint only during recording.

---

## Motion

| Transition | Duration | Easing |
|---|---|---|
| HUD appear | 180ms | ease-out |
| HUD disappear | 200ms | ease-in |
| HUD state change | 150ms | ease |
| Waveform bar height | 300ms | ease-in-out |
| Done checkmark appear | 200ms | spring (damping 0.7) |
| Window open | System default | — |
| Tab switch | System default | — |

No bounce. No overshoot except the checkmark spring. Motion serves function.

---

## Spacing & Layout

### HUD
```
[18pt] [28pt icon] [14pt] [VStack: 13px title / 4pt / 11px subtitle] [Spacer] [18pt]
```

### RecordTab
```
Vertical center:
  [80pt mic circle]
  [16pt gap]
  [14px status label]
```

### HistoryTab row
```
[16pt leading] [VStack: 13px text / 4pt / 11px date mono] [Spacer] [16pt trailing]
Row height: ~56pt
```

---

## What This Design Is Not

- Not glassmorphism — `.ultraThinMaterial` is the base, not decorative stacking
- Not dark-mode-first — warm parchment is the reference, dark adapts
- Not playful — no rounded display fonts, no emoji in UI
- Not loud — no full-colored HUD backgrounds, no drop shadows in the window
- Not persistent — State 2 never lingers beyond 2 seconds

---

## File Naming

```
koe-icon-1024.png
koe-icon-512.png
koe-menubar-idle@2x.png
koe-menubar-active@2x.png
```

All in-app icons use SF Symbols — no custom icon assets needed for v1.0.

---

## Future Design (post v1.0)

- Onboarding: single screen, wordmark + two permission prompts, no illustrations
- Hotkey customization: inline key capture in SettingsTab, no modal
- Model selector: dropdown in SettingsTab, updates model path in WhisperTranscriber
- Multiple languages: language dropdown, replaces `-l auto` with specific code
