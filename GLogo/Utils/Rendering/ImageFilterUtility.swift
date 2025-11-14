// ImageFilterUtility.swift

import UIKit
import CoreImage

/// 画像フィルター処理を提供するユーティリティクラス
class ImageFilterUtility {
    
    /// 基本的な色調補正を適用
    static func applyBasicColorAdjustment(to image: CIImage,saturation: CGFloat,brightness: CGFloat,contrast: CGFloat) -> CIImage? {
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey)
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        
        return filter.outputImage
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
    
    /// 色温度（Warmth）調整を適用
    static func applyWarmthAdjustment(to image: CIImage, warmth: CGFloat) -> CIImage? {
        guard let filter = CIFilter(name: "CITemperatureAndTint") else { return nil }
        
        // 温度調整値を変換（-100〜100の範囲を適切なベクトルに変換）
        let vector = CIVector(x: 6500 + (warmth * 1500), y: 0)
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(vector, forKey: "inputTargetNeutral")
        
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
            print("DEBUG: シャープネスフィルターが使用できません")
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
            print("DEBUG: CIGaussianBlurフィルターが使用できません")
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

    /// トーンカーブを適用
    static func applyToneCurve(to image: CIImage, points: [CGPoint]) -> CIImage? {
        // 5点未満の場合はスキップ
        guard points.count >= 5 else {
            print("DEBUG: トーンカーブの制御点が不足しています（最低5点必要）")
            return image
        }

        // デフォルトの対角線と同じ場合はスキップ（最適化）
        let isDefault = points[0] == CGPoint(x: 0.0, y: 0.0) &&
                       points[1] == CGPoint(x: 0.25, y: 0.25) &&
                       points[2] == CGPoint(x: 0.5, y: 0.5) &&
                       points[3] == CGPoint(x: 0.75, y: 0.75) &&
                       points[4] == CGPoint(x: 1.0, y: 1.0)

        if isDefault {
            return image
        }

        // CIToneCurveフィルターを作成
        guard let filter = CIFilter(name: "CIToneCurve") else {
            print("DEBUG: CIToneCurveフィルターが使用できません")
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)

        // 5つの制御点をCIVectorとして設定
        filter.setValue(CIVector(x: points[0].x, y: points[0].y), forKey: "inputPoint0")
        filter.setValue(CIVector(x: points[1].x, y: points[1].y), forKey: "inputPoint1")
        filter.setValue(CIVector(x: points[2].x, y: points[2].y), forKey: "inputPoint2")
        filter.setValue(CIVector(x: points[3].x, y: points[3].y), forKey: "inputPoint3")
        filter.setValue(CIVector(x: points[4].x, y: points[4].y), forKey: "inputPoint4")

        return filter.outputImage
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
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
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
