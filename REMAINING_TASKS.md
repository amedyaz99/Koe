# Remaining Tasks — Koe

Shipping status and technical debt report.

---

## 🚀 Shipping Priorities

### P0 — Distribution Readiness
- [ ] **Signing & Notarization:** Required to pass macOS Gatekeeper. Without this, users will see "Developer cannot be verified."
- [ ] **Entitlements:** Create `Entitlements.plist` with `com.apple.security.device.audio-input` for microphone access in a hardened runtime.
- [ ] **Bundle Validation:** Run `make bundle` and verify the `.app` launches on a machine without Homebrew.

### P1 — Visual Polish
- [ ] **App Icon:** Create and bundle `AppIcon.icns`. The current InkanStamp is a SwiftUI component, but the app needs a file-level icon for the Finder/Dock.
- [ ] **Release DMG:** Create a standard installer disk image (can use `create-dmg`).

### P2 — UX Enhancements
- [ ] **Auto-Launch:** Implement "Launch at login" properly using `SMAppService` (referenced in specs but needs verification).
- [ ] **Model Download:** (Optional) If 150MB is too large for the initial download, implement a "Downloading Model..." state on first launch.

---

## 🔍 Hidden Issues & Debug Report

### 1. AudioRecorder Silent Failures
- **Issue:** If `AVAudioFile` fails to initialize (e.g., Disk Full or Permissions), `beginRecording()` returns `void` and the app enters a broken state.
- **Fix:** Update `beginRecording()` to throw or return a Result, and show the `.error` HUD state immediately.

### 2. File Leaks in `/tmp`
- **Issue:** `WhisperTranscriber` deletes the `.txt` file, but if an error occurs during transcription, the `.wav` or `.txt` might be left behind.
- **Fix:** Use `defer { try? FileManager.default.removeItem(at: audioURL) }` more aggressively in `AppState` and the transcriber.

### 3. AppState Initializer Race
- **Issue:** `AppState.init` creates `OnboardingWindowController` and calls `show()` immediately. If `NSApplication` isn't fully ready, the window might not appear or might lose focus.
- **Fix:** Move onboarding trigger to a `.task` on the main view or a `didFinishLaunching` notification.

### 4. PasteManager Reliability
- **Issue:** `CGEvent` posting to a PID can be blocked by certain "secure input" fields (like password fields).
- **Fix:** Ensure the HUD shows `done` (copied) even if `pasted` fails, so the user can still manual paste as a fallback.

### 5. Multi-Monitor "Main" Screen Logic
- **Issue:** Fixed! (HUD now follows the mouse pointer).
