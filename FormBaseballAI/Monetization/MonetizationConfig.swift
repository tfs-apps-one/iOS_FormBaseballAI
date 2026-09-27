// MonetizationConfig.swift — 課金・広告まわりの ID / URL を 1 か所にまとめたもの。
// ID・URL はすべて本番用に設定済み（2026-09 リリース版）。

import Foundation

enum MonetizationConfig {

    /// リワード（動画）広告ユニット ID（iOS 用）。
    /// 本番 ID（iOS 用に AdMob で作成したリワード広告ユニット）。
    ///  開発中に大量に広告を表示して確認する場合は、無効なトラフィック扱いを避けるため
    ///  Google の iOS テスト用 ID（ca-app-pub-3940256099942544/1712485313）に一時的に戻すか、
    ///  AdMob 管理画面で自分の端末をテストデバイスに登録すること。
    static let rewardedAdUnitID = "ca-app-pub-4924620089567925/7928421392"

    /// 未ロード時に「読み込み完了を待ってから表示」する最大待ち時間（秒）。
    static let rewardedShowWaitTimeout: TimeInterval = 8

    /// 残り回数がこの値以下になったら、診断後にカメラ画面上部で残り回数を知らせる。
    static let lowQuotaNoticeThreshold = 2

    /// 利用規約（EULA）。App Store の自動更新サブスクでは購入画面からのリンクが必須
    /// （審査ガイドライン 3.1.2）。独自の規約が無ければ Apple 標準 EULA でよい。
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// プライバシーポリシー。自動更新サブスクでは購入画面からのリンクが必須。
    /// App Store Connect の「プライバシーポリシー URL」と同じものにすること。
    static let privacyPolicyURL = URL(string: "https://tfs-apps-one.github.io/")!
}
