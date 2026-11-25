// 背景設定（BackgroundSettings）の保存データの契約と、受け取った画像での描画（第26回）を検証する。

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

    // MARK: - 取得する名前（第26回）

    /// 取得する名前は、画像の背景のときのファイル名だけ。単色・グラデーションでは、ファイル名が残っていても取得しない。
    func test_imageNameToDraw_onlyForImageBackground() {
        let cases: [(BackgroundType, String?, String?)] = [
            (.image, "background_1", "background_1"),
            (.image, nil, nil),
            (.solid, "background_1", nil),
            (.gradient, "background_1", nil),
        ]
        for (type, fileName, expected) in cases {
            var settings = BackgroundSettings()
            settings.type = type
            settings.imageFileName = fileName
            XCTAssertEqual(settings.imageNameToDraw, expected, "\(type)・\(fileName ?? "ファイル名なし")")
        }
    }

    // MARK: - 受け取った画像での描画（第26回）
    // 期待値は描画の式からではなく、画素の値で書く（乗算済みの RGBA）。

    /// 画像の背景は、受け取った画像を CGContext.draw で描く。UIKit の描画先では上下が反転する（今の挙動を固定する）。
    func test_imageBackground_drawsGivenImageFlipped() throws {
        let settings = imageBackground(opacity: 1)

        let drawn = draw(settings, image: twoToneImage(top: .red, bottom: .blue))

        try assertRGBA(of: drawn, at: CGPoint(x: 20, y: 5), equals: BackgroundPixel.blue, "上側には画像の下半分（青）")
        try assertRGBA(of: drawn, at: CGPoint(x: 20, y: 35), equals: BackgroundPixel.red, "下側には画像の上半分（赤）")
    }

    /// 背景の不透明度は画像にもかかる（0.5 は半分、0 は描かない）。
    func test_imageBackground_appliesOpacity() throws {
        let image = twoToneImage(top: .red, bottom: .blue)

        let half = draw(imageBackground(opacity: 0.5), image: image)
        try assertRGBA(of: half, at: CGPoint(x: 20, y: 5), equals: BackgroundPixel.halfBlue, "不透明度 0.5（上側）")
        try assertRGBA(of: half, at: CGPoint(x: 20, y: 35), equals: BackgroundPixel.halfRed, "不透明度 0.5（下側）")

        let none = draw(imageBackground(opacity: 0), image: image)
        try assertRGBA(of: none, at: CGPoint(x: 20, y: 5), equals: BackgroundPixel.clear, "不透明度 0（上側）")
        try assertRGBA(of: none, at: CGPoint(x: 20, y: 35), equals: BackgroundPixel.clear, "不透明度 0（下側）")
    }

    /// 画像を受け取れなければ描かない。ファイル名のない画像の背景は、画像を渡されても描かない。
    func test_imageBackground_withoutImageOrName_drawsNothing() throws {
        let missing = draw(imageBackground(opacity: 1), image: nil)
        try assertRGBA(of: missing, at: CGPoint(x: 20, y: 20), equals: BackgroundPixel.clear, "画像を受け取れない")

        var unnamed = imageBackground(opacity: 1)
        unnamed.imageFileName = nil
        let drawn = draw(unnamed, image: snapshotImage(.magenta))
        try assertRGBA(of: drawn, at: CGPoint(x: 20, y: 20), equals: BackgroundPixel.clear, "ファイル名がない")
    }

    /// 単色の背景は、画像を渡されても（ファイル名が残っていても）単色で描く。
    func test_solidBackground_ignoresImage() throws {
        var settings = BackgroundSettings(color: .red)
        settings.imageFileName = "background_1"

        let drawn = draw(settings, image: snapshotImage(.magenta))

        try assertRGBA(of: drawn, at: CGPoint(x: 20, y: 20), equals: BackgroundPixel.red, "単色（赤）のまま")
    }

    /// グラデーションの背景は、画像を渡されても（ファイル名が残っていても）変わらない。
    func test_gradientBackground_ignoresImage() throws {
        var settings = BackgroundSettings(startColor: .red, endColor: .blue)
        settings.imageFileName = "background_1"

        let withImage = draw(settings, image: snapshotImage(.magenta))
        let withoutImage = draw(settings, image: nil)

        XCTAssertEqual(withImage.pngData(), withoutImage.pngData(), "画像を渡しても、渡さないときと同じ画素")
        // 上から下へ赤 → 青。端の画素は、それぞれの色に近い。
        try assertRGBA(of: withImage, at: CGPoint(x: 20, y: 0), equals: BackgroundPixel.red, "上端は開始色（赤）")
        try assertRGBA(of: withImage, at: CGPoint(x: 20, y: 39), equals: BackgroundPixel.blue, "下端は終了色（青）")
    }

    // MARK: - 補助

    private func imageBackground(opacity: CGFloat) -> BackgroundSettings {
        var settings = BackgroundSettings()
        settings.type = .image
        settings.imageFileName = "background_1"
        settings.opacity = opacity
        return settings
    }

    /// 透明な 40×40（倍率1）の描画先に、背景を描く。
    private func draw(_ settings: BackgroundSettings, image: UIImage?) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40), format: format).image { context in
            settings.draw(in: context.cgContext, rect: CGRect(x: 0, y: 0, width: 40, height: 40), image: image)
        }
    }
}
