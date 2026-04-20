import SwiftUI
import AppKit
import AVFoundation

@MainActor
class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func show() {
        guard window == nil else { return }

        let contentView = OnboardingView(appState: appState)
            .frame(width: 420, height: 480)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Welcome to Koe"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces]
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func close() {
        window?.close()
        window = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow closing, but don't complete onboarding if permissions not granted
        // The view handles the logic for showing warnings
        return true
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @State private var microphoneGranted = false
    @State private var accessibilityGranted = false
    @State private var showPermissionWarning = false

    var body: some View {
        ZStack {
            KoeTheme.sumiInk.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("Koe")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(KoeTheme.washiPaper)
                        Text(".")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(KoeTheme.vermilion)
                    }
                    Text("voice → clipboard")
                        .font(KoeTheme.monoSmall)
                        .foregroundColor(KoeTheme.washiMuted)
                        .tracking(1.5)
                }
                .padding(.top, 32)

                Spacer()

                // Permissions Section
                VStack(spacing: 16) {
                    permissionRow(
                        icon: "mic.fill",
                        title: "Microphone",
                        description: "Required to record your voice",
                        granted: microphoneGranted,
                        action: requestMicrophoneAccess
                    )

                    permissionRow(
                        icon: "keyboard.fill",
                        title: "Accessibility",
                        description: "Required for global hotkey",
                        granted: accessibilityGranted,
                        action: appState.hotkeyManager?.openAccessibilitySettings ?? {}
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // Hotkey Display
                VStack(spacing: 12) {
                    Text(HotkeyConfig.current.displayString)
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundColor(KoeTheme.washiPaper)

                    Text("Press this anywhere to start recording")
                        .font(KoeTheme.monoSmall)
                        .foregroundColor(KoeTheme.washiMuted)
                }
                .padding(.vertical, 24)

                // Warning (if skipping without permissions)
                if showPermissionWarning {
                    Text("Without these permissions, Koe won't work properly")
                        .font(KoeTheme.monoTiny)
                        .foregroundColor(KoeTheme.vermilion)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }

                // Got It Button
                Button(action: handleGotIt) {
                    HStack(spacing: 8) {
                        Text("Got it")
                            .font(KoeTheme.monoSmall)
                        if !allPermissionsGranted {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                        }
                    }
                }
                .buttonStyle(OnboardingButtonStyle(
                    backgroundColor: allPermissionsGranted ? KoeTheme.vermilion : KoeTheme.washiMuted.opacity(0.3),
                    foregroundColor: allPermissionsGranted ? KoeTheme.washiPaper : KoeTheme.washiPaper.opacity(0.6)
                ))
                .disabled(!allPermissionsGranted && !showPermissionWarning)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            checkPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkPermissions()
        }
    }

    private var allPermissionsGranted: Bool {
        microphoneGranted && accessibilityGranted
    }

    private func checkPermissions() {
        // Check microphone
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

        // Check accessibility
        accessibilityGranted = appState.hotkeyManager?.isAccessibilityTrusted ?? false
    }

    private func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                microphoneGranted = granted
            }
        }
    }

    private func handleGotIt() {
        if allPermissionsGranted {
            appState.completeOnboarding()
        } else {
            showPermissionWarning = true
            // Still allow them to proceed after showing warning
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                appState.completeOnboarding()
            }
        }
    }

    @ViewBuilder
    private func permissionRow(
        icon: String,
        title: String,
        description: String,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(granted ? KoeTheme.vermilion : KoeTheme.washiMuted)
                .frame(width: 24)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(KoeTheme.monoSmall)
                    .foregroundColor(KoeTheme.washiPaper)
                Text(description)
                    .font(KoeTheme.monoTiny)
                    .foregroundColor(KoeTheme.washiMuted)
            }

            Spacer()

            // Status / Button
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(KoeTheme.vermilion)
                    .font(.system(size: 18))
            } else {
                Button("Grant →", action: action)
                    .font(KoeTheme.monoSmall)
                    .foregroundColor(KoeTheme.vermilion)
                    .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(KoeTheme.sumiInkLight)
        .cornerRadius(8)
    }
}

private struct OnboardingButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
