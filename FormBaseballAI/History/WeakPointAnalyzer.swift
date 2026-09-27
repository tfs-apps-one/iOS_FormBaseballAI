// WeakPointAnalyzer.swift — Aggregates the last few PracticeRecords for one
// FormMode into a "weak point trend" summary: which body-part component is
// most often the session's worst, and whether recent scores are trending up,
// flat, or down.
// Mirrors: tfsapps.formbaseballai.history.WeakPointAnalyzer
//
// Records saved before `componentScores` existed (older app versions) are
// skipped entirely — they simply don't count toward the trend.
// Pure aggregation logic (no UI / storage dependency) so it is unit-testable.

import Foundation

enum WeakPointAnalyzer {

    /// Fixed lookback window: the last 5 valid sessions for a mode.
    static let lookback = 5

    /// Minimum valid sessions needed before the "biggest challenge" is shown.
    static let minForWorstComponent = 3

    /// Minimum valid sessions needed before a trend direction is shown (the full window).
    static let minForTrend = lookback

    /// Points of difference (older-half avg vs newer-half avg) required to call a trend.
    private static let trendThreshold: Float = 5

    /// Number of scored components per session (rightElbow, leftElbow, shoulderLevel, hipLevel, leadKnee).
    static let componentCount = 5

    enum Trend: Equatable { case improving, steady, worsening, pending }

    struct Result: Equatable {
        /// How many valid (componentScores-bearing) sessions were found, 0...lookback.
        let sessionCount: Int
        /// Index into the component name / improvement lists, or -1 if not enough data.
        let worstComponentIndex: Int
        /// How many of sessionCount had worstComponentIndex as their worst-scoring component.
        let worstComponentCount: Int
        let trend: Trend
        let olderAvg: Float
        let newerAvg: Float
        /// Persisted skeleton comparison image (file name) from the most recent valid
        /// session, or nil if none was saved.
        let recentImageFile: String?

        var hasEnoughForWorstComponent: Bool { sessionCount >= WeakPointAnalyzer.minForWorstComponent }
        var hasEnoughForTrend: Bool { sessionCount >= WeakPointAnalyzer.minForTrend }
    }

    /// Analyzes up to the most recent `lookback` sessions of `mode` that carry
    /// component-level scores. `records` must be newest-first (as stored).
    static func analyze(records: [PracticeRecord], mode: FormMode) -> Result {
        var valid = [PracticeRecord]()
        for r in records where r.mode == mode && (r.componentScores?.count ?? 0) == componentCount {
            valid.append(r)
            if valid.count >= lookback { break }
        }

        // valid is newest-first, so its head is the most recent session.
        let recentImageFile = valid.first?.weakPointImageFile

        let n = valid.count
        if n < minForWorstComponent {
            return Result(sessionCount: n, worstComponentIndex: -1, worstComponentCount: 0,
                          trend: .pending, olderAvg: 0, newerAvg: 0, recentImageFile: recentImageFile)
        }

        // Count how many sessions had each component as their worst.
        var worstCounts = [Int](repeating: 0, count: componentCount)
        for r in valid {
            let s = r.componentScores!
            var worstIdx = 0
            for i in 1..<componentCount where s[i] < s[worstIdx] { worstIdx = i }
            worstCounts[worstIdx] += 1
        }

        var topIdx = 0
        for i in 1..<componentCount {
            if worstCounts[i] > worstCounts[topIdx] {
                topIdx = i
            } else if worstCounts[i] == worstCounts[topIdx]
                        && averageFor(valid, i) < averageFor(valid, topIdx) {
                // Tie-break: the component with the lower average score wins.
                topIdx = i
            }
        }

        if n < minForTrend {
            return Result(sessionCount: n, worstComponentIndex: topIdx,
                          worstComponentCount: worstCounts[topIdx], trend: .pending,
                          olderAvg: 0, newerAvg: 0, recentImageFile: recentImageFile)
        }

        // Flip to oldest-first to split into two halves.
        let ascending = Array(valid.reversed())
        let olderCount = ascending.count / 2           // 5 -> 2
        let newerCount = ascending.count - olderCount  // 5 -> 3

        let olderAvg = ascending[0..<olderCount].map(\.score).reduce(0, +) / Float(olderCount)
        let newerAvg = ascending[olderCount...].map(\.score).reduce(0, +) / Float(newerCount)
        let diff = newerAvg - olderAvg

        let trend: Trend
        if diff >= trendThreshold {
            trend = .improving
        } else if diff <= -trendThreshold {
            trend = .worsening
        } else {
            trend = .steady
        }

        return Result(sessionCount: n, worstComponentIndex: topIdx,
                      worstComponentCount: worstCounts[topIdx], trend: trend,
                      olderAvg: olderAvg, newerAvg: newerAvg, recentImageFile: recentImageFile)
    }

    private static func averageFor(_ records: [PracticeRecord], _ componentIndex: Int) -> Float {
        records.map { $0.componentScores![componentIndex] }.reduce(0, +) / Float(records.count)
    }

    /// Averages each per-component score across all sampled phases in a session.
    static func averageComponentScores(_ phases: [[Float]]) -> [Float]? {
        guard let first = phases.first, !first.isEmpty else { return nil }
        let n = first.count
        var sums = [Float](repeating: 0, count: n)
        for p in phases {
            for i in 0..<min(n, p.count) { sums[i] += p[i] }
        }
        return sums.map { $0 / Float(phases.count) }
    }
}
