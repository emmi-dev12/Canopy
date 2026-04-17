import Foundation

/// Cleans and normalizes raw AX menu item titles into searchable `NormalizedMenuAction` values.
struct MenuItemNormalizer {

    // MARK: - Synonym table for instant-action matching

    /// Maps common shorthand terms to canonical searchable words.
    private static let synonyms: [String: [String]] = [
        "wi-fi":      ["wifi", "wlan", "wireless", "internet"],
        "bluetooth":  ["bt"],
        "enable":     ["on", "turn on", "activate"],
        "disable":    ["off", "turn off", "deactivate"],
        "vpn":        ["virtual private network", "tunnel"],
        "do not disturb": ["dnd", "focus", "quiet"],
        "dark mode":  ["night mode", "dark theme"],
        "brightness": ["screen brightness", "display brightness"],
        "volume":     ["sound", "audio"],
        "mute":       ["silence", "quiet"],
    ]

    // MARK: - Normalization

    /// Converts a raw AX title + path into a `NormalizedMenuAction`, or nil if it should be skipped.
    func normalize(
        rawTitle: String,
        flatPath: [String],
        ownerBundleID: String
    ) -> NormalizedMenuAction? {
        let cleaned = clean(rawTitle)
        guard !cleaned.isEmpty, !shouldSkip(cleaned) else { return nil }

        let enrichedPath = flatPath.map { clean($0) }.filter { !$0.isEmpty }

        return NormalizedMenuAction(
            displayTitle: cleaned,
            flatPath: enrichedPath.isEmpty ? [cleaned] : enrichedPath,
            ownerBundleID: ownerBundleID
        )
    }

    // MARK: - Helpers

    /// Removes trailing ellipses, collapses whitespace, strips invisible characters.
    func clean(_ title: String) -> String {
        var s = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: "...", with: "")
        // Collapse multiple spaces
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns true for items that are not useful search targets.
    private func shouldSkip(_ title: String) -> Bool {
        let lower = title.lowercased()
        // Skip separators, empty titles, and pure punctuation
        if title.count <= 1 { return true }
        if title.allSatisfy({ $0.isPunctuation || $0.isWhitespace }) { return true }
        // Skip "Services" submenus which are typically OS-level noise
        if lower == "services" { return true }
        return false
    }

    private func buildSearchableText(for title: String) -> String {
        let lower = title.lowercased()
        var parts = [lower]

        // Add matching synonyms
        for (canonical, syns) in Self.synonyms {
            if lower.contains(canonical) {
                parts.append(contentsOf: syns)
            }
            for syn in syns {
                if lower.contains(syn) {
                    parts.append(canonical)
                    break
                }
            }
        }

        // Add acronym
        let acronym = title
            .components(separatedBy: .init(charactersIn: " -_"))
            .compactMap { $0.first.map(String.init) }
            .joined()
            .lowercased()
        if acronym.count >= 2 { parts.append(acronym) }

        return parts.joined(separator: " ")
    }
}
