// PremiumManager.swift — プレミアム権利のローカルキャッシュ（画面から監視できる ObservableObject）。
// 判定ルールは EntitlementPolicy、App Store とのやり取りは StoreManager が担当する。
// Mirrors: tfsapps.formbaseballai.model.PremiumManager
//
// UserDefaults:
//   premium_ent_one_time … 買い切り（premium_plan）を保有
//   premium_ent_subs     … 月額サブスクが有効
//
// App Store への照会前・オフラインでも直前の状態で動作させるため、
// 照会結果はここに保存しておき、起動直後はこのキャッシュを使う。

import Foundation
import Combine

@MainActor
final class PremiumManager: ObservableObject {

    static let shared = PremiumManager()

    private static let keyOneTime = "premium_ent_one_time"
    private static let keySubs    = "premium_ent_subs"

    @Published private(set) var snapshot: EntitlementPolicy.Snapshot

    var isPremium: Bool { snapshot.isPremium }

    /// メインスレッド以外（や @MainActor 外の static 処理）から読むためのキャッシュ値。
    nonisolated static var cachedIsPremium: Bool {
        loadSnapshot().isPremium
    }

    private init() {
        snapshot = Self.loadSnapshot()
    }

    // MARK: - 照会結果の反映

    func applyOneTimeQuery(success: Bool, purchased: Set<String>) {
        save(EntitlementPolicy.applyOneTimeQuery(snapshot, success: success, purchased: purchased))
    }

    func applySubsQuery(success: Bool, purchased: Set<String>) {
        save(EntitlementPolicy.applySubsQuery(snapshot, success: success, purchased: purchased))
    }

    func applyNewPurchase(_ purchased: Set<String>) {
        save(EntitlementPolicy.applyNewPurchase(snapshot, purchased: purchased))
    }

    // MARK: - Persistence

    private nonisolated static func loadSnapshot() -> EntitlementPolicy.Snapshot {
        let d = UserDefaults.standard
        return EntitlementPolicy.Snapshot(oneTime: d.bool(forKey: keyOneTime),
                                          subscription: d.bool(forKey: keySubs))
    }

    private func save(_ s: EntitlementPolicy.Snapshot) {
        let d = UserDefaults.standard
        d.set(s.oneTime, forKey: Self.keyOneTime)
        d.set(s.subscription, forKey: Self.keySubs)
        if s != snapshot { snapshot = s }
    }

    #if DEBUG
    /// デバッグ用: キャッシュを直接書き換える（次回の App Store 照会で上書きされる）。
    func debugSet(oneTime: Bool, subscription: Bool) {
        save(EntitlementPolicy.Snapshot(oneTime: oneTime, subscription: subscription))
    }
    #endif
}
