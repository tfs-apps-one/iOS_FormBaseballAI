// DailyQuotaManager.swift — DailyQuotaPolicy を UserDefaults に永続化する iOS 側のラッパー。
// 画面からは基本的にこのクラスだけを使う。
// Mirrors: tfsapps.formbaseballai.quota.DailyQuotaManager

import Foundation

enum DailyQuotaManager {

    private static let lock = NSLock()
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let prefix        = "quota_"
        static let initialized   = prefix + "initialized"
        static let dayKey        = prefix + "day_key"
        static let remaining     = prefix + "remaining"
        static let trustedWallMs = prefix + "trusted_wall_ms"
        static let lastElapsedMs = prefix + "last_elapsed_ms"
        static let lastBootID    = prefix + "last_boot_id"
        static let maxWallMs     = prefix + "max_wall_ms"
        static let rewardsToday  = prefix + "rewards_today"
    }

    /// 本日の残り回数（リセット処理を反映した値）。
    static func remaining() -> Int {
        withLock { loadAndRefresh().remaining }
    }

    /// 診断を開始できるか（プレミアムは常に true）。
    static func canStart(isPremium: Bool = PremiumManager.cachedIsPremium) -> Bool {
        withLock { DailyQuotaPolicy.canStart(loadAndRefresh(), isPremium: isPremium) }
    }

    /// 診断 1 回分を消費する。消費後の残り回数を返す（プレミアムは -1）。
    @discardableResult
    static func consume(isPremium: Bool = PremiumManager.cachedIsPremium) -> Int {
        withLock {
            var s = loadAndRefresh()
            DailyQuotaPolicy.consume(&s, isPremium: isPremium)
            save(s)
            return isPremium ? -1 : s.remaining
        }
    }

    /// リワード広告視聴完了時に呼ぶ。付与後の残り回数を返す。
    @discardableResult
    static func grantReward() -> Int {
        withLock {
            var s = loadAndRefresh()
            DailyQuotaPolicy.grantReward(&s)
            save(s)
            return s.remaining
        }
    }

    // MARK: - Internals

    private static func withLock<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    private static func loadAndRefresh() -> DailyQuotaPolicy.State {
        var s = load()
        DailyQuotaPolicy.refresh(&s, currentClock())
        save(s)
        return s
    }

    static func currentClock() -> DailyQuotaPolicy.Clock {
        DailyQuotaPolicy.Clock(
            wallMs: Int64((Date().timeIntervalSince1970 * 1000).rounded()),
            elapsedMs: monotonicMillis(),
            bootID: bootSessionID(),
            timeZone: .current)
    }

    /// ユーザーが変更できない単調増加時計（ms）。Darwin の CLOCK_MONOTONIC は
    /// mach_continuous_time ベースでスリープ中も進み、端末の再起動でリセットされる。
    private static func monotonicMillis() -> Int64 {
        Int64(clock_gettime_nsec_np(CLOCK_MONOTONIC) / 1_000_000)
    }

    /// 起動ごとに変わるカーネルの起動セッション UUID。取得できなければ unknownBootID。
    private static func bootSessionID() -> String {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 0 else {
            return DailyQuotaPolicy.unknownBootID
        }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &buf, &size, nil, 0) == 0 else {
            return DailyQuotaPolicy.unknownBootID
        }
        return buf.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }

    private static func load() -> DailyQuotaPolicy.State {
        var s = DailyQuotaPolicy.State()
        s.initialized   = defaults.bool(forKey: Key.initialized)
        s.dayKey        = defaults.integer(forKey: Key.dayKey)
        s.remaining     = defaults.object(forKey: Key.remaining) as? Int ?? DailyQuotaPolicy.dailyFreeLimit
        s.trustedWallMs = (defaults.object(forKey: Key.trustedWallMs) as? NSNumber)?.int64Value ?? 0
        s.lastElapsedMs = (defaults.object(forKey: Key.lastElapsedMs) as? NSNumber)?.int64Value ?? 0
        s.lastBootID    = defaults.string(forKey: Key.lastBootID) ?? DailyQuotaPolicy.unknownBootID
        s.maxWallMs     = (defaults.object(forKey: Key.maxWallMs) as? NSNumber)?.int64Value ?? 0
        s.rewardsToday  = defaults.integer(forKey: Key.rewardsToday)
        return s
    }

    private static func save(_ s: DailyQuotaPolicy.State) {
        defaults.set(s.initialized, forKey: Key.initialized)
        defaults.set(s.dayKey, forKey: Key.dayKey)
        defaults.set(s.remaining, forKey: Key.remaining)
        defaults.set(NSNumber(value: s.trustedWallMs), forKey: Key.trustedWallMs)
        defaults.set(NSNumber(value: s.lastElapsedMs), forKey: Key.lastElapsedMs)
        defaults.set(s.lastBootID, forKey: Key.lastBootID)
        defaults.set(NSNumber(value: s.maxWallMs), forKey: Key.maxWallMs)
        defaults.set(s.rewardsToday, forKey: Key.rewardsToday)
    }

    #if DEBUG
    /// デバッグ用: 回数の状態をすべて消す（次回参照時に 5 回で初期化される）。
    static func debugReset() {
        withLock {
            for k in [Key.initialized, Key.dayKey, Key.remaining, Key.trustedWallMs,
                      Key.lastElapsedMs, Key.lastBootID, Key.maxWallMs, Key.rewardsToday] {
                defaults.removeObject(forKey: k)
            }
        }
    }
    #endif
}
