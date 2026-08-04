// ResultView.swift — Displays the full multi-frame analysis result.
// Mirrors: tfsapps.formbaseballai.result.ResultActivity
//
// Shows:
//   • Mode badge + star rating + numeric average score
//   • Phase score bar chart (up to 8 phases, worst highlighted in red, tappable)
//   • Skeleton comparison image for the selected phase
//   • Per-component breakdown for the selected phase
//   • Strengths and improvements list for the selected phase
//   • "Try Again" returns to the camera screen
//
// Tapping any "Phase N" row switches all of the detail panels below (image,
// breakdown, strengths/improvements) to that phase. The worst-scoring phase
// is selected by default when the screen first appears.

import SwiftUI

struct ResultView: View {

    let result: MultiFrameResult

    /// Which phase's details are currently shown; defaults to the worst phase.
    @State private var selectedPhaseIndex: Int

    @Environment(\.dismiss) private var dismiss

    init(result: MultiFrameResult) {
        self.result = result
        _selectedPhaseIndex = State(initialValue: result.worstPhaseIndex)
    }

    var body: some View {
        ZStack {
            Color(red: 0.078, green: 0.078, blue: 0.078).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // ── Header ────────────────────────────────────────────
                    header

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
                    .padding(.bottom, 40)
                }
                .padding(.top, 16)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
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
