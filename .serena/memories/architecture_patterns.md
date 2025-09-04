# GLogo アーキテクチャパターン詳細

## MVVM アーキテクチャ実装

### Model層の設計原則
```swift
// 純粋データ構造の例
struct LogoProject: Codable {
    let id: UUID
    var name: String
    var elements: [LogoElement]
    var backgroundSettings: BackgroundSettings
    var canvasSize: CGSize
    
    // 最小限のビジネスロジックのみ
    mutating func addElement(_ element: LogoElement) {
        elements.append(element)
    }
}
```

**Model層の責任範囲:**
- データの永続化（Codable準拠）
- 基本的なデータ操作
- プロトコル準拠による型安全性
- スレッドセーフな設計（値型優先）

### ViewModel層の設計パターン
```swift
@MainActor
class EditorViewModel: ObservableObject {
    // MARK: - Published Properties (リアクティブ状態)
    
    @Published private(set) var project: LogoProject
    @Published private(set) var selectedElement: LogoElement?
    @Published var isEditing: Bool = false
    
    // MARK: - Dependencies (依存注入)
    
    private let history: EditorHistory
    private let renderer: CanvasRenderer
    
    // MARK: - State Management
    
    func updateElementProperty<T>(_ element: LogoElement, keyPath: WritableKeyPath<LogoElement, T>, value: T) {
        // Event Sourcingとの連携
        let event = PropertyChangedEvent(element: element, keyPath: keyPath, oldValue: element[keyPath: keyPath], newValue: value)
        history.execute(event)
        
        // UI即座更新
        objectWillChange.send()
    }
}
```

**ViewModel層の責任範囲:**
- UI状態の管理（@Published）
- ビジネスロジックの実装
- Event Sourcingとの連携
- 非同期処理の調整
- Model↔View間のデータ変換

### View層の設計原則
```swift
struct EditorView: View {
    @StateObject private var viewModel = EditorViewModel()
    @State private var showingImagePicker = false
    
    var body: some View {
        VStack {
            // 宣言的UI構成
            CanvasViewRepresentable(
                project: viewModel.project,
                selectedElement: viewModel.selectedElement,
                onElementSelected: viewModel.selectElement,
                onManipulationStarted: viewModel.startManipulation
            )
            
            if let selectedElement = viewModel.selectedElement {
                ElementPropertyPanel(
                    element: selectedElement,
                    onPropertyChanged: viewModel.updateElementProperty
                )
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView { image in
                viewModel.addImageElement(image)
            }
        }
    }
}
```

**View層の責任範囲:**
- 宣言的UI記述
- ユーザー入力の受付
- 状態ベースの表示制御
- ViewModelとのバインディング

## Event Sourcing パターン

### イベント階層設計
```swift
// 基底プロトコル
protocol EditorEvent: Codable {
    var eventName: String { get }
    var timestamp: Date { get }
    
    func apply(to project: LogoProject)
    func revert(from project: LogoProject)
}

// 具体的イベント実装例
struct TextContentChangedEvent: EditorEvent {
    let eventName = "TextContentChanged"
    let timestamp = Date()
    
    let elementId: UUID
    let oldContent: String
    let newContent: String
    
    func apply(to project: LogoProject) {
        guard let textElement = project.elements.first(where: { $0.id == elementId }) as? TextElement else { return }
        textElement.text = newContent
    }
    
    func revert(from project: LogoProject) {
        guard let textElement = project.elements.first(where: { $0.id == elementId }) as? TextElement else { return }
        textElement.text = oldContent
    }
}
```

### 履歴管理システム
```swift
class EditorHistory {
    private var undoStack: [EditorEvent] = []
    private var redoStack: [EditorEvent] = []
    private let maxHistoryCount = 50
    
    // MARK: - Core Operations
    
    func execute(_ event: EditorEvent) {
        // イベント実行
        event.apply(to: project)
        
        // 履歴に追加
        undoStack.append(event)
        redoStack.removeAll() // Redo履歴をクリア
        
        // 履歴サイズ制限
        if undoStack.count > maxHistoryCount {
            undoStack.removeFirst()
        }
    }
    
    func undo() -> Bool {
        guard let event = undoStack.popLast() else { return false }
        
        event.revert(from: project)
        redoStack.append(event)
        
        return true
    }
    
    func redo() -> Bool {
        guard let event = redoStack.popLast() else { return false }
        
        event.apply(to: project)
        undoStack.append(event)
        
        return true
    }
}
```

## SwiftUI + UIKit 統合パターン

### UIViewRepresentable ブリッジ
```swift
struct CanvasViewRepresentable: UIViewRepresentable {
    let project: LogoProject
    let selectedElement: LogoElement?
    
    // Callback closures for UIKit → SwiftUI communication
    var onElementSelected: ((LogoElement?) -> Void)?
    var onManipulationStarted: ((ElementManipulationType, CGPoint) -> Void)?
    
    func makeUIView(context: Context) -> CanvasView {
        let canvasView = CanvasView()
        canvasView.coordinator = context.coordinator
        return canvasView
    }
    
    func updateUIView(_ uiView: CanvasView, context: Context) {
        // SwiftUI状態 → UIKit同期
        uiView.project = project
        uiView.selectedElement = selectedElement
        uiView.setNeedsDisplay()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator Pattern
    
    class Coordinator: NSObject {
        var parent: CanvasViewRepresentable
        
        init(_ parent: CanvasViewRepresentable) {
            self.parent = parent
        }
        
        // UIKit → SwiftUI イベント転送
        func elementSelected(_ element: LogoElement?) {
            parent.onElementSelected?(element)
        }
        
        func manipulationStarted(_ type: ElementManipulationType, at point: CGPoint) {
            parent.onManipulationStarted?(type, point)
        }
    }
}
```

### 高性能UIKitキャンバス
```swift
class CanvasView: UIView {
    // MARK: - Properties
    
    weak var coordinator: CanvasViewRepresentable.Coordinator?
    var project: LogoProject? {
        didSet { setNeedsDisplay() }
    }
    var selectedElement: LogoElement? {
        didSet { setNeedsDisplay() }
    }
    
    // MARK: - Rendering Pipeline
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let project = project else { return }
        
        // Z-Index順で描画
        let sortedElements = project.elements
            .filter { $0.isVisible }
            .sorted { $0.zIndex < $1.zIndex }
        
        for element in sortedElements {
            // カスタム描画ロジック
            ElementRenderer.render(element, in: context, bounds: bounds)
            
            // 選択状態の表示
            if element.id == selectedElement?.id {
                drawSelectionHandles(for: element, in: context)
            }
        }
    }
    
    // MARK: - Gesture Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        
        // Z-Index順でヒットテスト
        if let hitElement = hitTestElement(at: point) {
            coordinator?.elementSelected(hitElement)
        }
    }
}
```

## メモリ管理パターン

### Weak Reference パターン
```swift
class ElementViewModel: ObservableObject {
    @Published var element: LogoElement
    weak var editorViewModel: EditorViewModel? // サイクル防止
    
    // Closure でのweak self使用
    private func setupCallbacks() {
        onPropertyChanged = { [weak self] property, value in
            self?.editorViewModel?.updateElementProperty(property, value: value)
        }
    }
}
```

### Autoreleasepool 最適化
```swift
// 大量画像処理でのメモリ最適化
func processBatchImages(_ images: [UIImage]) -> [UIImage] {
    return images.compactMap { image in
        autoreleasepool {
            // メモリ集約的処理を分離
            let filteredImage = ImageFilterUtility.applyFilters(to: image)
            return filteredImage
        }
    }
}
```

## 並行性パターン (Swift 6.0)

### MainActor パターン
```swift
@MainActor
class EditorViewModel: ObservableObject {
    // UI関連処理は自動的にメインスレッド実行
    
    func updateUI() {
        // @MainActor により自動的にメインスレッド実行
        self.selectedElement = newElement
    }
    
    // 重い処理は非同期タスクに分離
    func processImageAsync(_ image: UIImage) async -> UIImage? {
        return await Task.detached {
            // バックグラウンドスレッドで実行
            return ImageFilterUtility.applyFilters(to: image)
        }.value
    }
}
```

### Sendable パターン
```swift
// スレッド間安全なデータ転送
struct ImageProcessingTask: Sendable {
    let sourceImage: UIImage
    let filterParameters: FilterParameters
    let completion: @Sendable (UIImage?) -> Void
}

actor ImageProcessor {
    func process(_ task: ImageProcessingTask) {
        let result = applyFilters(task.sourceImage, parameters: task.filterParameters)
        await MainActor.run {
            task.completion(result)
        }
    }
}
```

## パフォーマンス最適化パターン

### 2段階処理パターン
```swift
class ImageElement: LogoElement {
    private var cachedPreview: UIImage?
    private var cachedFullImage: UIImage?
    
    // 即座プレビュー
    func getPreviewImage() -> UIImage? {
        if cachedPreview == nil {
            cachedPreview = generatePreviewImage() // 512px低解像度
        }
        return applyPreviewFilters(cachedPreview)
    }
    
    // 高品質処理
    func getFullQualityImage() -> UIImage? {
        if cachedFullImage == nil {
            cachedFullImage = processFullResolution() // フルサイズ
        }
        return applyFilters(cachedFullImage)
    }
}
```

### レイジー評価パターン
```swift
// 必要時のみ計算実行
lazy var expensiveCalculation: ComplexResult = {
    return performComplexCalculation()
}()

// キャッシュ無効化
func invalidateCache() {
    _expensiveCalculation = LazySequence()
}
```