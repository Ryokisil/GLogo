# タスク完了時の実行ガイドライン

## 必須チェック項目

### 1. ビルド・コンパイル確認
```bash
# 基本ビルドエラーチェック
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo build

# 警告も含めた詳細チェック
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  build -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### 2. Swift 6.0 並行性チェック
```bash
# ストリクト並行性準拠確認
# プロジェクト設定でStrict Concurrency Checkingが有効になっているため、
# ビルド時に自動的に並行性問題が検出される

# 並行性関連のコンパイラ警告確認
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  build 2>&1 | grep -i "concurrency\|sendable\|actor"
```

### 3. メモリリークテスト実行
```bash
# 必須: ViewModelメモリリークテスト
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -only-testing:GLogoTests/ViewModelMemoryLeakTests test

# 必須: 操作系メモリリークテスト
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -only-testing:GLogoTests/OperationMemoryLeakTests test
```

## 機能別追加チェック

### UI/UX機能修正時
```bash
# UIテスト実行（該当機能）
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -only-testing:GLogoUITests test

# シミュレーター実機確認
xcrun simctl boot "iPhone 15 Pro"
# アプリを起動して手動動作確認
```

### 画像処理機能修正時
```bash
# Core Image関連のパフォーマンステスト
instruments -t "Core Image" -D core_image_trace.trace GLogo.app

# 高解像度画像テスト（4K以上）
# 実際に4284×5712の画像を使用してパフォーマンス確認
```

### Event Sourcing修正時
```bash
# イベント系テストの特別実行
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -only-testing:GLogoTests test | grep -i "event\|undo\|redo"

# 履歴機能の動作確認（手動テスト推奨）
```

## パフォーマンス確認

### メモリ使用量チェック
```bash
# メモリ使用量プロファイリング
instruments -t "Allocations" -D memory_check.trace GLogo.app

# リーク検出
instruments -t "Leaks" -D leak_check.trace GLogo.app
```

### 応答性テスト
```bash
# UI応答性測定
instruments -t "Time Profiler" -D ui_performance.trace GLogo.app

# 特に高解像度画像での応答性確認が重要
```

## コード品質確認

### 静的解析
```bash
# Xcode静的解析実行
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  analyze -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### コードカバレッジ
```bash
# テストカバレッジ測定
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -enableCodeCoverage YES test \
  -resultBundlePath TestResults.xcresult
```

## 特殊要件

### Swift 6.0準拠確認
- **Sendable プロトコル**: 新規作成したデータ型の並行安全性
- **@MainActor**: UI関連処理の適切な実行コンテキスト  
- **アクター分離**: データレース防止の確認
- **並行性警告**: コンパイラ警告の解決

### GLogo特有のチェック
- **Z-Index順**: 要素の描画・タッチ判定順序の一貫性
- **座標系統合**: SwiftUI/UIKit間の座標変換正確性
- **画像向き処理**: iOS画像向きの正しい処理
- **フィルター品質**: ITU-R BT.709準拠の処理結果

## エラー発生時の対応

### ビルドエラー
1. **派生データクリア**: `rm -rf ~/Library/Developer/Xcode/DerivedData/GLogo-*`
2. **クリーンビルド**: `xcodebuild clean build`
3. **依存関係再解決**: プロジェクト設定確認

### テスト失敗
1. **個別テスト実行**: 失敗テストを単体で実行し詳細確認
2. **メモリリーク**: `weak self`パターンと`autoreleasepool`確認
3. **並行性問題**: `@MainActor`と`Task`使用箇所の検証

### パフォーマンス問題  
1. **プロファイリング**: Instrumentsでボトルネック特定
2. **画像処理最適化**: 2段階処理の適切な実装確認
3. **メモリ効率**: 大容量画像処理でのメモリ管理

## 最終チェックリスト

- [ ] ✅ ビルド成功（警告含む）
- [ ] ✅ Swift 6.0並行性準拠
- [ ] ✅ メモリリークテスト通過
- [ ] ✅ 該当機能の動作確認
- [ ] ✅ パフォーマンス劣化なし
- [ ] ✅ コード品質基準遵守
- [ ] ✅ 日本語コメント・ドキュメント
- [ ] ✅ MARK構造整理
- [ ] ✅ Git準備（staging/commit）

## 完了報告テンプレート

```
✅ 実装完了: [機能名]

### 実施確認:
- ビルド: ✅ 成功（警告なし）  
- テスト: ✅ メモリリークテスト通過
- 動作: ✅ [具体的な動作確認内容]
- 品質: ✅ 静的解析・コードカバレッジ確認

### 特記事項:
- [パフォーマンス改善点など]
- [注意点や制限事項]
```