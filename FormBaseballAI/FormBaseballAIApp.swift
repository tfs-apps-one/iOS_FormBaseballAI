//
//  FormBaseballAIApp.swift
//  AI Baseball Form Coach / AI野球フォーム診断
//

import SwiftUI

@main
struct FormBaseballAIApp: App {

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
