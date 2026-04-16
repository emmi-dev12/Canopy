import AppKit
import SwiftUI

/// Manages Canopy's own NSStatusItem in the system menubar.
final class StatusItemController {
    private var statusItem: NSStatusItem?
    var onToggleOverlay: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        button.image = NSImage(systemSymbolName: "binoculars", accessibilityDescription: "Canopy")
        button.image?.isTemplate = true  // tints correctly in both light and dark modes
        button.action = #selector(statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            onToggleOverlay?()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        let searchItem = NSMenuItem(title: "Search (⌥Space)", action: #selector(handleSearch), keyEquivalent: "")
        searchItem.target = self
        menu.addItem(searchItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(handleSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Canopy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil  // remove after display so left-click works normally
    }

    @objc private func handleSearch() { onToggleOverlay?() }
    @objc private func handleSettings() { onOpenSettings?() }

    func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
}
