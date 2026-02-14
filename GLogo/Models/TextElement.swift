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
        try container.encode(effects, forKey: .effects)
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
        effects = try container.decode([TextEffect].self, forKey: .effects)
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

    
    /// テキストを描画
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
        
        // テキストを描画
        let attrString = attributedString()
        let rect = CGRect(origin: position, size: size)
        
        
        // NSStringDrawingOptionsで描画方法を明示的に制御
        let options: NSStringDrawingOptions = [
            .usesLineFragmentOrigin,    // 行の断片化を使用（複数行対応）
            .usesFontLeading           // フォントのリーディングを使用
        ]
        
        // boundingRectForDrawingOptionsを使用してテキストサイズを正確に計算
        let boundingRect = attrString.boundingRect(
            with: CGSize(width: rect.width, height: CGFloat.greatestFiniteMagnitude),
            options: options,
            context: nil
        )
        
        
        // 描画領域を調整（マージンを追加して切り欠けを防ぐ）
        var drawRect = rect
        
        // テキストサイズがrectより小さい場合のみ中央揃え調整
        if boundingRect.height < rect.height {
            let yOffset = (rect.height - boundingRect.height) / 2
            drawRect = CGRect(
                x: rect.origin.x,
                y: rect.origin.y + yOffset,
                width: rect.width,
                height: max(boundingRect.height + 4, rect.height) // 4pxのマージンを追加
            )
        }
        
        
        // テキストを描画
        attrString.draw(with: drawRect, options: options, context: nil)
        
        context.restoreGState()
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
        
        // 効果のコピー（TextEffect は参照型のため現状は浅いコピー）
        // 将来的に保存処理以外で個別編集する場合は deep copy 化を検討する
        copy.effects = effects
        
        return copy
    }
}
