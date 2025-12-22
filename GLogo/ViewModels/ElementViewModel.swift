//
//  ElementViewModel.swift
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
import Combine

/// 要素編集ビューモデル - 選択された要素の編集機能を提供
@MainActor
class ElementViewModel: ObservableObject {
    // MARK: - プロパティ
    
    /// エディタビューモデルへの弱参照 - 循環参照を防ぐため弱参照で保持。
    /// ElementViewModel　は　EditorViewによって所有され、EditorViewModelとは参照のみの関係を持つ。
    /// この設計により、EditorViewModelが解放されたときに自動的にnilになる。
    private weak var editorViewModel: EditorViewModel?
    
    /// 現在編集中の要素
    @Published private(set) var element: LogoElement?
    
    /// 要素の種類
    @Published private(set) var elementType: LogoElementType?
    
    /// 型変換済みの参照 - LogoElement型から適切なサブクラス型へ一度だけ変換しておくことで、
    /// 元の型を失わずに特定の要素タイプ固有のプロパティやメソッドに直接アクセスできる
    /// これによりビューコードでの毎回の型チェックや変換処理が不要になる
    @Published private(set) var textElement: TextElement?
    
    /// 図形要素（キャスト済み）
    @Published private(set) var shapeElement: ShapeElement?
    
    /// 画像要素（キャスト済み）
    @Published private(set) var imageElement: ImageElement?

    /// 購読の保持
    private var cancellables = Set<AnyCancellable>()

    /// 最新のみ実行するレンダリングスケジューラ
    private let renderScheduler = RenderScheduler()

    /// ジェスチャー変形用の基準値
    private var gestureBasePosition: CGPoint?
    private var gestureBaseSize: CGSize?
    private var gestureBaseRotation: CGFloat?
    
    // MARK: - イニシャライザ
    
    init(editorViewModel: EditorViewModel) {
        self.editorViewModel = editorViewModel
        
        // エディタの選択要素の変更を監視
        editorViewModel.$selectedElement
            .receive(on: RunLoop.main)
            .sink { [weak self] selectedElement in
                self?.updateElement(selectedElement)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - メソッド
    
    /// 要素の更新
    private func updateElement(_ element: LogoElement?) {
        self.element = element
        
        // 要素の種類に基づいて適切な要素にキャスト
        if let textElement = element as? TextElement {
            self.elementType = .text
            self.textElement = textElement
            self.shapeElement = nil
            self.imageElement = nil
        } else if let shapeElement = element as? ShapeElement {
            self.elementType = .shape
            self.textElement = nil
            self.shapeElement = shapeElement
            self.imageElement = nil
        } else if let imageElement = element as? ImageElement {
            self.elementType = .image
            self.textElement = nil
            self.shapeElement = nil
            self.imageElement = imageElement
        } else {
            self.elementType = nil
            self.textElement = nil
            self.shapeElement = nil
            self.imageElement = nil
        }
    }
    
    // MARK: - 共通プロパティの更新
    
    /// 位置の更新
    func updatePosition(_ position: CGPoint) {
        guard let element = element else { return }
        element.position = position
        
        updateElement(to: element)
    }
    
    /// サイズの更新
    func updateSize(_ size: CGSize) {
        guard let element = element else { return }
        element.size = size
        
        updateElement(to: element)
    }
    
    /// 回転の更新
    func updateRotation(_ rotation: CGFloat) {
        guard let element = element else { return }
        element.rotation = rotation
        
        updateElement(to: element)
    }

    /// ジェスチャーによる変形（移動・拡大縮小・回転）
    func applyGestureTransform(translation: CGSize?, scale: CGFloat?, rotation: CGFloat?, ended: Bool) {
        guard let element = element else { return }

        // 基準値を保持（ジェスチャー開始時のみ）
        if gestureBasePosition == nil { gestureBasePosition = element.position }
        if gestureBaseSize == nil { gestureBaseSize = element.size }
        if gestureBaseRotation == nil { gestureBaseRotation = element.rotation }

        if let basePos = gestureBasePosition, let delta = translation {
            element.position = CGPoint(x: basePos.x + delta.width, y: basePos.y + delta.height)
        }

        if let baseSize = gestureBaseSize, let scale = scale {
            let clampedScale = max(scale, 0.01) // 極端な縮小を防止
            element.size = CGSize(width: baseSize.width * clampedScale, height: baseSize.height * clampedScale)
        }

        if let baseRot = gestureBaseRotation, let deltaRot = rotation {
            element.rotation = baseRot + deltaRot
        }

        updateElement(to: element)

        if ended {
            gestureBasePosition = nil
            gestureBaseSize = nil
            gestureBaseRotation = nil
            editorViewModel?.markProjectModified()
        }
    }

    
    /// 不透明度の更新
    func updateOpacity(_ opacity: CGFloat) {
        guard let element = element else { return }
        element.opacity = opacity
        
        updateElement(to: element)
    }
    
    /// 名前の更新
    func updateName(_ name: String) {
        guard let element = element else { return }
        element.name = name
        
        updateElement(to: element)
    }
    
    /// 可視性の更新
    func updateVisibility(_ isVisible: Bool) {
        guard let element = element else { return }
        element.isVisible = isVisible
        
        updateElement(to: element)
    }
    
    /// ロック状態の更新
    func updateLock(_ isLocked: Bool) {
        guard let element = element else { return }
        element.isLocked = isLocked
        
        updateElement(to: element)
    }

    
    // MARK: - テキスト要素の更新
    
    /// テキスト内容の更新
    func updateText(_ text: String) {
        print("DEBUG: ElementViewModel - テキスト内容更新開始: \(text)")
        guard let textElement = textElement else {
            print("DEBUG: ElementViewModel - textElementがnilのため更新できません")
            return
        }
        
        // 現在と同じテキストなら何もしない
        if textElement.text == text {
            print("DEBUG: ElementViewModel - テキストが同じなので変更をスキップします")
            return
        }
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateTextContent(textElement, newText: text)
        
        print("DEBUG: ElementViewModel - テキスト内容更新完了")
    }
    
    /// フォントの更新
    func updateFont(name: String, size: CGFloat) {
        print("DEBUG: ElementViewModel - フォント更新開始: \(name), サイズ: \(size)")
        guard let textElement = textElement else {
            print("DEBUG: ElementViewModel - textElementがnilのため更新できません")
            return
        }
        
        // 現在と同じフォントとサイズなら何もしない
        if textElement.fontName == name && textElement.fontSize == size {
            print("DEBUG: ElementViewModel - フォントが同じなので変更をスキップします")
            return
        }
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateFont(textElement, fontName: name, fontSize: size)
        
        print("DEBUG: ElementViewModel - フォント更新完了")
    }
    
    /// テキスト色の更新
    func updateTextColor(_ color: UIColor) {
        print("DEBUG: ElementViewModel - テキスト色更新開始: \(color)")
        guard let textElement = textElement else {
            print("DEBUG: ElementViewModel - textElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ色なら何もしない
        if textElement.textColor.isEqual(color) {
            print("DEBUG: ElementViewModel - 色が同じなので変更をスキップします")
            return
        }
        
        editorViewModel?.updateTextColor(textElement, newColor: color)
    }
    
    /// テキスト整列の更新
    func updateTextAlignment(_ alignment: TextAlignment) {
        guard let textElement = textElement else { return }
        textElement.alignment = alignment
        
        updateElement(to: textElement)
    }
    
    /// 行間の更新
    func updateLineSpacing(_ spacing: CGFloat) {
        guard let textElement = textElement else { return }
        textElement.lineSpacing = spacing
        
        updateElement(to: textElement)
    }
    
    /// 文字間隔の更新
    func updateLetterSpacing(_ spacing: CGFloat) {
        guard let textElement = textElement else { return }
        textElement.letterSpacing = spacing
        
        updateElement(to: textElement)
    }
    
    /// テキスト効果の追加
    func addTextEffect(_ effect: TextEffect) {
        guard let textElement = textElement else { return }
        textElement.effects.append(effect)
        
        updateElement(to: textElement)
    }
    
    /// テキスト効果の削除
    func removeTextEffect(atIndex index: Int) {
        guard let textElement = textElement, index < textElement.effects.count else { return }
        textElement.effects.remove(at: index)
        
        updateElement(to: textElement)
    }
    
    /// テキスト効果の更新
    func updateTextEffect(atIndex index: Int, isEnabled: Bool) {
        guard let textElement = textElement, index < textElement.effects.count else { return }
        textElement.effects[index].isEnabled = isEnabled
        
        updateElement(to: textElement)
    }
    
    /// シャドウ効果の更新
    func updateShadowEffect(atIndex index: Int, color: UIColor, offset: CGSize, blurRadius: CGFloat) {
        guard let textElement = textElement, index < textElement.effects.count,
              let shadowEffect = textElement.effects[index] as? ShadowEffect else { return }
        
        shadowEffect.color = color
        shadowEffect.offset = offset
        shadowEffect.blurRadius = blurRadius
        
        updateElement(to: textElement)
    }
    
    // MARK: - 図形要素の更新
    
    /// 図形の種類の更新
    func updateShapeType(_ shapeType: ShapeType) {
        print("DEBUG: ElementViewModel - 図形タイプ更新開始: \(shapeType)")
        guard let shapeElement = shapeElement else {
            print("DEBUG: ElementViewModel - shapeElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ図形タイプなら何もしない
        if shapeElement.shapeType == shapeType {
            print("DEBUG: ElementViewModel - 図形タイプが同じなので変更をスキップします")
            return
        }
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateShapeType(shapeElement, newType: shapeType)
        
        print("DEBUG: ElementViewModel - 図形タイプ更新完了")
    }
    
    /// 塗りつぶしモードの更新
    func updateFillMode(_ fillMode: FillMode) {
        guard let shapeElement = shapeElement else {
            print("DEBUG: ElementViewModel - shapeElementがnilのため更新できません")
            return
        }
        
        // 現在と同じモードなら何もしない
        if shapeElement.fillMode == fillMode {
            print("DEBUG: ElementViewModel - モードが同じなので変更をスキップします")
            return
        }
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateShapeFillMode(shapeElement, newMode: fillMode)
    }
    
    /// 塗りつぶし色の更新
    func updateFillColor(_ color: UIColor) {
        guard let shapeElement = shapeElement else {
            print("DEBUG: ElementViewModel - shapeElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ色なら何もしない
        if shapeElement.fillColor.isEqual(color) {
            print("DEBUG: ElementViewModel - 色が同じなので変更をスキップします")
            return
        }
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateShapeFillColor(shapeElement, newColor: color)
    }
    
    /// グラデーション色の更新
    func updateGradientColors(startColor: UIColor, endColor: UIColor) {
        guard let shapeElement = shapeElement else {
            print("DEBUG: ElementViewModel - shapeElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ色なら何もしない
        if shapeElement.gradientStartColor.isEqual(startColor) && shapeElement.gradientEndColor.isEqual(endColor) {
            print("DEBUG: ElementViewModel - 色が同じなので変更をスキップします")
            return
        }
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateShapeGradientColors(
            shapeElement,
            oldStartColor: shapeElement.gradientStartColor,
            newStartColor: startColor,
            oldEndColor: shapeElement.gradientEndColor,
            newEndColor: endColor
        )
    }
    
    /// グラデーション角度の更新
    func updateGradientAngle(_ angle: CGFloat) {
        guard let shapeElement = shapeElement else {
            print("DEBUG: ElementViewModel - shapeElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ角度なら何もしない
        if shapeElement.gradientAngle == angle {
            print("DEBUG: ElementViewModel - 角度が同じなので変更をスキップします")
            return
        }
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateShapeGradientAngle(shapeElement, newAngle: angle)
    }
    
    /// 枠線モードの更新
    func updateStrokeMode(_ strokeMode: StrokeMode) {
        guard let shapeElement = shapeElement else {
            print("DEBUG: ElementViewModel - shapeElementがnilのため更新できません")
            return
        }
        
        // 現在と同じモードなら何もしない
        if shapeElement.strokeMode == strokeMode {
            print("DEBUG: ElementViewModel - モードが同じなので変更をスキップします")
            return
        }
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateShapeStrokeMode(shapeElement, newMode: strokeMode)
    }
    
    /// 枠線色の更新
    func updateStrokeColor(_ color: UIColor) {
        guard let shapeElement = shapeElement else {
            print("DEBUG: ElementViewModel - shapeElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ色なら何もしない
        if shapeElement.strokeColor.isEqual(color) {
            print("DEBUG: ElementViewModel - 色が同じなので変更をスキップします")
            return
        }
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateShapeStrokeColor(shapeElement, newColor: color)
    }
    
    /// 枠線の太さの更新
    func updateStrokeWidth(_ width: CGFloat) {
        guard let shapeElement = shapeElement else {
            print("DEBUG: ElementViewModel - shapeElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ太さなら何もしない
        if shapeElement.strokeWidth == width {
            print("DEBUG: ElementViewModel - 太さが同じなので変更をスキップします")
            return
        }
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateShapeStrokeWidth(shapeElement, newWidth: width)
    }
    
    /// 角丸の半径の更新
    func updateCornerRadius(_ radius: CGFloat) {
        guard let shapeElement = shapeElement else {
            print("DEBUG: ElementViewModel - shapeElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ半径なら何もしない
        if shapeElement.cornerRadius == radius {
            print("DEBUG: ElementViewModel - 半径が同じなので変更をスキップします")
            return
        }
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateShapeCornerRadius(shapeElement, newRadius: radius)
    }
    
    /// 多角形の辺の数の更新
    func updateSides(_ sides: Int) {
        guard let shapeElement = shapeElement else {
            print("DEBUG: ElementViewModel - shapeElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ辺の数なら何もしない
        if shapeElement.sides == sides {
            print("DEBUG: ElementViewModel - 辺の数が同じなので変更をスキップします")
            return
        }
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateShapeSides(shapeElement, newSides: sides)
    }
    
    /// カスタムポイントの更新
    func updateCustomPoints(_ points: [CGPoint]) {
        guard let shapeElement = shapeElement else { return }
        shapeElement.customPoints = points
        
        updateElement(to: shapeElement)
    }
    
    // MARK: - 画像要素の更新
    
    // fitMode 廃止: フィットモード更新は行わない
    
    /// 彩度調整の更新
    func updateSaturation(_ saturation: CGFloat) {
        print("DEBUG: ElementViewModel - 彩度調整更新開始: \(saturation)")
        guard let imageElement = imageElement else {
            print("DEBUG: ElementViewModel - imageElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ値なら何もしない
        if imageElement.saturationAdjustment == saturation {
            print("DEBUG: ElementViewModel - 彩度が同じなので変更をスキップします")
            return
        }
        
        // 変更前の値を記録（メタデータ編集履歴用）
        let oldValue = imageElement.saturationAdjustment
        
        // 編集開始をマーク
        imageElement.startEditing()
        
        // 即座に値を更新（UI即座反応のため）
        imageElement.saturationAdjustment = saturation
        
        // EditorViewModelの対応するメソッドを呼び出す（イベントソーシング用）
        editorViewModel?.updateImageSaturation(imageElement, newSaturation: saturation)
        
        // メタデータに編集を記録
        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "saturationAdjustment",
                oldValue: oldValue,
                newValue: saturation
            )
        }
    }
    
    /// 明度調整の更新
    func updateBrightness(_ brightness: CGFloat) {
        print("DEBUG: ElementViewModel - 明度調整更新開始: \(brightness)")
        guard let imageElement = imageElement else {
            print("DEBUG: ElementViewModel - imageElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ値なら何もしない
        if imageElement.brightnessAdjustment == brightness {
            print("DEBUG: ElementViewModel - 明度が同じなので変更をスキップします")
            return
        }
        
        let oldvalue = imageElement.brightnessAdjustment
        
        // 編集開始をマーク
        imageElement.startEditing()
        
        // 即座に値を更新（UI即座反応のため）
        imageElement.brightnessAdjustment = brightness
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateImageBrightness(imageElement, newBrightness: brightness)
        
        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "brigthtnessAdjustment",
                oldValue: oldvalue,
                newValue: brightness)
        }
    }
    
    /// コントラスト調整の更新
    func updateContrast(_ contrast: CGFloat) {
        print("DEBUG: ElementViewModel - コントラスト調整更新開始: \(contrast)")
        guard let imageElement = imageElement else {
            print("DEBUG: ElementViewModel - imageElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ値なら何もしない
        if imageElement.contrastAdjustment == contrast {
            print("DEBUG: ElementViewModel - コントラストが同じなので変更をスキップします")
            return
        }
        
        let oldvalue = imageElement.contrastAdjustment
        
        // 編集開始をマーク
        imageElement.startEditing()
        
        // 即座に値を更新（UI即座反応のため）
        imageElement.contrastAdjustment = contrast
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateImageContrast(imageElement, newContrast: contrast)
        
        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "contrastAdjustment",
                oldValue: oldvalue,
                newValue: contrast)
        }
    }
    
    // ハイライト調整の更新
    func updateHighlights(_ highlights: CGFloat) {
        print("DEBUG: ElementViewModel - ハイライト調整更新開始: \(highlights)")
        guard let imageElement = imageElement else {
            print("DEBUG: ElementViewModel - imageElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ値なら何もしない
        if imageElement.highlightsAdjustment == highlights {
            print("DEBUG: ElementViewModel - ハイライトが同じなので変更をスキップします")
            return
        }
        
        let oldvalue = imageElement.highlightsAdjustment
        
        // 編集開始をマーク
        imageElement.startEditing()
        
        // 即座に値を更新（UI即座反応のため）
        imageElement.highlightsAdjustment = highlights
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateImageHighlights(imageElement, newHighlights: highlights)
        
        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "highlightsAdjustment",
                oldValue: oldvalue,
                newValue: highlights)
        }
    }
    
    // シャドウ調整の更新
    func updateShadows(_ shadows: CGFloat) {
        print("DEBUG: ElementViewModel - シャドウ調整更新開始: \(shadows)")
        guard let imageElement = imageElement else {
            print("DEBUG: ElementViewModel - imageElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ値なら何もしない
        if imageElement.shadowsAdjustment == shadows {
            print("DEBUG: ElementViewModel - シャドウが同じなので変更をスキップします")
            return
        }
        
        let oldvalue = imageElement.shadowsAdjustment
        
        // 編集開始をマーク
        imageElement.startEditing()
        
        // 即座に値を更新（UI即座反応のため）
        imageElement.shadowsAdjustment = shadows
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateImageShadows(imageElement, newShadows: shadows)
        
        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "shadowsAdjustment",
                oldValue: oldvalue,
                newValue: shadows)
        }
    }
    
    /// 色相の更新
    func updateHue(_ hue: CGFloat) {
        print("DEBUG: ElementViewModel - 色相更新開始")
        guard let imageElement = imageElement else {
            print("DEBUG: ElementViewModel - imageElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ色相なら何もしない
        if imageElement.hueAdjustment == hue {
            print("DEBUG: ElementViewModel - 色相が同じなので変更をスキップします")
            return
        }
        
        let oldValue = imageElement.hueAdjustment
        
        // 編集開始をマーク
        imageElement.startEditing()
        
        // 即座に値を更新（UI即座反応のため）
        imageElement.hueAdjustment = hue
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateImageHue(imageElement, newHue: hue)
        
        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "hueAdjustment",
                oldValue: oldValue,
                newValue: hue)
        }
    }
    
    /// シャープネスの更新
    func updateSharpness(_ sharpness: CGFloat) {
        print("DEBUG: ElementViewModel - シャープネス更新開始")
        guard let imageElement = imageElement else {
            print("DEBUG: ElementViewModel - imageElementがnilのため更新できません")
            return
        }
        
        // 現在と同じシャープネスなら何もしない
        if imageElement.sharpnessAdjustment == sharpness {
            print("DEBUG: ElementViewModel - シャープネスが同じなので変更をスキップします")
            return
        }
        
        let oldValue = imageElement.sharpnessAdjustment
        
        // 編集開始をマーク
        imageElement.startEditing()
        
        // 即座に値を更新（UI即座反応のため）
        imageElement.sharpnessAdjustment = sharpness
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateImageSharpness(imageElement, newSharpness: sharpness)
        
        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "sharpnessAdjustment",
                oldValue: oldValue,
                newValue: sharpness)
        }
    }
    
    /// ガウシアンブラーの更新
    func updateGaussianBlur(_ radius: CGFloat) {
        print("DEBUG: ElementViewModel - ガウシアンブラー更新開始")
        guard let imageElement = imageElement else {
            print("DEBUG: ElementViewModel - imageElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ半径なら何もしない
        if imageElement.gaussianBlurRadius == radius {
            print("DEBUG: ElementViewModel - ガウシアンブラー半径が同じなので変更をスキップします")
            return
        }

        // 編集開始をマーク
        imageElement.startEditing()

        // 即座に値を更新（UI即座反応のため）
        imageElement.gaussianBlurRadius = radius

        // プレビュー描画を更新（最新のみ実行）
        editorViewModel?.updateImageElement(imageElement)

        renderScheduler.schedule { [weak self] in
            guard let self = self, let imageElement = self.imageElement else { return }

            imageElement.endEditing()
            imageElement.cachedImage = nil
            Task { @MainActor in
                self.editorViewModel?.updateImageElement(imageElement)
            }
        }
        return
    }
    
    /// トーンカーブの更新（プレビュー + 最終品質の2段階処理, RenderSchedulerを利用）
    func updateToneCurveData(_ newData: ToneCurveData) {
        guard let imageElement = imageElement else { return }

        // データを即座に更新
        imageElement.toneCurveData = newData

        // 編集中フラグを立てる（プレビュー品質で処理）
        imageElement.startEditing()

        #if DEBUG
        print("🎨 [ElementViewModel] トーンカーブ更新 - プレビュー処理")
        #endif

        // 即座にキャッシュをクリアして再描画（プレビュー品質）
        imageElement.cachedImage = nil
        editorViewModel?.updateImageElement(imageElement)

        // 新しい最新のみ実行のスケジューラを利用（旧タイマーは不使用）
        renderScheduler.schedule { [weak self] in
            guard let self = self, let imageElement = self.imageElement else { return }

            #if DEBUG
            print("✨ [ElementViewModel] トーンカーブ確定 - 最終品質処理 (RenderScheduler)")
            #endif

            // 編集終了フラグを立てる（最終品質で処理）
            imageElement.endEditing()

            // キャッシュをクリアして最終品質で再描画
            imageElement.cachedImage = nil
            Task { @MainActor in
                self.editorViewModel?.updateImageElement(imageElement)
            }
        }
    }

    /// ティントカラーの更新
    func updateTintColor(_ color: UIColor?, intensity: CGFloat) {
        print("DEBUG: ElementViewModel - ティントカラー更新開始")
        guard let imageElement = imageElement else {
            print("DEBUG: ElementViewModel - imageElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ色および強度なら何もしない
        let colorEqual = (color == nil && imageElement.tintColor == nil) ||
        (color != nil && imageElement.tintColor != nil && imageElement.tintColor!.isEqual(color!))
        let intensityEqual = imageElement.tintIntensity == intensity
        
        if colorEqual && intensityEqual {
            print("DEBUG: ElementViewModel - ティント設定が同じなので変更をスキップします")
            return
        }
        
        let oldColor = imageElement.tintColor
        let oldIntensity = imageElement.tintIntensity
        
        // 編集開始をマーク
        imageElement.startEditing()
        
        // 即座に値を更新（UI即座反応のため）
        imageElement.tintColor = color
        imageElement.tintIntensity = intensity
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateImageTintColor(imageElement, oldColor: oldColor, newColor: color, oldIntensity: oldIntensity, newIntensity: intensity)
        
        // メタデータに編集を記録
        if imageElement.originalImageIdentifier != nil {
            // 色の変更を記録
            imageElement.recordMetadataEdit(
                fieldKey: "tintColor",
                oldValue: oldColor?.description,
                newValue: color?.description
            )
            
            // 強度の変更を記録
            imageElement.recordMetadataEdit(
                fieldKey: "tintIntensity",
                oldValue: oldIntensity,
                newValue: intensity
            )
        }
    }
    
    /// フレーム表示の更新
    func updateShowFrame(_ showFrame: Bool) {
        print("DEBUG: ElementViewModel - フレーム表示更新開始: \(showFrame)")
        guard let imageElement = imageElement else {
            print("DEBUG: ElementViewModel - imageElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ設定なら何もしない
        if imageElement.showFrame == showFrame {
            print("DEBUG: ElementViewModel - フレーム表示設定が同じなので変更をスキップします")
            return
        }
        
        // 変更前の値を記録
        let oldValue = imageElement.showFrame
        
        // 編集開始をマーク
        imageElement.startEditing()
        
        // 即座に値を更新（UI即座反応のため）
        imageElement.showFrame = showFrame
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateImageShowFrame(imageElement, newValue: showFrame)
        
        // メタデータに編集を記録
        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "showFrame",
                oldValue: oldValue,
                newValue: showFrame
            )
        }
    }
    
    /// フレームの色の更新
    func updateFrameColor(_ color: UIColor) {
        print("DEBUG: ElementViewModel - フレーム色更新開始")
        guard let imageElement = imageElement else {
            print("DEBUG: ElementViewModel - imageElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ色なら何もしない
        if imageElement.frameColor.isEqual(color) {
            print("DEBUG: ElementViewModel - フレーム色が同じなので変更をスキップします")
            return
        }
        
        // 変更前の値を記録
        let oldColor = imageElement.frameColor
        
        // 編集開始をマーク
        imageElement.startEditing()
        
        // 即座に値を更新（UI即座反応のため）
        imageElement.frameColor = color
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateImageFrameColor(imageElement, newColor: color)
        
        // メタデータに編集を記録
        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "frameColor",
                oldValue: oldColor.description,
                newValue: color.description
            )
        }
    }
    
    /// フレームの太さの更新
    func updateFrameWidth(_ width: CGFloat) {
        print("DEBUG: ElementViewModel - フレーム太さ更新開始: \(width)")
        guard let imageElement = imageElement else {
            print("DEBUG: ElementViewModel - imageElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ太さなら何もしない
        if imageElement.frameWidth == width {
            print("DEBUG: ElementViewModel - フレーム太さが同じなので変更をスキップします")
            return
        }
        
        // 変更前の値を記録
        let oldWidth = imageElement.frameWidth
        
        // 編集開始をマーク
        imageElement.startEditing()
        
        // 即座に値を更新（UI即座反応のため）
        imageElement.frameWidth = width
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateImageFrameWidth(imageElement, newWidth: width)
        
        // メタデータに編集を記録
        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "frameWidth",
                oldValue: oldWidth,
                newValue: width
            )
        }
    }
    
    /// 角丸の設定の更新
    func updateRoundedCorners(_ rounded: Bool, radius: CGFloat) {
        print("DEBUG: ElementViewModel - 角丸設定更新開始: 有効=\(rounded), 半径=\(radius)")
        guard let imageElement = imageElement else {
            print("DEBUG: ElementViewModel - imageElementがnilのため更新できません")
            return
        }
        
        // 現在と同じ設定なら何もしない
        if imageElement.roundedCorners == rounded && imageElement.cornerRadius == radius {
            print("DEBUG: ElementViewModel - 角丸設定が同じなので変更をスキップします")
            return
        }
        
        // 変更前の値を記録
        let wasRounded = imageElement.roundedCorners
        let oldRadius = imageElement.cornerRadius
        
        // 編集開始をマーク
        imageElement.startEditing()
        
        // 即座に値を更新（UI即座反応のため）
        imageElement.roundedCorners = rounded
        imageElement.cornerRadius = radius
        
        // EditorViewModelの対応するメソッドを呼び出す
        editorViewModel?.updateImageRoundedCorners(imageElement, wasRounded: wasRounded, isRounded: rounded, oldRadius: oldRadius, newRadius: radius)
        
        // メタデータに編集を記録
        if imageElement.originalImageIdentifier != nil {
            // 角丸の有効/無効の変更を記録
            imageElement.recordMetadataEdit(
                fieldKey: "roundedCorners",
                oldValue: wasRounded,
                newValue: rounded
            )
            
            // 角丸半径の変更を記録
            imageElement.recordMetadataEdit(
                fieldKey: "cornerRadius",
                oldValue: oldRadius,
                newValue: radius
            )
        }
    }
    
    // MARK: - 更新の適用
    
    /// 要素を更新してエディタビューモデルに通知
    private func updateElement(to element: LogoElement) {
        // 要素の参照を更新
        self.element = element
        
        // エディタビューモデルに要素の更新を通知
        if let editorViewModel = editorViewModel {
            editorViewModel.updateSelectedElement(element)
            
            // 要素の種類に応じて専用の更新メソッドを呼び出す
            if let textElement = element as? TextElement {
                editorViewModel.updateTextElement(textElement)
                self.textElement = textElement
            } else if let shapeElement = element as? ShapeElement {
                editorViewModel.updateShapeElement(shapeElement)
                self.shapeElement = shapeElement
            } else if let imageElement = element as? ImageElement {
                editorViewModel.updateImageElement(imageElement)
                self.imageElement = imageElement
            }
        }
    }
}
