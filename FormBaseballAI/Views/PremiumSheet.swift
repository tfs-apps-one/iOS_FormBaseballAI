// PremiumSheet.swift — プレミアムプランの案内（購入画面）。
// Mirrors: tfsapps.formbaseballai.model.PremiumDialogHelper + res/layout/dialog_premium.xml
//
// 買い切り／月額の 2 プランと「購入を復元」を提示する。
// App Store の自動更新サブスクの審査要件（ガイドライン 3.1.2）に合わせ、
// 価格・期間・自動更新である旨・利用規約／プライバシーポリシーへのリンクを必ず表示する。
//
// 使い方: 任意の View に `.premiumSheet(isPresented: $showPremium)` を付ける。

import SwiftUI

extension View {
    /// プレミアム購入シートを表示する。
    func premiumSheet(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            PremiumSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct PremiumSheet: View {

    @ObservedObject private var store = StoreManager.shared
    @Environment(\.dismiss) private var dismiss

    private enum Busy: Equatable { case idle, lifetime, monthly, restore }
    @State private var busy: Busy = .idle
    @State private var errorMessage: String?

    private let features: [(icon: String, title: String, desc: String)] = [
        ("♾️", "premium_feature1_title", "premium_feature1_desc"),
        ("📅", "premium_feature2_title", "premium_feature2_desc"),
        ("📈", "premium_feature3_title", "premium_feature3_desc"),
        ("📊", "premium_feature4_title", "premium_feature4_desc"),
        ("🏆", "premium_feature5_title", "premium_feature5_desc"),
        ("🔁", "premium_feature6_title", "premium_feature6_desc"),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.11).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Text("👑").font(.system(size: 48)).padding(.top, 24)

                    Text(L("dialog_premium_title"))
                        .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                        .padding(.top, 8)

                    Text(L("premium_subtitle"))
                        .font(.system(size: 13)).foregroundColor(Color(white: 0.73))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    Text(L("premium_one_time_badge"))
                        .font(.system(size: 13, weight: .bold)).foregroundColor(AppColors.gold)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(AppColors.gold.opacity(0.12))
                        .overlay(Capsule().stroke(AppColors.gold.opacity(0.7), lineWidth: 1))
                        .clipShape(Capsule())
                        .padding(.top, 12)

                    featureCard.padding(.top, 20)

                    purchaseButtons.padding(.top, 20)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13)).foregroundColor(AppColors.bad)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    }

                    Text(L("premium_fine_print"))
                        .font(.system(size: 11)).foregroundColor(Color(white: 0.6))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)

                    HStack(spacing: 16) {
                        Link(L("premium_terms_of_use"), destination: MonetizationConfig.termsOfUseURL)
                        Text("|").foregroundColor(Color(white: 0.4))
                        Link(L("premium_privacy_policy"), destination: MonetizationConfig.privacyPolicyURL)
                    }
                    .font(.system(size: 12))
                    .tint(AppColors.cyan)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 24)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(busy != .idle)
        .task {
            if store.products.count < EntitlementPolicy.allProductIDs.count {
                await store.loadProducts()
            }
        }
    }

    // MARK: - Feature card

    private var featureCard: some View {
        VStack(spacing: 0) {
            ForEach(features.indices, id: \.self) { i in
                let f = features[i]
                HStack(alignment: .center, spacing: 16) {
                    Text(f.icon).font(.system(size: 24)).frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L(f.title))
                            .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        Text(L(f.desc))
                            .font(.system(size: 12)).foregroundColor(Color(white: 0.73))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                if i < features.count - 1 {
                    Rectangle().fill(Color(white: 0.2)).frame(height: 1).padding(.vertical, 12)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.gold.opacity(0.35), lineWidth: 1))
        .cornerRadius(16)
    }

    // MARK: - Buttons

    private var purchaseButtons: some View {
        VStack(spacing: 12) {
            Button { purchase(.lifetime) } label: {
                buttonLabel(title: lifetimeTitle, busy: busy == .lifetime, dark: true)
                    .background(AppColors.gold)
                    .cornerRadius(14)
            }

            Button { purchase(.monthly) } label: {
                buttonLabel(title: monthlyTitle, busy: busy == .monthly, dark: false)
                    .background(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cyan, lineWidth: 1.5))
                    .cornerRadius(14)
            }

            Button { restore() } label: {
                HStack(spacing: 8) {
                    if busy == .restore { ProgressView().tint(.white) }
                    Text(L("btn_restore_purchases"))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(white: 0.85))
                .padding(.vertical, 8)
            }
        }
        .disabled(busy != .idle)
    }

    private func buttonLabel(title: String, busy: Bool, dark: Bool) -> some View {
        HStack(spacing: 10) {
            if busy { ProgressView().tint(dark ? .black : .white) }
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .multilineTextAlignment(.center)
        }
        .foregroundColor(dark ? .black : .white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .padding(.horizontal, 12)
    }

    private var lifetimeTitle: String {
        if let price = store.formattedPrice(.lifetime) {
            return String(format: L("btn_premium_buy_lifetime_with_price"), price)
        }
        return L("btn_premium_buy_lifetime")
    }

    private var monthlyTitle: String {
        if let price = store.formattedPrice(.monthly) {
            return String(format: L("btn_premium_buy_monthly_with_price"), price)
        }
        return L("btn_premium_buy_monthly")
    }

    // MARK: - Actions

    private func purchase(_ plan: StoreManager.Plan) {
        errorMessage = nil
        busy = (plan == .lifetime) ? .lifetime : .monthly
        Task { @MainActor in
            let outcome = await store.purchase(plan)
            busy = .idle
            switch outcome {
            case .success:
                dismiss()
                ToastCenter.shared.show(L("msg_premium_active"))
            case .pending:
                dismiss()
                ToastCenter.shared.show(L("msg_purchase_pending"), duration: .long)
            case .cancelled:
                break
            case .failed(let message):
                errorMessage = message
            }
        }
    }

    private func restore() {
        errorMessage = nil
        busy = .restore
        Task { @MainActor in
            let outcome = await store.restore()
            busy = .idle
            switch outcome {
            case .restored:
                dismiss()
                ToastCenter.shared.show(L("msg_restore_success"), duration: .long)
            case .nothingToRestore:
                errorMessage = L("msg_restore_none")
            case .cancelled:
                break
            case .failed(let message):
                errorMessage = message
            }
        }
    }
}

/// NSLocalizedString の短縮形（このアプリの文字列はすべて Localizable.strings のキー）。
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

#Preview {
    PremiumSheet()
}
