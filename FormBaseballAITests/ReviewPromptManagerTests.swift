// ReviewPromptManagerTests.swift — 評価依頼の表示条件の確認。

import Foundation
import Testing
@testable import FormBaseballAI

struct ReviewPromptManagerTests {

    private final class Clock { var date = Date(timeIntervalSince1970: 1_790_384_400) }

    private func make() -> (ReviewPromptManager, Clock) {
        let suite = "ReviewPromptManagerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let clock = Clock()
        return (ReviewPromptManager(defaults: defaults, now: { clock.date }), clock)
    }

    /// days 日に分けて合計 count 回診断する
    private func use(_ m: ReviewPromptManager, _ c: Clock, count: Int, days: Int, premium: Bool) {
        for i in 0..<count {
            if i > 0 && i % max(1, count / days) == 0 { c.date += 86_400 }
            m.recordDiagnosis(isPremium: premium)
        }
    }

    @Test func lightUserSeesNothing() {
        let (m, c) = make()
        use(m, c, count: 5, days: 1, premium: false)
        #expect(m.decision(isPremium: false, isGoodResult: true) == .none)
    }

    @Test func heavyFreeUserGetsSystemPromptOnlyOnGoodResult() {
        let (m, c) = make()
        use(m, c, count: 15, days: 3, premium: false)
        #expect(m.isHeavyUser)
        #expect(m.decision(isPremium: false, isGoodResult: false) == .none)
        #expect(m.decision(isPremium: false, isGoodResult: true) == .systemPrompt)
    }

    @Test func manyDiagnosesInOneDayIsNotHeavy() {
        let (m, c) = make()
        use(m, c, count: 30, days: 1, premium: false)
        #expect(!m.isHeavyUser)
    }

    @Test func systemPromptHasCooldown() {
        let (m, c) = make()
        use(m, c, count: 15, days: 3, premium: false)
        m.markSystemPromptRequested()
        #expect(m.decision(isPremium: false, isGoodResult: true) == .none)
    }

    @Test func premiumGetsSpecialPopupAfterFiveDiagnoses() {
        let (m, c) = make()
        use(m, c, count: 4, days: 1, premium: true)
        #expect(m.decision(isPremium: true, isGoodResult: true) == .none)
        m.recordDiagnosis(isPremium: true)
        #expect(m.decision(isPremium: true, isGoodResult: true) == .premiumSpecial)
    }

    @Test func premiumSpecialMaxTwiceWithCooldown() {
        let (m, c) = make()
        use(m, c, count: 5, days: 1, premium: true)
        m.markPremiumSpecialShown()
        #expect(m.decision(isPremium: true, isGoodResult: true) == .none)   // 30 日以内
        c.date += 31 * 86_400
        #expect(m.decision(isPremium: true, isGoodResult: true) == .premiumSpecial)
        m.markPremiumSpecialShown()
        c.date += 31 * 86_400
        #expect(m.decision(isPremium: true, isGoodResult: true) != .premiumSpecial) // 最大 2 回
    }

    @Test func heavyPremiumUserAlsoGetsSystemPromptAfterSpecial() {
        let (m, c) = make()
        use(m, c, count: 15, days: 3, premium: true)
        #expect(m.decision(isPremium: true, isGoodResult: true) == .premiumSpecial)
        m.markPremiumSpecialShown()
        #expect(m.decision(isPremium: true, isGoodResult: true) == .none)  // 7 日は重ねない
        c.date += 8 * 86_400
        #expect(m.decision(isPremium: true, isGoodResult: true) == .systemPrompt)
    }
}

extension ReviewPromptManagerTests {
    @Test func existingUsersAreSeededFromHistory() {
        let (m, _) = make()
        let base = Date(timeIntervalSince1970: 1_790_000_000)
        let dates = (0..<15).map { base + Double($0 / 5) * 86_400 }   // 15 回・3 日
        m.seedFromHistoryIfNeeded(dates)
        #expect(m.isHeavyUser)
        m.seedFromHistoryIfNeeded([])   // 2 回目以降は何もしない
        #expect(m.isHeavyUser)
    }
}
