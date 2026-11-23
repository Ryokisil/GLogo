// 保存入力の値・参照の分離と、描画資源を再圧縮しない契約を検証する。

import UIKit
import XCTest
@testable import GLogo

final class SaveProjectSnapshotTests: XCTestCase {
    @MainActor
    func test_snapshot_preservesImageAppearance() throws {
        // 編集元の観察と受付には同じ管理役を使う。描画サービスは品質ごとに別の画像を返し、複製の状態を見分ける。
        let store = ImageRenderSessionStore()
        let preview = QualityPreviewService()
        let image = ImageElementFactory(previewService: preview)
            .makeElement(imageData: snapshotImage(.red).pngData()!, importOrder: 7)
        image.imageRole = .base
        image.zIndex = 155
        image.name = "Base"
        image.position = CGPoint(x: 12, y: 18)
        image.rotation = 0.3
        image.opacity = 0.7
        image.isVisible = false
        image.isLocked = true
        for descriptor in ImageAdjustmentDescriptor.all.values {
            image[keyPath: descriptor.keyPath] = 0.37
        }
        image.tintColor = .green
        image.backgroundBlurMaskData = Data([1, 2, 3])
        image.toneCurveData.rgbPoints[1].output = 0.7
        image.appliedFilterRecipe = FilterCatalog.vintageWarm.recipe
        image.appliedFilterPresetId = FilterCatalog.vintageWarm.id
        image.showFrame = true
        image.frameColor = .blue
        image.frameStyle = .double
        image.roundedCorners = true
        image.metadata = ImageMetadata(title: "保存用の複製に持ち越さない")
        let original = try XCTUnwrap(store.originalImage(of: image))
        let editorCache = snapshotImage(.black)
        store.storeRenderedImage(editorCache, of: image)
        store.startEditing(image)
        let project = LogoProject()
        project.addElement(image)

        let snapshot = SaveProjectSnapshot(project: project, renderSessions: store)
        let copy = try XCTUnwrap(snapshot.project.elements.first as? ImageElement)
        XCTAssertFalse(copy === image)
        XCTAssertEqual(copy.id, image.id)
        XCTAssertEqual(copy.name, "Base")
        XCTAssertEqual(copy.zIndex, 155)
        XCTAssertEqual(copy.originalImportOrder, 7)
        XCTAssertEqual(copy.imageRole, .base)
        XCTAssertEqual(copy.position, image.position)
        XCTAssertEqual(copy.rotation, image.rotation)
        XCTAssertEqual(copy.opacity, image.opacity)
        XCTAssertFalse(copy.isVisible)
        XCTAssertTrue(copy.isLocked)
        for descriptor in ImageAdjustmentDescriptor.all.values {
            XCTAssertEqual(copy[keyPath: descriptor.keyPath], 0.37, "\(descriptor.key)")
            image[keyPath: descriptor.keyPath] = 0.9
            XCTAssertEqual(copy[keyPath: descriptor.keyPath], 0.37)
        }
        XCTAssertEqual(copy.tintColor, .green)
        XCTAssertEqual(copy.backgroundBlurMaskData, Data([1, 2, 3]))
        XCTAssertEqual(copy.toneCurveData.rgbPoints[1].output, 0.7)
        XCTAssertEqual(copy.appliedFilterRecipe, FilterCatalog.vintageWarm.recipe)
        XCTAssertEqual(copy.appliedFilterPresetId, FilterCatalog.vintageWarm.id)
        XCTAssertTrue(copy.showFrame)
        XCTAssertEqual(copy.frameColor, .blue)
        XCTAssertEqual(copy.frameStyle, .double)
        XCTAssertTrue(copy.roundedCorners)
        XCTAssertNil(copy.metadata, "メタデータは保存の合成で使わないため、保存用の複製に持ち越さない")
        XCTAssertTrue(snapshot.originalImage(of: copy) === original, "画像バッファを再圧縮・複製しない")
        // 描画用の画像は、編集元の表示キャッシュ（黒）でも、編集中の即時プレビューでもなく、新しくフル品質で加工したもの。
        let drawn = snapshot.drawingImage(of: copy)
        XCTAssertFalse(drawn === editorCache, "編集中の表示キャッシュは保存に持ち越さない")
        XCTAssertTrue(drawn === preview.fullQuality, "編集中フラグも持ち越さない")
    }

    @MainActor
    func test_snapshot_isolatesTextShapeAndBackground() throws {
        let project = LogoProject(name: "Before", canvasSize: CGSize(width: 100, height: 80))
        project.backgroundSettings = BackgroundSettings(startColor: .red, endColor: .blue)
        let text = TextElement(text: "Before", fontSize: 24)
        let glow = GlowEffect(color: .green, radius: 9)
        text.effects = [glow]
        text.zIndex = 420
        text.lineSpacing = 5
        text.letterSpacing = 3
        let shape = ShapeElement(shapeType: .polygon)
        shape.customPoints = [CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)]
        shape.gradientAngle = 45
        shape.zIndex = 250
        project.elements = [text, shape]
        let copy = SaveProjectSnapshot(project: project, renderSessions: ImageRenderSessionStore()).project
        let copiedText = try XCTUnwrap(copy.elements[0] as? TextElement)
        let copiedGlow = try XCTUnwrap(copiedText.effects.first as? GlowEffect)
        let copiedShape = try XCTUnwrap(copy.elements[1] as? ShapeElement)

        text.text = "After"
        glow.radius = 30
        shape.customPoints.removeAll()
        shape.gradientAngle = 90
        project.backgroundSettings.gradientStartColor = .black
        project.canvasSize = .zero
        project.elements.removeAll()

        XCTAssertEqual(copy.canvasSize, CGSize(width: 100, height: 80))
        XCTAssertEqual(copy.backgroundSettings.gradientStartColor, .red)
        XCTAssertEqual(copy.elements.map(\.id), [text.id, shape.id])
        XCTAssertEqual(copy.elements.map(\.zIndex), [420, 250])
        XCTAssertEqual(copiedText.text, "Before")
        XCTAssertEqual(copiedText.lineSpacing, 5)
        XCTAssertEqual(copiedText.letterSpacing, 3)
        XCTAssertFalse(copiedGlow === glow)
        XCTAssertEqual(copiedGlow.radius, 9)
        XCTAssertEqual(copiedShape.customPoints.count, 2)
        XCTAssertEqual(copiedShape.gradientAngle, 45)
    }

    @MainActor
    func test_snapshot_pinsFileImageAfterDeletion() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try XCTUnwrap(snapshotImage(.red).pngData()).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        // 保存データ由来のファイルパス参照を持つ要素
        let image = ImageElement(
            source: .path(url.path), size: nil,
            sourceResolver: ImageSourceResolver(), previewService: ImagePreviewService.shared
        )
        let project = LogoProject()
        project.addElement(image)
        let store = ImageRenderSessionStore()
        let snapshot = SaveProjectSnapshot(project: project, renderSessions: store)
        let copy = try XCTUnwrap(snapshot.project.elements.first as? ImageElement)
        let frozen = try XCTUnwrap(snapshot.originalImage(of: copy))
        try FileManager.default.removeItem(at: url)
        image.replaceImageSource(with: snapshotImage(.blue).pngData()!, resetAdjustments: true)
        // 編集元の失効は、差し替えのイベントの範囲で履歴が管理役に求める。
        store.invalidateForSourceChange(of: image)
        XCTAssertTrue(snapshot.originalImage(of: copy) === frozen)
        XCTAssertNotEqual(snapshot.originalImage(of: copy)?.pngData(), store.originalImage(of: image)?.pngData())
        XCTAssertNotNil(ImageProcessingService().applyFilters(to: copy, images: snapshot))
    }

    @MainActor
    func test_snapshot_preservesOrientationAndColorSpace() throws {
        let base = snapshotImage(.red)
        let oriented = UIImage(cgImage: try XCTUnwrap(base.cgImage), scale: 2, orientation: .leftMirrored)
        let image = ImageElementFactory(sourceResolver: SnapshotSourceResolver(image: oriented))
            .makeElement(imageData: Data(), importOrder: 1)
        let store = ImageRenderSessionStore()
        let original = try XCTUnwrap(store.originalImage(of: image))
        let project = LogoProject()
        project.addElement(image)
        let snapshot = SaveProjectSnapshot(project: project, renderSessions: store)
        let copy = try XCTUnwrap(snapshot.project.elements.first as? ImageElement)
        let pinned = try XCTUnwrap(snapshot.originalImage(of: copy))
        XCTAssertTrue(pinned === original)
        XCTAssertEqual(pinned.cgImage?.bitsPerComponent, original.cgImage?.bitsPerComponent)
        XCTAssertEqual(pinned.cgImage?.colorSpace?.name, original.cgImage?.colorSpace?.name)
        XCTAssertEqual(pinned.imageOrientation, original.imageOrientation)
        XCTAssertEqual(pinned.scale, original.scale)
        XCTAssertNotEqual(image.copy().id, image.id, "UI 用複製は引き続き別 ID")
    }

    @MainActor
    func test_snapshot_pinsBackgroundAsset() throws {
        let name = "snapshot_test_\(UUID().uuidString)"
        let assets = AssetManager.shared
        XCTAssertTrue(assets.saveImage(snapshotImage(.red), name: name, type: .background, alsoSaveProxy: false))
        defer { _ = assets.deleteImage(named: name, type: .background) }
        let project = LogoProject()
        project.backgroundSettings.type = .image
        project.backgroundSettings.imageFileName = name
        let snapshot = SaveProjectSnapshot(project: project, renderSessions: ImageRenderSessionStore())
        let before = drawBackground(snapshot.project.backgroundSettings)
        // 等しさだけでは「両方とも描かない」誤りを通すため、描いた色も確かめる（第26回）。
        try assertRGBA(of: before, at: CGPoint(x: 4, y: 4), equals: BackgroundPixel.red, "受付の時点の画像（赤）で描く")
        XCTAssertTrue(assets.saveImage(snapshotImage(.blue), name: name, type: .background, alsoSaveProxy: false))
        XCTAssertEqual(drawBackground(snapshot.project.backgroundSettings).pngData(), before.pngData())
        XCTAssertNotEqual(drawBackground(project.backgroundSettings).pngData(), before.pngData())
        try assertRGBA(of: drawBackground(project.backgroundSettings), at: CGPoint(x: 4, y: 4),
                       equals: BackgroundPixel.blue, "編集側は、更新したファイル（青）で描く")
        // ランタイム資源は永続化しないため、元の設定と JSON の契約は同一。
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(snapshot.project.backgroundSettings), try encoder.encode(project.backgroundSettings))
    }

    // MARK: - 保存の範囲（第18回）

    /// 受付では、画像要素ごとに要素の順で1回ずつ、エディタの管理役から元画像だけを受け取って固定する。
    @MainActor
    func test_snapshot_readsOriginalsThroughStore() throws {
        let first = ImageElementFactory().makeElement(imageData: snapshotImage(.red).pngData()!)
        let second = ImageElementFactory().makeElement(imageData: snapshotImage(.blue).pngData()!)
        let project = LogoProject()
        project.elements = [first, TextElement(text: "A", fontSize: 12), second]
        // 要素自身の画像（赤・青）と別の画像を返し、固定した画像の出どころを見分ける。
        let marker = snapshotImage(.green)
        let store = RenderSessionSpy(original: marker)

        let snapshot = SaveProjectSnapshot(project: project, renderSessions: store)

        XCTAssertEqual(store.requests, [.init(.originalImage, first), .init(.originalImage, second)])
        let copies = snapshot.project.elements.compactMap { $0 as? ImageElement }
        XCTAssertEqual(copies.map(\.id), [first.id, second.id])
        for copy in copies {
            XCTAssertTrue(snapshot.originalImage(of: copy) === marker, "管理役から受け取った元画像を固定する")
        }
        XCTAssertEqual(store.requests.count, 2, "固定した元画像を返すときは、管理役に問い合わせない")
    }

    /// 範囲は自分の複製にだけ画像を返す。編集元の要素と、同じ ID を持つ別の保存要求の複製には返さない。
    @MainActor
    func test_snapshot_servesOnlyOwnCopies() throws {
        let image = ImageElementFactory().makeElement(imageData: snapshotImage(.red).pngData()!)
        let project = LogoProject()
        project.addElement(image)
        let store = ImageRenderSessionStore()
        let first = SaveProjectSnapshot(project: project, renderSessions: store)
        let second = SaveProjectSnapshot(project: project, renderSessions: store)
        let firstCopy = try XCTUnwrap(first.project.elements.first as? ImageElement)
        let secondCopy = try XCTUnwrap(second.project.elements.first as? ImageElement)
        XCTAssertEqual(secondCopy.id, firstCopy.id)
        XCTAssertEqual(firstCopy.id, image.id)

        XCTAssertNotNil(first.originalImage(of: firstCopy))
        XCTAssertNotNil(first.filteredImage(of: firstCopy))
        XCTAssertNotNil(first.drawingImage(of: firstCopy))
        for (outsider, label) in [(image, "編集元の要素"), (secondCopy, "別の保存要求の複製")] {
            XCTAssertNil(first.originalImage(of: outsider), label)
            XCTAssertNil(first.filteredImage(of: outsider), label)
            XCTAssertNil(first.drawingImage(of: outsider), label)
        }
    }

    /// 同じ内容を続けて受け付けた2件は、同じ元画像を参照してよい（バッファは複製しない）が、
    /// セッションとキャッシュの状態は独立し、片方のキャッシュへの書き込みがもう片方と編集元に届かない。
    /// 表示画像のキャッシュの有無は、フル品質の加工の回数で見分ける（範囲には、キャッシュを見るだけの口がないため）。
    @MainActor
    func test_snapshots_keepIndependentCaches() throws {
        let source = DataOnlySourceResolver(image: snapshotImage(.red))
        let preview = QualityPreviewService()
        let image = ImageElement(source: .data(Data()), size: nil, sourceResolver: source, previewService: preview)
        let project = LogoProject()
        project.addElement(image)
        let store = ImageRenderSessionStore()
        let first = SaveProjectSnapshot(project: project, renderSessions: store)
        let second = SaveProjectSnapshot(project: project, renderSessions: store)
        let firstCopy = try XCTUnwrap(first.project.elements.first as? ImageElement)
        let secondCopy = try XCTUnwrap(second.project.elements.first as? ImageElement)
        XCTAssertEqual(source.originalCalls, 1, "2件目の受付は、編集元のキャッシュから元画像を受け取る")
        XCTAssertTrue(first.originalImage(of: firstCopy) === second.originalImage(of: secondCopy))

        // 片方で作った描画用の画像のキャッシュは、もう片方にも編集元にも書かない。
        XCTAssertNotNil(first.drawingImage(of: firstCopy))
        XCTAssertEqual(preview.fullCalls, 1)
        XCTAssertNotNil(first.drawingImage(of: firstCopy))
        XCTAssertEqual(preview.fullCalls, 1, "書いた側は、自分のキャッシュを使う")
        XCTAssertNotNil(second.drawingImage(of: secondCopy))
        XCTAssertEqual(preview.fullCalls, 2, "もう片方には届いていないため、自分で加工する")
        XCTAssertNil(store.cachedRenderedImage(of: image), "編集元にも届かない")
        XCTAssertTrue(store.originalImage(of: image) === source.image, "編集元の元画像のキャッシュも、そのまま")
        XCTAssertEqual(source.originalCalls, 1)
    }

    /// 受付では、エディタでまだ取得していない元画像だけを取得してよい（取得したものはエディタのキャッシュに残る）。
    /// 受付のあとの保存処理（元画像・加工した画像・描画用の画像の受け取り）は、エディタ側の取得・表示画像のキャッシュ・
    /// 編集中の状態を変えない。保存用の複製は、エディタの管理役の表に登録しない（表の確認は、回収も生成もしない口で行う）。
    /// エディタで未取得・取得済み・編集中の3つの状態で確かめる。
    @MainActor
    func test_saveProcessing_leavesEditorStateUnchanged() throws {
        for state in ["未取得", "取得済み", "編集中"] {
            let source = DataOnlySourceResolver(image: snapshotImage(.red))
            let preview = QualityPreviewService()
            let image = ImageElement(source: .data(Data([1])), size: nil, sourceResolver: source, previewService: preview)
            let project = LogoProject()
            project.addElement(image)
            let store = ImageRenderSessionStore()
            var rendered: UIImage?
            if state != "未取得" {
                XCTAssertNotNil(store.originalImage(of: image))
                rendered = try XCTUnwrap(store.displayImage(of: image))
            }
            if state == "編集中" {
                store.startEditing(image)
                rendered = nil
            }
            let callsBefore = source.originalCalls
            XCTAssertEqual(store.registeredSessionCount, state == "未取得" ? 0 : 1, state)

            let snapshot = SaveProjectSnapshot(project: project, renderSessions: store)
            XCTAssertEqual(source.originalCalls, callsBefore + (state == "未取得" ? 1 : 0), "\(state)：受付で取得するのは未取得のときだけ")
            XCTAssertEqual(store.registeredSessionCount, 1, "\(state)：受付で登録してよいのは編集元の要素の分だけ")
            let callsAfterAcceptance = source.originalCalls

            let copy = try XCTUnwrap(snapshot.project.elements.first as? ImageElement)
            XCTAssertTrue(snapshot.originalImage(of: copy) === source.image, state)
            XCTAssertNotNil(snapshot.filteredImage(of: copy), state)
            XCTAssertNotNil(snapshot.drawingImage(of: copy), state)

            XCTAssertEqual(source.originalCalls, callsAfterAcceptance, "\(state)：保存処理は元画像を取得し直さない")
            XCTAssertEqual(store.registeredSessionCount, 1, "\(state)：保存用の複製は、エディタの表に登録しない")
            XCTAssertFalse(store.hasSession(for: copy), state)
            XCTAssertTrue(store.cachedRenderedImage(of: image) === rendered, "\(state)：エディタの表示画像のキャッシュは変わらない")
            XCTAssertTrue(store.originalImage(of: image) === source.image, state)
            XCTAssertEqual(source.originalCalls, callsAfterAcceptance, "\(state)：エディタの元画像は受付のときのキャッシュのまま")
            if state == "編集中" {
                XCTAssertTrue(store.drawingImage(of: image) === preview.instant, "編集中の状態は変わらない")
            }
        }
    }

    // MARK: - 背景画像の固定（第26回）
    // 合成の出力で確かめる。合成は背景のあとに画像要素を描くため、画像要素を透明にし、背景の画素がそのまま出るようにする。

    /// 受付のあと、最初の合成より前にファイルを更新しても、受付の時点の画像で合成する（取得漏れ・取得の遅れ・取り直しを見分ける）。
    @MainActor
    func test_snapshot_compositesBackgroundAtAcceptance() throws {
        let file = BackgroundAssetFile()
        defer { file.remove() }
        file.write(snapshotImage(.red))
        let project = try makeBackgroundImageProject(fileName: file.name)
        let snapshot = SaveProjectSnapshot(project: project, renderSessions: ImageRenderSessionStore())

        file.write(snapshotImage(.blue))

        try assertRGBA(of: try compositeBackground(of: snapshot), at: CGPoint(x: 20, y: 20),
                       equals: BackgroundPixel.red, "受付の時点の画像（赤）で合成する")
    }

    /// 保存1件ごとに、その受付の時点の画像を固定する。A を受付 → 更新 → B を受付 → B、A の順で合成しても取り違えない。
    @MainActor
    func test_snapshots_pinOwnBackground() throws {
        let file = BackgroundAssetFile()
        defer { file.remove() }
        file.write(snapshotImage(.red))
        let project = try makeBackgroundImageProject(fileName: file.name)
        let first = SaveProjectSnapshot(project: project, renderSessions: ImageRenderSessionStore())
        file.write(snapshotImage(.blue))
        let second = SaveProjectSnapshot(project: project, renderSessions: ImageRenderSessionStore())

        try assertRGBA(of: try compositeBackground(of: second), at: CGPoint(x: 20, y: 20),
                       equals: BackgroundPixel.blue, "B は B の受付の時点の画像（青）")
        try assertRGBA(of: try compositeBackground(of: first), at: CGPoint(x: 20, y: 20),
                       equals: BackgroundPixel.red, "A は A の受付の時点の画像（赤）。あとの受付の画像に替わらない")
    }

    /// 受付のときに取得できなければ、背景画像なしで固定する。あとでファイルができても、その保存では取り直さない。
    @MainActor
    func test_snapshot_keepsMissingBackground() throws {
        let file = BackgroundAssetFile()
        defer { file.remove() }
        let project = try makeBackgroundImageProject(fileName: file.name)
        let missing = SaveProjectSnapshot(project: project, renderSessions: ImageRenderSessionStore())

        file.write(snapshotImage(.red))

        try assertRGBA(of: try compositeBackground(of: missing), at: CGPoint(x: 20, y: 20),
                       equals: BackgroundPixel.clear, "受付のときになかった背景は描かない")
        // ファイルは読める状態になっている（あとの受付では描く）。
        let later = SaveProjectSnapshot(project: project, renderSessions: ImageRenderSessionStore())
        try assertRGBA(of: try compositeBackground(of: later), at: CGPoint(x: 20, y: 20),
                       equals: BackgroundPixel.red, "あとの受付では、できたファイル（赤）で描く")
    }

    /// 今の描き方（CGContext.draw）を固定する。背景の不透明度がかかり、画像は上下が反転して描かれる。
    /// 上半分が赤・下半分が青の画像を、不透明度 0.5 で描く。
    @MainActor
    func test_composite_keepsBackgroundDrawing() throws {
        let file = BackgroundAssetFile()
        defer { file.remove() }
        file.write(twoToneImage(top: .red, bottom: .blue))
        let project = try makeBackgroundImageProject(fileName: file.name, opacity: 0.5)
        let snapshot = SaveProjectSnapshot(project: project, renderSessions: ImageRenderSessionStore())

        let output = try compositeBackground(of: snapshot)

        try assertRGBA(of: output, at: CGPoint(x: 20, y: 5), equals: BackgroundPixel.halfBlue,
                       "出力の上側には、画像の下半分（青）が不透明度 0.5 で出る")
        try assertRGBA(of: output, at: CGPoint(x: 20, y: 35), equals: BackgroundPixel.halfRed,
                       "出力の下側には、画像の上半分（赤）が不透明度 0.5 で出る")
    }

    /// 保存の範囲の内容で合成する（ベースは範囲の1つ目の要素）。
    @MainActor
    private func compositeBackground(of snapshot: SaveProjectSnapshot) throws -> UIImage {
        let base = try XCTUnwrap(snapshot.project.elements.first as? ImageElement)
        return try XCTUnwrap(
            ImageProcessingService().makeCompositeImage(baseElement: base, project: snapshot.project, images: snapshot)
        )
    }

    private func drawBackground(_ background: BackgroundSettings) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            background.draw(in: context.cgContext, rect: CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }
}

/// UIImage の向きや scale をエンコードで失わず、そのまま保存入力へ渡すための代替解決器。
private struct SnapshotSourceResolver: ImageSourceResolving {
    let image: UIImage
    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? { image }
    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? { image }
}

/// 画像データを持つ要素にだけ画像を返し、元画像の取得の回数を数える取得先。
/// ソースを持たない保存用の複製には nil を返すため、複製が固定した元画像を失ったことを見分けられる。
/// テストのスレッドから同期にだけ呼ばれる前提で、回数をロックなしで持つ。
private final class DataOnlySourceResolver: ImageSourceResolving, @unchecked Sendable {
    let image: UIImage
    private(set) var originalCalls = 0

    init(image: UIImage) {
        self.image = image
    }

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        originalCalls += 1
        return imageData == nil ? nil : image
    }

    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? { nil }
}

/// 品質ごとに別の画像を返し、フル品質の加工の回数を数える描画サービス。テストのスレッドから同期にだけ呼ばれる。
private final class QualityPreviewService: ImagePreviewing, @unchecked Sendable {
    let fullQuality = snapshotImage(.green)
    let instant = snapshotImage(.magenta)
    private(set) var fullCalls = 0

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        editingImage ?? originalImage
    }

    func instantPreview(baseImage: UIImage?, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        instant
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        if quality == .full { fullCalls += 1 }
        return fullQuality
    }

    func applyFiltersAsync(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) async -> UIImage? {
        fullQuality
    }

    func resetCache() {}
}

/// 保存テスト用の小さな単色画像。
func snapshotImage(_ color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: 32, height: 24), format: format).image { context in
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
    }
}
