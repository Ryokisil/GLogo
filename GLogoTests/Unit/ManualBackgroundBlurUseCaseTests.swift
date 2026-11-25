// 手動背景ぼかしのプレビューが、描画の境界へマスクと半径を渡すことを検証する。

import UIKit
import XCTest
@testable import GLogo

final class ManualBackgroundBlurUseCaseTests: XCTestCase {
    func test_previewImage_passesMaskAndRadiusToRenderer() {
        let renderer = BackgroundBlurRendererSpy()
        let original = snapshotImage(.white)
        let mask = snapshotImage(.black)

        let preview = ManualBackgroundBlurUseCase(renderer: renderer)
            .makePreviewImage(originalImage: original, maskImage: mask, blurRadius: 7)

        XCTAssertTrue(preview === renderer.output)
        XCTAssertTrue(renderer.receivedImage === original)
        XCTAssertEqual(renderer.receivedMaskData, mask.pngData())
        XCTAssertEqual(renderer.receivedRadius, 7)
    }
}

private final class BackgroundBlurRendererSpy: BackgroundBlurRendering {
    let output = UIImage()
    var receivedImage: UIImage?
    var receivedMaskData: Data?
    var receivedRadius: CGFloat?

    func applyBackgroundBlur(to image: UIImage, maskData: Data, radius: CGFloat) -> UIImage? {
        receivedImage = image
        receivedMaskData = maskData
        receivedRadius = radius
        return output
    }
}
