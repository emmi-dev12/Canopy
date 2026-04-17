import SwiftUI
import AppKit

/// Onboarding screen shown at first launch when Accessibility permission is not granted.
/// Guides the user through granting both Accessibility and Input Monitoring.
struct PermissionsView: View {
    @ObservedObject var accessibility: AccessibilityService
    @ObservedObject var hotkeyService: HotkeyService
    @State private var showingInputMonitoringTip = false

    var body: some View {
        VStack(spacing: 32) {
            // App icon + title
            VStack(spacing: 12) {
                Image(systemName: "binoculars.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Canopy needs a few permissions")
                    .font(.system(size: 20, weight: .semibold))

                Text("These are required to search and interact with your menubar apps.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            // Permission rows
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: "Lets Canopy read menu items from other apps.",
                    isGranted: accessibility.isTrusted,
                    action: {
                        accessibility.checkAndRequestPermission()
                        accessibility.startPolling()
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        )
                    }
                )

                PermissionRow(
                    icon: "keyboard",
                    title: "Input Monitoring",
                    description: "Lets Canopy respond to the global hotkey (⌥Space).",
                    isGranted: hotkeyService.inputMonitoringGranted,
                    action: {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
                        )
                    }
                )
            }
            .padding(.horizontal, 40)

            // Continue button
            Button("Continue without all permissions") {
                NSApp.mainWindow?.close()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.system(size: 13))
        }
        .padding(40)
        .frame(width: 500)
    }
}

// MARK: - Permission row

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(isGranted ? .green : .blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 18))
            } else {
                Button("Open Settings", action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
