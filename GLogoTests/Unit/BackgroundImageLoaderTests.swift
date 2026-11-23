// 背景画像の取得の実装（BackgroundImageLoader）が、アセットの背景のディレクトリから読むことを検証する。

import UIKit
import XCTest
@testable import GLogo

final class BackgroundImageLoaderTests: XCTestCase {
    /// 背景のディレクトリから読む。同じ名前の画像要素のアセット（別の色）とは取り違えない。
    func test_load_readsBackgroundAsset() throws {
        let name = "loader_test_\(UUID().uuidString)"
        let assets = AssetManager.shared
        XCTAssertTrue(assets.saveImage(snapshotImage(.red), name: name, type: .background, alsoSaveProxy: false))
        XCTAssertTrue(assets.saveImage(snapshotImage(.blue), name: name, type: .image, alsoSaveProxy: false))
        defer {
            _ = assets.deleteImage(named: name, type: .background)
            _ = assets.deleteImage(named: name, type: .image)
        }

        let image = try XCTUnwrap(BackgroundImageLoader().loadBackgroundImage(named: name))

        try assertRGBA(of: image, at: CGPoint(x: 4, y: 4), equals: BackgroundPixel.red, "背景のアセット（赤）")
    }

    /// 背景のアセットがなければ nil を返す（画像要素のアセットがあっても、それを返さない）。
    func test_load_missingReturnsNil() {
        let name = "loader_test_\(UUID().uuidString)"
        let assets = AssetManager.shared
        XCTAssertTrue(assets.saveImage(snapshotImage(.blue), name: name, type: .image, alsoSaveProxy: false))
        defer { _ = assets.deleteImage(named: name, type: .image) }

        XCTAssertNil(BackgroundImageLoader().loadBackgroundImage(named: name))
    }
}
