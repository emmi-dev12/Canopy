import AppKit

/// Heuristically determines whether a running application has a menubar (status bar) presence.
/// There is no public API to enumerate NSStatusItems from other processes, so we filter by
/// activation policy and window state.
struct MenubarPresenceChecker {

    /// Bundle identifiers of system processes that should always be excluded.
    private static let excludedBundleIDs: Set<String> = [
        "com.apple.dock",
        "com.apple.finder",
        "com.apple.loginwindow",
        "com.apple.WindowServer",
        "com.apple.SystemUIServer",    // handles system menu extras — included separately
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.universalaccessd"
    ]

    /// Returns true if `app` is likely to have a menubar/status-bar presence.
    func likelyHasMenubarPresence(_ app: NSRunningApplication) -> Bool {
        // Never include ourselves
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }

        // Exclude known system background processes
        if let bid = app.bundleIdentifier, Self.excludedBundleIDs.contains(bid) { return false }

        switch app.activationPolicy {
        case .accessory:
            // Pure menubar/background apps (Bartender, Dropzone, etc.) — always include
            return true
        case .prohibited:
            // Daemons with no UI — generally exclude, but some have status items
            // Include only if they have a bundle ID (i.e. are real apps, not bare daemons)
            return app.bundleIdentifier != nil
        case .regular:
            // Regular apps: include if they have no visible main window
            // (e.g. Fantastical, Spark — regular policy but live primarily in menubar)
            return !hasVisibleMainWindow(app)
        @unknown default:
            return false
        }
    }

    // MARK: - Private

    private func hasVisibleMainWindow(_ app: NSRunningApplication) -> Bool {
        let options: CGWindowListOption = [.excludeDesktopElements, .optionOnScreenOnly]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return list.contains { info in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == app.processIdentifier,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,                            // normal window layer
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = bounds["Width"], width > 50,
                  let height = bounds["Height"], height > 50
            else { return false }
            return true
        }
    }
}
