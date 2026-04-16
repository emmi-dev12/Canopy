import Foundation
import Combine

/// Central search service. Converts a query string into ranked `SearchResult` values.
/// All work is synchronous and in-memory — never blocks the main thread with I/O or AX calls.
final class SearchEngine: ObservableObject {
    private let matcher = SmartMatcher()
    private let ranking: RankingService
    private let enumerator = MenuItemEnumerator()

    // In-memory indices
    private var appIndex: [MenubarApp] = []
    private var folderIndex: [AppFolder] = []
    /// Actions keyed by ownerBundleID; populated lazily in the background.
    private(set) var actionIndex: [String: [NormalizedMenuAction]] = [:]
    /// Tracks which apps have had their actions enumerated.
    private var enumeratedApps = Set<String>()

    init(ranking: RankingService) {
        self.ranking = ranking
    }

    // MARK: - Index updates (called from AppEnvironment via Combine sinks)

    func updateAppIndex(_ apps: [MenubarApp]) {
        var updated = apps
        ranking.applyScores(to: &updated)
        appIndex = updated
        // Kick off background enumeration for newly discovered apps
        enumerateNewApps(updated)
    }

    func updateFolderIndex(_ folders: [AppFolder]) {
        folderIndex = folders
    }

    // MARK: - Search

    /// Returns ranked results.
    /// - Action-intent queries ("wifi off", "bt on") put action results FIRST.
    /// - Apps that matched but had no actions get a `.reveal` fallback injected.
    /// Must be called on the main thread.
    func search(query: String) -> [SearchResult] {
        if query.isEmpty {
            return topResults(limit: 8)
        }

        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return topResults(limit: 8) }

        let appResults   = scoredApps(for: q)
        let actionResults = scoredActions(for: q)
        let folderResults = scoredFolders(for: q)
        let revealResults = revealFallbacks(appResults: appResults, actionResults: actionResults)

        // When the query looks like a direct intent ("wifi off"), surface actions first
        let actionFirst = isActionIntent(q) && !actionResults.isEmpty

        var results: [SearchResult] = []
        if actionFirst {
            results += actionResults.prefix(5)
            results += appResults.prefix(3)
        } else {
            results += appResults.prefix(5)
            results += actionResults.prefix(5)
        }
        results += folderResults.prefix(3)
        results += revealResults   // always at the end — they're a last resort

        // Re-sort within the assembled list but preserve action-first intent weighting
        return actionFirst
            ? results   // order already prioritised above
            : results.sorted { $0.score > $1.score }
    }

    // MARK: - Smart suggestions (empty query)

    private func topResults(limit: Int) -> [SearchResult] {
        let apps = appIndex
            .sorted { $0.usageScore > $1.usageScore }
            .prefix(limit)
            .map { SearchResult.app($0) }
        return Array(apps)
    }

    // MARK: - Scoring helpers

    private func scoredApps(for query: String) -> [SearchResult] {
        appIndex.compactMap { app -> SearchResult? in
            let textScore = matcher.score(query, against: app.name)
            guard textScore >= SmartMatcher.threshold else { return nil }
            let boost = ranking.queryBoost(for: app.bundleIdentifier, query: query)
            var scored = app
            scored.usageScore = textScore * 0.6 + app.usageScore * 0.4
            scored.usageScore *= boost
            return .app(scored)
        }
        .sorted { $0.score > $1.score }
    }

    private func scoredActions(for query: String) -> [SearchResult] {
        let allApps = Dictionary(uniqueKeysWithValues: appIndex.map { ($0.bundleIdentifier, $0) })

        return actionIndex.values.joined().compactMap { action -> SearchResult? in
            let textScore = matcher.score(query, against: action.searchableText)
            guard textScore >= SmartMatcher.threshold else { return nil }
            guard let ownerApp = allApps[action.ownerBundleID] else { return nil }
            let boost = ranking.queryBoost(for: action.id, query: query)
            var scored = action
            scored.usageScore = textScore * 0.7 + action.usageScore * 0.3
            scored.usageScore *= boost
            return .action(scored, ownerApp: ownerApp)
        }
        .sorted { $0.score > $1.score }
    }

    private func scoredFolders(for query: String) -> [SearchResult] {
        folderIndex.compactMap { folder -> SearchResult? in
            let textScore = matcher.score(query, against: folder.name)
            guard textScore >= SmartMatcher.threshold else { return nil }
            var scored = folder
            scored.usageScore = textScore * 0.6 + folder.usageScore * 0.4
            return .folder(scored)
        }
        .sorted { $0.score > $1.score }
    }

    // MARK: - Action intent detection

    /// Returns true when the query looks like the user wants to trigger an action rather
    /// than find an app. Used to flip the result ordering so actions appear first.
    private func isActionIntent(_ query: String) -> Bool {
        let q = query.lowercased()
        let actionTriggers = [
            "on", "off", "enable", "disable", "toggle",
            "turn on", "turn off", "open", "close", "quit",
            "connect", "disconnect", "pause", "resume",
            "mute", "unmute", "start", "stop", "show", "hide",
            "restart", "reboot", "lock", "sleep",
        ]
        return actionTriggers.contains(where: { q.contains($0) })
    }

    // MARK: - Reveal fallback injection

    /// For each top-scoring app that has no matching actions in the result set,
    /// injects a `.reveal(app)` result so there's always something useful to do.
    /// Only injected for apps whose AX enumeration has already run (to avoid
    /// premature fallbacks during the initial background scan).
    private func revealFallbacks(
        appResults: [SearchResult],
        actionResults: [SearchResult]
    ) -> [SearchResult] {
        // Collect bundle IDs that already have action results
        let coveredBundleIDs = Set(actionResults.compactMap { result -> String? in
            if case .action(_, let owner) = result { return owner.bundleIdentifier }
            return nil
        })

        return appResults.prefix(3).compactMap { result -> SearchResult? in
            guard case .app(let app) = result else { return nil }
            // Only inject reveal if:
            // 1. This app has no actions in the current result set
            // 2. AX enumeration has completed for this app (avoid flicker during initial scan)
            let hasBeenEnumerated = enumeratedApps.contains(app.bundleIdentifier)
            let hasCoveredActions = coveredBundleIDs.contains(app.bundleIdentifier)
            guard hasBeenEnumerated && !hasCoveredActions else { return nil }
            return .reveal(app)
        }
    }

    // MARK: - Background AX enumeration

    private func enumerateNewApps(_ apps: [MenubarApp]) {
        let toEnumerate = apps.filter { !enumeratedApps.contains($0.bundleIdentifier) }
        guard !toEnumerate.isEmpty else { return }

        for app in toEnumerate {
            enumeratedApps.insert(app.bundleIdentifier)
            Task.detached(priority: .background) { [weak self] in
                guard let self else { return }
                var actions = await self.enumerator.enumerate(for: app)
                self.ranking.applyScores(to: &actions)
                await MainActor.run {
                    self.actionIndex[app.bundleIdentifier] = actions
                }
            }
        }
    }

    /// Forces re-enumeration of a specific app (e.g. after the user grants AX permission).
    func reenumerate(app: MenubarApp) {
        enumeratedApps.remove(app.bundleIdentifier)
        enumerateNewApps([app])
    }
}
