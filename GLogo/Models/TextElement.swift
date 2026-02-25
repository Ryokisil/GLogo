//
//  TextElement.swift
//
//  概要:
//  このファイルはテキスト要素を表すモデルクラスを定義しています。
//  LogoElementを継承し、テキスト内容、フォント、サイズ、色、整列、行間、文字間隔などの
//  テキスト固有のプロパティを管理します。また、シャドウなどのテキストエフェクトも
//  サポートしています。テキスト描画に必要な属性付き文字列の生成も行います。
//

import Foundation
import UIKit

/// テキストの整列を表す列挙型
enum TextAlignment: Int, Codable {
    case left
    case center
    case right
    
    /// UIKitのNSTextAlignmentに変換
    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }
}

/// テキスト効果の種類を表す列挙型
enum TextEffectType: String, Codable {
    case shadow
    case stroke
    case gradient
    case glow
}

/// テキスト効果の基本クラス
class TextEffect: Codable {
    /// 効果の種類
    let type: TextEffectType

    /// 効果が有効かどうか
    var isEnabled: Bool = true

    /// エンコード用のコーディングキー
    enum CodingKeys: String, CodingKey {
        case type, isEnabled
    }

    init(type: TextEffectType) {
        self.type = type
    }

    /// 効果を適用するメソッド（サブクラスでオーバーライド）
    func apply(to attributes: inout [NSAttributedString.Key: Any]) {
        // サブクラスで実装
    }

    /// ディープコピーを作成（サブクラスでオーバーライド）
    func deepCopy() -> TextEffect {
        let copy = TextEffect(type: type)
        copy.isEnabled = isEnabled
        return copy
    }

    /// スケール済みコピーを返す（サブクラスでオーバーライド）
    func scaled(by scale: CGFloat) -> TextEffect {
        assertionFailure("未対応の TextEffect サブクラス: \(Swift.type(of: self))")
        return deepCopy()
    }
}

/// シャドウ効果
class ShadowEffect: TextEffect {
    /// シャドウの色
    var color: UIColor = .black
    
    /// シャドウのオフセット
    var offset: CGSize = CGSize(width: 2, height: 2)
    
    /// シャドウのぼかし半径
    var blurRadius: CGFloat = 3.0
    
    /// エンコード用のコーディングキー
    private enum ShadowCodingKeys: String, CodingKey {
        case colorData, offsetWidth, offsetHeight, blurRadius
    }
    
    init(color: UIColor = .black, offset: CGSize = CGSize(width: 2, height: 2), blurRadius: CGFloat = 3.0) {
        super.init(type: .shadow)
        self.color = color
        self.offset = offset
        self.blurRadius = blurRadius
    }
    
    required init(from decoder: Decoder) throws {
        _ = try decoder.container(keyedBy: CodingKeys.self)
        try super.init(from: decoder)
        
        let shadowContainer = try decoder.container(keyedBy: ShadowCodingKeys.self)
        if let colorData = try? shadowContainer.decode(Data.self, forKey: .colorData),
           let decodedColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
            color = decodedColor
        }
        
        let offsetWidth = try shadowContainer.decode(CGFloat.self, forKey: .offsetWidth)
        let offsetHeight = try shadowContainer.decode(CGFloat.self, forKey: .offsetHeight)
        offset = CGSize(width: offsetWidth, height: offsetHeight)
        blurRadius = try shadowContainer.decode(CGFloat.self, forKey: .blurRadius)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var shadowContainer = encoder.container(keyedBy: ShadowCodingKeys.self)
        
        // UIColorのエンコード
        let colorData = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
        try shadowContainer.encode(colorData, forKey: .colorData)
        
        try shadowContainer.encode(offset.width, forKey: .offsetWidth)
        try shadowContainer.encode(offset.height, forKey: .offsetHeight)
        try shadowContainer.encode(blurRadius, forKey: .blurRadius)
    }
    
    override func apply(to attributes: inout [NSAttributedString.Key: Any]) {
        if isEnabled {
            let shadow = NSShadow()
            shadow.shadowColor = color
            shadow.shadowOffset = offset
            shadow.shadowBlurRadius = blurRadius
            attributes[.shadow] = shadow
        }
    }

    override func deepCopy() -> TextEffect {
        let copy = ShadowEffect(color: color, offset: offset, blurRadius: blurRadius)
        copy.isEnabled = isEnabled
        return copy
    }

    override func scaled(by scale: CGFloat) -> TextEffect {
        let copy = ShadowEffect(
            color: color,
            offset: CGSize(width: offset.width * scale, height: offset.height * scale),
            blurRadius: blurRadius * scale
        )
        copy.isEnabled = isEnabled
        return copy
    }
}

/// テキストの外枠線エフェクト
class StrokeEffect: TextEffect {
    /// ストロークの色
    var color: UIColor = .black
    
    /// ストロークの太さ
    var width: CGFloat = 2.0
    
    /// エンコード用のコーディングキー
    private enum StrokeCodingKeys: String, CodingKey {
        case colorData, width
    }
    
    init(color: UIColor = .black, width: CGFloat = 2.0) {
        super.init(type: .stroke)
        self.color = color
        self.width = width
    }
    
    required init(from decoder: Decoder) throws {
        _ = try decoder.container(keyedBy: CodingKeys.self)
        try super.init(from: decoder)
        
        let strokeContainer = try decoder.container(keyedBy: StrokeCodingKeys.self)
        if let colorData = try? strokeContainer.decode(Data.self, forKey: .colorData),
           let decodedColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
            color = decodedColor
        }
        
        width = try strokeContainer.decode(CGFloat.self, forKey: .width)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var strokeContainer = encoder.container(keyedBy: StrokeCodingKeys.self)
        
        // UIColorのエンコード
        let colorData = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
        try strokeContainer.encode(colorData, forKey: .colorData)
        try strokeContainer.encode(width, forKey: .width)
    }
    
    override func apply(to attributes: inout [NSAttributedString.Key: Any]) {
        if isEnabled {
            attributes[.strokeColor] = color
            attributes[.strokeWidth] = width

            // 注意: NSAttributedString.Key.strokeWidthの負の値は塗りつぶしありの外枠線
            // 正の値は塗りつぶしなしの外枠線になります
            // 既存のテキスト色を保持したい場合は負の値を使用
            attributes[.strokeWidth] = -width
        }
    }

    override func deepCopy() -> TextEffect {
        let copy = StrokeEffect(color: color, width: width)
        copy.isEnabled = isEnabled
        return copy
    }

    override func scaled(by scale: CGFloat) -> TextEffect {
        let copy = StrokeEffect(color: color, width: width * scale)
        copy.isEnabled = isEnabled
        return copy
    }
}

/// グロー効果
class GlowEffect: TextEffect {
    /// グローの色
    var color: UIColor = .white

    /// グローの半径
    var radius: CGFloat = 5.0

    /// エンコード用のコーディングキー
    private enum GlowCodingKeys: String, CodingKey {
        case colorData, radius
    }

    init(color: UIColor = .white, radius: CGFloat = 5.0) {
        super.init(type: .glow)
        self.color = color
        self.radius = radius
    }

    required init(from decoder: Decoder) throws {
        _ = try decoder.container(keyedBy: CodingKeys.self)
        try super.init(from: decoder)

        let glowContainer = try decoder.container(keyedBy: GlowCodingKeys.self)
        if let colorData = try? glowContainer.decode(Data.self, forKey: .colorData),
           let decodedColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
            color = decodedColor
        }

        radius = try glowContainer.decode(CGFloat.self, forKey: .radius)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var glowContainer = encoder.container(keyedBy: GlowCodingKeys.self)

        // UIColorのエンコード
        let colorData = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
        try glowContainer.encode(colorData, forKey: .colorData)
        try glowContainer.encode(radius, forKey: .radius)
    }

    /// グローはマルチパス描画で直接処理するため apply は no-op
    override func apply(to attributes: inout [NSAttributedString.Key: Any]) {
        // マルチパス描画で直接処理
    }

    override func deepCopy() -> TextEffect {
        let copy = GlowEffect(color: color, radius: radius)
        copy.isEnabled = isEnabled
        return copy
    }

    override func scaled(by scale: CGFloat) -> TextEffect {
        let copy = GlowEffect(color: color, radius: radius * scale)
        copy.isEnabled = isEnabled
        return copy
    }
}

/// グラデーション塗り効果
class GradientFillEffect: TextEffect {
    /// グラデーション開始色
    var startColor: UIColor = .red

    /// グラデーション終了色
    var endColor: UIColor = .blue

    /// グラデーション角度（度数: 0=左→右, 90=上→下）
    var angle: CGFloat = 0.0

    /// グラデーションの不透明度（0.0...1.0）
    var opacity: CGFloat = 1.0

    /// エンコード用のコーディングキー
    private enum GradientCodingKeys: String, CodingKey {
        case startColorData, endColorData, angle, opacity
    }

    init(startColor: UIColor = .red, endColor: UIColor = .blue, angle: CGFloat = 0.0, opacity: CGFloat = 1.0) {
        super.init(type: .gradient)
        self.startColor = startColor
        self.endColor = endColor
        self.angle = angle
        self.opacity = opacity
    }

    required init(from decoder: Decoder) throws {
        _ = try decoder.container(keyedBy: CodingKeys.self)
        try super.init(from: decoder)

        let gradientContainer = try decoder.container(keyedBy: GradientCodingKeys.self)
        if let colorData = try? gradientContainer.decode(Data.self, forKey: .startColorData),
           let decodedColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
            startColor = decodedColor
        }
        if let colorData = try? gradientContainer.decode(Data.self, forKey: .endColorData),
           let decodedColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
            endColor = decodedColor
        }

        angle = try gradientContainer.decodeIfPresent(CGFloat.self, forKey: .angle) ?? 0.0
        opacity = try gradientContainer.decodeIfPresent(CGFloat.self, forKey: .opacity) ?? 1.0
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var gradientContainer = encoder.container(keyedBy: GradientCodingKeys.self)

        // UIColorのエンコード
        let startData = try NSKeyedArchiver.archivedData(withRootObject: startColor, requiringSecureCoding: false)
        try gradientContainer.encode(startData, forKey: .startColorData)
        let endData = try NSKeyedArchiver.archivedData(withRootObject: endColor, requiringSecureCoding: false)
        try gradientContainer.encode(endData, forKey: .endColorData)
        try gradientContainer.encode(angle, forKey: .angle)
        try gradientContainer.encode(opacity, forKey: .opacity)
    }

    /// グラデーションはマルチパス描画で直接処理するため apply は no-op
    override func apply(to attributes: inout [NSAttributedString.Key: Any]) {
        // マルチパス描画で直接処理
    }

    override func deepCopy() -> TextEffect {
        let copy = GradientFillEffect(startColor: startColor, endColor: endColor, angle: angle, opacity: opacity)
        copy.isEnabled = isEnabled
        return copy
    }

    override func scaled(by scale: CGFloat) -> TextEffect {
        // 角度はスケール不要
        let copy = GradientFillEffect(startColor: startColor, endColor: endColor, angle: angle, opacity: opacity)
        copy.isEnabled = isEnabled
        return copy
    }
}

// MARK: - 多態 Codable ラッパー

/// TextEffect のサブクラス情報を保持して Codable ラウンドトリップを実現するラッパー
struct AnyTextEffect: Codable {
    let effect: TextEffect

    init(_ effect: TextEffect) {
        self.effect = effect
    }

    init(from decoder: Decoder) throws {
        // "type" フィールドを先読みして対応サブクラスをデコード
        let typeContainer = try decoder.container(keyedBy: TextEffect.CodingKeys.self)
        let effectType = try typeContainer.decode(TextEffectType.self, forKey: .type)

        switch effectType {
        case .shadow:
            effect = try ShadowEffect(from: decoder)
        case .stroke:
            effect = try StrokeEffect(from: decoder)
        case .glow:
            effect = try GlowEffect(from: decoder)
        case .gradient:
            effect = try GradientFillEffect(from: decoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try effect.encode(to: encoder)
    }
}

/// テキスト要素クラス
class TextElement: LogoElement {
    /// テキスト内容
    var text: String = ""
    
    /// フォント名
    var fontName: String = "HelveticaNeue"
    
    /// フォントサイズ
    var fontSize: CGFloat = 36.0
    
    /// テキストの色
    var textColor: UIColor = .white
    
    /// テキストの整列
    var alignment: TextAlignment = .center
    
    /// 行間
    var lineSpacing: CGFloat = 1.0
    
    /// 文字間隔
    var letterSpacing: CGFloat = 0.0
    
    /// テキスト効果のリスト
    var effects: [TextEffect] = []
    
    /// 要素の種類
    override var type: LogoElementType {
        return .text
    }
    
    /// フォントの取得
    var font: UIFont {
        return UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
    }
    
    /// エンコード用のコーディングキー
    private enum TextCodingKeys: String, CodingKey {
        case text, fontName, fontSize, textColorData, alignment, lineSpacing, letterSpacing, effects
    }
    
    /// カスタムエンコーダー
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var container = encoder.container(keyedBy: TextCodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        
        // UIColorのエンコード
        let colorData = try NSKeyedArchiver.archivedData(withRootObject: textColor, requiringSecureCoding: false)
        try container.encode(colorData, forKey: .textColorData)
        
        try container.encode(alignment, forKey: .alignment)
        try container.encode(lineSpacing, forKey: .lineSpacing)
        try container.encode(letterSpacing, forKey: .letterSpacing)
        // AnyTextEffect でラップしてサブクラス情報を保持
        try container.encode(effects.map { AnyTextEffect($0) }, forKey: .effects)
    }
    
    /// カスタムデコーダー
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        
        let container = try decoder.container(keyedBy: TextCodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        fontName = try container.decode(String.self, forKey: .fontName)
        fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        
        // UIColorのデコード
        if let colorData = try? container.decode(Data.self, forKey: .textColorData),
           let decodedColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
            textColor = decodedColor
        }
        
        alignment = try container.decode(TextAlignment.self, forKey: .alignment)
        lineSpacing = try container.decode(CGFloat.self, forKey: .lineSpacing)
        letterSpacing = try container.decode(CGFloat.self, forKey: .letterSpacing)
        // AnyTextEffect 経由でサブクラス情報を復元（後方互換: キーなし→空配列）
        let wrappedEffects = try container.decodeIfPresent([AnyTextEffect].self, forKey: .effects) ?? []
        effects = wrappedEffects.map { $0.effect }
    }
    
    /// 初期化メソッド
    init(text: String, fontName: String = "HelveticaNeue", fontSize: CGFloat = 36.0, textColor: UIColor = .white) {
        super.init(name: "Text")
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.textColor = textColor
        
        // デフォルトでシャドウ効果を追加
        effects.append(ShadowEffect())
        
        // デフォルトzIndexを設定
        self.zIndex = ElementPriority.text.rawValue
    }
    
    /// テキストの属性付き文字列を生成
    func attributedString() -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment.nsTextAlignment
        paragraphStyle.lineSpacing = lineSpacing
        
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        if letterSpacing != 0 {
            attributes[.kern] = letterSpacing
        }
        
        // 効果を適用
        for effect in effects where effect.isEnabled {
            effect.apply(to: &attributes)
        }
        
        return NSAttributedString(string: text, attributes: attributes)
    }

    
    // MARK: - マルチパス描画

    /// テキストをマルチパスで描画（グロー → ストローク群 → 塗り＋シャドウ）
    override func draw(in context: CGContext) {
        guard isVisible else { return }

        context.saveGState()

        // 透明度の設定
        context.setAlpha(opacity)

        // 中心点を計算
        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2

        // 変換行列を適用（回転と位置）
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: rotation)
        context.translateBy(x: -centerX, y: -centerY)

        let drawingOptions: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let drawRect = calculateDrawRect()

        // パス1: グロー（最背面）
        for effect in effects where effect.isEnabled {
            if let glow = effect as? GlowEffect {
                drawGlowPass(glow, in: drawRect, options: drawingOptions)
            }
        }

        // パス2: ストローク群（太→細の順で描画、外縁だけが残る）
        let enabledStrokes = effects.compactMap { $0.isEnabled ? ($0 as? StrokeEffect) : nil }
            .sorted { $0.width > $1.width }
        for stroke in enabledStrokes {
            drawStrokePass(stroke, in: drawRect, options: drawingOptions)
        }

        // パス3: テキスト本体＋シャドウ（最前面）
        drawFillPass(in: drawRect, options: drawingOptions)

        // パス4: グラデーション塗り（テキスト本体の上にクリッピングマスクで描画）
        for effect in effects where effect.isEnabled {
            if let gradient = effect as? GradientFillEffect {
                drawGradientFillPass(gradient, in: context, drawRect: drawRect, options: drawingOptions)
            }
        }

        context.restoreGState()
    }

    /// 垂直中央揃えを考慮した描画矩形を算出
    private func calculateDrawRect() -> CGRect {
        let rect = CGRect(origin: position, size: size)
        let measureString = attributedStringForMeasurement()
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let boundingRect = measureString.boundingRect(
            with: CGSize(width: rect.width, height: CGFloat.greatestFiniteMagnitude),
            options: options,
            context: nil
        )

        let baseRect: CGRect
        if boundingRect.height < rect.height {
            let yOffset = (rect.height - boundingRect.height) / 2
            baseRect = CGRect(
                x: rect.origin.x,
                y: rect.origin.y + yOffset,
                width: rect.width,
                height: max(boundingRect.height + 4, rect.height)
            )
        } else {
            baseRect = rect
        }

        // 編集中の見た目を安定させるため、エフェクト値の変化で描画原点を動かさない
        return baseRect
    }

    /// エフェクトなしの計測用属性付き文字列
    private func attributedStringForMeasurement() -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment.nsTextAlignment
        paragraphStyle.lineSpacing = lineSpacing

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        if letterSpacing != 0 {
            attributes[.kern] = letterSpacing
        }
        return NSAttributedString(string: text, attributes: attributes)
    }

    /// グローパスを描画
    private func drawGlowPass(_ glow: GlowEffect, in rect: CGRect, options: NSStringDrawingOptions) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment.nsTextAlignment
        paragraphStyle.lineSpacing = lineSpacing

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: glow.color,
            .paragraphStyle: paragraphStyle
        ]
        if letterSpacing != 0 {
            attributes[.kern] = letterSpacing
        }

        // グローは中心からの発光なのでオフセット0のシャドウで表現
        let shadow = NSShadow()
        shadow.shadowColor = glow.color
        shadow.shadowOffset = .zero
        shadow.shadowBlurRadius = glow.radius
        attributes[.shadow] = shadow

        let attrString = NSAttributedString(string: text, attributes: attributes)
        attrString.draw(with: rect, options: options, context: nil)
    }

    /// ストロークパスを描画
    private func drawStrokePass(_ stroke: StrokeEffect, in rect: CGRect, options: NSStringDrawingOptions) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment.nsTextAlignment
        paragraphStyle.lineSpacing = lineSpacing

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: stroke.color,
            .paragraphStyle: paragraphStyle,
            .strokeColor: stroke.color,
            .strokeWidth: -stroke.width // 負＝塗り＋輪郭
        ]
        if letterSpacing != 0 {
            attributes[.kern] = letterSpacing
        }

        let attrString = NSAttributedString(string: text, attributes: attributes)
        attrString.draw(with: rect, options: options, context: nil)
    }

    /// テキスト本体＋シャドウパスを描画（最前面）
    private func drawFillPass(in rect: CGRect, options: NSStringDrawingOptions) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment.nsTextAlignment
        paragraphStyle.lineSpacing = lineSpacing

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        if letterSpacing != 0 {
            attributes[.kern] = letterSpacing
        }

        // シャドウ効果を適用
        for effect in effects where effect.isEnabled {
            if let shadowEffect = effect as? ShadowEffect {
                shadowEffect.apply(to: &attributes)
            }
        }

        let attrString = NSAttributedString(string: text, attributes: attributes)
        attrString.draw(with: rect, options: options, context: nil)
    }
    
    /// グラデーション塗りパスを描画（テキスト形状にクリッピングしてグラデーション描画）
    private func drawGradientFillPass(
        _ gradient: GradientFillEffect,
        in context: CGContext,
        drawRect: CGRect,
        options: NSStringDrawingOptions
    ) {
        // オフスクリーンコンテキストでテキストをマスク用に描画
        // コンテキストの CTM からスケールを取得（回転・オフスクリーン描画にも対応）
        let ctm = context.ctm
        let scaleX = hypot(ctm.a, ctm.c)
        let scaleY = hypot(ctm.b, ctm.d)
        let scale = max(scaleX, scaleY, 1.0)
        let maskWidth = Int(drawRect.width * scale)
        let maskHeight = Int(drawRect.height * scale)
        guard maskWidth > 0, maskHeight > 0 else { return }

        guard let maskContext = CGContext(
            data: nil,
            width: maskWidth,
            height: maskHeight,
            bitsPerComponent: 8,
            bytesPerRow: maskWidth,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return }

        // マスク用コンテキストの座標変換（UIKit座標系に合わせる）
        maskContext.scaleBy(x: scale, y: scale)
        maskContext.translateBy(x: -drawRect.origin.x, y: -drawRect.origin.y)

        // 黒背景で初期化（マスクでは白=表示、黒=非表示）
        maskContext.setFillColor(UIColor.black.cgColor)
        maskContext.fill(CGRect(origin: drawRect.origin, size: drawRect.size))

        // テキストを白で描画
        UIGraphicsPushContext(maskContext)
        let maskAttrString = attributedStringForMask()
        maskAttrString.draw(with: drawRect, options: options, context: nil)
        UIGraphicsPopContext()

        guard let maskImage = maskContext.makeImage() else { return }

        // メインコンテキストでクリッピング＋グラデーション描画
        context.saveGState()
        context.clip(to: drawRect, mask: maskImage)

        // 角度からグラデーションの始点・終点を計算
        let angleRad = gradient.angle * .pi / 180.0
        let centerX = drawRect.midX
        let centerY = drawRect.midY
        let halfDiag = sqrt(drawRect.width * drawRect.width + drawRect.height * drawRect.height) / 2

        let startPoint = CGPoint(
            x: centerX - cos(angleRad) * halfDiag,
            y: centerY - sin(angleRad) * halfDiag
        )
        let endPoint = CGPoint(
            x: centerX + cos(angleRad) * halfDiag,
            y: centerY + sin(angleRad) * halfDiag
        )

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [gradient.startColor.cgColor, gradient.endColor.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]

        if let cgGradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
            context.setAlpha(max(0.0, min(gradient.opacity, 1.0)))
            context.drawLinearGradient(
                cgGradient,
                start: startPoint,
                end: endPoint,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }

        context.restoreGState()
    }

    /// マスク描画用の属性付き文字列（白色・エフェクトなし）
    private func attributedStringForMask() -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment.nsTextAlignment
        paragraphStyle.lineSpacing = lineSpacing

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        if letterSpacing != 0 {
            attributes[.kern] = letterSpacing
        }
        return NSAttributedString(string: text, attributes: attributes)
    }

    /// 要素のコピーを作成
    override func copy() -> LogoElement {
        let copy = TextElement(text: text, fontName: fontName, fontSize: fontSize, textColor: textColor)
        copy.position = position
        copy.size = size
        copy.rotation = rotation
        copy.opacity = opacity
        copy.name = "\(name) Copy"
        copy.isVisible = isVisible
        copy.isLocked = isLocked
        copy.alignment = alignment
        copy.lineSpacing = lineSpacing
        copy.letterSpacing = letterSpacing
        
        // 効果のディープコピー（参照型のため独立したインスタンスを生成）
        copy.effects = effects.map { $0.deepCopy() }
        
        return copy
    }
}
