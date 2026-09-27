// QuotaExhaustedDialog.swift — 本日の無料枠を使い切ったときの案内モーダル。
// Mirrors: CameraActivity#showQuotaExhaustedDialog() + res/layout/dialog_quota_exhausted.xml
//
// デザインは上部お知らせと統一（黒背景＋水色の外枠＋白文字）。
// 「▶ 動画を見て＋3回」「👑 プレミアムで無制限にする」「閉じる」の 3 択。

import SwiftUI

struct QuotaExhaustedDialog: View {

    let onWatchReward: () -> Void
    let onGoPremium: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 14) {
                Text("🎬").font(.system(size: 40))

                Text(L("quota_exhausted_title"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(String(format: L("quota_exhausted_message"),
                            DailyQuotaPolicy.dailyFreeLimit, DailyQuotaPolicy.rewardBonus))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    Button(action: onWatchReward) {
                        Text(String(format: L("btn_watch_reward_ad"), DailyQuotaPolicy.rewardBonus))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.cyan)
                            .cornerRadius(12)
                    }

                    Button(action: onGoPremium) {
                        Text(L("btn_quota_go_premium"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(AppColors.gold)
                            .cornerRadius(12)
                    }

                    Button(action: onClose) {
                        Text(L("btn_quota_later"))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, 4)
            }
            .padding(22)
            .background(Color.black)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.cyan, lineWidth: 2))
            .cornerRadius(18)
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
        .zIndex(10)
    }
}

#Preview {
    QuotaExhaustedDialog(onWatchReward: {}, onGoPremium: {}, onClose: {})
}
