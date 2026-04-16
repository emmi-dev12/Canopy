import Foundation

/// A single recorded interaction, used to update the decay-weighted usage score.
struct UsageEvent: Codable {
    /// The persistence key for this item (bundleID for apps, stable action ID for actions).
    let key: String
    /// The raw query the user typed when selecting this result. Used for query-context boosting.
    let queryAtTime: String
    let timestamp: Date

    init(key: String, queryAtTime: String, timestamp: Date = .now) {
        self.key = key
        self.queryAtTime = queryAtTime
        self.timestamp = timestamp
    }
}

/// Persisted record for one item's aggregated usage (stored in usage.json).
struct UsageRecord: Codable {
    var key: String
    var totalCount: Int
    var lastUsedAt: Date
    /// Exponentially decayed score; updated incrementally on each use.
    var decayedScore: Double
}

/// Maps a normalized query to the result key that was most recently selected for it.
struct QueryContextRecord: Codable {
    /// Normalized (lowercased, trimmed) query string.
    var queryHash: String
    /// The key of the result selected while this query was active.
    var selectedKey: String
    var count: Int
}
