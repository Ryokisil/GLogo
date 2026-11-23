// 背景画像のテストで共有する補助。背景のアセットの書き換え、背景が見えるプロジェクト、画素の読み取りをまとめる。

import UIKit
import XCTest
@testable import GLogo

/// テストごとに一意の名前で、背景のアセット（AssetManager の背景のディレクトリ）を書き換える。
/// 書き込みは AssetManager の保存を通すため、キャッシュも同じ内容になる（キャンバスの次の描画に届く形）。
/// 使い終わったら remove() で消す。
struct BackgroundAssetFile {
    let name = "background_test_\(UUID().uuidString)"

    func write(_ image: UIImage, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            AssetManager.shared.saveImage(image, name: name, type: .background, alsoSaveProxy: false),
            "背景のアセットを書き込めない", file: file, line: line
        )
    }

    func remove() {
        _ = AssetManager.shared.deleteImage(named: name, type: .background)
    }
}

/// 画素の期待値（乗算済みの RGBA、0〜255）。
enum BackgroundPixel {
    static let red = [255, 0, 0, 255]
    static let blue = [0, 0, 255, 255]
    static let magenta = [255, 0, 255, 255]
    static let halfRed = [128, 0, 0, 128]
    static let halfBlue = [0, 0, 128, 128]
    static let clear = [0, 0, 0, 0]
}

/// 背景を画像にし、キャンバス全体を覆う透明な画像要素を置いたプロジェクト（キャンバスは 40×40）。
/// 合成は背景のあとに画像要素を描くため、画像要素を透明にして、背景の画素がそのまま出力に出るようにする。
/// 1つ目の要素をベースにする。出力の画素の座標は、キャンバスの座標と同じになる。
/// - Parameter imageCount: 透明な画像要素の数。2以上なら、自動の判定でも合成保存になる
@MainActor
func makeBackgroundImageProject(fileName: String?, opacity: CGFloat = 1, imageCount: Int = 1) throws -> LogoProject {
    let size = CGSize(width: 40, height: 40)
    let project = LogoProject(name: "BackgroundImage", canvasSize: size)
    project.backgroundSettings.type = .image
    project.backgroundSettings.imageFileName = fileName
    project.backgroundSettings.opacity = opacity
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    let transparent = try XCTUnwrap(UIGraphicsImageRenderer(size: size, format: format).image { _ in }.pngData())
    for index in 0..<imageCount {
        let element = ImageElementFactory().makeElement(imageData: transparent, importOrder: index)
        element.position = .zero
        element.size = size
        element.imageRole = index == 0 ? .base : .overlay
        project.addElement(element)
    }
    return project
}

/// 上半分と下半分で色の違う画像（32×24）。描いたときの向きを見分ける。
func twoToneImage(top: UIColor, bottom: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: 32, height: 24), format: format).image { context in
        top.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 12))
        bottom.setFill()
        context.fill(CGRect(x: 0, y: 12, width: 32, height: 12))
    }
}

/// 画素（上からの座標）が、期待値（乗算済みの RGBA、0〜255）に近いことを確かめる。許容差は各成分 ±8。
func assertRGBA(
    of image: UIImage,
    at point: CGPoint,
    equals expected: [Int],
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    let cgImage = try XCTUnwrap(image.cgImage, file: file, line: line)
    let width = cgImage.width
    let height = cgImage.height
    var buffer = [UInt8](repeating: 0, count: width * height * 4)
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    let context = try XCTUnwrap(CGContext(
        data: &buffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo
    ), file: file, line: line)
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    // 画像の座標は上から。画素の倍率（scale）を掛けて位置を合わせる。
    let x = Int(point.x * image.scale)
    let y = Int(point.y * image.scale)
    let offset = (y * width + x) * 4
    let actual = buffer[offset..<(offset + 4)].map(Int.init)
    let isClose = zip(actual, expected).allSatisfy { abs($0 - $1) <= 8 }
    XCTAssertTrue(isClose, "\(message)（期待: \(expected)、実際: \(actual)）", file: file, line: line)
}
