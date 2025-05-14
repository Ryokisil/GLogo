//
//  CanvasRenderer.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはロゴプロジェクトのキャンバスレンダリング機能を提供します。
//  プロジェクト内のすべての要素（テキスト、図形、画像）を適切な順序と効果で描画し、
//  UIImageとしてエクスポートするための機能を提供します。
//  CoreGraphicsを使用した高品質なレンダリングを実装しています。
//

import UIKit
import CoreGraphics

/// キャンバスレンダリングユーティリティ
class CanvasRenderer {
    /// プロジェクト参照
    private let project: LogoProject
    
    /// レンダリング設定
    private let settings: RenderSettings
    
    /// イニシャライザ
    init(project: LogoProject, settings: RenderSettings = RenderSettings()) {
        self.project = project
        self.settings = settings
    }
    
    /// プロジェクトをUIImageとしてレンダリング
    func renderAsImage() -> UIImage? {
        // レンダリングサイズを決定（スケールファクターを考慮）
        let baseSize = settings.customSize ?? project.canvasSize
        let renderSize = CGSize(
            width: baseSize.width * settings.resolutionScale,
            height: baseSize.height * settings.resolutionScale
        )
        
        // UIGraphicsImageRendererを使用して描画
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // スケールを適用
            if settings.resolutionScale != 1.0 {
                cgContext.scaleBy(x: settings.resolutionScale, y: settings.resolutionScale)
            }
            
            // 背景を描画
            drawBackground(in: cgContext, size: baseSize)
            
            // すべての要素を描画
            for element in project.elements where element.isVisible {
                element.draw(in: cgContext)
            }
            
            // エクスポート時の品質向上のためのポストプロセス
            if settings.applyPostProcessing {
                applyPostProcessing(in: cgContext, size: baseSize)
            }
        }
    }
    
    /// プロジェクトを指定された形式でデータとしてエクスポート
//    func exportData(format: ExportFormat) -> Data? {
//        guard let image = renderAsImage() else { return nil }
//        
//        switch format {
//        case .png:
//            return image.pngData()
//        case .jpg:
//            return image.jpegData(compressionQuality: settings.jpegQuality)
//        }
//    }
    
    // MARK: - 描画メソッド
    
    /// 背景の描画
    private func drawBackground(in context: CGContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        
        if settings.transparentBackground {
            // 透明背景（PNG形式用）
            context.clear(rect)
        } else {
            // プロジェクトの背景設定を使用
            project.backgroundSettings.draw(in: context, rect: rect)
        }
    }
    
    /// ポストプロセスの適用（アンチエイリアスやシャープネスなど）
    private func applyPostProcessing(in context: CGContext, size: CGSize) {
        if settings.applyAntiAliasing {
            // アンチエイリアス設定
            context.setShouldAntialias(true)
            context.setAllowsAntialiasing(true)
        }
        
        // その他のポストプロセス効果をここに追加可能
    }
    
    // MARK: - レンダリング設定構造体
    
    /// レンダリング設定オプション
    struct RenderSettings {
        /// カスタムサイズ（nilの場合はプロジェクトのサイズを使用）
        var customSize: CGSize?
        
        /// 透明背景（PNG形式用）
        var transparentBackground: Bool = false
        
        /// JPEG品質（0.0〜1.0）
        var jpegQuality: CGFloat = 0.9
        
        /// アンチエイリアスを適用
        var applyAntiAliasing: Bool = true
        
        /// ポストプロセスを適用
        var applyPostProcessing: Bool = true
        
        /// 解像度スケール（高解像度出力用）
        var resolutionScale: CGFloat = 1.0
        
        /// スケールしたサイズを取得
        var scaledSize: CGSize? {
            guard let size = customSize else { return nil }
            return CGSize(
                width: size.width * resolutionScale,
                height: size.height * resolutionScale
            )
        }
        
        /// デフォルト設定でイニシャライザ
        init() {}
        
        /// カスタム設定でイニシャライザ
        init(
            customSize: CGSize? = nil,
            transparentBackground: Bool = false,
            jpegQuality: CGFloat = 0.9,
            applyAntiAliasing: Bool = true,
            applyPostProcessing: Bool = true,
            resolutionScale: CGFloat = 1.0
        ) {
            self.customSize = customSize
            self.transparentBackground = transparentBackground
            self.jpegQuality = jpegQuality
            self.applyAntiAliasing = applyAntiAliasing
            self.applyPostProcessing = applyPostProcessing
            self.resolutionScale = resolutionScale
        }
    }
}

// MARK: - 便利な拡張メソッド

extension CanvasRenderer {
//    /// シンプルな設定でプロジェクトをPNGデータとしてエクスポート
//    static func quickExportAsPNG(_ project: LogoProject, transparentBackground: Bool = true) -> Data? {
//        let settings = RenderSettings(transparentBackground: transparentBackground)
//        let renderer = CanvasRenderer(project: project, settings: settings)
//        return renderer.exportData(format: .png)
//    }
//    
//    /// シンプルな設定でプロジェクトをJPEGデータとしてエクスポート
//    static func quickExportAsJPEG(_ project: LogoProject, quality: CGFloat = 0.9) -> Data? {
//        let settings = RenderSettings(transparentBackground: false, jpegQuality: quality)
//        let renderer = CanvasRenderer(project: project, settings: settings)
//        return renderer.exportData(format: .jpg)
//    }
//    
//    /// 高解像度でプロジェクトをエクスポート
//    static func exportHighResolution(_ project: LogoProject, format: ExportFormat, scale: CGFloat = 2.0) -> Data? {
//        let settings = RenderSettings(
//            transparentBackground: format == .png,
//            jpegQuality: 1.0,
//            applyAntiAliasing: true,
//            applyPostProcessing: true,
//            resolutionScale: scale
//        )
//        let renderer = CanvasRenderer(project: project, settings: settings)
//        return renderer.exportData(format: format)
//    }
    
    /// プロジェクトのサムネイル画像を生成
    static func createThumbnail(for project: LogoProject, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage? {
        // 元のキャンバス比率を維持
        let originalSize = project.canvasSize
        let aspectRatio = originalSize.width / originalSize.height
        
        var thumbnailSize = size
        if aspectRatio > 1 {
            thumbnailSize.height = size.width / aspectRatio
        } else {
            thumbnailSize.width = size.height * aspectRatio
        }
        
        let settings = RenderSettings(
            customSize: thumbnailSize,
            transparentBackground: false,
            applyAntiAliasing: true
        )
        
        let renderer = CanvasRenderer(project: project, settings: settings)
        return renderer.renderAsImage()
    }
}

// MARK: - エクスポート形式

/// エクスポート形式の列挙型
//enum ExportFormat {
//    case png
//    case jpg
//    
//    /// ファイル拡張子
//    var fileExtension: String {
//        switch self {
//        case .png: return "png"
//        case .jpg: return "jpg"
//        }
//    }
//    
//    /// MIMEタイプ
//    var mimeType: String {
//        switch self {
//        case .png: return "image/png"
//        case .jpg: return "image/jpeg"
//        }
//    }
//}
