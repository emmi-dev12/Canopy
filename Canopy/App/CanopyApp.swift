import SwiftUI

/// App entry point. Uses NSApplicationDelegateAdaptor to bridge to AppDelegate,
/// which bootstraps the full AppEnvironment.
///
/// The only SwiftUI Scene is the Settings window — all other UI (the overlay) is
/// an NSPanel managed imperatively by OverlayWindowController.
@main
struct CanopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.environment)
        }
    }
}
