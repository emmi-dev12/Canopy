import Foundation

/// Computes time-decay exponential scores for usage-based ranking.
///
/// Formula: score = Σ exp(−λ·Δt) where Δt is the age in days of each use event.
/// Stored as an aggregate: the decayed score is updated incrementally on each new use,
/// avoiding the need to store the full event history.
///
/// Half-life of 14 days means something used two weeks ago counts for half as much as
/// something used today.
struct DecayCalculator {
    let halfLifeDays: Double

    init(halfLifeDays: Double = 14) {
        self.halfLifeDays = halfLifeDays
    }

    private var lambda: Double { log(2) / halfLifeDays }

    /// Called when a new use event occurs.
    /// - Parameters:
    ///   - previousScore: The stored decayed score.
    ///   - scoredAt: When `previousScore` was last computed (i.e. the previous use time).
    ///   - now: Current time (injectable for testing).
    /// - Returns: Updated score reflecting the decayed previous value plus +1 for this new use.
    func updateScore(previousScore: Double, scoredAt: Date, now: Date = .now) -> Double {
        let ageDays = now.timeIntervalSince(scoredAt) / 86_400
        let decayed = previousScore * exp(-lambda * ageDays)
        return decayed + 1.0
    }

    /// Called at query time to get the current score without writing a new event.
    /// - Parameters:
    ///   - storedScore: The last persisted decayed score.
    ///   - scoredAt: When `storedScore` was last computed.
    ///   - now: Current time.
    func currentScore(storedScore: Double, scoredAt: Date, now: Date = .now) -> Double {
        guard storedScore > 0 else { return 0 }
        let ageDays = now.timeIntervalSince(scoredAt) / 86_400
        return storedScore * exp(-lambda * ageDays)
    }

    /// Normalizes a raw decayed score into [0, 1] using a soft-max cap.
    /// A score of ~10 (using roughly once a day for two weeks) maps to about 0.8.
    func normalizedScore(_ rawScore: Double) -> Double {
        rawScore / (rawScore + 5.0)
    }
}
