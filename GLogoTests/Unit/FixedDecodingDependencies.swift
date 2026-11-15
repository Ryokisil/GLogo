// 復元の依存の受け渡しを確かめるテストで使う、状態を持たない取得先と描画サービス。
// どちらも不変の値だけを持ち、Sendable を検査付きで満たすため、並行に読み込むテストでも使える。

import UIKit
@testable import GLogo

/// 固定の取得先と描画サービスの組。届いた依存と見比べられるよう、両方を保持する。
struct FixedDecodingDependencies: Sendable {
    let resolver: FixedImageSourceResolver
    let preview: FixedPreviewService

    /// 組ごとに別の画像インスタンスを返す（別の組の依存と取り違えると、同一性の確認で分かる）。
    init(color: UIColor) {
        resolver = FixedImageSourceResolver(image: snapshotImage(color))
        preview = FixedPreviewService(output: snapshotImage(color))
    }

    var dependencies: ProjectDecodingDependencies {
        ProjectDecodingDependencies(sourceResolver: resolver, previewService: preview)
    }

    /// 画像要素がこの組の依存を使っているか。取得先は振る舞い（返した画像）で、描画サービスは同一性で確かめる。
    /// 第20回で Model の取得の API を外したため、要素のセッションから直接取得する（所有を移す第21回で見直す）。
    func isUsed(by image: ImageElement) -> Bool {
        image.previewService === preview && image.renderSession.originalImage(of: image) === resolver.image
    }
}

/// どの参照に対しても、固定した画像を元画像・編集用画像として返す取得先。
struct FixedImageSourceResolver: ImageSourceResolving {
    let image: UIImage

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        image
    }

    func resolveEditingImage(
        identifier: String?,
        fileName: String?,
        originalPath: String?,
        originalImageProvider: () -> UIImage?,
        proxyTargetLongSide: CGFloat,
        highResThresholdMP: CGFloat
    ) -> UIImage? {
        image
    }
}

/// 固定した画像を描画結果として返す描画サービス。キャッシュを持たない。
final class FixedPreviewService: ImagePreviewing {
    let output: UIImage

    init(output: UIImage) {
        self.output = output
    }

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        output
    }

    func instantPreview(
        baseImage: UIImage?,
        params: ImageFilterParams,
        quality: RenderQuality,
        mode: ImageRenderMode
    ) -> UIImage? {
        output
    }

    func applyFilters(
        to image: UIImage,
        params: ImageFilterParams,
        quality: RenderQuality,
        mode: ImageRenderMode
    ) -> UIImage? {
        output
    }

    func applyFiltersAsync(
        to image: UIImage,
        params: ImageFilterParams,
        quality: RenderQuality,
        mode: ImageRenderMode
    ) async -> UIImage? {
        output
    }

    func resetCache() {}
}
