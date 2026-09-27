//
//  FormBaseballAIApp.swift
//  AI Baseball Form Coach / AI野球フォーム診断
//

import SwiftUI

@main
struct FormBaseballAIApp: App {

    // Lets AppDelegate answer UIKit's orientation query, so the app can stay
    // portrait-only everywhere except the practice-record graph screen,
    // which locks itself to landscape while presented.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Counts a "launch" once per cold start of the app process.
        ReviewPromptManager.shared.recordLaunch()

        // StoreKit 2: 未処理の取引・更新・返金の監視を起動直後から開始し、
        // 商品情報と現在の権利（プレミアムかどうか）を App Store に照会する。
        StoreManager.shared.start()
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) {
            // 復帰時に権利を読み直す（サブスクの失効・別端末での購入などを反映）
            if scenePhase == .active {
                Task { await StoreManager.shared.refreshEntitlements() }
            }
        }
    }
}
