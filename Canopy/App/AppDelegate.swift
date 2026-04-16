import AppKit

/// NSApplicationDelegate that bootstraps the app environment and prevents the app
/// from quitting when all windows are closed (it's a pure menubar app).
final class AppDelegate: NSObject, NSApplicationDelegate {
    var environment: AppEnvironment!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement = YES hides the Dock icon + Cmd-Tab entry (set in Info.plist)
        environment = AppEnvironment()
        environment.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // The app lives in the menubar; closing Settings should not quit it
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment.statusItemController.teardown()
    }
}
