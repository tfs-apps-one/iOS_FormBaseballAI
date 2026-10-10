// ReviewPromptManager.swift — 評価依頼を「いつ・誰に」出すかを決める。
//
// ■ 方針（v評価改善版）
//  起動時に全員へ毎回ポップアップを出す方式は廃止。診断結果が「良かった瞬間」に、
//  使い込んでいるユーザーにだけ控えめに依頼する。
//
//  (A) ヘビーユーザー（無料・プレミアム問わず）
//      → Apple 標準の評価ダイアログ（SKStoreReviewController / requestReview）。
//        iOS 側でも 365 日に最大 3 回までしか表示されない。
//  (B) プレミアム会員だけの追加の特別ポップアップ
//      → 感謝メッセージ付きの独自ポップアップ（ReviewPromptOverlay）。
//        「評価する」で App Store のレビュー画面へ。最大 2 回まで。
//
// ■ 守ること
//  • 星の数や満足度を先に聞いて、高評価の人だけをレビューへ送る（レビューゲーティング）はしない。
//  • 回数追加などの見返りとレビューを結び付けない。
//  • (A) と (B) を同じ診断で重ねて出さない。

import Foundation
import UIKit

final class ReviewPromptManager {

    static let shared = ReviewPromptManager()

    // MARK: - Config（ここを変えれば条件を調整できる）

    /// (A) ヘビーユーザー判定：累計診断回数
    static let heavyMinDiagnoses = 15
    /// (A) ヘビーユーザー判定：診断した日数（別々の日）
    static let heavyMinActiveDays = 3
    /// (A) 標準ダイアログを再度依頼するまでの最短日数（同一バージョンでは 1 回のみ）
    static let systemPromptCooldownDays = 60

    /// (B) プレミアム加入後の診断回数
    static let premiumMinDiagnoses = 5
    /// (B) 特別ポップアップの最大表示回数
    static let premiumSpecialMaxShows = 2
    /// (B) 特別ポップアップを再表示するまでの最短日数
    static let premiumSpecialCooldownDays = 30
    /// (A)(B) どちらかを出した後、もう一方を出さない日数（連続表示の防止）
    static let crossCooldownDays = 7

    /// App Store Connect の数値の Apple ID。
    private let appStoreID = "6796918322"

    // MARK: - Storage keys

    private enum Key {
        static let totalDiagnoses      = "review_totalDiagnoses"
        static let premiumDiagnoses    = "review_premiumDiagnoses"
        static let activeDays          = "review_activeDays"
        static let lastActiveDayKey    = "review_lastActiveDayKey"
        static let lastSystemPromptAt  = "review_lastSystemPromptAt"
        static let lastSystemVersion   = "review_lastSystemPromptVersion"
        static let premiumShows        = "review_premiumSpecialShows"
        static let lastPremiumAt       = "review_lastPremiumSpecialAt"
        static let premiumDone         = "review_premiumSpecialDone"
        static let seeded              = "review_seededFromHistory"
    }

    enum Decision: Equatable {
        case none
        /// (A) Apple 標準の評価ダイアログ
        case systemPrompt
        /// (B) プレミアム会員向け特別ポップアップ
        case premiumSpecial
    }

    private let defaults: UserDefaults
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        // 旧方式（起動回数で毎回表示）のキーは不要になったので掃除しておく
        defaults.removeObject(forKey: "reviewPrompt_launchCount")
        defaults.removeObject(forKey: "reviewPrompt_optedOut")
    }

    // MARK: - Usage tracking

    /// アップデート前から使っているユーザーを「新規」扱いしないよう、
    /// 初回だけ既存の練習記録（最大 30 件）から診断回数と利用日数を引き継ぐ。
    func seedFromHistoryIfNeeded(_ dates: [Date]) {
        guard !defaults.bool(forKey: Key.seeded) else { return }
        defaults.set(true, forKey: Key.seeded)
        guard !dates.isEmpty else { return }
        let days = Set(dates.map(Self.dayKey))
        defaults.set(dates.count, forKey: Key.totalDiagnoses)
        defaults.set(days.count, forKey: Key.activeDays)
        defaults.set(days.max() ?? 0, forKey: Key.lastActiveDayKey)
    }

    /// 診断が 1 回完了するたびに呼ぶ（CameraView で記録を保存した直後）。
    func recordDiagnosis(isPremium: Bool) {
        defaults.set(defaults.integer(forKey: Key.totalDiagnoses) + 1, forKey: Key.totalDiagnoses)
        if isPremium {
            defaults.set(defaults.integer(forKey: Key.premiumDiagnoses) + 1, forKey: Key.premiumDiagnoses)
        }
        let today = Self.dayKey(now())
        if defaults.integer(forKey: Key.lastActiveDayKey) != today {
            defaults.set(today, forKey: Key.lastActiveDayKey)
            defaults.set(defaults.integer(forKey: Key.activeDays) + 1, forKey: Key.activeDays)
        }
    }

    var isHeavyUser: Bool {
        defaults.integer(forKey: Key.totalDiagnoses) >= Self.heavyMinDiagnoses &&
        defaults.integer(forKey: Key.activeDays)     >= Self.heavyMinActiveDays
    }

    // MARK: - Decision

    /// 診断結果画面で「今、評価依頼を出すか」を決める。
    /// - Parameter isGoodResult: 自己ベスト更新 or ★4 以上など、良い結果だったか
    func decision(isPremium: Bool, isGoodResult: Bool) -> Decision {
        guard isGoodResult else { return .none }

        // (B) プレミアム特別ポップアップを優先（出せるなら）
        if isPremium, canShowPremiumSpecial { return .premiumSpecial }
        // (A) ヘビーユーザーへの標準ダイアログ
        if isHeavyUser, canShowSystemPrompt { return .systemPrompt }
        return .none
    }

    private var canShowPremiumSpecial: Bool {
        guard !defaults.bool(forKey: Key.premiumDone),
              defaults.integer(forKey: Key.premiumShows) < Self.premiumSpecialMaxShows,
              defaults.integer(forKey: Key.premiumDiagnoses) >= Self.premiumMinDiagnoses
        else { return false }
        if daysSince(Key.lastPremiumAt) < Self.premiumSpecialCooldownDays { return false }
        if daysSince(Key.lastSystemPromptAt) < Self.crossCooldownDays { return false }
        return true
    }

    private var canShowSystemPrompt: Bool {
        if defaults.string(forKey: Key.lastSystemVersion) == Self.appVersion { return false }
        if daysSince(Key.lastSystemPromptAt) < Self.systemPromptCooldownDays { return false }
        if daysSince(Key.lastPremiumAt) < Self.crossCooldownDays { return false }
        return true
    }

    // MARK: - Mark as shown

    func markSystemPromptRequested() {
        defaults.set(now().timeIntervalSince1970, forKey: Key.lastSystemPromptAt)
        defaults.set(Self.appVersion, forKey: Key.lastSystemVersion)
    }

    func markPremiumSpecialShown() {
        defaults.set(defaults.integer(forKey: Key.premiumShows) + 1, forKey: Key.premiumShows)
        defaults.set(now().timeIntervalSince1970, forKey: Key.lastPremiumAt)
    }

    // MARK: - Actions (premium special popup)

    /// 「評価する」→ App Store のレビュー画面へ。以後この特別ポップアップは出さない。
    func premiumSpecialRateTapped() {
        defaults.set(true, forKey: Key.premiumDone)
        openAppStoreReviewPage()
    }

    /// App Store の「レビューを書く」画面を開く（お知らせ画面などの常設リンクからも使える）。
    func openAppStoreReviewPage() {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreID)?action=write-review")
        else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Helpers

    private func daysSince(_ key: String) -> Int {
        let t = defaults.double(forKey: key)
        guard t > 0 else { return .max }
        return Int(now().timeIntervalSince1970 - t) / 86_400
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static func dayKey(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    // MARK: - Debug

    #if DEBUG
    func debugReset() {
        for k in [Key.totalDiagnoses, Key.premiumDiagnoses, Key.activeDays, Key.lastActiveDayKey,
                  Key.lastSystemPromptAt, Key.lastSystemVersion, Key.premiumShows,
                  Key.lastPremiumAt, Key.premiumDone, Key.seeded] {
            defaults.removeObject(forKey: k)
        }
    }
    #endif
}
