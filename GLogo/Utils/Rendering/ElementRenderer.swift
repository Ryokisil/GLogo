////
////  ElementRenderer.swift
////  GameLogoMaker
////
////  概要:
////  このファイルは個々のロゴ要素（テキスト、図形、画像）のレンダリング機能を拡張し、
////  特殊効果や最適化されたレンダリングのための追加機能を提供します。
////  CanvasRendererと連携して、高品質なロゴ出力を実現します。
////
//
//import UIKit
//import CoreGraphics
//
///// 要素レンダリングユーティリティ
//class ElementRenderer {
//    
//    // MARK: - 要素レンダリング
//    
//    /// 要素を個別にレンダリングしてUIImageとして返す
//    static func renderElement(_ element: LogoElement, backgroundColor: UIColor? = nil) -> UIImage? {
//        // 要素の境界矩形を取得（回転を考慮）
//        let bounds = calculateRenderBounds(for: element)
//        
//        // UIGraphicsImageRendererを使用して描画
//        let renderer = UIGraphicsImageRenderer(bounds: bounds)
//        
//        return renderer.image { context in
//            let cgContext = context.cgContext
//            
//            // 背景を描画（指定されている場合）
//            if let backgroundColor = backgroundColor {
//                cgContext.setFillColor(backgroundColor.cgColor)
//                cgContext.fill(bounds)
//            }
//            
//            // 要素の元の位置を保存
//            let originalPosition = element.position
//            
//            // 要素の位置を一時的に調整してレンダリング領域内に配置
//            var adjustedElement = element
//            adjustedElement.position = CGPoint(
//                x: adjustedElement.position.x - bounds.origin.x,
//                y: adjustedElement.position.y - bounds.origin.y
//            )
//            
//            // 要素を描画
//            adjustedElement.draw(in: cgContext)
//            
//            // 要素の位置を元に戻す（要素自体を変更しないため）
//            adjustedElement.position = originalPosition
//        }
//    }
//    
//    /// 要素の境界矩形を計算（回転を考慮）
//    private static func calculateRenderBounds(for element: LogoElement) -> CGRect {
//        var bounds = element.frame
//        
//        // 回転がある場合、適切な境界矩形を計算
//        if element.rotation != 0 {
//            // 回転後の矩形を計算
//            let center = CGPoint(x: bounds.midX, y: bounds.midY)
//            
//            // 四隅の点を取得
//            let topLeft = CGPoint(x: bounds.minX, y: bounds.minY)
//                .rotated(around: center, angle: element.rotation)
//            let topRight = CGPoint(x: bounds.maxX, y: bounds.minY)
//                .rotated(around: center, angle: element.rotation)
//            let bottomLeft = CGPoint(x: bounds.minX, y: bounds.maxY)
//                .rotated(around: center, angle: element.rotation)
//            let bottomRight = CGPoint(x: bounds.maxX, y: bounds.maxY)
//                .rotated(around: center, angle: element.rotation)
//            
//            // 回転後の点から最小と最大のX,Y座標を見つける
//            let points = [topLeft, topRight, bottomLeft, bottomRight]
//            let minX = points.min { $0.x < $1.x }?.x ?? bounds.minX
//            let maxX = points.max { $0.x < $1.x }?.x ?? bounds.maxX
//            let minY = points.min { $0.y < $1.y }?.y ?? bounds.minY
//            let maxY = points.max { $0.y < $1.y }?.y ?? bounds.maxY
//            
//            // 新しい境界矩形を作成
//            bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
//        }
//        
//        // 余白を追加（効果やシャドウが切れないように）
//        let padding: CGFloat = 20
//        return bounds.insetBy(dx: -padding, dy: -padding)
//    }
//    
//    // MARK: - テキストレンダリング拡張
//    
//    /// テキスト要素に特殊効果を適用してレンダリング
//    static func renderTextWithEffects(_ textElement: TextElement, additionalEffects: [TextEffect] = []) -> UIImage? {
//        // オリジナルのエフェクトを保存
//        let originalEffects = textElement.effects
//        
//        // 追加のエフェクトを適用
//        if !additionalEffects.isEmpty {
//            var combinedEffects = originalEffects
//            combinedEffects.append(contentsOf: additionalEffects)
//            textElement.effects = combinedEffects
//        }
//        
//        // レンダリング
//        let result = renderElement(textElement)
//        
//        // 元のエフェクトに戻す
//        textElement.effects = originalEffects
//        
//        return result
//    }
//    
//    /// 3Dテキスト効果を適用
//    static func render3DText(_ textElement: TextElement, depth: CGFloat = 5.0, depthColor: UIColor = .black) -> UIImage? {
//        // レンダリング用のキャンバスサイズを計算
//        let bounds = calculateRenderBounds(for: textElement)
//        let size = CGSize(width: bounds.width + depth, height: bounds.height + depth)
//        
//        let renderer = UIGraphicsImageRenderer(size: size)
//        
//        return renderer.image { context in
//            let cgContext = context.cgContext
//            
//            // 奥行き部分を描画
//            for i in stride(from: depth, to: 0, by: -1) {
//                let shadowOpacity = 0.8 - (i / depth) * 0.5
//                
//                var depthTextElement = textElement
//                depthTextElement.position = CGPoint(
//                    x: textElement.position.x - bounds.origin.x + i,
//                    y: textElement.position.y - bounds.origin.y + i
//                )
//                depthTextElement.textColor = depthColor.withAlphaComponent(CGFloat(shadowOpacity))
//                
//                // テキストの効果を一時的に無効化（重複を避ける）
//                let originalEffects = depthTextElement.effects
//                depthTextElement.effects = []
//                
//                // 奥行き部分を描画
//                depthTextElement.draw(in: cgContext)
//                
//                // 効果を戻す
//                depthTextElement.effects = originalEffects
//            }
//            
//            // オリジナルテキストを描画
//            var originalTextElement = textElement
//            originalTextElement.position = CGPoint(
//                x: textElement.position.x - bounds.origin.x,
//                y: textElement.position.y - bounds.origin.y
//            )
//            originalTextElement.draw(in: cgContext)
//        }
//    }
//    
//    // MARK: - 図形レンダリング拡張
//    
//    /// グラデーションオーバーレイ効果のある図形を描画
//    static func renderShapeWithGradientOverlay(_ shapeElement: ShapeElement, startColor: UIColor, endColor: UIColor, angle: CGFloat = 0) -> UIImage? {
//        // オリジナルの設定を保存
//        let originalFillMode = shapeElement.fillMode
//        let originalFillColor = shapeElement.fillColor
//        let originalGradientStart = shapeElement.gradientStartColor
//        let originalGradientEnd = shapeElement.gradientEndColor
//        let originalGradientAngle = shapeElement.gradientAngle
//        
//        // グラデーション設定を適用
//        shapeElement.fillMode = .gradient
//        shapeElement.gradientStartColor = startColor
//        shapeElement.gradientEndColor = endColor
//        shapeElement.gradientAngle = angle
//        
//        // レンダリング
//        let result = renderElement(shapeElement)
//        
//        // 元の設定に戻す
//        shapeElement.fillMode = originalFillMode
//        shapeElement.fillColor = originalFillColor
//        shapeElement.gradientStartColor = originalGradientStart
//        shapeElement.gradientEndColor = originalGradientEnd
//        shapeElement.gradientAngle = originalGradientAngle
//        
//        return result
//    }
//    
//    /// テクスチャオーバーレイ効果のある図形を描画
//    static func renderShapeWithTextureOverlay(_ shapeElement: ShapeElement, texture: UIImage, blendMode: CGBlendMode = .overlay, alpha: CGFloat = 0.5) -> UIImage? {
//        // 通常の図形をレンダリング
//        guard let shapeImage = renderElement(shapeElement, backgroundColor: nil) else {
//            return nil
//        }
//        
//        // UIGraphicsImageRendererを使用してテクスチャを適用
//        let renderer = UIGraphicsImageRenderer(size: shapeImage.size)
//        
//        return renderer.image { context in
//            let cgContext = context.cgContext
//            
//            // 図形を描画
//            shapeImage.draw(in: CGRect(origin: .zero, size: shapeImage.size))
//            
//            // テクスチャを適切なブレンドモードで描画
//            cgContext.saveGState()
//            cgContext.setAlpha(alpha)
//            cgContext.setBlendMode(blendMode)
//            
//            // テクスチャを図形のサイズに合わせて描画
//            texture.draw(in: CGRect(origin: .zero, size: shapeImage.size))
//            
//            cgContext.restoreGState()
//        }
//    }
//    
//    // MARK: - 画像レンダリング拡張
//    
//    /// リフレクション効果のある画像を描画
//    static func renderImageWithReflection(_ imageElement: ImageElement, reflectionHeight: CGFloat = 0.5, opacity: CGFloat = 0.5, fadeFactor: CGFloat = 0.8) -> UIImage? {
//        guard let elementImage = renderElement(imageElement) else {
//            return nil
//        }
//        
//        let totalHeight = elementImage.size.height * (1.0 + reflectionHeight)
//        let renderer = UIGraphicsImageRenderer(size: CGSize(width: elementImage.size.width, height: totalHeight))
//        
//        return renderer.image { context in
//            let cgContext = context.cgContext
//            
//            // オリジナル画像を描画
//            elementImage.draw(at: .zero)
//            
//            // リフレクション用の位置を計算
//            let reflectionRect = CGRect(
//                x: 0,
//                y: elementImage.size.height,
//                width: elementImage.size.width,
//                height: elementImage.size.height * reflectionHeight
//            )
//            
//            // リフレクション用のコンテキスト設定
//            cgContext.saveGState()
//            
//            // リフレクション領域をクリップ
//            cgContext.clip(to: reflectionRect)
//            
//            // 反転して描画
//            cgContext.translateBy(x: 0, y: totalHeight)
//            cgContext.scaleBy(x: 1.0, y: -1.0)
//            elementImage.draw(in: CGRect(x: 0, y: 0, width: elementImage.size.width, height: elementImage.size.height))
//            
//            // グラデーションマスクを適用
//            let colors = [
//                UIColor.white.withAlphaComponent(opacity).cgColor,
//                UIColor.white.withAlphaComponent(0).cgColor
//            ] as CFArray
//            
//            let locations: [CGFloat] = [0.0, fadeFactor]
//            
//            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
//                cgContext.setBlendMode(.sourceIn)
//                
//                let startPoint = CGPoint(x: 0, y: reflectionRect.minY)
//                let endPoint = CGPoint(x: 0, y: reflectionRect.maxY)
//                
//                cgContext.drawLinearGradient(
//                    gradient,
//                    start: startPoint,
//                    end: endPoint,
//                    options: []
//                )
//            }
//            
//            cgContext.restoreGState()
//        }
//    }
//    
//    /// 画像にフレームとシャドウを適用
//    static func renderImageWithFrameAndShadow(_ imageElement: ImageElement, frameWidth: CGFloat = 10, frameColor: UIColor = .white, shadowRadius: CGFloat = 8, shadowColor: UIColor = UIColor.black.withAlphaComponent(0.5)) -> UIImage? {
//        // オリジナルの設定を保存
//        let originalShowFrame = imageElement.showFrame
//        let originalFrameWidth = imageElement.frameWidth
//        let originalFrameColor = imageElement.frameColor
//        
//        // フレーム設定を適用
//        imageElement.showFrame = true
//        imageElement.frameWidth = frameWidth
//        imageElement.frameColor = frameColor
//        
//        // レンダリング領域を計算（シャドウのための余白を含む）
//        let bounds = calculateRenderBounds(for: imageElement)
//        let paddedSize = CGSize(
//            width: bounds.width + shadowRadius * 2,
//            height: bounds.height + shadowRadius * 2
//        )
//        
//        let renderer = UIGraphicsImageRenderer(size: paddedSize)
//        
//        let result = renderer.image { context in
//            let cgContext = context.cgContext
//            
//            // シャドウ設定
//            cgContext.setShadow(
//                offset: CGSize(width: 0, height: 0),
//                blur: shadowRadius,
//                color: shadowColor.cgColor
//            )
//            
//            // 位置を調整して描画
//            var adjustedElement = imageElement
//            adjustedElement.position = CGPoint(
//                x: imageElement.position.x - bounds.origin.x + shadowRadius,
//                y: imageElement.position.y - bounds.origin.y + shadowRadius
//            )
//            
//            // 要素を描画
//            adjustedElement.draw(in: cgContext)
//        }
//        
//        // 元の設定に戻す
//        imageElement.showFrame = originalShowFrame
//        imageElement.frameWidth = originalFrameWidth
//        imageElement.frameColor = originalFrameColor
//        
//        return result
//    }
//}
