// RewardedAdManager.swift — リワード（動画）広告だけを扱うマネージャー。
// Mirrors: tfsapps.formbaseballai.ads.RewardedAdManager
//
// バナー／インタースティシャル広告は Android v3.0 に合わせて全廃したため、
// アプリ内で使う広告はこれのみ。
//
// 報酬の付与は onRewardEarned（= AdMob の userDidEarnRewardHandler）が
// 呼ばれた時点でのみ行うこと。
//
// Google Mobile Ads SDK 11+ の接頭辞なし Swift API（RewardedAd / Request /
// FullScreenContentDelegate）を使用。

import Foundation
import UIKit
import GoogleMobileAds

@MainActor
final class RewardedAdManager: NSObject {

    static let shared = RewardedAdManager()

    struct Listener {
        /// 視聴完了（報酬獲得）。ここで回数を加算する。
        let onRewardEarned: () -> Void
        /// 広告が閉じられた。rewarded=false なら途中で閉じられた。
        let onAdClosed: (_ rewarded: Bool) -> Void
        /// 広告を表示できなかった（在庫なし・通信エラー等）。
        let onAdUnavailable: () -> Void
    }

    private var rewardedAd: RewardedAd?
    private var loading = false

    private var pendingListener: Listener?
    private var pendingTimeout: Task<Void, Never>?

    /// 表示中の広告のリスナーと報酬獲得フラグ。
    private var activeListener: Listener?
    private var activeEarned = false

    private override init() {
        super.init()
    }

    var isReady: Bool { rewardedAd != nil }

    /// 先読み。既にロード済み／ロード中なら何もしない。
    func load() {
        guard rewardedAd == nil, !loading else { return }
        AdsBootstrap.startSDKIfNeeded()
        loading = true
        RewardedAd.load(with: MonetizationConfig.rewardedAdUnitID, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.loading = false
                if let error {
                    #if DEBUG
                    print("RewardedAdManager: failed to load — \(error.localizedDescription)")
                    #endif
                    self.rewardedAd = nil
                    let l = self.pendingListener
                    self.clearPending()
                    l?.onAdUnavailable()
                    return
                }
                self.rewardedAd = ad
                if let l = self.pendingListener {
                    self.clearPending()
                    self.show(l)
                }
            }
        }
    }

    /// 広告を表示する。未ロードなら読み込みを待って表示（タイムアウトあり）。
    func show(_ listener: Listener) {
        guard let ad = rewardedAd else {
            pendingListener = listener
            pendingTimeout?.cancel()
            pendingTimeout = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(MonetizationConfig.rewardedShowWaitTimeout * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }
                let l = self.pendingListener
                self.clearPending()
                l?.onAdUnavailable()
            }
            load()
            return
        }

        guard let presenter = UIApplication.topMostViewController() else {
            listener.onAdUnavailable()
            return
        }

        rewardedAd = nil
        activeListener = listener
        activeEarned = false
        ad.fullScreenContentDelegate = self
        ad.present(from: presenter) { [weak self] in
            Task { @MainActor in
                guard let self, !self.activeEarned else { return }
                self.activeEarned = true
                self.activeListener?.onRewardEarned()
            }
        }
    }

    /// 画面破棄時に呼ぶ。待機中の表示要求を破棄する。
    func cancelPending() {
        clearPending()
    }

    private func clearPending() {
        pendingTimeout?.cancel()
        pendingTimeout = nil
        pendingListener = nil
    }
}

extension RewardedAdManager: FullScreenContentDelegate {

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            let l = self.activeListener
            let earned = self.activeEarned
            self.activeListener = nil
            l?.onAdClosed(earned)
            self.load() // 次回のために先読み
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            #if DEBUG
            print("RewardedAdManager: failed to present — \(error.localizedDescription)")
            #endif
            let l = self.activeListener
            self.activeListener = nil
            l?.onAdUnavailable()
            self.load()
        }
    }
}
