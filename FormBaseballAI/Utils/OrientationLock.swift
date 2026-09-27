// OrientationLock.swift — Lets a single screen (the practice-record graph)
// force landscape while the rest of the app stays portrait-only.
//
// The app is portrait-only by default (see Info.plist). To rotate just the
// graph screen, PracticeRecordGraphView calls OrientationLock.lock(.landscape)
// on appear and OrientationLock.lock(.portrait) on disappear; AppDelegate
// reports whatever mask is currently set to UIKit.

import UIKit

enum OrientationLock {

    /// The orientation mask UIKit is currently allowed to rotate into.
    /// Defaults to portrait so every screen besides the graph is unaffected.
    static var mask: UIInterfaceOrientationMask = .portrait

    /// Updates the allowed mask and asks the active window scene to rotate
    /// to match right away (rather than waiting for the next natural
    /// rotation event).
    static func lock(_ mask: UIInterfaceOrientationMask) {
        self.mask = mask

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        if #available(iOS 16.0, *) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
            scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            let orientation: UIInterfaceOrientation = mask.contains(.landscapeRight) ? .landscapeRight : .portrait
            UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
        }
    }
}

/// Registered via @UIApplicationDelegateAdaptor in FormBaseballAIApp so UIKit
/// has a delegate to ask for the currently-allowed orientation mask, and to
/// give AdMob a standard launch hook (see AdsBootstrap.swift).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AdsBootstrap.start()
        return true
    }

    func application(_ application: UIApplication,
                      supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}
