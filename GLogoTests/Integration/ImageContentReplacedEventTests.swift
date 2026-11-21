// 画像の差し替え（手動背景除去・高画質化の結果適用）を Undo／Redo したとき、画像ソースと編集値30項目が
// 差し替えの前・後の状態へ戻ることと、配置サイズが各操作の直前の値のまま変わらないことを確かめる。

import UIKit
import XCTest
@testable import GLogo

final class ImageContentReplacedEventTests: XCTestCase {
    @MainActor
    func test_replaceUndo_restoresAllEditValues() throws {
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

            // 保つのは、イベントを作った時点ではなく、Undo・Redo それぞれの直前の配置サイズ。
            // 作った時点の値と区別するため、ここでは履歴を通さずに配置サイズを変えておく。
            element.size = CGSize(width: 55, height: 44)
            viewModel.undo()
            XCTAssertEqual(element.imageData, oldData, "\(path)")
            XCTAssertEqual(element.originalImageIdentifier, oldIdentifier, "\(path)")
            XCTAssertEqual(element.size, CGSize(width: 55, height: 44), "Undo の直前の配置サイズを保つ: \(path)")
            // フレームと背景ぼかしも含め、差し替え前の30項目へ戻る。
            XCTAssertEqual(ImageEditStateRecord(element), edited, "\(path)")

            element.size = CGSize(width: 66, height: 22)
            viewModel.redo()
            XCTAssertNotEqual(element.imageData, oldData, "\(path)")
            XCTAssertEqual(element.size, CGSize(width: 66, height: 22), "Redo の直前の配置サイズを保つ: \(path)")
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
