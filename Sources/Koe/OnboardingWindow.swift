import SwiftUI
import AppKit
import AVFoundation

@MainActor
class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSPanel?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func show() {
        guard window == nil else { return }

        let contentView = OnboardingView(appState: appState)
            .frame(width: 440, height: 520)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = ""
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.contentView = NSHostingView(rootView: contentView)
        panel.center()
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = panel
    }

    func close() {
        window?.close()
        window = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Only allow closing via the button in the UI
        return false
    }
}

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @State private var microphoneGranted = false
    @State private var accessibilityGranted = false
    @State private var showPermissionWarning = false
    @State private var debugClickCount = 0

    var body: some View {
        ZStack {
            ContinuousRoundedRectangle(cornerRadius: 24)
                .fill(KoeTheme.sumiInk)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    InkanStamp(size: 44)
                        .padding(.top, 40)
                        .onTapGesture {
                            debugClickCount += 1
                            if debugClickCount >= 3 {
                                appState.completeOnboarding()
                            }
                        }
                    
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("Koe")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(KoeTheme.washiPaper)
                        Text(".")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(KoeTheme.vermilion)
                    }
                    Text("voice → clipboard")
                        .font(KoeTheme.monoSmall)
                        .foregroundColor(KoeTheme.washiMuted)
                        .tracking(2.0)
                }

                Spacer()

                // Permissions Section
                VStack(spacing: 16) {
                    permissionRow(
                        icon: "mic.fill",
                        title: "Microphone Access",
                        description: "Used to record audio for transcription",
                        granted: microphoneGranted,
                        action: requestMicrophoneAccess
                    )

                    permissionRow(
                        icon: "keyboard.fill",
                        title: "Accessibility API",
                        description: "Required to detect the global hotkey",
                        granted: accessibilityGranted,
                        action: {
                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                            appState.hotkeyManager?.openAccessibilitySettings()
                        }
                    )
                }
                .padding(.horizontal, 32)

                Spacer()

                // Hotkey Display
                VStack(spacing: 14) {
                    Text(HotkeyConfig.current.displayString)
                        .font(.system(size: 52, weight: .light, design: .monospaced))
                        .foregroundColor(KoeTheme.washiPaper)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(
                            ContinuousRoundedRectangle(cornerRadius: 12)
                                .stroke(KoeTheme.vermilion.opacity(0.3), lineWidth: 1)
                        )

                    Text("Press this anywhere to start recording")
                        .font(KoeTheme.monoTiny)
                        .foregroundColor(KoeTheme.washiMuted)
                        .textCase(.uppercase)
                        .tracking(1.0)
                }
                .padding(.bottom, 40)

                // Warning / Got It Button
                VStack(spacing: 12) {
                    if showPermissionWarning && !allPermissionsGranted {
                        Text("Permissions required for Koe to function.")
                            .font(KoeTheme.monoTiny)
                            .foregroundColor(KoeTheme.vermilion)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Button(action: handleGotIt) {
                        Text("Complete Setup")
                            .font(KoeTheme.monoSmall)
                            .tracking(1.0)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingButtonStyle(
                        isHighlighted: allPermissionsGranted
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KoeTheme.vermilion, lineWidth: 2)
                            .scaleEffect(allPermissionsGranted ? 1.05 : 1.0)
                            .opacity(allPermissionsGranted ? 0 : 0) // Hidden by default, but useful for pulse if we wanted
                    )
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
        }
        .animation(KoeTheme.spring, value: microphoneGranted)
        .animation(KoeTheme.spring, value: accessibilityGranted)
        .animation(KoeTheme.spring, value: showPermissionWarning)
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
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
    }

    private func requestMicrophoneAccess() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Task { @MainActor in
                microphoneGranted = granted
            }
        }
    }

    private func handleGotIt() {
        if allPermissionsGranted {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            appState.completeOnboarding()
        } else {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            withAnimation {
                showPermissionWarning = true
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
            ZStack {
                Circle()
                    .fill(granted ? KoeTheme.vermilion.opacity(0.1) : KoeTheme.washiMuted.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(granted ? KoeTheme.vermilion : KoeTheme.washiMuted)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(KoeTheme.monoSmall)
                    .foregroundColor(KoeTheme.washiPaper)
                Text(description)
                    .font(KoeTheme.monoTiny)
                    .foregroundColor(KoeTheme.washiMuted)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(KoeTheme.vermilion)
            } else {
                Button("Grant", action: action)
                    .font(KoeTheme.monoTiny)
                    .foregroundColor(KoeTheme.vermilion)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        ContinuousRoundedRectangle(cornerRadius: 6)
                            .stroke(KoeTheme.vermilion, lineWidth: 1)
                    )
                    .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(KoeTheme.sumiInkLight)
        .cornerRadius(12)
    }
}

private struct OnboardingButtonStyle: ButtonStyle {
    let isHighlighted: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHighlighted ? KoeTheme.washiPaper : KoeTheme.washiMuted)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    if isHighlighted {
                        KoeTheme.vermilion
                    } else {
                        KoeTheme.sumiInkLight
                    }
                }
            )
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

