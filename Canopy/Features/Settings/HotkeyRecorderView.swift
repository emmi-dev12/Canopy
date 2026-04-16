import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A view that lets the user record a new global hotkey.
/// Displays the current hotkey and enters a "recording" state when clicked.
struct HotkeyRecorderView: View {
    @Binding var keyCode: UInt16
    @Binding var modifiers: NSEvent.ModifierFlags
    var onChanged: ((UInt16, NSEvent.ModifierFlags) -> Void)?

    @State private var isRecording = false
    @State private var localMonitor: Any?

    var body: some View {
        HStack {
            Text(isRecording ? "Press a key combination…" : hotkeyDescription)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(isRecording ? .blue : .primary)

            Spacer()

            if isRecording {
                Button("Cancel") { stopRecording() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            } else {
                Button("Record") { startRecording() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isRecording ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var hotkeyDescription: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option)  { parts.append("⌥") }
        if modifiers.contains(.shift)   { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    private func keyCodeToString(_ code: UInt16) -> String {
        // Map common key codes to readable names
        let map: [UInt16: String] = [
            49: "Space", 36: "↩", 53: "⎋",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            117: "⌦", 51: "⌫"
        ]
        if let name = map[code] { return name }

        // Try to get the key character from the key code
        var deadKeys: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let source = TISCopyCurrentKeyboardLayoutInputSource()
        if let src = source?.takeRetainedValue(),
           let data = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) {
            let layout = unsafeBitCast(data, to: CFData.self)
            let ptr = CFDataGetBytePtr(layout)
            let keyLayout = ptr?.bindMemory(to: UCKeyboardLayout.self, capacity: 1)
            UCKeyTranslate(
                keyLayout, code, UInt16(kUCKeyActionDisplay),
                0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeys, 4, &length, &chars
            )
        }
        if length > 0, let scalar = Unicode.Scalar(chars[0]) {
            return String(scalar).uppercased()
        }
        return "Key \(code)"
    }

    // MARK: - Recording

    private func startRecording() {
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            guard isRecording else { return event }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            // Require at least one modifier (prevent bare key presses as hotkeys)
            guard !mods.isEmpty else { return event }
            let newCode = event.keyCode
            keyCode = newCode
            modifiers = mods
            onChanged?(newCode, mods)
            stopRecording()
            return nil  // consume the event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
