# GLogo 開発コマンド一覧

## ビルド・実行コマンド

### プロジェクトビルド
```bash
# 基本ビルド
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo build

# クリーンビルド（問題発生時）
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo clean build

# 特定デバイス向けビルド
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

### テスト実行
```bash
# 全テスト実行
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo test

# メモリリークテスト専用
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -only-testing:GLogoTests/ViewModelMemoryLeakTests test

xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -only-testing:GLogoTests/OperationMemoryLeakTests test

# 特定テスト実行
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -only-testing:GLogoTests/ViewModelMemoryLeakTests/testEditorViewModelDoesNotLeak test
```

## iOS シミュレーター操作

### デバイス管理
```bash
# 利用可能シミュレーター一覧
xcrun simctl list devices

# 特定シミュレーター起動
xcrun simctl boot "iPhone 15 Pro"

# 全シミュレーター終了
xcrun simctl shutdown all
```

### アプリ操作
```bash
# アプリインストール
xcrun simctl install booted /path/to/GLogo.app

# アプリ起動
xcrun simctl launch booted com.yourcompany.GLogo

# ビルド＆実行（統合コマンド）
# プロジェクトパスとスキーム指定でビルド～実行まで自動化
```

## 開発・デバッグコマンド

### パフォーマンス分析
```bash
# Core Image フィルター性能テスト
instruments -t "Core Image" -D trace_results.trace GLogo.app

# メモリ使用量分析
instruments -t "Allocations" -D memory_trace.trace GLogo.app

# メモリリーク検出
instruments -t "Leaks" -D leak_trace.trace GLogo.app
```

### ログ・デバッグ
```bash
# シミュレーターログ監視
xcrun simctl spawn booted log stream --predicate 'subsystem contains "GLogo"'

# Core Image デバッグログ有効化
export CI_PRINT_TREE=1
export CI_LOG_LEVEL=1
```

### コード品質チェック
```bash
# 静的解析
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  analyze -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Swift フォーマット確認
swiftformat GLogo/ --lint

# コードカバレッジ測定
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  -enableCodeCoverage YES test
```

## 高度なテスト・分析

### メモリデバッグ
```bash
# アドレスサニタイザー有効
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  test -enableAddressSanitizer YES \
  -only-testing:GLogoTests/ViewModelMemoryLeakTests

# 詳細メモリリーク検出
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  test -enableAddressSanitizer YES -enableUndefinedBehaviorSanitizer YES
```

### 並行性・パフォーマンス
```bash
# スレッドサニタイザー
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  test -enableThreadSanitizer YES

# パフォーマンス詳細測定
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo \
  build -enableCodeCoverage YES \
  -resultBundlePath PerformanceResults.xcresult
```

## プロジェクト管理

### Git 操作
```bash
# ブランチ作成・切り替え
git checkout -b feature/new-filter-implementation

# 変更確認
git status
git diff

# コミット（標準形式）
git add .
git commit -m "新フィルター実装: [機能名]

詳細説明...

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"
```

### ファイル操作
```bash
# プロジェクト構造確認
find GLogo -name "*.swift" | head -20

# 特定機能検索
rg "EditorViewModel" GLogo/ --type swift

# ファイル一覧（ディレクトリ別）
ls -la GLogo/ViewModels/
ls -la GLogo/Models/
ls -la GLogo/Utils/
```

## 開発サポート

### Xcode プロジェクト操作
```bash
# Xcode でプロジェクト開く
open GLogo.xcodeproj

# 派生データクリア（問題解決時）
rm -rf ~/Library/Developer/Xcode/DerivedData/GLogo-*

# シミュレーターリセット
xcrun simctl erase all
```

### 環境確認
```bash
# Xcode バージョン確認
xcodebuild -version

# Swift バージョン確認
swift --version

# 利用可能SDK確認
xcodebuild -showsdks

# シミュレーターヘルプ
xcrun simctl help
```

## 緊急時・トラブルシューティング

### ビルド問題解決
```bash
# 派生データ完全クリア
rm -rf ~/Library/Developer/Xcode/DerivedData

# Xcode キャッシュクリア
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# シミュレーター完全リセット
xcrun simctl delete unavailable
xcrun simctl erase all
```

### パフォーマンス問題診断
```bash
# メモリ使用量リアルタイム監視
instruments -t "Activity Monitor" GLogo.app

# CPU使用率分析
instruments -t "Time Profiler" GLogo.app

# I/O パフォーマンス
instruments -t "File Activity" GLogo.app
```