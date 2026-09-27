// DailyQuotaPolicy.swift — 無料ユーザーの「1日の診断回数」ルール（UI・永続化に依存しない純粋ロジック）。
// Mirrors: tfsapps.formbaseballai.quota.DailyQuotaPolicy
//
// • 1日あたり dailyFreeLimit 回（ピッチング・バッティング合計）
// • 端末ローカル日付が変わった時点で残り回数を dailyFreeLimit にリセット
// • リワード広告 1 回視聴ごとに rewardBonus 回加算
//
// ■ 不正な時刻変更への対策（Android 版と同じ考え方）
//  1. 同一起動中は「ユーザーが変更できない単調増加時計」（iOS では
//     CLOCK_MONOTONIC = スリープ中も進む mach_continuous_time）で
//     「信頼できる現在時刻」を推定する。端末時計が推定値から driftToleranceMs 以上
//     ずれていたら、端末時計ではなく推定値を使う。→ 時計を進めてリセットさせる手口が
//     同一起動中は効かない。
//  2. リセットは「日付が前回より進んだとき」のみ。時計を戻しても回数は増えない。
//  3. 再起動をまたぐと単調時計が使えないため端末時計を採用するが、これまでの最大時刻より
//     largeRollbackMs 以上過去に戻っていた場合は「時計の修正」とみなして基準日だけ引き直し、
//     回数は付与しない。
//
// Android は boot count（Int）で再起動を判定するが、iOS には同等の値が無いため
// カーネルの起動セッション UUID（sysctl kern.bootsessionuuid）を文字列で使う。

import Foundation

enum DailyQuotaPolicy {

    static let dailyFreeLimit = 5
    static let rewardBonus    = 3

    /// NTP 補正などの正当なずれとして許容する幅。
    static let driftToleranceMs: Int64 = 10 * 60 * 1000

    /// これ以上の巻き戻しは「時計の修正」とみなして基準を引き直す。
    static let largeRollbackMs: Int64 = 36 * 60 * 60 * 1000

    /// 起動セッション ID が取得できないときの値。
    static let unknownBootID = ""

    /// 永続化される状態。フィールドはそのまま UserDefaults のキーに対応する。
    struct State: Equatable {
        var initialized   = false
        /// 最後にリセットしたローカル日付（yyyyMMdd）。
        var dayKey        = 0
        /// 本日の残り回数。
        var remaining     = DailyQuotaPolicy.dailyFreeLimit
        /// 前回観測時の「信頼できる」壁時計時刻（epoch ms）。
        var trustedWallMs: Int64 = 0
        /// 前回観測時の単調時計（ms）。
        var lastElapsedMs: Int64 = 0
        /// 前回観測時の起動セッション ID。
        var lastBootID    = DailyQuotaPolicy.unknownBootID
        /// これまでに観測した信頼できる時刻の最大値（最高水位）。
        var maxWallMs: Int64 = 0
        /// 本日のリワード視聴回数（分析用）。
        var rewardsToday  = 0
    }

    /// 現在の時計情報のスナップショット。
    struct Clock {
        let wallMs:    Int64
        let elapsedMs: Int64
        let bootID:    String
        let timeZone:  TimeZone
    }

    /// epoch ミリ秒をローカル日付の yyyyMMdd 整数に変換する。
    static func dayKey(of epochMs: Int64, timeZone: TimeZone) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let date = Date(timeIntervalSince1970: TimeInterval(epochMs) / 1000)
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    /// 前回観測と同じ起動セッション内かどうか。
    static func isSameBoot(_ s: State, _ c: Clock) -> Bool {
        if c.bootID != unknownBootID && s.lastBootID != unknownBootID {
            return c.bootID == s.lastBootID && c.elapsedMs >= s.lastElapsedMs
        }
        // 起動 ID が取れない場合は単調時計が巻き戻っていなければ同一起動とみなす
        return c.elapsedMs >= s.lastElapsedMs
    }

    /// 改ざん対策を適用した「信頼できる現在時刻」。
    static func trustedNow(_ s: State, _ c: Clock) -> Int64 {
        guard isSameBoot(s, c) else { return c.wallMs }
        let estimate = s.trustedWallMs + (c.elapsedMs - s.lastElapsedMs)
        return abs(c.wallMs - estimate) <= driftToleranceMs ? c.wallMs : estimate
    }

    /// 時刻を観測し、必要ならリセットを行う。回数の参照・消費・付与の前に必ず呼ぶ。
    /// - Returns: この呼び出しで日次リセットが発生したら true
    @discardableResult
    static func refresh(_ s: inout State, _ c: Clock) -> Bool {
        if !s.initialized {
            s.initialized  = true
            s.dayKey       = dayKey(of: c.wallMs, timeZone: c.timeZone)
            s.remaining    = dailyFreeLimit
            s.rewardsToday = 0
            s.maxWallMs    = c.wallMs
            updateAnchors(&s, c, now: c.wallMs)
            return false
        }

        let now = trustedNow(s, c)
        var didReset = false

        if now < s.maxWallMs - largeRollbackMs {
            // 大きな巻き戻し: 時計の修正とみなし基準のみ引き直す（回数は付与しない）
            s.dayKey    = dayKey(of: now, timeZone: c.timeZone)
            s.maxWallMs = now
        } else {
            let today = dayKey(of: now, timeZone: c.timeZone)
            if today > s.dayKey {
                s.dayKey       = today
                s.remaining    = dailyFreeLimit
                s.rewardsToday = 0
                didReset = true
            }
        }

        updateAnchors(&s, c, now: now)
        return didReset
    }

    private static func updateAnchors(_ s: inout State, _ c: Clock, now: Int64) {
        s.trustedWallMs = now
        s.lastElapsedMs = c.elapsedMs
        s.lastBootID    = c.bootID
        if now > s.maxWallMs { s.maxWallMs = now }
    }

    /// 診断を開始できるか。
    static func canStart(_ s: State, isPremium: Bool) -> Bool {
        isPremium || s.remaining > 0
    }

    /// 診断 1 回分を消費する。プレミアムは消費しない。
    /// - Returns: 消費できた（またはプレミアムで消費不要）なら true
    @discardableResult
    static func consume(_ s: inout State, isPremium: Bool) -> Bool {
        if isPremium { return true }
        guard s.remaining > 0 else { return false }
        s.remaining -= 1
        return true
    }

    /// リワード広告の視聴完了で +rewardBonus 回。
    static func grantReward(_ s: inout State) {
        s.remaining    += rewardBonus
        s.rewardsToday += 1
    }
}
