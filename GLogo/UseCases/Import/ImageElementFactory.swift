// 画像データから画像要素を作る生成手順（寸法の読み取りと配置サイズの決定）を担当する。

import CoreGraphics
import Foundation

/// 画像データの寸法を読み取って配置サイズを決め、I/O を持たない ImageElement の初期化へ渡す。
/// メタデータは抽出しない。
struct ImageElementFactory {
    private let loader: any ImageInitializationLoading
    private let sourceResolver: any ImageSourceResolving
    private let previewService: any ImagePreviewing

    init(
        loader: any ImageInitializationLoading,
        sourceResolver: any ImageSourceResolving,
        previewService: any ImagePreviewing
    ) {
        self.loader = loader
        self.sourceResolver = sourceResolver
        self.previewService = previewService
    }

    /// 画像データから画像要素を作る。
    /// デコードできない Data も参照として保持し、配置サイズは既定値のままにする。
    /// - Parameters:
    ///   - canvasSize: 配置サイズの基準。要素にも保持し、画像差し替え時のサイズ計算に使う
    ///   - importOrder: インポート順序（1番目はベース画像として扱う）
    func makeElement(
        imageData: Data,
        canvasSize: CGSize = ImageElement.defaultCanvasSize,
        importOrder: Int = 0
    ) -> ImageElement {
        let size = loader.imageSize(imageData: imageData).map {
            ImageSizeCalculator.fittedSize(imageSize: $0, canvasSize: canvasSize)
        }
        return ImageElement(
            source: .data(imageData), size: size, canvasSize: canvasSize, importOrder: importOrder,
            sourceResolver: sourceResolver, previewService: previewService
        )
    }
}
