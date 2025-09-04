# GLogo プロジェクト概要

## プロジェクトの目的
GLogoは**プロフェッショナルレベルのiOSロゴ・画像編集アプリケーション**です。Swift 6.0とSwiftUIを基盤として、高度な画像処理機能と直感的なユーザーインターフェースを組み合わせ、モバイルデバイス上でのクリエイティブワークを支援します。

## 技術スタック

### 開発言語・フレームワーク
- **Swift 6.0**: 最新の言語機能とストリクト並行性モデル
- **SwiftUI + UIKit**: 宣言的UIと高性能描画の融合
- **Core Graphics + Core Image**: プロフェッショナル画像処理
- **iOS 15.0+**: モダンなiOS機能活用
- **macOS Catalyst**: デスクトップ対応

### アーキテクチャパターン
- **MVVM**: Model-View-ViewModel設計
- **Event Sourcing**: 包括的なアンドゥ/リドゥシステム
- **Protocol-Oriented**: 型安全性と拡張性重視
- **SwiftUI + UIKit統合**: パフォーマンス重視のハイブリッド構成

## プロジェクト構造

```
GLogo/
├── App/                    # アプリケーションエントリーポイント
│   └── GameLogoMakerApp.swift
├── Models/                 # データモデル層
│   ├── LogoProject.swift
│   ├── LogoElement.swift
│   ├── TextElement.swift
│   ├── ShapeElement.swift
│   ├── ImageElement.swift
│   └── BackgroundSettings.swift
├── ViewModels/            # ビジネスロジック層
│   ├── EditorViewModel.swift
│   ├── ElementViewModel.swift
│   ├── LibraryViewModel.swift
│   └── ImageCropViewModel.swift
├── Views/                 # UI層
│   ├── Editor/
│   ├── ToolPanels/
│   └── Export/
└── Utils/                 # ユーティリティ
    ├── History/           # イベントソーシング
    ├── Rendering/         # 描画エンジン
    ├── Storage/           # データ永続化
    └── Extensions/        # 拡張機能
```

## 主要機能・特徴

### 1. プロフェッショナル画像編集
- **カスタムハイライト/シャドウ調整**: ITU-R BT.709規格準拠
- **マルチパスフィルタリング**: 複数フィルター段階適用
- **高解像度対応**: 4K以上の画像処理最適化

### 2. 高度なイベントソーシング
- **20+種類の専用イベント**: 各操作に対応した細分化
- **完全なアンドゥ/リドゥ**: 双方向操作サポート
- **メモリ効率**: 最小限のデータ保存

### 3. ハイブリッドUI構成
- **SwiftUI**: 宣言的なインターフェース設計
- **UIKit Canvas**: 高性能リアルタイム描画
- **座標系統合**: シームレスな操作体験

### 4. メモリ管理・パフォーマンス
- **自動メモリリーク検出**: 包括的テストスイート
- **2段階画像処理**: プレビュー＋高品質の最適化
- **Z-Index順描画**: 直感的な要素操作

## 独自技術実装

### カスタム画像フィルター
- **ハイライト/シャドウ調整**: Core Imageにない機能を独自実装
- **iTU-R BT.709**: 業界標準の輝度係数使用
- **iOS画像向き対応**: UIImage/CGImage座標系統合

### 高解像度UI応答性
- **512px プレビュー**: 即座反応のための低解像度処理
- **500ms デバウンス**: 自動高品質更新
- **97%メモリ削減**: 24.5MP → 0.26MP処理

## 開発・テスト環境
- **Xcode**: GLogo.xcodeproj
- **iOS Simulator**: iPhone 15 Pro等
- **テストターゲット**: GLogoTests, GLogoUITests
- **メモリリークテスト**: 自動化された包括的検証