// ReviewPromptManager.swift — Tracks app launch count and decides whether to
// show the in-app "please review" prompt.
//
// Important: this class only decides *whether we ask*. It never reads or
// reacts to a star rating the user might give — Apple's guidelines
// (4.3 App Review Guidelines, Human Interface Guidelines "Ratings and
// Reviews") prohibit gating a review prompt behind a positive in-app
// rating ("thumbs up → App Store review, thumbs down → hidden feedback
// form"). Everyone who reaches the launch threshold sees the same prompt.

import Foundation
import UIKit

final class ReviewPromptManager {

    static let shared = ReviewPromptManager()

    // MARK: - Config

    /// Show the prompt once the user has launched the app this many times.
    private let launchThreshold = 3

    /// Replace with your numeric App Store Connect "Apple ID"
    /// (App Store Connect → App Information → General Information → Apple ID).
    /// Do NOT use the bundle identifier here — it must be the numeric ID.
    private let appStoreID = "6796918322"

    // MARK: - Storage keys

    private let launchCountKey = "reviewPrompt_launchCount"
    private let optedOutKey    = "reviewPrompt_optedOut"

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Launch counting

    /// Call exactly once per cold launch (see FormBaseballAIApp.init()).
    func recordLaunch() {
        guard !defaults.bool(forKey: optedOutKey) else { return }
        let count = defaults.integer(forKey: launchCountKey) + 1
        defaults.set(count, forKey: launchCountKey)
    }

    // MARK: - Decision

    /// Whether the review prompt should be shown right now.
    /// Shows on every launch from launchThreshold onward until the user
    /// explicitly opts out via "次回以降は表示しない" — tapping "評価する"
    /// does NOT suppress future prompts, only opting out does.
    var shouldShowPrompt: Bool {
        guard !defaults.bool(forKey: optedOutKey) else { return false }
        return defaults.integer(forKey: launchCountKey) >= launchThreshold
    }

    // MARK: - Actions

    /// Suppress the prompt for all future launches.
    /// Call this ONLY from the "次回以降は表示しない" button — tapping
    /// "評価する" should NOT call this, so the prompt keeps appearing on
    /// every later launch (3rd, 4th, 5th, …) until the user opts out.
    func optOut() {
        defaults.set(true, forKey: optedOutKey)
    }

    /// Sends the user straight to the App Store's "Write a Review" screen
    /// (star rating + comment box). This requires the app to already be
    /// live on the App Store, and `appStoreID` above must be set correctly.
    func openAppStoreReviewPage() {
        guard appStoreID != "YOUR_APP_STORE_ID",
              let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreID)?action=write-review")
        else {
            #if DEBUG
            assertionFailure("ReviewPromptManager.appStoreID is not set. Fill in your numeric App Store Connect Apple ID.")
            #endif
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: - Debug helpers (optional)

    #if DEBUG
    /// Reset all review-prompt state so you can test the flow again in Simulator.
    func debugReset() {
        defaults.removeObject(forKey: launchCountKey)
        defaults.removeObject(forKey: optedOutKey)
    }
    #endif
}
