//
//  ShapeElement.swift
//  GameLogoMaker
//
//  概要:
//  このファイルは図形要素を表すモデルクラスを定義しています。
//  LogoElementを継承し、四角形、円、三角形、星、多角形などの基本図形と
//  それらの塗りつぶし色、グラデーション、枠線などのプロパティを管理します。
//  また、各図形タイプに応じたパスの生成と描画処理も実装しています。
//

import Foundation
import UIKit

/// 図形の種類を表す列挙型
enum ShapeType: String, Codable {
    case rectangle
    case roundedRectangle
    case circle
    case ellipse
    case triangle
    case star
    case polygon
    case custom // カスタムパス
}

/// 図形の塗りつぶしモードを表す列挙型
enum FillMode: String, Codable {
    case none
    case solid
    case gradient
}

/// 図形の枠線モードを表す列挙型
enum StrokeMode: String, Codable {
    case none
    case solid
}

/// 図形要素クラス
class ShapeElement: LogoElement {
    /// 図形の種類
    var shapeType: ShapeType = .rectangle
    
    /// 図形の塗りつぶしモード
    var fillMode: FillMode = .solid
    
    /// 図形の塗りつぶし色
    var fillColor: UIColor = .white
    
    /// グラデーション開始色
    var gradientStartColor: UIColor = .blue
    
    /// グラデーション終了色
    var gradientEndColor: UIColor = .purple
    
    /// グラデーションの角度（度数）
    var gradientAngle: CGFloat = 0
    
    /// 枠線モード
    var strokeMode: StrokeMode = .solid
    
    /// 枠線の色
    var strokeColor: UIColor = .black
    
    /// 枠線の太さ
    var strokeWidth: CGFloat = 2.0
    
    /// 角丸の半径（角丸四角形の場合）
    var cornerRadius: CGFloat = 10.0
    
    /// 多角形の辺の数（星や多角形の場合）
    var sides: Int = 5
    
    /// カスタムパスのポイント（カスタム図形の場合）
    var customPoints: [CGPoint] = []
    
    /// 要素の種類
    override var type: LogoElementType {
        return .shape
    }
    
    /// エンコード用のコーディングキー
    private enum ShapeCodingKeys: String, CodingKey {
        case shapeType, fillMode, strokeMode, strokeWidth, cornerRadius, sides
        case fillColorData, strokeColorData, gradientStartColorData, gradientEndColorData, gradientAngle
        case customPointsX, customPointsY
    }
    
    /// カスタムエンコーダー
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var container = encoder.container(keyedBy: ShapeCodingKeys.self)
        try container.encode(shapeType, forKey: .shapeType)
        try container.encode(fillMode, forKey: .fillMode)
        try container.encode(strokeMode, forKey: .strokeMode)
        try container.encode(strokeWidth, forKey: .strokeWidth)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(sides, forKey: .sides)
        try container.encode(gradientAngle, forKey: .gradientAngle)
        
        // UIColorのエンコード
        let fillColorData = try NSKeyedArchiver.archivedData(withRootObject: fillColor, requiringSecureCoding: false)
        try container.encode(fillColorData, forKey: .fillColorData)
        
        let strokeColorData = try NSKeyedArchiver.archivedData(withRootObject: strokeColor, requiringSecureCoding: false)
        try container.encode(strokeColorData, forKey: .strokeColorData)
        
        let gradientStartColorData = try NSKeyedArchiver.archivedData(withRootObject: gradientStartColor, requiringSecureCoding: false)
        try container.encode(gradientStartColorData, forKey: .gradientStartColorData)
        
        let gradientEndColorData = try NSKeyedArchiver.archivedData(withRootObject: gradientEndColor, requiringSecureCoding: false)
        try container.encode(gradientEndColorData, forKey: .gradientEndColorData)
        
        // カスタムポイントのエンコード
        if !customPoints.isEmpty {
            let xValues = customPoints.map { $0.x }
            let yValues = customPoints.map { $0.y }
            try container.encode(xValues, forKey: .customPointsX)
            try container.encode(yValues, forKey: .customPointsY)
        }
    }
    
    /// カスタムデコーダー
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        
        let container = try decoder.container(keyedBy: ShapeCodingKeys.self)
        shapeType = try container.decode(ShapeType.self, forKey: .shapeType)
        fillMode = try container.decode(FillMode.self, forKey: .fillMode)
        strokeMode = try container.decode(StrokeMode.self, forKey: .strokeMode)
        strokeWidth = try container.decode(CGFloat.self, forKey: .strokeWidth)
        cornerRadius = try container.decode(CGFloat.self, forKey: .cornerRadius)
        sides = try container.decode(Int.self, forKey: .sides)
        gradientAngle = try container.decode(CGFloat.self, forKey: .gradientAngle)
        
        // UIColorのデコード
        if let fillColorData = try? container.decode(Data.self, forKey: .fillColorData),
           let decodedFillColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: fillColorData) {
            fillColor = decodedFillColor
        }
        
        if let strokeColorData = try? container.decode(Data.self, forKey: .strokeColorData),
           let decodedStrokeColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: strokeColorData) {
            strokeColor = decodedStrokeColor
        }
        
        if let gradientStartColorData = try? container.decode(Data.self, forKey: .gradientStartColorData),
           let decodedStartColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: gradientStartColorData) {
            gradientStartColor = decodedStartColor
        }
        
        if let gradientEndColorData = try? container.decode(Data.self, forKey: .gradientEndColorData),
           let decodedEndColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: gradientEndColorData) {
            gradientEndColor = decodedEndColor
        }
        
        // カスタムポイントのデコード
        if let xValues = try? container.decode([CGFloat].self, forKey: .customPointsX),
           let yValues = try? container.decode([CGFloat].self, forKey: .customPointsY),
           xValues.count == yValues.count {
            customPoints = zip(xValues, yValues).map { CGPoint(x: $0, y: $1) }
        }
    }
    
    /// 初期化メソッド
    init(shapeType: ShapeType, fillColor: UIColor = .white) {
        super.init(name: "\(shapeType.rawValue.capitalized) Shape")
        self.shapeType = shapeType
        self.fillColor = fillColor
    }
    
    /// パスを作成
    func createPath() -> UIBezierPath {
        let rect = CGRect(origin: .zero, size: size)
        let path = UIBezierPath()
        
        switch shapeType {
        case .rectangle:
            path.append(UIBezierPath(rect: rect))
            
        case .roundedRectangle:
            path.append(UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius))
            
        case .circle:
            let diameter = min(size.width, size.height)
            let circleRect = CGRect(
                x: (size.width - diameter) / 2,
                y: (size.height - diameter) / 2,
                width: diameter,
                height: diameter
            )
            path.append(UIBezierPath(ovalIn: circleRect))
            
        case .ellipse:
            path.append(UIBezierPath(ovalIn: rect))
            
        case .triangle:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.close()
            
        case .star:
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outerRadius = min(rect.width, rect.height) / 2
            let innerRadius = outerRadius * 0.4
            
            let pointCount = max(5, sides) * 2
            
            path.move(to: CGPoint(
                x: center.x + outerRadius * cos(0),
                y: center.y + outerRadius * sin(0)
            ))
            
            for i in 1..<pointCount {
                let radius = i % 2 == 0 ? outerRadius : innerRadius
                let angle = CGFloat(i) * .pi * 2 / CGFloat(pointCount)
                
                path.addLine(to: CGPoint(
                    x: center.x + radius * cos(angle),
                    y: center.y + radius * sin(angle)
                ))
            }
            path.close()
            
        case .polygon:
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            
            let angleIncrement = 2 * .pi / CGFloat(sides)
            
            path.move(to: CGPoint(
                x: center.x + radius * cos(0),
                y: center.y + radius * sin(0)
            ))
            
            for i in 1..<sides {
                let angle = CGFloat(i) * angleIncrement
                path.addLine(to: CGPoint(
                    x: center.x + radius * cos(angle),
                    y: center.y + radius * sin(angle)
                ))
            }
            path.close()
            
        case .custom:
            if !customPoints.isEmpty {
                // 最初のポイントに移動
                path.move(to: scalePoint(customPoints[0]))
                
                // 残りのポイントに線を引く
                for i in 1..<customPoints.count {
                    path.addLine(to: scalePoint(customPoints[i]))
                }
                
                path.close()
            }
        }
        
        return path
    }
    
    /// カスタムポイントをサイズに合わせてスケーリング
    private func scalePoint(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
    
    /// グラデーションを描画
    private func drawGradient(in context: CGContext, path: UIBezierPath) {
        // グラデーションカラースペースの作成
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        
        // グラデーションカラーの設定
        let colors = [gradientStartColor.cgColor, gradientEndColor.cgColor] as CFArray
        
        // グラデーションの位置の設定
        let locations: [CGFloat] = [0.0, 1.0]
        
        // グラデーションの作成
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
        
        // パスをクリッピング領域として設定
        context.saveGState()
        path.addClip()
        
        // グラデーションの描画領域
        let bounds = path.bounds
        
        // グラデーションの角度に基づいて開始点と終了点を計算
        let angle = gradientAngle * .pi / 180
        let distance = hypot(bounds.width, bounds.height)
        
        let centerX = bounds.midX
        let centerY = bounds.midY
        
        let startPoint = CGPoint(
            x: centerX - cos(angle) * distance / 2,
            y: centerY - sin(angle) * distance / 2
        )
        
        let endPoint = CGPoint(
            x: centerX + cos(angle) * distance / 2,
            y: centerY + sin(angle) * distance / 2
        )
        
        // グラデーションの描画
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: []
        )
        
        context.restoreGState()
    }
    
    /// 図形を描画
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
        context.translateBy(x: -size.width / 2, y: -size.height / 2)
        
        // パスの作成
        let path = createPath()
        
        // 図形の塗りつぶし
        if fillMode != .none {
            context.saveGState()
            
            if fillMode == .solid {
                // 単色塗りつぶし
                fillColor.setFill()
                path.fill()
            } else if fillMode == .gradient {
                // グラデーション塗りつぶし
                drawGradient(in: context, path: path)
            }
            
            context.restoreGState()
        }
        
        // 図形の枠線
        if strokeMode != .none && strokeWidth > 0 {
            context.saveGState()
            
            strokeColor.setStroke()
            context.setLineWidth(strokeWidth)
            path.stroke()
            
            context.restoreGState()
        }
        
        context.restoreGState()
    }
    
    /// 要素のコピーを作成
    override func copy() -> LogoElement {
        let copy = ShapeElement(shapeType: shapeType, fillColor: fillColor)
        copy.position = position
        copy.size = size
        copy.rotation = rotation
        copy.opacity = opacity
        copy.name = "\(name) Copy"
        copy.isVisible = isVisible
        copy.isLocked = isLocked
        
        copy.fillMode = fillMode
        copy.strokeMode = strokeMode
        copy.strokeColor = strokeColor
        copy.strokeWidth = strokeWidth
        copy.cornerRadius = cornerRadius
        copy.sides = sides
        
        copy.gradientStartColor = gradientStartColor
        copy.gradientEndColor = gradientEndColor
        copy.gradientAngle = gradientAngle
        
        copy.customPoints = customPoints
        
        return copy
    }
}
