# NFR運用メモ

## 目的
非機能要件（起動性能・編集プレビュー・保存性能）を定期的に再検証し、リリース品質を維持する。

## 実行タイミング
- 毎PR: 4K中心のNFRテストを実行
- リリース前: 8Kを有効化して実機で再実行
- リリース後: 週1回または重い画像処理変更後に再実行

## 実行コマンド
### 1. 4K中心（通常運用）
```bash
xcodebuild -project GLogo.xcodeproj -scheme GLogo \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:GLogoTests/NFRPerformanceTests \
  test
```

### 2. 8K有効（リリース前）
```bash
PERF_RUN_8K=1 xcodebuild -project GLogo.xcodeproj -scheme GLogo \
  -destination 'id=<実機UDID>' \
  -only-testing:GLogoTests/NFRPerformanceTests \
  test
```

### 3. 起動NFR
```bash
xcodebuild -project GLogo.xcodeproj -scheme GLogo \
  -destination 'id=<実機UDID>' \
  -only-testing:GLogoUITests/NFRLaunchPerformanceTests \
  test
```

## Xcodeから8Kを有効化する方法
1. `Product > Scheme > Edit Scheme...`
2. `Test > Arguments`
3. `Environment Variables` に `PERF_RUN_8K=1` を追加
4. `NFRPerformanceTests` を実行

## 直近実測（2026-02-17）
- 端末: iPhone 16
- OS: iOS 26.2.1

判定結果:
- `NFRPerformanceTests`（4K/8K）: 失敗なし
- `NFRLaunchPerformanceTests`: 失敗なし

観測値（ログ抜粋）:
- Save 8K SDR テストケース実行時間: `2.762s`（passed）
- Save 8K HDR テストケース実行時間: `2.442s`（passed）
- Launch System Metric Average: `0.293s`
- Memory Peak Physical（4K Preview）:
  - SDR: `165495.848 kB`
  - HDR: `160461.021 kB`

## 注意点
- `NFRPerformanceTests` は閾値超過時のみ `P95` 値を詳細表示する。
- `Memory Physical` は差分計測のため、0や負値が混在することがある。
- メモリは `Memory Peak Physical` を主指標として扱う。
