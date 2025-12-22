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
    case textCreate  // テキスト作成
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

    /// 外部からプロジェクト変更フラグを立てる
    func markProjectModified() {
        isProjectModified = true
    }
    
    // MARK: - イニシャライザ
    
    /// 新しいプロジェクトでエディタを初期化
    init(project: LogoProject = LogoProject()) {
        self.project = project
        print("DEBUG: ViewModel初期化時のプロジェクト要素数: \(project.elements.count)")
        
        // 履歴管理の初期化
        history = EditorHistory(project: project)
        print("DEBUG: 履歴管理初期化完了")
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
        print("DEBUG: 要素追加前のプロジェクト要素数: \(project.elements.count)")
        
        // 自動Z-Index設定
        setAutoZIndex(for: element)
        
        let event = ElementAddedEvent(element: element)
        history.recordAndApply(event)
        
        print("DEBUG: 要素追加後のプロジェクト要素数: \(project.elements.count)")
        print("DEBUG: 追加された要素ID: \(element.id), zIndex: \(element.zIndex)")
        
        selectedElement = element
        isProjectModified = true
    }
    
    /// 要素の自動Z-Index設定
    private func setAutoZIndex(for element: LogoElement) {
        let elementPriority = ElementPriority.defaultPriority(for: element.type)
        let nextZIndex = elementPriority.nextAvailableZIndex(existingElements: project.elements)
        element.zIndex = nextZIndex
        
        print("DEBUG: 要素タイプ: \(element.type), 優先度: \(elementPriority), 設定されたzIndex: \(nextZIndex)")
    }
    
    /// テキスト要素を追加
    func addTextElement(text: String = "Double tap here to change text", position: CGPoint) {
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
        
        print("DEBUG: テキスト編集開始 - 要素ID: \(textElement.id)")
    }
    
    /// テキスト編集を終了
    func endTextEditing() {
        if isEditingText {
            print("DEBUG: テキスト編集終了")
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
    func updateSelectedElement(_ element: LogoElement, recordInHistory: Bool = true) {
        guard let index = project.elements.firstIndex(where: { $0.id == element.id }) else { return }
        
        // 履歴に記録するかどうかを判断
        if recordInHistory {
            // ここではイベントを使用しない
            project.elements[index] = element
        } else {
            // 履歴に記録せずに要素を直接更新
            project.elements[index] = element
        }
        
        // 選択要素を更新
        selectedElement = element
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
    
    // MARK: - テキスト要素の操作
    
    /// テキスト内容の更新
    func updateTextContent(_ textElement: TextElement, newText: String) {
        let event = TextContentChangedEvent(
            elementId: textElement.id,
            oldText: textElement.text,
            newText: newText
        )
        
        history.recordAndApply(event)
        
        // 選択要素を更新
        if selectedElement?.id == textElement.id {
            selectedElement = textElement
        }
        
        isProjectModified = true
    }
    
    /// テキスト色の更新
    func updateTextColor(_ textElement: TextElement, newColor: UIColor) {
        print("DEBUG: テキスト色変更開始 - 要素ID: \(textElement.id)")
        print("DEBUG: 色変更前のイベントスタック: \(history.getEventNames())")
        
        // 現在と同じ色なら何もしない
        if textElement.textColor.isEqual(newColor) {
            print("DEBUG: 色が同じなので変更をスキップします")
            return
        }
        
        // TextColorChangedEventを作成
        let event = TextColorChangedEvent(
            elementId: textElement.id,
            oldColor: textElement.textColor,
            newColor: newColor
        )
        
        // イベントを履歴に記録して適用
        history.recordAndApply(event)
        
        print("DEBUG: 色変更後のイベントスタック: \(history.getEventNames())")
        
        // 選択要素を更新
        if selectedElement?.id == textElement.id {
            selectedElement = textElement
        }
        
        isProjectModified = true
        print("DEBUG: テキスト色変更完了")
    }
    
    /// フォントの更新
    func updateFont(_ textElement: TextElement, fontName: String, fontSize: CGFloat) {
        print("DEBUG: フォント更新開始 - 要素ID: \(textElement.id)")
        print("DEBUG: 更新前のフォント: \(textElement.fontName), サイズ: \(textElement.fontSize)")
        
        // フォント変更イベントの作成
        let event = FontChangedEvent(
            elementId: textElement.id,
            oldFontName: textElement.fontName,
            newFontName: fontName,
            oldFontSize: textElement.fontSize,
            newFontSize: fontSize
        )
        
        // イベントを履歴に記録して適用
        history.recordAndApply(event)
        
        // 選択要素を更新
        if selectedElement?.id == textElement.id {
            // 最新の状態を反映
            if let updatedElement = project.elements.first(where: { $0.id == textElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: フォント更新完了: \(fontName), サイズ: \(fontSize)")
    }
    
    // MARK: - 図形の操作
    
    /// 図形タイプの更新
    func updateShapeType(_ shapeElement: ShapeElement, newType: ShapeType) {
        print("DEBUG: 図形タイプ変更開始 - 要素ID: \(shapeElement.id)")
        
        // 図形タイプ変更イベントの作成
        let event = ShapeTypeChangedEvent(
            elementId: shapeElement.id,
            oldType: shapeElement.shapeType,
            newType: newType
        )
        
        // イベントを履歴に記録して適用
        history.recordAndApply(event)
        
        // 選択要素を更新
        if selectedElement?.id == shapeElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == shapeElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 図形タイプ変更完了: \(newType)")
    }
    
    /// 図形の塗りつぶし色を更新
    func updateShapeFillColor(_ shapeElement: ShapeElement, newColor: UIColor) {
        print("DEBUG: 塗りつぶし色変更開始 - 要素ID: \(shapeElement.id)")
        
        let event = ShapeFillColorChangedEvent(
            elementId: shapeElement.id,
            oldColor: shapeElement.fillColor,
            newColor: newColor
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == shapeElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == shapeElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 塗りつぶし色変更完了")
    }
    
    /// 図形の塗りつぶしモードを更新
    func updateShapeFillMode(_ shapeElement: ShapeElement, newMode: FillMode) {
        print("DEBUG: 塗りつぶしモード変更開始 - 要素ID: \(shapeElement.id)")
        
        let event = ShapeFillModeChangedEvent(
            elementId: shapeElement.id,
            oldMode: shapeElement.fillMode,
            newMode: newMode
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == shapeElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == shapeElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 塗りつぶしモード変更完了")
    }
    
    /// 図形の枠線色を更新
    func updateShapeStrokeColor(_ shapeElement: ShapeElement, newColor: UIColor) {
        print("DEBUG: 枠線色変更開始 - 要素ID: \(shapeElement.id)")
        
        let event = ShapeStrokeColorChangedEvent(
            elementId: shapeElement.id,
            oldColor: shapeElement.strokeColor,
            newColor: newColor
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == shapeElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == shapeElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 枠線色変更完了")
    }
    
    /// 図形の枠線太さを更新
    func updateShapeStrokeWidth(_ shapeElement: ShapeElement, newWidth: CGFloat) {
        print("DEBUG: 枠線太さ変更開始 - 要素ID: \(shapeElement.id)")
        
        let event = ShapeStrokeWidthChangedEvent(
            elementId: shapeElement.id,
            oldWidth: shapeElement.strokeWidth,
            newWidth: newWidth
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == shapeElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == shapeElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 枠線太さ変更完了")
    }
    
    /// 図形の枠線モードを更新
    func updateShapeStrokeMode(_ shapeElement: ShapeElement, newMode: StrokeMode) {
        print("DEBUG: 枠線モード変更開始 - 要素ID: \(shapeElement.id)")
        
        let event = ShapeStrokeModeChangedEvent(
            elementId: shapeElement.id,
            oldMode: shapeElement.strokeMode,
            newMode: newMode
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == shapeElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == shapeElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 枠線モード変更完了")
    }
    
    /// 図形の角丸半径を更新
    func updateShapeCornerRadius(_ shapeElement: ShapeElement, newRadius: CGFloat) {
        print("DEBUG: 角丸半径変更開始 - 要素ID: \(shapeElement.id)")
        
        let event = ShapeCornerRadiusChangedEvent(
            elementId: shapeElement.id,
            oldRadius: shapeElement.cornerRadius,
            newRadius: newRadius
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == shapeElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == shapeElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 角丸半径変更完了")
    }
    
    /// 図形の辺の数を更新
    func updateShapeSides(_ shapeElement: ShapeElement, newSides: Int) {
        print("DEBUG: 辺の数変更開始 - 要素ID: \(shapeElement.id)")
        
        let event = ShapeSidesChangedEvent(
            elementId: shapeElement.id,
            oldSides: shapeElement.sides,
            newSides: newSides
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == shapeElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == shapeElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 辺の数変更完了")
    }
    
    /// 図形のグラデーション色を更新
    func updateShapeGradientColors(_ shapeElement: ShapeElement, oldStartColor: UIColor, newStartColor: UIColor, oldEndColor: UIColor, newEndColor: UIColor) {
        print("DEBUG: グラデーション色変更開始 - 要素ID: \(shapeElement.id)")
        
        let event = ShapeGradientColorsChangedEvent(
            elementId: shapeElement.id,
            oldStartColor: oldStartColor,
            newStartColor: newStartColor,
            oldEndColor: oldEndColor,
            newEndColor: newEndColor
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == shapeElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == shapeElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: グラデーション色変更完了")
    }
    
    func updateShapeGradientAngle(_ shapeElement: ShapeElement, newAngle: CGFloat) {
        print("DEBUG: グラデーション角度変更開始 - 要素ID: \(shapeElement.id)")
        
        let event = ShapeGradientAngleChangedEvent(
            elementId: shapeElement.id,
            oldAngle: shapeElement.gradientAngle,
            newAngle: newAngle
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == shapeElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == shapeElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: グラデーション角度変更完了")
    }
    
    // MARK: - 画像要素の操作
    
    /// 画像の彩度を更新
    func updateImageSaturation(_ imageElement: ImageElement, newSaturation: CGFloat) {
        print("DEBUG: 画像彩度変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageSaturationChangedEvent(
            elementId: imageElement.id,
            oldSaturation: imageElement.saturationAdjustment,
            newSaturation: newSaturation
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像彩度変更完了")
    }
    
    /// 画像の明度を更新
    func updateImageBrightness(_ imageElement: ImageElement, newBrightness: CGFloat) {
        print("DEBUG: 画像明度変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageBrightnessChangedEvent(
            elementId: imageElement.id,
            oldBrightness: imageElement.brightnessAdjustment,
            newBrightness: newBrightness
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像明度変更完了")
    }
    
    /// 画像のコントラストを更新
    func updateImageContrast(_ imageElement: ImageElement, newContrast: CGFloat) {
        print("DEBUG: 画像コントラスト変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageContrastChangedEvent(
            elementId: imageElement.id,
            oldContrast: imageElement.contrastAdjustment,
            newContrast: newContrast
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像コントラスト変更完了")
    }
    
    /// 画像のハイライトを更新
    func updateImageHighlights(_ imageElement: ImageElement, newHighlights: CGFloat) {
        print("DEBUG: 画像ハイライト変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageHighlightsChangedEvent(
            elementId: imageElement.id,
            oldHighlights: imageElement.highlightsAdjustment,
            newHighlights: newHighlights
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像ハイライト変更完了")
    }
    
    /// 画像のシャドウを更新
    func updateImageShadows(_ imageElement: ImageElement, newShadows: CGFloat) {
        print("DEBUG: 画像シャドウ変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageShadowsChangedEvent(
            elementId: imageElement.id,
            oldShadows: imageElement.shadowsAdjustment,
            newShadows: newShadows
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像シャドウ変更完了")
    }
    
    /// 画像の色相を更新
    func updateImageHue(_ imageElement: ImageElement, newHue: CGFloat) {
        print("DEBUG: 画像色相変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageHueChangedEvent(
            elementId: imageElement.id,
            oldHue: imageElement.hueAdjustment,
            newHue: newHue
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像色相変更完了")
    }
    
    /// 画像のシャープネスを更新
    func updateImageSharpness(_ imageElement: ImageElement, newSharpness: CGFloat) {
        print("DEBUG: 画像シャープネス変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageSharpnessChangedEvent(
            elementId: imageElement.id,
            oldSharpness: imageElement.sharpnessAdjustment,
            newSharpness: newSharpness
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像シャープネス変更完了")
    }
    
    /// 画像のガウシアンブラーを更新
    func updateImageGaussianBlur(_ imageElement: ImageElement, newRadius: CGFloat) {
        print("DEBUG: 画像ガウシアンブラー変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageGaussianBlurChangedEvent(
            elementId: imageElement.id,
            oldRadius: imageElement.gaussianBlurRadius,
            newRadius: newRadius
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像ガウシアンブラー変更完了")
    }
    
    /// 画像のティントカラーを更新
    func updateImageTintColor(_ imageElement: ImageElement, oldColor: UIColor?, newColor: UIColor?, oldIntensity: CGFloat, newIntensity: CGFloat) {
        print("DEBUG: 画像ティントカラー変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageTintColorChangedEvent(
            elementId: imageElement.id,
            oldColor: oldColor,
            newColor: newColor,
            oldIntensity: oldIntensity,
            newIntensity: newIntensity
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像ティントカラー変更完了")
    }
    
    /// 画像のフレーム表示を更新
    func updateImageShowFrame(_ imageElement: ImageElement, newValue: Bool) {
        print("DEBUG: 画像フレーム表示変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageShowFrameChangedEvent(
            elementId: imageElement.id,
            oldValue: imageElement.showFrame,
            newValue: newValue
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像フレーム表示変更完了")
    }
    
    /// 画像のフレーム色を更新
    func updateImageFrameColor(_ imageElement: ImageElement, newColor: UIColor) {
        print("DEBUG: 画像フレーム色変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageFrameColorChangedEvent(
            elementId: imageElement.id,
            oldColor: imageElement.frameColor,
            newColor: newColor
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像フレーム色変更完了")
    }
    
    /// 画像のフレーム太さを更新
    func updateImageFrameWidth(_ imageElement: ImageElement, newWidth: CGFloat) {
        print("DEBUG: 画像フレーム太さ変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageFrameWidthChangedEvent(
            elementId: imageElement.id,
            oldWidth: imageElement.frameWidth,
            newWidth: newWidth
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像フレーム太さ変更完了")
    }
    
    /// 画像の角丸設定を更新
    func updateImageRoundedCorners(_ imageElement: ImageElement, wasRounded: Bool, isRounded: Bool, oldRadius: CGFloat, newRadius: CGFloat) {
        print("DEBUG: 画像角丸設定変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageRoundedCornersChangedEvent(
            elementId: imageElement.id,
            wasRounded: wasRounded,
            isRounded: isRounded,
            oldRadius: oldRadius,
            newRadius: newRadius
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像角丸設定変更完了")
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
        
        print("DEBUG: 画像役割変更: \(oldRole.displayName) → \(newRole.displayName)")
        print("DEBUG: zIndex変更: \(imageElement.zIndex)")
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
            updateSelectedElement(movedElement, recordInHistory: false) // 履歴に記録しない
            
        case .resize:
            // 要素のサイズ変更
            let resizedElement = element
            resizedElement.size = CGSize(
                width: max(10, (manipulationStartElement?.size.width ?? 0) + deltaX),
                height: max(10, (manipulationStartElement?.size.height ?? 0) + deltaY)
            )
            updateSelectedElement(resizedElement, recordInHistory: false) // 履歴に記録しない
            
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
            updateSelectedElement(rotatedElement, recordInHistory: false) // 履歴に記録しない
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
            
            print("DEBUG: 各イベントの詳細:")
            for (index, event) in history.eventStack.enumerated() {
                if let colorEvent = event as? TextColorChangedEvent {
                    print("DEBUG: イベント[\(index)]: \(event.eventName) - 旧色:\(colorEvent.oldColor) 新色:\(colorEvent.newColor)")
                } else {
                    print("DEBUG: イベント[\(index)]: \(event.eventName)")
                }
            }
            
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
        print("DEBUG: addImageElement開始 - PHAsset: \(phAsset != nil), 識別子: \(assetIdentifier ?? "なし")")
        guard let (result, viewportSize) = importImageElement(
            source: .imageData(imageData),
            canvasSize: nil,
            assetIdentifier: assetIdentifier
        ) else {
            return
        }

        if let assetIdentifier = result.assetIdentifier {
            print("DEBUG: 受け取った識別子を設定: \(assetIdentifier)")
        } else {
            print("DEBUG: 内部生成のUUIDを設定: \(result.element.originalImageIdentifier ?? "なし")")
        }

        print("DEBUG: 配置位置 - X: \(result.element.position.x), Y: \(result.element.position.y)")
        print("DEBUG: ビューポートサイズ: \(viewportSize)")

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

        print("DEBUG: クロップ済み画像配置位置 - X: \(result.element.position.x), Y: \(result.element.position.y)")
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
        
        print("DEBUG: カメラを中央に移動: \(centerPoint)")
        
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
