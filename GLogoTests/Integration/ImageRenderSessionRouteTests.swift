// 受け取る側の入口（キャンバス・削除エフェクト・画像一覧・AI・フィルターのサムネイル・手動背景除去・背景ぼかしマスク）が、
// エディタの管理役を通して画像を受け取ることを確かめる。
// アプリの管理役と、ほかの経路（要素の依存で作ったセッション）は同じ画像を返すため、同じ画像が届くことだけでは接続漏れに気づけない。
// そこで問い合わせを記録する偽物の管理役をエディタに渡し、要素の元画像（赤）とは別の画像を返させて、
// 問い合わせの記録と、届いた画像（描かれた色・受け取った画像のインスタンス）の両方で見分ける。

import Combine
import SwiftUI
import XCTest
@testable import GLogo

final class ImageRenderSessionRouteTests: XCTestCase {
    // MARK: - キャンバスと削除エフェクト

    /// 実際のエディタ画面の中のキャンバスが、エディタの管理役から受け取った画像で描く。
    @MainActor
    func test_canvas_drawsImageFromRenderSessions() throws {
        var windows: [UIWindow] = []
        defer { windows.forEach { $0.isHidden = true } }
        let spy = RenderSessionSpy(drawing: snapshotImage(.magenta))
        let (editor, element) = try makeEditor(renderSessions: spy)
        let canvas = try showCanvas(of: editor, in: &windows)
        spy.removeAllRequests()

        let drawn = render(canvas)

        XCTAssertEqual(spy.requests, [.init(.drawingImage, element)], "画像要素の描く画像を、管理役に1回問い合わせる")
        try assertColor(of: drawn, at: CGPoint(x: 20, y: 20), equals: .magenta, "管理役が返した画像を描く")
    }

    /// キャンバスの削除モードの削除（CanvasViewRepresentable が設定した処理）は、削除の前に管理役からスナップショットの画像を受け取る。
    @MainActor
    func test_canvasDelete_snapshotsBeforeDeletion() throws {
        var windows: [UIWindow] = []
        defer { windows.forEach { $0.isHidden = true } }
        let spy = RenderSessionSpy(drawing: snapshotImage(.magenta))
        let (editor, element) = try makeEditor(renderSessions: spy)
        editor.selectElement(element)
        let canvas = try showCanvas(of: editor, in: &windows)
        let membership = recordMembership(of: element, in: editor, spy: spy)
        spy.removeAllRequests()

        let delete = try XCTUnwrap(canvas.onElementDelete)
        delete()

        XCTAssertEqual(spy.requests, [.init(.drawingImage, element)], "スナップショットの画像を、管理役に1回問い合わせる")
        XCTAssertEqual(membership.values, [true], "問い合わせは削除の前")
        XCTAssertFalse(editor.project.elements.contains { $0 === element }, "そのあと削除する")
    }

    /// ツールバーの削除も、確認のあと削除の前に、管理役から受け取った画像でスナップショットを作る。
    @MainActor
    func test_toolbarDelete_snapshotsBeforeDeletion() throws {
        let spy = RenderSessionSpy(drawing: snapshotImage(.magenta))
        let (editor, element) = try makeEditor(renderSessions: spy)
        editor.selectElement(element)
        let frame = element.frame
        let effect = DeleteEffectBox()
        let toolbar = EditorOverlayToolbarView(
            viewModel: editor,
            activeSheet: .constant(nil),
            deleteEffect: Binding(get: { effect.state }, set: { effect.state = $0 }),
            // 確認ダイアログで削除を選んだのと同じく、すぐに続きの処理を行う。
            onShowConfirmation: { _, action in action() },
            onOpenAppSettings: {}
        )
        let membership = recordMembership(of: element, in: editor, spy: spy)
        spy.removeAllRequests()

        toolbar.requestDelete()

        XCTAssertEqual(spy.requests, [.init(.drawingImage, element)], "スナップショットの画像を、管理役に1回問い合わせる")
        XCTAssertEqual(membership.values, [true], "問い合わせは削除の前")
        XCTAssertFalse(editor.project.elements.contains { $0 === element }, "そのあと削除する")
        XCTAssertTrue(effect.state.isActive)
        XCTAssertEqual(effect.state.frame, frame)
        let snapshot = try XCTUnwrap(effect.state.snapshot)
        try assertColor(of: snapshot, at: CGPoint(x: 10, y: 10), equals: .magenta, "管理役が返した画像でスナップショットを作る")
    }

    // MARK: - 画像一覧

    /// 画像一覧のサムネイルは、管理役から受け取った元画像で作る。
    @MainActor
    func test_imageListRail_usesOriginalFromRenderSessions() throws {
        var windows: [UIWindow] = []
        defer { windows.forEach { $0.isHidden = true } }
        let spy = RenderSessionSpy(original: snapshotImage(.blue))
        let (editor, element) = try makeEditor(renderSessions: spy)
        let second = try makeImageElement()
        editor.project.addElement(second)

        show(ImageListRailView(viewModel: editor), in: &windows)

        XCTAssertTrue(spy.requests.contains(.init(.originalImage, element)), "記録: \(spy.requests)")
        XCTAssertTrue(spy.requests.contains(.init(.originalImage, second)), "記録: \(spy.requests)")
    }

    // MARK: - AI とフィルターのサムネイル

    /// AI の3つの要求は、要求を受けた時点で管理役から元画像を受け取り、それを加工に渡す。
    @MainActor
    func test_aiRequests_useOriginalFromRenderSessions() async throws {
        let processor = ReceivedImageRecorder()
        let spy = RenderSessionSpy(original: snapshotImage(.blue))
        let (editor, element) = try makeEditor(renderSessions: spy, dependencies: .live(
            imageUpscaleUseCase: ImageUpscaleUseCase(lanczosPipeline: processor, realESRGANPipeline: processor),
            makeBackgroundRemover: { processor }
        ))
        editor.selectElement(element)
        let tools = editor.aiTools

        await assertRequest("背景除去", spy: spy, element: element, finished: tools.$isProcessingAI) {
            tools.requestAIBackgroundRemoval(for: element)
        }
        await assertRequest("背景ぼかし", spy: spy, element: element, finished: tools.$isProcessingAI) {
            tools.requestAIBackgroundBlur(for: element)
        }
        await assertRequest("高画質化", spy: spy, element: element, finished: tools.$isProcessingUpscale) {
            tools.requestImageUpscale(for: element, method: .lanczos)
        }

        let received = await processor.received
        XCTAssertEqual(received.count, 3)
        XCTAssertTrue(received.allSatisfy { $0 === spy.original }, "管理役が返した元画像を加工に渡す")
    }

    /// フィルターのサムネイルは、管理役から受け取った元画像と描画サービスで作る。
    @MainActor
    func test_filterThumbnail_usesRenderSessions() async throws {
        let service = FixedPreviewService(output: snapshotImage(.green))
        let spy = RenderSessionSpy(original: snapshotImage(.blue), service: service)
        let (editor, element) = try makeEditor(renderSessions: spy)
        let panels = ElementViewModel(editorViewModel: editor)
        editor.selectElement(element)
        spy.removeAllRequests()

        let thumbnail = await panels.filters.generateFilterPreview(for: FilterCatalog.noir,
                                                                   targetSize: CGSize(width: 20, height: 20))

        XCTAssertEqual(spy.requests, [.init(.originalImage, element), .init(.previewService, element)])
        XCTAssertTrue(thumbnail === service.output, "管理役が返した描画サービスで作る")
    }

    // MARK: - 編集画面

    /// 手動背景除去は、元画像が取れないときにだけ、そのあとで表示画像を受け取る（今の評価の順序）。
    @MainActor
    func test_manualRemoval_fallsBackToDisplayAfterOriginal() throws {
        let spy = RenderSessionSpy(original: nil, display: snapshotImage(.blue))
        let element = try makeImageElement()

        let viewModel = ManualBackgroundRemovalViewModel(
            imageElement: element, renderSessions: spy, completion: { _ in },
            backgroundRemovalUseCase: ReceivedImageRecorder(), imageSourceResolver: ProviderPassingResolver()
        )

        XCTAssertEqual(spy.requests, [.init(.originalImage, element), .init(.displayImage, element)])
        XCTAssertTrue(viewModel.originalImage === spy.display, "元画像が取れなければ、表示画像で編集する")
    }

    /// 手動背景除去は、元画像が取れれば表示画像を求めない。
    @MainActor
    func test_manualRemoval_usesOriginalWithoutDisplay() throws {
        let spy = RenderSessionSpy(original: snapshotImage(.green), display: snapshotImage(.blue))
        let element = try makeImageElement()

        let viewModel = ManualBackgroundRemovalViewModel(
            imageElement: element, renderSessions: spy, completion: { _ in },
            backgroundRemovalUseCase: ReceivedImageRecorder(), imageSourceResolver: ProviderPassingResolver()
        )

        XCTAssertEqual(spy.requests, [.init(.originalImage, element)], "表示画像は求めない（加工とキャッシュが走らない）")
        XCTAssertTrue(viewModel.originalImage === spy.original)
    }

    /// 背景ぼかしマスクの編集は、管理役から受け取った元画像で編集する。
    @MainActor
    func test_blurMask_usesOriginalFromRenderSessions() throws {
        let spy = RenderSessionSpy(original: snapshotImage(.green), display: snapshotImage(.blue))
        let element = try makeImageElement()

        let viewModel = BackgroundBlurMaskEditViewModel(
            imageElement: element, renderSessions: spy, initialMaskData: nil, blurRadius: 6, completion: { _ in },
            manualBackgroundBlurUseCase: AppComposition.makeManualBackgroundBlurUseCase(),
            backgroundRemovalUseCase: ReceivedImageRecorder(), imageSourceResolver: ProviderPassingResolver()
        )

        XCTAssertEqual(spy.requests, [.init(.originalImage, element)])
        XCTAssertTrue(viewModel.originalImage === spy.original)
    }

    // MARK: - 組み立て

    /// 偽物の管理役を持つエディタと、プロジェクトに置いた画像要素。
    @MainActor
    private func makeEditor(
        renderSessions: RenderSessionSpy,
        dependencies: EditorDependencies? = nil
    ) throws -> (EditorViewModel, ImageElement) {
        let element = try makeImageElement()
        let project = LogoProject()
        project.addElement(element)
        let editor = EditorViewModel(project: project, dependencies: dependencies ?? .live(), renderSessions: renderSessions)
        return (editor, element)
    }

    /// 要素の元画像は赤（偽物の管理役を通らない経路で描くと赤になる）。キャンバスの (10, 10) から 20×20 に置く。
    private func makeImageElement() throws -> ImageElement {
        let element = ImageElementFactory().makeElement(imageData: try XCTUnwrap(snapshotImage(.red).pngData()))
        element.position = CGPoint(x: 10, y: 10)
        element.size = CGSize(width: 20, height: 20)
        return element
    }

    /// 削除の前に問い合わせたかを調べるため、キャンバスに描く画像の問い合わせごとに、その時点で要素がプロジェクトにあったかを記録する。
    @MainActor
    private func recordMembership(of element: ImageElement, in editor: EditorViewModel,
                                  spy: RenderSessionSpy) -> MembershipLog {
        let log = MembershipLog()
        spy.onRequest = { [weak editor] request, requested in
            guard request.kind == .drawingImage, requested === element, let editor else { return }
            log.values.append(editor.project.elements.contains { $0 === element })
        }
        return log
    }

    /// 実際のエディタ画面を表示し、その中のキャンバスを取り出す。
    @MainActor
    private func showCanvas(of editor: EditorViewModel, in windows: inout [UIWindow]) throws -> CanvasView {
        let host = show(EditorView(viewModel: editor), in: &windows)
        return try XCTUnwrap(findCanvas(in: host.view), "エディタ画面の中にキャンバスがある")
    }

    @MainActor
    private func findCanvas(in view: UIView) -> CanvasView? {
        if let canvas = view as? CanvasView { return canvas }
        for subview in view.subviews {
            if let canvas = findCanvas(in: subview) { return canvas }
        }
        return nil
    }

    @MainActor
    @discardableResult
    private func show<Screen: View>(_ screen: Screen, in windows: inout [UIWindow]) -> UIHostingController<Screen> {
        let host = UIHostingController(rootView: screen)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        windows.append(window)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        return host
    }

    /// キャンバスの描画（draw(_:)）を、キャンバスの左上 40×40 の範囲で行う。
    @MainActor
    private func render(_ canvas: CanvasView) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let rect = CGRect(x: 0, y: 0, width: 40, height: 40)
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
            canvas.draw(rect)
        }
    }

    /// 要求を出した時点で管理役に元画像を1回問い合わせることを確かめ、処理の終了を待つ。
    @MainActor
    private func assertRequest(
        _ name: String,
        spy: RenderSessionSpy,
        element: ImageElement,
        finished processing: Published<Bool>.Publisher,
        file: StaticString = #filePath,
        line: UInt = #line,
        request: () -> Void
    ) async {
        let finished = expectation(description: "\(name)の終了")
        let observation = processing.dropFirst().filter { !$0 }.first().sink { _ in finished.fulfill() }
        defer { observation.cancel() }
        spy.removeAllRequests()

        request()

        XCTAssertEqual(spy.requests, [.init(.originalImage, element)], "\(name): 要求を受けた時点で受け取る",
                       file: file, line: line)
        await fulfillment(of: [finished], timeout: 3)
    }

    /// 画像の指定位置（上からの座標）の色が、期待した色に近いことを確かめる。
    private func assertColor(
        of image: UIImage,
        at point: CGPoint,
        equals expected: UIColor,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let cgImage = try XCTUnwrap(image.cgImage, file: file, line: line)
        let width = cgImage.width
        let height = cgImage.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let context = try XCTUnwrap(CGContext(
            data: &buffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo
        ), file: file, line: line)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let offset = (Int(point.y) * width + Int(point.x)) * 4
        let actual = Array(buffer[offset..<(offset + 4)])

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        expected.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let expectedComponents = [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
        for (index, value) in actual.enumerated() {
            XCTAssertLessThanOrEqual(abs(Int(value) - expectedComponents[index]), 8,
                                     "\(message)（期待: \(expectedComponents)、実際: \(actual)）", file: file, line: line)
        }
    }
}

// MARK: - 記録用

/// 削除エフェクトの状態を、テストから読み書きできるように持つ。
@MainActor
private final class DeleteEffectBox {
    var state = DeleteEffectState()
}

/// 問い合わせの時点で、要素がプロジェクトにあったかの記録。
@MainActor
private final class MembershipLog {
    var values: [Bool] = []
}

/// 受け取った画像を記録し、失敗を返す AI 処理。結果の適用まで進めず、届いた画像だけを確かめる。
private actor ReceivedImageRecorder: BackgroundRemovalProcessing, ImageUpscalingPipeline {
    private(set) var received: [UIImage] = []

    nonisolated var method: ImageUpscaleMethod { .lanczos }
    nonisolated var isAvailable: Bool { true }

    func removeBackground(from image: UIImage) async throws -> UIImage {
        received.append(image)
        throw RecordedFailure()
    }

    func generateMask(from image: UIImage) async throws -> UIImage {
        received.append(image)
        throw RecordedFailure()
    }

    func upscale(_ request: ImageUpscaleRequest) async throws -> ImageUpscaleResult {
        received.append(request.sourceImage)
        throw RecordedFailure()
    }
}

private struct RecordedFailure: LocalizedError {
    var errorDescription: String? { "テスト用の処理失敗" }
}

/// 編集用画像として、渡された元画像（管理役から受け取った画像）をそのまま返す。
private struct ProviderPassingResolver: ImageSourceResolving {
    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        nil
    }

    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? {
        originalImageProvider()
    }
}
