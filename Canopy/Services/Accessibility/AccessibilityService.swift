import AppKit
import ApplicationServices
import Combine

/// Manages Accessibility permission state and provides a polling mechanism to detect
/// when the user grants permission in System Settings.
final class AccessibilityService: ObservableObject {
    @Published private(set) var isTrusted: Bool = false

    private var pollTimer: Timer?

    init() {
        isTrusted = AXIsProcessTrusted()
    }

    /// Checks current trust status. If not trusted, triggers the macOS system prompt
    /// that directs the user to Privacy & Security > Accessibility.
    /// - Returns: `true` if already trusted.
    @discardableResult
    func checkAndRequestPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        isTrusted = trusted
        return trusted
    }

    /// Starts polling every second for permission changes (called while System Settings is open).
    func startPolling() {
        guard !isTrusted else { return }
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let trusted = AXIsProcessTrusted()
            if trusted {
                DispatchQueue.main.async {
                    self.isTrusted = true
                }
                timer.invalidate()
                self.pollTimer = nil
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    deinit { stopPolling() }
}
