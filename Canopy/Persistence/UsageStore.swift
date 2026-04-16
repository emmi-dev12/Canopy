import Foundation
import Combine

/// Persists and retrieves UsageRecord and QueryContextRecord values.
/// In-memory cache backed by JSON files in Application Support.
final class UsageStore {
    private let persistence: PersistenceController
    private var usageCache: [String: UsageRecord] = [:]
    private var queryCache: [String: QueryContextRecord] = [:]

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        loadAll()
    }

    // MARK: - Usage records

    func allUsageRecords() -> [UsageRecord] {
        Array(usageCache.values)
    }

    func usageRecord(for key: String) -> UsageRecord? {
        usageCache[key]
    }

    func upsert(_ record: UsageRecord) {
        var updated = record
        if let existing = usageCache[record.key] {
            updated = UsageRecord(
                key: record.key,
                totalCount: existing.totalCount + 1,
                lastUsedAt: record.lastUsedAt,
                decayedScore: record.decayedScore
            )
        } else {
            updated = UsageRecord(
                key: record.key,
                totalCount: 1,
                lastUsedAt: record.lastUsedAt,
                decayedScore: record.decayedScore
            )
        }
        usageCache[record.key] = updated
        persist()
    }

    // MARK: - Query context records

    func allQueryContextRecords() -> [QueryContextRecord] {
        Array(queryCache.values)
    }

    func queryContextRecord(for queryHash: String) -> QueryContextRecord? {
        queryCache[queryHash]
    }

    func upsertQueryContext(_ record: QueryContextRecord) {
        queryCache[record.queryHash] = record
        persistQueryContext()
    }

    // MARK: - Persistence

    private func loadAll() {
        if let records = persistence.load([UsageRecord].self, from: persistence.usageRecordsURL) {
            usageCache = Dictionary(uniqueKeysWithValues: records.map { ($0.key, $0) })
        }
        if let contexts = persistence.load([QueryContextRecord].self, from: persistence.queryContextURL) {
            queryCache = Dictionary(uniqueKeysWithValues: contexts.map { ($0.queryHash, $0) })
        }
    }

    private func persist() {
        let records = Array(usageCache.values)
        persistence.save(records, to: persistence.usageRecordsURL)
    }

    private func persistQueryContext() {
        let records = Array(queryCache.values)
        persistence.save(records, to: persistence.queryContextURL)
    }
}
