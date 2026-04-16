# Koe — Japanese Stationery Redesign
**Date:** 2026-04-16
**Status:** Implemented
**Author:** Imad + Claude

---

## Overview

A full visual overhaul of Koe's three UI surfaces (HUD, main window, menu bar) replacing the original warm-minimalist palette with a "Minimalist Japanese stationery meets archival teletype" aesthetic. The app's interaction model and state machine are unchanged; only the visual layer is redesigned.

---

## Aesthetic Direction

**Core metaphor:** A handwritten field report filed in a Japanese archive. The UI feels like physical stationery — ivory paper, ink stamps, typewriter entries, tape marks — rendered as a precision digital tool.

| Element | Treatment |
|---|---|
| Background | Ivory `#F8F5F0` with subtle vermilion dot grid (18px spacing, 1.4px dots at 13% opacity) |
| Primary text | Sumi-black `#1A1410` |
| Accent | Vermilion `#C0392B` — replaces the previous amber `#C47D3A` |
| Secondary text | Warm stone `#8C7B6A` |
| Typography | Hiragino Mincho (section headings), SF Mono (metadata, values, labels), Hiragino Mincho W3 (wordmark, tab labels) |
| Decoration | Tape marks at window top edge, Inkan stamp, dotted leader rules, archival section dividers |

**What was removed:** Colored circle backgrounds on the mic button, orange/amber tints, standard SwiftUI Form and List chrome, `.grouped` form style, alternating row backgrounds.

---

## Design Decisions

### Layout: Tabbed (not sidebar)

The brief described a sidebar, but a sidebar is over-engineered for exactly three navigation destinations (Record, History, Settings). Tabs are the correct macOS pattern at this scale and preserve more horizontal space for content. The sidebar's visual DNA — typewriter entries, red underlines, serif section headings — was transplanted into the Settings tab interior instead.

### Inkan Stamp

- Characters: **こえ** (koe in hiragana) — phonetic Japanese for "voice"
- Color: Sumi-black `#1A1410` (not vermilion)
- Shape: Square, upright (no rotation)
- Positioned: Top-right of the custom tab bar, bottom-right of the About section

Rationale: Red was too decorative and competed with the vermilion accent system. Black reads as an institutional stamp — archival, authoritative. Upright reinforces the editorial calm of the design.

### Custom Tab Bar

Standard SwiftUI `TabView` was replaced with a hand-built tab bar to allow full control over:
- Hiragino Mincho serif tab labels
- Tape marks at the top edge (above the tab buttons)
- Inkan stamp anchored in the tab bar's trailing edge
- Ivory background continuity with the window title bar (`titlebarAppearsTransparent = true`)

### Recording Pill

The main Record tab interface is built around a "Recording Pill" component that shows live terminal-style state:

```
┌──────────────────────────────────┐
│  ▌▌▌▌▌▌▌   Buffer: Active        │
│             ● REC — 00:04        │
└──────────────────────────────────┘
```

Below the pill: a terminal metadata block (Sample Rate, Channels, Model, Engine, Status) that updates the Status field in real time. This replaces the previous large amber circle + status text label.

### History Tab

Replaced standard `List` with `ScrollView + LazyVStack` of custom rows:
- Sequential index numbers (`01. / 02.`) in faded vermilion
- Transcript text in Georgia/Hiragino Mincho serif
- Dotted leader rules (vermilion, 18% opacity) between date and "copy" label
- Hover reveals "copy" label and "×" delete button (no swipe gesture — desktop-native hover is cleaner)

### Settings Tab

Replaced `Form(.grouped)` with a custom section system:
- Each section has a serif uppercase heading + Japanese subtitle in faded vermilion (ショートカット, 文字起こし, システム, について)
- A gradient archival rule trails the heading to the right edge
- Each setting row uses `DottedLeaderRow` — a dotted red line fills the space between label and value (typewriter leader tab effect)
- Values in vermilion; secondary values in stone
- The launch-at-login toggle is a custom sumi-black capsule (no system tint)

### HUD (State 2)

The floating pill retains `.ultraThinMaterial` for dark/light adaptability. Changes:
- Recording state accent: vermilion (was amber)
- Title/subtitle copy: terminal-style (`Buffer: Active`, `● REC — press ⌥Space to stop`)
- Waveform default color: sumi-black `.primary`-equivalent via `KoeTheme.ink`

---

## Color Palette

| Token | Hex | Usage |
|---|---|---|
| `ink` | `#1A1410` | Primary text, mic button, Inkan |
| `ivory` | `#F8F5F0` | Window background |
| `ivoryDeep` | `#F0EBE3` | Panel backgrounds, hover states |
| `vermilion` | `#C0392B` | Accent, recording state, dot grid, underlines |
| `stone` | `#8C7B6A` | Secondary text, metadata keys |
| `stoneL` | `#B8A898` | Muted UI elements |
| `transcribingColor` | `#4B6BC8` | Indigo — transcribing state |
| `doneColor` | `#508C5A` | Moss — success/copied state |
| `errorColor` | `#B85A3C` | Terracotta — error state |

---

## Components (DesignSystem.swift)

| Component | Description |
|---|---|
| `DotGridBackground` | Canvas-drawn dot grid, parameterizable color/spacing/size |
| `TapeMarks` | Three evenly-spaced tape strip decorations at the window top |
| `InkanStamp` | Black square with こえ in Hiragino Mincho W6; size-parameterizable |
| `ArchivalDivider` | Gradient horizontal rule — full-weight vermilion line + short dim dot |
| `TerminalRow` | Monospaced key/value row with configurable value color |
| `DottedLeaderRow` | Label + dotted rule (drawn with Path) + trailing value slot |

---

## Files Changed

| File | Change |
|---|---|
| `DesignSystem.swift` | New palette, new components (`TerminalRow`, `DottedLeaderRow`), updated `InkanStamp` |
| `MainView.swift` | Custom `KoeTabBar`, `ZStack` with ivory + dot grid background |
| `RecordTab.swift` | `RecordingPill` component, terminal metadata block, recording timer |
| `HistoryTab.swift` | `ScrollView`-based `ArchivalEntryRow` with hover interactions |
| `SettingsTab.swift` | Custom sections, `DottedLeaderRow`, `ArchivalToggle`, `HotkeyBadge` |
| `MainWindowController.swift` | `titlebarAppearsTransparent`, ivory `backgroundColor` |
| `HUDWindow.swift` | Vermilion recording state, monospaced terminal copy |
| `WaveformView.swift` | Default color `KoeTheme.ink` (was amber hex string) |

---

## What Was Not Changed

- App interaction model and state machine
- Audio recording, transcription, clipboard pipeline
- HotkeyManager and HotkeyConfig
- TranscriptStore persistence
- Window size, min size, and close/hide behavior
- All three macOS permission flows (microphone, accessibility, login item)
