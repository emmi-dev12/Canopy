import AppKit

/// Represents a running application that has a menubar (status bar) presence.
/// Equality and hashing are based on `bundleIdentifier` for stable identity across launches.
struct MenubarApp: Identifiable, Hashable {
    let id: UUID
    let bundleIdentifier: String  // Falls back to "pid.<pid>" for system components with no bundle ID
    let name: String
    let icon: NSImage?
    let pid: pid_t
    var folderID: UUID?
    var usageScore: Double

    init(from app: NSRunningApplication, folderID: UUID? = nil, usageScore: Double = 0) {
        // Use bundle ID if available; fall back to process name + pid for system components
        let bid = app.bundleIdentifier
            ?? app.executableURL?.deletingPathExtension().lastPathComponent.lowercased()
            .map { "proc.\($0)" }
            ?? "pid.\(app.processIdentifier)"
        self.bundleIdentifier = bid
        // Deterministic UUID derived from bundle identifier so the id is stable within a session
        self.id = UUID(uuidString: bid.stableUUIDString) ?? UUID()
        self.name = app.localizedName ?? bid
        self.icon = app.icon
        self.pid = app.processIdentifier
        self.folderID = folderID
        self.usageScore = usageScore
    }

    // Equality and hashing by bundle identifier so de-dup works correctly
    static func == (lhs: MenubarApp, rhs: MenubarApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
}

// MARK: - String → stable UUID helper

private extension String {
    /// Produces a deterministic UUID-shaped string from any string using DJB2 hashing.
    /// Not cryptographically secure — only used for SwiftUI identity, not persistence keys.
    var stableUUIDString: String {
        var hash: UInt64 = 5381
        for byte in utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        let h = String(format: "%016llx", hash)
        // Format: 8-4-4-4-12 (pad with zeros)
        let s = h.padding(toLength: 32, withPad: "0", startingAt: 0)
        let a = s.prefix(8)
        let b = s.dropFirst(8).prefix(4)
        let c = s.dropFirst(12).prefix(4)
        let d = s.dropFirst(16).prefix(4)
        let e = s.dropFirst(20).prefix(12).padding(toLength: 12, withPad: "0", startingAt: 0)
        return "\(a)-\(b)-\(c)-\(d)-\(e)"
    }
}
