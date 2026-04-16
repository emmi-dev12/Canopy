import AppKit

/// Provides a convenience factory for Canopy's right-click status menu.
/// The menu is re-created on each display to stay up to date with permission state.
enum StatusMenuView {
    static func makeMenu(
        onSearch: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        inputMonitoringUnavailable: Bool
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let searchItem = NSMenuItem(title: "Open Canopy  ⌥Space", action: nil, keyEquivalent: "")
        searchItem.isEnabled = true
        searchItem.representedObject = onSearch
        searchItem.action = #selector(NSMenuItem.performAction)
        menu.addItem(searchItem)

        menu.addItem(.separator())

        if inputMonitoringUnavailable {
            let warningItem = NSMenuItem(
                title: "⚠️ Hotkey unavailable (Input Monitoring)",
                action: nil,
                keyEquivalent: ""
            )
            warningItem.isEnabled = false
            menu.addItem(warningItem)

            let fixItem = NSMenuItem(title: "Grant Input Monitoring…", action: nil, keyEquivalent: "")
            fixItem.isEnabled = true
            menu.addItem(fixItem)

            menu.addItem(.separator())
        }

        let settingsItem = NSMenuItem(title: "Settings…", action: nil, keyEquivalent: ",")
        settingsItem.isEnabled = true
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Canopy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }
}

// Helper: make NSMenuItem work with closures
private extension NSMenuItem {
    @objc func performAction() {
        (representedObject as? () -> Void)?()
    }
}
