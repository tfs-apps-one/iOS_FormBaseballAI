// PersonalBestManager.swift — モードごとの自己ベスト（最高スコア）を保存する。
// Mirrors: tfsapps.formbaseballai.history.PersonalBestManager
//
// 練習記録（最大30件）とは別に保存するので、古い記録が押し出されても自己ベストは消えない。
// 初回だけ、既存の練習記録から最高スコアを拾って初期値にする（アップデート前の記録も反映）。
//
// UserDefaults: personalBest_score_{mode}（Float） / personalBest_time_{mode}（Double） / personalBest_seeded（Bool）

import Foundation

enum PersonalBestManager {

    private static let keySeeded      = "personalBest_seeded"
    private static let keyScorePrefix = "personalBest_score_"
    private static let keyTimePrefix  = "personalBest_time_"

    private static let lock = NSRecursiveLock()
    private static var defaults: UserDefaults { .standard }

    /// 自己ベスト。記録がなければ nil。
    static func best(for mode: FormMode) -> Float? {
        lock.lock(); defer { lock.unlock() }
        seedFromHistoryIfNeeded()
        let key = keyScorePrefix + mode.rawValue
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.float(forKey: key)
    }

    /// 今回の点数が自己ベストを（表示上の整数で）上回っていれば更新する。
    static func record(mode: FormMode, score: Float, date: Date = Date()) {
        lock.lock(); defer { lock.unlock() }
        let current = best(for: mode)
        if current == nil || ProgressComparator.round(score) > ProgressComparator.round(current!) {
            defaults.set(score, forKey: keyScorePrefix + mode.rawValue)
            defaults.set(date.timeIntervalSince1970, forKey: keyTimePrefix + mode.rawValue)
        }
    }

    private static func seedFromHistoryIfNeeded() {
        guard !defaults.bool(forKey: keySeeded) else { return }
        let records = PracticeRecordStore.shared.records
        for mode in FormMode.allCases {
            if let best = records.filter({ $0.mode == mode }).max(by: { $0.score < $1.score }) {
                defaults.set(best.score, forKey: keyScorePrefix + mode.rawValue)
                defaults.set(best.date.timeIntervalSince1970, forKey: keyTimePrefix + mode.rawValue)
            }
        }
        defaults.set(true, forKey: keySeeded)
    }
}
