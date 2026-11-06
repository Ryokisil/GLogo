// Composition Root が、アプリで使う実装をエディタごと・画面ごとに組み立てることを確かめる。

import UIKit
import XCTest
@testable import GLogo

final class AppCompositionTests: XCTestCase {
    @MainActor
    func test_editorImport_usesSharedPreviewService() throws {
        let editor = AppComposition.makeEditorViewModel()

        editor.addImageElement(imageData: try XCTUnwrap(snapshotImage(.green).pngData()), position: .zero)

        // 要素間で描画キャッシュを共有するため、取り込んだ画像は共有の描画サービスを使う。
        let image = try XCTUnwrap(editor.project.elements.compactMap { $0 as? ImageElement }.last)
        XCTAssertTrue(image.previewService === ImagePreviewService.shared)
    }

    @MainActor
    func test_screenFactories_createPerCall() {
        let dependencies = AppComposition.makeEditorDependencies()

        let first = dependencies.makeImageSourceResolver() as AnyObject
        let second = dependencies.makeImageSourceResolver() as AnyObject

        XCTAssertFalse(first === second, "画面を開くたびに新しく作る")
    }
}
