//
//  EventSourcing.swift
//
//  概要:
//  このファイルはイベントソーシングに基づくシンプルなアンドゥ・リドゥ機能を実装
//  コマンドパターンより実装が簡単、「何をしたか」を明確に記録します。
//

import Foundation
import UIKit

/// 編集の適用と取り消しを1組で表す履歴の単位。
/// 履歴は Undo／Redo のためにメモリ上だけで保持し、保存しないため Codable にしない。
protocol EditorEvent {
    /// イベントを適用するメソッド
    func apply(to project: LogoProject)
    
    /// イベントを元に戻すメソッド
    func revert(from project: LogoProject)
    
    /// イベントの説明
    var description: String { get }
}

/// エディタの履歴を管理するクラス
class EditorHistory {
    /// 履歴の移動をまたぐ非同期要求を失効させる。Undo／Redo しても巻き戻さない。
    private(set) var restorationRevision: UInt = 0

    /// 実行済みイベントのスタック
    private(set) var eventStack: [EditorEvent] = []
    
    /// 取り消されたイベントのスタック（リドゥ用）
    private var undoneEventStack: [EditorEvent] = []
    
    /// 履歴の最大数
    private let maxHistoryCount: Int
    
    /// プロジェクト参照
    private var project: LogoProject?
    
    /// イニシャライザ
    init(project: LogoProject?, maxHistoryCount: Int = 100) {
        self.project = project
        self.maxHistoryCount = maxHistoryCount
    }
    
    /// プロジェクト参照を更新
    func setProject(_ project: LogoProject) {
        restorationRevision &+= 1
        self.project = project
    }
    
    /// イベントを記録して適用
    func recordAndApply(_ event: EditorEvent) {
        guard let project = project else { return }
        
        // イベントをプロジェクトに適用
        event.apply(to: project)
        
        // イベントスタックに追加
        eventStack.append(event)
        
        // 履歴の最大数を超えた場合、古いものから削除
        if eventStack.count > maxHistoryCount {
            eventStack.removeFirst()
        }
        
        // 取り消し履歴をクリア
        undoneEventStack.removeAll()
    }
    
    /// 最後のイベントを巻き戻す。
    /// - Returns: 巻き戻し対象が存在した場合は `true`。
    @discardableResult
    func undo() -> Bool {
        
        guard let project = project, let lastEvent = eventStack.popLast() else {
            return false
        }
        restorationRevision &+= 1
        
        // イベントの効果を元に戻す
        lastEvent.revert(from: project)
        
        // 取り消し履歴に追加
        undoneEventStack.append(lastEvent)
        
        return true
    }
    
    /// リドゥ操作
    @discardableResult
    func redo() -> Bool {
        guard let project = project, let lastUndoneEvent = undoneEventStack.popLast() else {
            return false
        }
        restorationRevision &+= 1
        
        // 取り消したイベントを再適用
        lastUndoneEvent.apply(to: project)
        
        // イベント履歴に追加
        eventStack.append(lastUndoneEvent)
        
        return true
    }
    
    /// アンドゥ可能かどうか
    var canUndo: Bool {
        return !eventStack.isEmpty
    }
    
    /// リドゥ可能かどうか
    var canRedo: Bool {
        return !undoneEventStack.isEmpty
    }
    
    /// 履歴をクリア
    func clearHistory() {
        restorationRevision &+= 1
        eventStack.removeAll()
        undoneEventStack.removeAll()
    }
    
    /// アンドゥスタックの深さ（履歴の数）
    var undoCount: Int {
        return eventStack.count
    }
    
    /// リドゥスタックの深さ
    var redoCount: Int {
        return undoneEventStack.count
    }
    
    /// 履歴の説明を取得（UIに表示可能）
    func getHistoryDescriptions() -> [String] {
        return eventStack.map { $0.description }
    }
}

// MARK: - 具体的なイベント実装

/// 要素追加イベント
struct ElementAddedEvent: EditorEvent {
    let element: LogoElement
    
    var description: String {
        return "\(element.name)を追加しました"
    }
    
    func apply(to project: LogoProject) {
        project.elements.append(element)
    }
    
    func revert(from project: LogoProject) {
        project.elements.removeAll { $0.id == element.id }
    }
}

/// 要素削除イベント
struct ElementRemovedEvent: EditorEvent {
    let element: LogoElement
    let index: Int
    
    var description: String {
        return "\(element.name)を削除しました"
    }
    
    func apply(to project: LogoProject) {
        project.elements.removeAll { $0.id == element.id }
    }
    
    func revert(from project: LogoProject) {
        // インデックスが範囲内かチェック
        let safeIndex = min(index, project.elements.count)
        project.elements.insert(element, at: safeIndex)
    }
}

/// 要素回転イベント
struct ElementRotatedEvent: EditorEvent {
    let elementId: UUID
    let oldRotation: CGFloat
    let newRotation: CGFloat
    
    var description: String {
        return "要素を回転しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId) {
            element.rotation = newRotation
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId) {
            element.rotation = oldRotation
        }
    }
}

/// テキスト内容変更イベント
struct TextContentChangedEvent: EditorEvent {
    let elementId: UUID
    let oldText: String
    let newText: String
    
    var description: String {
        return "テキストを編集しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.text = newText
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.text = oldText
        }
    }
}

/// テキスト色変更イベント
struct TextColorChangedEvent: EditorEvent {
    let elementId: UUID
    let oldColor: UIColor
    let newColor: UIColor
    
    var description: String {
        return "テキストの色を変更しました"
    }
    
    func apply(to project: LogoProject) {
        
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.textColor = newColor
        }
    }
    
    func revert(from project: LogoProject) {

        if let element = project.element(for: elementId, as: TextElement.self) {
            element.textColor = oldColor
        }
    }
}

/// フォント変更イベント
struct FontChangedEvent: EditorEvent {
    let elementId: UUID
    let oldFontName: String
    let newFontName: String
    let oldFontSize: CGFloat
    let newFontSize: CGFloat
    
    var description: String {
        return "フォントを変更しました"
    }
    
    func apply(to project: LogoProject) {
        
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.fontName = newFontName
            element.fontSize = newFontSize
        }
    }
    
    func revert(from project: LogoProject) {
        
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.fontName = oldFontName
            element.fontSize = oldFontSize
        }
    }
}

/// 行間変更イベント
struct TextLineSpacingChangedEvent: EditorEvent {
    let elementId: UUID
    let oldSpacing: CGFloat
    let newSpacing: CGFloat

    var description: String {
        return "テキストの行間を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.lineSpacing = newSpacing
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.lineSpacing = oldSpacing
        }
    }
}

/// 文字間隔変更イベント
struct TextLetterSpacingChangedEvent: EditorEvent {
    let elementId: UUID
    let oldSpacing: CGFloat
    let newSpacing: CGFloat

    var description: String {
        return "テキストの文字間隔を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.letterSpacing = newSpacing
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.letterSpacing = oldSpacing
        }
    }
}

/// シャドウ効果変更イベント
struct TextShadowEffectChangedEvent: EditorEvent {
    let elementId: UUID
    let effectIndex: Int
    let oldOffset: CGSize
    let newOffset: CGSize
    let oldBlurRadius: CGFloat
    let newBlurRadius: CGFloat

    var description: String {
        return "テキストのシャドウを調整しました"
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let shadowEffect = element.effects[effectIndex] as? ShadowEffect else { return }

        shadowEffect.offset = newOffset
        shadowEffect.blurRadius = newBlurRadius
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let shadowEffect = element.effects[effectIndex] as? ShadowEffect else { return }

        shadowEffect.offset = oldOffset
        shadowEffect.blurRadius = oldBlurRadius
    }
}

/// ストローク効果変更イベント
struct TextStrokeEffectChangedEvent: EditorEvent {
    let elementId: UUID
    let effectIndex: Int
    let oldWidth: CGFloat
    let newWidth: CGFloat

    var description: String {
        return "テキストのストロークを調整しました"
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let strokeEffect = element.effects[effectIndex] as? StrokeEffect else { return }

        strokeEffect.width = newWidth
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let strokeEffect = element.effects[effectIndex] as? StrokeEffect else { return }

        strokeEffect.width = oldWidth
    }
}

/// グロー効果変更イベント
struct TextGlowEffectChangedEvent: EditorEvent {
    let elementId: UUID
    let effectIndex: Int
    let oldRadius: CGFloat
    let newRadius: CGFloat

    var description: String {
        return "テキストのグローを調整しました"
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let glowEffect = element.effects[effectIndex] as? GlowEffect else { return }

        glowEffect.radius = newRadius
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let glowEffect = element.effects[effectIndex] as? GlowEffect else { return }

        glowEffect.radius = oldRadius
    }
}

/// グラデーション塗り効果の色変更イベント
struct TextGradientFillColorChangedEvent: EditorEvent {
    let elementId: UUID
    let effectIndex: Int
    let oldStartColor: UIColor
    let newStartColor: UIColor
    let oldEndColor: UIColor
    let newEndColor: UIColor

    var description: String {
        return "テキストのグラデーション色を変更しました"
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let gradientEffect = element.effects[effectIndex] as? GradientFillEffect else { return }

        gradientEffect.startColor = newStartColor
        gradientEffect.endColor = newEndColor
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let gradientEffect = element.effects[effectIndex] as? GradientFillEffect else { return }

        gradientEffect.startColor = oldStartColor
        gradientEffect.endColor = oldEndColor
    }
}

/// グラデーション塗り効果の角度変更イベント
struct TextGradientFillEffectChangedEvent: EditorEvent {
    let elementId: UUID
    let effectIndex: Int
    let oldAngle: CGFloat
    let newAngle: CGFloat

    var description: String {
        return "テキストのグラデーション角度を調整しました"
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let gradientEffect = element.effects[effectIndex] as? GradientFillEffect else { return }

        gradientEffect.angle = newAngle
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let gradientEffect = element.effects[effectIndex] as? GradientFillEffect else { return }

        gradientEffect.angle = oldAngle
    }
}

/// グラデーション塗り効果の不透明度変更イベント
struct TextGradientFillOpacityChangedEvent: EditorEvent {
    let elementId: UUID
    let effectIndex: Int
    let oldOpacity: CGFloat
    let newOpacity: CGFloat

    var description: String {
        return "テキストのグラデーション不透明度を調整しました"
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let gradientEffect = element.effects[effectIndex] as? GradientFillEffect else { return }

        gradientEffect.opacity = newOpacity
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let gradientEffect = element.effects[effectIndex] as? GradientFillEffect else { return }

        gradientEffect.opacity = oldOpacity
    }
}

// MARK: - 図形に関するイベントの実装

/// 図形タイプ変更イベント
struct ShapeTypeChangedEvent: EditorEvent {
    let elementId: UUID
    let oldType: ShapeType
    let newType: ShapeType
    
    var description: String {
        return "図形タイプを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.shapeType = newType
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.shapeType = oldType
        }
    }
}

/// 図形の塗りつぶし色変更イベント
struct ShapeFillColorChangedEvent: EditorEvent {
    let elementId: UUID
    let oldColor: UIColor
    let newColor: UIColor
    
    var description: String {
        return "図形の塗りつぶし色を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.fillColor = newColor
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.fillColor = oldColor
        }
    }
}

/// 図形の塗りつぶしモード変更イベント
struct ShapeFillModeChangedEvent: EditorEvent {
    let elementId: UUID
    let oldMode: FillMode
    let newMode: FillMode
    
    var description: String {
        return "図形の塗りつぶしモードを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.fillMode = newMode
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.fillMode = oldMode
        }
    }
}

/// 図形の枠線色変更イベント
struct ShapeStrokeColorChangedEvent: EditorEvent {
    let elementId: UUID
    let oldColor: UIColor
    let newColor: UIColor
    
    var description: String {
        return "図形の枠線色を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.strokeColor = newColor
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.strokeColor = oldColor
        }
    }
}

/// 図形の枠線太さ変更イベント
struct ShapeStrokeWidthChangedEvent: EditorEvent {
    let elementId: UUID
    let oldWidth: CGFloat
    let newWidth: CGFloat
    
    var description: String {
        return "図形の枠線太さを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.strokeWidth = newWidth
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.strokeWidth = oldWidth
        }
    }
}

/// 図形の枠線モード変更イベント
struct ShapeStrokeModeChangedEvent: EditorEvent {
    let elementId: UUID
    let oldMode: StrokeMode
    let newMode: StrokeMode
    
    var description: String {
        return "図形の枠線モードを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.strokeMode = newMode
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.strokeMode = oldMode
        }
    }
}

/// 図形の角丸半径変更イベント
struct ShapeCornerRadiusChangedEvent: EditorEvent {
    let elementId: UUID
    let oldRadius: CGFloat
    let newRadius: CGFloat
    
    var description: String {
        return "図形の角丸半径を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.cornerRadius = newRadius
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.cornerRadius = oldRadius
        }
    }
}

/// 図形の辺の数変更イベント
struct ShapeSidesChangedEvent: EditorEvent {
    let elementId: UUID
    let oldSides: Int
    let newSides: Int
    
    var description: String {
        return "図形の辺の数を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.sides = newSides
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.sides = oldSides
        }
    }
}

/// 図形のグラデーション色変更イベント
struct ShapeGradientColorsChangedEvent: EditorEvent {
    let elementId: UUID
    let oldStartColor: UIColor
    let newStartColor: UIColor
    let oldEndColor: UIColor
    let newEndColor: UIColor
    
    var description: String {
        return "図形のグラデーション色を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.gradientStartColor = newStartColor
            element.gradientEndColor = newEndColor
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.gradientStartColor = oldStartColor
            element.gradientEndColor = oldEndColor
        }
    }
}

/// 図形のグラデーション角度変更イベント
struct ShapeGradientAngleChangedEvent: EditorEvent {
    let elementId: UUID
    let oldAngle: CGFloat
    let newAngle: CGFloat
    
    var description: String {
        return "図形のグラデーション角度を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.gradientAngle = newAngle
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.gradientAngle = oldAngle
        }
    }
}

// MARK: - 画像要素に関するイベントの実装

// fitMode 廃止: ImageFitModeChangedEvent 削除

/// 画像彩度変更イベント
struct ImageSaturationChangedEvent: EditorEvent {
    let elementId: UUID
    let oldSaturation: CGFloat
    let newSaturation: CGFloat
    
    var description: String {
        return "画像の彩度を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.saturationAdjustment = newSaturation
            element.invalidateRenderedImageCache()
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.saturationAdjustment = oldSaturation
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像明度変更イベント
struct ImageBrightnessChangedEvent: EditorEvent {
    let elementId: UUID
    let oldBrightness: CGFloat
    let newBrightness: CGFloat
    
    var description: String {
        return "画像の明度を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.brightnessAdjustment = newBrightness
            element.invalidateRenderedImageCache()
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.brightnessAdjustment = oldBrightness
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像コントラスト変更イベント
struct ImageContrastChangedEvent: EditorEvent {
    let elementId: UUID
    let oldContrast: CGFloat
    let newContrast: CGFloat
    
    var description: String {
        return "画像のコントラストを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.contrastAdjustment = newContrast
            element.invalidateRenderedImageCache()
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.contrastAdjustment = oldContrast
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像ハイライト変更イベント
struct ImageHighlightsChangedEvent: EditorEvent {
    let elementId: UUID
    let oldHighlights: CGFloat
    let newHighlights: CGFloat
    
    var description: String {
        return "画像のハイライトを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.highlightsAdjustment = newHighlights
            element.invalidateRenderedImageCache()
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.highlightsAdjustment = oldHighlights
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像シャドウ変更イベント
struct ImageShadowsChangedEvent: EditorEvent {
    let elementId: UUID
    let oldShadows: CGFloat
    let newShadows: CGFloat
    
    var description: String {
        return "画像のシャドウを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.shadowsAdjustment = newShadows
            element.invalidateRenderedImageCache()
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.shadowsAdjustment = oldShadows
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像黒レベル変更イベント
struct ImageBlacksChangedEvent: EditorEvent {
    let elementId: UUID
    let oldBlacks: CGFloat
    let newBlacks: CGFloat

    var description: String {
        return "画像の黒レベルを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.blacksAdjustment = newBlacks
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.blacksAdjustment = oldBlacks
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像白レベル変更イベント
struct ImageWhitesChangedEvent: EditorEvent {
    let elementId: UUID
    let oldWhites: CGFloat
    let newWhites: CGFloat

    var description: String {
        return "画像の白レベルを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.whitesAdjustment = newWhites
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.whitesAdjustment = oldWhites
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像色温度変更イベント
struct ImageWarmthChangedEvent: EditorEvent {
    let elementId: UUID
    let oldWarmth: CGFloat
    let newWarmth: CGFloat

    var description: String {
        return "画像の色温度を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.warmthAdjustment = newWarmth
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.warmthAdjustment = oldWarmth
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像ヴィブランス変更イベント
struct ImageVibranceChangedEvent: EditorEvent {
    let elementId: UUID
    let oldVibrance: CGFloat
    let newVibrance: CGFloat

    var description: String {
        return "画像のヴィブランスを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.vibranceAdjustment = newVibrance
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.vibranceAdjustment = oldVibrance
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像色相変更イベント
struct ImageHueChangedEvent: EditorEvent {
    let elementId: UUID
    let oldHue: CGFloat
    let newHue: CGFloat
    
    var description: String {
        return "画像の色相を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.hueAdjustment = newHue
            element.invalidateRenderedImageCache()
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.hueAdjustment = oldHue
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像シャープネス変更イベント
struct ImageSharpnessChangedEvent: EditorEvent {
    let elementId: UUID
    let oldSharpness: CGFloat
    let newSharpness: CGFloat
    
    var description: String {
        return "画像のシャープネスを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.sharpnessAdjustment = newSharpness
            element.invalidateRenderedImageCache()
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.sharpnessAdjustment = oldSharpness
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像ガウシアンブラー変更イベント
struct ImageGaussianBlurChangedEvent: EditorEvent {
    let elementId: UUID
    let oldRadius: CGFloat
    let newRadius: CGFloat
    
    var description: String {
        return "画像のガウシアンブラーを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.gaussianBlurRadius = newRadius
            element.invalidateRenderedImageCache()
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.gaussianBlurRadius = oldRadius
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像ビネット変更イベント
struct ImageVignetteChangedEvent: EditorEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像のビネットを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.vignetteAdjustment = newIntensity
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.vignetteAdjustment = oldIntensity
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像ブルーム変更イベント
struct ImageBloomChangedEvent: EditorEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像のブルームを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.bloomAdjustment = newIntensity
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.bloomAdjustment = oldIntensity
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像グレイン変更イベント
struct ImageGrainChangedEvent: EditorEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像のグレインを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.grainAdjustment = newIntensity
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.grainAdjustment = oldIntensity
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像フェード変更イベント
struct ImageFadeChangedEvent: EditorEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像のフェードを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.fadeAdjustment = newIntensity
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.fadeAdjustment = oldIntensity
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像色収差変更イベント
struct ImageChromaticAberrationChangedEvent: EditorEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像の色収差を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.chromaticAberrationAdjustment = newIntensity
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.chromaticAberrationAdjustment = oldIntensity
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像ティントカラー変更イベント
struct ImageTintColorChangedEvent: EditorEvent {
    let elementId: UUID
    let oldColor: UIColor?
    let newColor: UIColor?
    let oldIntensity: CGFloat
    let newIntensity: CGFloat
    
    var description: String {
        return "画像のティントカラーを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.tintColor = newColor
            element.tintIntensity = newIntensity
            element.invalidateRenderedImageCache()
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.tintColor = oldColor
            element.tintIntensity = oldIntensity
            element.invalidateRenderedImageCache()
        }
    }
}

/// リバート時に復元可能な画像調整状態スナップショット
private struct ImageRevertStateSnapshot {
    let saturationAdjustment: CGFloat
    let brightnessAdjustment: CGFloat
    let contrastAdjustment: CGFloat
    let highlightsAdjustment: CGFloat
    let shadowsAdjustment: CGFloat
    let blacksAdjustment: CGFloat
    let whitesAdjustment: CGFloat
    let warmthAdjustment: CGFloat
    let vibranceAdjustment: CGFloat
    let hueAdjustment: CGFloat
    let sharpnessAdjustment: CGFloat
    let gaussianBlurRadius: CGFloat
    let vignetteAdjustment: CGFloat
    let bloomAdjustment: CGFloat
    let grainAdjustment: CGFloat
    let fadeAdjustment: CGFloat
    let chromaticAberrationAdjustment: CGFloat
    let backgroundBlurRadius: CGFloat
    let backgroundBlurMaskData: Data?
    let toneCurveData: ToneCurveData
    let tintColor: RGBAColorSnapshot?
    let tintIntensity: CGFloat
    let appliedFilterRecipe: FilterRecipe?
    let appliedFilterPresetId: String?
    let showFrame: Bool
    let frameColor: RGBAColorSnapshot
    let frameWidth: CGFloat
    let frameStyle: ImageFrameStyle
    let roundedCorners: Bool
    let cornerRadius: CGFloat

    init(element: ImageElement) {
        saturationAdjustment = element.saturationAdjustment
        brightnessAdjustment = element.brightnessAdjustment
        contrastAdjustment = element.contrastAdjustment
        highlightsAdjustment = element.highlightsAdjustment
        shadowsAdjustment = element.shadowsAdjustment
        blacksAdjustment = element.blacksAdjustment
        whitesAdjustment = element.whitesAdjustment
        warmthAdjustment = element.warmthAdjustment
        vibranceAdjustment = element.vibranceAdjustment
        hueAdjustment = element.hueAdjustment
        sharpnessAdjustment = element.sharpnessAdjustment
        gaussianBlurRadius = element.gaussianBlurRadius
        vignetteAdjustment = element.vignetteAdjustment
        bloomAdjustment = element.bloomAdjustment
        grainAdjustment = element.grainAdjustment
        fadeAdjustment = element.fadeAdjustment
        chromaticAberrationAdjustment = element.chromaticAberrationAdjustment
        backgroundBlurRadius = element.backgroundBlurRadius
        backgroundBlurMaskData = element.backgroundBlurMaskData
        toneCurveData = element.toneCurveData
        tintColor = element.tintColor.map(RGBAColorSnapshot.init)
        tintIntensity = element.tintIntensity
        appliedFilterRecipe = element.appliedFilterRecipe
        appliedFilterPresetId = element.appliedFilterPresetId
        showFrame = element.showFrame
        frameColor = RGBAColorSnapshot(element.frameColor)
        frameWidth = element.frameWidth
        frameStyle = element.frameStyle
        roundedCorners = element.roundedCorners
        cornerRadius = element.cornerRadius
    }

    /// スナップショット状態を画像要素へ反映する
    /// - Parameters:
    ///   - element: 反映先画像要素
    /// - Returns: なし
    func apply(to element: ImageElement) {
        element.saturationAdjustment = saturationAdjustment
        element.brightnessAdjustment = brightnessAdjustment
        element.contrastAdjustment = contrastAdjustment
        element.highlightsAdjustment = highlightsAdjustment
        element.shadowsAdjustment = shadowsAdjustment
        element.blacksAdjustment = blacksAdjustment
        element.whitesAdjustment = whitesAdjustment
        element.warmthAdjustment = warmthAdjustment
        element.vibranceAdjustment = vibranceAdjustment
        element.hueAdjustment = hueAdjustment
        element.sharpnessAdjustment = sharpnessAdjustment
        element.gaussianBlurRadius = gaussianBlurRadius
        element.vignetteAdjustment = vignetteAdjustment
        element.bloomAdjustment = bloomAdjustment
        element.grainAdjustment = grainAdjustment
        element.fadeAdjustment = fadeAdjustment
        element.chromaticAberrationAdjustment = chromaticAberrationAdjustment
        element.backgroundBlurRadius = backgroundBlurRadius
        element.backgroundBlurMaskData = backgroundBlurMaskData
        element.toneCurveData = toneCurveData
        element.tintColor = tintColor?.uiColor
        element.tintIntensity = tintIntensity
        element.appliedFilterRecipe = appliedFilterRecipe
        element.appliedFilterPresetId = appliedFilterPresetId
        element.showFrame = showFrame
        element.frameColor = frameColor.uiColor
        element.frameWidth = frameWidth
        element.frameStyle = frameStyle
        element.roundedCorners = roundedCorners
        element.cornerRadius = cornerRadius
        element.invalidateRenderedImageCache()
    }
}

/// UIColor を RGBA 成分に変換して保持する色の値
struct RGBAColorSnapshot {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ color: UIColor) {
        var redValue: CGFloat = 0
        var greenValue: CGFloat = 0
        var blueValue: CGFloat = 0
        var alphaValue: CGFloat = 0

        if color.getRed(&redValue, green: &greenValue, blue: &blueValue, alpha: &alphaValue) {
            red = redValue
            green = greenValue
            blue = blueValue
            alpha = alphaValue
            return
        }

        let ciColor = CIColor(color: color)
        red = ciColor.red
        green = ciColor.green
        blue = ciColor.blue
        alpha = ciColor.alpha
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

/// 画像要素を初期状態へ戻すイベント（UndoでRevert前状態へ復元可能）
struct ImageRevertedToInitialStateEvent: EditorEvent {
    let elementId: UUID
    private let beforeState: ImageRevertStateSnapshot

    var description: String {
        "画像を初期状態に戻しました"
    }

    /// 初期化
    /// - Parameters:
    ///   - element: Revert対象画像要素
    /// - Returns: なし
    init(element: ImageElement) {
        self.elementId = element.id
        self.beforeState = ImageRevertStateSnapshot(element: element)
    }

    /// Revert操作を適用する
    /// - Parameters:
    ///   - project: 対象プロジェクト
    /// - Returns: なし
    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: ImageElement.self) else {
            return
        }
        ImageElementMetadataRevertUseCase().revertToInitialState(element)
    }

    /// Revert適用前の状態に戻す
    /// - Parameters:
    ///   - project: 対象プロジェクト
    /// - Returns: なし
    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: ImageElement.self) else {
            return
        }
        beforeState.apply(to: element)
    }
}

/// 画像内容差し替えイベント（手動背景除去などの結果適用）
struct ImageContentReplacedEvent: EditorEvent {
    let elementId: UUID
    let oldImageData: Data?
    let oldImageFileName: String?
    let oldOriginalImageURL: URL?
    let oldOriginalImagePath: String?
    let oldOriginalImageIdentifier: String?
    let oldHasAppliedUpscale: Bool
    let oldToneCurveData: ToneCurveData
    let oldSaturation: CGFloat
    let oldBrightness: CGFloat
    let oldContrast: CGFloat
    let oldHighlights: CGFloat
    let oldShadows: CGFloat
    let oldBlacks: CGFloat
    let oldWhites: CGFloat
    let oldWarmth: CGFloat
    let oldVibrance: CGFloat
    let oldHue: CGFloat
    let oldSharpness: CGFloat
    let oldGaussianBlurRadius: CGFloat
    let oldVignette: CGFloat
    let oldBloom: CGFloat
    let oldGrain: CGFloat
    let oldFade: CGFloat
    let oldChromaticAberration: CGFloat
    let oldTintIntensity: CGFloat
    let oldTintColor: UIColor?
    let oldAppliedFilterRecipe: FilterRecipe?
    let oldAppliedFilterPresetId: String?
    let newImageData: Data
    let newOriginalImageIdentifier: String
    let newHasAppliedUpscale: Bool

    var description: String {
        return "画像内容を差し替えました"
    }

    /// 画像差し替えイベントを生成する
    /// - Parameters:
    ///   - elementId: 対象要素のID
    ///   - oldImageData: 以前の画像データ
    ///   - oldImageFileName: 以前の画像ファイル名
    ///   - oldOriginalImageURL: 以前の画像URL
    ///   - oldOriginalImagePath: 以前の画像パス
    ///   - oldOriginalImageIdentifier: 以前の画像識別子
    ///   - oldHasAppliedUpscale: 以前の高画質化適用状態
    ///   - oldToneCurveData: 以前のトーンカーブ
    ///   - oldSaturation: 以前の彩度
    ///   - oldBrightness: 以前の明度
    ///   - oldContrast: 以前のコントラスト
    ///   - oldHighlights: 以前のハイライト補正
    ///   - oldShadows: 以前のシャドウ補正
    ///   - oldBlacks: 以前の黒レベル補正
    ///   - oldWhites: 以前の白レベル補正
    ///   - oldWarmth: 以前の色温度補正
    ///   - oldVibrance: 以前のヴィブランス補正
    ///   - oldHue: 以前の色相
    ///   - oldSharpness: 以前のシャープネス
    ///   - oldGaussianBlurRadius: 以前のガウシアンブラー半径
    ///   - oldVignette: 以前のビネット強度
    ///   - oldBloom: 以前のブルーム強度
    ///   - oldGrain: 以前のグレイン強度
    ///   - oldFade: 以前のフェード強度
    ///   - oldChromaticAberration: 以前の色収差強度
    ///   - oldTintIntensity: 以前のティント強度
    ///   - oldTintColor: 以前のティントカラー
    ///   - oldAppliedFilterRecipe: 以前のフィルターレシピ
    ///   - oldAppliedFilterPresetId: 以前のフィルタープリセットID
    ///   - newImageData: 差し替え後の画像データ
    ///   - newOriginalImageIdentifier: 差し替え後の画像識別子
    ///   - newHasAppliedUpscale: 差し替え後の高画質化適用状態
    /// - Returns: なし
    init(
        elementId: UUID,
        oldImageData: Data?,
        oldImageFileName: String?,
        oldOriginalImageURL: URL?,
        oldOriginalImagePath: String?,
        oldOriginalImageIdentifier: String?,
        oldHasAppliedUpscale: Bool,
        oldToneCurveData: ToneCurveData,
        oldSaturation: CGFloat,
        oldBrightness: CGFloat,
        oldContrast: CGFloat,
        oldHighlights: CGFloat,
        oldShadows: CGFloat,
        oldBlacks: CGFloat,
        oldWhites: CGFloat,
        oldWarmth: CGFloat,
        oldVibrance: CGFloat,
        oldHue: CGFloat,
        oldSharpness: CGFloat,
        oldGaussianBlurRadius: CGFloat,
        oldVignette: CGFloat,
        oldBloom: CGFloat,
        oldGrain: CGFloat,
        oldFade: CGFloat,
        oldChromaticAberration: CGFloat,
        oldTintIntensity: CGFloat,
        oldTintColor: UIColor?,
        oldAppliedFilterRecipe: FilterRecipe?,
        oldAppliedFilterPresetId: String?,
        newImageData: Data,
        newOriginalImageIdentifier: String,
        newHasAppliedUpscale: Bool
    ) {
        self.elementId = elementId
        self.oldImageData = oldImageData
        self.oldImageFileName = oldImageFileName
        self.oldOriginalImageURL = oldOriginalImageURL
        self.oldOriginalImagePath = oldOriginalImagePath
        self.oldOriginalImageIdentifier = oldOriginalImageIdentifier
        self.oldHasAppliedUpscale = oldHasAppliedUpscale
        self.oldToneCurveData = oldToneCurveData
        self.oldSaturation = oldSaturation
        self.oldBrightness = oldBrightness
        self.oldContrast = oldContrast
        self.oldHighlights = oldHighlights
        self.oldShadows = oldShadows
        self.oldBlacks = oldBlacks
        self.oldWhites = oldWhites
        self.oldWarmth = oldWarmth
        self.oldVibrance = oldVibrance
        self.oldHue = oldHue
        self.oldSharpness = oldSharpness
        self.oldGaussianBlurRadius = oldGaussianBlurRadius
        self.oldVignette = oldVignette
        self.oldBloom = oldBloom
        self.oldGrain = oldGrain
        self.oldFade = oldFade
        self.oldChromaticAberration = oldChromaticAberration
        self.oldTintIntensity = oldTintIntensity
        self.oldTintColor = oldTintColor
        self.oldAppliedFilterRecipe = oldAppliedFilterRecipe
        self.oldAppliedFilterPresetId = oldAppliedFilterPresetId
        self.newImageData = newImageData
        self.newOriginalImageIdentifier = newOriginalImageIdentifier
        self.newHasAppliedUpscale = newHasAppliedUpscale
    }

    /// 画像内容を差し替える
    /// - Parameters:
    ///   - project: 対象プロジェクト
    /// - Returns: なし
    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: ImageElement.self) else {
            return
        }
        // 背景除去の適用ではレイアウトサイズを維持する
        let preservedSize = element.size
        element.replaceImageSource(
            with: newImageData,
            resetAdjustments: true,
            originalIdentifier: newOriginalImageIdentifier,
            hasAppliedUpscale: newHasAppliedUpscale
        )
        element.size = preservedSize
    }

    /// 画像内容を元に戻す
    /// - Parameters:
    ///   - project: 対象プロジェクト
    /// - Returns: なし
    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: ImageElement.self) else {
            return
        }
        // Undo時も適用前のレイアウトサイズを維持する
        let preservedSize = element.size

        element.restoreImageSource(
            imageData: oldImageData,
            fileName: oldImageFileName,
            url: oldOriginalImageURL,
            path: oldOriginalImagePath,
            originalIdentifier: oldOriginalImageIdentifier,
            hasAppliedUpscale: oldHasAppliedUpscale
        )
        element.size = preservedSize

        element.toneCurveData = oldToneCurveData
        element.saturationAdjustment = oldSaturation
        element.brightnessAdjustment = oldBrightness
        element.contrastAdjustment = oldContrast
        element.highlightsAdjustment = oldHighlights
        element.shadowsAdjustment = oldShadows
        element.blacksAdjustment = oldBlacks
        element.whitesAdjustment = oldWhites
        element.warmthAdjustment = oldWarmth
        element.vibranceAdjustment = oldVibrance
        element.hueAdjustment = oldHue
        element.sharpnessAdjustment = oldSharpness
        element.gaussianBlurRadius = oldGaussianBlurRadius
        element.vignetteAdjustment = oldVignette
        element.bloomAdjustment = oldBloom
        element.grainAdjustment = oldGrain
        element.fadeAdjustment = oldFade
        element.chromaticAberrationAdjustment = oldChromaticAberration
        element.tintColor = oldTintColor
        element.tintIntensity = oldTintIntensity
        element.appliedFilterRecipe = oldAppliedFilterRecipe
        element.appliedFilterPresetId = oldAppliedFilterPresetId
    }
}

/// 画像フレーム表示変更イベント
struct ImageShowFrameChangedEvent: EditorEvent {
    let elementId: UUID
    let oldValue: Bool
    let newValue: Bool
    
    var description: String {
        return "画像のフレーム表示を\(newValue ? "有効" : "無効")にしました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.showFrame = newValue
            element.invalidateRenderedImageCache()
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.showFrame = oldValue
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像フレーム色変更イベント
struct ImageFrameColorChangedEvent: EditorEvent {
    let elementId: UUID
    let oldColor: UIColor
    let newColor: UIColor
    
    var description: String {
        return "画像のフレーム色を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.frameColor = newColor
            element.invalidateRenderedImageCache()
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.frameColor = oldColor
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像フレーム太さ変更イベント
struct ImageFrameWidthChangedEvent: EditorEvent {
    let elementId: UUID
    let oldWidth: CGFloat
    let newWidth: CGFloat
    
    var description: String {
        return "画像のフレーム太さを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.frameWidth = newWidth
            element.invalidateRenderedImageCache()
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.frameWidth = oldWidth
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像フレームスタイル変更イベント
struct ImageFrameStyleChangedEvent: EditorEvent {
    let elementId: UUID
    let oldStyle: ImageFrameStyle
    let newStyle: ImageFrameStyle

    var description: String {
        return "画像のフレームスタイルを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.frameStyle = newStyle
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.frameStyle = oldStyle
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像フレームの表示・スタイル・色をまとめて変更するイベント
struct ImageFrameAppearanceChangedEvent: EditorEvent {
    let elementId: UUID
    let oldShowFrame: Bool
    let newShowFrame: Bool
    let oldFrameStyle: ImageFrameStyle
    let newFrameStyle: ImageFrameStyle
    let oldFrameColor: RGBAColorSnapshot
    let newFrameColor: RGBAColorSnapshot

    var description: String {
        return "画像のフレーム見た目を変更しました"
    }

    init(
        elementId: UUID,
        oldShowFrame: Bool,
        newShowFrame: Bool,
        oldFrameStyle: ImageFrameStyle,
        newFrameStyle: ImageFrameStyle,
        oldFrameColor: UIColor,
        newFrameColor: UIColor
    ) {
        self.elementId = elementId
        self.oldShowFrame = oldShowFrame
        self.newShowFrame = newShowFrame
        self.oldFrameStyle = oldFrameStyle
        self.newFrameStyle = newFrameStyle
        self.oldFrameColor = RGBAColorSnapshot(oldFrameColor)
        self.newFrameColor = RGBAColorSnapshot(newFrameColor)
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.showFrame = newShowFrame
            element.frameStyle = newFrameStyle
            element.frameColor = newFrameColor.uiColor
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.showFrame = oldShowFrame
            element.frameStyle = oldFrameStyle
            element.frameColor = oldFrameColor.uiColor
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像角丸設定変更イベント
struct ImageRoundedCornersChangedEvent: EditorEvent {
    let elementId: UUID
    let wasRounded: Bool
    let isRounded: Bool
    let oldRadius: CGFloat
    let newRadius: CGFloat
    
    var description: String {
        if wasRounded != isRounded {
            return "画像の角丸を\(isRounded ? "有効" : "無効")にしました"
        } else {
            return "画像の角丸半径を変更しました"
        }
    }
    
    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.roundedCorners = isRounded
            element.cornerRadius = newRadius
            element.invalidateRenderedImageCache()
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.roundedCorners = wasRounded
            element.cornerRadius = oldRadius
            element.invalidateRenderedImageCache()
        }
    }
}

// MARK: - その他

/// プロジェクト名変更イベント
struct ProjectNameChangedEvent: EditorEvent {
    let oldName: String
    let newName: String
    
    var description: String {
        return "プロジェクト名を「\(newName)」に変更しました"
    }
    
    func apply(to project: LogoProject) {
        project.name = newName
    }
    
    func revert(from project: LogoProject) {
        project.name = oldName
    }
}

/// キャンバスサイズ変更イベント
struct CanvasSizeChangedEvent: EditorEvent {
    let oldSize: CGSize
    let newSize: CGSize
    
    var description: String {
        return "キャンバスサイズを変更しました"
    }
    
    func apply(to project: LogoProject) {
        project.canvasSize = newSize
    }
    
    func revert(from project: LogoProject) {
        project.canvasSize = oldSize
    }
}

/// 要素の複合変更イベント（移動 + サイズ変更 + 回転）
struct ElementTransformedEvent: EditorEvent {
    let elementId: UUID
    let oldPosition: CGPoint?
    let newPosition: CGPoint?
    let oldSize: CGSize?
    let newSize: CGSize?
    let oldRotation: CGFloat?
    let newRotation: CGFloat?
    
    var description: String {
        var desc = "要素を"
        if oldPosition != nil { desc += "移動" }
        if oldSize != nil { desc += oldPosition != nil ? "・リサイズ" : "リサイズ" }
        if oldRotation != nil { desc += (oldPosition != nil || oldSize != nil) ? "・回転" : "回転" }
        desc += "しました"
        return desc
    }
    
    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId) else { return }
        
        if let newPosition = newPosition {
            element.position = newPosition
        }
        
        if let newSize = newSize {
            element.size = newSize
        }
        
        if let newRotation = newRotation {
            element.rotation = newRotation
        }
    }
    
    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId) else { return }
        
        if let oldPosition = oldPosition {
            element.position = oldPosition
        }
        
        if let oldSize = oldSize {
            element.size = oldSize
        }
        
        if let oldRotation = oldRotation {
            element.rotation = oldRotation
        }
    }
}

/// 画像要素の並び順一括変更イベント（画像一覧レールでのドラッグ並べ替え用）
struct ImageOrderChangedEvent: EditorEvent {
    /// 変更対象: (要素ID, 旧zIndex, 新zIndex)
    let changes: [(elementId: UUID, oldZIndex: Int, newZIndex: Int)]

    var description: String {
        return "画像の並び順を変更しました"
    }

    func apply(to project: LogoProject) {
        for change in changes {
            guard let element = project.element(for: change.elementId) else { continue }
            element.zIndex = change.newZIndex
        }
    }

    func revert(from project: LogoProject) {
        for change in changes {
            guard let element = project.element(for: change.elementId) else { continue }
            element.zIndex = change.oldZIndex
        }
    }
}

// MARK: - 背景ぼかし関連イベント

/// 背景ぼかしマスク変更イベント
struct ImageBackgroundBlurMaskChangedEvent: EditorEvent {
    let elementId: UUID
    let oldMaskData: Data?
    let newMaskData: Data?

    var description: String {
        if newMaskData != nil {
            return "背景ぼかしマスクを設定しました"
        } else {
            return "背景ぼかしマスクを削除しました"
        }
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.backgroundBlurMaskData = newMaskData
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.backgroundBlurMaskData = oldMaskData
            element.invalidateRenderedImageCache()
        }
    }
}

/// 背景ぼかし半径変更イベント
struct ImageBackgroundBlurRadiusChangedEvent: EditorEvent {
    let elementId: UUID
    let oldRadius: CGFloat
    let newRadius: CGFloat

    var description: String {
        return "背景ぼかしの強度を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.backgroundBlurRadius = newRadius
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.backgroundBlurRadius = oldRadius
            element.invalidateRenderedImageCache()
        }
    }
}

// MARK: - フィルタープリセット関連イベント

/// フィルタープリセット変更イベント
struct FilterPresetChangedEvent: EditorEvent {
    let elementId: UUID
    let oldRecipe: FilterRecipe?
    let newRecipe: FilterRecipe?
    let oldPresetId: String?
    let newPresetId: String?

    var description: String {
        if newPresetId != nil {
            return "フィルタープリセットを変更しました"
        } else {
            return "フィルタープリセットを解除しました"
        }
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: ImageElement.self) else { return }
        element.appliedFilterRecipe = newRecipe
        element.appliedFilterPresetId = newPresetId
        element.invalidateRenderedImageCache()
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: ImageElement.self) else { return }
        element.appliedFilterRecipe = oldRecipe
        element.appliedFilterPresetId = oldPresetId
        element.invalidateRenderedImageCache()
    }
}
