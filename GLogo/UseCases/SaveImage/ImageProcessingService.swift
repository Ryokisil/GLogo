//
// 概要：フィルター適用・合成処理。
// ベース画像の範囲を基準に、editor と同じキャンバス座標系で可視要素を再描画する。
// 保存解像度はベース画像の実ピクセルサイズを使用し、はみ出した要素はクリップする。

import UIKit
import OSLog

struct ImageProcessingService: ImageProcessing {
    private static let logger = Logger(subsystem: "com.silvia.GLogo", category: "Save")
    private static let maxCompositePixelCount: CGFloat = 24_000_000
    private static let maxCompositeLongSide: CGFloat = 6_144

    private struct CompositeRenderMetrics {
        let renderScale: CGSize
        let renderSize: CGSize
    }

    /// ImageElement に設定されたフィルターを適用した画像を返す
    func applyFilters(to imageElement: ImageElement) -> UIImage? {
        imageElement.getFilteredImageForce()
    }

    /// ベース画像の範囲を基準に合成して返す
    /// - Parameters:
    ///   - baseElement: 保存基準となるベース画像要素
    ///   - project: プロジェクト
    /// - Returns: 合成画像（ベース画像の実ピクセルサイズで出力）
    func makeCompositeImage(baseElement: ImageElement, project: LogoProject) -> UIImage? {
        guard let baseImage = baseElement.getFilteredImageForce() else {
            Self.logger.warning("合成保存に失敗: ベース画像のフィルタ適用に失敗")
            return nil
        }

        let basePixelSize = pixelSize(of: baseImage)
        guard basePixelSize.width > 0, basePixelSize.height > 0,
              baseElement.size.width > 0, baseElement.size.height > 0 else {
            Self.logger.warning("合成保存に失敗: ベース画像サイズが無効")
            return nil
        }

        // ベース要素の editor 上フレームをキャンバスでクリップ
        let baseFrame = CGRect(origin: baseElement.position, size: baseElement.size)
        let canvasRect = CGRect(origin: .zero, size: project.canvasSize)
        let exportRect = baseFrame.intersection(canvasRect)
        guard !exportRect.isNull, !exportRect.isEmpty else {
            Self.logger.warning("合成保存に失敗: ベース画像がキャンバス外")
            return nil
        }

        // 保存倍率: ベース画像のピクセル密度を縦横別に反映する
        let baseScaleX = basePixelSize.width / baseElement.size.width
        let baseScaleY = basePixelSize.height / baseElement.size.height
        let renderMetrics = resolveRenderMetrics(
            xScale: baseScaleX,
            yScale: baseScaleY,
            exportRect: exportRect
        )
        let renderScale = renderMetrics.renderScale
        let renderSize = renderMetrics.renderSize

        let visibleElements = project.elements
            .filter(\.isVisible)
            .sorted { $0.zIndex < $1.zIndex }
        let resolvedImages = resolvedImages(for: visibleElements)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        return renderer.image { context in
            let cgContext = context.cgContext

            cgContext.scaleBy(x: renderScale.width, y: renderScale.height)
            // editor と同じキャンバス座標系のまま描画し、ベース要素原点へ平行移動する
            cgContext.translateBy(x: -exportRect.minX, y: -exportRect.minY)
            // ベース画像範囲（∩キャンバス）でクリップ
            cgContext.clip(to: exportRect)

            // 背景設定描画（editor と同じ座標系。clip によりベース画像範囲内のみ反映）
            project.backgroundSettings.draw(in: cgContext, rect: canvasRect)

            for element in visibleElements {
                if let imageElement = element as? ImageElement,
                   let highResImage = resolvedImages[element.id] {
                    ImageElementRenderer.draw(imageElement, in: cgContext, image: highResImage)
                    continue
                }

                element.draw(in: cgContext)
            }
        }
    }

    // MARK: - 補助

    /// 可視画像要素のフル品質画像を一度だけ解決する
    private func resolvedImages(for elements: [LogoElement]) -> [UUID: UIImage] {
        Dictionary(
            uniqueKeysWithValues: elements.compactMap { element in
                guard let imageElement = element as? ImageElement,
                      let highResImage = imageElement.getFilteredImageForce() else {
                    return nil
                }

                return (element.id, highResImage)
            }
        )
    }

    /// ピクセル上限を考慮しつつ、実際の出力サイズと描画倍率を解決する
    private func resolveRenderMetrics(
        xScale: CGFloat,
        yScale: CGFloat,
        exportRect: CGRect
    ) -> CompositeRenderMetrics {
        let requestedSize = CGSize(
            width: exportRect.width * xScale,
            height: exportRect.height * yScale
        )
        let requestedPixelCount = max(requestedSize.width * requestedSize.height, 1)
        let requestedLongSide = max(requestedSize.width, requestedSize.height, 1)

        let pixelLimitedScale = sqrt(Self.maxCompositePixelCount / requestedPixelCount)
        let longSideLimitedScale = Self.maxCompositeLongSide / requestedLongSide
        let downscaleFactor = min(1.0, pixelLimitedScale, longSideLimitedScale)

        let renderSize = CGSize(
            width: max(1.0, (requestedSize.width * downscaleFactor).rounded()),
            height: max(1.0, (requestedSize.height * downscaleFactor).rounded())
        )
        let renderScale = CGSize(
            width: renderSize.width / exportRect.width,
            height: renderSize.height / exportRect.height
        )

        return CompositeRenderMetrics(
            renderScale: renderScale,
            renderSize: renderSize
        )
    }

    /// UIImage の実ピクセルサイズを返す
    private func pixelSize(of image: UIImage) -> CGSize {
        if let cgImage = image.cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }

        return CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
    }
}
