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
    
    /// 要素操作の開始位置
    private var manipulationStartPoint: CGPoint = .zero
    
    /// 操作前の要素の状態
    private var manipulationStartElement: LogoElement?
    
    /// 次に作成する図形のタイプ
    var nextShapeType: ShapeType = .rectangle
    
    /// プロジェクトが変更されたかどうか
    @Published private(set) var isProjectModified = false
    
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
    func addImageElement(fileName: String, position: CGPoint) {
        let imageElement = ImageElement(fileName: fileName)
        imageElement.position = position
        addElement(imageElement)
    }
    
    /// 画像要素をデータから追加
    func addImageElement(imageData: Data, position: CGPoint, phAsset: PHAsset? = nil, assetIdentifier: String? = nil) {
        print("DEBUG: addImageElement開始 - PHAsset: \(phAsset != nil), 識別子: \(assetIdentifier ?? "なし")")
        
        // 現在の画像要素数を数えてインポート順番を決定
        let currentImageCount = project.elements.compactMap { $0 as? ImageElement }.count
        let importOrder = currentImageCount + 1
        
        let imageElement = ImageElement(imageData: imageData, fitMode: .aspectFit, importOrder: importOrder)
        
        // 役割に応じてzIndexを設定
        if imageElement.imageRole == .base {
            // ベース画像（1番目）は背面に配置
            imageElement.zIndex = ElementPriority.image.rawValue - 10
        } else {
            // オーバーレイ画像は前面に配置
            imageElement.zIndex = ElementPriority.image.rawValue + 10
        }
        
        // 一時保存された識別子を使用
        if let assetIdentifier = TemporaryImageData.shared.lastSelectedAssetIdentifier {
            imageElement.originalImageIdentifier = assetIdentifier
            print("DEBUG: 一時保存されていた識別子を設定: \(assetIdentifier)")
            
            // 使用したら消去（次回のために）
            TemporaryImageData.shared.lastSelectedAssetIdentifier = nil
        } else {
            // PHAssetがない場合は内部で生成したUUIDを使用
            imageElement.originalImageIdentifier = UUID().uuidString
            print("DEBUG: 内部生成のUUIDを設定: \(imageElement.originalImageIdentifier!)")
        }
        
        // 【修正箇所1】画面に表示される範囲の中央に配置（ビューポートの中央）
        // デバイスの画面サイズを取得（おおよそのビューポート）
        let viewportSize = getViewportSize() // 新しいメソッドを追加
        let viewportCenter = CGPoint(
            x: viewportSize.width / 2,
            y: viewportSize.height / 4
        )
        
        // キャンバス上の可視範囲の中央に配置
        imageElement.position = CGPoint(
            x: viewportCenter.x - imageElement.size.width / 2,
            y: viewportCenter.y - imageElement.size.height / 2
        )
        
        print("DEBUG: 配置位置 - X: \(imageElement.position.x), Y: \(imageElement.position.y)")
        print("DEBUG: ビューポートサイズ: \(viewportSize)")
        
        addElement(imageElement)
        selectElement(imageElement)
        
        // 【修正箇所2】画像が見えるようにカメラを移動
        centerViewOnElement(imageElement)
    }
    
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
        // 逆順（前面の要素から）にチェック
        for element in project.elements.reversed() {
            if !element.isLocked && element.isVisible && element.hitTest(point) {
                return element
            }
        }
        return nil
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
        
        // TODO: 可視性切り替えイベントの実装
        // 現在の実装では直接可視性を切り替え
        element.isVisible = !element.isVisible
        
        updateSelectedElement(element)
        isProjectModified = true
    }
    
    /// 選択中の要素のロック状態を切り替え
    func toggleSelectedElementLock() {
        guard let element = selectedElement else { return }
        
        // TODO: ロック状態切り替えイベントの実装
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
    
    /// 画像のフィッティングモードを更新
    func updateImageFitMode(_ imageElement: ImageElement, newMode: ImageFitMode) {
        print("DEBUG: 画像フィットモード変更開始 - 要素ID: \(imageElement.id)")
        
        let event = ImageFitModeChangedEvent(
            elementId: imageElement.id,
            oldMode: imageElement.fitMode,
            newMode: newMode
        )
        
        history.recordAndApply(event)
        
        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }
        
        isProjectModified = true
        print("DEBUG: 画像フィットモード変更完了")
    }
    
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

    /// 画像のトーンカーブを更新
    func updateImageToneCurve(_ imageElement: ImageElement, newPoints: [CGPoint]) {
        print("DEBUG: 画像トーンカーブ変更開始 - 要素ID: \(imageElement.id)")

        let event = ImageToneCurveChangedEvent(
            elementId: imageElement.id,
            oldPoints: imageElement.toneCurvePoints,
            newPoints: newPoints
        )

        history.recordAndApply(event)

        if selectedElement?.id == imageElement.id {
            if let updatedElement = project.elements.first(where: { $0.id == imageElement.id }) {
                selectedElement = updatedElement
            }
        }

        isProjectModified = true
        print("DEBUG: 画像トーンカーブ変更完了")
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
    
    // MARK: - 編集した画像、テキスト、図形要素などの保存
    
    /// 写真アプリに画像を保存（通常の1枚保存）
    /// プロジェクトの編集内容をフィルター適用済み画像として写真ライブラリに保存する
    func saveProject(completion: @escaping (Bool) -> Void) {
        saveToPhotoLibrary(completion: completion)
    }
    
    /// 写真アプリに画像を保存（通常の1枚保存）
    /// - Parameter completion: 保存結果のコールバック（true: 成功, false: 失敗）
    func saveToPhotoLibrary(completion: @escaping (Bool) -> Void) {
        // 現在の写真ライブラリへの書き込み権限を確認
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch authStatus {
        case .authorized, .limited:
            // 既に権限がある場合は即座に保存処理開始
            performPhotoLibrarySave(completion: completion)
        case .notDetermined:
            // 権限が未決定の場合はユーザーに権限を要求
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
                // システムの権限ダイアログの結果を受け取る
                DispatchQueue.main.async {
                    switch status {
                    case .authorized, .limited:
                        // 権限が許可された場合は保存処理実行
                        self?.performPhotoLibrarySave(completion: completion)
                    default:
                        // 権限が拒否された場合は失敗として処理
                        completion(false)
                    }
                }
            }
        default:
            // .denied または .restricted の場合は即座に失敗
            completion(false)
        }
    }
    
    /// 実際の写真ライブラリ保存処理（画像要素直接保存）
    /// 権限確認後に呼び出される
    /// 画像要素をベースとし、その上に配置されたテキスト・図形要素を重ねて統合画像を作成・保存
    private func performPhotoLibrarySave(completion: @escaping (Bool) -> Void) {
        // 重い画像処理をバックグラウンドタスクで実行（UIをブロックしない）
        Task.detached(priority: .userInitiated) { [weak self] in
            // ViewModelが解放されている場合は処理中止
            guard let self = self else {
                // 解放されてたら実行される
                await MainActor.run { completion(false) }
                return
            }
            
            // プロジェクト内の全要素から画像要素のみを抽出
            // compactMapを使用してnilを除外し、ImageElement型のみを残す
            let imageElements = self.project.elements.compactMap { $0 as? ImageElement }
            
            print("DEBUG: 画像要素数: \(imageElements.count)")
            
            // 画像要素が1つ以上存在することを確認、なければ保存処理を中止
            guard !imageElements.isEmpty else {
                print("DEBUG: 保存する画像要素が見つかりません")
                await MainActor.run { completion(false) }
                return
            }
            
            // 複数の画像要素の中から最高解像度のものを保存対象として選択
            // 理由: 最も高品質な画像を保存するため
            var targetImageElement: ImageElement?
            var maxPixelCount: CGFloat = 0
            
            // 各画像要素の解像度を比較して最大のものを見つける
            for imageElement in imageElements {
                if let originalImage = imageElement.originalImage,
                   let cgImage = originalImage.cgImage {
                    // ピクセル総数を計算（幅 × 高さ）
                    let pixelCount = CGFloat(cgImage.width * cgImage.height)
                    print("DEBUG: 画像要素 \(imageElement.id) - サイズ: \(cgImage.width)x\(cgImage.height), ピクセル数: \(pixelCount)")
                    
                    // より高解像度の画像が見つかったら更新
                    if pixelCount > maxPixelCount {
                        maxPixelCount = pixelCount
                        targetImageElement = imageElement
                        print("DEBUG: 最大解像度画像更新: \(cgImage.width)x\(cgImage.height)")
                    }
                }
            }
            
            // 選択された画像要素からフィルター適用済みの画像を取得
            // getFilteredImageForce(): フィルター未適用の場合は強制的に適用して取得
            guard let imageElement = targetImageElement,
                  let processedImage = imageElement.getFilteredImageForce() else {
                print("DEBUG: 保存対象の画像要素が見つからない、または画像処理に失敗")
                await MainActor.run { completion(false) }
                return
            }
            
            print("DEBUG: 保存する画像サイズ: \(processedImage.size)")
            print("DEBUG: 保存する画像スケール: \(processedImage.scale)")
            
            // この画像要素の上に配置されているテキスト・図形要素を収集
            // 画像要素以外かつ可視状態のテキスト・図形要素のみを対象とする
            let overlayElements = self.project.elements.filter { element in
                // 以下の条件をすべて満たす要素を抽出:
                // 1. 現在の画像要素とは異なる（自分自身は除外）
                // 2. 可視状態である（非表示要素は除外）
                // 3. テキストまたは図形要素である
                return element.id != imageElement.id && element.isVisible &&
                (element.type == .text || element.type == .shape)
            }
            
            print("DEBUG: 画像要素情報 - ID: \(imageElement.id), 位置: \(imageElement.position), サイズ: \(imageElement.size)")
            
            print("DEBUG: オーバーレイ要素数 - テキスト: \(overlayElements.filter { $0.type == .text }.count), 図形: \(overlayElements.filter { $0.type == .shape }.count)")
            
            // 保存する最終画像を決定する分岐処理
            let finalImage: UIImage
            if !overlayElements.isEmpty {
                // テキストや図形要素がある場合: 統合画像を作成
                // createCompositeImage()で画像上にテキスト・図形を描画した統合画像を作成
                // 失敗した場合はフィルター適用済み画像をフォールバック
                finalImage = self.createCompositeImage(baseImage: processedImage, overlayElements: overlayElements) ?? processedImage
                print("DEBUG: 統合画像作成完了")
            } else {
                // オーバーレイ要素がない場合: 元のフィルター適用済み画像をそのまま使用
                finalImage = processedImage
                print("DEBUG: オーバーレイなし - 元の画像をそのまま使用")
            }
            
            // 最終画像を写真ライブラリに保存
            do {
                // PHPhotoLibrary.performChanges: 写真ライブラリへの変更操作を実行
                // PHAssetCreationRequest: UIImageから新しい写真アセットを作成
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.creationRequestForAsset(from: finalImage)
                }
                // 保存成功時はメインスレッドでコールバック実行
                await MainActor.run { completion(true) }
                print("DEBUG: 画像要素の保存完了")
            } catch {
                // 保存失敗時のエラーハンドリング
                print("DEBUG: 写真ライブラリ保存エラー: \(error.localizedDescription)")
                await MainActor.run { completion(false) }
            }
        }
    }
    
    // MARK: - 合成画像保存　編集した画像、テキスト、図形要素などの保存
    
    /// - 役割：ユーザーが「保存」ボタンを押した時の最初の受け口（エントリーポイント）
    /// - 処理：写真ライブラリの権限確認のみ
    /// - 呼び出し：権限OKなら performCompositeImageSave を呼ぶ
    func saveAsCompositeImage(completion: @escaping (Bool) -> Void) {
        print("DEBUG: 合成保存開始")
        
        // 現在の写真ライブラリへの書き込み権限を確認
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch authStatus {
        case .authorized, .limited:
            // 既に権限がある場合は即座に保存処理開始
            performCompositeImageSave(completion: completion)
        case .notDetermined:
            // 権限が未決定の場合はユーザーに権限を要求
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized, .limited:
                        self?.performCompositeImageSave(completion: completion)
                    default:
                        completion(false)
                    }
                }
            }
        default:
            // 権限が拒否されている場合は即座に失敗
            completion(false)
        }
    }
    
    /// - 役割：実際の保存処理を統括
    /// - 処理： ベース画像選択, オーバーレイ要素抽出, 背景向き判定と合成処理の振り分け（ここが重要！）, 写真ライブラリへの保存
    /// - 呼び出し：判定結果に応じて適切な合成関数を呼ぶ
    private func performCompositeImageSave(completion: @escaping (Bool) -> Void) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else {
                await MainActor.run { completion(false) }
                return
            }
            
            // 画像要素を抽出
            let imageElements = self.project.elements.compactMap { $0 as? ImageElement }
            
            print("DEBUG: 画像要素数: \(imageElements.count)")
            
            guard !imageElements.isEmpty else {
                print("DEBUG: 保存する画像要素が見つかりません")
                await MainActor.run { completion(false) }
                return
            }
            
            // ベース画像を役割ベースで選択（新しいロジック）
            var baseImageElement: ImageElement?
            
            // 1. まずベース役割の画像を探す
            baseImageElement = imageElements.first { $0.imageRole == .base }
            
            // 2. ベース役割がない場合は、最高解像度の画像を選択（既存ロジック）
            if baseImageElement == nil {
                var maxPixelCount: CGFloat = 0
                for imageElement in imageElements {
                    if let originalImage = imageElement.originalImage,
                       let cgImage = originalImage.cgImage {
                        let pixelCount = CGFloat(cgImage.width * cgImage.height)
                        if pixelCount > maxPixelCount {
                            maxPixelCount = pixelCount
                            baseImageElement = imageElement
                        }
                    }
                }
            }
            
            guard let selectedBaseImageElement = baseImageElement,
                  let baseImage = selectedBaseImageElement.getFilteredImageForce() else {
                print("DEBUG: ベース画像の取得に失敗")
                await MainActor.run { completion(false) }
                return
            }
            
            print("DEBUG: ベース画像選択 - 役割: \(selectedBaseImageElement.imageRole.displayName), インポート順: \(selectedBaseImageElement.originalImportOrder)")
            
            // 他の全要素をオーバーレイ（画像・テキスト・図形すべて）
            let overlayElements = self.project.elements.filter { element in
                return element.id != selectedBaseImageElement.id && element.isVisible
            }
            
            print("DEBUG: オーバーレイ要素数: \(overlayElements.count)")
            
            // STEP: 背景画像の向き判定（合成保存用）
            let isPortraitBackground = baseImage.size.height > baseImage.size.width
            print("DEBUG: =============== 合成保存：背景画像向き判定 ===============")
            print("DEBUG: 画像サイズ - 幅: \(baseImage.size.width), 高さ: \(baseImage.size.height)")
            print("DEBUG: アスペクト比: \(baseImage.size.width / baseImage.size.height)")
            print("DEBUG: 判定結果: \(isPortraitBackground ? "縦向き" : "横向き")")
            print("DEBUG: =====================================================")
            
            let finalImage: UIImage
            if isPortraitBackground {
                // 縦向き背景: 専用の合成関数を使用
                print("DEBUG: 🔥 縦向き背景検出 - createCompositeImagePortrait を使用開始")
                finalImage = self.createCompositeImagePortrait(baseImage: baseImage, overlayElements: overlayElements) ?? baseImage
                print("DEBUG: 🔥 縦向き背景処理完了")
            } else {
                // 横向き背景: 既存の合成関数を使用
                print("DEBUG: ➡️ 横向き背景検出 - createCompositeImage を使用開始")
                finalImage = self.createCompositeImage(baseImage: baseImage, overlayElements: overlayElements) ?? baseImage
                print("DEBUG: ➡️ 横向き背景処理完了")
            }
            
            // 写真ライブラリに保存
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.creationRequestForAsset(from: finalImage)
                }
                await MainActor.run { completion(true) }
                print("DEBUG: 合成画像保存完了")
            } catch {
                print("DEBUG: 合成画像保存エラー: \(error.localizedDescription)")
                await MainActor.run { completion(false) }
            }
        }
    }
    
    
    
    /// 高解像度画像要素を直接描画（ImageElement.drawのロジックを再現）
    private func drawHighResolutionImageElement(
        image: UIImage,
        element: ImageElement,
        adjustedElement: LogoElement,
        in context: CGContext
    ) {
        guard element.isVisible else { return }
        
        context.saveGState()
        
        // 透明度の設定
        context.setAlpha(element.opacity)
        
        // 中心点を計算
        let centerX = adjustedElement.position.x + adjustedElement.size.width / 2
        let centerY = adjustedElement.position.y + adjustedElement.size.height / 2
        
        // 変換行列を適用（回転と位置）
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: element.rotation)
        context.translateBy(x: -adjustedElement.size.width / 2, y: -adjustedElement.size.height / 2)
        
        // 描画領域
        let rect = CGRect(origin: .zero, size: adjustedElement.size)
        
        // 角丸クリッピングパスの設定
        if element.roundedCorners && element.cornerRadius > 0 {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: element.cornerRadius)
            context.addPath(path.cgPath)
            context.clip()
        }
        
        // フィットモードに応じた描画矩形を計算
        let drawRect = self.calculateImageDrawRect(imageSize: image.size, boundingRect: rect, fitMode: element.fitMode)
        
        if element.fitMode == .tile {
            // タイルパターンで描画
            context.saveGState()
            context.clip(to: rect)
            
            let tileSize = image.size
            let horizontalTiles = ceil(adjustedElement.size.width / tileSize.width)
            let verticalTiles = ceil(adjustedElement.size.height / tileSize.height)
            
            for y in 0..<Int(verticalTiles) {
                for x in 0..<Int(horizontalTiles) {
                    let tileRect = CGRect(
                        x: CGFloat(x) * tileSize.width,
                        y: CGFloat(y) * tileSize.height,
                        width: tileSize.width,
                        height: tileSize.height
                    )
                    image.draw(in: tileRect)
                }
            }
            
            context.restoreGState()
        } else {
            // 通常描画
            image.draw(in: drawRect)
        }
        
        // フレーム描画
        if element.showFrame && element.frameWidth > 0 {
            context.setStrokeColor(element.frameColor.cgColor)
            context.setLineWidth(element.frameWidth)
            
            if element.roundedCorners && element.cornerRadius > 0 {
                let frameRect = rect.insetBy(dx: element.frameWidth / 2, dy: element.frameWidth / 2)
                let path = UIBezierPath(roundedRect: frameRect, cornerRadius: element.cornerRadius)
                context.addPath(path.cgPath)
                context.strokePath()
            } else {
                context.stroke(rect.insetBy(dx: element.frameWidth / 2, dy: element.frameWidth / 2))
            }
        }
        
        context.restoreGState()
    }
    
    /// フィッティングモードに応じた描画矩形を計算
    private func calculateImageDrawRect(imageSize: CGSize, boundingRect: CGRect, fitMode: ImageFitMode) -> CGRect {
        switch fitMode {
        case .fill:
            return boundingRect
            
        case .aspectFit:
            let widthRatio = boundingRect.width / imageSize.width
            let heightRatio = boundingRect.height / imageSize.height
            let scale = min(widthRatio, heightRatio)
            
            let newWidth = imageSize.width * scale
            let newHeight = imageSize.height * scale
            
            return CGRect(
                x: boundingRect.midX - newWidth / 2,
                y: boundingRect.midY - newHeight / 2,
                width: newWidth,
                height: newHeight
            )
            
        case .aspectFill:
            let widthRatio = boundingRect.width / imageSize.width
            let heightRatio = boundingRect.height / imageSize.height
            let scale = max(widthRatio, heightRatio)
            
            let newWidth = imageSize.width * scale
            let newHeight = imageSize.height * scale
            
            return CGRect(
                x: boundingRect.midX - newWidth / 2,
                y: boundingRect.midY - newHeight / 2,
                width: newWidth,
                height: newHeight
            )
            
        case .center:
            return CGRect(
                x: boundingRect.midX - imageSize.width / 2,
                y: boundingRect.midY - imageSize.height / 2,
                width: imageSize.width,
                height: imageSize.height
            )
            
        case .tile:
            return boundingRect
        }
    }
    
    /// アスペクト比を考慮した最適な合成サイズを計算
    /// - Parameters:
    ///   - baseImage: ベース画像
    ///   - overlayElements: オーバーレイ要素配列
    /// - Returns: 最適な合成サイズ
    private func calculateOptimalCompositeSize(baseImage: UIImage, overlayElements: [LogoElement]) -> CGSize {
        let baseSize = baseImage.size
        let baseAspectRatio = baseSize.width / baseSize.height
        
        print("DEBUG: ベース画像 - サイズ: \(baseSize), アスペクト比: \(baseAspectRatio)")
        
        // オーバーレイ画像要素の最大解像度を検出
        var maxOverlaySize = CGSize.zero
        var maxOverlayPixels: CGFloat = 0
        
        for element in overlayElements {
            if let imageElement = element as? ImageElement,
               let originalImage = imageElement.originalImage {
                let elementSize = originalImage.size
                let elementPixels = elementSize.width * elementSize.height
                let elementAspectRatio = elementSize.width / elementSize.height
                
                print("DEBUG: オーバーレイ画像 - サイズ: \(elementSize), アスペクト比: \(elementAspectRatio)")
                
                if elementPixels > maxOverlayPixels {
                    maxOverlaySize = elementSize
                    maxOverlayPixels = elementPixels
                }
            }
        }
        
        // オーバーレイがない場合はベース画像サイズを使用
        if maxOverlaySize == CGSize.zero {
            print("DEBUG: オーバーレイなし - ベースサイズを使用: \(baseSize)")
            return baseSize
        }
        
        let overlayAspectRatio = maxOverlaySize.width / maxOverlaySize.height
        print("DEBUG: 最大オーバーレイ - サイズ: \(maxOverlaySize), アスペクト比: \(overlayAspectRatio)")
        
        // オーバーレイの解像度を優先しつつ、キャンバスのアスペクト比を維持  
        // 注意: baseSizeではなくself.project.canvasSizeを使用（編集時の実際のキャンバス比率）
        let canvasAspectRatio = self.project.canvasSize.width / self.project.canvasSize.height
        
        print("DEBUG: アスペクト比比較 - キャンバス: \(canvasAspectRatio), オーバーレイ: \(overlayAspectRatio)")
        
        // 修正されたアプローチ: キャンバスアスペクト比を維持しつつ高解像度を活用
        print("DEBUG: 🔍 キャンバス比率保持 + 高解像度アプローチを採用")
        print("DEBUG: ベース画像サイズ: \(baseSize)")  
        print("DEBUG: オーバーレイ最大サイズ: \(maxOverlaySize)")
        print("DEBUG: キャンバスサイズ: \(self.project.canvasSize)")
        
        // ステップ1: 最大解像度を決定（ベースとオーバーレイの大きい方）
        let maxPixels = max(baseSize.width * baseSize.height, maxOverlaySize.width * maxOverlaySize.height)
        let targetResolution = sqrt(maxPixels)
        
        // ステップ2: キャンバスのアスペクト比で最適サイズを計算
        let optimalSize = CGSize(
            width: targetResolution * sqrt(canvasAspectRatio),
            height: targetResolution / sqrt(canvasAspectRatio)
        )
        
        print("DEBUG: 目標解像度: \(targetResolution)")
        print("DEBUG: キャンバスアスペクト比適用後サイズ: \(optimalSize)")
        
        print("DEBUG: 🎯 最終決定サイズ: \(optimalSize)")
        print("DEBUG: 最終アスペクト比: \(optimalSize.width / optimalSize.height)")
        return optimalSize
    }
    
    /// 縦向き画像用のアスペクト比を考慮した最適な合成サイズを計算
    /// - Parameters:
    ///   - baseImage: ベース画像（縦向き）
    ///   - overlayElements: オーバーレイ要素配列
    /// - Returns: 縦向きに最適化された合成サイズ
    private func calculateOptimalCompositeSizePortrait(baseImage: UIImage, overlayElements: [LogoElement]) -> CGSize {
        let baseSize = baseImage.size
        let baseAspectRatio = baseSize.width / baseSize.height  // 縦向きの場合 < 1.0
        
        print("DEBUG: 縦向きベース画像 - サイズ: \(baseSize), アスペクト比: \(baseAspectRatio)")
        
        // オーバーレイ画像要素の最大解像度を検出（横向き関数と同じロジック）
        var maxOverlaySize = CGSize.zero
        var maxOverlayPixels: CGFloat = 0
        
        for element in overlayElements {
            if let imageElement = element as? ImageElement,
               let originalImage = imageElement.originalImage {
                let elementSize = originalImage.size
                let elementPixels = elementSize.width * elementSize.height
                let elementAspectRatio = elementSize.width / elementSize.height
                
                print("DEBUG: 縦向きオーバーレイ画像 - サイズ: \(elementSize), アスペクト比: \(elementAspectRatio)")
                
                if elementPixels > maxOverlayPixels {
                    maxOverlaySize = elementSize
                    maxOverlayPixels = elementPixels
                }
            }
        }
        
        // オーバーレイがない場合はベース画像サイズを使用
        if maxOverlaySize == CGSize.zero {
            print("DEBUG: 縦向きオーバーレイなし - ベースサイズを使用: \(baseSize)")
            return baseSize
        }
        
        let overlayAspectRatio = maxOverlaySize.width / maxOverlaySize.height
        print("DEBUG: 縦向き最大オーバーレイ - サイズ: \(maxOverlaySize), アスペクト比: \(overlayAspectRatio)")
        
        // 縦向き専用: キャンバスのアスペクト比を取得（< 1.0 を前提）
        let canvasAspectRatio = self.project.canvasSize.width / self.project.canvasSize.height
        
        print("DEBUG: 縦向きアスペクト比比較 - キャンバス: \(canvasAspectRatio), オーバーレイ: \(overlayAspectRatio)")
        print("DEBUG: 🔍 縦向き専用アプローチを採用（canvasAspectRatio < 1.0 前提）")
        print("DEBUG: 縦向きベース画像サイズ: \(baseSize)")
        print("DEBUG: 縦向きオーバーレイ最大サイズ: \(maxOverlaySize)")
        print("DEBUG: 縦向きキャンバスサイズ: \(self.project.canvasSize)")
        
        // ステップ1: 縦向きでは愚直にオーバーレイ元解像度を強制適用
        print("DEBUG: 🎯 縦向き専用アプローチ - オーバーレイ元解像度を強制適用")
        print("DEBUG: ベース画像解像度: \(baseSize.width * baseSize.height)")
        print("DEBUG: 最大オーバーレイ解像度: \(maxOverlaySize.width * maxOverlaySize.height)")
        
        // アスペクト比不一致チェック付きでオーバーレイ解像度を適用
        let optimalSize: CGSize
        if maxOverlaySize != CGSize.zero {
            let baseAspectRatio = baseSize.width / baseSize.height      // 縦向きベース: < 1.0
            let overlayAspectRatio = maxOverlaySize.width / maxOverlaySize.height  // オーバーレイのアスペクト比
            
            print("DEBUG: アスペクト比チェック - ベース: \(baseAspectRatio), オーバーレイ: \(overlayAspectRatio)")
            
            // 縦向きベース + 横向きオーバーレイの不一致パターンを検出
            if baseAspectRatio < 1.0 && overlayAspectRatio > 1.0 {
                print("DEBUG: 🔄 アスペクト比不一致検出（縦向きベース + 横向きオーバーレイ）")
                print("DEBUG: ベースのアスペクト比を保持してオーバーレイ解像度を適用")
                
                // オーバーレイの解像度を使いつつ、ベースのアスペクト比を保持
                let overlayPixels = maxOverlaySize.width * maxOverlaySize.height
                let targetResolution = sqrt(overlayPixels)
                
                optimalSize = CGSize(
                    width: targetResolution * sqrt(baseAspectRatio),   // ベースのアスペクト比を保持
                    height: targetResolution / sqrt(baseAspectRatio)
                )
                print("DEBUG: ✅ アスペクト比調整済みサイズ: \(optimalSize)")
                print("DEBUG: 調整後アスペクト比: \(optimalSize.width / optimalSize.height) (ベースと一致: \(abs((optimalSize.width / optimalSize.height) - baseAspectRatio) < 0.01))")
            } else {
                // アスペクト比が一致または他のパターンの場合は従来通り
                optimalSize = maxOverlaySize
                print("DEBUG: ✅ オーバーレイ元解像度を直接適用: \(optimalSize)")
            }
        } else {
            optimalSize = baseSize
            print("DEBUG: ⚠️ オーバーレイなし - ベースサイズにフォールバック: \(optimalSize)")
        }
        
        print("DEBUG: 🎯 縦向き最終決定サイズ: \(optimalSize)")
        print("DEBUG: 縦向き最終アスペクト比: \(optimalSize.width / optimalSize.height)")
        return optimalSize
    }
    
    // MARK: - baseImageが横向き画像用の合成保存処理
    
    /// 画像要素をベースにテキスト・図形要素を重ねた統合画像を作成
    /// 核心アルゴリズム: ====baseImageが横向き画像に対する合成保存処理====     キャンバス座標系から高解像度画像座標系への変換と要素描画
    /// - Parameters:
    ///   - baseImage: ベースとなるフィルター適用済み画像
    ///   - overlayElements: 重ね合わせるテキスト・図形要素の配列
    /// - Returns: 統合された画像、失敗時はnil
    private func createCompositeImage(baseImage: UIImage, overlayElements: [LogoElement]) -> UIImage? {
        print("DEBUG: createCompositeImage開始 - ベース画像サイズ: \(baseImage.size)")
        print("DEBUG: オーバーレイ要素数: \(overlayElements.count)")
        
        // 最小解像度チェックを追加（低解像度画像での座標変換エラーを防ぐ）
        let minWidth: CGFloat = 700
        let minHeight: CGFloat = 400
        
        if baseImage.size.width < minWidth || baseImage.size.height < minHeight {
            print("DEBUG: 画像解像度が低すぎるため処理をスキップ（\(baseImage.size) < \(minWidth)x\(minHeight)）")
            print("DEBUG: 低解像度画像では座標変換で精度誤差が発生するため、ベース画像をそのまま返します")
            return baseImage
        }
        
        // プロジェクト内から今回保存する画像要素を特定
        // 必要な理由: オーバーレイ要素の座標変換に画像要素のキャンバス上での位置・サイズが必要
        print("DEBUG: ========== 画像要素特定開始 ==========")
        print("DEBUG: ベース画像サイズ: \(baseImage.size)")
        print("DEBUG: プロジェクト内の全画像要素:")
        
        for (index, element) in project.elements.enumerated() {
            if let imageElement = element as? ImageElement {
                let originalSize = imageElement.originalImage?.size ?? .zero
                let processedSize = imageElement.image?.size ?? .zero
                print("  [\(index)] ID: \(imageElement.id.uuidString.prefix(8))")
                print("      位置: \(imageElement.position), サイズ: \(imageElement.size)")
                print("      オリジナル画像: \(originalSize)")
                print("      処理後画像: \(processedSize)")
                print("      表示状態: \(imageElement.isVisible ? "表示" : "非表示")")
            }
        }
        
        guard let targetImageElement = self.project.elements.first(where: { element in
            if let imageElement = element as? ImageElement,
               let originalImage = imageElement.originalImage {
                let originalMatch = originalImage.size == baseImage.size
                let processedMatch = imageElement.image?.size == baseImage.size
                print("DEBUG: 画像要素候補 ID: \(imageElement.id.uuidString.prefix(8))")
                print("  - オリジナル: \(originalImage.size) vs ベース: \(baseImage.size) = \(originalMatch ? "一致" : "不一致")")
                print("  - 処理後: \(imageElement.image?.size ?? .zero) vs ベース: \(baseImage.size) = \(processedMatch ? "一致" : "不一致")")
                return originalMatch || processedMatch
            }
            return false
        }) as? ImageElement else {
            // 対応する画像要素が見つからない場合はデバッグ情報を出力してベース画像をそのまま返す
            print("DEBUG: ❌ 対象の画像要素が見つかりません！")
            print("DEBUG: ベース画像と一致するサイズの画像要素が存在しない可能性があります")
            print("DEBUG: =========================================")
            return baseImage
        }
        
        // 特定された画像要素の詳細情報を出力
        print("DEBUG: ✅ 対象画像要素が特定されました！")
        print("DEBUG: 特定された画像要素 ID: \(targetImageElement.id.uuidString.prefix(8))")
        print("DEBUG: キャンバス上の位置: \(targetImageElement.position)")
        print("DEBUG: キャンバス上のサイズ: \(targetImageElement.size)")
        print("DEBUG: =========================================")
        
        // アスペクト比を考慮した最適な合成サイズを計算
        let optimalSize = calculateOptimalCompositeSize(baseImage: baseImage, overlayElements: overlayElements)
        
        // 高解像度画像と同サイズの描画コンテキストを作成
        let imageSize = optimalSize
        print("DEBUG: 最終決定サイズ - ベース: \(baseImage.size), 合成: \(imageSize)")
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // スケール統一（デバイススケールに依存しない）
        format.opaque = true  // 写真保存のため透明度なしで最適化
        
        // UIGraphicsImageRenderer: iOS 10+の現代的な画像描画API
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        
        // ステップ1: キャンバス上での画像要素の境界矩形を取得
        // これが座標変換の基準となる領域（編集ビューでの画像の表示領域）
        let imageElementRect = CGRect(
            x: targetImageElement.position.x,
            y: targetImageElement.position.y,
            width: targetImageElement.size.width,
            height: targetImageElement.size.height
        )
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // ステップ2: ベース画像を編集時の位置・サイズ比率で描画
            // キャンバス内での画像要素の位置を保存画像内に再現
            
            print("DEBUG: 🖼️ ベース画像描画計算開始")
            print("DEBUG: imageElementRect: \(imageElementRect)")
            print("DEBUG: imageSize: \(imageSize)")
            print("DEBUG: baseImage.size: \(baseImage.size)")
            
            // 🎯 修正: 画像要素範囲内のみを描画対象にする座標変換
            // ベース画像を保存画像全体に描画（白いエリアを除去）
            let baseRect = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
            
            print("DEBUG: 🎯 ベース画像描画位置: \(baseRect)")
            print("DEBUG: ベース画像は保存画像全体に描画（白エリア除去）")
            
            baseImage.draw(in: baseRect)
            
            print("DEBUG: 画像要素の範囲: \(imageElementRect)")
            print("DEBUG: 保存画像サイズ: \(imageSize)")
            
            // ステップ3: 画像要素範囲を基準とした座標変換比率を計算
            // 画像要素の範囲内でのみ座標変換（白いエリア除去）
            let scaleX = imageSize.width / imageElementRect.width   // X軸方向の拡大率
            let scaleY = imageSize.height / imageElementRect.height // Y軸方向の拡大率
            
            print("DEBUG: 📐 座標変換比率計算")
            print("DEBUG: 変換比率 - scaleX: \(scaleX), scaleY: \(scaleY)")
            print("DEBUG: 保存サイズ: \(imageSize), キャンバスサイズ: \(self.project.canvasSize)")
            print("DEBUG: scaleX == scaleY: \(abs(scaleX - scaleY) < 0.001)")  // 等比率かチェック
            
            // ステップ4: オーバーレイ要素をZ-Index順で描画（手前から奥の順番を維持）
            let sortedElements = overlayElements.sorted { $0.zIndex < $1.zIndex }
            
            for element in sortedElements {
                // 要素の境界矩形を取得（キャンバス座標系）
                let elementRect = CGRect(x: element.position.x, y: element.position.y, width: element.size.width, height: element.size.height)
                
                // 画像領域との交差判定（画像範囲外の要素はスキップ）
                // intersects: 2つの矩形が重なっているかを判定
                // 低解像度画像での座標変換エラーを防ぐため、判定にマージンを追加
                let marginSize: CGFloat = 10.0
                let expandedImageRect = imageElementRect.insetBy(dx: -marginSize, dy: -marginSize)
                
                guard expandedImageRect.intersects(elementRect) else {
                    print("DEBUG: 要素 \(element.type) は画像範囲外のためスキップ - 要素位置: \(elementRect)")
                    print("DEBUG: 拡張された画像範囲: \(expandedImageRect)")
                    continue
                }
                
                // ステップ5: キャンバス座標を保存画像座標に直接変換
                print("DEBUG: ⚡ 座標変換計算開始 ⚡")
                print("DEBUG: 要素タイプ: \(element.type)")
                print("DEBUG: 元要素位置: \(element.position)")
                print("DEBUG: 元要素サイズ: \(element.size)")
                print("DEBUG: キャンバスサイズ: \(self.project.canvasSize)")
                
                // 🎯 修正: 画像要素範囲内での相対座標に変換
                let relativeX = element.position.x - imageElementRect.minX
                let relativeY = element.position.y - imageElementRect.minY
                
                let actualX = relativeX * scaleX
                let actualY = relativeY * scaleY
                let actualWidth = element.size.width * scaleX
                let actualHeight = element.size.height * scaleY
                
                print("DEBUG: 🔄 座標変換結果:")
                print("  相対X: \(relativeX) * \(scaleX) = \(actualX)")
                print("  相対Y: \(relativeY) * \(scaleY) = \(actualY)")  
                print("  W: \(element.size.width) * \(scaleX) = \(actualWidth)")
                print("  H: \(element.size.height) * \(scaleY) = \(actualHeight)")
                
                // 元の位置との比較（ゼロ除算回避）
                if element.position.x != 0 && element.position.y != 0 {
                    let scaleXRatio = actualX / element.position.x
                    let scaleYRatio = actualY / element.position.y
                    print("DEBUG: 🔍 実際のスケール比率チェック:")
                    print("  X軸実測値: \(scaleXRatio), 期待値: \(scaleX)")
                    print("  Y軸実測値: \(scaleYRatio), 期待値: \(scaleY)")
                } else {
                    print("DEBUG: 🔍 元位置が0のためスケール比率計算をスキップ")
                }
                
                print("DEBUG: ========== 要素 \(element.type) (ID: \(element.id)) ==========")
                print("  - キャンバス位置: \(element.position), サイズ: \(element.size)")
                print("  - 画像範囲との交差: \(imageElementRect.intersects(elementRect))")
                print("  - 保存位置: (\(actualX), \(actualY)), 保存サイズ: (\(actualWidth), \(actualHeight))")
                
                // サイズ妥当性チェック（ゼロ以下のサイズは描画不可能）
                guard actualWidth > 0 && actualHeight > 0 else {
                    print("DEBUG: 無効なサイズのためスキップ")
                    continue
                }
                
                // ステップ7: 要素のディープコピーを作成し高解像度用に調整
                // 元の要素を変更せずに新しいインスタンスで描画用パラメータを設定
                let adjustedElement = element.copy()
                adjustedElement.position = CGPoint(x: actualX, y: actualY)
                adjustedElement.size = CGSize(width: actualWidth, height: actualHeight)
                
                // ステップ8a: 画像要素の特別処理（高解像度直接描画）
                if let imageElement = adjustedElement as? ImageElement {
                    // AI背景除去等の処理で解像度が低下した場合の対策
                    // 合成保存時は必ず高解像度の原画からフィルターを再適用
                    if let originalImage = imageElement.originalImage {
                        let currentImageSize = imageElement.image?.size ?? .zero
                        print("DEBUG: 画像要素の高解像度再処理 - 原画: \(originalImage.size) -> 現在: \(currentImageSize)")
                        
                        // 原画からフィルターを再適用（AI背景除去も含めて）
                        if let highResProcessedImage = imageElement.getFilteredImageForce() {
                            print("DEBUG: 高解像度再処理完了 - サイズ: \(highResProcessedImage.size)")
                            
                            // 高解像度画像を直接描画（ImageElement.drawのロジックを再現）
                            self.drawHighResolutionImageElement(
                                image: highResProcessedImage,
                                element: imageElement,
                                adjustedElement: adjustedElement,
                                in: cgContext
                            )
                            
                            print("DEBUG: ========== 高解像度画像要素描画完了 ==========\n")
                            continue
                        }
                    }
                }
                
                // ステップ8b: テキスト要素の特別処理（フォントサイズ・エフェクトのスケーリング）
                if let textElement = adjustedElement as? TextElement {
                    let originalFontSize = textElement.fontSize
                    // フォントサイズのスケーリング（縦横比の小さい方を使用してアスペクト比を維持）
                    let scaledFontSize = originalFontSize * min(scaleX, scaleY)
                    textElement.fontSize = scaledFontSize
                    
                    // テキストエフェクト（シャドウ等）のスケーリング処理
                    for effect in textElement.effects {
                        if let shadowEffect = effect as? ShadowEffect {
                            let originalOffset = shadowEffect.offset
                            let originalBlurRadius = shadowEffect.blurRadius
                            
                            // シャドウオフセットを軸別にスケーリング（方向性を維持）
                            shadowEffect.offset = CGSize(
                                width: originalOffset.width * scaleX,
                                height: originalOffset.height * scaleY
                            )
                            // ぼかし半径は等比例スケーリング（視覚的なバランス維持）
                            shadowEffect.blurRadius = originalBlurRadius * min(scaleX, scaleY)
                            
                            print("DEBUG: シャドウエフェクトをスケーリング:")
                            print("  - オフセット: \(originalOffset) -> \(shadowEffect.offset)")
                            print("  - ぼかし半径: \(originalBlurRadius) -> \(shadowEffect.blurRadius)")
                        }
                    }
                    
                    print("DEBUG: テキスト要素詳細:")
                    print("  - テキスト内容: '\(textElement.text)'")
                    print("  - 元フォントサイズ: \(originalFontSize) -> スケール後: \(scaledFontSize)")
                    print("  - フォント名: \(textElement.fontName)")
                    print("  - テキスト色: \(textElement.textColor)")
                    print("  - エフェクト数: \(textElement.effects.count)")
                }
                
                // ステップ9: Core Graphicsコンテキストに要素を描画
                print("DEBUG: 描画実行 - 調整後位置: \(adjustedElement.position), サイズ: \(adjustedElement.size)")
                print("DEBUG: 描画コンテキストサイズ: \(imageSize)")
                
                // 各要素のdraw(in:)メソッドを呼び出してCGContextに描画
                // TextElement: NSAttributedStringを使用した高品質テキスト描画
                // ShapeElement: UIBezierPathを使用したベクター図形描画
                adjustedElement.draw(in: cgContext)
                print("DEBUG: ========== 要素描画完了 ==========\n")
            }
        }
    }
    
    // MARK: - baseImageが縦向き用の合成保存処理
    
    /// 縦向き画像要素をベースにテキスト・図形要素を重ねた統合画像を作成
    /// - Parameters:
    ///   - baseImage: ベース画像（縦向き、フィルター適用済み）
    ///   - overlayElements: 重ねる要素配列（テキスト・図形）
    /// - Returns: 統合された画像、失敗時はnil
    private func createCompositeImagePortrait(baseImage: UIImage, overlayElements: [LogoElement]) -> UIImage? {
        print("DEBUG: createCompositeImagePortrait開始 - ベース画像サイズ: \(baseImage.size)")
        print("DEBUG: オーバーレイ要素数: \(overlayElements.count)")
        
        // STEP 1: 対象画像要素の特定（横向き実装を流用）
        guard let targetImageElement = self.project.elements.first(where: { element in
            if let imageElement = element as? ImageElement,
               let originalImage = imageElement.originalImage {
                let originalMatch = originalImage.size == baseImage.size
                let processedMatch = imageElement.image?.size == baseImage.size
                print("DEBUG: 縦向き画像要素候補 ID: \(imageElement.id.uuidString.prefix(8))")
                print("  - オリジナル: \(originalImage.size) vs ベース: \(baseImage.size) = \(originalMatch ? "一致" : "不一致")")
                print("  - 処理後: \(imageElement.image?.size ?? .zero) vs ベース: \(baseImage.size) = \(processedMatch ? "一致" : "不一致")")
                return originalMatch || processedMatch
            }
            return false
        }) as? ImageElement else {
            print("DEBUG: ❌ 縦向き対象画像要素が見つかりません！")
            return baseImage
        }
        
        print("DEBUG: ✅ 縦向き対象画像要素が特定されました！")
        print("DEBUG: 特定された画像要素 ID: \(targetImageElement.id.uuidString.prefix(8))")
        print("DEBUG: キャンバス上の位置: \(targetImageElement.position)")
        print("DEBUG: キャンバス上のサイズ: \(targetImageElement.size)")
        
        // STEP 2: 縦向き専用最適化関数を使用してオーバーレイ元解像度を保持
        
        let optimalSize = calculateOptimalCompositeSizePortrait(baseImage: baseImage, overlayElements: overlayElements)
        let imageSize = optimalSize
        print("DEBUG: 縦向き最適化サイズ適用 - オーバーレイ元解像度保持: \(imageSize)")
        
        // STEP 3: 描画コンテキストの設定（横向き実装と同一）
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // スケール統一（デバイススケールに依存しない）
        format.opaque = true  // 写真保存のため透明度なしで最適化
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        print("DEBUG: 縦向きレンダラー設定完了 - 描画サイズ: \(imageSize)")
        
        // キャンバス上での画像要素の境界矩形を取得
        let imageElementRect = CGRect(
            x: targetImageElement.position.x,
            y: targetImageElement.position.y,
            width: targetImageElement.size.width,
            height: targetImageElement.size.height
        )
        
        // STEP 3: 縦向き専用統合描画実行
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // STEP 3.1: ベース画像の描画（最下層）- 横向き処理と同じ方式に統一
            let baseRect = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
            
            print("DEBUG: 🖼️ 縦向きベース画像描画計算開始")
            print("DEBUG: 縦向き保存画像サイズ: \(imageSize)")
            print("DEBUG: 縦向きベース画像サイズ: \(baseImage.size)")
            print("DEBUG: 🎯 縦向きベース画像描画位置: \(baseRect)")
            
            baseImage.draw(in: baseRect)
            print("DEBUG: 縦向きベース画像描画完了")
            
            // STEP 3.2: 縦向き画像専用座標変換パラメータの計算
            // キャンバスが横向き設定でも縦向き画像の実際のアスペクト比で計算
            
            let imageElementRect = CGRect(
                x: targetImageElement.position.x,
                y: targetImageElement.position.y,
                width: targetImageElement.size.width,
                height: targetImageElement.size.height
            )
            
            print("DEBUG: 縦向き画像要素の範囲: \(imageElementRect)")
            
            // 縦向き専用スケール比率の計算
            // キャンバス上で横に引き伸ばされた表示を補正
            let scaleX = imageSize.width / imageElementRect.width
            let scaleY = imageSize.height / imageElementRect.height
            
            // 縦向き画像の場合、キャンバス表示での歪みを補正
            let aspectRatioCanvas = imageElementRect.width / imageElementRect.height  // キャンバス上のアスペクト比（横に引き伸ばされた状態）
            let aspectRatioActual = imageSize.width / imageSize.height              // 実際の画像のアスペクト比（縦向き）
            let aspectCorrectionFactor = aspectRatioCanvas / aspectRatioActual      // 補正係数（逆算）
            
            print("DEBUG: 縦向き変換比率 - scaleX: \(scaleX), scaleY: \(scaleY)")
            print("DEBUG: アスペクト比補正 - キャンバス: \(aspectRatioCanvas), 実際: \(aspectRatioActual), 補正係数: \(aspectCorrectionFactor)")
            
            // STEP 3.3: オーバーレイ要素の描画処理
            let sortedElements = overlayElements.sorted { $0.zIndex < $1.zIndex }
            print("DEBUG: 縦向きZ-Index順ソート完了 - 要素数: \(sortedElements.count)")
            
            for element in sortedElements {
                print("DEBUG: ========== 縦向き要素 \(element.type) (ID: \(element.id)) ==========")
                
                // STEP 3.3.1: 境界検査
                let elementRect = CGRect(x: element.position.x, y: element.position.y, width: element.size.width, height: element.size.height)
                
                guard imageElementRect.intersects(elementRect) else {
                    print("DEBUG: 縦向き要素 \(element.type) は画像範囲外のためスキップ")
                    continue
                }
                
                // STEP 3.3.2: 縦向き専用相対座標の計算
                // アスペクト比補正を適用した座標変換
                let relativeX = (element.position.x - imageElementRect.minX) / imageElementRect.width
                let relativeY = (element.position.y - imageElementRect.minY) / imageElementRect.height
                let relativeWidth = element.size.width / imageElementRect.width * aspectCorrectionFactor  // X軸補正適用
                let relativeHeight = element.size.height / imageElementRect.height
                
                print("DEBUG: 縦向き相対座標計算:")
                print("  - 相対位置: (\(relativeX), \(relativeY))")
                print("  - 相対サイズ（補正後）: (\(relativeWidth), \(relativeHeight))")
                
                // STEP 3.3.3: 縦向き画像での実座標への変換
                let actualX = relativeX * imageSize.width
                let actualY = relativeY * imageSize.height
                let actualWidth = relativeWidth * imageSize.width
                let actualHeight = relativeHeight * imageSize.height
                
                print("DEBUG: 縦向き実座標変換:")
                print("  - 保存位置: (\(actualX), \(actualY))")
                print("  - 保存サイズ: (\(actualWidth), \(actualHeight))")
                
                // STEP 3.3.4: サイズ妥当性チェック
                guard actualWidth > 0 && actualHeight > 0 else {
                    print("DEBUG: 縦向き無効サイズのためスキップ")
                    continue
                }
                
                // STEP 3.3.5: 要素のコピーと調整
                let adjustedElement = element.copy()
                adjustedElement.position = CGPoint(x: actualX, y: actualY)
                adjustedElement.size = CGSize(width: actualWidth, height: actualHeight)
                
                // STEP 3.3.6a: 画像要素の特別処理（高解像度直接描画）- 横向き実証済みコード流用
                if let imageElement = adjustedElement as? ImageElement {
                    // AI背景除去等の処理で解像度が低下した場合の対策
                    // 合成保存時は必ず高解像度の原画からフィルターを再適用
                    if let originalImage = imageElement.originalImage {
                        let currentImageSize = imageElement.image?.size ?? .zero
                        print("DEBUG: 画像要素の高解像度再処理 - 原画: \(originalImage.size) -> 現在: \(currentImageSize)")
                        
                        // 原画からフィルターを再適用（AI背景除去も含めて）
                        if let highResProcessedImage = imageElement.getFilteredImageForce() {
                            print("DEBUG: 高解像度再処理完了 - サイズ: \(highResProcessedImage.size)")
                            
                            // 高解像度画像を直接描画（ImageElement.drawのロジックを再現）
                            self.drawHighResolutionImageElement(
                                image: highResProcessedImage,
                                element: imageElement,
                                adjustedElement: adjustedElement,
                                in: cgContext
                            )
                            
                            print("DEBUG: ========== 高解像度画像要素描画完了 ==========\n")
                            continue
                        }
                    }
                }
                
                // STEP 3.3.6b: 縦向き画像でのテキスト要素専用処理
                if let textElement = adjustedElement as? TextElement {
                    print("DEBUG: 縦向きテキスト要素専用処理開始")
                    
                    // 縦向き画像でのフォントサイズスケーリング
                    let originalFontSize = textElement.fontSize
                    let scaledFontSize = originalFontSize * min(scaleX, scaleY) * aspectCorrectionFactor
                    textElement.fontSize = scaledFontSize
                    
                    print("DEBUG: 縦向きフォントサイズ調整:")
                    print("  - 元サイズ: \(originalFontSize)pt -> 補正後: \(scaledFontSize)pt")
                    
                    // 縦向き画像でのシャドウエフェクト調整
                    for effect in textElement.effects {
                        if let shadowEffect = effect as? ShadowEffect {
                            let originalOffset = shadowEffect.offset
                            shadowEffect.offset = CGSize(
                                width: originalOffset.width * scaleX * aspectCorrectionFactor,  // X軸にアスペクト比補正適用
                                height: originalOffset.height * scaleY
                            )
                            
                            let originalBlurRadius = shadowEffect.blurRadius
                            shadowEffect.blurRadius = originalBlurRadius * min(scaleX, scaleY) * aspectCorrectionFactor
                            
                            print("DEBUG: 縦向きシャドウパラメータ調整:")
                            print("  - オフセット: \(originalOffset) -> \(shadowEffect.offset)")
                            print("  - ぼかし半径: \(originalBlurRadius) -> \(shadowEffect.blurRadius)")
                        }
                    }
                }
                
                // STEP 3.3.7: 縦向き画像での描画実行
                print("DEBUG: 縦向き描画実行 - 調整後位置: \(adjustedElement.position), サイズ: \(adjustedElement.size)")
                adjustedElement.draw(in: cgContext)
                
                print("DEBUG: ========== 縦向き要素描画完了 ==========\n")
            }
            
            print("DEBUG: 縦向き全要素描画完了 - 統合画像生成成功")
        }
    }
    
    // MARK: - インポート
    
    /// 画像のクロップ後にImageElementを追加
    func addCroppedImageElement(image: UIImage) {
        // UIImageをDataに変換
        guard let imageData = image.pngData() else { return }
        
        // 現在の画像要素数を数えてインポート順番を決定
        let currentImageCount = project.elements.compactMap { $0 as? ImageElement }.count
        let importOrder = currentImageCount + 1
        
        let imageElement = ImageElement(imageData: imageData, fitMode: .aspectFit, canvasSize: project.canvasSize, importOrder: importOrder)
        
        // 役割に応じてzIndexを設定
        if imageElement.imageRole == .base {
            // ベース画像（1番目）は背面に配置
            imageElement.zIndex = ElementPriority.image.rawValue - 10
        } else {
            // オーバーレイ画像は前面に配置
            imageElement.zIndex = ElementPriority.image.rawValue + 10
        }
        
        // ビューポートの中央に配置
        let viewportSize = getViewportSize()
        let viewportCenter = CGPoint(
            x: viewportSize.width / 2,
            y: viewportSize.height / 4
        )
        
        // 画像の中央位置を計算
        imageElement.position = CGPoint(
            x: viewportCenter.x - imageElement.size.width / 2,
            y: viewportCenter.y - imageElement.size.height / 2
        )
        
        print("DEBUG: クロップ済み画像配置位置 - X: \(imageElement.position.x), Y: \(imageElement.position.y)")
        
        // 要素を追加
        addElement(imageElement)
        selectElement(imageElement)
        
        // 画像が見えるようにカメラを移動
        centerViewOnElement(imageElement)
    }
    
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
