// インポートの生成と配置がプロジェクトを変更せず、既存画像数と入力識別子を使うことを検証する。

import UIKit
import XCTest
@testable import GLogo

final class ImageImportCoordinatorTests: XCTestCase {
    func test_import_countsImagesWithoutMutatingProject() throws {
        let image = snapshotImage(.blue)
        let project = LogoProject()
        project.addElement(TextElement(text: "Text"))
        project.addElement(ImageElement(imageData: try XCTUnwrap(image.pngData())))
        let originalIDs = project.elements.map(\.id)
        let result = try XCTUnwrap(ImageImportCoordinator().importImage(
            source: .uiImage(image), project: project, viewportSize: CGSize(width: 400, height: 800),
            assetIdentifier: "asset", canvasSize: CGSize(width: 600, height: 400)))
        XCTAssertEqual(project.elements.map(\.id), originalIDs)
        XCTAssertEqual(result.element.originalImportOrder, 2)
        XCTAssertEqual(result.element.imageRole, .overlay)
        XCTAssertEqual(result.element.zIndex, ElementPriority.image.rawValue + 10)
        XCTAssertEqual(result.assetIdentifier, "asset")
        XCTAssertEqual(result.element.originalImageIdentifier, "asset")
        XCTAssertEqual(result.element.position.x + result.element.size.width / 2, 200, accuracy: 0.001)
        XCTAssertEqual(result.element.position.y + result.element.size.height / 2, 200, accuracy: 0.001)
    }

    func test_import_unencodableImageReturnsNil() {
        let project = LogoProject()
        let result = ImageImportCoordinator().importImage(
            source: .uiImage(UIImage()), project: project, viewportSize: CGSize(width: 300, height: 600),
            assetIdentifier: nil)
        XCTAssertNil(result)
        XCTAssertTrue(project.elements.isEmpty)
    }
}
