// 描画依存の独立性、生成経路での引き継ぎ、サムネイルとメモリ警告の接続を検証する。

import UIKit
import XCTest
@testable import GLogo

final class ImagePreviewDependencyTests: XCTestCase {
    func test_defaultDependency_reusesSharedService() throws {
        let first = ImageElementFactory().makeElement(imageData: Data())
        let second = ImageElementFactory().makeElement(imageData: Data())
        XCTAssertTrue(first.previewService === second.previewService)
        XCTAssertTrue(first.previewService === ImagePreviewService.shared)
        let decoded = try JSONDecoder().decode(ImageElement.self, from: JSONEncoder().encode(first))
        XCTAssertTrue(decoded.previewService === first.previewService)
    }

    func test_rendering_isolatesServicesAndResets() throws {
        let firstService = PreviewDependencySpy(color: .red)
        let secondService = PreviewDependencySpy(color: .blue)
        let first = try element(service: firstService)
        let second = try element(service: secondService)
        first.appliedFilterPresetId = "hdr_fixture"
        first.brightnessAdjustment = 0.25
        XCTAssertTrue(first.image === firstService.output)
        XCTAssertTrue(second.image === secondService.output)
        XCTAssertTrue(first.getInstantPreview() === firstService.output)
        XCTAssertTrue(second.getInstantPreview() === secondService.output)
        XCTAssertEqual(firstService.state.mode, .hdr)
        XCTAssertEqual(firstService.state.brightness, 0.25)
        XCTAssertEqual(secondService.state.mode, .sdr)
        XCTAssertEqual(secondService.state.brightness, 0)
        first.replaceImageSource(with: Data(), resetAdjustments: false)
        XCTAssertEqual(firstService.state.resets, 1)
        XCTAssertEqual(secondService.state.resets, 0)
        XCTAssertTrue(second.image === secondService.output)
        XCTAssertEqual(secondService.state.syncCalls, 1, "他要素の差し替えで描画結果を失わない")
    }

    @MainActor
    func test_asyncRendering_keepsBoundService() async throws {
        let firstService = PreviewDependencySpy(color: .red)
        let secondService = PreviewDependencySpy(color: .blue)
        let first = try element(service: firstService)
        let second = try element(service: secondService)
        let rendered = await first.renderFullQualityImageAsync()
        XCTAssertTrue(rendered === firstService.output)
        XCTAssertNil(first.cachedImage, "世代照合前の結果はModelへ書き込まない")
        let secondRendered = await second.renderFullQualityImageAsync()
        XCTAssertTrue(secondRendered === secondService.output)
        XCTAssertEqual(firstService.state.asyncCalls, 1)
        XCTAssertEqual(secondService.state.asyncCalls, 1)
        XCTAssertEqual(firstService.state.quality, .full)
    }

    func test_initializersAndCopies_preserveDependency() throws {
        let service = PreviewDependencySpy(color: .orange)
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let factory = ImageElementFactory(previewService: service)
        // 保存データ由来のソースは Model の初期化で直接作り、複製の各分岐も通す。
        let legacySources: [ImageElement.ImageSource] = [.fileName(""), .path(missing.path), .url(missing)]
        let elements = [
            factory.makeElement(imageData: Data()),
            factory.makeElement(imageData: Data(), canvasSize: CGSize(width: 80, height: 80))
        ] + legacySources.map {
            ImageElement(source: $0, size: nil, sourceResolver: ImageSourceResolver(), previewService: service)
        }
        for element in elements {
            let copy = try XCTUnwrap(element.copy() as? ImageElement)
            XCTAssertTrue(element.previewService === service)
            XCTAssertTrue(copy.previewService === service)
            XCTAssertTrue(element.renderCopy().previewService === service)
            XCTAssertNil(copy.cachedImage)
            XCTAssertNotEqual(element.id, copy.id)
        }
    }

    func test_projectDecode_preservesFormatAndIsolatesServices() throws {
        let project = LogoProject()
        let original = try element(service: PreviewDependencySpy(color: .orange))
        project.addElement(original)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(project)
        let first = PreviewDependencySpy(color: .red)
        let second = PreviewDependencySpy(color: .blue)
        for service in [first, second] {
            let decoder = JSONDecoder()
            decoder.userInfo[.imagePreviewService] = service
            let decoded = try decoder.decode(LogoProject.self, from: data)
            let image = try XCTUnwrap(decoded.elements.first as? ImageElement)
            XCTAssertTrue(image.previewService === service)
            XCTAssertTrue(image.image === service.output)
            XCTAssertEqual(try encoder.encode(decoded), data)
        }
        XCTAssertEqual(first.state.syncCalls, 1)
        XCTAssertEqual(second.state.syncCalls, 1)
    }

    func test_importBuilder_propagatesDependency() throws {
        let service = PreviewDependencySpy(color: .yellow)
        let importer = ImageImportCoordinator(useCase: ImageImportUseCase(
            elementBuilder: ImageImportElementBuilder(elementFactory: ImageElementFactory(previewService: service))))
        let data = try XCTUnwrap(snapshotImage(.green).pngData())
        for canvas in [nil, CGSize(width: 800, height: 600)] as [CGSize?] {
            let result = try XCTUnwrap(importer.importImage(
                source: .imageData(data), project: LogoProject(), viewportSize: CGSize(width: 320, height: 640),
                assetIdentifier: nil, canvasSize: canvas))
            XCTAssertTrue(result.element.previewService === service)
            XCTAssertTrue(result.element.image === service.output)
        }
    }

    @MainActor
    func test_thumbnails_useSelectedImageService() async throws {
        let firstService = PreviewDependencySpy(color: .red)
        let secondService = PreviewDependencySpy(color: .blue)
        let first = try element(service: firstService)
        let second = try element(service: secondService)
        first.brightnessAdjustment = 0.25
        let project = LogoProject()
        project.addElement(first)
        project.addElement(second)
        let editor = EditorViewModel(project: project)
        let panels = ElementViewModel(editorViewModel: editor)
        editor.selectElement(first)
        let firstResult = await panels.filters.generateFilterPreview(for: FilterCatalog.noir,
                                                                     targetSize: CGSize(width: 20, height: 20))
        editor.selectElement(second)
        let secondResult = await panels.filters.generateFilterPreview(for: FilterCatalog.noir,
                                                                      targetSize: CGSize(width: 20, height: 20))
        XCTAssertTrue(firstResult === firstService.output)
        XCTAssertTrue(secondResult === secondService.output)
        XCTAssertEqual(firstService.state.brightness, 0.25)
        XCTAssertEqual(secondService.state.brightness, 0)
        XCTAssertEqual(firstService.state.asyncCalls, 1)
        XCTAssertEqual(secondService.state.asyncCalls, 1)
        XCTAssertEqual(firstService.state.quality, .preview)
        XCTAssertEqual(firstService.state.mode, .sdr)
    }

    func test_facadeReleaseMemory_releasesBothServices() {
        let sdr = PreviewDependencySpy(color: .red)
        let hdr = PreviewDependencySpy(color: .blue)
        ImagePreviewService(sdrService: sdr, hdrService: hdr).releaseMemory()
        XCTAssertEqual(sdr.state.resets, 1)
        XCTAssertEqual(hdr.state.resets, 1)
    }

    func test_cacheRelease_resetsEachUsedServiceOnce() throws {
        let shared = PreviewDependencySpy(color: .red)
        let separate = PreviewDependencySpy(color: .blue)
        let unused = PreviewDependencySpy(color: .green)
        let images = try [element(service: shared), element(service: shared), element(service: separate)]
        for image in images { XCTAssertNotNil(image.image) }
        ImageCacheReleaseUseCase.releaseCaches(in: images, defaultService: ImagePreviewService.shared)
        for image in images { XCTAssertNil(image.cachedImage) }
        XCTAssertEqual(shared.state.resets, 1)
        XCTAssertEqual(separate.state.resets, 1)
        XCTAssertEqual(unused.state.resets, 0)
        ImageCacheReleaseUseCase.releaseCaches(in: [], defaultService: ImagePreviewService.shared)
        XCTAssertEqual(shared.state.resets, 1)
    }

    @MainActor
    func test_editorMemoryWarning_releasesInjectedService() async throws {
        let reset = expectation(description: "描画サービスのキャッシュ解放")
        let service = PreviewDependencySpy(color: .red, onReset: { reset.fulfill() })
        let image = try element(service: service)
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project)
        XCTAssertNotNil(image.image)
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        await fulfillment(of: [reset], timeout: 2)
        XCTAssertNil(image.cachedImage)
        XCTAssertEqual(service.state.resets, 1)
        withExtendedLifetime(editor) {}
    }

    /// 注入した描画サービスを既定の解放対象にし、画像が同じサービスを使っていても1回だけ解放する。
    /// 画像ごとの別の描画サービスも引き続き解放する。
    @MainActor
    func test_editorMemoryWarning_releasesInjectedDefaultOnce() async throws {
        let released = expectation(description: "注入したサービスと画像のサービスの解放")
        released.expectedFulfillmentCount = 2
        let injected = PreviewDependencySpy(color: .red, onReset: { released.fulfill() })
        let separate = PreviewDependencySpy(color: .blue, onReset: { released.fulfill() })
        let project = LogoProject()
        project.addElement(try element(service: injected))
        project.addElement(try element(service: separate))
        let editor = EditorViewModel(project: project, dependencies: .live(previewService: injected))

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)

        await fulfillment(of: [released], timeout: 2)
        XCTAssertEqual(injected.state.resets, 1, "既定と画像で同じサービスは1回だけ解放する")
        XCTAssertEqual(separate.state.resets, 1)
        withExtendedLifetime(editor) {}
    }

    /// 画像が1枚もなくても、注入した描画サービスを解放する。
    @MainActor
    func test_editorMemoryWarning_releasesInjectedDefaultWithoutImages() async {
        let released = expectation(description: "注入したサービスの解放")
        let injected = PreviewDependencySpy(color: .red, onReset: { released.fulfill() })
        let editor = EditorViewModel(project: LogoProject(), dependencies: .live(previewService: injected))

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)

        await fulfillment(of: [released], timeout: 2)
        XCTAssertEqual(injected.state.resets, 1)
        withExtendedLifetime(editor) {}
    }

    private func element(service: any ImagePreviewing) throws -> ImageElement {
        let data = try XCTUnwrap(snapshotImage(.white).pngData())
        return ImageElementFactory(previewService: service).makeElement(imageData: data)
    }
}

/// 可変の観測値はロック下でのみ読み書きし、固定したUIImageを描画結果として返す。
private final class PreviewDependencySpy: ImagePreviewing, @unchecked Sendable {
    struct State {
        var syncCalls = 0
        var asyncCalls = 0
        var resets = 0
        var brightness: CGFloat?
        var mode: ImageRenderMode?
        var quality: ToneCurveFilter.Quality?
    }

    let output: UIImage
    private let lock = NSLock()
    private var storage = State()
    private let onReset: @Sendable () -> Void
    var state: State { lock.withLock { storage } }

    init(color: UIColor, onReset: @escaping @Sendable () -> Void = {}) {
        output = snapshotImage(color)
        self.onReset = onReset
    }

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        editingImage ?? originalImage
    }

    func instantPreview(baseImage: UIImage?, params: ImageFilterParams,
                        quality: ToneCurveFilter.Quality, mode: ImageRenderMode) -> UIImage? {
        record(params: params, quality: quality, mode: mode)
        return output
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams,
                      quality: ToneCurveFilter.Quality, mode: ImageRenderMode) -> UIImage? {
        lock.withLock { storage.syncCalls += 1 }
        record(params: params, quality: quality, mode: mode)
        return output
    }

    func applyFiltersAsync(to image: UIImage, params: ImageFilterParams,
                           quality: ToneCurveFilter.Quality, mode: ImageRenderMode) async -> UIImage? {
        lock.withLock { storage.asyncCalls += 1 }
        record(params: params, quality: quality, mode: mode)
        return output
    }

    func resetCache() {
        lock.withLock { storage.resets += 1 }
        onReset()
    }

    private func record(params: ImageFilterParams, quality: ToneCurveFilter.Quality, mode: ImageRenderMode) {
        lock.withLock {
            storage.brightness = params.brightness
            storage.mode = mode
            storage.quality = quality
        }
    }
}
