// 画像要素ごとの、元画像・編集用プロキシの取得、表示画像と即時プレビューの描画、キャッシュ、編集中の状態を受け持つ。

import UIKit

/// 画像要素ごとの取得・描画・キャッシュの管理。要素と同じ寿命を持ち、編集の終了では破棄しない。
///
/// 分離の中間段階として、Model（`ImageElement`）が要素ごとに1つ作って持ち、既存の API から委譲する。
/// 所有の場所と、Model から UseCases の具体型への依存の向きは、まだ整理していない。
/// 複製・Decoder・保存用の複製は、それぞれ別のインスタンスを持つ（保存用の複製は、元の要素と同じ ID でも別の状態）。
/// 並行アクセスの同期は行わない。要素と同じく、呼び出し側の実行場所の取り決めに従う
/// （保存用の複製はバックグラウンドで使うため、型全体を MainActor にはしない）。
final class ImageRenderSession {
    /// 元画像・プロキシ取得の実行時依存。要素ごとに固定し、永続化しない。
    let sourceResolver: any ImageSourceResolving

    /// 描画とサムネイルで共有する生成時の依存。保存データには含めない。
    let previewService: any ImagePreviewing

    /// 表示画像・元画像・プロキシ・プレビュー元画像のキャッシュ。Codable やコピーには含めない。
    private var cache = ImageRenderCache()

    /// 編集中かどうか（プレビュー品質と高品質の切り替え用）
    private var isEditing = false

    /// プロキシ生成時の長辺目安（約2MP相当）
    private let proxyTargetLongSide: CGFloat = 1920

    /// 高解像度判定の閾値（MP）
    private let highResThresholdMP: CGFloat = 18.0

    init(sourceResolver: any ImageSourceResolving, previewService: any ImagePreviewing) {
        self.sourceResolver = sourceResolver
        self.previewService = previewService
    }

    // MARK: - キャッシュ

    /// 加工済みの表示画像のキャッシュ。履歴と描画完了処理が読み書きする。
    var renderedImage: UIImage? {
        get { cache.renderedImage }
        set { cache.renderedImage = newValue }
    }

    /// 操作に応じた範囲でキャッシュを消す。共有の描画サービスのキャッシュは消さない。
    func invalidate(_ scope: ImageRenderCache.Invalidation) {
        cache.invalidate(scope)
    }

    /// 画像ソースの差し替え・復元のとき、4つのキャッシュと共有の描画サービスのキャッシュを消す。
    func invalidateForSourceChange() {
        cache.invalidate(.all)
        previewService.resetCache()
    }

    /// 保存用の複製で、受付時の元画像を固定する。後のソースの差し替えや削除の影響を受けないようにするため。
    func fixOriginalImage(_ image: UIImage?) {
        cache.originalImage = image
    }

    // MARK: - 編集中の状態

    /// 編集開始をマーク
    func startEditing() {
        isEditing = true
        cache.invalidate(.rendered)
    }

    /// 編集終了をマーク。キャッシュとセッションは破棄しない。
    func endEditing() {
        isEditing = false
    }

    // MARK: - 取得

    /// 元画像を取得
    func originalImage(of element: ImageElement) -> UIImage? {
        if let cachedOriginalImage = cache.originalImage {
            return cachedOriginalImage
        }

        let loadedImage = sourceResolver.resolveOriginalImage(
            imageData: element.imageData,
            fileName: element.imageFileName,
            url: element.originalImageURL,
            path: element.originalImagePath
        )

        // 元画像をキャッシュ
        cache.originalImage = loadedImage
        return loadedImage
    }

    /// 編集用プロキシ画像（外部リポジトリで生成・解決）
    private func editingImage(of element: ImageElement) -> UIImage? {
        if let proxy = cache.proxyImage {
            return proxy
        }
        if let resolved = sourceResolver.resolveEditingImage(
            identifier: element.originalImageIdentifier,
            fileName: element.imageFileName,
            originalPath: element.originalImagePath,
            originalImageProvider: { self.originalImage(of: element) },
            proxyTargetLongSide: proxyTargetLongSide,
            highResThresholdMP: highResThresholdMP
        ) {
            cache.proxyImage = resolved
            return resolved
        }
        return originalImage(of: element)
    }

    // MARK: - 描画

    /// 表示画像。編集中は即時プレビュー（なければプロキシ、元画像の順）、それ以外はフル品質で加工してキャッシュする。
    func displayImage(of element: ImageElement) -> UIImage? {
        // 編集中はプレビュー品質のみ返してメインスレッド負荷を抑える。
        // フォールバック候補は、即時プレビューの有無にかかわらず先に取得する（今の評価の順序）。
        if isEditing {
            let instant = instantPreview(of: element)
            let fallbackEditing = editingImage(of: element)
            let fallbackOriginal = originalImage(of: element)
            let resolved = instant ?? fallbackEditing ?? fallbackOriginal
            return resolved
        }

        if let renderedImage = cache.renderedImage {
            return renderedImage
        }

        guard let originalImage = originalImage(of: element) else {
            return nil
        }

        // 編集操作を適用した画像を返す（非編集時はフル品質）
        let processedImage = applyFilters(to: originalImage, of: element, quality: .full)

        // 編集後の画像をキャッシュ
        cache.renderedImage = processedImage
        return processedImage
    }

    /// キャンバスに描く画像。表示画像を求めたうえで、編集中は即時プレビュー、プレビュー品質の加工、表示画像の順に選ぶ。
    func drawingImage(of element: ImageElement) -> UIImage? {
        guard let image = displayImage(of: element) else { return nil }
        if isEditing {
            return instantPreview(of: element) ?? applyFilters(to: image, of: element, quality: .preview) ?? image
        } else {
            return image
        }
    }

    /// フィルター適用済み画像を強制的に生成する。表示画像のキャッシュは使わないが、元画像のキャッシュは使う。
    func filteredImage(of element: ImageElement) -> UIImage? {
        guard let originalImage = originalImage(of: element) else {
            return nil
        }

        // 表示画像のキャッシュを無視して常に最新のフィルターを適用
        return applyFilters(to: originalImage, of: element)
    }

    /// フル品質のフィルター適用結果を非同期で生成する。元画像のキャッシュは使う。
    ///
    /// 表示画像のキャッシュに書き込まないため、採用可否の判定と書き込みは呼び出し側（`ImageRenderRefreshUseCase`）が行う。
    @MainActor
    func fullQualityImageAsync(of element: ImageElement) async -> UIImage? {
        guard let originalImage = originalImage(of: element) else {
            return nil
        }

        return await applyFiltersAsync(to: originalImage, of: element, quality: .full)
    }

    /// 即座プレビュー用の画像を取得（低解像度、高速処理）
    func instantPreview(of element: ImageElement) -> UIImage? {
        if cache.previewBaseImage == nil {
            cache.previewBaseImage = generatePreviewImage(of: element)
        }

        guard let preview = cache.previewBaseImage else { return nil }

        let params = element.currentFilterParams()
        return previewService.instantPreview(
            baseImage: preview,
            params: params,
            quality: .preview,
            mode: element.currentRenderMode()
        )
    }

    /// プレビュー用低解像度画像を生成
    private func generatePreviewImage(of element: ImageElement) -> UIImage? {
        previewService.generatePreviewImage(
            editingImage: editingImage(of: element),
            originalImage: originalImage(of: element),
            mode: element.currentRenderMode()
        )
    }

    /// 画像にフィルターを適用
    private func applyFilters(to image: UIImage, of element: ImageElement, quality: RenderQuality = .full) -> UIImage? {
        previewService.applyFilters(
            to: image,
            params: element.currentFilterParams(),
            quality: quality,
            mode: element.currentRenderMode()
        )
    }

    /// 画像にフィルターを非同期で適用（彩度調整特化）
    @MainActor
    private func applyFiltersAsync(
        to image: UIImage,
        of element: ImageElement,
        quality: RenderQuality = .full
    ) async -> UIImage? {
        await previewService.applyFiltersAsync(
            to: image,
            params: element.currentFilterParams(),
            quality: quality,
            mode: element.currentRenderMode()
        )
    }
}
