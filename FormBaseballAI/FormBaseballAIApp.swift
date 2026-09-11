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
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
    }
}
