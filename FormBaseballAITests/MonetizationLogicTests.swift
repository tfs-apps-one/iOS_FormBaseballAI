// MonetizationLogicTests.swift — Android 版の純粋ロジックと同じ挙動になっているかの確認。
// 対象: DailyQuotaPolicy / EntitlementPolicy / ProgressComparator / WeakPointAnalyzer

import Foundation
import Testing
@testable import FormBaseballAI

// MARK: - DailyQuotaPolicy

struct DailyQuotaPolicyTests {

    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    private let hour: Int64 = 60 * 60 * 1000

    /// 2026-09-26 10:00 JST
    private let base: Int64 = 1_790_384_400_000

    private func clock(_ wall: Int64, _ elapsed: Int64, boot: String = "A") -> DailyQuotaPolicy.Clock {
        .init(wallMs: wall, elapsedMs: elapsed, bootID: boot, timeZone: tokyo)
    }

    @Test func firstLaunchGivesFullQuota() {
        var s = DailyQuotaPolicy.State()
        DailyQuotaPolicy.refresh(&s, clock(base, 1_000))
        #expect(s.remaining == 5)
        #expect(s.dayKey == 20260926)
    }

    @Test func consumeAndRewardAndPremium() {
        var s = DailyQuotaPolicy.State()
        DailyQuotaPolicy.refresh(&s, clock(base, 1_000))
        for _ in 0..<5 { #expect(DailyQuotaPolicy.consume(&s, isPremium: false)) }
        #expect(!DailyQuotaPolicy.canStart(s, isPremium: false))
        #expect(DailyQuotaPolicy.canStart(s, isPremium: true))
        #expect(!DailyQuotaPolicy.consume(&s, isPremium: false))
        DailyQuotaPolicy.grantReward(&s)
        #expect(s.remaining == 3)
        #expect(s.rewardsToday == 1)
        #expect(DailyQuotaPolicy.consume(&s, isPremium: true))
        #expect(s.remaining == 3) // プレミアムは消費しない
    }

    @Test func resetsWhenDateAdvancesNaturally() {
        var s = DailyQuotaPolicy.State()
        DailyQuotaPolicy.refresh(&s, clock(base, 1_000))
        s.remaining = 0
        // 同一起動のまま 15 時間経過（翌日 01:00 JST）
        let reset = DailyQuotaPolicy.refresh(&s, clock(base + 15 * hour, 1_000 + 15 * hour))
        #expect(reset)
        #expect(s.remaining == 5)
    }

    @Test func movingClockForwardInSameBootDoesNotReset() {
        var s = DailyQuotaPolicy.State()
        DailyQuotaPolicy.refresh(&s, clock(base, 1_000))
        s.remaining = 0
        // 1 分しか経っていないのに端末時計を 1 日進めた
        let reset = DailyQuotaPolicy.refresh(&s, clock(base + 24 * hour, 61_000))
        #expect(!reset)
        #expect(s.remaining == 0)
    }

    @Test func movingClockBackDoesNotGrant() {
        var s = DailyQuotaPolicy.State()
        DailyQuotaPolicy.refresh(&s, clock(base, 1_000))
        s.remaining = 0
        // 再起動後に 2 日戻す → 基準の引き直しのみ
        DailyQuotaPolicy.refresh(&s, clock(base - 48 * hour, 500, boot: "B"))
        #expect(s.remaining == 0)
        // その後の自然な経過で「引き直した日」の翌日にはリセットされる
        let reset = DailyQuotaPolicy.refresh(&s, clock(base - 24 * hour, 500 + 24 * hour, boot: "B"))
        #expect(reset)
        #expect(s.remaining == 5)
    }

    @Test func rebootNextDayResets() {
        var s = DailyQuotaPolicy.State()
        DailyQuotaPolicy.refresh(&s, clock(base, 99_000_000))
        s.remaining = 0
        let reset = DailyQuotaPolicy.refresh(&s, clock(base + 20 * hour, 5_000, boot: "B"))
        #expect(reset)
        #expect(s.remaining == 5)
    }
}

// MARK: - EntitlementPolicy

struct EntitlementPolicyTests {

    @Test func queryFailureKeepsCache() {
        let cached = EntitlementPolicy.Snapshot(oneTime: true, subscription: true)
        #expect(EntitlementPolicy.applyOneTimeQuery(cached, success: false, purchased: []) == cached)
        #expect(EntitlementPolicy.applySubsQuery(cached, success: false, purchased: []) == cached)
    }

    @Test func successfulQueryOverwrites() {
        let cached = EntitlementPolicy.Snapshot(oneTime: false, subscription: true)
        let s1 = EntitlementPolicy.applySubsQuery(cached, success: true, purchased: [])
        #expect(!s1.isPremium) // サブスク失効
        let s2 = EntitlementPolicy.applyOneTimeQuery(s1, success: true,
                                                     purchased: [EntitlementPolicy.oneTimeProductID])
        #expect(s2.oneTime && s2.isPremium)
    }

    @Test func newPurchaseNeverDrops() {
        let cached = EntitlementPolicy.Snapshot(oneTime: true, subscription: false)
        let s = EntitlementPolicy.applyNewPurchase(cached, purchased: [EntitlementPolicy.monthlyProductID])
        #expect(s.oneTime && s.subscription)
    }
}

// MARK: - ProgressComparator

struct ProgressComparatorTests {

    @Test func evaluateBest() {
        #expect(ProgressComparator.evaluateBest(previousBest: nil, currentScore: 71.6).kind == .first)
        let nb = ProgressComparator.evaluateBest(previousBest: 78.2, currentScore: 82.6)
        #expect(nb.kind == .newBest && nb.previousBest == 78 && nb.current == 83 && nb.gain == 5)
        // 小数では上回っていても整数表示が同じなら更新扱いにしない
        let same = ProgressComparator.evaluateBest(previousBest: 78.1, currentScore: 78.4)
        #expect(same.kind == .notBest && same.pointsToBeat == 1)
    }

    @Test func roundsHalfUpLikeJava() {
        #expect(ProgressComparator.round(78.5) == 79)
        #expect(ProgressComparator.round(-0.5) == 0)
    }

    @Test func deltasAndFormatting() {
        #expect(ProgressComparator.componentDeltas(previous: nil, current: [1]) == nil)
        #expect(ProgressComparator.componentDeltas(previous: [70, 80, 50], current: [76, 77]) == [6, -3])
        #expect(ProgressComparator.formatSigned(6) == "+6")
        #expect(ProgressComparator.formatSigned(-3) == "−3")
        #expect(ProgressComparator.formatSigned(0) == "±0")
    }
}

// MARK: - WeakPointAnalyzer

struct WeakPointAnalyzerTests {

    private func rec(_ score: Float, _ comps: [Float]?, mode: FormMode = .pitching,
                     image: String? = nil) -> PracticeRecord {
        PracticeRecord(mode: mode, score: score, improvementSummary: "",
                       componentScores: comps, weakPointImageFile: image)
    }

    @Test func notEnoughData() {
        let r = WeakPointAnalyzer.analyze(records: [rec(50, [1, 2, 3, 4, 5]), rec(50, nil)], mode: .pitching)
        #expect(r.sessionCount == 1)
        #expect(!r.hasEnoughForWorstComponent)
    }

    @Test func worstComponentAndTrend() {
        // newest first: 新しい 3 回が高得点 → 改善傾向
        let records = [
            rec(80, [10, 90, 90, 90, 90], image: "new.png"),
            rec(80, [10, 90, 90, 90, 90]),
            rec(80, [90, 10, 90, 90, 90]),
            rec(60, [10, 90, 90, 90, 90], mode: .batting), // 別モードは無視
            rec(60, [10, 90, 90, 90, 90]),
            rec(60, [90, 90, 90, 90, 10]),
        ]
        let r = WeakPointAnalyzer.analyze(records: records, mode: .pitching)
        #expect(r.sessionCount == 5)
        #expect(r.worstComponentIndex == 0)
        #expect(r.worstComponentCount == 3)
        #expect(r.trend == .improving)
        #expect(r.olderAvg == 60 && r.newerAvg == 80)
        #expect(r.recentImageFile == "new.png")
    }
}
