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
    /// 再試行しても一部（または全部）の商品情報を取得できなかった。
    @Published private(set) var productsUnavailable = false

    private var updatesTask: Task<Void, Never>?
    /// 実行中の商品情報の取得。同時に呼ばれた場合は同じ取得の完了を待つ
    /// （購入画面の表示直後に購入ボタンを押しても「取得中」エラーにならないように）。
    private var loadTask: Task<Void, Never>?

    private var hasAllProducts: Bool {
        products.count >= EntitlementPolicy.allProductIDs.count
    }
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

    /// 商品情報を取得する。すでに取得中ならその完了を待つ。
    /// 通信エラーや一時的に空で返ってきた場合は、間隔をあけて最大 3 回まで取り直す。
    func loadProducts() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { @MainActor in
            await self.performLoadProducts()
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// まだ揃っていなければ取り直す（アプリ復帰時など）。
    func loadProductsIfNeeded() async {
        if !hasAllProducts { await loadProducts() }
    }

    private func performLoadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        let ids = EntitlementPolicy.allProductIDs
        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            do {
                let list = try await Product.products(for: ids)
                // 取れた分だけでも残す（部分的な成功を失わないよう上書きではなくマージ）
                for p in list { products[p.id] = p }
                #if DEBUG
                print("StoreManager: attempt \(attempt) got \(list.map(\.id))")
                #endif
            } catch {
                #if DEBUG
                print("StoreManager: attempt \(attempt) failed — \(error.localizedDescription)")
                #endif
            }
            if hasAllProducts { break }
            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_500_000_000)
            }
        }
        productsUnavailable = !hasAllProducts
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
            return .failed(NSLocalizedString("msg_products_unavailable", comment: ""))
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
