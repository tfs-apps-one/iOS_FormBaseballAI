// ProgressComparator.swift — 「自己ベスト」と「前回との比較」の計算ロジック（純粋ロジック）。
// Mirrors: tfsapps.formbaseballai.history.ProgressComparator
//
// 画面には点数を整数で表示するため、比較もすべて四捨五入した整数で行う。
// （小数のまま比べると「78点 → 78点 で自己ベスト更新」のような表示の矛盾が起きるため）
// 四捨五入は Java の Math.round と同じ「.5 は大きい方へ」（floor(x + 0.5)）に揃える。

import Foundation

enum ProgressComparator {

    enum BestKind: Equatable {
        /// このモードで初めての記録。
        case first
        /// 自己ベストを更新した。
        case newBest
        /// 更新ならず。
        case notBest
    }

    struct BestResult: Equatable {
        let kind: BestKind
        /// 更新前の自己ベスト（first のときは今回の点数）。
        let previousBest: Int
        /// 今回の点数。
        let current: Int
        /// 更新幅（newBest のときのみ正の値、それ以外は 0）。
        let gain: Int
        /// 自己ベスト更新まであと何点か（notBest のときのみ正の値、それ以外は 0）。
        let pointsToBeat: Int
    }

    /// Java の Math.round(float) 相当。
    static func round(_ v: Float) -> Int {
        Int((v + 0.5).rounded(.down))
    }

    /// 今回の点数を、これまでの自己ベストと比べる。
    /// - Parameters:
    ///   - previousBest: これまでの自己ベスト。記録がなければ nil
    ///   - currentScore: 今回の平均スコア
    static func evaluateBest(previousBest: Float?, currentScore: Float) -> BestResult {
        let current = round(currentScore)
        guard let previousBest else {
            return BestResult(kind: .first, previousBest: current, current: current, gain: 0, pointsToBeat: 0)
        }
        let best = round(previousBest)
        if current > best {
            return BestResult(kind: .newBest, previousBest: best, current: current,
                              gain: current - best, pointsToBeat: 0)
        }
        return BestResult(kind: .notBest, previousBest: best, current: current,
                          gain: 0, pointsToBeat: best - current + 1)
    }

    /// 総合点の前回差（整数）。
    static func totalDelta(previous: Float, current: Float) -> Int {
        round(current) - round(previous)
    }

    /// 部位ごとの前回差（整数）。どちらかが nil（旧バージョンの記録など）なら nil。
    /// 要素数が違う場合は短い方に合わせる。
    static func componentDeltas(previous: [Float]?, current: [Float]?) -> [Int]? {
        guard let previous, let current else { return nil }
        let n = min(previous.count, current.count)
        return (0..<n).map { round(current[$0]) - round(previous[$0]) }
    }

    /// 差分を「+6」「−3」「±0」の形にする（マイナスはハイフンより見やすいマイナス記号 − を使う）。
    static func formatSigned(_ delta: Int) -> String {
        if delta > 0 { return "+\(delta)" }
        if delta < 0 { return "−\(-delta)" }
        return "±0"
    }
}
