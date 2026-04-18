# HUD Compact Redesign — Design Spec
_2026-04-18_

## Goal

Replace the current large HUD pill (340×72pt, light frosted glass, text-heavy) with a compact dark pill that is small enough to stay out of the way but attention-grabbing through animation and color rather than size.

Inspiration: Warp terminal's recording indicator — a tight dark pill with an icon and waveform, no prose labels.

---

## Dimensions & Position

| Property | Value |
|---|---|
| Width | 210pt |
| Height | 34pt |
| Corner radius | 17pt (fully rounded) |
| Position | Top-right of main screen |
| Top inset | 16pt below `visibleFrame.maxY` |
| Right inset | 16pt from `visibleFrame.maxX` |

The pill sits just below the right side of the menu bar, where the clock lives. It never occludes center-screen content.

---

## Visual Identity

**Background:** `#111111` (near-black, opaque — no material blur)
**No text labels during recording.** The waveform communicates state; prose would be noise.
**All state feedback is through:** dot animation + waveform + outer glow color.

---

## States

### 1. Recording
- **Left element:** 7pt blinking red dot (`#E83333`, 1s step blink)
- **Right element:** 12-bar waveform, bars 2.5pt wide, amber `#E8A020`, heights vary 5–20pt, each bar animates on alternating delay (0.06s apart), `scaleY` 0.3→1
- **Outer glow:** Pulsing red — `box-shadow` breathes between `0 0 18px rgba(220,50,50,0.35)` and `0 0 30px rgba(220,50,50,0.55)` over 1.4s
- **Gap between dot and wave:** 10pt

### 2. Transcribing
- **Left element:** 3 indigo dots (`#7B8FE0`), 5pt each, sequential fade animation (1.2s, 0.2s delay apart)
- **Right element:** `processing` in monospaced 10pt, `rgba(255,255,255,0.35)`
- **Outer glow:** Static soft indigo — `0 0 14px rgba(100,120,220,0.2)`

### 3. Done
- **Left element:** `✓` checkmark, `#3CB85A`, 14pt, pops in with scale animation (0.6→1.15→1)
- **Right element:** `copied` in monospaced 11pt, `rgba(255,255,255,0.6)`
- **Outer glow:** Static soft green — `0 0 14px rgba(60,180,90,0.2)`
- **Auto-dismiss:** 2.0s

### 4. Error
- **Left element:** `✗`, red `#E83333`, 14pt
- **Right element:** `error` in monospaced 11pt, `rgba(255,255,255,0.6)`
- **Outer glow:** Static soft red — `0 0 14px rgba(220,50,50,0.2)`
- **Auto-dismiss:** 1.5s

---

## Window Properties

No changes to `NSWindow` configuration beyond the frame origin calculation:

```swift
// New positioning — top-right
let x = frame.maxX - 210 - 16
let y = frame.maxY - 34 - 16
```

Window size changes from `340×72` to `210×34`.

---

## What Doesn't Change

- `HUDState` enum — no changes
- Auto-dismiss timing — same (2.0s done, 1.5s error)
- `NSWindow` flags — borderless, floating, ignores mouse, joins all spaces
- All audio/transcription pipeline — untouched
- `WaveformView` in `RecordTab` (main window) — untouched

---

## Files to Modify

| File | Change |
|---|---|
| `Sources/Koe/HUD/HUDWindow.swift` | Replace `HUDView` layout, update window size and `position()` |
