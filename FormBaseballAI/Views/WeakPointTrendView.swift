// WeakPointTrendView.swift — ウィークポイント傾向レポートの専用画面と、
// 無料ユーザー向けの説明シート。
// Mirrors: tfsapps.formbaseballai.history.WeakPointTrendActivity
//          tfsapps.formbaseballai.history.WeakPointExplainerDialog
//
// モードごとのカードは 4 状態:
//   1. そのモードの記録が 1 件もない        → 非表示
//   2. データ不足（有効な記録が 3 回未満）   → 「あと N 回で傾向が見えてきます」
//   3. 無料ユーザー（データは十分）          → ロック表示。タップで説明シート → 購入シート
//   4. プレミアム                             → 最大の課題＋推移＋アドバイス＋直近のスケルトン画像

import SwiftUI

/// 部位名・部位ごとのアドバイスのローカライズ（Android の string-array に相当）。
enum ComponentText {
    static var names: [String] {
        ["component_right_elbow", "component_left_elbow", "component_shoulder",
         "component_hip", "component_lead_knee"].map(L)
    }

    static func improvements(for mode: FormMode) -> [String] {
        switch mode {
        case .pitching:
            return ["improve_pitch_right_elbow", "improve_pitch_left_elbow", "improve_pitch_shoulder",
                    "improve_pitch_hip", "improve_pitch_knee"].map(L)
        case .batting:
            return ["improve_bat_right_elbow", "improve_bat_left_elbow", "improve_bat_shoulder",
                    "improve_bat_hip", "improve_bat_knee"].map(L)
        }
    }

    /// 「ピッチング」「バッティング」（「〜モード」なし）
    static func modeLabel(_ mode: FormMode) -> String {
        mode == .pitching ? L("mode_pitching_label") : L("mode_batting_label")
    }
}

struct WeakPointTrendView: View {

    @ObservedObject private var store   = PracticeRecordStore.shared
    @ObservedObject private var premium = PremiumManager.shared

    @State private var showExplainer = false
    @State private var showPremium   = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(L("weakpoint_trend_screen_title"))
                        .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer()
                    Button { dismiss() } label: {
                        Text(L("btn_close"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 10)

                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(FormMode.allCases, id: \.self) { mode in
                            trendCard(for: mode)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showExplainer) {
            WeakPointExplainerSheet {
                showExplainer = false
                // シートを閉じ切ってから購入シートを出す
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { showPremium = true }
            }
            .presentationDetents([.medium, .large])
        }
        .premiumSheet(isPresented: $showPremium)
    }

    @ViewBuilder
    private func trendCard(for mode: FormMode) -> some View {
        if store.records.contains(where: { $0.mode == mode }) {
            let result = WeakPointAnalyzer.analyze(records: store.records, mode: mode)
            let title = String(format: L("weakpoint_card_title"), ComponentText.modeLabel(mode))

            if !result.hasEnoughForWorstComponent {
                let more = WeakPointAnalyzer.minForWorstComponent - result.sessionCount
                card(title: title, body: String(format: L("weakpoint_insufficient_data"), more),
                     imageFile: nil, locked: false)
            } else if !premium.isPremium {
                Button { showExplainer = true } label: {
                    card(title: title,
                         body: String(format: L("weakpoint_locked_message"), result.sessionCount),
                         imageFile: nil, locked: true)
                }
                .buttonStyle(.plain)
            } else {
                card(title: title, body: premiumBody(result, mode: mode),
                     imageFile: result.recentImageFile, locked: false)
            }
        }
    }

    private func premiumBody(_ r: WeakPointAnalyzer.Result, mode: FormMode) -> String {
        var lines = [String(format: L("weakpoint_worst_component"),
                            ComponentText.names[r.worstComponentIndex],
                            r.worstComponentCount, r.sessionCount)]
        if r.hasEnoughForTrend {
            let key: String
            switch r.trend {
            case .improving: key = "weakpoint_trend_improving"
            case .worsening: key = "weakpoint_trend_worsening"
            default:         key = "weakpoint_trend_steady"
            }
            lines.append(String(format: L(key), r.olderAvg, r.newerAvg))
            lines.append(String(format: L("weakpoint_advice_prefix"),
                                ComponentText.improvements(for: mode)[r.worstComponentIndex]))
        } else {
            lines.append(String(format: L("weakpoint_trend_pending"),
                                WeakPointAnalyzer.minForTrend - r.sessionCount))
        }
        return lines.joined(separator: "\n")
    }

    private func card(title: String, body: String, imageFile: String?, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            Text(body)
                .font(.system(size: 14))
                .foregroundColor(locked ? AppColors.cyan : .white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
            if let url = WeakPointImageStore.url(for: imageFile),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(10)
                    .accessibilityLabel(L("weakpoint_image_content_description"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.card)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(locked ? AppColors.cyan.opacity(0.6) : Color.clear, lineWidth: 1))
        .cornerRadius(14)
    }
}

/// 無料ユーザーがロック中の傾向カード（または結果画面のティーザー）をタップしたときに、
/// 購入シートの前に「何が見られる機能なのか」を説明するシート。
struct WeakPointExplainerSheet: View {

    let onUpgrade: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.11).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    Text("📊").font(.system(size: 40)).padding(.top, 24)
                    Text(L("weakpoint_explainer_title"))
                        .font(.system(size: 19, weight: .bold)).foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text(L("weakpoint_explainer_body"))
                        .font(.system(size: 14)).foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L("weakpoint_explainer_sample"))
                        .font(.system(size: 13)).foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(AppColors.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cyan.opacity(0.5)))
                        .cornerRadius(12)
                    Button(action: onUpgrade) {
                        Text(L("btn_weakpoint_upgrade"))
                            .font(.system(size: 16, weight: .bold)).foregroundColor(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(AppColors.gold).cornerRadius(12)
                    }
                    .padding(.top, 4)
                    Button { dismiss() } label: {
                        Text(L("btn_close"))
                            .font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
                            .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    WeakPointTrendView()
}
