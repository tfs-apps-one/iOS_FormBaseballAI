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

## 5. AdMob の本番設定

本番リリース前に以下のテスト用IDを本番IDに差し替えてください：

| ファイル | テスト用ID | 本番IDに差替 |
|---------|-----------|------------|
| `CameraView.swift` L147 | `ca-app-pub-3940256099942544/4411468910` | インタースティシャル iOS用ID |
| `CameraView.swift` L262 | `ca-app-pub-3940256099942544/2934735716` | バナー iOS用ID |
| `Info.plist` | `ca-app-pub-3940256099942544~1458002511` | AdMob App ID |

Google AdMobダッシュボード（https://admob.google.com）でiOS用の新しい広告ユニットを作成してください。

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
