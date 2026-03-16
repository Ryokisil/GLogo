//
//  CoreMLUpscaler.swift
//  GLogo
//
//  概要:
//  このファイルは Core ML の画像変換モデルを動的に読み込み、
//  汎用的な image-to-image 推論を実行するための実行器を定義します。
//  Real-ESRGAN 以外の超解像モデルへ差し替える場合も、この実装を共通基盤として再利用します。
//

import CoreImage
import CoreML
import Foundation
import UIKit

/// Core ML ベースの高画質化実行器
final class CoreMLUpscaler {
    private let configuration: RealESRGANPipelineConfiguration
    private let context = CIContext()
    private let memoryPolicy = UpscaleMemoryPolicy()
    private let highResolutionLongSideThreshold: CGFloat = 2_000
    private var cachedModel: MLModel?
    private var cachedInterface: CoreMLImageModelInterface?

    /// Core ML 実行器を生成する
    /// - Parameters:
    ///   - configuration: モデル解決に利用する設定値
    /// - Returns: 生成された実行器
    init(configuration: RealESRGANPipelineConfiguration) {
        self.configuration = configuration
    }

    /// Core ML による高画質化を実行する
    /// - Parameters:
    ///   - request: 実行対象の高画質化リクエスト
    /// - Returns: 高画質化結果
    func upscale(_ request: ImageUpscaleRequest) async throws -> ImageUpscaleResult {
        let model = try loadModel()
        let interface = try resolveInterface(for: model)
        let inputCGImage = try makeNormalizedCGImage(from: request.sourceImage)
        let sourcePixelSize = CGSize(width: inputCGImage.width, height: inputCGImage.height)
        let modelScale = interface.derivedScaleFactor ?? request.scaleFactor.multiplier
        let requestedScale = min(request.scaleFactor.multiplier, modelScale)
        let actualScale = memoryPolicy.safeScale(
            requestedScale: requestedScale,
            sourcePixelSize: sourcePixelSize
        )
        guard actualScale >= 1 else {
            throw ImageUpscaleError.sourceImageTooLarge
        }

        let workingImage = try makeWorkingInputImage(
            from: inputCGImage,
            sourcePixelSize: sourcePixelSize,
            modelScale: modelScale,
            actualScale: actualScale
        )
        let processingScale = CGFloat(workingImage.width) > 0
            ? (sourcePixelSize.width * actualScale) / CGFloat(workingImage.width)
            : modelScale
        let outputCGImage: CGImage

        if let tileSize = interface.preferredTileSize(configuration: configuration) {
            let tileProcessor = UpscaleTileProcessor(
                tileSize: tileSize,
                modelScaleFactor: modelScale,
                outputScaleFactor: processingScale,
                renderer: { [weak self] tileImage in
                    guard let self else {
                        throw ImageUpscaleError.predictionFailed(reason: "Core ML 実行器が解放されました。")
                    }
                    return try self.runPrediction(
                        tileImage,
                        model: model,
                        interface: interface
                    )
                }
            )
            outputCGImage = try tileProcessor.process(image: workingImage)
        } else {
            let predictedImage = try runPrediction(
                workingImage,
                model: model,
                interface: interface
            )
            if abs(processingScale - modelScale) > 0.01 {
                outputCGImage = predictedImage
            } else {
                outputCGImage = try resizeOutputIfNeeded(
                    predictedImage,
                    modelScale: modelScale,
                    outputScale: actualScale,
                    sourceSize: sourcePixelSize
                )
            }
        }

        let appliedScaleFactor = ImageUpscaleScaleFactor(
            rawValue: Int(actualScale.rounded())
        ) ?? request.scaleFactor

        let resultImage = UIImage(
            cgImage: outputCGImage,
            scale: request.sourceImage.scale,
            orientation: .up
        )

        return ImageUpscaleResult(
            image: resultImage,
            appliedMethod: .realESRGAN,
            scaleFactor: appliedScaleFactor,
            actualScaleMultiplier: actualScale
        )
    }

    /// 高解像度画像では入力を先に縮小して待機時間を抑える
    /// - Parameters:
    ///   - image: 元の入力画像
    ///   - sourcePixelSize: 元画像のピクセルサイズ
    ///   - modelScale: モデル本来の倍率
    ///   - actualScale: 最終的に適用したい倍率
    /// - Returns: 推論に使う入力画像
    private func makeWorkingInputImage(
        from image: CGImage,
        sourcePixelSize: CGSize,
        modelScale: CGFloat,
        actualScale: CGFloat
    ) throws -> CGImage {
        guard modelScale > actualScale else {
            return image
        }

        let sourceLongSide = max(sourcePixelSize.width, sourcePixelSize.height)
        guard sourceLongSide >= highResolutionLongSideThreshold else {
            return image
        }

        let workingRatio = actualScale / modelScale
        let workingSize = CGSize(
            width: max((sourcePixelSize.width * workingRatio).rounded(), 1),
            height: max((sourcePixelSize.height * workingRatio).rounded(), 1)
        )

        guard workingSize.width < sourcePixelSize.width || workingSize.height < sourcePixelSize.height else {
            return image
        }

        return try resizeCGImage(image, to: workingSize)
    }

    /// コンパイル済み Core ML モデルを読み込む
    /// - Parameters: なし
    /// - Returns: 読み込み済みモデル
    private func loadModel() throws -> MLModel {
        if let cachedModel {
            return cachedModel
        }

        guard let modelURL = configuration.modelLocator.compiledModelURL(named: configuration.compiledModelName) else {
            throw ImageUpscaleError.modelNotFound(name: configuration.compiledModelName)
        }

        let modelConfiguration = MLModelConfiguration()
        modelConfiguration.computeUnits = .all

        do {
            let model = try MLModel(contentsOf: modelURL, configuration: modelConfiguration)
            cachedModel = model
            return model
        } catch {
            throw ImageUpscaleError.predictionFailed(reason: error.localizedDescription)
        }
    }

    /// モデルの画像入出力インターフェースを解決する
    /// - Parameters:
    ///   - model: 対象モデル
    /// - Returns: 解決済みインターフェース
    private func resolveInterface(for model: MLModel) throws -> CoreMLImageModelInterface {
        if let cachedInterface {
            return cachedInterface
        }

        guard let interface = CoreMLImageModelInterface(model: model) else {
            throw ImageUpscaleError.invalidModelInterface
        }

        cachedInterface = interface
        return interface
    }

    /// Core ML 推論を1回実行して CGImage を返す
    /// - Parameters:
    ///   - image: 入力 CGImage
    ///   - model: 読み込み済みモデル
    ///   - interface: 入出力定義
    /// - Returns: 推論後の CGImage
    private func runPrediction(
        _ image: CGImage,
        model: MLModel,
        interface: CoreMLImageModelInterface
    ) throws -> CGImage {
        let pixelBuffer = try makePixelBuffer(
            from: image,
            width: image.width,
            height: image.height,
            pixelFormatType: interface.inputPixelFormatType
        )

        let inputProvider = try MLDictionaryFeatureProvider(
            dictionary: [
                interface.inputName: MLFeatureValue(pixelBuffer: pixelBuffer)
            ]
        )

        let prediction: MLFeatureProvider
        do {
            prediction = try model.prediction(from: inputProvider)
        } catch {
            throw ImageUpscaleError.predictionFailed(reason: error.localizedDescription)
        }

        guard let outputValue = prediction.featureValue(for: interface.outputName) else {
            throw ImageUpscaleError.invalidModelInterface
        }

        if let outputPixelBuffer = outputValue.imageBufferValue {
            let outputImage = CIImage(cvPixelBuffer: outputPixelBuffer)
            guard let outputCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
                throw ImageUpscaleError.imageGenerationFailed
            }
            return outputCGImage
        }

        if let outputMultiArray = outputValue.multiArrayValue {
            return try makeCGImage(
                from: outputMultiArray,
                expectedOutputSize: interface.outputSize
            )
        }

        throw ImageUpscaleError.invalidModelInterface
    }

    /// MLMultiArray 出力を CGImage へ変換する
    /// - Parameters:
    ///   - multiArray: 変換対象の出力テンソル
    ///   - expectedOutputSize: モデル定義から推定した出力サイズ
    /// - Returns: 画像化された CGImage
    private func makeCGImage(
        from multiArray: MLMultiArray,
        expectedOutputSize: CGSize?
    ) throws -> CGImage {
        let layout = try resolveMultiArrayLayout(
            from: multiArray,
            expectedOutputSize: expectedOutputSize
        )
        let valueScale = resolveTensorValueScale(
            multiArray,
            layout: layout
        )

        var rgbaBytes = [UInt8](
            repeating: 0,
            count: layout.width * layout.height * 4
        )

        for y in 0..<layout.height {
            for x in 0..<layout.width {
                let red = clampedColorComponent(
                    value: scalarValue(
                        from: multiArray,
                        at: layout.index(channel: 0, x: x, y: y)
                    ),
                    scale: valueScale
                )
                let green = clampedColorComponent(
                    value: scalarValue(
                        from: multiArray,
                        at: layout.index(channel: 1, x: x, y: y)
                    ),
                    scale: valueScale
                )
                let blue = clampedColorComponent(
                    value: scalarValue(
                        from: multiArray,
                        at: layout.index(channel: 2, x: x, y: y)
                    ),
                    scale: valueScale
                )

                let pixelOffset = (y * layout.width + x) * 4
                rgbaBytes[pixelOffset] = red
                rgbaBytes[pixelOffset + 1] = green
                rgbaBytes[pixelOffset + 2] = blue
                rgbaBytes[pixelOffset + 3] = 255
            }
        }

        let bytesPerRow = layout.width * 4
        let data = Data(rgbaBytes)
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width: layout.width,
                height: layout.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw ImageUpscaleError.invalidModelInterface
        }
        return cgImage
    }

    /// モデル出力を必要に応じて安全サイズへ縮小する
    /// - Parameters:
    ///   - image: モデルが返した出力画像
    ///   - modelScale: モデル本来の倍率
    ///   - outputScale: 実際に採用する倍率
    ///   - sourceSize: 元画像サイズ
    /// - Returns: 必要に応じて縮小済みの出力画像
    private func resizeOutputIfNeeded(
        _ image: CGImage,
        modelScale: CGFloat,
        outputScale: CGFloat,
        sourceSize: CGSize
    ) throws -> CGImage {
        guard outputScale < modelScale else {
            return image
        }

        let targetSize = CGSize(
            width: max((sourceSize.width * outputScale).rounded(), 1),
            height: max((sourceSize.height * outputScale).rounded(), 1)
        )
        return try resizeCGImage(
            image,
            to: targetSize
        )
    }

    /// UIImage を見た目どおりの向きで CGImage 化する
    /// - Parameters:
    ///   - image: 変換対象の画像
    /// - Returns: 正規化済み CGImage
    private func makeNormalizedCGImage(from image: UIImage) throws -> CGImage {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }

        let pixelSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        let renderedImage = UIGraphicsImageRenderer(
            size: pixelSize,
            format: format
        ).image { _ in
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
        }

        guard let cgImage = renderedImage.cgImage else {
            throw ImageUpscaleError.missingCGImage
        }
        return cgImage
    }

    /// CGImage を Core ML 入力用 PixelBuffer に変換する
    /// - Parameters:
    ///   - image: 変換対象画像
    ///   - width: 出力バッファの幅
    ///   - height: 出力バッファの高さ
    ///   - pixelFormatType: 必要なピクセルフォーマット
    /// - Returns: 生成された PixelBuffer
    private func makePixelBuffer(
        from image: CGImage,
        width: Int,
        height: Int,
        pixelFormatType: OSType
    ) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        let creationStatus = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormatType,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard creationStatus == kCVReturnSuccess, let pixelBuffer else {
            throw ImageUpscaleError.imageGenerationFailed
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw ImageUpscaleError.imageGenerationFailed
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue |
            CGBitmapInfo.byteOrder32Little.rawValue

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw ImageUpscaleError.imageGenerationFailed
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }

    /// CGImage を指定サイズへ縮小する
    /// - Parameters:
    ///   - image: 縮小対象画像
    ///   - size: 目標サイズ
    /// - Returns: 縮小済み画像
    private func resizeCGImage(
        _ image: CGImage,
        to size: CGSize
    ) throws -> CGImage {
        guard let resizedContext = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageUpscaleError.imageGenerationFailed
        }

        resizedContext.interpolationQuality = .high
        resizedContext.draw(image, in: CGRect(origin: .zero, size: size))

        guard let resizedImage = resizedContext.makeImage() else {
            throw ImageUpscaleError.imageGenerationFailed
        }
        return resizedImage
    }

    /// 画像テンソルのチャンネル並びと座標解決を返す
    /// - Parameters:
    ///   - multiArray: 解析対象テンソル
    ///   - expectedOutputSize: モデル定義から推定した出力サイズ
    /// - Returns: 座標解決済みのレイアウト
    private func resolveMultiArrayLayout(
        from multiArray: MLMultiArray,
        expectedOutputSize: CGSize?
    ) throws -> MultiArrayImageLayout {
        let shape = multiArray.shape.map(\.intValue)
        let strides = multiArray.strides.map(\.intValue)

        switch shape.count {
        case 4 where shape[0] == 1 && shape[1] == 3:
            return MultiArrayImageLayout(
                width: shape[3],
                height: shape[2],
                channelIndex: { channel, x, y in
                    y * strides[2] + x * strides[3] + channel * strides[1]
                }
            )
        case 4 where shape[0] == 1 && shape[3] == 3:
            return MultiArrayImageLayout(
                width: shape[2],
                height: shape[1],
                channelIndex: { channel, x, y in
                    y * strides[1] + x * strides[2] + channel * strides[3]
                }
            )
        case 3 where shape[0] == 3:
            return MultiArrayImageLayout(
                width: shape[2],
                height: shape[1],
                channelIndex: { channel, x, y in
                    channel * strides[0] + y * strides[1] + x * strides[2]
                }
            )
        case 3 where shape[2] == 3:
            return MultiArrayImageLayout(
                width: shape[1],
                height: shape[0],
                channelIndex: { channel, x, y in
                    y * strides[0] + x * strides[1] + channel * strides[2]
                }
            )
        default:
            if let expectedOutputSize {
                throw ImageUpscaleError.predictionFailed(
                    reason: "未対応のテンソル形状です: \(shape), expected: \(expectedOutputSize)"
                )
            }
            throw ImageUpscaleError.invalidModelInterface
        }
    }

    /// 出力テンソルの値レンジを推定する
    /// - Parameters:
    ///   - multiArray: 対象テンソル
    ///   - layout: 解決済みレイアウト
    /// - Returns: 画像化に使うスケール値
    private func resolveTensorValueScale(
        _ multiArray: MLMultiArray,
        layout: MultiArrayImageLayout
    ) -> Float {
        let sampleWidth = min(layout.width, 8)
        let sampleHeight = min(layout.height, 8)
        var maxValue: Float = 0

        for y in 0..<sampleHeight {
            for x in 0..<sampleWidth {
                for channel in 0..<3 {
                    let value = scalarValue(
                        from: multiArray,
                        at: layout.index(channel: channel, x: x, y: y)
                    )
                    maxValue = max(maxValue, value)
                }
            }
        }

        return maxValue <= 1.5 ? 255 : 1
    }

    /// MLMultiArray から 1 要素を取得する
    /// - Parameters:
    ///   - multiArray: 対象テンソル
    ///   - index: 線形インデックス
    /// - Returns: Float 化した値
    private func scalarValue(
        from multiArray: MLMultiArray,
        at index: Int
    ) -> Float {
        switch multiArray.dataType {
        case .float16:
            let pointer = multiArray.dataPointer.bindMemory(
                to: UInt16.self,
                capacity: multiArray.count
            )
            return Float(Float16(bitPattern: pointer[index]))
        case .float32:
            let pointer = multiArray.dataPointer.bindMemory(
                to: Float.self,
                capacity: multiArray.count
            )
            return pointer[index]
        case .double:
            let pointer = multiArray.dataPointer.bindMemory(
                to: Double.self,
                capacity: multiArray.count
            )
            return Float(pointer[index])
        default:
            return 0
        }
    }

    /// カラーチャンネル値を 0...255 のバイトへ丸める
    /// - Parameters:
    ///   - value: 元のテンソル値
    ///   - scale: 画像レンジへ戻す係数
    /// - Returns: 丸め後のチャンネル値
    private func clampedColorComponent(
        value: Float,
        scale: Float
    ) -> UInt8 {
        let scaledValue = value * scale
        return UInt8(max(0, min(255, Int(scaledValue.rounded()))))
    }
}

/// MLMultiArray を画像として読むためのレイアウト解決結果
private struct MultiArrayImageLayout {
    let width: Int
    let height: Int
    let channelIndex: (Int, Int, Int) -> Int

    /// 画像座標をテンソルの線形インデックスへ変換する
    /// - Parameters:
    ///   - channel: 0=R, 1=G, 2=B
    ///   - x: x 座標
    ///   - y: y 座標
    /// - Returns: 線形インデックス
    func index(channel: Int, x: Int, y: Int) -> Int {
        channelIndex(channel, x, y)
    }
}

/// Core ML 画像モデルの入出力定義
private struct CoreMLImageModelInterface {
    enum OutputKind {
        case image
        case multiArray
    }

    let inputName: String
    let outputName: String
    let outputKind: OutputKind
    let inputPixelFormatType: OSType
    let inputSize: CGSize?
    let outputSize: CGSize?

    /// モデル記述から画像入出力を解決する
    /// - Parameters:
    ///   - model: 解決対象のモデル
    /// - Returns: 解決できた場合はインターフェース、失敗時は nil
    init?(model: MLModel) {
        guard let input = model.modelDescription.inputDescriptionsByName.first(where: {
            $0.value.type == .image
        }) else {
            return nil
        }

        guard let output = model.modelDescription.outputDescriptionsByName.first(where: {
            $0.value.type == .image || $0.value.type == .multiArray
        }) else {
            return nil
        }

        inputName = input.key
        outputName = output.key
        inputPixelFormatType = input.value.imageConstraint?.pixelFormatType ?? kCVPixelFormatType_32BGRA
        outputKind = output.value.type == .image ? .image : .multiArray

        if let inputConstraint = input.value.imageConstraint,
           inputConstraint.pixelsWide > 0,
           inputConstraint.pixelsHigh > 0 {
            inputSize = CGSize(
                width: inputConstraint.pixelsWide,
                height: inputConstraint.pixelsHigh
            )
        } else {
            inputSize = nil
        }

        outputSize = Self.resolveOutputSize(for: output.value)
    }

    /// モデル定義から推定できる拡大倍率
    /// - Parameters: なし
    /// - Returns: 推定倍率
    var derivedScaleFactor: CGFloat? {
        guard let inputSize,
              let outputSize,
              inputSize.width > 0,
              inputSize.height > 0 else {
            return nil
        }

        let scaleX = outputSize.width / inputSize.width
        let scaleY = outputSize.height / inputSize.height
        guard abs(scaleX - scaleY) < 0.01 else {
            return nil
        }
        return scaleX
    }

    /// タイル処理に使う入力サイズを返す
    /// - Parameters:
    ///   - configuration: パイプライン設定
    /// - Returns: 利用可能な場合はタイルサイズ
    func preferredTileSize(configuration: RealESRGANPipelineConfiguration) -> Int? {
        if let preferredTileSize = configuration.preferredTileSize {
            return preferredTileSize
        }
        guard let inputSize, abs(inputSize.width - inputSize.height) < 0.01 else {
            return nil
        }
        return Int(inputSize.width.rounded())
    }

    /// 出力定義から出力サイズを推定する
    /// - Parameters:
    ///   - outputDescription: 出力の特徴量定義
    /// - Returns: 推定できた場合は出力サイズ
    private static func resolveOutputSize(for outputDescription: MLFeatureDescription) -> CGSize? {
        if let outputConstraint = outputDescription.imageConstraint,
           outputConstraint.pixelsWide > 0,
           outputConstraint.pixelsHigh > 0 {
            return CGSize(
                width: outputConstraint.pixelsWide,
                height: outputConstraint.pixelsHigh
            )
        }

        guard let shape = outputDescription.multiArrayConstraint?.shape.map(\.intValue) else {
            return nil
        }

        switch shape.count {
        case 4 where shape[0] == 1 && shape[1] == 3:
            return CGSize(width: shape[3], height: shape[2])
        case 4 where shape[0] == 1 && shape[3] == 3:
            return CGSize(width: shape[2], height: shape[1])
        case 3 where shape[0] == 3:
            return CGSize(width: shape[2], height: shape[1])
        case 3 where shape[2] == 3:
            return CGSize(width: shape[1], height: shape[0])
        default:
            return nil
        }
    }
}
