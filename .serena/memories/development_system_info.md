# GLogo 開発システム情報

## システム環境

### プラットフォーム情報
- **OS**: macOS (Darwin 24.6.0)
- **開発環境**: Xcode + iOS Simulator
- **ターゲットOS**: iOS 15.0+
- **言語**: Swift 6.0
- **アーキテクチャ**: MVVM + Event Sourcing

### プロジェクト設定
- **プロジェクトファイル**: `GLogo.xcodeproj`
- **ワークスペース**: `GLogo.xcworkspace` (CocoaPods使用時)
- **Bundle ID**: `com.yourcompany.GLogo`
- **デプロイメントターゲット**: iOS 15.0
- **Swift Concurrency**: Strict compliance enabled

## Darwinシステム固有コマンド

### ファイルシステム操作
```bash
# macOS標準コマンド
ls -la                    # ファイル一覧（詳細）
find . -name "*.swift"    # Swift ファイル検索
grep -r "pattern" GLogo/  # 再帰検索

# spotlight検索（macOS特有）
mdfind -name "EditorViewModel.swift"

# Finder で開く
open GLogo.xcodeproj
open -a Xcode GLogo.xcodeproj
```

### プロセス・システム情報
```bash
# システム情報
system_profiler SPHardwareDataType  # ハードウェア情報
sysctl -n hw.memsize                # メモリサイズ取得
sysctl -n hw.ncpu                   # CPU数取得

# プロセス監視
ps aux | grep GLogo                 # GLogo関連プロセス
top -pid `pgrep GLogo`             # リソース使用量監視
```

### 開発者ツール (Xcode Command Line Tools)
```bash
# Xcode バージョン管理
xcode-select --print-path           # 使用中のXcode確認  
sudo xcode-select -s /Applications/Xcode.app  # Xcode指定

# 証明書・プロビジョニング
security find-identity -v -p codesigning  # コード署名証明書一覧
security dump-keychain                     # キーチェーン情報
```

## iOS シミュレーター (macOS)

### シミュレーター固有操作
```bash
# デバイス管理
xcrun simctl list                        # 全デバイス・ランタイム一覧
xcrun simctl list devices available      # 利用可能デバイス
xcrun simctl list runtimes               # iOS ランタイム一覧

# デバイス操作
xcrun simctl create "iPhone 15 Pro Test" "iPhone 15 Pro" "iOS-17-0"  # カスタムデバイス作成
xcrun simctl delete unavailable          # 無効デバイス削除
xcrun simctl erase all                   # 全デバイスリセット

# アプリ管理
xcrun simctl listapps booted                           # インストール済みアプリ一覧
xcrun simctl uninstall booted com.yourcompany.GLogo   # アプリアンインストール
xcrun simctl get_app_container booted com.yourcompany.GLogo  # アプリコンテナ取得
```

### システムログ・デバッグ
```bash
# ログ監視（macOS 10.12+）
log stream --predicate 'subsystem contains "GLogo"'
log stream --level debug --predicate 'process == "GLogo"'

# Console.app でのログ確認
open -a Console

# クラッシュレポート
ls ~/Library/Logs/DiagnosticReports/GLogo*
```

## Git・バージョン管理 (macOS)

### Git設定
```bash
# グローバル設定確認
git config --global --list

# macOS Keychain統合
git config --global credential.helper osxkeychain

# ファイル属性（macOS特有）
git config --global core.precomposeunicode true
git config --global core.quotepath false
```

### 除外設定
```bash
# .gitignore (macOS固有項目)
.DS_Store
*.swp
*.swo
*~
.Trashes
.Spotlight-V100
.fseventsd

# Xcode固有
build/
DerivedData/
*.xcuserstate
*.xccheckout
xcschememanagement.plist
```

## パフォーマンス分析・プロファイリング

### Instruments (macOS開発者ツール)
```bash
# パフォーマンス分析
instruments -l                                    # 利用可能テンプレート一覧
instruments -t "Time Profiler" GLogo.app         # CPU使用率分析
instruments -t "Allocations" GLogo.app           # メモリ使用量
instruments -t "Leaks" GLogo.app                 # メモリリーク検出
instruments -t "Core Image" GLogo.app            # Core Image最適化

# 結果保存・解析
instruments -t "Time Profiler" -D profile.trace GLogo.app
open profile.trace  # 結果をInstrumentsで開く
```

### システムリソース監視
```bash
# CPU・メモリ監視
top -pid `pgrep -f GLogo`
htop -p `pgrep -f GLogo`  # htop使用時

# ディスク使用量
du -sh GLogo/                    # プロジェクトサイズ
df -h                           # ディスク容量

# ネットワーク監視
netstat -an | grep GLogo
lsof -i | grep GLogo
```

## セキュリティ・権限管理

### macOS セキュリティ
```bash
# Gatekeeper
spctl --assess --verbose GLogo.app     # アプリ署名確認
codesign -vvv --deep GLogo.app         # コード署名検証

# 権限管理
tccutil reset All com.yourcompany.GLogo  # プライバシー設定リセット
```

### Keychain・証明書管理
```bash
# キーチェーン操作
security list-keychains                       # キーチェーン一覧
security find-certificate -p login.keychain   # 証明書検索
security import cert.p12 -k login.keychain    # 証明書インポート
```

## 開発効率化

### エディタ・IDE統合
```bash
# VS Code 統合 (Swift開発サポート)
code GLogo/                              # VS Codeでプロジェクト開く
code GLogo/ViewModels/EditorViewModel.swift  # 特定ファイル開く

# Xcode プロジェクト操作
open GLogo.xcworkspace                   # ワークスペース開く
xed GLogo/                              # Xcode editor起動
```

### 自動化・スクリプト
```bash
# zsh/bash スクリプト（macOS標準シェル）
#!/bin/zsh
# ビルド・テスト自動化スクリプト例

set -e
echo "🔨 GLogo ビルド開始..."
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo clean build
echo "✅ ビルド完了"

echo "🧪 テスト実行..."
xcodebuild -workspace GLogo.xcworkspace -scheme GLogo test
echo "✅ テスト完了"
```

### Homebrew パッケージ管理
```bash
# 開発支援ツール
brew install swiftlint      # Swift リンター
brew install swiftformat    # Swift フォーマッター
brew install rg            # 高速検索ツール
brew install htop          # システム監視
```

## トラブルシューティング (macOS固有)

### Xcode・開発環境問題
```bash
# Xcode リセット
sudo xcode-select --reset
sudo xcodebuild -license accept          # ライセンス同意

# 派生データ削除
rm -rf ~/Library/Developer/Xcode/DerivedData/GLogo*
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# シミュレーター問題
sudo killall -9 com.apple.CoreSimulator.CoreSimulatorService
xcrun simctl shutdown all
xcrun simctl erase all
```

### システム権限・アクセス問題
```bash
# ディスクアクセス権限
sudo chmod -R 755 GLogo/
sudo chown -R $USER GLogo/

# プロセス強制終了
sudo pkill -f GLogo
sudo killall GLogo
```

### パフォーマンス問題診断
```bash
# システムリソース確認
vm_stat                    # 仮想メモリ統計
iostat -d                  # ディスクI/O
fs_usage -w -f pathname    # ファイルシステム使用量監視
```