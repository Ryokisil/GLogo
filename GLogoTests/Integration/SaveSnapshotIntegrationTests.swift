// 権限待ち・加工待ち・AI 完了を制御し、保存要求時の内容が書き出されることと、合成をメインスレッドの外で呼ぶことを検証する。

import Combine
import Photos
import UIKit
import XCTest
@testable import GLogo

final class SaveSnapshotIntegrationTests: XCTestCase {
    @MainActor
    func test_authorizationWait_freezesBothSaveEntries() async throws {
        for composite in [false, true] {
            let writer = SnapshotWriter()
            let coordinator = SaveImageCoordinator(processingService: ImageProcessingService(), writer: writer)
            let (project, image) = makeProject()
            let expected = try XCTUnwrap(composite
                ? ImageProcessingService().makeCompositeImage(baseElement: image, project: project)
                : ImageProcessingService().applyFilters(to: image))
            let completed = expectation(description: "保存完了")
            let completion: @MainActor @Sendable (PhotoLibrarySaveResult) -> Void = { result in
                if case .failure(let error) = result { XCTFail("\(error)") }
                completed.fulfill()
            }
            if composite {
                coordinator.saveComposite(project: project, completion: completion)
            } else {
                coordinator.save(project: project, completion: completion)
            }
            image.replaceImageSource(with: snapshotImage(.blue).pngData()!, resetAdjustments: true)
            image.showFrame = true
            image.size = CGSize(width: 3, height: 2)
            project.backgroundSettings.color = .green
            project.canvasSize = .zero
            project.elements.removeAll()
            writer.authorize()
            await fulfillment(of: [completed], timeout: 5)
            XCTAssertEqual(writer.savedImage?.pngData(), expected.pngData())
            XCTAssertEqual(writer.writeCount, 1)
        }
    }

    @MainActor
    func test_processingWait_isolatesComposition() async throws {
        let writer = SnapshotWriter()
        let started = expectation(description: "加工開始")
        let processor = PausedSnapshotProcessing(started: started)
        defer { processor.resume() }
        let coordinator = SaveImageCoordinator(processingService: processor, writer: writer)
        let (project, base) = makeProject()
        let overlay = ImageElementFactory().makeElement(imageData: snapshotImage(.blue).pngData()!, importOrder: 2)
        overlay.imageRole = .overlay
        overlay.position = CGPoint(x: 4, y: 5)
        overlay.size = CGSize(width: 8, height: 8)
        overlay.zIndex = 180
        let text = TextElement(text: "A", fontSize: 12)
        text.size = CGSize(width: 16, height: 16)
        let glow = GlowEffect(color: .green, radius: 2)
        text.effects = [glow]
        text.zIndex = 310
        let shape = ShapeElement(shapeType: .rectangle, fillColor: .yellow)
        shape.size = CGSize(width: 4, height: 4)
        shape.zIndex = 220
        project.elements += [overlay, text, shape]
        let expected = try XCTUnwrap(ImageProcessingService().makeCompositeImage(baseElement: base, project: project))
        let completed = expectation(description: "合成保存完了")
        coordinator.save(project: project) { result in
            if case .failure(let error) = result { XCTFail("\(error)") }
            completed.fulfill()
        }
        writer.authorize()
        await fulfillment(of: [started], timeout: 5)
        base.imageRole = .overlay
        overlay.imageRole = .base
        overlay.zIndex = 500
        text.text = "B"
        glow.radius = 10
        shape.fillColor = .black
        base.brightnessAdjustment = 0.8
        project.elements.removeAll()
        processor.resume()
        await fulfillment(of: [completed], timeout: 5)
        XCTAssertEqual(writer.savedImage?.pngData(), expected.pngData())
        XCTAssertEqual(text.text, "B")
        XCTAssertEqual(glow.radius, 10, "保存側の描画は編集側の効果を触らない")
    }

    @MainActor
    func test_aiCompletionAndUndo_doNotChangePendingSave() async throws {
        let writer = SnapshotWriter()
        let started = expectation(description: "AI 開始")
        let ai = SaveBoundaryAIProcessor(started: started)
        let (project, image) = makeProject()
        image.brightnessAdjustment = 0.2
        let expected = try XCTUnwrap(ImageProcessingService().applyFilters(to: image))
        let editor = EditorViewModel(project: project, backgroundRemovalUseCase: ai,
                                     photoLibrarySaver: SaveImageCoordinator(processingService: ImageProcessingService(), writer: writer))
        let aiFinished = expectation(description: "AI 完了")
        let observation = editor.aiTools.$isProcessingAI.dropFirst().filter { !$0 }.sink { _ in aiFinished.fulfill() }
        editor.aiTools.requestAIBackgroundRemoval(for: image)
        await fulfillment(of: [started], timeout: 3)
        let saved = expectation(description: "保存完了")
        editor.saveToPhotoLibrary { result in
            if case .failure(let error) = result { XCTFail("\(error)") }
            saved.fulfill()
        }
        XCTAssertTrue(editor.isSavingImage)
        await ai.finish(snapshotImage(.blue))
        await fulfillment(of: [aiFinished], timeout: 3)
        XCTAssertEqual(image.brightnessAdjustment, 0)
        editor.undo()
        XCTAssertEqual(image.brightnessAdjustment, 0.2)
        editor.redo()
        project.removeElement(withId: image.id)
        writer.authorize()
        await fulfillment(of: [saved], timeout: 5)
        XCTAssertEqual(writer.savedImage?.pngData(), expected.pngData())
        XCTAssertFalse(editor.isSavingImage)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_pendingSave_doesNotRetainSourceProject() async {
        let writer = SnapshotWriter()
        var project: LogoProject? = makeProject().0
        weak var source = project
        let completed = expectation(description: "画面解放後の保存完了")
        SaveImageCoordinator(processingService: ImageProcessingService(), writer: writer).save(project: project!) { result in
            if case .failure(let error) = result { XCTFail("\(error)") }
            completed.fulfill()
        }
        project = nil
        XCTAssertNil(source)
        writer.authorize()
        await fulfillment(of: [completed], timeout: 5)
        XCTAssertEqual(writer.writeCount, 1)
    }

    // MARK: - エディタの管理役（第18回）

    /// 両方の入口で、元画像は権限待ちより前の受付で管理役から1回だけ受け取り、完了まで問い合わせない。
    /// 保存した画像は、管理役が返した画像（要素自身の赤ではなく緑）から作られる。
    @MainActor
    func test_acceptance_readsStoreOnlyWhileSaving() async throws {
        for composite in [false, true] {
            let writer = SnapshotWriter()
            let coordinator = SaveImageCoordinator(processingService: ImageProcessingService(), writer: writer)
            let (project, image) = makeProject()
            let store = RenderSessionSpy(original: snapshotImage(.green))
            let completed = expectation(description: "保存完了")
            let completion: @MainActor @Sendable (PhotoLibrarySaveResult) -> Void = { result in
                if case .failure(let error) = result { XCTFail("\(error)") }
                completed.fulfill()
            }
            if composite {
                coordinator.saveComposite(project: project, renderSessions: store, completion: completion)
            } else {
                coordinator.save(project: project, renderSessions: store, completion: completion)
            }
            XCTAssertEqual(store.requests, [.init(.originalImage, image)], "合成: \(composite)")

            writer.authorize()
            await fulfillment(of: [completed], timeout: 5)
            XCTAssertEqual(store.requests.count, 1, "受付のあとは問い合わせない（合成: \(composite)）")
            try assertCenter(of: XCTUnwrap(writer.savedImage), isGreen: true, "合成: \(composite)")
        }
    }

    /// 保存の要求は管理役を持たない。権限待ちの間に管理役を解放しても、受付で固定した画像で保存できる。
    @MainActor
    func test_pendingSave_doesNotRetainStore() async throws {
        for composite in [false, true] {
            let writer = SnapshotWriter()
            let coordinator = SaveImageCoordinator(processingService: ImageProcessingService(), writer: writer)
            let (project, _) = makeProject()
            var store: RenderSessionSpy? = RenderSessionSpy(original: snapshotImage(.green))
            weak let weakStore = store
            let completed = expectation(description: "管理役の解放後の保存完了")
            let completion: @MainActor @Sendable (PhotoLibrarySaveResult) -> Void = { result in
                if case .failure(let error) = result { XCTFail("\(error)") }
                completed.fulfill()
            }
            if composite {
                coordinator.saveComposite(project: project, renderSessions: try XCTUnwrap(store), completion: completion)
            } else {
                coordinator.save(project: project, renderSessions: try XCTUnwrap(store), completion: completion)
            }
            store = nil
            XCTAssertNil(weakStore, "権限待ちの間、保存の要求は管理役を持たない（合成: \(composite)）")

            writer.authorize()
            await fulfillment(of: [completed], timeout: 5)
            XCTAssertEqual(writer.writeCount, 1)
            try assertCenter(of: XCTUnwrap(writer.savedImage), isGreen: true, "合成: \(composite)")
        }
    }

    /// 受付のあとのメモリ警告でエディタの要素のキャッシュが消えても、保存は受付で固定した元画像を使う。
    @MainActor
    func test_memoryWarningAfterAcceptance_usesPinnedImage() async throws {
        let writer = SnapshotWriter()
        let released = expectation(description: "メモリ警告の処理の終了")
        let editor = EditorViewModel(
            project: LogoProject(canvasSize: CGSize(width: 32, height: 24)),
            dependencies: .live(
                photoLibrarySaver: SaveImageCoordinator(processingService: ImageProcessingService(), writer: writer),
                previewService: ReleaseSignalingPreview { released.fulfill() }
            )
        )
        let store = try XCTUnwrap(editor.managedRenderSessions as? ImageRenderSessionStore)
        let source = SwitchableResolver(image: snapshotImage(.red))
        let image = ImageElement(source: .data(Data([1])), size: nil, sourceResolver: source, previewService: PassThroughPreview())
        image.size = CGSize(width: 32, height: 24)
        editor.addElement(image)
        let completed = expectation(description: "保存完了")
        editor.saveToPhotoLibrary { result in
            if case .failure(let error) = result { XCTFail("\(error)") }
            completed.fulfill()
        }

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        await fulfillment(of: [released], timeout: 2)
        let replacement = snapshotImage(.green)
        source.image = replacement
        XCTAssertTrue(store.originalImage(of: image) === replacement, "エディタの要素は、消えたキャッシュを取得し直す")

        writer.authorize()
        await fulfillment(of: [completed], timeout: 5)
        try assertCenter(of: XCTUnwrap(writer.savedImage), isGreen: false, "受付で固定した赤で保存する")
    }

    // MARK: - 元画像を取得できない画像要素

    // 受付では編集元から1回取得し、nil を固定する。保存用の複製はソースを持たないため、
    // 選定・加工・描き直しで画像を求めるたびに、複製の取得先へ取得し直す（取得できないまま）。

    /// 単独保存で、ただ1つの画像の元画像を取得できなければ、選定に失敗して書き込まない。
    @MainActor
    func test_unresolvedOriginal_failsIndividualSave() async throws {
        let broken = UnresolvedSourceResolver()
        let project = LogoProject(canvasSize: CGSize(width: 32, height: 24))
        project.addElement(makeImage(resolver: broken, frame: CGRect(x: 0, y: 0, width: 32, height: 24), role: .base))
        let writer = SnapshotWriter()

        let result = try await save(project, composite: false, writer: writer)

        guard case .failure(let failure) = result else { return XCTFail("失敗するべき") }
        XCTAssertEqual(failure, .imageSelectionFailed)
        XCTAssertEqual(writer.writeCount, 0)
        XCTAssertEqual(broken.originalCalls, 2, "受付の1回と、選定での取得し直しの1回")
    }

    /// 強制の合成で、ベースの元画像を取得できなければ、合成に失敗して書き込まない。
    @MainActor
    func test_unresolvedBase_failsCompositeSave() async throws {
        let broken = UnresolvedSourceResolver()
        let project = LogoProject(canvasSize: CGSize(width: 32, height: 24))
        project.addElement(makeImage(resolver: broken, frame: CGRect(x: 0, y: 0, width: 32, height: 24), role: .base))
        let writer = SnapshotWriter()

        let result = try await save(project, composite: true, writer: writer)

        guard case .failure(let failure) = result else { return XCTFail("失敗するべき") }
        XCTAssertEqual(failure, .compositeGenerationFailed)
        XCTAssertEqual(writer.writeCount, 0)
        XCTAssertEqual(broken.originalCalls, 2, "受付の1回と、ベースの加工での取得し直しの1回")
    }

    /// 合成で、ベースは正常・重ねる画像だけ元画像を取得できなければ、その画像を描かずに保存は成功する。
    @MainActor
    func test_unresolvedOverlay_isOmittedFromComposite() async throws {
        let broken = UnresolvedSourceResolver()
        let project = LogoProject(canvasSize: CGSize(width: 32, height: 24))
        project.addElement(makeImage(
            resolver: FixedImageResolver(image: snapshotImage(.red)),
            frame: CGRect(x: 0, y: 0, width: 32, height: 24), role: .base
        ))
        project.addElement(makeImage(resolver: broken, frame: CGRect(x: 4, y: 4, width: 8, height: 8), role: .overlay))
        let writer = SnapshotWriter()

        let result = try await save(project, composite: false, writer: writer)

        guard case .success = result else { return XCTFail("成功するべき: \(String(describing: result))") }
        XCTAssertEqual(writer.writeCount, 1)
        let saved = try XCTUnwrap(writer.savedImage)
        let overlayArea = try rgba(of: saved, at: CGPoint(x: 8, y: 8))
        XCTAssertTrue(overlayArea[1] > 200 && overlayArea[0] < 60, "重ねる画像の位置にはベース（緑）が見える: \(overlayArea)")
        XCTAssertEqual(broken.originalCalls, 3, "受付の1回と、合成の加工・描き直しでの取得し直しの2回")
    }

    /// 合成の保存は、保存のタスク（メインスレッドの外）で合成を呼び、画像本体と白系のフレームの塗りを描く。
    /// 合成を呼んだスレッドは、本物の合成を呼ぶ包みの中で記録する（完了は MainActor で呼ばれるため、そこでは分からない）。
    @MainActor
    func test_compositeSave_drawsOffMainThread() async throws {
        let project = LogoProject(canvasSize: CGSize(width: 120, height: 120))
        let gray = solidImage(UIColor(red: 128 / 255, green: 128 / 255, blue: 128 / 255, alpha: 1), CGSize(width: 120, height: 120))
        let blue = solidImage(.blue, CGSize(width: 100, height: 100))
        project.addElement(makeImage(
            resolver: FixedImageResolver(image: gray), frame: CGRect(x: 0, y: 0, width: 120, height: 120), role: .base,
            output: gray
        ))
        let overlay = makeImage(
            resolver: FixedImageResolver(image: blue), frame: CGRect(x: 10, y: 10, width: 100, height: 100), role: .overlay,
            output: blue
        )
        overlay.showFrame = true
        overlay.frameStyle = .softWhite
        overlay.frameColor = .red
        overlay.frameWidth = 10
        project.addElement(overlay)
        let processing = ThreadRecordingProcessing()
        let writer = SnapshotWriter()
        let coordinator = SaveImageCoordinator(processingService: processing, writer: writer)
        let completed = expectation(description: "保存完了")
        let completion: @MainActor @Sendable (PhotoLibrarySaveResult) -> Void = { result in
            if case .failure(let error) = result { XCTFail("\(error)") }
            completed.fulfill()
        }

        coordinator.saveComposite(project: project, renderSessions: ImageRenderSessionStore(), completion: completion)
        writer.authorize()
        await fulfillment(of: [completed], timeout: 5)

        XCTAssertEqual(processing.compositeCallsOnMainThread, [false], "合成は1回だけ、メインスレッドの外で呼ぶ")
        let saved = try XCTUnwrap(writer.savedImage)
        let expectations: [(name: String, point: CGPoint, color: [Int])] = [
            ("画像本体", CGPoint(x: 60, y: 60), [0, 0, 255, 255]),
            // 赤を白へ 72% 寄せた色を、不透明度 0.92 で画像の青の上に重ねた色
            ("白系のフレームの塗り", CGPoint(x: 16, y: 60), [235, 169, 189, 255]),
        ]
        for expected in expectations {
            let actual = try rgba(of: saved, at: expected.point).map(Int.init)
            XCTAssertTrue(zip(actual, expected.color).allSatisfy { abs($0 - $1) <= 10 },
                          "\(expected.name)（期待: \(expected.color)、実際: \(actual)）")
        }
    }

    /// 受付から完了までを待ち、結果を返す。管理役はアプリと同じ実装を明示して渡す。
    @MainActor
    private func save(_ project: LogoProject, composite: Bool, writer: SnapshotWriter) async throws -> PhotoLibrarySaveResult? {
        let coordinator = SaveImageCoordinator(processingService: ImageProcessingService(), writer: writer)
        let box = SaveResultBox()
        let completed = expectation(description: "保存完了")
        let completion: @MainActor @Sendable (PhotoLibrarySaveResult) -> Void = { result in
            box.result = result
            completed.fulfill()
        }
        if composite {
            coordinator.saveComposite(project: project, renderSessions: ImageRenderSessionStore(), completion: completion)
        } else {
            coordinator.save(project: project, renderSessions: ImageRenderSessionStore(), completion: completion)
        }
        writer.authorize()
        await fulfillment(of: [completed], timeout: 5)
        return box.result
    }

    /// 加工は入力によらず決めた画像（既定は緑）を返す描画サービスで、取得先だけを差し替えた画像要素。
    private func makeImage(
        resolver: any ImageSourceResolving, frame: CGRect, role: ImageRole, output: UIImage = snapshotImage(.green)
    ) -> ImageElement {
        let image = ImageElement(
            source: .data(Data([1])), size: nil, sourceResolver: resolver,
            previewService: FixedPreviewService(output: output)
        )
        image.position = frame.origin
        image.size = frame.size
        image.imageRole = role
        image.zIndex = role == .base ? 100 : 110
        return image
    }

    /// 画像の指定位置（上からの座標）の RGBA 成分（0〜255）
    private func rgba(of image: UIImage, at point: CGPoint) throws -> [UInt8] {
        let cgImage = try XCTUnwrap(image.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ))
        let cropped = try XCTUnwrap(cgImage.cropping(to: CGRect(origin: point, size: CGSize(width: 1, height: 1))))
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return pixel
    }

    /// 保存した画像の中央が、緑（管理役が返した画像）か赤（要素自身の画像）かを確かめる。
    private func assertCenter(
        of image: UIImage,
        isGreen: Bool,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let cgImage = try XCTUnwrap(image.cgImage, file: file, line: line)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ), file: file, line: line)
        let center = CGRect(x: cgImage.width / 2, y: cgImage.height / 2, width: 1, height: 1)
        let cropped = try XCTUnwrap(cgImage.cropping(to: center), file: file, line: line)
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let (red, green) = (Int(pixel[0]), Int(pixel[1]))
        if isGreen {
            XCTAssertTrue(green > 200 && red < 60, "\(message)（RGBA: \(pixel)）", file: file, line: line)
        } else {
            XCTAssertTrue(red > 200 && green < 60, "\(message)（RGBA: \(pixel)）", file: file, line: line)
        }
    }

    // MARK: - 背景画像（第26回）

    /// 保存の2つの入口（自動の判定で合成・合成の強制）は、受付の時点の背景画像で合成する。
    /// 受付のあと、権限の許可より前にファイルを更新しても、保存結果は受付の時点の画像になる。
    /// 合成は背景のあとに画像要素を描くため、画像要素は透明にして、背景の画素で確かめる。
    @MainActor
    func test_compositeSave_usesBackgroundAtAcceptance() async throws {
        for composite in [false, true] {
            let entry = composite ? "saveComposite" : "save"
            let file = BackgroundAssetFile()
            defer { file.remove() }
            file.write(snapshotImage(.red))
            // 自動の判定でも合成になるよう、透明な画像要素を2つ置く。
            let project = try makeBackgroundImageProject(fileName: file.name, imageCount: 2)
            let writer = SnapshotWriter()
            let coordinator = SaveImageCoordinator(processingService: ImageProcessingService(), writer: writer)
            let completed = expectation(description: "\(entry)の完了")
            let completion: @MainActor @Sendable (PhotoLibrarySaveResult) -> Void = { result in
                if case .failure(let error) = result { XCTFail("\(entry)：\(error)") }
                completed.fulfill()
            }
            if composite {
                coordinator.saveComposite(project: project, completion: completion)
            } else {
                coordinator.save(project: project, completion: completion)
            }

            file.write(snapshotImage(.blue))
            writer.authorize()
            await fulfillment(of: [completed], timeout: 5)

            let saved = try XCTUnwrap(writer.savedImage, entry)
            try assertRGBA(of: saved, at: CGPoint(x: 20, y: 20), equals: BackgroundPixel.red,
                           "\(entry)：受付の時点の背景画像（赤）で合成する")
        }
    }

    /// 保存の2つの入口は、呼び出しから戻るまでに（権限を待つ前に）、メインスレッドで背景画像を1回だけ取得する。
    /// 合成まで待って数えるだけでは、取得を権限の許可のあとへ遅らせる誤りを見逃すため、戻った直後にも数える。
    /// 個別保存（自動の判定）と権限の拒否でも、受付で取得する（今の挙動）。合成は、注入した取得先の画像（マゼンタ）で描く。
    @MainActor
    func test_saveEntries_loadBackgroundBeforeAuthorization() async throws {
        let cases: [(entry: String, composite: Bool, imageCount: Int, denied: Bool)] = [
            ("save・合成", false, 2, false),
            ("save・個別", false, 1, false),
            ("saveComposite", true, 1, false),
            ("save・権限の拒否", false, 2, true),
            ("saveComposite・権限の拒否", true, 1, true),
        ]
        for testCase in cases {
            let entry = testCase.entry
            let loader = BackgroundImageLoadingSpy(image: snapshotImage(.magenta))
            let project = try makeBackgroundImageProject(fileName: "background_entry", imageCount: testCase.imageCount)
            let writer = SnapshotWriter()
            let coordinator = SaveImageCoordinator(
                processingService: ImageProcessingService(),
                writer: testCase.denied ? DeniedWriter() : writer,
                backgroundImages: loader
            )
            let box = SaveResultBox()
            let completed = expectation(description: "\(entry)の完了")
            let completion: @MainActor @Sendable (PhotoLibrarySaveResult) -> Void = { result in
                box.result = result
                completed.fulfill()
            }
            if testCase.composite {
                coordinator.saveComposite(project: project, renderSessions: ImageRenderSessionStore(), completion: completion)
            } else {
                coordinator.save(project: project, renderSessions: ImageRenderSessionStore(), completion: completion)
            }

            XCTAssertEqual(loader.requestedNames, ["background_entry"], "\(entry)：呼び出しから戻るまでに1回取得する")
            XCTAssertEqual(loader.calledOnMainThread, [true], "\(entry)：メインスレッドで取得する")
            if !testCase.denied {
                writer.authorize()
            }
            await fulfillment(of: [completed], timeout: 5)

            XCTAssertEqual(loader.requestedNames, ["background_entry"], "\(entry)：保存の処理では取り直さない")
            if testCase.denied {
                guard case .failure(.permissionDenied) = box.result else {
                    return XCTFail("\(entry)：権限の拒否で終わる（\(String(describing: box.result))）")
                }
                continue
            }
            guard case .success = box.result else {
                return XCTFail("\(entry)：保存に成功する（\(String(describing: box.result))）")
            }
            if testCase.imageCount == 2 || testCase.composite {
                let saved = try XCTUnwrap(writer.savedImage, entry)
                try assertRGBA(of: saved, at: CGPoint(x: 20, y: 20), equals: BackgroundPixel.magenta,
                               "\(entry)：注入した取得先の画像（マゼンタ）で合成する")
            }
        }
    }

    private func makeProject() -> (LogoProject, ImageElement) {
        let project = LogoProject(canvasSize: CGSize(width: 32, height: 24))
        let image = ImageElementFactory().makeElement(imageData: snapshotImage(.red).pngData()!, importOrder: 1)
        image.size = project.canvasSize
        project.addElement(image)
        return (project, image)
    }
}

/// 完了で受け取った結果。完了は MainActor で呼ばれる。
@MainActor
private final class SaveResultBox {
    var result: PhotoLibrarySaveResult?
}

/// 写真ライブラリの権限が拒否されている書き込み先。権限を求めず、書き込みも呼ばれない。
private struct DeniedWriter: PhotoLibraryWriting {
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus { .denied }
    func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping @Sendable (PHAuthorizationStatus) -> Void) {
        XCTFail("拒否されているときは、権限を求めない")
    }
    func performSave(of image: UIImage, format: SaveImageFormat) async throws {
        XCTFail("拒否されているときは、書き込まない")
    }
}

/// 元画像を取得できない取得先。保存のタスクからも呼ばれるため、取得の回数をロックで守る。
private final class UnresolvedSourceResolver: ImageSourceResolving, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var originalCalls: Int { lock.withLock { count } }

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        lock.withLock { count += 1 }
        return nil
    }

    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? { nil }
}

/// 常に同じ画像を返す取得先。不変の値だけを持つ。
private struct FixedImageResolver: ImageSourceResolving {
    let image: UIImage

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? { image }

    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? { image }
}

/// 返す元画像を途中で差し替えられる取得先。保存のタスクからも呼ばれうるため、ロックで守る。
private final class SwitchableResolver: ImageSourceResolving, @unchecked Sendable {
    private let lock = NSLock()
    private var current: UIImage

    init(image: UIImage) {
        current = image
    }

    var image: UIImage {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? { image }

    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? { image }
}

/// 入力の画像をそのまま返す描画サービス。不変の値だけを持つ。
private final class PassThroughPreview: ImagePreviewing, @unchecked Sendable {
    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        editingImage ?? originalImage
    }

    func instantPreview(baseImage: UIImage?, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        baseImage
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        image
    }

    func applyFiltersAsync(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) async -> UIImage? {
        image
    }

    func resetCache() {}
}

/// メモリ警告で解放されたことを知らせる、エディタの既定の描画サービス。画像は作らない。
private final class ReleaseSignalingPreview: ImagePreviewing, @unchecked Sendable {
    private let onRelease: @Sendable () -> Void

    init(onRelease: @escaping @Sendable () -> Void) {
        self.onRelease = onRelease
    }

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? { nil }

    func instantPreview(baseImage: UIImage?, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        nil
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        nil
    }

    func applyFiltersAsync(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) async -> UIImage? {
        nil
    }

    func resetCache() {
        onRelease()
    }
}

/// 権限応答だけを保留し、非同期書き込みの結果をロックで保護する。
private final class SnapshotWriter: PhotoLibraryWriting, @unchecked Sendable {
    private let lock = NSLock()
    private var authorization: (@Sendable (PHAuthorizationStatus) -> Void)?
    private var image: UIImage?
    private var count = 0

    var savedImage: UIImage? { lock.withLock { image } }
    var writeCount: Int { lock.withLock { count } }
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus { .notDetermined }
    func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping @Sendable (PHAuthorizationStatus) -> Void) {
        lock.withLock { authorization = handler }
    }
    func authorize() {
        let handler = lock.withLock {
            let handler = authorization
            authorization = nil
            return handler
        }
        XCTAssertNotNil(handler)
        handler?(.authorized)
    }
    func performSave(of image: UIImage, format: SaveImageFormat) async throws {
        lock.withLock {
            self.image = image
            count += 1
        }
    }
}

/// 本物の加工と合成を呼び、合成を呼んだときのスレッドを記録する。保存のタスクから呼ばれるため、記録をロックで守る。
private final class ThreadRecordingProcessing: ImageProcessing, @unchecked Sendable {
    private let lock = NSLock()
    private let processing = ImageProcessingService()
    private var mainThreadFlags: [Bool] = []

    /// 合成を呼ぶたびに、メインスレッドだったかを順に記録した値
    var compositeCallsOnMainThread: [Bool] { lock.withLock { mainThreadFlags } }

    func applyFilters(to imageElement: ImageElement, images: any SaveImageReading) -> UIImage? {
        processing.applyFilters(to: imageElement, images: images)
    }

    func makeCompositeImage(baseElement: ImageElement, project: LogoProject, images: any SaveImageReading) -> UIImage? {
        let isMainThread = Thread.isMainThread
        lock.withLock { mainThreadFlags.append(isMainThread) }
        return processing.makeCompositeImage(baseElement: baseElement, project: project, images: images)
    }
}

/// 単色の画像（倍率1）
private func solidImage(_ color: UIColor, _ size: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}

/// 待機は detached 保存タスク上だけで行い、MainActor を止めない。
private final class PausedSnapshotProcessing: ImageProcessing, @unchecked Sendable {
    private let gate = DispatchSemaphore(value: 0)
    private let started: XCTestExpectation
    init(started: XCTestExpectation) { self.started = started }
    func resume() { gate.signal() }
    func applyFilters(to imageElement: ImageElement, images: any SaveImageReading) -> UIImage? {
        XCTFail("合成モードを維持するべき")
        return nil
    }
    func makeCompositeImage(baseElement: ImageElement, project: LogoProject, images: any SaveImageReading) -> UIImage? {
        started.fulfill()
        guard gate.wait(timeout: .now() + 5) == .success else {
            XCTFail("加工再開が届かない")
            return nil
        }
        // 受け取った保存の範囲をそのまま渡し、本番と同じ画像で合成する。
        return ImageProcessingService().makeCompositeImage(baseElement: baseElement, project: project, images: images)
    }
}

private actor SaveBoundaryAIProcessor: BackgroundRemovalProcessing {
    let started: XCTestExpectation
    private var continuation: CheckedContinuation<UIImage, Never>?
    init(started: XCTestExpectation) { self.started = started }
    func removeBackground(from image: UIImage) async throws -> UIImage {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started.fulfill()
        }
    }
    func generateMask(from image: UIImage) async throws -> UIImage { image }
    func finish(_ image: UIImage) {
        continuation?.resume(returning: image)
        continuation = nil
    }
}
