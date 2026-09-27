// HomeView.swift — Mode selection screen (equivalent to MainActivity).
// Mirrors: tfsapps.formbaseballai.MainActivity
//
// v3.0 相当の追加要素（Android と同じ）:
//   • 右上「📢 お知らせ」（未読なら 🔴）
//   • 「本日の無料診断 残り N / 5 回」／「💎 プレミアム：診断回数 無制限」
//   • プレミアムのみ「🏆 自己ベスト ピッチング 83 ／ バッティング 76」
//   • 「💎 プレミアムにアップグレード」（購入済みならグレーの「💎 プレミアム適用中」）
// 練習記録は無料でも直近3件まで閲覧できる（ソフトペイウォール）。
// 全件表示のロック解除導線は PracticeRecordListView 側で提示する。

import SwiftUI

struct HomeView: View {

    @State private var selectedMode: FormMode? = nil
    @State private var navigateToCamera = false
    @State private var navigateToPracticeRecord = false
    @State private var navigateToNotice = false
    @State private var showReviewPrompt = false
    @State private var hasCheckedReviewPrompt = false
    @State private var showPremium = false

    @State private var quotaRemaining = DailyQuotaPolicy.dailyFreeLimit
    @State private var noticeUnread = NoticeManager.hasUnread
    @State private var bestPitching: Float? = nil
    @State private var bestBatting: Float? = nil

    @ObservedObject private var premium = PremiumManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // 小さい画面（iPhone SE など）でも全ボタンに届くよう、はみ出す時だけスクロールさせる
                GeometryReader { geo in
                ScrollView {
                VStack(spacing: 0) {
                    // ── お知らせ ──────────────────────────────────────────────
                    HStack {
                        Spacer()
                        Button { navigateToNotice = true } label: {
                            Text(L(noticeUnread ? "btn_notice_unread" : "btn_notice"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()

                    // ── App icon ──────────────────────────────────────────────
                    Image("baseballai_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .cornerRadius(20)
                        .padding(.bottom, 20)

                    // ── Title ─────────────────────────────────────────────────
                    Text(NSLocalizedString("home_title", comment: ""))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text(NSLocalizedString("home_subtitle", comment: ""))
                        .font(.system(size: 16))
                        .foregroundColor(Color.white.opacity(0.7))
                        .padding(.top, 8)

                    // ── 本日の無料枠 / 自己ベスト ──────────────────────────────
                    Text(quotaLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(premium.isPremium ? AppColors.gold : AppColors.cyan)
                        .padding(.top, 14)

                    if let bestLabel {
                        Text(bestLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.gold)
                            .padding(.top, 6)
                    }

                    Spacer().frame(height: 32)

                    // ── Mode buttons ──────────────────────────────────────────
                    VStack(spacing: 16) {
                        ModeButton(
                            title: NSLocalizedString("btn_pitching", comment: ""),
                            color: AppColors.pitching,
                            icon: "figure.baseball"
                        ) {
                            selectedMode   = .pitching
                            navigateToCamera = true
                        }

                        ModeButton(
                            title: NSLocalizedString("btn_batting", comment: ""),
                            color: AppColors.batting,
                            icon: "sportscourt"
                        ) {
                            selectedMode   = .batting
                            navigateToCamera = true
                        }

                        ModeButton(
                            title: NSLocalizedString("btn_practice_record", comment: ""),
                            color: Color(red: 0.365, green: 0.361, blue: 0.902), // indigo accent
                            icon: "chart.line.uptrend.xyaxis"
                        ) {
                            navigateToPracticeRecord = true
                        }

                        premiumButton
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                    Spacer()
                }
                .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                }

                // ── Review prompt overlay ────────────────────────────────
                if showReviewPrompt {
                    ReviewPromptOverlay(
                        onRate: {
                            // Do NOT opt out here — the prompt should keep
                            // appearing on every future launch (3rd, 4th, 5th…)
                            // unless the user explicitly dismisses it forever.
                            ReviewPromptManager.shared.openAppStoreReviewPage()
                            withAnimation { showReviewPrompt = false }
                        },
                        onDismissForever: {
                            ReviewPromptManager.shared.optOut()
                            withAnimation { showReviewPrompt = false }
                        }
                    )
                }
            }
            .navigationDestination(isPresented: $navigateToCamera) {
                if let mode = selectedMode {
                    CameraView(mode: mode)
                }
            }
            .navigationDestination(isPresented: $navigateToPracticeRecord) {
                PracticeRecordListView()
            }
            .navigationDestination(isPresented: $navigateToNotice) {
                NoticeView()
            }
            .navigationBarHidden(true)
            .premiumSheet(isPresented: $showPremium)
            .onAppear {
                // 日付が変わった／リワードで増えた／購入した などを反映
                refreshStatus()

                // Guard so returning to HomeView from CameraView (a pop, which
                // re-triggers onAppear) doesn't re-check/re-show the prompt.
                guard !hasCheckedReviewPrompt else { return }
                hasCheckedReviewPrompt = true

                if ReviewPromptManager.shared.shouldShowPrompt {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation { showReviewPrompt = true }
                    }
                }
            }
            .onChange(of: premium.isPremium) { refreshStatus() }
            .onChange(of: scenePhase) { if scenePhase == .active { refreshStatus() } }
        }
    }

    // MARK: – Status

    private func refreshStatus() {
        quotaRemaining = DailyQuotaManager.remaining()
        noticeUnread   = NoticeManager.hasUnread
        bestPitching   = PersonalBestManager.best(for: .pitching)
        bestBatting    = PersonalBestManager.best(for: .batting)
    }

    /// 「本日の無料診断 残り N / 5 回」またはプレミアム無制限。
    private var quotaLabel: String {
        premium.isPremium
            ? L("quota_label_unlimited")
            : String(format: L("quota_label_remaining"), quotaRemaining, DailyQuotaPolicy.dailyFreeLimit)
    }

    /// プレミアムのみ「🏆 自己ベスト ピッチング 83 ／ バッティング 76」。
    private var bestLabel: String? {
        guard premium.isPremium, bestPitching != nil || bestBatting != nil else { return nil }
        let none = L("home_personal_best_none")
        return String(format: L("home_personal_best"),
                      bestPitching.map { String(ProgressComparator.round($0)) } ?? none,
                      bestBatting.map { String(ProgressComparator.round($0)) } ?? none)
    }

    private var premiumButton: some View {
        Button { showPremium = true } label: {
            Text(L(premium.isPremium ? "msg_premium_active" : "btn_premium_upgrade"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(premium.isPremium ? .white : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(premium.isPremium ? Color.gray : AppColors.gold)
                .cornerRadius(16)
        }
        .disabled(premium.isPremium)
    }
}

// MARK: – Mode Button

private struct ModeButton: View {
    let title:   String
    let color:   Color
    let icon:    String
    let action:  () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: color.opacity(0.5), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    HomeView()
}
