// PracticeRecordListView.swift — Lists up to the last 30 diagnosis results
// (score + weak-point summary), newest first. The "グラフ" button in the
// top-right pushes into PracticeRecordGraphView, a landscape-locked line
// chart of the same history.
// Mirrors: tfsapps.formbaseballai.practice.PracticeRecordActivity

import SwiftUI

struct PracticeRecordListView: View {

    @ObservedObject private var store = PracticeRecordStore.shared
    @State private var showGraph = false

    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f
    }()

    var body: some View {
        ZStack {
            Color(red: 0.078, green: 0.078, blue: 0.078).ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if store.records.isEmpty {
                    Spacer()
                    Text(NSLocalizedString("practice_record_empty", comment: ""))
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(store.records) { record in
                                PracticeRecordCard(record: record, dateText: Self.dateFormatter.string(from: record.date))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $showGraph) {
            PracticeRecordGraphView(records: store.records)
        }
    }

    // MARK: – Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Text(NSLocalizedString("practice_record_title", comment: ""))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            Button {
                showGraph = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 15, weight: .semibold))
                    Text(NSLocalizedString("btn_graph", comment: ""))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.937, green: 0.325, blue: 0.314))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
            }
            .disabled(store.records.isEmpty)
            .opacity(store.records.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}

// MARK: – Record card

private struct PracticeRecordCard: View {
    let record: PracticeRecord
    let dateText: String

    /// Matches the app's existing pitching = green / batting = orange scheme
    /// (see HomeView / ResultView) so the practice log stays visually consistent.
    private var modeColor: Color {
        record.mode == .pitching
            ? Color(red: 0.133, green: 0.545, blue: 0.133)
            : Color(red: 0.827, green: 0.329, blue: 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(dateText)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                Text(String(format: "%.1f", record.score))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(record.mode.localizedName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(modeColor)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("practice_record_improvements", comment: ""))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 1, green: 0.42, blue: 0.31))

                Text(record.improvementSummary)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
}

#Preview {
    PracticeRecordListView()
}
