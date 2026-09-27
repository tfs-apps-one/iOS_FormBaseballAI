// ResultView.swift — Displays the full multi-frame analysis result.
// Mirrors: tfsapps.formbaseballai.result.ResultActivity
//
// Shows:
//   • Mode badge + star rating + numeric average score
//   • Phase score bar chart (up to 8 phases, worst highlighted in red, tappable)
//   • Skeleton comparison image for the selected phase
//   • Per-component breakdown for the selected phase
//   • Strengths and improvements list for the selected phase
//   • 自己ベスト / 前回との比較カード（詳細はプレミアム — see progressCards）
//   • "Try Again" returns to the camera screen
//   • Weak Point Trend teaser (free users only — see weakPointTeaser)
//
// Tapping any "Phase N" row switches all of the detail panels below (image,
// breakdown, strengths/improvements) to that phase. The worst-scoring phase
// is selected by default when the screen first appears.
//
// 記録の保存・自己ベストの更新は CameraView 側で「一度だけ」行い、その直前に
// 取得した前回の記録と自己ベストを ProgressSnapshot として受け取る
// （SwiftUI の View は何度も生成され得るため、ここでは保存しない）。

import SwiftUI

/// 結果画面の「自己ベスト」「前回との比較」を描くための材料。
/// 今回の記録を保存する「前」に作ること。
struct ProgressSnapshot {
    let best: ProgressComparator.BestResult
    /// 同じモードの前回の記録。なければ nil。
    let previousRecord: PracticeRecord?
    /// 今回の部位別スコア（全フェーズ平均）。
    let currentComponentScores: [Float]?
}

struct ResultView: View {

    let result: MultiFrameResult
    let progress: ProgressSnapshot?

    /// Which phase's details are currently shown; defaults to the worst phase.
    @State private var selectedPhaseIndex: Int

    @ObservedObject private var premium = PremiumManager.shared
    @State private var showPremium   = false
    @State private var showExplainer = false

    @Environment(\.dismiss) private var dismiss

    init(result: MultiFrameResult, progress: ProgressSnapshot? = nil) {
        self.result = result
        self.progress = progress
        _selectedPhaseIndex = State(initialValue: result.worstPhaseIndex)
    }

    var body: some View {
        ZStack {
            Color(red: 0.078, green: 0.078, blue: 0.078).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // ── Header ────────────────────────────────────────────
                    header

                    // ── 自己ベスト / 前回との比較 ─────────────────────────
                    progressCards
                        .padding(.horizontal, 20)

                    // ── Phase bar chart ───────────────────────────────────
                    phaseChart
                        .padding(.top, 20)

                    // ── Selected-phase image ──────────────────────────────
                    selectedPhaseImage
                        .padding(.top, 20)

                    // ── Component breakdown ───────────────────────────────
                    componentBreakdown
                        .padding(.top, 20)

                    // ── Strengths ─────────────────────────────────────────
                    feedbackSection(
                        title: NSLocalizedString("result_strengths", comment: ""),
                        items: result.strengthsPerPhase[selectedPhaseIndex],
                        color: Color(red: 0, green: 0.902, blue: 0.463)
                    )
                    .padding(.top, 16)

                    // ── Improvements ──────────────────────────────────────
                    feedbackSection(
                        title: NSLocalizedString("result_improvements", comment: ""),
                        items: result.improvementsPerPhase[selectedPhaseIndex],
                        color: Color(red: 1, green: 0.792, blue: 0.157)
                    )
                    .padding(.top, 8)

                    // ── Try Again ─────────────────────────────────────────
                    Button {
                        dismiss()
                    } label: {
                        Text(NSLocalizedString("btn_try_again", comment: ""))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(result.mode == .pitching ?
                                        Color(red: 0.133, green: 0.545, blue: 0.133) :
                                        Color(red: 0.827, green: 0.329, blue: 0))
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    // ── Weak Point Trend teaser（無料ユーザーのみ） ─────────
                    if !premium.isPremium {
                        weakPointTeaser
                            .padding(.horizontal, 20)
                            .padding(.top, 14)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showExplainer) {
            WeakPointExplainerSheet {
                showExplainer = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { showPremium = true }
            }
            .presentationDetents([.medium, .large])
        }
        .premiumSheet(isPresented: $showPremium)
    }

    // MARK: – 自己ベスト / 前回との比較
    // 無料: 自己ベスト更新の事実と総合点の前回差まで。更新幅・部位別の変化はプレミアム。

    @ViewBuilder
    private var progressCards: some View {
        if let progress {
            VStack(spacing: 12) {
                bestCard(progress.best)
                if let prev = progress.previousRecord {
                    compareCard(previous: prev, currentComponents: progress.currentComponentScores)
                }
            }
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func bestCard(_ best: ProgressComparator.BestResult) -> some View {
        switch best.kind {
        case .first:
            progressCard(gold: true) {
                cardText(String(format: L("progress_best_first"), best.current),
                         color: AppColors.gold, size: 14, bold: true)
            }
        case .newBest:
            progressCard(gold: true) {
                cardText(L("progress_best_new_title"), color: AppColors.gold, size: 18, bold: true)
                if premium.isPremium {
                    cardText(String(format: L("progress_best_new_detail"),
                                    best.previousBest, best.current, best.gain),
                             color: .white, size: 14)
                } else {
                    lockedLine(L("progress_best_locked"))
                }
            }
        case .notBest:
            if premium.isPremium {
                progressCard(gold: false) {
                    cardText(String(format: L("progress_best_remaining"),
                                    best.previousBest, best.pointsToBeat),
                             color: Color(white: 0.8), size: 13)
                }
            }
        }
    }

    private func compareCard(previous: PracticeRecord, currentComponents: [Float]?) -> some View {
        let total = ProgressComparator.totalDelta(previous: previous.score, current: result.averageScore)
        return progressCard(gold: false) {
            cardText(L("progress_compare_title"), color: .white, size: 15, bold: true)
            cardText(String(format: L("progress_compare_total"),
                            ProgressComparator.round(previous.score),
                            ProgressComparator.round(result.averageScore),
                            ProgressComparator.formatSigned(total)),
                     color: AppColors.delta(total, neutral: Color(white: 0.8)), size: 13)

            if !premium.isPremium {
                lockedLine(L("progress_compare_locked"))
            } else if let deltas = ProgressComparator.componentDeltas(previous: previous.componentScores,
                                                                      current: currentComponents),
                      let prev = previous.componentScores, let cur = currentComponents {
                let names = ComponentText.names
                ForEach(0..<min(deltas.count, names.count), id: \.self) { i in
                    deltaRow(name: names[i],
                             prev: ProgressComparator.round(prev[i]),
                             cur: ProgressComparator.round(cur[i]),
                             delta: deltas[i])
                }
            } else {
                // 旧バージョンで保存された記録には部位別スコアがない
                cardText(L("progress_compare_no_parts"), color: Color(white: 0.53), size: 12)
            }
        }
    }

    private func progressCard<Content: View>(gold: Bool,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 4) { content() }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(gold ? AppColors.gold.opacity(0.10) : Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(gold ? AppColors.gold.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 1))
            .cornerRadius(12)
    }

    private func cardText(_ text: String, color: Color, size: CGFloat, bold: Bool = false) -> some View {
        Text(text)
            .font(.system(size: size, weight: bold ? .bold : .regular))
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 無料ユーザー向けの「🔒 …はプレミアムで」行。タップでプレミアムの案内を開く。
    private func lockedLine(_ text: String) -> some View {
        Button { showPremium = true } label: {
            cardText(text, color: AppColors.cyan, size: 12)
                .padding(.top, 6)
        }
        .buttonStyle(.plain)
    }

    /// 部位ごとの行: 「右ひじ   72 → 78   ↑ +6」
    private func deltaRow(name: String, prev: Int, cur: Int, delta: Int) -> some View {
        let arrow = delta > 0 ? "↑ " : (delta < 0 ? "↓ " : "→ ")
        return HStack {
            Text(name).font(.system(size: 13)).foregroundColor(.white)
            Spacer()
            Text("\(prev) → \(cur)").font(.system(size: 12)).foregroundColor(Color(white: 0.6))
            Text(arrow + ProgressComparator.formatSigned(delta))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppColors.delta(delta, neutral: Color(white: 0.6)))
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.top, 6)
    }

    // MARK: – Weak Point Trend teaser

    /// 診断直後（上達が一番気になるタイミング）に無料ユーザーへ出す小さな案内。
    /// タップすると購入シートの前に説明シートを開く。
    private var weakPointTeaser: some View {
        Button { showExplainer = true } label: {
            Text(L("result_weakpoint_teaser"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.cyan)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cyan.opacity(0.6), lineWidth: 1))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: – Header

    private var header: some View {
        VStack(spacing: 8) {
            Text(result.mode.localizedName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(result.mode == .pitching ?
                            Color(red: 0.133, green: 0.545, blue: 0.133) :
                            Color(red: 0.827, green: 0.329, blue: 0))
                .cornerRadius(8)

            Text(result.starsString)
                .font(.system(size: 36))

            Text(String(format: "%@: %.0f / 100",
                        NSLocalizedString("label_avg_score", comment: ""), result.averageScore))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
    }

    // MARK: – Phase bar chart

    private var phaseChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("result_phase_scores", comment: ""))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            ForEach(result.phases.indices, id: \.self) { i in
                let phase      = result.phases[i]
                let isWorst    = (i == result.worstPhaseIndex)
                let isSelected = (i == selectedPhaseIndex)

                Button {
                    selectedPhaseIndex = i
                } label: {
                    HStack(spacing: 8) {
                        Text(String(format: "%@ %d",
                                    NSLocalizedString("label_phase", comment: ""), i + 1))
                            .font(.system(size: 12, weight: isWorst ? .bold : .regular))
                            .foregroundColor(isWorst ? Color(red: 0.937, green: 0.325, blue: 0.314) : .white)
                            .frame(width: 72, alignment: .leading)

                        ProgressView(value: Double(phase.overallScore), total: 100)
                            .tint(isWorst ? Color(red: 0.937, green: 0.325, blue: 0.314) :
                                            scoreColor(phase.overallScore))

                        Text(String(format: "%.0f", phase.overallScore))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isWorst ? Color(red: 0.937, green: 0.325, blue: 0.314) :
                                                       scoreColor(phase.overallScore))
                            .frame(width: 36, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.white.opacity(0.55) : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }

            // Worst phase label
            Text(String(format: "%@ %d  (%.0f%%)",
                        NSLocalizedString("result_worst_phase", comment: ""),
                        result.worstPhaseIndex + 1,
                        result.phases[result.worstPhaseIndex].overallScore))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(red: 0.937, green: 0.325, blue: 0.314))
                .padding(.top, 4)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    // MARK: – Selected-phase skeleton image

    private var selectedPhaseImage: some View {
        VStack {
            if selectedPhaseIndex < result.imagePaths.count,
               let path = result.imagePaths[selectedPhaseIndex],
               let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: – Component breakdown

    private var componentBreakdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(format: "%@ (%@ %d)",
                        NSLocalizedString("result_details", comment: ""),
                        NSLocalizedString("label_phase", comment: ""),
                        selectedPhaseIndex + 1))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 12)

            let componentNames = [
                NSLocalizedString("component_right_elbow",   comment: ""),
                NSLocalizedString("component_left_elbow",    comment: ""),
                NSLocalizedString("component_shoulder",      comment: ""),
                NSLocalizedString("component_hip",           comment: ""),
                NSLocalizedString("component_lead_knee",     comment: "")
            ]

            let selected = result.phases[selectedPhaseIndex]
            ForEach(componentNames.indices, id: \.self) { i in
                let score    = (i < selected.componentScores.count) ? selected.componentScores[i] : 0
                let measured = (i < selected.measuredAngles.count)  ? selected.measuredAngles[i]  : 0
                let ideal    = (i < selected.idealAngles.count)     ? selected.idealAngles[i]     : 0

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(componentNames[i])
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.0f%%", score))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(scoreColor(score))
                    }
                    ProgressView(value: Double(score), total: 100)
                        .tint(scoreColor(score))
                    if measured != 0 {
                        Text(String(format: "%.0f° → %.0f°", measured, ideal))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    } else {
                        Text("—")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 10)

                if i < componentNames.count - 1 {
                    Divider().background(Color.white.opacity(0.1))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    // MARK: – Feedback section

    private func feedbackSection(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(color)
                    Text(item)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    // MARK: – Helpers

    private func scoreColor(_ score: Float) -> Color {
        if score >= 80 { return Color(red: 0, green: 0.902, blue: 0.463) }
        if score >= 55 { return Color(red: 1, green: 0.792, blue: 0.157) }
        return Color(red: 0.937, green: 0.325, blue: 0.314)
    }
}
