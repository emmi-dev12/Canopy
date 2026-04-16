import Foundation

/// A normalized, searchable representation of an AX menu item discovered inside a menubar app.
/// The `id` is stable across enumerations so usage scores can be persisted correctly.
struct NormalizedMenuAction: Identifiable, Hashable {
    /// Stable ID: sha-like hash of ownerBundleID + joined flatPath.
    let id: String
    /// Human-readable title, cleaned of whitespace, ellipses, and redundancy.
    let displayTitle: String
    /// Flattened path from the status item root, e.g. ["Control Center", "Wi-Fi"].
    let flatPath: [String]
    /// Title + synonyms + acronym, lowercased, used for matching.
    let searchableText: String
    /// Bundle identifier of the app that owns this action.
    let ownerBundleID: String
    /// Usage score populated by RankingService at query time.
    var usageScore: Double

    init(displayTitle: String, flatPath: [String], ownerBundleID: String, usageScore: Double = 0) {
        self.displayTitle = displayTitle
        self.flatPath = flatPath
        self.ownerBundleID = ownerBundleID
        self.usageScore = usageScore

        // Stable ID: hash of bundle ID + path
        let raw = ownerBundleID + "::" + flatPath.joined(separator: "/")
        self.id = raw.stableID

        // Searchable text: title + path context + acronym
        let pathContext = flatPath.dropLast().joined(separator: " ")
        let acronym = displayTitle
            .components(separatedBy: .whitespaces)
            .compactMap { $0.first.map(String.init) }
            .joined()
        self.searchableText = [displayTitle, pathContext, acronym]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    /// Breadcrumb string for display: "Wi-Fi › Turn Off"
    var breadcrumb: String {
        flatPath.joined(separator: " › ")
    }

    static func == (lhs: NormalizedMenuAction, rhs: NormalizedMenuAction) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Stable ID helper

private extension String {
    var stableID: String {
        var hash: UInt64 = 5381
        for byte in utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(format: "%016llx", hash)
    }
}
