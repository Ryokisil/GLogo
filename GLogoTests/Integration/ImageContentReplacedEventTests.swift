// 画像の差し替え（手動背景除去・高画質化の結果適用）を Undo／Redo したとき、
// 画像ソース・配置サイズ・編集値30項目のうち何が戻るかを固定する。

import UIKit
import XCTest
@testable import GLogo

final class ImageContentReplacedEventTests: XCTestCase {
    @MainActor
    func test_replaceUndo_keepsFrameAndBlurReset() throws {
        for path in ReplacementPath.allCases {
            let project = LogoProject(name: "replace-undo", canvasSize: CGSize(width: 1080, height: 1920))
            let viewModel = EditorViewModel(project: project)
            let oldData = try XCTUnwrap(makeImage(color: .white, size: CGSize(width: 64, height: 64)).pngData())
            let element = ImageElementFactory().makeElement(imageData: oldData, importOrder: 0)
            viewModel.addElement(element)
            let oldIdentifier = element.originalImageIdentifier
            let initial = ImageEditStateRecord(element)
            ImageEditStateRecord.applyDistinctValues(to: element)
            let edited = ImageEditStateRecord(element)
            element.size = CGSize(width: 77, height: 33)

            path.apply(makeImage(color: .black, size: CGSize(width: 32, height: 16)), to: element, in: viewModel)
            XCTAssertNotEqual(element.imageData, oldData, "\(path)")
            XCTAssertNotEqual(element.originalImageIdentifier, oldIdentifier, "\(path)")
            XCTAssertEqual(element.size, CGSize(width: 77, height: 33), "差し替えても配置サイズを保つ: \(path)")
            XCTAssertEqual(ImageEditStateRecord(element), initial, "差し替えで編集値を初期状態へ戻す: \(path)")

            viewModel.undo()
            XCTAssertEqual(element.imageData, oldData, "\(path)")
            XCTAssertEqual(element.originalImageIdentifier, oldIdentifier, "\(path)")
            XCTAssertEqual(element.size, CGSize(width: 77, height: 33), "\(path)")
            // 現状の差し替えイベントはフレームと背景ぼかしを記録しておらず、差し替え時に戻した初期値のまま残る。
            var expected = edited
            expected.frame = initial.frame
            expected.backgroundBlurRadius = initial.backgroundBlurRadius
            expected.backgroundBlurMaskData = initial.backgroundBlurMaskData
            XCTAssertEqual(ImageEditStateRecord(element), expected, "\(path)")

            viewModel.redo()
            XCTAssertEqual(ImageEditStateRecord(element), initial, "\(path)")
        }
    }

    /// 差し替えイベントを作る2つの入口。
    private enum ReplacementPath: CaseIterable {
        case manualBackgroundRemoval
        case upscale

        @MainActor
        func apply(_ image: UIImage, to element: ImageElement, in viewModel: EditorViewModel) {
            switch self {
            case .manualBackgroundRemoval:
                viewModel.imageEdits.applyManualBackgroundRemovalResult(image, to: element)
            case .upscale:
                viewModel.imageEdits.applyUpscaledImageResult(image, to: element)
            }
        }
    }

    private func makeImage(color: UIColor, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
