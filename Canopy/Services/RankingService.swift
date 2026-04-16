import Foundation
import Combine

/// Computes and persists decay-weighted usage scores.
/// Maintains an in-memory cache of scores for hot-path query performance.
final class RankingService {
    private let usageStore: UsageStore
    private let decay = DecayCalculator()

    /// In-memory score cache: key → (decayedScore, lastUsedAt)
    private var scoreCache: [String: (Double, Date)] = [:]

    /// In-memory query context: normalizedQuery → selectedKey
    private var queryContext: [String: String] = [:]

    init(usageStore: UsageStore) {
        self.usageStore = usageStore
        preloadCache()
    }

    // MARK: - Query-time scoring

    /// Returns the current normalized score for a persistence key.
    func score(for key: String) -> Double {
        guard let (stored, scoredAt) = scoreCache[key] else { return 0 }
        let raw = decay.currentScore(storedScore: stored, scoredAt: scoredAt)
        return decay.normalizedScore(raw)
    }

    /// Returns a 1.5× boost multiplier if this key was previously selected for a similar query.
    func queryBoost(for key: String, query: String) -> Double {
        let normalized = normalizeQuery(query)
        guard !normalized.isEmpty else { return 1.0 }
        return queryContext[normalized] == key ? 1.5 : 1.0
    }

    // MARK: - Recording a use event

    /// Records a selection and updates the persisted + cached score.
    func recordUse(key: String, query: String) {
        let now = Date.now
        let (prev, prevDate) = scoreCache[key] ?? (0, now)
        let newScore = decay.updateScore(previousScore: prev, scoredAt: prevDate, now: now)

        scoreCache[key] = (newScore, now)
        usageStore.upsert(UsageRecord(key: key, totalCount: 0, lastUsedAt: now, decayedScore: newScore))

        // Update query context
        let normalizedQuery = normalizeQuery(query)
        if !normalizedQuery.isEmpty {
            queryContext[normalizedQuery] = key
            usageStore.upsertQueryContext(QueryContextRecord(
                queryHash: normalizedQuery,
                selectedKey: key,
                count: (usageStore.queryContextRecord(for: normalizedQuery)?.count ?? 0) + 1
            ))
        }
    }

    // MARK: - Bulk score refresh (called when app list updates)

    func applyScores(to apps: inout [MenubarApp]) {
        for i in apps.indices {
            apps[i].usageScore = score(for: apps[i].bundleIdentifier)
        }
    }

    func applyScores(to actions: inout [NormalizedMenuAction]) {
        for i in actions.indices {
            actions[i].usageScore = score(for: actions[i].id)
        }
    }

    // MARK: - Private

    private func preloadCache() {
        let records = usageStore.allUsageRecords()
        for record in records {
            scoreCache[record.key] = (record.decayedScore, record.lastUsedAt)
        }
        let contexts = usageStore.allQueryContextRecords()
        for ctx in contexts {
            queryContext[ctx.queryHash] = ctx.selectedKey
        }
    }

    private func normalizeQuery(_ query: String) -> String {
        query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
