// UIApplication+TopViewController.swift — Finds the currently active
// (topmost) view controller, used to present rewarded (video) ads from
// whatever screen is actually on top right now.

import UIKit

extension UIApplication {
    /// The active window's root view controller, walking through any
    /// presented view controller so ads present from whatever is actually
    /// on screen right now.
    static func topMostViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
