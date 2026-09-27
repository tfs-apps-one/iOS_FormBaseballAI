# AI Baseball Form Coach — iOS セットアップ手順

## 1. CocoaPods インストール（初回のみ）

```bash
sudo gem install cocoapods
```

## 2. 依存ライブラリのインストール

```bash
cd ~/iOS/FormBaseballAI
pod install
```

インストール後、**必ず** `FormBaseballAI.xcworkspace` を開いてください（`.xcodeproj` ではなく）。

```bash
open FormBaseballAI.xcworkspace
```

## 3. Xcodeで新しいSwiftファイルをプロジェクトに追加

以下のフォルダとファイルを Xcode の Project Navigator にドラッグ&ドロップしてください：

```
FormBaseballAI/
├── Models/
│   ├── FormMode.swift
│   ├── CoachModel.swift
│   ├── CapturePose.swift
│   ├── FrameCapture.swift
│   ├── MultiFrameResult.swift
│   └── PoseResult.swift
├── Analyzer/
│   ├── PoseAnalyzer.swift
│   └── PoseValidator.swift
├── Scoring/
│   └── FormScorer.swift
├── ViewModels/
│   └── CameraViewModel.swift
├── Views/
│   ├── HomeView.swift
│   ├── CameraView.swift
│   ├── PoseOverlayUIView.swift
│   └── ResultView.swift
├── Utils/
│   └── SkeletonRenderer.swift
├── en.lproj/
│   └── Localizable.strings
├── ja.lproj/
│   └── Localizable.strings
└── Info.plist
```

**追加方法：**
1. Xcodeの左パネルで `FormBaseballAI` フォルダを右クリック
2. "Add Files to FormBaseballAI..." を選択
3. 各フォルダを選択して追加（"Create groups" を選択）

## 4. Info.plist の設定

Xcodeプロジェクトの `Info.plist` に以下を追加（`Info.plist` ファイルが既にある場合はマージ）：
- `NSCameraUsageDescription`: カメラ権限の説明文
- `GADApplicationIdentifier`: AdMob App ID

## 5. 課金（StoreKit 2）と広告（リワード動画）の設定 — Android v3.0 と同期

Android 版で先行実装した「1日5回の無料枠＋リワード動画（+3回）＋新プレミアム（買い切り／月額）」を移植済みです。
バナー広告・インタースティシャル広告は Android v3.0 に合わせて**全廃**しました（残る広告はリワード動画のみ）。

### 5-1. App Store Connect でアプリ内課金を作成

| 種類 | 製品 ID（コードと一致させる） | 参考価格 | 備考 |
|------|------------------------------|---------|------|
| 非消耗型（Non-Consumable） | `premium_plan` | ¥1,200 | 買い切り |
| 自動更新サブスクリプション | `premium_monthly` | ¥150 / 1か月 | サブスクリプショングループ「Premium」を作成して追加 |

- 製品 ID は `Monetization/EntitlementPolicy.swift` の定数と**完全一致**させてください（変更する場合はコード側も変更）。
- 「契約／税金／口座情報」で有料 App 契約が有効になっている必要があります。
- 初回はアプリ内課金を**アプリのバージョンと一緒に審査へ提出**します（バージョンページの「App 内課金とサブスクリプション」で追加）。
- 審査用メモに「無料枠（1日5回）を使い切る → 動画 or プレミアム」の再現手順を書いておくとスムーズです。

### 5-2. 必須のリンク（審査ガイドライン 3.1.2）

自動更新サブスクは購入画面に **利用規約（EULA）** と **プライバシーポリシー** のリンクが必須です。
`Monetization/MonetizationConfig.swift` の `privacyPolicyURL` を公開中の URL に差し替えてください（現在は仮の `https://example.com/privacy`）。
利用規約は Apple 標準 EULA を指定済みです。App Store Connect の「App 情報」にも同じプライバシーポリシー URL を登録し、
説明文（アプリ概要）の末尾にも利用規約へのリンクを記載してください。

### 5-3. AdMob（リワード広告）の本番設定

| ファイル | 現在（テスト用） | 本番に差し替え |
|---------|----------------|--------------|
| `Monetization/MonetizationConfig.swift` `rewardedAdUnitID` | `ca-app-pub-3940256099942544/1712485313` | **iOS 用**のリワード広告ユニット ID |
| `Info.plist` `GADApplicationIdentifier` | `ca-app-pub-3940256099942544~1458002511` | iOS 用の AdMob App ID |

※ Android 用のユニット ID（`ca-app-pub-4924620089567925/7006714868`）は iOS では使えません。AdMob で iOS アプリを登録し、リワード広告ユニットを新規作成してください。

### 5-4. シミュレーター／実機での課金テスト（StoreKit 構成ファイル）

プロジェクト直下に `Products.storekit`（上記 2 商品を定義済み）を置いています。
1. Xcode → Product → Scheme → Edit Scheme… → Run → Options
2. **StoreKit Configuration** で `Products.storekit` を選択
3. 実行すると App Store Connect なしで購入・復元・サブスク更新／失効を試せます（Debug → StoreKit → Manage Transactions）

本番の商品で試す場合は StoreKit Configuration を「None」に戻し、Sandbox アカウントでテストしてください。

### 5-5. 仕様（Android と同一）

| 項目 | 内容 | 実装 |
|------|------|------|
| 無料枠 | 1日5回（ピッチング・バッティング合計）。端末の日付が変わるとリセット | `DailyQuotaPolicy` / `DailyQuotaManager` |
| 時刻改ざん対策 | 同一起動中は単調時計で補正／時計を戻しても回数は増えない／大きな巻き戻しは基準のみ引き直し | 同上 |
| リワード | 動画を最後まで見ると +3 回（報酬コールバック時のみ付与） | `RewardedAdManager` |
| 消費タイミング | 診断が完了し結果画面へ進むとき | `CameraView.consumeQuotaThenNavigate()` |
| 残り少ない通知 | 残り2回以下で、結果画面から戻ったときカメラ画面上部に表示 | `CameraView` |
| プレミアム | 買い切り or 月額のどちらかが有効ならプレミアム。照会失敗時はキャッシュを維持 | `EntitlementPolicy` / `PremiumManager` / `StoreManager` |
| 練習記録 | 保存は常に30件。無料は直近3件のみ表示＋アンロックカード | `PracticeRecordStore` / `PracticeRecordListView` |
| 成長グラフ | 無料は直近3件、プレミアムは30件（横画面なので購入導線は置かない） | `PracticeRecordGraphView` |
| ウィークポイント傾向 | 直近5回から最大の課題・推移・アドバイス。無料はロック表示→説明→購入 | `WeakPointAnalyzer` / `WeakPointTrendView` |
| 自己ベスト | 更新の事実は無料でも表示。更新幅・「あと○点」・ホームの表示はプレミアム | `PersonalBestManager` / `ProgressComparator` |
| 前回との比較 | 総合点の差は無料でも表示。5部位ごとの差はプレミアム | `ResultView.progressCards` |
| お知らせ | ホーム右上。内容を変えたら `NoticeManager.currentNoticeVersion` を +1 | `NoticeView` |

iOS 版の差分: Android の「既存プレミアム購入者への永続適用（祖父条項）」と「v3.0 リリース特価」の告知は iOS に該当しないため表示していません。
iOS で広告入りの版を既にリリースしている場合のみ、`NoticeView.showsAdsRemovalItem` を `true` にすると「広告撤廃」の項目を表示できます。

## 6. アプリアイコン

`Assets.xcassets/AppIcon.appiconset` にAndroid版と同じ `icon_512.png` を追加してください。

## 7. ビルド設定確認

- Deployment Target: iOS 15.0以上
- Signing: 自分のApple Developer アカウントで署名
- Privacy: Info.plist のカメラ権限説明が正しいか確認

## 8. 実機テスト

**重要**: カメラを使用するため、**実機（iPhone）でのテストが必要**です。シミュレーターではカメラが動作しません。

---

## ファイル構成と Android との対応関係

| iOS | Android | 役割 |
|-----|---------|------|
| `HomeView.swift` | `MainActivity.java` | モード選択画面 |
| `CameraView.swift` | `CameraActivity.java` | カメラ画面・録画 |
| `PoseOverlayUIView.swift` | `PoseOverlayView.java` | AR骨格オーバーレイ |
| `ResultView.swift` | `ResultActivity.java` | 分析結果画面 |
| `PoseAnalyzer.swift` | `PoseAnalyzer.java` | ML Kit骨格検出 |
| `PoseValidator.swift` | `PoseValidator.java` | ポーズ検証 |
| `FormScorer.swift` | `FormScorer.java` | フォームスコアリング |
| `CoachModel.swift` | `CoachModel.java` | 理想角度データ |
| `CameraViewModel.swift` | `CameraViewModel.java` | 状態管理 |
| `SkeletonRenderer.swift` | `SkeletonBitmapRenderer.java` | 静止画レンダリング |
| `DailyQuotaPolicy.swift` / `DailyQuotaManager.swift` | `quota/DailyQuotaPolicy.java` / `DailyQuotaManager.java` | 1日の無料枠 |
| `EntitlementPolicy.swift` / `PremiumManager.swift` | `model/EntitlementPolicy.java` / `PremiumManager.java` | プレミアム権利 |
| `StoreManager.swift` | `model/BillingManager.java` | StoreKit 2（Play Billing 相当） |
| `PremiumSheet.swift` | `model/PremiumDialogHelper.java` | プレミアム購入画面 |
| `RewardedAdManager.swift` | `ads/RewardedAdManager.java` | リワード動画 |
| `QuotaExhaustedDialog.swift` | `dialog_quota_exhausted.xml` | 無料枠切れモーダル |
| `PracticeRecordStore.swift` | `history/HistoryManager.java` | 練習記録 |
| `PracticeRecordListView.swift` / `PracticeRecordGraphView.swift` | `history/HistoryActivity.java` / `GraphActivity.java` | 練習記録・グラフ |
| `WeakPointAnalyzer.swift` / `WeakPointTrendView.swift` | `history/WeakPointAnalyzer.java` / `WeakPointTrendActivity.java` / `WeakPointExplainerDialog.java` | ウィークポイント傾向 |
| `PersonalBestManager.swift` / `ProgressComparator.swift` | `history/PersonalBestManager.java` / `ProgressComparator.java` | 自己ベスト・前回比較 |
| `NoticeView.swift` | `notice/NoticeActivity.java` | お知らせ |
