import Foundation

/// Fast, multi-strategy string matcher for search results.
/// Scoring ladder (highest wins):
///   1.00 — exact match
///   0.95 — prefix match (candidate starts with query)
///   0.85 — substring match
///   0.80 — acronym prefix match ("wf" → "Wi-Fi", "cal" → "Calendar")
///   0.40–0.79 — bigram overlap (fuzzy)
///   0.00 — no match (below threshold)
struct SmartMatcher {
    /// Minimum score below which a result is excluded from search output.
    static let threshold: Double = 0.30

    /// Returns a score in [0, 1] for how well `query` matches `candidate`.
    func score(_ query: String, against candidate: String) -> Double {
        guard !query.isEmpty, !candidate.isEmpty else { return 0 }

        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        let c = candidate.lowercased().trimmingCharacters(in: .whitespaces)

        guard !q.isEmpty else { return 0 }

        // 1. Exact
        if c == q { return 1.0 }

        // 2. Prefix
        if c.hasPrefix(q) { return 0.95 }

        // 3. Substring
        if c.contains(q) { return 0.85 }

        // 4. Acronym prefix — e.g. query "wf" matches candidate "wi-fi", "cal" matches "calendar"
        let acronym = makeAcronym(c)
        if !acronym.isEmpty && acronym.hasPrefix(q) { return 0.80 }

        // 5. Word-prefix — any word in candidate starts with query
        let words = c.components(separatedBy: .init(charactersIn: " -_./"))
        if words.contains(where: { $0.hasPrefix(q) }) { return 0.75 }

        // 6. Bigram overlap — scaled into [0, 0.70]
        let overlap = bigramOverlap(q, c)
        return overlap * 0.70
    }

    // MARK: - Private helpers

    private func makeAcronym(_ s: String) -> String {
        s.components(separatedBy: .init(charactersIn: " -_"))
            .compactMap { $0.first.map(String.init) }
            .joined()
    }

    private func bigramOverlap(_ a: String, _ b: String) -> Double {
        let aBigrams = bigrams(a)
        let bBigrams = bigrams(b)
        guard !aBigrams.isEmpty, !bBigrams.isEmpty else { return 0 }

        var bSet = bBigrams
        var matches = 0
        for gram in aBigrams {
            if let idx = bSet.firstIndex(of: gram) {
                matches += 1
                bSet.remove(at: idx)
            }
        }
        return Double(2 * matches) / Double(aBigrams.count + bBigrams.count)
    }

    private func bigrams(_ s: String) -> [String] {
        guard s.count >= 2 else { return [s] }
        let chars = Array(s)
        return zip(chars, chars.dropFirst()).map { "\($0)\($1)" }
    }
}
