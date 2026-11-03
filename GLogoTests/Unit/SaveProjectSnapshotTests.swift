// 保存入力の値・参照の分離と、描画資源を再圧縮しない契約を検証する。

import UIKit
import XCTest
@testable import GLogo

final class SaveProjectSnapshotTests: XCTestCase {
    @MainActor
    func test_snapshot_preservesImageAppearance() throws {
        let image = ImageElement(imageData: snapshotImage(.red).pngData()!, importOrder: 7)
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
        let original = try XCTUnwrap(image.originalImage)
        image.cachedImage = snapshotImage(.black)
        image.startEditing()
        let project = LogoProject()
        project.addElement(image)

        let copy = try XCTUnwrap(SaveProjectSnapshot(project: project).project.elements.first as? ImageElement)
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
        XCTAssertTrue(copy.originalImage === original, "画像バッファを再圧縮・複製しない")
        XCTAssertNil(copy.cachedImage, "編集中の表示キャッシュは保存に持ち越さない")
        let marker = snapshotImage(.white)
        copy.cachedImage = marker
        XCTAssertTrue(copy.image === marker, "編集中フラグも持ち越さない")
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
        let copy = SaveProjectSnapshot(project: project).project
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
        let image = ImageElement(path: url.path)
        let project = LogoProject()
        project.addElement(image)
        let copy = try XCTUnwrap(SaveProjectSnapshot(project: project).project.elements.first as? ImageElement)
        let frozen = try XCTUnwrap(copy.originalImage)
        try FileManager.default.removeItem(at: url)
        image.replaceImageSource(with: snapshotImage(.blue).pngData()!, resetAdjustments: true)
        XCTAssertTrue(copy.originalImage === frozen)
        XCTAssertNotEqual(copy.originalImage?.pngData(), image.originalImage?.pngData())
        XCTAssertNotNil(ImageProcessingService().applyFilters(to: copy))
    }

    @MainActor
    func test_snapshot_preservesOrientationAndColorSpace() throws {
        let base = snapshotImage(.red)
        let oriented = UIImage(cgImage: try XCTUnwrap(base.cgImage), scale: 2, orientation: .leftMirrored)
        let image = ImageElement(imageData: Data(), importOrder: 1,
                                 sourceResolver: SnapshotSourceResolver(image: oriented))
        let original = try XCTUnwrap(image.originalImage)
        let copy = image.renderCopy()
        XCTAssertTrue(copy.originalImage === original)
        XCTAssertEqual(copy.originalImage?.cgImage?.bitsPerComponent, original.cgImage?.bitsPerComponent)
        XCTAssertEqual(copy.originalImage?.cgImage?.colorSpace?.name, original.cgImage?.colorSpace?.name)
        XCTAssertEqual(copy.originalImage?.imageOrientation, original.imageOrientation)
        XCTAssertEqual(copy.originalImage?.scale, original.scale)
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
        let snapshot = SaveProjectSnapshot(project: project)
        let before = drawBackground(snapshot.project.backgroundSettings)
        XCTAssertTrue(assets.saveImage(snapshotImage(.blue), name: name, type: .background, alsoSaveProxy: false))
        XCTAssertEqual(drawBackground(snapshot.project.backgroundSettings).pngData(), before.pngData())
        XCTAssertNotEqual(drawBackground(project.backgroundSettings).pngData(), before.pngData())
        // ランタイム資源は永続化しないため、元の設定と JSON の契約は同一。
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(snapshot.project.backgroundSettings), try encoder.encode(project.backgroundSettings))
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

/// 保存テスト用の小さな単色画像。
func snapshotImage(_ color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: 32, height: 24), format: format).image { context in
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
    }
}
