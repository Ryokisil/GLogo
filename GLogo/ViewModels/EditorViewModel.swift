//
//  EditorViewModel.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはエディタ画面の主要なビューモデルを定義しています。
//  プロジェクトの状態管理、要素の追加/選択/編集/削除などの編集操作、
//  要素の移動/リサイズ/回転などの操作処理、操作履歴の管理（イベントソーシングによるアンドゥ/リドゥ）、
//  プロジェクトの保存/読み込み、画像エクスポート機能など、
//  エディタの中核となる機能を提供します。ユーザー操作とモデルの間の橋渡し役を担います。
//

import Foundation
import UIKit
import Photos

/// エディタモード
enum EditorMode {
    case select      // 要素の選択・移動
    case shapeCreate // 図形作成
    case imageImport // 画像インポート
    case delete      // 削除
}

/// 選択した要素の操作タイプ
enum ElementManipulationType {
    case none
    case move
    case resize
    case rotate
}

/// エディタビューモデル - エディタ画面の状態とロジックを管理
@MainActor
class EditorViewModel: ObservableObject {
    // MARK: - プロパティ
    
    /// 現在のプロジェクト
    @Published private(set) var project: LogoProject
    
    /// 選択中の要素
    @Published private(set) var selectedElement: LogoElement?
    
    /// エディタモード
    @Published var editorMode: EditorMode = .select
    
    /// 操作タイプ
    @Published private(set) var manipulationType: ElementManipulationType = .none
    
    /// テキスト編集中かどうか
    @Published private(set) var isEditingText: Bool = false
    
    /// 編集中のテキスト要素
    @Published private(set) var editingTextElement: TextElement?
    
    /// 操作履歴の管理
    private lazy var history = EditorHistory(project: project)

    /// 保存フローのオーケストレーター
    private let saveCoordinator = SaveImageCoordinator()
    private let imageImportCoordinator = ImageImportCoordinator()
    
    /// 要素操作の開始位置
    private var manipulationStartPoint: CGPoint = .zero
    
    /// 操作前の要素の状態
    private var manipulationStartElement: LogoElement?
    
    /// 次に作成する図形のタイプ
    var nextShapeType: ShapeType = .rectangle
    
    /// プロジェクトが変更されたかどうか
    @Published private(set) var isProjectModified = false

    /// メモリ警告監視のトークン
    private var memoryWarningObserver: NSObjectProtocol?

    /// 外部からプロジェクト変更フラグを立てる
    func markProjectModified() {
        isProjectModified = true
    }

    /// メモリ警告を受けた際にキャッシュを解放する
    private func handleMemoryWarning() {
        for element in project.elements {
            (element as? ImageElement)?.handleMemoryWarning()
        }
        ImageElement.previewService.resetCache()
        ToneCurveFilter.clearCache()
    }

    // MARK: - イニシャライザ
    
    /// 新しいプロジェクトでエディタを初期化
    init(project: LogoProject = LogoProject()) {
        self.project = project
        
        // 履歴管理の初期化
        history = EditorHistory(project: project)

        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
    }
    
    // MARK: - プロジェクト操作
    
    /// プロジェクト名を更新
    func updateProjectName(_ name: String) {
        // プロジェクト名に変更があれば更新
        if project.name != name {
            let event = ProjectNameChangedEvent(
                oldName: project.name,
                newName: name
            )
            
            history.recordAndApply(event)
            isProjectModified = true
        }
    }
    
    /// プロジェクトのキャンバスサイズを更新
    func updateCanvasSize(_ size: CGSize) {
        // キャンバスサイズに変更があれば更新
        if project.canvasSize != size {
            let event = CanvasSizeChangedEvent(
                oldSize: project.canvasSize,
                newSize: size
            )
            
            history.recordAndApply(event)
            isProjectModified = true
        }
    }
    
    /// 背景設定を更新
    func updateBackgroundSettings(_ settings: BackgroundSettings) {
        let event = BackgroundSettingsChangedEvent(
            oldSettings: project.backgroundSettings,
            newSettings: settings
        )
        
        history.recordAndApply(event)
        isProjectModified = true
    }
    
    // MARK: - 要素操作
    
    /// 要素を追加
    func addElement(_ element: LogoElement) {
        
        // 自動Z-Index設定
        setAutoZIndex(for: element)
        
        let event = ElementAddedEvent(element: element)
        history.recordAndApply(event)
        
        
        selectedElement = element
        isProjectModified = true
    }
    
    /// 要素の自動Z-Index設定
    private func setAutoZIndex(for element: LogoElement) {
        let elementPriority = ElementPriority.defaultPriority(for: element.type)
        let nextZIndex = elementPriority.nextAvailableZIndex(existingElements: project.elements)
        element.zIndex = nextZIndex
        
    }
    
    /// テキスト要素を追加
    func addTextElement(text: String = "Text", position: CGPoint) {
        let textElement = TextElement(text: text)
        textElement.position = position
        addElement(textElement)
    }
    
    /// 図形要素を追加
    func addShapeElement(type: ShapeType, position: CGPoint) {
        let shapeElement = ShapeElement(shapeType: type)
        shapeElement.position = position
        addElement(shapeElement)
    }
    
    /// 画像要素を追加
//    func addImageElement(fileName: String, position: CGPoint) {
//        let imageElement = ImageElement(fileName: fileName)
//        imageElement.position = position
//        addElement(imageElement)
//    }
    
    /// 選択中の要素を削除
    func deleteSelectedElement() {
        guard let selectedElement = selectedElement else { return }
        
        // 要素のインデックスを取得
        guard let index = project.elements.firstIndex(where: { $0.id == selectedElement.id }) else { return }
        
        // 削除イベントを作成して実行
        let event = ElementRemovedEvent(element: selectedElement, index: index)
        history.recordAndApply(event)
        
        self.selectedElement = nil
        isProjectModified = true
    }
    
    /// 特定の位置にある要素を取得（ヒットテスト）
    func elementAt(_ point: CGPoint) -> LogoElement? {
        // zIndexの降順で判定（前面優先）
        let sorted = project.elements
            .filter { $0.isVisible && !$0.isLocked }
            .sorted { $0.zIndex > $1.zIndex }
        return sorted.first { $0.hitTest(point) }
    }
    
    /// 要素を選択
    func selectElement(at point: CGPoint) {
        selectedElement = elementAt(point)
    }
    
    // 特定の要素を直接選択
    func selectElement(_ element: LogoElement?) {
        selectedElement = element
    }
    
    /// 選択を解除
    func clearSelection() {
        selectedElement = nil
    }
    
    /// テキスト編集を開始
    func startTextEditing(for textElement: TextElement) {
        // 現在の編集を終了（もしあれば）
        endTextEditing()
        
        editingTextElement = textElement
        isEditingText = true
        selectedElement = textElement
        
    }
    
    /// テキスト編集を終了
    func endTextEditing() {
        if isEditingText {
            isEditingText = false
            editingTextElement = nil
        }
    }
    
    /// 選択中の要素を最前面に移動
    func bringSelectedElementToFront() {
        guard let selectedElement = selectedElement else { return }
        
        // 要素のインデックスを取得
        guard let index = project.elements.firstIndex(where: { $0.id == selectedElement.id }) else { return }
        
        // 削除してから最後に追加
        let removeEvent = ElementRemovedEvent(element: selectedElement, index: index)
        history.recordAndApply(removeEvent)
        
        let addEvent = ElementAddedEvent(element: selectedElement)
        history.recordAndApply(addEvent)
        
        isProjectModified = true
    }
    
    /// 選択中の要素を最背面に移動
    func sendSelectedElementToBack() {
        guard let selectedElement = selectedElement else { return }
        
        // 要素のインデックスを取得
        guard let index = project.elements.firstIndex(where: { $0.id == selectedElement.id }) else { return }
        
        // 削除してから先頭に追加する代わりに
        // 削除してインデックス0で再追加する必要があるため、コピーを使用
        let elementCopy = selectedElement.copy()
        
        let removeEvent = ElementRemovedEvent(element: selectedElement, index: index)
        history.recordAndApply(removeEvent)
        
        // 元の要素を一時的に削除
        project.elements.removeAll { $0.id == selectedElement.id }
        
        // 先頭に追加
        project.elements.insert(elementCopy, at: 0)
        
        // 選択要素を更新
        self.selectedElement = elementCopy
        
        isProjectModified = true
    }
    
    /// 選択中の要素の可視性を切り替え
    func toggleSelectedElementVisibility() {
        guard let element = selectedElement else { return }
        
        // 現在の実装では直接可視性を切り替え
        element.isVisible = !element.isVisible
        
        updateSelectedElement(element)
        isProjectModified = true
    }
    
    /// 選択中の要素のロック状態を切り替え
    func toggleSelectedElementLock() {
        guard let element = selectedElement else { return }
        
        // 現在の実装では直接ロック状態を切り替え
        element.isLocked = !element.isLocked
        
        updateSelectedElement(element)
        isProjectModified = true
    }
    
    /// 選択中の要素をコピー
    func duplicateSelectedElement() {
        guard let selectedElement = selectedElement else { return }
        
        // 要素のコピーを作成
        let copy = selectedElement.copy()
        
        // コピーした要素を少しずらして配置
        copy.move(by: CGPoint(x: 20, y: 20))
        
        // 要素を追加
        let event = ElementAddedEvent(element: copy)
        history.recordAndApply(event)
        
        self.selectedElement = copy
        isProjectModified = true
    }
    
    /// 選択中の要素を更新
    func updateSelectedElement(_ element: LogoElement) {
        guard let index = project.elements.firstIndex(where: { $0.id == element.id }) else { return }
        
        // ここではイベントを使用しない
        project.elements[index] = element
        
        // 選択要素を更新
        selectedElement = element
        isProjectModified = true
    }

    /// 編集イベントを適用し、選択要素と変更フラグを更新
    /// - Parameters:
    ///   - event: 適用する編集イベント
    ///   - elementId: 対象要素のID
    /// - Returns: なし
    private func applyEventAndRefreshSelection(_ event: EditorEvent, elementId: UUID) {
        history.recordAndApply(event)

        if selectedElement?.id == elementId {
            if let updatedElement = project.elements.first(where: { $0.id == elementId }) {
                selectedElement = updatedElement
            }
        }

        isProjectModified = true
    }
    
    /// テキスト要素のプロパティを更新
    func updateTextElement(_ textElement: TextElement) {
        updateSelectedElement(textElement)
    }
    
    /// 図形要素のプロパティを更新
    func updateShapeElement(_ shapeElement: ShapeElement) {
        updateSelectedElement(shapeElement)
    }
    
    /// 画像要素のプロパティを更新
    func updateImageElement(_ imageElement: ImageElement) {
        updateSelectedElement(imageElement)
    }

    /// 選択中の画像要素を初期状態に戻し、Undo可能な履歴として記録
    /// - Parameters: なし
    /// - Returns: なし
    func revertSelectedImageToInitialState() {
        guard let imageElement = selectedElement as? ImageElement else {
            return
        }

        let event = ImageRevertedToInitialStateEvent(element: imageElement)
        applyEventAndRefreshSelection(event, elementId: imageElement.id)
    }

    /// 手動背景除去の結果を画像要素に反映
    /// - Parameters:
    ///   - image: 背景除去後の画像
    ///   - imageElement: 更新対象の画像要素
    /// - Returns: なし
    func applyManualBackgroundRemovalResult(_ image: UIImage, to imageElement: ImageElement) {
        guard let newImageData = image.pngData() else { return }

        let newOriginalIdentifier = UUID().uuidString
        let event = ImageContentReplacedEvent(
            elementId: imageElement.id,
            oldImageData: imageElement.imageData,
            oldImageFileName: imageElement.imageFileName,
            oldOriginalImageURL: imageElement.originalImageURL,
            oldOriginalImagePath: imageElement.originalImagePath,
            oldOriginalImageIdentifier: imageElement.originalImageIdentifier,
            oldToneCurveData: imageElement.toneCurveData,
            oldSaturation: imageElement.saturationAdjustment,
            oldBrightness: imageElement.brightnessAdjustment,
            oldContrast: imageElement.contrastAdjustment,
            oldHighlights: imageElement.highlightsAdjustment,
            oldShadows: imageElement.shadowsAdjustment,
            oldBlacks: imageElement.blacksAdjustment,
            oldWhites: imageElement.whitesAdjustment,
            oldWarmth: imageElement.warmthAdjustment,
            oldVibrance: imageElement.vibranceAdjustment,
            oldHue: imageElement.hueAdjustment,
            oldSharpness: imageElement.sharpnessAdjustment,
            oldGaussianBlurRadius: imageElement.gaussianBlurRadius,
            oldVignette: imageElement.vignetteAdjustment,
            oldBloom: imageElement.bloomAdjustment,
            oldGrain: imageElement.grainAdjustment,
            oldFade: imageElement.fadeAdjustment,
            oldChromaticAberration: imageElement.chromaticAberrationAdjustment,
            oldTintIntensity: imageElement.tintIntensity,
            oldTintColor: imageElement.tintColor,
            oldAppliedFilterRecipe: imageElement.appliedFilterRecipe,
            oldAppliedFilterPresetId: imageElement.appliedFilterPresetId,
            newImageData: newImageData,
            newOriginalImageIdentifier: newOriginalIdentifier
        )

        history.recordAndApply(event)

        if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
            selectedElement = updatedElement
        }
        isProjectModified = true
        objectWillChange.send()
    }
    
    // MARK: - テキスト要素の操作
    
    /// テキスト内容の更新
    func updateTextContent(_ textElement: TextElement, newText: String) {
        let event = TextContentChangedEvent(
            elementId: textElement.id,
            oldText: textElement.text,
            newText: newText
        )
        
        applyEventAndRefreshSelection(event, elementId: textElement.id)
    }
    
    /// テキスト色の更新
    func updateTextColor(_ textElement: TextElement, newColor: UIColor) {
        
        // 現在と同じ色なら何もしない
        if textElement.textColor.isEqual(newColor) {
            return
        }
        
        // TextColorChangedEventを作成
        let event = TextColorChangedEvent(
            elementId: textElement.id,
            oldColor: textElement.textColor,
            newColor: newColor
        )
        
        // イベントを履歴に記録して適用
        applyEventAndRefreshSelection(event, elementId: textElement.id)
        
    }
    
    /// フォントの更新
    func updateFont(_ textElement: TextElement, fontName: String, fontSize: CGFloat) {
        if textElement.fontName == fontName && textElement.fontSize == fontSize {
            return
        }

        updateFont(
            textElement,
            oldFontName: textElement.fontName,
            newFontName: fontName,
            oldFontSize: textElement.fontSize,
            newFontSize: fontSize
        )
    }

    /// フォントの更新（旧値を明示指定）
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - oldFontName: 変更前フォント名
    ///   - newFontName: 変更後フォント名
    ///   - oldFontSize: 変更前フォントサイズ
    ///   - newFontSize: 変更後フォントサイズ
    /// - Returns: なし
    func updateFont(
        _ textElement: TextElement,
        oldFontName: String,
        newFontName: String,
        oldFontSize: CGFloat,
        newFontSize: CGFloat
    ) {
        if oldFontName == newFontName && oldFontSize == newFontSize {
            return
        }

        let event = FontChangedEvent(
            elementId: textElement.id,
            oldFontName: oldFontName,
            newFontName: newFontName,
            oldFontSize: oldFontSize,
            newFontSize: newFontSize
        )

        applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// 行間の更新
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - oldSpacing: 変更前の行間
    ///   - newSpacing: 変更後の行間
    /// - Returns: なし
    func updateTextLineSpacing(_ textElement: TextElement, oldSpacing: CGFloat, newSpacing: CGFloat) {
        if oldSpacing == newSpacing {
            return
        }

        let event = TextLineSpacingChangedEvent(
            elementId: textElement.id,
            oldSpacing: oldSpacing,
            newSpacing: newSpacing
        )

        applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// 文字間隔の更新
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - oldSpacing: 変更前の文字間隔
    ///   - newSpacing: 変更後の文字間隔
    /// - Returns: なし
    func updateTextLetterSpacing(_ textElement: TextElement, oldSpacing: CGFloat, newSpacing: CGFloat) {
        if oldSpacing == newSpacing {
            return
        }

        let event = TextLetterSpacingChangedEvent(
            elementId: textElement.id,
            oldSpacing: oldSpacing,
            newSpacing: newSpacing
        )

        applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// シャドウ効果の更新
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - effectIndex: 更新対象の効果インデックス
    ///   - oldOffset: 変更前のオフセット
    ///   - newOffset: 変更後のオフセット
    ///   - oldBlurRadius: 変更前のぼかし半径
    ///   - newBlurRadius: 変更後のぼかし半径
    /// - Returns: なし
    func updateTextShadowEffect(
        _ textElement: TextElement,
        effectIndex: Int,
        oldOffset: CGSize,
        newOffset: CGSize,
        oldBlurRadius: CGFloat,
        newBlurRadius: CGFloat
    ) {
        if oldOffset == newOffset && oldBlurRadius == newBlurRadius {
            return
        }

        let event = TextShadowEffectChangedEvent(
            elementId: textElement.id,
            effectIndex: effectIndex,
            oldOffset: oldOffset,
            newOffset: newOffset,
            oldBlurRadius: oldBlurRadius,
            newBlurRadius: newBlurRadius
        )

        applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// ストローク効果の更新
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - effectIndex: 更新対象の効果インデックス
    ///   - oldWidth: 変更前の太さ
    ///   - newWidth: 変更後の太さ
    /// - Returns: なし
    func updateTextStrokeEffect(
        _ textElement: TextElement,
        effectIndex: Int,
        oldWidth: CGFloat,
        newWidth: CGFloat
    ) {
        if oldWidth == newWidth {
            return
        }

        let event = TextStrokeEffectChangedEvent(
            elementId: textElement.id,
            effectIndex: effectIndex,
            oldWidth: oldWidth,
            newWidth: newWidth
        )

        applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// グロー効果の更新
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - effectIndex: 更新対象の効果インデックス
    ///   - oldRadius: 変更前の半径
    ///   - newRadius: 変更後の半径
    /// - Returns: なし
    func updateTextGlowEffect(
        _ textElement: TextElement,
        effectIndex: Int,
        oldRadius: CGFloat,
        newRadius: CGFloat
    ) {
        if oldRadius == newRadius {
            return
        }

        let event = TextGlowEffectChangedEvent(
            elementId: textElement.id,
            effectIndex: effectIndex,
            oldRadius: oldRadius,
            newRadius: newRadius
        )

        applyEventAndRefreshSelection(event, elementId: textElement.id)
    }
    
    // MARK: - 図形の操作
    
    /// 図形タイプの更新
    func updateShapeType(_ shapeElement: ShapeElement, newType: ShapeType) {
        
        // 図形タイプ変更イベントの作成
        let event = ShapeTypeChangedEvent(
            elementId: shapeElement.id,
            oldType: shapeElement.shapeType,
            newType: newType
        )
        
        // イベントを履歴に記録して適用
        applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }
    
    /// 図形の塗りつぶし色を更新
    func updateShapeFillColor(_ shapeElement: ShapeElement, newColor: UIColor) {
        
        let event = ShapeFillColorChangedEvent(
            elementId: shapeElement.id,
            oldColor: shapeElement.fillColor,
            newColor: newColor
        )
        
        applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }
    
    /// 図形の塗りつぶしモードを更新
    func updateShapeFillMode(_ shapeElement: ShapeElement, newMode: FillMode) {
        
        let event = ShapeFillModeChangedEvent(
            elementId: shapeElement.id,
            oldMode: shapeElement.fillMode,
            newMode: newMode
        )
        
        applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }
    
    /// 図形の枠線色を更新
    func updateShapeStrokeColor(_ shapeElement: ShapeElement, newColor: UIColor) {
        
        let event = ShapeStrokeColorChangedEvent(
            elementId: shapeElement.id,
            oldColor: shapeElement.strokeColor,
            newColor: newColor
        )
        
        applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }
    
    /// 図形の枠線太さを更新
    func updateShapeStrokeWidth(_ shapeElement: ShapeElement, newWidth: CGFloat) {
        
        let event = ShapeStrokeWidthChangedEvent(
            elementId: shapeElement.id,
            oldWidth: shapeElement.strokeWidth,
            newWidth: newWidth
        )
        
        applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }
    
    /// 図形の枠線モードを更新
    func updateShapeStrokeMode(_ shapeElement: ShapeElement, newMode: StrokeMode) {
        
        let event = ShapeStrokeModeChangedEvent(
            elementId: shapeElement.id,
            oldMode: shapeElement.strokeMode,
            newMode: newMode
        )
        
        applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }
    
    /// 図形の角丸半径を更新
    func updateShapeCornerRadius(_ shapeElement: ShapeElement, newRadius: CGFloat) {
        
        let event = ShapeCornerRadiusChangedEvent(
            elementId: shapeElement.id,
            oldRadius: shapeElement.cornerRadius,
            newRadius: newRadius
        )
        
        applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }
    
    /// 図形の辺の数を更新
    func updateShapeSides(_ shapeElement: ShapeElement, newSides: Int) {
        
        let event = ShapeSidesChangedEvent(
            elementId: shapeElement.id,
            oldSides: shapeElement.sides,
            newSides: newSides
        )
        
        applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }
    
    /// 図形のグラデーション色を更新
    func updateShapeGradientColors(_ shapeElement: ShapeElement, oldStartColor: UIColor, newStartColor: UIColor, oldEndColor: UIColor, newEndColor: UIColor) {
        
        let event = ShapeGradientColorsChangedEvent(
            elementId: shapeElement.id,
            oldStartColor: oldStartColor,
            newStartColor: newStartColor,
            oldEndColor: oldEndColor,
            newEndColor: newEndColor
        )
        
        applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }
    
    func updateShapeGradientAngle(_ shapeElement: ShapeElement, newAngle: CGFloat) {
        
        let event = ShapeGradientAngleChangedEvent(
            elementId: shapeElement.id,
            oldAngle: shapeElement.gradientAngle,
            newAngle: newAngle
        )
        
        applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }
    
    // MARK: - 画像要素の操作
    
    /// 画像のティントカラーを更新
    func updateImageTintColor(_ imageElement: ImageElement, oldColor: UIColor?, newColor: UIColor?, oldIntensity: CGFloat, newIntensity: CGFloat) {
        
        let event = ImageTintColorChangedEvent(
            elementId: imageElement.id,
            oldColor: oldColor,
            newColor: newColor,
            oldIntensity: oldIntensity,
            newIntensity: newIntensity
        )
        
        applyEventAndRefreshSelection(event, elementId: imageElement.id)
    }
    
    /// 画像のフレーム表示を更新
    func updateImageShowFrame(_ imageElement: ImageElement, newValue: Bool) {
        
        let event = ImageShowFrameChangedEvent(
            elementId: imageElement.id,
            oldValue: imageElement.showFrame,
            newValue: newValue
        )
        
        applyEventAndRefreshSelection(event, elementId: imageElement.id)
    }
    
    /// 画像のフレーム色を更新
    func updateImageFrameColor(_ imageElement: ImageElement, newColor: UIColor) {
        
        let event = ImageFrameColorChangedEvent(
            elementId: imageElement.id,
            oldColor: imageElement.frameColor,
            newColor: newColor
        )
        
        applyEventAndRefreshSelection(event, elementId: imageElement.id)
    }
    
    /// 画像の角丸設定を更新
    func updateImageRoundedCorners(_ imageElement: ImageElement, wasRounded: Bool, isRounded: Bool, oldRadius: CGFloat, newRadius: CGFloat) {

        let event = ImageRoundedCornersChangedEvent(
            elementId: imageElement.id,
            wasRounded: wasRounded,
            isRounded: isRounded,
            oldRadius: oldRadius,
            newRadius: newRadius
        )

        applyEventAndRefreshSelection(event, elementId: imageElement.id)
    }

    /// 背景ぼかし系の反映後に選択要素と更新通知を同期
    /// - Parameters:
    ///   - elementId: 同期対象の要素ID
    /// - Returns: なし
    private func refreshSelectionAndNotifyAfterBackgroundBlur(elementId: UUID) {
        if selectedElement?.id == elementId {
            if let updatedElement = project.elements.first(where: { $0.id == elementId }) {
                selectedElement = updatedElement
            }
        }

        isProjectModified = true
        objectWillChange.send()
    }

    // MARK: - 背景ぼかし

    /// AI背景ぼかし用のユースケース
    private let backgroundRemovalUseCase = BackgroundRemovalUseCase()

    /// 背景ぼかしマスク編集画面への遷移フラグ
    @Published var isNavigatingToBackgroundBlurMaskEdit: Bool = false

    /// 背景ぼかしマスク編集対象の画像要素
    @Published var backgroundBlurMaskEditTarget: ImageElement?

    /// AI処理中フラグ
    @Published private(set) var isProcessingAI: Bool = false

    /// AI背景除去をリクエスト（ワンタップで背景を透過に置換）
    /// - Parameter imageElement: 対象の画像要素
    func requestAIBackgroundRemoval(for imageElement: ImageElement) {
        guard !isProcessingAI else { return }
        isProcessingAI = true

        Task {
            defer { isProcessingAI = false }

            guard let originalImage = imageElement.originalImage else {
                return
            }

            do {
                let resultImage = try await backgroundRemovalUseCase.removeBackground(from: originalImage)
                applyManualBackgroundRemovalResult(resultImage, to: imageElement)
            } catch {
            }
        }
    }

    /// AI背景ぼかしをリクエスト
    /// - Parameter imageElement: 対象の画像要素
    func requestAIBackgroundBlur(for imageElement: ImageElement) {
        guard !isProcessingAI else { return }
        isProcessingAI = true

        Task {
            defer { isProcessingAI = false }

            guard let originalImage = imageElement.originalImage else {
                return
            }

            do {
                let maskImage = try await backgroundRemovalUseCase.generateMask(from: originalImage)
                guard let maskData = maskImage.pngData() else {
                    return
                }

                let oldMaskData = imageElement.backgroundBlurMaskData
                let oldRadius = imageElement.backgroundBlurRadius
                let defaultBlurRadius: CGFloat = 12.0

                // マスクとデフォルト半径を設定
                imageElement.backgroundBlurMaskData = maskData
                imageElement.backgroundBlurRadius = defaultBlurRadius
                imageElement.invalidateRenderedImageCache()

                // 履歴に記録
                let maskEvent = ImageBackgroundBlurMaskChangedEvent(
                    elementId: imageElement.id,
                    oldMaskData: oldMaskData,
                    newMaskData: maskData
                )
                history.recordAndApply(maskEvent)

                if oldRadius != defaultBlurRadius {
                    let radiusEvent = ImageBackgroundBlurRadiusChangedEvent(
                        elementId: imageElement.id,
                        oldRadius: oldRadius,
                        newRadius: defaultBlurRadius
                    )
                    history.recordAndApply(radiusEvent)
                }

                refreshSelectionAndNotifyAfterBackgroundBlur(elementId: imageElement.id)

            } catch {
            }
        }
    }

    /// 背景ぼかしマスク編集をリクエスト
    /// - Parameter imageElement: 対象の画像要素
    func requestBackgroundBlurMaskEdit(for imageElement: ImageElement) {
        backgroundBlurMaskEditTarget = imageElement
        isNavigatingToBackgroundBlurMaskEdit = true
    }

    /// 背景ぼかしマスク編集の結果を適用
    /// - Parameters:
    ///   - maskData: 編集後のマスクデータ（nilの場合は変更なし）
    ///   - imageElement: 対象の画像要素
    func applyBackgroundBlurMaskResult(_ maskData: Data?, to imageElement: ImageElement) {
        let oldMaskData = imageElement.backgroundBlurMaskData

        // nilの場合は変更なし
        guard maskData != oldMaskData else { return }

        // マスクを設定
        imageElement.backgroundBlurMaskData = maskData
        imageElement.invalidateRenderedImageCache()

        // 半径が未設定（0）の場合はデフォルト値を適用
        let oldRadius = imageElement.backgroundBlurRadius
        let defaultBlurRadius: CGFloat = 12.0
        if maskData != nil && oldRadius == 0 {
            imageElement.backgroundBlurRadius = defaultBlurRadius
        }

        // 履歴に記録
        let event = ImageBackgroundBlurMaskChangedEvent(
            elementId: imageElement.id,
            oldMaskData: oldMaskData,
            newMaskData: maskData
        )
        history.recordAndApply(event)

        // 半径変更も履歴に記録
        if maskData != nil && oldRadius == 0 {
            let radiusEvent = ImageBackgroundBlurRadiusChangedEvent(
                elementId: imageElement.id,
                oldRadius: oldRadius,
                newRadius: defaultBlurRadius
            )
            history.recordAndApply(radiusEvent)
        }

        refreshSelectionAndNotifyAfterBackgroundBlur(elementId: imageElement.id)

    }

    /// 背景ぼかしマスクを削除
    /// - Parameter imageElement: 対象の画像要素
    func removeBackgroundBlurMask(from imageElement: ImageElement) {
        let oldMaskData = imageElement.backgroundBlurMaskData
        let oldRadius = imageElement.backgroundBlurRadius

        // マスクと半径をクリア
        imageElement.backgroundBlurMaskData = nil
        imageElement.backgroundBlurRadius = 0
        imageElement.invalidateRenderedImageCache()

        // 履歴に記録
        let maskEvent = ImageBackgroundBlurMaskChangedEvent(
            elementId: imageElement.id,
            oldMaskData: oldMaskData,
            newMaskData: nil
        )
        history.recordAndApply(maskEvent)

        if oldRadius != 0 {
            let radiusEvent = ImageBackgroundBlurRadiusChangedEvent(
                elementId: imageElement.id,
                oldRadius: oldRadius,
                newRadius: 0
            )
            history.recordAndApply(radiusEvent)
        }

        refreshSelectionAndNotifyAfterBackgroundBlur(elementId: imageElement.id)
    }

    /// 画像の役割を変更（ベース/オーバーレイの切り替え）
    func toggleImageRole(_ imageElement: ImageElement) {
        let oldRole = imageElement.imageRole
        let newRole: ImageRole = (oldRole == .base) ? .overlay : .base
        
        // 新しい役割がベースの場合、他の画像要素のベース役割を解除
        if newRole == .base {
            for element in project.elements {
                if let otherImageElement = element as? ImageElement, 
                   otherImageElement.id != imageElement.id,
                   otherImageElement.imageRole == .base {
                    otherImageElement.imageRole = .overlay
                    // 元ベース画像を前面に移動
                    otherImageElement.zIndex = ElementPriority.image.rawValue + 10
                }
            }
        }
        
        // 役割を変更
        imageElement.imageRole = newRole
        
        // zIndexを役割に応じて調整
        if newRole == .base {
            // ベース画像は最背面に配置
            imageElement.zIndex = ElementPriority.image.rawValue - 10
        } else {
            // オーバーレイ画像は通常の画像レイヤーに配置
            imageElement.zIndex = ElementPriority.image.rawValue + 10
        }
        
        // プロジェクト内の要素を現在のzIndex順に並び替え
        project.elements.sort { $0.zIndex < $1.zIndex }
        
        // 変更を通知
        objectWillChange.send()
        isProjectModified = true
        
    }
    
    // MARK: - 要素の操作(移動)
    
    /// 操作開始
    func startManipulation(_ type: ElementManipulationType, at point: CGPoint) {
        manipulationType = type
        manipulationStartPoint = point
        
        // 操作前の要素の状態を保存（ディープコピーを作成）
        if let selectedElement = selectedElement {
            manipulationStartElement = selectedElement.copy()
        } else {
            manipulationStartElement = nil
        }
    }
    
    /// 操作中
    func continueManipulation(at point: CGPoint) {
        guard let element = selectedElement, manipulationType != .none else { return }
        
        let deltaX = point.x - manipulationStartPoint.x
        let deltaY = point.y - manipulationStartPoint.y
        
        switch manipulationType {
        case .move:
            // 要素の移動
            let movedElement = element
            let startX = manipulationStartElement?.position.x ?? 0
            let startY = manipulationStartElement?.position.y ?? 0
            
            movedElement.position = CGPoint(
                x: startX + deltaX,
                y: startY + deltaY
            )
            updateSelectedElement(movedElement) // 操作中は履歴に記録しない
            
        case .resize:
            // 要素のサイズ変更
            let resizedElement = element
            resizedElement.size = CGSize(
                width: max(10, (manipulationStartElement?.size.width ?? 0) + deltaX),
                height: max(10, (manipulationStartElement?.size.height ?? 0) + deltaY)
            )
            updateSelectedElement(resizedElement) // 操作中は履歴に記録しない
            
        case .rotate:
            // 要素の回転
            // 中心点を計算
            let center = CGPoint(
                x: element.position.x + element.size.width / 2,
                y: element.position.y + element.size.height / 2
            )
            
            // 開始点と現在点の角度を計算
            let startAngle = atan2(manipulationStartPoint.y - center.y, manipulationStartPoint.x - center.x)
            let currentAngle = atan2(point.y - center.y, point.x - center.x)
            
            // 回転角度の差分を計算
            let deltaAngle = currentAngle - startAngle
            
            let rotatedElement = element
            rotatedElement.rotation = (manipulationStartElement?.rotation ?? 0) + deltaAngle
            updateSelectedElement(rotatedElement) // 操作中は履歴に記録しない
        case .none:
            break
        }
    }
    
    /// 操作終了 - イベントを記録
    func endManipulation() {
        if let startElement = manipulationStartElement, let element = selectedElement {
            // 実際に変更があった場合のみイベントを記録
            let positionChanged = startElement.position != element.position
            let sizeChanged = startElement.size != element.size
            let rotationChanged = startElement.rotation != element.rotation
            
            if positionChanged || sizeChanged || rotationChanged {
                // 複合変換イベントを作成
                let event = ElementTransformedEvent(
                    elementId: element.id,
                    oldPosition: positionChanged ? startElement.position : nil,
                    newPosition: positionChanged ? element.position : nil,
                    oldSize: sizeChanged ? startElement.size : nil,
                    newSize: sizeChanged ? element.size : nil,
                    oldRotation: rotationChanged ? startElement.rotation : nil,
                    newRotation: rotationChanged ? element.rotation : nil
                )
                
                history.recordAndApply(event)
                isProjectModified = true
            }
        }
        
        manipulationType = .none
        manipulationStartElement = nil
    }
    
    // MARK: - 編集履歴操作
    
    /// アンドゥ操作
    func undo() {
        if history.canUndo {
            history.undo()

            // 選択要素の状態を適切に更新
            if let selectedElement = selectedElement {
                
                // 現在選択中の要素がまだ存在するか確認
                if let updatedElement = project.elements.first(where: { $0.id == selectedElement.id }) {
                    self.selectedElement = updatedElement
                } else {
                    // 要素が削除された場合は選択を解除
                    self.selectedElement = nil
                }
            }
            
            isProjectModified = true
            objectWillChange.send()
        }
    }
    
    /// リドゥ操作
    func redo() {
        if history.canRedo {
            history.redo()
            
            // リドゥ後、選択要素の状態を適切に更新
            if let selectedElement = selectedElement {
                // 現在選択中の要素がまだ存在するか確認
                if let updatedElement = project.elements.first(where: { $0.id == selectedElement.id }) {
                    self.selectedElement = updatedElement
                } else {
                    // 要素が削除された場合は選択を解除
                    self.selectedElement = nil
                }
            }
            
            isProjectModified = true
            objectWillChange.send()
        }
    }
    
    /// アンドゥが可能かどうか
    var canUndo: Bool {
        return history.canUndo
    }
    
    /// リドゥが可能かどうか
    var canRedo: Bool {
        return history.canRedo
    }
    
    // MARK: - イベント適用
    
    /// イベントを適用して記録
    func applyEvent(_ event: EditorEvent) {
        history.recordAndApply(event)
        isProjectModified = true
    }
    
    // MARK: - 履歴情報
    
    /// 操作履歴の説明を取得
    func getHistoryDescriptions() -> [String] {
        return history.getHistoryDescriptions()
    }
    
    // MARK: - 保存（通常/合成）
    //
    // フロー概要:
    //  - UI からは saveProject を呼ぶだけで、要素構成に応じて通常 or 合成を自動判定。
    //  - saveAsCompositeImage は互換用に合成保存を強制するエントリーポイント。
    //  - 保存本体のロジックは SaveImage 配下に分離済み。
    
    /// 写真アプリに画像を保存（通常の1枚保存）
    /// プロジェクトの編集内容をフィルター適用済み画像として写真ライブラリに保存する
    func saveProject(completion: @escaping (Bool) -> Void) {
        saveCoordinator.save(project: project, completion: completion)
    }
    
    /// - 役割：ユーザーが「保存」ボタンを押した時の最初の受け口（エントリーポイント）
    /// - 処理：写真ライブラリの権限確認と合成保存フローの呼び出し
    func saveAsCompositeImage(completion: @escaping (Bool) -> Void) {
        saveCoordinator.saveComposite(project: project, completion: completion)
    }
    
    // MARK: - インポート
    //
    // フロー概要:
    //  - UI から addImageElement / addCroppedImageElement を呼び出す（エントリーポイント）。
    //  - 画像ソースと条件を ImageImportCoordinator に渡して生成・初期配置を委譲。
    //  - 生成後は ViewModel で追加・選択・カメラセンタリングを実行する。
    
    /// 画像要素をデータから追加
    func addImageElement(imageData: Data, position: CGPoint, phAsset: PHAsset? = nil, assetIdentifier: String? = nil) {
        guard let (result, _) = importImageElement(
            source: .imageData(imageData),
            canvasSize: nil,
            assetIdentifier: assetIdentifier
        ) else {
            return
        }

        applyImportedImage(result.element)
    }
    
    /// 画像のクロップ後にImageElementを追加
    func addCroppedImageElement(image: UIImage, assetIdentifier: String? = nil) {
        guard let (result, _) = importImageElement(
            source: .uiImage(image),
            canvasSize: project.canvasSize,
            assetIdentifier: assetIdentifier
        ) else {
            return
        }

        applyImportedImage(result.element)
    }

    private func importImageElement(
        source: ImageImportSource,
        canvasSize: CGSize?,
        assetIdentifier: String?
    ) -> (ImageImportResult, CGSize)? {
        let viewportSize = getViewportSize()
        guard let result = imageImportCoordinator.importImage(
            source: source,
            project: project,
            viewportSize: viewportSize,
            assetIdentifier: assetIdentifier,
            canvasSize: canvasSize
        ) else {
            return nil
        }

        return (result, viewportSize)
    }

    private func applyImportedImage(_ element: ImageElement) {
        addElement(element)
        selectElement(element)

        // 画像が見えるようにカメラを移動
        centerViewOnElement(element)
    }
    
    // MARK: - インポートの表示制御
    
    /// デバイスの画面サイズを取得
    private func getViewportSize() -> CGSize {
        // デバイスの画面サイズを取得
        // 実際の実装は状況に応じて調整が必要
        return UIScreen.main.bounds.size
    }
    
    /// 特定の要素にビューを中央揃え
    private func centerViewOnElement(_ element: LogoElement) {
        // このメソッドは、カメラビューがある場合に、そのビューを特定の要素の位置に移動させる
        // 実装はビューコントローラーのカメラビューの実装に依存
        // NotificationCenter経由で通知を送るか、デリゲートパターンを使用
        
        let centerPoint = CGPoint(
            x: element.position.x + element.size.width / 2,
            y: element.position.y + element.size.height / 2
        )
        
        
        // 通知を送信して、ビューコントローラーにカメラ移動を要求
        NotificationCenter.default.post(
            name: Notification.Name("CenterCameraOnPoint"),
            object: centerPoint
        )
    }
    
    // MARK: - デバッグ
    
#if DEBUG
    /// 履歴の状態をデバッグ出力
    func printHistoryStatus() {
        print("===== 履歴状態 =====")
        print("アンドゥスタック: \(history.undoCount) 項目")
        print("リドゥスタック: \(history.redoCount) 項目")
        print("アンドゥ可能: \(history.canUndo)")
        print("リドゥ可能: \(history.canRedo)")
        
        // 選択状態などの追加情報
        print("選択中の要素: \(selectedElement != nil ? "あり (\(selectedElement!.type))" : "なし")")
        print("エディタモード: \(editorMode)")
        print("プロジェクト変更済み: \(isProjectModified)")
        print("====================")
    }
    
    /// テスト用の要素を追加
    func addTestElements() {
        // テキスト要素を追加
        let textElement = TextElement(text: "テスト文字列")
        textElement.position = CGPoint(x: 100, y: 100)
        addElement(textElement)
        
        // 図形要素を追加
        let shapeElement = ShapeElement(shapeType: .rectangle)
        shapeElement.position = CGPoint(x: 200, y: 200)
        shapeElement.fillColor = .systemBlue
        addElement(shapeElement)
        
        print("テスト要素を追加しました")
    }
#endif
}
