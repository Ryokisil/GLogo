# GLogo

GLogo は iOS 向けの画像編集アプリです。  
画像・テキスト・図形を重ねた編集、フィルター調整、保存までを一貫して行えます。

## 主な機能
- 画像・テキスト・図形のレイヤー編集
- 調整（彩度/明度/コントラスト/ハイライト/シャドウ/ブラック/ホワイト/色温度/ヴィブランス など）
- フィルタープリセット（Standard / HDR）
- 背景ぼかしマスク編集
- Undo / Redo（イベントソーシング）
- 合成画像保存（ベース画像解像度を維持）

## アーキテクチャ
MVVM + Clean Architecture
- `Views`: SwiftUI中心の表示層
- `ViewModels`: 画面状態と操作のオーケストレーション
- `UseCases`: ビジネスルール（インポート/レンダリング/保存/履歴）
- `Models`: 要素・プロジェクトなどのドメインデータ
- `Utils`: 共通ユーティリティ

## 技術スタック
- Swift / SwiftUI / UIKit
- Core Image / Core Graphics
- Swift Concurrency
- XCTest / XCUITest

## ディレクトリ構成
- `GLogo/App`: エントリポイント
- `GLogo/Models`: データモデル
- `GLogo/UseCases`: 編集・レンダリング・保存・履歴
- `GLogo/ViewModels`: 状態管理
- `GLogo/Views`: UI実装
- `GLogoTests`: Unit / Integration / Regression テスト

## 開発環境
- Xcode 26.1
- iOS Deployment Target: 17.6+

## 非機能要件（NFR）
最終更新: 2026-02-17  
ステータス: 直近実測を反映済み（iPhone 16 / iOS 26.2.1）

測定条件:
- Release ビルド（Debug計測は参考値扱い）
- 実機計測（端末クラスA: iPhone 16 / 端末クラスB: iPhone 12）
- 各シナリオ10回実行し、判定は P95 を採用（平均値は参考）
- 4K画像（HEIC/PNG）を基準に、SDR/HDRの両経路を計測

性能目標（P95）:
- 起動: クラスA <= 2.5s / クラスB <= 3.5s
- 編集プレビュー反映: SDR <= 100ms、HDR <= 140ms
- 保存（4K）: SDR <= 2.5s、HDR <= 3.2s
- 保存（8K）: SDR <= 6.0s、HDR <= 7.0s

直近実測（2026-02-17 / 実機: iPhone 16, iOS 26.2.1）:
- `NFRPerformanceTests` 4K/8K: 全シナリオ `passed`（P95閾値内）
- `NFRLaunchPerformanceTests`:
  - `testColdStartLatency_P95`: `passed`（クラスA閾値内）
  - `testColdStartLatency_SystemMetric`: Average `0.293s`
- 参考値（テストケース実行時間）:
  - 8K Save SDR: `2.762s`
  - 8K Save HDR: `2.442s`
- 参考値（Memory Peak Physical / 4K Preview）:
  - SDR: `165495.848 kB`
  - HDR: `160461.021 kB`

品質目標:
- 安定性: Crash-free users >= 99.5%（TestFlight / 本番）
- 回帰防止: Unit / Integration / Regression テストをリリース前に通過
- 出力整合: SDR/HDRともにベース解像度を維持し、主要調整値・テキスト効果（影/縁取り）を保存結果へ反映

## ビルド
```bash
xcodebuild -project GLogo.xcodeproj -scheme GLogo -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## テスト
全体:
```bash
xcodebuild -project GLogo.xcodeproj -scheme GLogo -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test
```

回帰テストのみ:
```bash
xcodebuild -project GLogo.xcodeproj -scheme GLogo \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:GLogoTests/FilterCatalogRegressionTests \
  -only-testing:GLogoTests/SavePipelineRegressionTests \
  test
```

## ドキュメント方針
README は「現在の正解（現行仕様）」のみを記載します。  
過去の実装経緯・調査メモ・詳細技術ノートは以下へ分離しています。
- `docs/technical-notes-legacy.md`
- `docs/nfr-operations.md`
