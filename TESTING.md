# Testing Checklist — Koe

Manual testing checklist before each commit. Verify both the HUD (State 2) and main window (State 3) workflows.

## State 2 — HUD (⌥Space hotkey flow)

- [ ] ⌥Space starts recording — amber waveform HUD appears at bottom of screen
- [ ] ⌥Space pressed again stops recording — transitions to "Transcribing…" state
- [ ] Done state displays text preview — can paste with ⌘V
- [ ] HUD auto-dismisses 2 seconds after done
- [ ] No temp .wav or .txt files remain in `/tmp` after completion

## State 3 — Main Window

- [ ] Menu bar icon click opens main window
- [ ] Spotlight search "Koe" opens main window
- [ ] Record tab: mic button records + inline waveform appears during recording
- [ ] History tab: new transcript entry appears after each recording
- [ ] History tab: tapping row copies to clipboard
- [ ] Settings tab: renders without errors (hotkey label, model name, launch-at-login toggle)
- [ ] Closing main window does NOT quit the app — menu bar icon remains active

## Always (every build)

- [ ] App does not appear in Dock (`LSUIElement = YES` in effect)
- [ ] Quit from menu bar icon works without errors
