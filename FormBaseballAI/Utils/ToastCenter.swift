// ToastCenter.swift — Android の Toast 相当の一時メッセージ。
//
// 購入完了・復元結果などはシートや広告が閉じた直後に出したいので、
// 画面階層ではなく専用の UIWindow（アラートより上のレベル・タッチは素通り）に表示する。
// これでどの画面・シートの上でも同じように見える。

import SwiftUI
import UIKit

@MainActor
final class ToastCenter {

    static let shared = ToastCenter()

    enum Duration {
        case short, long
        var seconds: TimeInterval { self == .short ? 2.2 : 3.8 }
    }

    private var window: UIWindow?
    private var hideTask: Task<Void, Never>?

    private init() {}

    func show(_ message: String, duration: Duration = .short) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }

        hideTask?.cancel()

        let host = UIHostingController(rootView: ToastView(message: message))
        host.view.backgroundColor = .clear

        let w = window ?? PassthroughWindow(windowScene: scene)
        w.windowLevel = .alert + 1
        w.backgroundColor = .clear
        w.isUserInteractionEnabled = false
        w.rootViewController = host
        w.isHidden = false
        w.alpha = 0
        window = w
        UIView.animate(withDuration: 0.18) { w.alpha = 1 }

        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration.seconds * 1_000_000_000))
            guard !Task.isCancelled, let self, let w = self.window else { return }
            UIView.animate(withDuration: 0.25, animations: { w.alpha = 0 }) { [weak self] _ in
                // 表示中に次のトーストが来ていたら、そのウィンドウは消さない
                guard let self, self.window === w, w.alpha == 0 else { return }
                w.isHidden = true
                self.window = nil
            }
        }
    }
}

private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

private struct ToastView: View {
    let message: String
    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cyan, lineWidth: 1.5))
                .cornerRadius(12)
                .padding(.horizontal, 28)
                .padding(.bottom, 90)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
