// EntitlementPolicy.swift — プレミアム権利の判定ルール（StoreKit に依存しない純粋ロジック）。
// Mirrors: tfsapps.formbaseballai.model.EntitlementPolicy
//
// 権利の出どころは 2 つ。どちらか一方でも有効ならプレミアム。
//  • oneTimeProductID : 買い切り（非消耗型 / Non-Consumable）
//  • monthlyProductID : 月額の自動更新サブスクリプション（Auto-Renewable Subscription）
//
// App Store への照会が「成功したとき」だけ該当ソースを上書きする。
// 照会失敗（オフライン等）ではキャッシュを維持し、既存ユーザーが一時的に
// 特典を失わないようにする。

import Foundation

enum EntitlementPolicy {

    /// 買い切り（非消耗型）。App Store Connect の「製品 ID」と一致させること。
    static let oneTimeProductID = "premium_plan"
    /// 月額サブスクリプション（自動更新）。App Store Connect の「製品 ID」と一致させること。
    static let monthlyProductID = "premium_monthly"

    static var allProductIDs: [String] { [oneTimeProductID, monthlyProductID] }

    /// 不変の権利スナップショット。
    struct Snapshot: Equatable {
        let oneTime:      Bool
        let subscription: Bool

        var isPremium: Bool { oneTime || subscription }
    }

    static let none = Snapshot(oneTime: false, subscription: false)

    /// 旧バージョンの単一フラグからの移行（旧フラグが立っていれば買い切り保有とみなす）。
    /// iOS 版には旧プレミアムが存在しないため通常は使われないが、Android と挙動を揃えるため残す。
    static func migrateLegacyFlag(_ cached: Snapshot, oldIsPremiumFlag: Bool) -> Snapshot {
        guard oldIsPremiumFlag, !cached.oneTime else { return cached }
        return Snapshot(oneTime: true, subscription: cached.subscription)
    }

    /// 買い切りの照会結果を反映する。
    static func applyOneTimeQuery(_ cached: Snapshot, success: Bool,
                                  purchased: Set<String>) -> Snapshot {
        guard success else { return cached }
        return Snapshot(oneTime: purchased.contains(oneTimeProductID),
                        subscription: cached.subscription)
    }

    /// サブスクの照会結果を反映する。Transaction.currentEntitlements は
    /// 有効（猶予期間含む）なサブスクのみ返すため、含まれていなければ失効扱い。
    static func applySubsQuery(_ cached: Snapshot, success: Bool,
                               purchased: Set<String>) -> Snapshot {
        guard success else { return cached }
        return Snapshot(oneTime: cached.oneTime,
                        subscription: purchased.contains(monthlyProductID))
    }

    /// 新規購入を反映する。既存の権利は落とさない。
    static func applyNewPurchase(_ cached: Snapshot, purchased: Set<String>) -> Snapshot {
        Snapshot(oneTime: cached.oneTime || purchased.contains(oneTimeProductID),
                 subscription: cached.subscription || purchased.contains(monthlyProductID))
    }
}
