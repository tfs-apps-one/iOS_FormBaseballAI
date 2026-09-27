// NoticeView.swift — 「お知らせ」詳細画面（1日5回の無料枠・リワード動画・新プレミアム・
// 自己ベスト／前回との比較）。
// Mirrors: tfsapps.formbaseballai.notice.NoticeActivity + res/layout/activity_notice.xml
//
// iOS 版の差分:
//  • Android の「【重要】既存プレミアム購入者様へ」は iOS に旧プレミアムが無いため表示しない。
//  • Android の「v3.0 リリース特価」カードは Google Play 側の価格施策なので表示しない。
//  • Android の「プレミアムに新機能が2つ加わりました」カードは、iOS ではプレミアム自体が初公開のため
//    ④ 自己ベスト ⑤ 前回との比較 として通常の項目に並べている。
//  • 「① バナー・全画面広告を撤廃」は showsAdsRemovalItem で切り替え
//    （iOS で広告入りの版をリリース済みの場合のみ true にする）。

import SwiftUI

enum NoticeManager {

    /// お知らせ内容を差し替えたら +1 する（ホームの「お知らせ」ボタンに未読の 🔴 が再表示される）。
    static let currentNoticeVersion = 1

    private static let keySeenVersion = "notice_seen_version"

    static var hasUnread: Bool {
        UserDefaults.standard.integer(forKey: keySeenVersion) < currentNoticeVersion
    }

    static func markRead() {
        UserDefaults.standard.set(currentNoticeVersion, forKey: keySeenVersion)
    }
}

struct NoticeView: View {

    /// iOS でバナー／全画面広告入りの版を既にリリースしている場合のみ true にする。
    static let showsAdsRemovalItem = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L("notice_date"))
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.5))

                        Text(L("notice_title"))
                            .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        bodyText(L("notice_intro"))

                        if Self.showsAdsRemovalItem {
                            item(title: L("notice_item_ads_title"), body: L("notice_item_ads_body"))
                        }
                        item(title: L("notice_item_free_title"), body: L("notice_item_free_body"))
                        item(title: L("notice_item_reward_title"), body: L("notice_item_reward_body"))
                        item(title: L("notice_item_premium_title"), body: L("notice_item_premium_body"))
                        item(title: L("notice_item_best_title"), body: L("notice_item_best_body"))
                        item(title: L("notice_item_compare_title"), body: L("notice_item_compare_body"))

                        Text(L("notice_free_note"))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)

                        bodyText(L("notice_closing"))
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear { NoticeManager.markRead() }
    }

    private var header: some View {
        HStack {
            Text(L("notice_screen_title"))
                .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Spacer()
            Button { dismiss() } label: {
                Text(L("btn_close"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func item(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppColors.cyan)
                .fixedSize(horizontal: false, vertical: true)
            bodyText(body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.card)
        .cornerRadius(12)
    }
}

#Preview {
    NoticeView()
}
