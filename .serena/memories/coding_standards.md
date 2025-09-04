# GLogo コーディング規約・スタイル

## 言語・ドキュメント方針

### 主要言語: 日本語
- **コメント**: 実装意図の正確な伝達のため日本語使用
- **変数・関数名**: camelCase英語命名
- **ドキュメント**: Swift DocC形式（`///`）
- **実装ノート**: `//` でのインライン解説

### コメント記述規則

#### ドキュメントコメント（`///`）
```swift
/// エディタの主要な状態を管理するビューモデル
/// ユーザーの編集操作を受け取り、プロジェクトの状態を更新する
class EditorViewModel: ObservableObject {
    
    /// 現在編集中のプロジェクト
    @Published private(set) var project: LogoProject
    
    /// プロジェクトに新しい要素を追加する
    /// - Parameter element: 追加する要素
    func addElement(_ element: LogoElement) {
        // Implementation...
    }
}
```

#### 実装コメント（`//`）
```swift
func processImage(_ image: UIImage) -> UIImage? {
    // 画像の向きを正規化して座標系の不整合を防ぐ
    guard let orientedCGImage = createOrientedCGImage(from: image) else {
        return nil
    }
    
    // フィルターチェーンを適用
    let filteredImage = applyFilters(to: orientedCGImage)
    
    return UIImage(cgImage: filteredImage)
}
```

## コード構成・組織化

### MARK使用による構造化
**必須セクション分離**:
```swift
class EditorViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published private(set) var project: LogoProject
    @Published private(set) var selectedElement: LogoElement?
    
    // MARK: - Initialization
    
    init(project: LogoProject = LogoProject()) {
        self.project = project
    }
    
    // MARK: - Element Operations
    
    func addElement(_ element: LogoElement) {
        // Implementation...
    }
    
    // MARK: - Private Methods
    
    private func updateProjectState() {
        // Implementation...
    }
}
```

### 標準MARKカテゴリ
- `// MARK: - Properties`: プロパティ・定数
- `// MARK: - Initialization`: 初期化処理
- `// MARK: - Public Methods`: パブリックインターフェース
- `// MARK: - Private Methods`: 内部実装
- `// MARK: - Event Handling`: イベント・コールバック
- `// MARK: - Protocol Conformance`: プロトコル実装

## 命名規則

### 変数・プロパティ
```swift
// camelCase for properties and variables
var selectedElement: LogoElement?
var isProjectModified: Bool = false
var backgroundSettings: BackgroundSettings
```

### クラス・構造体・列挙型
```swift
// PascalCase for types
class EditorViewModel: ObservableObject { }
struct LogoProject: Codable { }
enum EditorMode { }
```

### メソッド
```swift
// 動詞ベースの説明的命名
/// 要素を選択状態にする
func selectElement(_ element: LogoElement)

/// プロジェクトを保存する
func saveProject(completion: @escaping (Bool) -> Void)
```

### ファイル
```swift
// PascalCase with descriptive purpose
EditorViewModel.swift          // Main editor business logic
EventSourcing.swift           // Event system implementation
ImageFilterUtility.swift     // Image processing utilities
```

## Swift 6.0 並行性規約

### 並行性パターン
```swift
/// 画像処理を非同期で実行する
/// - Parameter image: 処理対象の画像
/// - Returns: 処理済みの画像
@MainActor
func processImageAsync(_ image: UIImage) async -> UIImage? {
    // UIKit操作は@MainActorで実行
    let size = image.size
    
    // 重い処理は非同期タスクで実行
    return await withTaskGroup(of: UIImage?.self) { group in
        group.addTask {
            // Core Image処理（バックグラウンドスレッド）
            return await self.applyFiltersAsync(to: image)
        }
        
        return await group.first { $0 != nil } ?? image
    }
}
```

### 並行性ガイドライン
- **Primary Pattern**: Swift Concurrency (`async/await`, `Task`, `@MainActor`)
- **Legacy Support**: 必要時のみGCD（外部ライブラリ互換性）
- **UI Updates**: `@MainActor` でメインスレッド保証
- **Heavy Processing**: `Task.detached` でバックグラウンド実行

## エラーハンドリング

### 一貫したエラー管理
```swift
/// 画像ファイルを読み込む
/// - Parameter url: 画像ファイルのURL
/// - Returns: 読み込んだ画像、失敗時はnil
func loadImage(from url: URL) -> UIImage? {
    do {
        let data = try Data(contentsOf: url)
        return UIImage(data: data)
    } catch {
        print("DEBUG: 画像読み込みエラー: \(error.localizedDescription)")
        return nil
    }
}
```

## ファイルヘッダー標準

```swift
//
//  EditorViewModel.swift
//  GLogo
//
//  概要:
//  このファイルはエディタ画面の主要なビューモデルを定義しています。
//  プロジェクトの状態管理、要素の追加/選択/編集/削除などの編集操作を提供し、
//  イベントソーシングシステムと連携してアンドゥ/リドゥ機能を実現します。
//

import Foundation
import UIKit
```

## 設計原則

### 責任分離
- **Models**: 純粋データ構造、最小ビジネスロジック
- **ViewModels**: リアクティブ状態管理、@Published プロパティ
- **Views**: 宣言的UI、最小命令的コード
- **Utilities**: 純粋関数、画像処理・座標計算

### Protocol-Oriented設計
```swift
// 型安全な拡張可能設計
protocol LogoElement: Codable {
    var id: UUID { get }
    var type: LogoElementType { get }
    func copy() -> LogoElement
    func hitTest(_ point: CGPoint) -> Bool
    func draw(in context: CGContext)
}
```

### 列挙型による状態管理
```swift
enum EditorMode {
    case select, textCreate, shapeCreate, imageImport, delete
}

enum ImageFitMode: String, Codable {
    case fill, aspectFit, aspectFill, center, tile
}
```

## 品質保証

### メモリ管理パターン
```swift
// Weak参照によるサイクル防止
onElementSelected = { [weak self] element in
    self?.handleSelection(element)
}

// Autoreleasepool による大量処理最適化
autoreleasepool {
    for image in imageSet {
        let processed = applyFilters(to: image)
        results.append(processed)
    }
}
```

### テスト可能設計
- Protocol-based mocking
- 依存注入サポート
- メモリリーク自動検出
- ユニットテスト全面対応