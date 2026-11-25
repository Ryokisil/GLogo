// キャッシュの無効化で不要なUIImageの所有が実際に解放されることを検証する。

import UIKit
import XCTest
@testable import GLogo

final class ImageRenderCacheTests: XCTestCase {
    func test_invalidation_releasesOwnedImages() {
        var cache = ImageRenderCache()
        weak var rendered: UIImage?
        weak var original: UIImage?
        weak var proxy: UIImage?
        weak var preview: UIImage?
        autoreleasepool {
            cache.renderedImage = snapshotImage(.red)
            cache.originalImage = snapshotImage(.blue)
            cache.proxyImage = snapshotImage(.green)
            cache.previewBaseImage = snapshotImage(.orange)
            rendered = cache.renderedImage
            original = cache.originalImage
            proxy = cache.proxyImage
            preview = cache.previewBaseImage
        }
        XCTAssertNotNil(rendered)
        XCTAssertNotNil(original)
        XCTAssertNotNil(proxy)
        XCTAssertNotNil(preview)

        cache.invalidate(.revert)
        XCTAssertNil(rendered)
        XCTAssertNil(original)
        XCTAssertNotNil(proxy)
        XCTAssertNotNil(preview)

        cache.invalidate(.all)
        XCTAssertNil(proxy)
        XCTAssertNil(preview)
    }
}
