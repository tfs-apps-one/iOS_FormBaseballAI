// ReviewPromptOverlay.swift — Custom "please review" popup.
//
// Shown as an overlay (not a .sheet/.alert) so it can't be swiped away
// without an explicit choice, matching the two options the app offers:
// "評価する" (Rate) and "次回以降は表示しない" (Don't show again).

import SwiftUI

struct ReviewPromptOverlay: View {

    let onRate: () -> Void
    let onDismissForever: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("⚾️")
                    .font(.system(size: 40))

                Text(NSLocalizedString("review_prompt_title", comment: ""))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("review_prompt_message", comment: ""))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)

                VStack(spacing: 10) {
                    Button(action: onRate) {
                        Text(NSLocalizedString("review_prompt_rate_button", comment: ""))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.133, green: 0.545, blue: 0.133)) // forest green, matches app accent
                            .cornerRadius(12)
                    }

                    Button(action: onDismissForever) {
                        Text(NSLocalizedString("review_prompt_dismiss_button", comment: ""))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .cornerRadius(20)
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
        .zIndex(1)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ReviewPromptOverlay(onRate: {}, onDismissForever: {})
    }
}
