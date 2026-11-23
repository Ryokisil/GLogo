// 背景設定（BackgroundSettings）の保存データの契約を検証する。

import UIKit
import XCTest
@testable import GLogo

final class BackgroundSettingsTests: XCTestCase {
    // MARK: - 保存データ

    /// 画像の背景は、種類・ファイル名・不透明度を書き出し、読み戻せる。書き出すキーは今の形のまま（画像そのものは含めない）。
    func test_imageBackground_roundTrips() throws {
        var settings = BackgroundSettings()
        settings.type = .image
        settings.imageFileName = "background_1"
        settings.opacity = 0.4

        let data = try JSONEncoder().encode(settings)

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), [
            "type", "opacity", "gradientType", "gradientDirection", "gradientAngle", "imageFileName",
            "colorData", "gradientStartColorData", "gradientEndColorData",
        ])
        XCTAssertEqual(object["type"] as? String, "image")
        XCTAssertEqual(object["imageFileName"] as? String, "background_1")
        let decoded = try JSONDecoder().decode(BackgroundSettings.self, from: data)
        XCTAssertEqual(decoded.type, .image)
        XCTAssertEqual(decoded.imageFileName, "background_1")
        XCTAssertEqual(decoded.opacity, 0.4, accuracy: 0.0001)
    }
}
