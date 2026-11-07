// 本番の初期化から外した既定値（アプリで使う実装）を、既存テストの呼び出しのために補う生成口。
// 中身は Composition Root（AppComposition）と同じ生成関数を使い、テストで明示した実装（偽物を含む）はそのまま渡す。
// 本番コードに既定値が残っているわけではない。新しいテストは、依存を明示して渡すことを優先する。

import UIKit
@testable import GLogo

extension EditorDependencies {
    /// アプリと同じ実装で組み立て、指定した依存だけを差し替える。
    /// 指定しなかった依存は、以前の既定値と同じく必要になったものだけを作る。
    @MainActor
    static func live(
        photoLibrarySaver: (any PhotoLibrarySaving)? = nil,
        imageImporter: (any ImageImporting)? = nil,
        imageUpscaleUseCase: ImageUpscaleUseCase? = nil,
        metadataStore: (any ImageMetadataStoring)? = nil,
        previewService: (any ImagePreviewing)? = nil,
        makeBackgroundRemover: (@MainActor () -> any BackgroundRemovalProcessing)? = nil,
        makeImageRenderRefresh: (@MainActor () -> ImageRenderRefreshUseCase)? = nil
    ) -> EditorDependencies {
        EditorDependencies(
            photoLibrarySaver: photoLibrarySaver ?? AppComposition.makePhotoLibrarySaver(),
            imageImporter: imageImporter ?? AppComposition.makeImageImporter(),
            imageUpscaleUseCase: imageUpscaleUseCase ?? AppComposition.makeImageUpscaleUseCase(),
            metadataStore: metadataStore ?? AppComposition.metadataStore,
            previewService: previewService ?? AppComposition.previewService,
            makeBackgroundRemover: makeBackgroundRemover ?? AppComposition.makeBackgroundRemover,
            makeImageSourceResolver: AppComposition.makeImageSourceResolver,
            makeManualBackgroundBlurUseCase: AppComposition.makeManualBackgroundBlurUseCase,
            makeImageRenderRefresh: makeImageRenderRefresh ?? AppComposition.makeImageRenderRefresh
        )
    }
}

extension EditorViewModel {
    /// 第9回で初期化から外した既定値と同じ実装で組み立てる。
    /// 引数の並びは以前の初期化と同じにし、既存テストの呼び出しを変えずに通す。
    convenience init(
        project: LogoProject = LogoProject(),
        backgroundRemovalUseCase: (any BackgroundRemovalProcessing)? = nil,
        photoLibrarySaver: (any PhotoLibrarySaving)? = nil,
        imageImporter: (any ImageImporting)? = nil,
        viewportSizeProvider: @escaping @MainActor () -> CGSize = { UIScreen.main.bounds.size },
        imageUpscaleUseCase: ImageUpscaleUseCase? = nil
    ) {
        var makeBackgroundRemover: (@MainActor () -> any BackgroundRemovalProcessing)?
        if let backgroundRemovalUseCase {
            makeBackgroundRemover = { backgroundRemovalUseCase }
        }
        let dependencies = EditorDependencies.live(
            photoLibrarySaver: photoLibrarySaver,
            imageImporter: imageImporter,
            imageUpscaleUseCase: imageUpscaleUseCase,
            makeBackgroundRemover: makeBackgroundRemover
        )
        self.init(project: project, dependencies: dependencies, viewportSizeProvider: viewportSizeProvider)
    }
}

extension ElementViewModel {
    /// エディタが受け取った依存から、EditorView と同じ形でパネルを組み立てる（第10回で初期化から外した既定値の代わり）。
    /// `imageRefresh` を指定したときは、調整とフィルターがそれを共有する。フレームには別のものを作る。
    convenience init(editorViewModel: EditorViewModel, imageRefresh: ImageRenderRefreshUseCase? = nil) {
        let dependencies = editorViewModel.dependencies
        self.init(
            editorViewModel: editorViewModel,
            imageRefresh: imageRefresh ?? dependencies.makeImageRenderRefresh(),
            frameImageRefresh: dependencies.makeImageRenderRefresh(),
            metadataStore: dependencies.metadataStore
        )
    }
}

extension ImageElementFactory {
    // 既存テストが使う引数の組み合わせだけを用意する。本番の3引数の初期化とは形が異なるため、呼び出しは曖昧にならない。

    init() {
        self = Self.live()
    }

    init(loader: any ImageInitializationLoading) {
        self = Self.live(loader: loader)
    }

    init(sourceResolver: any ImageSourceResolving) {
        self = Self.live(sourceResolver: sourceResolver)
    }

    init(previewService: any ImagePreviewing) {
        self = Self.live(previewService: previewService)
    }

    init(sourceResolver: any ImageSourceResolving, previewService: any ImagePreviewing) {
        self = Self.live(sourceResolver: sourceResolver, previewService: previewService)
    }

    /// 指定しなかった依存は、Composition Root と同じ実装にする。
    private static func live(
        loader: (any ImageInitializationLoading)? = nil,
        sourceResolver: (any ImageSourceResolving)? = nil,
        previewService: (any ImagePreviewing)? = nil
    ) -> ImageElementFactory {
        ImageElementFactory(
            loader: loader ?? ImageInitializationLoader(),
            sourceResolver: sourceResolver ?? AppComposition.makeImageSourceResolver(),
            previewService: previewService ?? ImagePreviewService.shared
        )
    }
}

extension ImageImportCoordinator {
    init() {
        self.init(useCase: ImageImportUseCase(
            elementBuilder: ImageImportElementBuilder(elementFactory: AppComposition.makeElementFactory())
        ))
    }
}

extension ImageUpscaleUseCase {
    init() {
        self = AppComposition.makeImageUpscaleUseCase()
    }
}
