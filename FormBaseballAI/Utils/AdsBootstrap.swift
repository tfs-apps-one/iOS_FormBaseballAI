// AdsBootstrap.swift — One-time AdMob startup, called from AppDelegate at
// launch (see OrientationLock.swift, which hosts the app's AppDelegate).
//
// The only ad left in the app is the rewarded video (see RewardedAdManager —
// banner and interstitial ads were removed to match Android v3.0). Premium
// users never see ads, so for them neither the App Tracking Transparency
// prompt nor the Mobile Ads SDK is started at all (Android: "プレミアム会員では
// MobileAds.initialize を呼ばない").
//
// Order matters for free users: Apple wants the ATT prompt requested after
// the app's UI is visible (a fixed delay is the simplest reliable way to
// guarantee that from AppDelegate), and the Mobile Ads SDK should start
// regardless of how the user answers — AdMob still serves non-personalized
// ads without tracking permission.

import Foundation
import AppTrackingTransparency
import GoogleMobileAds

enum AdsBootstrap {

    private static var sdkStarted = false

    static func start() {
        guard !PremiumManager.cachedIsPremium else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            requestTrackingAuthorizationIfNeeded {
                startSDKIfNeeded()
            }
        }
    }

    /// Starts the Mobile Ads SDK once. Safe to call repeatedly (RewardedAdManager
    /// calls it before its first load in case launch-time startup was skipped).
    static func startSDKIfNeeded() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !sdkStarted else { return }
        sdkStarted = true
        MobileAds.shared.start(completionHandler: nil)
    }

    private static func requestTrackingAuthorizationIfNeeded(then completion: @escaping () -> Void) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            completion()
            return
        }

        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async { completion() }
        }
    }
}
