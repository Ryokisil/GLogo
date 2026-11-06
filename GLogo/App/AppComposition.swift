// 編集画面で使う技術的な実装（Infrastructure）を作って渡す Composition Root。
// ここから渡す依存は、受け取る側（UseCases・ViewModels）では境界の Protocol として扱う。

import Foundation

/// エディタの入口と、そこから開く2つの編集画面（手動背景除去・背景ぼかしマスク）が使う実装を組み立てる。
/// 生成の単位は、以前の初期化引数の既定値と同じにする。
/// 編集パネル側の一部の UseCase と Model には、まだ Infrastructure を指す既定値や直接の参照が残る
/// （docs/architecture/README.md の「計画外の対応と残件」で追跡）。
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
            makeBackgroundRemover: makeBackgroundRemover,
            makeImageSourceResolver: makeImageSourceResolver,
            makeManualBackgroundBlurUseCase: makeManualBackgroundBlurUseCase
        )
    }

    // MARK: - 個別の実装

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

    /// 画像要素の生成。描画サービスは要素間でキャッシュを共有するため、共有インスタンスを渡す。
    static func makeElementFactory() -> ImageElementFactory {
        ImageElementFactory(
            loader: ImageInitializationLoader(),
            sourceResolver: makeImageSourceResolver(),
            previewService: ImagePreviewService.shared
        )
    }
}
