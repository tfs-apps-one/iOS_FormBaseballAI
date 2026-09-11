// PracticeRecordGraphView.swift — Landscape-locked line-chart view of the
// practice-record history: score (0–100) over time, one line per mode,
// colored to match the rest of the app (pitching = green, batting = orange).
// Mirrors: tfsapps.formbaseballai.practice.PracticeRecordGraphActivity

import SwiftUI
import Charts

struct PracticeRecordGraphView: View {

    /// Newest-first, as stored — this view re-sorts to oldest-first so the
    /// chart reads left (older) to right (more recent), like a trend line.
    let records: [PracticeRecord]

    @Environment(\.dismiss) private var dismiss

    private static let pointDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d H:mm"
        return f
    }()

    /// (chronological index, record) pairs, oldest first.
    private var chronological: [(index: Int, record: PracticeRecord)] {
        // .enumerated() yields (offset:element:) tuples, which Swift's type
        // checker treats as a different type from (index:record:) even
        // though the shapes match — Array(...) can't bridge the differing
        // labels through a generic Sequence conformance, so map explicitly.
        records.sorted { $0.date < $1.date }.enumerated().map { (index: $0.offset, record: $0.element) }
    }

    private func color(for mode: FormMode) -> Color {
        mode == .pitching
            ? Color(red: 0.133, green: 0.545, blue: 0.133)
            : Color(red: 0.827, green: 0.329, blue: 0)
    }

    private func legendLabel(for mode: FormMode) -> String {
        mode == .pitching
            ? NSLocalizedString("chart_legend_pitching", comment: "")
            : NSLocalizedString("chart_legend_batting", comment: "")
    }

    var body: some View {
        ZStack {
            Color(red: 0.078, green: 0.078, blue: 0.078).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                chart
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear { OrientationLock.lock(.landscape) }
        .onDisappear { OrientationLock.lock(.portrait) }
    }

    // MARK: – Header

    private var header: some View {
        HStack {
            legend

            Spacer()

            Text(NSLocalizedString("graph_title", comment: ""))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text(NSLocalizedString("btn_close", comment: ""))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(FormMode.allCases, id: \.self) { mode in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(for: mode))
                        .frame(width: 14, height: 14)
                    Text(legendLabel(for: mode))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
    }

    // MARK: – Chart

    private var chart: some View {
        let points = chronological

        // Both marks are grouped by the same "Mode" value so Swift Charts
        // treats pitching/batting as two independent series: each line
        // connects only its own mode's points (in x order), naturally
        // skipping x-slots that belong to the other mode — exactly the
        // jagged, two-color trend line the practice log is meant to show.
        return Chart {
            ForEach(points, id: \.record.id) { entry in
                LineMark(
                    x: .value("Index", entry.index),
                    y: .value("Score", entry.record.score)
                )
                .foregroundStyle(by: .value("Mode", legendLabel(for: entry.record.mode)))
                .interpolationMethod(.linear)

                PointMark(
                    x: .value("Index", entry.index),
                    y: .value("Score", entry.record.score)
                )
                .foregroundStyle(by: .value("Mode", legendLabel(for: entry.record.mode)))
                .symbolSize(70)
                .annotation(position: entry.index.isMultiple(of: 2) ? .top : .bottom, spacing: 4) {
                    Text(Self.pointDateFormatter.string(from: entry.record.date))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize()
                }
            }
        }
        .chartForegroundStyleScale(
            [legendLabel(for: .pitching): color(for: .pitching),
             legendLabel(for: .batting):  color(for: .batting)]
        )
        .chartLegend(.hidden)
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 20, 40, 60, 80, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let score = value.as(Int.self) {
                        Text("\(score)")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .chartXAxis(.hidden)
        .chartXScale(domain: -1...(max(points.count, 1)))
    }
}

#Preview {
    PracticeRecordGraphView(records: [])
}
