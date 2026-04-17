import AppKit
import SwiftUI

/// Manages the floating Spotlight-style search panel.
///
/// The panel:
/// - Uses `.nonactivatingPanel` so it never steals focus from the previously active app
/// - Sits at `.popUpMenu` window level — above virtually everything including the menubar
/// - Joins all Spaces so it's always accessible regardless of the current desktop
final class OverlayWindowController: NSWindowController {
    private weak var viewModel: OverlayViewModel?
    private var outsideClickMonitor: Any?
    private var isVisible = false

    convenience init(viewModel: OverlayViewModel) {
        let panel = Self.makePanel()
        self.init(window: panel)
        self.viewModel = viewModel

        let root = OverlayView(viewModel: viewModel)
        panel.contentView = NSHostingView(rootView: root)
    }

    // MARK: - Show / hide

    func show() {
        guard !isVisible else { return }
        isVisible = true
        positionPanel()
        viewModel?.prepareForPresentation()
        window?.alphaValue = 0
        window?.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            window?.animator().alphaValue = 1
        }
        installOutsideClickMonitor()
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        removeOutsideClickMonitor()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.10
            window?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        })
        viewModel?.clearOnDismiss()
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    // MARK: - Panel setup

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 480),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        return panel
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let panelSize = NSSize(width: 620, height: 480)
        let x = (screen.frame.width - panelSize.width) / 2 + screen.frame.minX
        // ~38% from top — above center, Spotlight-style
        let y = screen.frame.minY + screen.frame.height * 0.62 - panelSize.height / 2
        window?.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: panelSize), display: false)
    }

    // MARK: - Dismiss on outside click

    private func installOutsideClickMonitor() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self, let panel = self.window else { return }
            // If the click is outside the panel bounds, dismiss
            let locationInScreen = NSEvent.mouseLocation
            if !panel.frame.contains(locationInScreen) {
                DispatchQueue.main.async { self.hide() }
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}
