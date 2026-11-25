// 画像要素の編集値30項目が、editState で取り出して applyEditState で反映したときに漏れなく往復することを確かめる。

import UIKit
import XCTest
@testable import GLogo

final class ImageEditStateTests: XCTestCase {
    func test_applyEditState_copiesAllValues() throws {
        let source = try makeElement()
        ImageEditStateRecord.applyDistinctValues(to: source)
        let target = try makeElement()
        XCTAssertNotEqual(ImageEditStateRecord(target), ImageEditStateRecord(source))

        target.applyEditState(source.editState)

        // 記録は要素のプロパティを直接読むため、editState・applyEditState の項目漏れを検出できる。
        XCTAssertEqual(ImageEditStateRecord(target), ImageEditStateRecord(source))
        XCTAssertEqual(target.editState, source.editState)
    }

    private func makeElement() throws -> ImageElement {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return ImageElementFactory().makeElement(imageData: try XCTUnwrap(image.pngData()))
    }
}
