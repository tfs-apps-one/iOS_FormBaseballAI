// StoreManager.swift — StoreKit 2 のラッパー。
// Mirrors: tfsapps.formbaseballai.model.BillingManager（Google Play Billing → StoreKit 2）
//
//  • 買い切り   EntitlementPolicy.oneTimeProductID（非消耗型 / Non-Consumable）
//  • 月額サブスク EntitlementPolicy.monthlyProductID（自動更新サブスクリプション）
//
// 権利の判定・保存は PremiumManager / EntitlementPolicy が担当する。
// Android 版は画面ごとに BillingManager を生成していたが、StoreKit 2 では
// Transaction.updates の監視をアプリ起動時から 1 本だけ張る必要があるため、シングルトンにしている
// （FormBaseballAIApp の init で start() を呼ぶ）。

import Foundation
import StoreKit
import Combine

@MainActor
final class StoreManager: ObservableObject {

    static let shared = StoreManager()

    /// 購入できるプラン。
    enum Plan {
        case lifetime, monthly

        var productID: String {
            switch self {
            case .lifetime: return EntitlementPolicy.oneTimeProductID
            case .monthly:  return EntitlementPolicy.monthlyProductID
            }
        }
    }

    enum PurchaseOutcome: Equatable {
        case success
        case cancelled
        /// 「承認と購入のリクエスト」（ペアレンタルコントロール）や追加認証の待ち。
        case pending
        case failed(String)
    }

    enum RestoreOutcome: Equatable {
        case restored
        case nothingToRestore
        case cancelled
        case failed(String)
    }

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var isLoadingProducts = false

    private var updatesTask: Task<Void, Never>?
    private var started = false

    private init() {}

    // MARK: - 起動

    /// アプリ起動時に 1 回だけ呼ぶ。未処理の取引・更新・返金の監視を開始し、
    /// 商品情報の取得と権利の照会を行う。
    func start() {
        guard !started else { return }
        started = true

        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handleTransactionUpdate(result)
            }
        }

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: - 商品情報

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let list = try await Product.products(for: EntitlementPolicy.allProductIDs)
            var dict = [String: Product]()
            for p in list { dict[p.id] = p }
            products = dict
            #if DEBUG
            if list.count < EntitlementPolicy.allProductIDs.count {
                print("StoreManager: some products are unavailable — got \(list.map(\.id))")
            }
            #endif
        } catch {
            #if DEBUG
            print("StoreManager: failed to load products — \(error.localizedDescription)")
            #endif
        }
    }

    func product(for plan: Plan) -> Product? {
        products[plan.productID]
    }

    /// App Store Connect の実価格（例: "¥1,200" / "¥150"）。未取得なら nil。
    func formattedPrice(_ plan: Plan) -> String? {
        product(for: plan)?.displayPrice
    }

    // MARK: - 権利の照会 / 復元

    /// 現在有効な権利（買い切り・有効なサブスク）を App Store から読み直してキャッシュに反映する。
    /// currentEntitlements は有効（猶予期間含む）なものだけを返すため、含まれていなければ失効扱い。
    func refreshEntitlements() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            if let exp = t.expirationDate, exp < Date() { continue }
            ids.insert(t.productID)
        }
        PremiumManager.shared.applyOneTimeQuery(success: true, purchased: ids)
        PremiumManager.shared.applySubsQuery(success: true, purchased: ids)
    }

    /// 「購入を復元」。App Store と同期してから権利を照会し直す。
    func restore() async -> RestoreOutcome {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch {
            return .failed(NSLocalizedString("msg_billing_unavailable", comment: ""))
        }
        await refreshEntitlements()
        return PremiumManager.shared.isPremium ? .restored : .nothingToRestore
    }

    // MARK: - 購入フロー

    func purchase(_ plan: Plan) async -> PurchaseOutcome {
        if product(for: plan) == nil {
            await loadProducts()
        }
        guard let product = product(for: plan) else {
            return .failed(NSLocalizedString("msg_billing_loading", comment: ""))
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed(String(format: NSLocalizedString("msg_purchase_error", comment: ""),
                                          NSLocalizedString("msg_purchase_verify_failed", comment: "")))
                }
                PremiumManager.shared.applyNewPurchase([transaction.productID])
                await transaction.finish()
                return .success
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .cancelled
            }
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch {
            return .failed(String(format: NSLocalizedString("msg_purchase_error", comment: ""),
                                  error.localizedDescription))
        }
    }

    // MARK: - 取引の更新（承認待ちの完了・別端末での購入・更新・返金など）

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        let wasPremium = PremiumManager.shared.isPremium
        if transaction.revocationDate == nil {
            PremiumManager.shared.applyNewPurchase([transaction.productID])
        }
        await transaction.finish()
        // 返金・失効も反映するため、最終的には現在の権利で上書きする
        await refreshEntitlements()
        if !wasPremium && PremiumManager.shared.isPremium {
            ToastCenter.shared.show(NSLocalizedString("msg_premium_active", comment: ""))
        }
    }
}
