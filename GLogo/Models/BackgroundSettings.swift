//
//  BackgroundSettings.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはロゴプロジェクトの背景設定を管理するモデルクラスを定義しています。
//  単色、グラデーション、画像、透明などの背景タイプと、それぞれのタイプに応じた
//  プロパティ（色、グラデーション方向、画像ファイル名など）を提供します。
//  また、背景の描画処理も実装しています。
//

import Foundation
import UIKit

/// 背景種類の列挙型
enum BackgroundType: String, Codable {
    case solid      // 単色
    case gradient   // グラデーション
    case image      // 画像
    case transparent // 透明
}

/// グラデーションの種類
enum GradientType: String, Codable {
    case linear     // 線形グラデーション
    case radial     // 放射状グラデーション
}

/// グラデーション方向
enum GradientDirection: String, Codable {
    case topToBottom
    case leftToRight
    case diagonal
    case custom     // カスタム角度
}

/// 背景設定を管理するクラス
struct BackgroundSettings: Codable {
    /// 背景タイプ
    var type: BackgroundType = .solid
    
    /// 背景色（単色の場合）
    var color: UIColor = .black
    
    /// 不透明度
    var opacity: CGFloat = 1.0
    
    /// グラデーション開始色
    var gradientStartColor: UIColor = .blue
    
    /// グラデーション終了色
    var gradientEndColor: UIColor = .purple
    
    /// グラデーションタイプ
    var gradientType: GradientType = .linear
    
    /// グラデーション方向
    var gradientDirection: GradientDirection = .topToBottom
    
    /// カスタムグラデーション角度（度数）
    var gradientAngle: CGFloat = 0
    
    /// 背景画像のファイル名
    var imageFileName: String?
    
    /// エンコード用のコーディングキー
    enum CodingKeys: String, CodingKey {
        case type, opacity, gradientType, gradientDirection, gradientAngle, imageFileName
        case colorData, gradientStartColorData, gradientEndColorData
    }
    
    /// カスタムエンコーダー（UIColorのエンコード対応）
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(type, forKey: .type)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(gradientType, forKey: .gradientType)
        try container.encode(gradientDirection, forKey: .gradientDirection)
        try container.encode(gradientAngle, forKey: .gradientAngle)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        
        // UIColorのエンコード
        let colorData = try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
        try container.encode(colorData, forKey: .colorData)
        
        let startColorData = try NSKeyedArchiver.archivedData(withRootObject: gradientStartColor, requiringSecureCoding: false)
        try container.encode(startColorData, forKey: .gradientStartColorData)
        
        let endColorData = try NSKeyedArchiver.archivedData(withRootObject: gradientEndColor, requiringSecureCoding: false)
        try container.encode(endColorData, forKey: .gradientEndColorData)
    }
    
    /// カスタムデコーダー（UIColorのデコード対応）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        type = try container.decode(BackgroundType.self, forKey: .type)
        opacity = try container.decode(CGFloat.self, forKey: .opacity)
        gradientType = try container.decode(GradientType.self, forKey: .gradientType)
        gradientDirection = try container.decode(GradientDirection.self, forKey: .gradientDirection)
        gradientAngle = try container.decode(CGFloat.self, forKey: .gradientAngle)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        
        // UIColorのデコード
        if let colorData = try? container.decode(Data.self, forKey: .colorData),
           let decodedColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData) {
            color = decodedColor
        }
        
        if let startColorData = try? container.decode(Data.self, forKey: .gradientStartColorData),
           let decodedStartColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: startColorData) {
            gradientStartColor = decodedStartColor
        }
        
        if let endColorData = try? container.decode(Data.self, forKey: .gradientEndColorData),
           let decodedEndColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: endColorData) {
            gradientEndColor = decodedEndColor
        }
    }
    
    /// デフォルトイニシャライザ
    init() {}
    
    /// 単色背景用のイニシャライザ
    init(color: UIColor, opacity: CGFloat = 1.0) {
        self.type = .solid
        self.color = color
        self.opacity = opacity
    }
    
    /// グラデーション背景用のイニシャライザ
    init(startColor: UIColor, endColor: UIColor, type: GradientType = .linear, direction: GradientDirection = .topToBottom) {
        self.type = .gradient
        self.gradientStartColor = startColor
        self.gradientEndColor = endColor
        self.gradientType = type
        self.gradientDirection = direction
    }
    
    /// 背景を描画するメソッド
    func draw(in context: CGContext, rect: CGRect) {
        context.saveGState()
        
        // 透明度を設定
        context.setAlpha(opacity)
        
        switch type {
        case .solid:
            // 単色背景
            context.setFillColor(color.cgColor)
            context.fill(rect)
            
        case .gradient:
            // グラデーション背景
            drawGradient(in: context, rect: rect)
            
        case .image:
            // 画像背景
            drawBackgroundImage(in: context, rect: rect)
            
        case .transparent:
            // 透明背景の場合は何も描画しない
            break
        }
        
        context.restoreGState()
    }
    
    /// グラデーションを描画
    private func drawGradient(in context: CGContext, rect: CGRect) {
        // グラデーションカラースペースの作成
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        
        // グラデーションカラーの設定
        let colors = [gradientStartColor.cgColor, gradientEndColor.cgColor] as CFArray
        
        // グラデーションの位置の設定
        let locations: [CGFloat] = [0.0, 1.0]
        
        // グラデーションの作成
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
        
        // グラデーションの開始点と終了点の設定
        var startPoint = CGPoint.zero
        var endPoint = CGPoint.zero
        
        switch gradientType {
        case .linear:
            // 線形グラデーションの方向設定
            switch gradientDirection {
            case .topToBottom:
                startPoint = CGPoint(x: rect.midX, y: rect.minY)
                endPoint = CGPoint(x: rect.midX, y: rect.maxY)
                
            case .leftToRight:
                startPoint = CGPoint(x: rect.minX, y: rect.midY)
                endPoint = CGPoint(x: rect.maxX, y: rect.midY)
                
            case .diagonal:
                startPoint = CGPoint(x: rect.minX, y: rect.minY)
                endPoint = CGPoint(x: rect.maxX, y: rect.maxY)
                
            case .custom:
                // カスタム角度でのグラデーション
                let angle = gradientAngle * .pi / 180 // 度数からラジアンに変換
                let distance = hypot(rect.width, rect.height) / 2
                
                let centerX = rect.midX
                let centerY = rect.midY
                
                startPoint = CGPoint(
                    x: centerX - cos(angle) * distance,
                    y: centerY - sin(angle) * distance
                )
                
                endPoint = CGPoint(
                    x: centerX + cos(angle) * distance,
                    y: centerY + sin(angle) * distance
                )
            }
            
            // 線形グラデーションの描画
            context.drawLinearGradient(
                gradient,
                start: startPoint,
                end: endPoint,
                options: .drawsBeforeStartLocation
            )
            
        case .radial:
            // 放射状グラデーションの設定
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = max(rect.width, rect.height) / 2
            
            // 放射状グラデーションの描画
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: .drawsBeforeStartLocation
            )
        }
    }
    
    /// 背景画像を描画
    private func drawBackgroundImage(in context: CGContext, rect: CGRect) {
        // ファイル名がない場合は終了
        guard let imageFileName = imageFileName else { return }
        
        // まずAssetManagerからの読み込みを試みる
        var image: UIImage? = AssetManager.shared.loadImage(named: imageFileName, type: .background)
        
        // AssetManagerで見つからなかった場合、UIImageから直接読み込む
        if image == nil {
            image = UIImage(named: imageFileName)
        }
        
        // 画像が見つからない場合は終了
        guard let cgImage = image?.cgImage else {
            print("画像が見つかりません: \(imageFileName)")
            return
        }
        
        // 画像をデバッグ情報としてログに出力
        print("背景画像を描画します: \(imageFileName), サイズ: \(image?.size ?? CGSize.zero)")
        
        // 画像を指定された矩形に描画
        context.saveGState()
        context.setAlpha(opacity) // 不透明度を設定
        
        // 画像の描画
        context.draw(cgImage, in: rect)
        
        context.restoreGState()
    }
}
