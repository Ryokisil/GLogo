// 編集画面で使う技術的な実装（Infrastructure）を作って渡す Composition Root。
// ここから渡す依存は、受け取る側（UseCases・ViewModels）では境界の Protocol として扱う。

import Foundation

/// エディタ、その編集パネル、そこから開く2つの編集画面（手動背景除去・背景ぼかしマスク）が使う実装を組み立てる。
/// 生成の単位は、以前の初期化引数の既定値と同じにする。
/// Model からの直接の参照（背景画像）は、まだここを通らない
/// （docs/architecture/README.md の「計画外の対応と残件」で追跡）。
/// プロジェクトの読み込み（`ProjectStorage`）はアプリから呼ばれていないため、`ProjectDecodingDependencies` の
/// 生成関数はまだ置かない。読み込みの経路を戻すときに、ここで作って渡す。
enum AppComposition {
    // MARK: - 編集画面

    /// アプリの入口とプレビューで使うエディタを組み立てる。
    @MainActor
    static func makeEditorViewModel() -> EditorViewModel {
        EditorViewModel(dependencies: makeEditorDependencies())
    }

    /// エディタ1つ分の依存を組み立てる。呼ぶたびに、エディタで共有する実装を新しく作る。
    static func makeEditorDependencies() -> EditorDependencies {
        EditorDependencies(
            photoLibrarySaver: makePhotoLibrarySaver(),
            imageImporter: makeImageImporter(),
            imageUpscaleUseCase: makeImageUpscaleUseCase(),
            metadataStore: metadataStore,
            previewService: previewService,
            makeBackgroundRemover: makeBackgroundRemover,
            makeImageSourceResolver: makeImageSourceResolver,
            makeManualBackgroundBlurUseCase: makeManualBackgroundBlurUseCase,
            makeImageRenderRefresh: makeImageRenderRefresh
        )
    }

    // MARK: - 個別の実装

    /// メタデータの保存先。編集の記録と Revert の巻き戻しが同じ履歴を使うよう、アプリ全体で1つを共有する。
    static var metadataStore: any ImageMetadataStoring {
        ImageMetadataManager.shared
    }

    /// 描画サービス。要素間でキャッシュを共有するため、共有インスタンスを使う。
    static var previewService: any ImagePreviewing {
        ImagePreviewService.shared
    }

    static func makePhotoLibrarySaver() -> any PhotoLibrarySaving {
        SaveImageCoordinator(processingService: ImageProcessingService(), writer: PhotoLibraryWriter())
    }

    static func makeImageImporter() -> any ImageImporting {
        ImageImportCoordinator(useCase: ImageImportUseCase(
            elementBuilder: ImageImportElementBuilder(elementFactory: makeElementFactory())
        ))
    }

    static func makeImageUpscaleUseCase() -> ImageUpscaleUseCase {
        ImageUpscaleUseCase(lanczosPipeline: LanczosUpscalePipeline(), realESRGANPipeline: RealESRGANPipeline())
    }

    static func makeBackgroundRemover() -> any BackgroundRemovalProcessing {
        VisionBackgroundRemover()
    }

    static func makeImageSourceResolver() -> any ImageSourceResolving {
        ImageSourceResolver(assetRepository: ImageAssetRepository.shared)
    }

    static func makeManualBackgroundBlurUseCase() -> ManualBackgroundBlurUseCase {
        ManualBackgroundBlurUseCase(renderer: CoreImageBackgroundBlurRenderer())
    }

    /// 描画の更新。描画の間引きは状態を持つため、呼ぶたびに新しく作る。
    @MainActor
    static func makeImageRenderRefresh() -> ImageRenderRefreshUseCase {
        ImageRenderRefreshUseCase(renderScheduler: RenderScheduler())
    }

    /// 画像要素の生成。描画サービスは要素間でキャッシュを共有するため、共有インスタンスを渡す。
    static func makeElementFactory() -> ImageElementFactory {
        ImageElementFactory(
            loader: ImageInitializationLoader(),
            sourceResolver: makeImageSourceResolver(),
            previewService: previewService
        )
    }
}
