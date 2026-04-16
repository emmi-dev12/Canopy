import AppKit
import ApplicationServices

/// Activates (triggers) a `NormalizedMenuAction` via the AX API.
///
/// Strategy:
/// 1. Attempt the AX press directly.
/// 2. If it fails, temporarily activate the owning app, retry once, then restore focus.
final class MenuItemActivator {

    enum ActivationError: Error {
        case appNotRunning
        case elementNotFound
        case axError(AXError)
    }

    /// Attempt to activate the action. The `app` is needed to find the AX element and optionally
    /// bring it to the front.
    func activate(_ action: NormalizedMenuAction, in app: MenubarApp) async throws {
        guard let pid = app.pid else { throw ActivationError.appNotRunning }

        let axApp = AXHelpers.applicationElement(for: pid)

        // Try direct activation first (doesn't steal focus)
        if tryActivate(action: action, in: axApp) { return }

        // Fallback: temporarily activate the target app and retry
        let previousApp = NSWorkspace.shared.frontmostApplication
        let targetApp = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first

        targetApp?.activate(options: [.activateIgnoringOtherApps])
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms for app to come forward

        let success = tryActivate(action: action, in: axApp)

        // Restore the previously active app
        previousApp?.activate(options: [.activateIgnoringOtherApps])

        if !success { throw ActivationError.elementNotFound }
    }

    // MARK: - Private

    private func tryActivate(action: NormalizedMenuAction, in axApp: AXUIElement) -> Bool {
        guard let menuBar: AXUIElement = AXHelpers.menuBar(of: axApp) else { return false }
        return findAndPress(
            matching: action.flatPath,
            in: menuBar,
            depth: 0
        )
    }

    /// Recursively navigates the AX tree following `pathComponents`, pressing the final element.
    private func findAndPress(
        matching pathComponents: [String],
        in element: AXUIElement,
        depth: Int
    ) -> Bool {
        guard depth < pathComponents.count else { return false }

        let target = pathComponents[depth].lowercased()
        let children = AXHelpers.children(of: element) ?? []

        for child in children {
            let title = (AXHelpers.title(of: child) ?? "").lowercased()
            guard title == target || title.hasPrefix(target) else { continue }

            if depth == pathComponents.count - 1 {
                // We found the target element — press it
                return AXHelpers.perform(action: kAXPressAction, on: child)
            } else {
                // Navigate deeper
                if findAndPress(matching: pathComponents, in: child, depth: depth + 1) {
                    return true
                }
            }
        }
        return false
    }
}
