// ImageFilterUtility.swift

import UIKit
import CoreImage

/// 画像フィルター処理を提供するユーティリティクラス
class ImageFilterUtility {
    
    /// 共有の作業カラースペース（sRGBで統一）
    static let workingColorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    
    // 共有CIContext（sRGBで色管理を揃える）
    private static let sharedContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .workingColorSpace: workingColorSpace,
            .outputColorSpace: workingColorSpace,
            .useSoftwareRenderer: false
        ]
        return CIContext(options: options)
    }()
    
    /// 基本的な色調補正を適用
    static func applyBasicColorAdjustment(to image: CIImage,saturation: CGFloat,brightness: CGFloat,contrast: CGFloat) -> CIImage? {
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey)
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        
        return filter.outputImage
    }

    /// ルミナンス画像（グレースケール）を生成
    /// - Parameters:
    ///   - image: 入力画像
    /// - Returns: ルミナンス画像。生成できない場合は nil
    private static func makeLuminanceImage(from image: CIImage) -> CIImage? {
        guard let luminanceFilter = CIFilter(name: "CIColorMatrix") else { return nil }
        luminanceFilter.setValue(image, forKey: kCIInputImageKey)
        luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputRVector")
        luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputGVector")
        luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputBVector")
        return luminanceFilter.outputImage
    }
    
    /// ハイライトの調整を適用
    static func applyHighlightAdjustment(to image: CIImage, amount: CGFloat) -> CIImage? {
        // 値が0の場合は変更なし - 処理コストを節約するため、早期リターン
        if amount == 0 {
            return image
        }
        
        // 入力値を-1.0〜1.0の範囲に制限 - 予測可能な動作範囲を確保し、極端な値による不自然な結果を防止
        let clampedAmount = max(-1.0, min(1.0, amount))
        
        // ハイライト領域マスクを作成 - 画像の明るい部分のみを対象とするため
        guard let luminanceFilter = CIFilter(name: "CIColorMatrix") else { return image }
        luminanceFilter.setValue(image, forKey: kCIInputImageKey)
        
        // RGB→輝度変換 - 人間の視覚特性に合わせたITU-R BT.709規格の係数を使用
        // R: 0.2126, G: 0.7152, B: 0.0722 は人間の目が緑に最も敏感であることを反映
        luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputRVector")
        luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputGVector")
        luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputBVector")
        
        guard let luminanceImage = luminanceFilter.outputImage else { return image }
        
        if clampedAmount < 0 {
            // ハイライトを暗くする場合 - 明るい部分の詳細を保持しつつ明るさを抑える
            let darkenAmount = abs(clampedAmount)
            
            // ガンマ補正を適用して明るい部分を強調したマスク作成
            // ガンマ値を0.5に設定することで、中間輝度を明るくし、明るい部分をさらに強調
            guard let gammaFilter = CIFilter(name: "CIGammaAdjust") else { return image }
            gammaFilter.setValue(luminanceImage, forKey: kCIInputImageKey)
            gammaFilter.setValue(0.5, forKey: "inputPower") // 1.0未満のガンマ値で明るい部分を強調
            
            guard let maskImage = gammaFilter.outputImage else { return image }
            
            // 露出調整でハイライト部分を下げる - EVを負の値にすることで露出を下げる
            // 0.7の係数は、調整強度を適度に抑えて自然な見た目を維持するため
            guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else { return image }
            exposureFilter.setValue(image, forKey: kCIInputImageKey)
            exposureFilter.setValue(-darkenAmount * 0.7, forKey: kCIInputEVKey) // 負のEV値で露出を下げる
            
            guard let darkened = exposureFilter.outputImage else { return image }
            
            // マスクを使って元画像とブレンド - マスクの明るさに応じて元画像と調整画像を合成
            // これにより画像の明るい部分のみが調整され、暗い部分は元のまま保持される
            guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return darkened }
            blendFilter.setValue(image, forKey: kCIInputImageKey) // 元画像
            blendFilter.setValue(darkened, forKey: kCIInputBackgroundImageKey) // 調整された画像
            blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey) // ハイライトマスク
            
            return blendFilter.outputImage
            
        } else {
            // ハイライトを明るくする場合 - 白飛びを防ぎつつ明るい部分の輝きを増強
            
            // マスク作成 - より明るい部分のみに影響するように
            // 暗くする場合と同じガンマ値0.5を使用し、一貫性のある処理を実現
            guard let gammaFilter = CIFilter(name: "CIGammaAdjust") else { return image }
            gammaFilter.setValue(luminanceImage, forKey: kCIInputImageKey)
            gammaFilter.setValue(0.5, forKey: "inputPower") // 一貫したマスク生成のため同じ値を使用
            
            guard let maskImage = gammaFilter.outputImage else { return image }
            
            // ハイライト部分に色相保持した明るさ調整を適用
            // CIExposureAdjustは色相を維持しながら露出を調整するため、不自然な色変化を防止
            guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else { return image }
            exposureFilter.setValue(image, forKey: kCIInputImageKey)
            exposureFilter.setValue(clampedAmount * 1.7, forKey: kCIInputEVKey) // 正のEV値で露出を上げる
            // 0.8の係数は、調整強度を適度に抑えて白飛びを防止するため
            
            guard let brightened = exposureFilter.outputImage else { return image }
            
            // マスクを使って元画像とブレンド - マスクの明るさに応じて元画像と調整画像を合成
            // これにより画像の明るい部分のみが調整され、暗い部分は元のまま保持される
            // CIBlendWithMaskは透明度に基づくブレンドを行い、滑らかな移行を実現
            guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return brightened }
            blendFilter.setValue(image, forKey: kCIInputImageKey) // 元画像
            blendFilter.setValue(brightened, forKey: kCIInputBackgroundImageKey) // 調整された画像
            blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey) // ハイライトマスク
            
            return blendFilter.outputImage
        }
    }
    
    /// シャドウの調整を適用（saturation等のようにCIFilterに標準機能がない為、ルミナンスマスクフィルタリングで実装）
    static func applyShadowAdjustment(to image: CIImage, amount: CGFloat) -> CIImage? {
        // 値が0の場合は変更なし
        if amount == 0 {
            return image
        }
        
        // 入力値を-1.0〜1.0の範囲に制限
        let clampedAmount = max(-1.0, min(1.0, amount))
        
        if clampedAmount < 0 {
            // シャドウを暗くする場合：CIColorControlsとCIVignetteEffectの組み合わせ
            let darkness = abs(clampedAmount) * 0.5  // 最大で0.5の暗さ（緩やかな変化）
            
            // まず暗い部分をより暗くする（コントラスト調整）
            guard let contrastFilter = CIFilter(name: "CIColorControls") else { return image }
            contrastFilter.setValue(image, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.0 + darkness * 0.3, forKey: kCIInputContrastKey)  // 微小なコントラスト増加
            contrastFilter.setValue(-darkness * 0.1, forKey: kCIInputBrightnessKey)     // 微小な明るさ減少
            
            guard let contrastImage = contrastFilter.outputImage else { return image }
            
            // 暗い部分により効果を出すためのマスク生成
            guard let luminanceFilter = CIFilter(name: "CIColorMatrix") else { return contrastImage }
            luminanceFilter.setValue(image, forKey: kCIInputImageKey)
            
            // RGB→グレースケール変換行列（暗い部分を検出）
            luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputRVector")
            luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputGVector")
            luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputBVector")
            
            guard let luminanceImage = luminanceFilter.outputImage else { return contrastImage }
            
            // 暗い部分のマスクをガンマ補正してシャドウ部分を強調
            guard let gammaFilter = CIFilter(name: "CIGammaAdjust") else { return contrastImage }
            gammaFilter.setValue(luminanceImage, forKey: kCIInputImageKey)
            gammaFilter.setValue(2.0 + darkness * 3.0, forKey: "inputPower")  // ガンマ値を大きくして暗い部分を強調
            
            guard let maskImage = gammaFilter.outputImage else { return contrastImage }
            
            // マスク画像を使ってブレンド
            guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return contrastImage }
            blendFilter.setValue(image, forKey: kCIInputImageKey)  // 元画像
            blendFilter.setValue(contrastImage, forKey: kCIInputBackgroundImageKey)  // コントラスト調整画像
            blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)  // マスク
            
            return blendFilter.outputImage
            
        } else {
            // シャドウを明るくする場合：CIColorCurveとマスクの組み合わせ
            let brightness = clampedAmount * 0.3  // 最大で0.3の明るさ（緩やかな変化）
            
            // まず暗い部分をより明るくする
            guard let brightnessFilter = CIFilter(name: "CIColorControls") else { return image }
            brightnessFilter.setValue(image, forKey: kCIInputImageKey)
            brightnessFilter.setValue(brightness, forKey: kCIInputBrightnessKey)
            
            guard let brightImage = brightnessFilter.outputImage else { return image }
            
            // 暗い部分により効果を出すためのマスク生成（反転）
            guard let luminanceFilter = CIFilter(name: "CIColorMatrix") else { return brightImage }
            luminanceFilter.setValue(image, forKey: kCIInputImageKey)
            
            // RGB→グレースケール変換行列（暗い部分を検出）
            luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputRVector")
            luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputGVector")
            luminanceFilter.setValue(CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0), forKey: "inputBVector")
            
            guard let luminanceImage = luminanceFilter.outputImage else { return brightImage }
            
            // 明るい部分を反転して暗い部分を強調
            guard let invertFilter = CIFilter(name: "CIColorInvert") else { return brightImage }
            invertFilter.setValue(luminanceImage, forKey: kCIInputImageKey)
            
            guard let invertedImage = invertFilter.outputImage else { return brightImage }
            
            // ガンマ補正で中間〜暗い部分をさらに強調
            guard let gammaFilter = CIFilter(name: "CIGammaAdjust") else { return brightImage }
            gammaFilter.setValue(invertedImage, forKey: kCIInputImageKey)
            gammaFilter.setValue(1.5, forKey: "inputPower")
            
            guard let maskImage = gammaFilter.outputImage else { return brightImage }
            
            // マスク画像を使ってブレンド
            guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return brightImage }
            blendFilter.setValue(image, forKey: kCIInputImageKey)  // 元画像
            blendFilter.setValue(brightImage, forKey: kCIInputBackgroundImageKey)  // 明るさ調整画像
            blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)  // マスク
            
            return blendFilter.outputImage
        }
    }

    /// 黒レベル調整を適用（暗部端点の締まり/持ち上げ）
    /// - Parameters:
    ///   - image: 入力画像
    ///   - amount: 調整量（-1.0...1.0）
    /// - Returns: 調整後の画像
    static func applyBlackAdjustment(to image: CIImage, amount: CGFloat) -> CIImage? {
        if amount == 0 { return image }

        let clampedAmount = max(-1.0, min(1.0, amount))
        guard let luminanceImage = makeLuminanceImage(from: image) else { return image }

        // 暗部優先マスク（ルミナンス反転）
        guard let invertFilter = CIFilter(name: "CIColorInvert") else { return image }
        invertFilter.setValue(luminanceImage, forKey: kCIInputImageKey)
        guard let inverted = invertFilter.outputImage else { return image }

        guard let gammaFilter = CIFilter(name: "CIGammaAdjust") else { return image }
        gammaFilter.setValue(inverted, forKey: kCIInputImageKey)
        gammaFilter.setValue(1.8, forKey: "inputPower")
        guard let darkMask = gammaFilter.outputImage else { return image }

        let adjustedImage: CIImage?
        if clampedAmount > 0 {
            // 黒を締める（暗部をわずかに下げる）
            guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else { return image }
            exposureFilter.setValue(image, forKey: kCIInputImageKey)
            exposureFilter.setValue(-clampedAmount * 0.8, forKey: kCIInputEVKey)
            adjustedImage = exposureFilter.outputImage
        } else {
            // 黒を持ち上げる（暗部を持ち上げる）
            guard let colorFilter = CIFilter(name: "CIColorControls") else { return image }
            colorFilter.setValue(image, forKey: kCIInputImageKey)
            colorFilter.setValue(abs(clampedAmount) * 0.25, forKey: kCIInputBrightnessKey)
            adjustedImage = colorFilter.outputImage
        }

        guard let target = adjustedImage,
              let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            return image
        }
        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(target, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(darkMask, forKey: kCIInputMaskImageKey)
        return blendFilter.outputImage
    }

    /// 白レベル調整を適用（明部端点の伸び/抑制）
    /// - Parameters:
    ///   - image: 入力画像
    ///   - amount: 調整量（-1.0...1.0）
    /// - Returns: 調整後の画像
    static func applyWhiteAdjustment(to image: CIImage, amount: CGFloat) -> CIImage? {
        if amount == 0 { return image }

        let clampedAmount = max(-1.0, min(1.0, amount))
        guard let luminanceImage = makeLuminanceImage(from: image) else { return image }

        // 明部優先マスク
        guard let gammaFilter = CIFilter(name: "CIGammaAdjust") else { return image }
        gammaFilter.setValue(luminanceImage, forKey: kCIInputImageKey)
        gammaFilter.setValue(0.6, forKey: "inputPower")
        guard let highlightMask = gammaFilter.outputImage else { return image }

        let adjustedImage: CIImage?
        if clampedAmount > 0 {
            // 白を伸ばす（明部をわずかに押し上げる）
            guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else { return image }
            exposureFilter.setValue(image, forKey: kCIInputImageKey)
            exposureFilter.setValue(clampedAmount * 0.8, forKey: kCIInputEVKey)
            adjustedImage = exposureFilter.outputImage
        } else {
            // 白を抑える（白飛びを軽減）
            guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else { return image }
            exposureFilter.setValue(image, forKey: kCIInputImageKey)
            exposureFilter.setValue(-abs(clampedAmount) * 0.6, forKey: kCIInputEVKey)
            adjustedImage = exposureFilter.outputImage
        }

        guard let target = adjustedImage,
              let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            return image
        }
        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(target, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(highlightMask, forKey: kCIInputMaskImageKey)
        return blendFilter.outputImage
    }
    
    /// 色温度（Warmth）調整を適用
    /// - Parameters:
    ///   - image: 入力画像
    ///   - warmth: 調整量（-100...100）
    /// - Returns: 調整後の画像。フィルター生成に失敗した場合は nil
    static func applyWarmthAdjustment(to image: CIImage, warmth: CGFloat) -> CIImage? {
        if warmth == 0 {
            return image
        }
        guard let filter = CIFilter(name: "CITemperatureAndTint") else { return nil }

        // 温度調整値を変換（-100〜100をおおよそ3000K〜10000Kへ）
        let clampedWarmth = max(-100.0, min(100.0, warmth))
        let neutralTemperature: CGFloat = 6500
        let vector = CIVector(x: neutralTemperature + (clampedWarmth * 35.0), y: 0)
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(vector, forKey: "inputTargetNeutral")
        
        return filter.outputImage
    }

    /// ヴィブランス調整を適用
    /// - Parameters:
    ///   - image: 入力画像
    ///   - amount: 調整量（-1.0...1.0）
    /// - Returns: 調整後の画像。フィルター生成に失敗した場合は nil
    static func applyVibranceAdjustment(to image: CIImage, amount: CGFloat) -> CIImage? {
        if amount == 0 {
            return image
        }
        guard let filter = CIFilter(name: "CIVibrance") else { return nil }

        let clampedAmount = max(-1.0, min(1.0, amount))
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(clampedAmount, forKey: "inputAmount")
        return filter.outputImage
    }
    
    /// 色相調整を適用
    static func applyHueAdjustment(to image: CIImage, angle: CGFloat) -> CIImage? {
        // 値が0の場合は変更なし - 処理コストを節約するため、早期リターン
        if angle == 0 {
            return image
        }
        
        // 入力値を-180〜180度の範囲に制限し、ラジアンに変換
        let clampedAngle = max(-180.0, min(180.0, angle))
        let radians = clampedAngle * .pi / 180.0
        
        // 色相調整フィルターを作成
        guard let filter = CIFilter(name: "CIHueAdjust") else { return nil }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(radians, forKey: kCIInputAngleKey)
        
        return filter.outputImage
    }
    
    /// シャープネス調整を適用
    static func applySharpness(to image: CIImage, intensity: CGFloat) -> CIImage? {
        // 値が0の場合は変更なし - 処理コストを節約するため、早期リターン
        if intensity == 0 {
            return image
        }
        
        // 入力値を0.0〜2.0の範囲に制限（安全な範囲）
        let clampedIntensity = max(0.0, min(2.0, intensity))
        
        // まずCISharpenLuminanceを試す
        if let filter = CIFilter(name: "CISharpenLuminance") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(clampedIntensity, forKey: "inputSharpness")
            
            if let output = filter.outputImage {
                return output
            }
        }
        
        // CISharpenLuminanceが失敗した場合、CIUnsharpMaskを使用
        guard let filter = CIFilter(name: "CIUnsharpMask") else {
            return image
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(clampedIntensity, forKey: "inputIntensity")
        filter.setValue(1.0, forKey: "inputRadius")
        filter.setValue(0.0, forKey: "inputThreshold")
        
        return filter.outputImage
    }
    
    /// ガウシアンブラーを適用
    static func applyGaussianBlur(to image: CIImage, radius: CGFloat) -> CIImage? {
        // 値が0の場合は変更なし - 処理コストを節約するため、早期リターン
        if radius == 0 {
            return image
        }

        // 入力値を0.0〜10.0の範囲に制限（ロゴ制作に適した範囲）
        let clampedRadius = max(0.0, min(10.0, radius))

        // 元の画像の範囲を保存
        let originalExtent = image.extent

        // ガウシアンブラーフィルターを作成
        guard let filter = CIFilter(name: "CIGaussianBlur") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(clampedRadius, forKey: kCIInputRadiusKey)

        guard let blurredImage = filter.outputImage else {
            return image
        }

        // 元の画像サイズにクロップして範囲を復元
        return blurredImage.cropped(to: originalExtent)
    }

    /// 背景ぼかし合成を適用
    /// - Parameters:
    ///   - image: 元画像（CIImage）
    ///   - maskImage: 前景マスク画像（白＝前景、黒＝背景）
    ///   - radius: ぼかし半径
    /// - Returns: 背景がぼかされた合成画像
    static func applyBackgroundBlur(to image: CIImage, mask maskImage: CIImage, radius: CGFloat) -> CIImage? {
        // 半径が0の場合は変更なし
        if radius == 0 {
            return image
        }

        // ぼかし半径を0〜50の範囲に制限（背景ぼかし用により広い範囲）
        let clampedRadius = max(0.0, min(50.0, radius))

        // 元の画像の範囲を保存
        let originalExtent = image.extent

        // 背景用にぼかした画像を生成
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            return image
        }
        blurFilter.setValue(image, forKey: kCIInputImageKey)
        blurFilter.setValue(clampedRadius, forKey: kCIInputRadiusKey)

        guard let blurredImage = blurFilter.outputImage?.cropped(to: originalExtent) else {
            return image
        }

        // マスクを画像サイズにスケーリング
        let scaledMask = maskImage.transformed(by: CGAffineTransform(
            scaleX: originalExtent.width / maskImage.extent.width,
            y: originalExtent.height / maskImage.extent.height
        ))

        // CIBlendWithMaskで合成
        // input: 前景画像（元画像）
        // background: 背景画像（ぼかし画像）
        // mask: マスク（白＝前景、黒＝背景）
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            return image
        }
        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(blurredImage, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(scaledMask, forKey: kCIInputMaskImageKey)

        return blendFilter.outputImage?.cropped(to: originalExtent)
    }

    /// 背景ぼかし合成を適用（UIImage版）
    /// - Parameters:
    ///   - image: 元画像
    ///   - maskData: 前景マスクのPNGデータ
    ///   - radius: ぼかし半径
    /// - Returns: 背景がぼかされた合成画像
    static func applyBackgroundBlur(to image: UIImage, maskData: Data, radius: CGFloat) -> UIImage? {
        guard let cgImage = image.cgImage,
              let maskUIImage = UIImage(data: maskData),
              let maskCGImage = maskUIImage.cgImage else {
            return image
        }

        let ciImage = CIImage(cgImage: cgImage)
        let maskCIImage = CIImage(cgImage: maskCGImage)

        guard let resultCIImage = applyBackgroundBlur(to: ciImage, mask: maskCIImage, radius: radius) else {
            return image
        }

        return convertToUIImage(resultCIImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    /// ティントカラーオーバーレイを適用
    static func applyTintOverlay(to image: UIImage, color: UIColor, intensity: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        let rect = CGRect(origin: .zero, size: image.size)
        image.draw(in: rect)
        
        color.withAlphaComponent(intensity).setFill()
        UIRectFillUsingBlendMode(rect, .overlay)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// CIImageをUIImageに変換
    static func convertToUIImage(_ ciImage: CIImage, scale: CGFloat, orientation: UIImage.Orientation) -> UIImage? {
        guard let cgImage = sharedContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
    }
}

/// 非同期処理
extension ImageFilterUtility {
    /// 非同期で画像にフィルターを適用する
    static func applyFiltersAsync(to image: UIImage,
                                  saturation: CGFloat,
                                  brightness: CGFloat,
                                  contrast: CGFloat,
                                  highlights: CGFloat,
                                  shadows: CGFloat,
                                  blacks: CGFloat,
                                  whites: CGFloat,
                                  warmth: CGFloat,
                                  vibrance: CGFloat,
                                  tintColor: UIColor?,
                                  tintIntensity: CGFloat) async -> UIImage? {
        
        return await Task.detached(priority: .userInitiated) {
            guard let cgImage = image.cgImage else { return image }
            
            // 元のCIImageを作成
            var ciImage = CIImage(cgImage: cgImage)
            
            // 基本的な色調整を適用
            if let adjusted = ImageFilterUtility.applyBasicColorAdjustment(
                to: ciImage,
                saturation: saturation,
                brightness: brightness,
                contrast: contrast
            ) {
                ciImage = adjusted
            }
            
            // ハイライトの調整を適用（値が0でない場合のみ）
            if highlights != 0,
               let adjusted = ImageFilterUtility.applyHighlightAdjustment(
                to: ciImage,
                amount: highlights
               ) {
                ciImage = adjusted
            }
            
            // シャドウの調整を適用（値が0でない場合のみ）
            if shadows != 0,
               let adjusted = ImageFilterUtility.applyShadowAdjustment(
                to: ciImage,
                amount: shadows
               ) {
                ciImage = adjusted
            }

            // 黒レベル調整を適用（値が0でない場合のみ）
            if blacks != 0,
               let adjusted = ImageFilterUtility.applyBlackAdjustment(
                to: ciImage,
                amount: blacks
               ) {
                ciImage = adjusted
            }

            // 白レベル調整を適用（値が0でない場合のみ）
            if whites != 0,
               let adjusted = ImageFilterUtility.applyWhiteAdjustment(
                to: ciImage,
                amount: whites
               ) {
                ciImage = adjusted
            }

            // 色温度調整を適用（値が0でない場合のみ）
            if warmth != 0,
               let adjusted = ImageFilterUtility.applyWarmthAdjustment(
                to: ciImage,
                warmth: warmth
               ) {
                ciImage = adjusted
            }

            // ヴィブランス調整を適用（値が0でない場合のみ）
            if vibrance != 0,
               let adjusted = ImageFilterUtility.applyVibranceAdjustment(
                to: ciImage,
                amount: vibrance
               ) {
                ciImage = adjusted
            }
            
            // CIImageをUIImageに変換
            var filteredImage = ImageFilterUtility.convertToUIImage(
                ciImage,
                scale: image.scale,
                orientation: image.imageOrientation
            ) ?? image
            
            // ティントカラーを適用
            if let tintColor = tintColor, tintIntensity > 0,
               let tinted = ImageFilterUtility.applyTintOverlay(
                to: filteredImage,
                color: tintColor,
                intensity: tintIntensity
               ) {
                filteredImage = tinted
            }
            
            return filteredImage
        }.value
    }
}
