# Build & Run — Koe

Build and run Koe using Swift Package Manager from Warp or terminal. No Xcode GUI required.

## Prerequisites

```bash
xcode-select --install        # Xcode CLI tools
swift --version               # confirm 5.9+
/usr/local/bin/whisper-cli --version
ls ~/Library/Application\ Support/Koe/ggml-base.en.bin
```

Verify all four commands succeed before building.

## Commands

```bash
cd ~/Developer/Koe
swift build                   # debug build
swift run                     # run debug build
swift build -c release        # release build
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Hotkey does nothing | Accessibility not granted | System Settings → Privacy → Accessibility → grant Koe access |
| HUD never appears | Event tap failed | Check Console.app for `Koe` logs; verify accessibility granted |
| Transcription errors | whisper-cli not found | Confirm binary at `/usr/local/bin/whisper-cli` |
| Empty transcription | Model not found | Confirm model at `~/Library/Application Support/Koe/ggml-base.en.bin` |
| App shows in Dock | `LSUIElement` missing from Info.plist | Add `LSUIElement = YES` to Resources/Info.plist |
| Window won't open | `MainWindowController` not retained | Verify AppDelegate holds strong reference to `MainWindowController` |

## Notes

- Builds are placed in `.build/debug` or `.build/release`
- The app requires swift 5.9+
- whisper.cpp binary and model must be present before running
