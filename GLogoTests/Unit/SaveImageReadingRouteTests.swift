// 保存の選定・加工・合成が、画像要素の画像を保存の範囲（SaveImageReading）から受け取ることを確かめる。
// 範囲の偽物は要素自身の画像と別の画像を返し、問い合わせの記録と出力の両方から、範囲を通ったかを見分ける。
// 加工に失敗したときの扱い（ベースなら合成を終える・重ねる画像なら描画用の画像で描き直す）も、問い合わせの順で固定する。

import UIKit
import XCTest
@testable import GLogo

final class SaveImageReadingRouteTests: XCTestCase {
    // MARK: - 選定

    /// 解像度は、要素自身の元画像ではなく、範囲が返す元画像で比べる。
    func test_selection_comparesScopeOriginals() {
        // 要素自身の元画像は first のほうを大きくし、範囲が返す画像は second のほうを大きくする。
        let first = makeElement(color: .red, size: CGSize(width: 64, height: 64))
        let second = makeElement(color: .blue, size: CGSize(width: 8, height: 8))
        let images = SaveImageReadingSpy()
        images.originals[ObjectIdentifier(first)] = solidImage(.red, CGSize(width: 8, height: 8))
        images.originals[ObjectIdentifier(second)] = solidImage(.blue, CGSize(width: 64, height: 64))

        let selected = ImageSelectionService().selectHighestResolutionImageElement(from: [first, second], images: images)

        XCTAssertTrue(selected === second)
        XCTAssertEqual(images.requests, [.init(.original, first), .init(.original, second)])
    }

    /// ベースの役割を持つ画像があれば、元画像を問い合わせずにそれを選ぶ。
    func test_selectBase_prefersRoleWithoutReading() {
        let overlay = makeElement(color: .red, size: CGSize(width: 64, height: 64))
        let base = makeElement(color: .blue, size: CGSize(width: 8, height: 8))
        base.imageRole = .base
        let images = SaveImageReadingSpy()

        let selected = ImageSelectionService().selectBaseImageElement(from: [overlay, base], images: images)

        XCTAssertTrue(selected === base)
        XCTAssertEqual(images.requests, [])
    }

    // MARK: - 単独の加工

    func test_applyFilters_returnsScopeFilteredImage() {
        let element = makeElement(color: .red, size: CGSize(width: 32, height: 24))
        let images = SaveImageReadingSpy()
        let marker = solidImage(.green, CGSize(width: 32, height: 24))
        images.filtered[ObjectIdentifier(element)] = [marker]

        let output = ImageProcessingService().applyFilters(to: element, images: images)

        XCTAssertTrue(output === marker)
        XCTAssertEqual(images.requests, [.init(.filtered, element)])
    }

    // MARK: - 合成

    /// ベースは寸法を得るためと可視の要素をまとめて解決するための2回、重ねる画像は1回、範囲に加工済みの画像を求める。
    /// 非表示の画像は求めない。出力は範囲が返した画像から作られる。
    func test_composite_drawsScopeFilteredImages() throws {
        let fixture = CompositeFixture()
        fixture.images.filtered[ObjectIdentifier(fixture.base)] = [fixture.baseOutput, fixture.baseOutput]
        fixture.images.filtered[ObjectIdentifier(fixture.overlay)] = [fixture.overlayOutput]

        let output = try XCTUnwrap(fixture.makeComposite())

        XCTAssertEqual(fixture.images.requests, [
            .init(.filtered, fixture.base), .init(.filtered, fixture.base), .init(.filtered, fixture.overlay)
        ])
        try assertColor(of: output, at: fixture.baseOnlyPoint, is: .green)
        try assertColor(of: output, at: fixture.overlayPoint, is: .yellow)
    }

    /// 重ねる画像の加工に失敗したら、範囲に描画用の画像を求めて描く。
    func test_composite_overlayFailure_drawsScopeDrawingImage() throws {
        let fixture = CompositeFixture()
        fixture.images.filtered[ObjectIdentifier(fixture.base)] = [fixture.baseOutput, fixture.baseOutput]
        fixture.images.filtered[ObjectIdentifier(fixture.overlay)] = [nil]
        fixture.images.drawing[ObjectIdentifier(fixture.overlay)] = solidImage(.magenta, CGSize(width: 16, height: 16))

        let output = try XCTUnwrap(fixture.makeComposite())

        XCTAssertEqual(fixture.images.requests, [
            .init(.filtered, fixture.base), .init(.filtered, fixture.base),
            .init(.filtered, fixture.overlay), .init(.drawing, fixture.overlay)
        ])
        try assertColor(of: output, at: fixture.overlayPoint, is: .magenta)
    }

    /// 描画用の画像も得られなければ、重ねる画像は描かずに合成を続ける。
    func test_composite_overlayFailures_skipOverlay() throws {
        let fixture = CompositeFixture()
        fixture.images.filtered[ObjectIdentifier(fixture.base)] = [fixture.baseOutput, fixture.baseOutput]
        fixture.images.filtered[ObjectIdentifier(fixture.overlay)] = [nil]

        let output = try XCTUnwrap(fixture.makeComposite())

        XCTAssertEqual(fixture.images.requests, [
            .init(.filtered, fixture.base), .init(.filtered, fixture.base),
            .init(.filtered, fixture.overlay), .init(.drawing, fixture.overlay)
        ])
        try assertColor(of: output, at: fixture.overlayPoint, is: .green)
    }

    /// ベースの2回目の加工に失敗したら、ベースも描画用の画像で描く。
    func test_composite_baseSecondFailure_drawsScopeDrawingImage() throws {
        let fixture = CompositeFixture()
        fixture.images.filtered[ObjectIdentifier(fixture.base)] = [fixture.baseOutput, nil]
        fixture.images.filtered[ObjectIdentifier(fixture.overlay)] = [fixture.overlayOutput]
        fixture.images.drawing[ObjectIdentifier(fixture.base)] = solidImage(.cyan, CGSize(width: 32, height: 24))

        let output = try XCTUnwrap(fixture.makeComposite())

        XCTAssertEqual(fixture.images.requests, [
            .init(.filtered, fixture.base), .init(.filtered, fixture.base),
            .init(.filtered, fixture.overlay), .init(.drawing, fixture.base)
        ])
        try assertColor(of: output, at: fixture.baseOnlyPoint, is: .cyan)
        try assertColor(of: output, at: fixture.overlayPoint, is: .yellow)
    }

    /// ベースの最初の加工に失敗したら、ほかを問い合わせずに合成を終える。
    func test_composite_baseFailure_returnsNil() {
        let fixture = CompositeFixture()
        fixture.images.filtered[ObjectIdentifier(fixture.base)] = [nil]

        XCTAssertNil(fixture.makeComposite())
        XCTAssertEqual(fixture.images.requests, [.init(.filtered, fixture.base)])
    }

    // MARK: - Helpers

    private func makeElement(color: UIColor, size: CGSize) -> ImageElement {
        ImageElementFactory().makeElement(imageData: solidImage(color, size).pngData()!)
    }

    private func assertColor(
        of image: UIImage,
        at point: CGPoint,
        is expected: UIColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let cgImage = try XCTUnwrap(image.cgImage, file: file, line: line)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ), file: file, line: line)
        let cropped = try XCTUnwrap(cgImage.cropping(to: CGRect(origin: point, size: CGSize(width: 1, height: 1))),
                                    file: file, line: line)
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        expected.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let expectedComponents = [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
        for (index, value) in pixel.enumerated() {
            XCTAssertLessThanOrEqual(abs(Int(value) - expectedComponents[index]), 8,
                                     "期待: \(expectedComponents)、実際: \(pixel)", file: file, line: line)
        }
    }
}

/// ベース（キャンバス全体）・重ねる画像（左上寄りの 8×8）・非表示の画像を持つ合成の場面。
/// 出力はベースの範囲で、ベースが返す画像（32×24）の実ピクセルの大きさになる。
private struct CompositeFixture {
    let project = LogoProject(canvasSize: CGSize(width: 32, height: 24))
    let base: ImageElement
    let overlay: ImageElement
    let hidden: ImageElement
    let images = SaveImageReadingSpy()
    let baseOutput = solidImage(.green, CGSize(width: 32, height: 24))
    let overlayOutput = solidImage(.yellow, CGSize(width: 16, height: 16))
    /// 重ねる画像が描かれる位置
    let overlayPoint = CGPoint(x: 8, y: 8)
    /// ベースだけが描かれる位置
    let baseOnlyPoint = CGPoint(x: 24, y: 18)

    init() {
        let factory = ImageElementFactory()
        base = factory.makeElement(imageData: solidImage(.red, CGSize(width: 32, height: 24)).pngData()!)
        base.imageRole = .base
        base.position = .zero
        base.size = CGSize(width: 32, height: 24)
        base.zIndex = 100
        overlay = factory.makeElement(imageData: solidImage(.blue, CGSize(width: 16, height: 16)).pngData()!)
        overlay.imageRole = .overlay
        overlay.position = CGPoint(x: 4, y: 4)
        overlay.size = CGSize(width: 8, height: 8)
        overlay.zIndex = 110
        hidden = factory.makeElement(imageData: solidImage(.black, CGSize(width: 16, height: 16)).pngData()!)
        hidden.imageRole = .overlay
        hidden.position = .zero
        hidden.size = CGSize(width: 32, height: 24)
        hidden.zIndex = 120
        hidden.isVisible = false
        project.elements = [base, overlay, hidden]
    }

    func makeComposite() -> UIImage? {
        ImageProcessingService().makeCompositeImage(baseElement: base, project: project, images: images)
    }
}

/// 問い合わせを順に記録し、要素ごとに決めておいた画像を返す保存の範囲の偽物。決めていない要素には nil を返す。
/// テストのスレッドから同期にだけ呼ばれる前提で、記録をロックなしで持つ。
private final class SaveImageReadingSpy: SaveImageReading {
    enum Kind: Equatable {
        case original
        case filtered
        case drawing
    }

    struct Request: Equatable {
        let kind: Kind
        let element: ObjectIdentifier

        init(_ kind: Kind, _ element: ImageElement) {
            self.kind = kind
            self.element = ObjectIdentifier(element)
        }
    }

    var originals: [ObjectIdentifier: UIImage] = [:]
    /// 加工済みの画像。呼ばれるたびに先頭から順に返す（nil は加工の失敗）。
    var filtered: [ObjectIdentifier: [UIImage?]] = [:]
    var drawing: [ObjectIdentifier: UIImage] = [:]
    private(set) var requests: [Request] = []

    func originalImage(of element: ImageElement) -> UIImage? {
        requests.append(Request(.original, element))
        return originals[ObjectIdentifier(element)]
    }

    func filteredImage(of element: ImageElement) -> UIImage? {
        requests.append(Request(.filtered, element))
        let key = ObjectIdentifier(element)
        guard let next = filtered[key]?.first else { return nil }
        filtered[key]?.removeFirst()
        return next
    }

    func drawingImage(of element: ImageElement) -> UIImage? {
        requests.append(Request(.drawing, element))
        return drawing[ObjectIdentifier(element)]
    }

    /// 背景画像は扱わない（このファイルのテストは画像要素の画像の経路だけを見る）。
    var backgroundImage: UIImage? { nil }
}

private func solidImage(_ color: UIColor, _ size: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}
