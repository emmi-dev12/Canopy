import AppKit
import Carbon.HIToolbox

/// Registers and handles the global hotkey that triggers the Canopy overlay.
///
/// Strategy:
/// - Primary: CGEventTap — works even without a focused window, requires Input Monitoring.
/// - Fallback: Carbon RegisterEventHotKey — less powerful but no special permission needed.
final class HotkeyService {
    /// Called on the main thread when the hotkey is pressed.
    var onActivate: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var carbonHotKeyRef: EventHotKeyRef?
    private var carbonEventHandlerRef: EventHandlerRef?
    private var registeredKeyCode: UInt16 = 49      // Space
    private var registeredModifiers: NSEvent.ModifierFlags = [.option]

    // MARK: - Registration

    /// Registers the hotkey. Falls back to Carbon if CGEventTap is unavailable.
    func register(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        unregister()
        self.registeredKeyCode = keyCode
        self.registeredModifiers = modifiers

        if !tryRegisterEventTap(keyCode: keyCode, modifiers: modifiers) {
            tryRegisterCarbon(keyCode: keyCode, modifiers: modifiers)
        }
    }

    func unregister() {
        // Remove CGEventTap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
        // Remove Carbon hotkey
        if let ref = carbonHotKeyRef {
            UnregisterEventHotKey(ref)
            carbonHotKeyRef = nil
        }
        if let ref = carbonEventHandlerRef {
            RemoveEventHandler(ref)
            carbonEventHandlerRef = nil
        }
    }

    deinit { unregister() }

    // MARK: - CGEventTap

    private func tryRegisterEventTap(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        // We need a C-compatible callback — use an unmanaged self pointer
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()
                return service.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        )

        guard let tap else {
            // CGEventTap failed — likely Input Monitoring not granted
            NotificationCenter.default.post(name: .canopyInputMonitoringUnavailable, object: nil)
            return false
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = src
        return true
    }

    private func handleCGEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let wantedFlags = cgFlags(from: registeredModifiers)

        guard code == registeredKeyCode,
              flags.intersection(wantedFlags) == wantedFlags else {
            return Unmanaged.passUnretained(event)
        }

        DispatchQueue.main.async { [weak self] in self?.onActivate?() }
        return nil  // consume the event
    }

    private func cgFlags(from modifiers: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option)  { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift)   { flags.insert(.maskShift) }
        return flags
    }

    // MARK: - Carbon fallback

    private func tryRegisterCarbon(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.option)  { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if modifiers.contains(.shift)   { carbonModifiers |= UInt32(shiftKey) }

        let id = EventHotKeyID(signature: OSType(0x43414E59), id: 1)  // "CANY"
        var hotKeyRef: EventHotKeyRef?
        RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        carbonHotKeyRef = hotKeyRef

        // Install a Carbon event handler to receive the hotkey event
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, refcon -> OSStatus in
                guard let refcon else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()
                DispatchQueue.main.async { service.onActivate?() }
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &carbonEventHandlerRef
        )
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let canopyInputMonitoringUnavailable = Notification.Name("canopyInputMonitoringUnavailable")
}
