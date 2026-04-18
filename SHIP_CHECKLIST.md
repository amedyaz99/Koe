# Koe — Ship Checklist

Things needed to go from personal tool → something anyone can download and use.
Tackle these in order — each one builds on the last.

---

## 1. Bundle whisper.cpp + model
**Effort: ~1 day**

Right now users need to install whisper-cli via Homebrew and download the model manually. That kills non-technical users immediately.

**Steps:**
- [ ] Download `whisper-cli` binary from https://github.com/ggerganov/whisper.cpp/releases (pick the latest macOS release)
- [ ] Download `ggml-base.en.bin` from https://huggingface.co/ggerganov/whisper.cpp
- [ ] Place both in `Sources/Koe/Resources/`
- [ ] Add them to `Package.swift` as bundle resources:
  ```swift
  .executableTarget(
      name: "Koe",
      resources: [
          .copy("Resources/whisper-cli"),
          .copy("Resources/ggml-base.en.bin")
      ]
  )
  ```
- [ ] Make `whisper-cli` executable after bundling — add a post-build script or do it at runtime:
  ```swift
  // In WhisperTranscriber, after resolving the binary URL:
  try? FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: binaryURL.path
  )
  ```
- [ ] Delete your Homebrew whisper (`brew uninstall whisper-cpp`) and test the app cold — transcription should still work

---

## 2. Fix silent failure when whisper isn't found
**Effort: ~half a day**

Currently if the binary is missing, the HUD just shows `error` with no explanation. Users will think the app is broken.

**Steps:**
- [ ] In `WhisperTranscriber.swift`, before launching the subprocess, check the binary path exists:
  ```swift
  guard FileManager.default.fileExists(atPath: binaryURL.path) else {
      completion(.failure(WhisperError.binaryNotFound))
      return
  }
  ```
- [ ] Add `binaryNotFound` to your error enum
- [ ] In `AppState.swift`, catch that specific error and show a different HUD message or trigger a notification:
  ```swift
  case .failure(WhisperError.binaryNotFound):
      // open a URL to your setup docs or show an alert
  ```
- [ ] Test by temporarily renaming the binary and triggering a transcription

---

## 3. Fix silent Accessibility permission failure
**Effort: ~half a day**

If the user denies Accessibility access, the hotkey silently does nothing. Users will think the app is broken.

**Steps:**
- [ ] In `HotkeyManager.register()`, after the initial `AXIsProcessTrustedWithOptions` prompt, if not trusted, show a persistent menu bar badge or post a notification
- [ ] Open System Settings directly to the right pane — add this helper anywhere:
  ```swift
  func openAccessibilitySettings() {
      let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
      NSWorkspace.shared.open(url)
  }
  ```
- [ ] Add a menu item "Grant Accessibility Access →" to the right-click menu bar menu that calls the above, shown only when not trusted
- [ ] Test by revoking Accessibility in System Settings → Privacy → Accessibility, then relaunching

---

## 4. First-run onboarding
**Effort: ~1 day**

When someone opens the app for the first time they see a menu bar icon and nothing else. They won't know what to do.

**Steps:**
- [ ] Add a launch flag to `AppState` or use `@AppStorage("koe.hasCompletedOnboarding")` defaulting to `false`
- [ ] On first launch, open a small centered window (not the main window) with:
  - App name + one-line description
  - "Grant Microphone Access" button → calls `AVCaptureDevice.requestAccess(for: .audio)`
  - "Grant Accessibility Access" button → opens System Settings (see Step 3 above)
  - The hotkey displayed large: `⌥ K` — "Press this anywhere to start recording"
  - A "Got it" button that sets `hasCompletedOnboarding = true` and closes the window
- [ ] Make the window non-closable until both permissions are granted (or at least clearly warn)
- [ ] Set `hasCompletedOnboarding = true` and never show again

---

## 5. Sign + Notarize the app
**Effort: ~1 weekend the first time, ~30 min after that**

Without this, macOS shows "cannot be opened because the developer cannot be verified." Most users won't get past this.

**Steps:**
- [ ] Buy Apple Developer membership at https://developer.apple.com/enroll/ ($99/yr)
- [ ] In Xcode → Settings → Accounts, add your Apple ID and download your certificates
- [ ] Create a "Developer ID Application" certificate (for distribution outside the App Store)
- [ ] Add an `Entitlements.plist` to the project:
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>com.apple.security.device.audio-input</key>
      <true/>
      <key>com.apple.security.automation.apple-events</key>
      <true/>
  </dict>
  </plist>
  ```
- [ ] Build a release binary: `swift build -c release`
- [ ] Sign it:
  ```bash
  codesign --deep --force --verify --verbose \
    --sign "Developer ID Application: YOUR NAME (TEAM_ID)" \
    --entitlements Entitlements.plist \
    .build/release/Koe
  ```
- [ ] Create a DMG using `create-dmg` (install via `brew install create-dmg`):
  ```bash
  create-dmg \
    --volname "Koe" \
    --window-size 600 400 \
    --icon-size 128 \
    "Koe.dmg" \
    ".build/release/Koe"
  ```
- [ ] Notarize the DMG:
  ```bash
  xcrun notarytool submit Koe.dmg \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "app-specific-password" \
    --wait
  ```
- [ ] Staple the notarization ticket to the DMG:
  ```bash
  xcrun stapler staple Koe.dmg
  ```
- [ ] Send the DMG to a friend on a different Mac and have them open it — verify no Gatekeeper warning

---

## Summary

| # | Task | Effort | Blocks |
|---|---|---|---|
| 1 | Bundle whisper + model | 1 day | Users without Homebrew |
| 2 | Whisper not found error | ½ day | Silent failures |
| 3 | Accessibility nudge | ½ day | Hotkey silently broken |
| 4 | First-run onboarding | 1 day | User confusion on launch |
| 5 | Sign + notarize | 1 weekend | macOS Gatekeeper block |

Do them in order. After all five, Koe is ready to share publicly.
