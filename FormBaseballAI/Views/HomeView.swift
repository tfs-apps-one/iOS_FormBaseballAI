// HomeView.swift — Mode selection screen (equivalent to MainActivity).
// Mirrors: tfsapps.formbaseballai.MainActivity

import SwiftUI

struct HomeView: View {

    @State private var selectedMode: FormMode? = nil
    @State private var navigateToCamera = false
    @State private var navigateToPracticeRecord = false
    @State private var showReviewPrompt = false
    @State private var hasCheckedReviewPrompt = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // ── App icon ──────────────────────────────────────────────
                    Image("baseballai_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .cornerRadius(22)
                        .padding(.bottom, 24)

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
                        .padding(.bottom, 48)

                    // ── Mode buttons ──────────────────────────────────────────
                    VStack(spacing: 20) {
                        ModeButton(
                            title: NSLocalizedString("btn_pitching", comment: ""),
                            color: Color(red: 0.133, green: 0.545, blue: 0.133), // #228B22 forest green
                            icon: "figure.baseball"
                        ) {
                            selectedMode   = .pitching
                            navigateToCamera = true
                        }

                        ModeButton(
                            title: NSLocalizedString("btn_batting", comment: ""),
                            color: Color(red: 0.827, green: 0.329, blue: 0),     // #D35400 orange
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
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                    Spacer()
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
            .navigationBarHidden(true)
            .onAppear {
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
        }
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
