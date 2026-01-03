//
//  ManualBackgroundRemovalUseCaseTests.swift
//  GLogoTests
//
//  概要:
//  手動背景除去ユースケースのテストコード
//

import XCTest
import UIKit
@testable import GLogo

class ManualBackgroundRemovalUseCaseTests: XCTestCase {

    var useCase: ManualBackgroundRemovalUseCase!
    var testImage: UIImage!

    override func setUp() {
        super.setUp()
        useCase = ManualBackgroundRemovalUseCase()

        // テスト用の画像を作成（100x100の赤い画像）
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        testImage = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    override func tearDown() {
        useCase = nil
        testImage = nil
        super.tearDown()
    }

    // MARK: - createInitialMask テスト

    /// 初期マスクが正しいサイズで生成されることを確認
    func testCreateInitialMaskHasCorrectSize() {
        let mask = useCase.createInitialMask(for: testImage)

        XCTAssertEqual(mask.size.width, testImage.size.width, "マスクの幅が元画像と一致すべき")
        XCTAssertEqual(mask.size.height, testImage.size.height, "マスクの高さが元画像と一致すべき")
    }

    /// 初期マスクが白色（表示状態）で生成されることを確認
    func testCreateInitialMaskIsWhite() {
        let mask = useCase.createInitialMask(for: testImage)

        // マスク中央のピクセルを取得して白であることを確認
        let color = getPixelColor(from: mask, at: CGPoint(x: 50, y: 50))

        XCTAssertNotNil(color, "ピクセルカラーが取得できるべき")
        if let color = color {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

            XCTAssertGreaterThan(red, 0.9, "赤成分が十分に高いべき")
            XCTAssertGreaterThan(green, 0.9, "緑成分が十分に高いべき")
            XCTAssertGreaterThan(blue, 0.9, "青成分が十分に高いべき")
            XCTAssertGreaterThan(alpha, 0.9, "アルファが十分に高いべき")
        }
    }

    // MARK: - drawBrush テスト

    /// ブラシ描画（消去モード）でマスクが黒くなることを確認
    func testDrawBrushEraseMode() {
        let initialMask = useCase.createInitialMask(for: testImage)
        let brushPoint = CGPoint(x: 50, y: 50)
        let brushSize: CGFloat = 20

        let updatedMask = useCase.drawBrush(
            on: initialMask,
            at: brushPoint,
            size: brushSize,
            mode: .erase
        )

        // ブラシ適用位置のピクセルが黒（透明化）になっていることを確認
        let color = getPixelColor(from: updatedMask, at: brushPoint)

        XCTAssertNotNil(color, "ピクセルカラーが取得できるべき")
        if let color = color {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

            XCTAssertLessThan(red, 0.1, "消去モードで赤成分が十分に低いべき")
            XCTAssertLessThan(green, 0.1, "消去モードで緑成分が十分に低いべき")
            XCTAssertLessThan(blue, 0.1, "消去モードで青成分が十分に低いべき")
        }
    }

    /// ブラシ描画（復元モード）でマスクが白くなることを確認
    func testDrawBrushRestoreMode() {
        // まず消去してから復元をテスト
        let initialMask = useCase.createInitialMask(for: testImage)
        let brushPoint = CGPoint(x: 50, y: 50)
        let brushSize: CGFloat = 20

        // 消去
        let erasedMask = useCase.drawBrush(
            on: initialMask,
            at: brushPoint,
            size: brushSize,
            mode: .erase
        )

        // 復元
        let restoredMask = useCase.drawBrush(
            on: erasedMask,
            at: brushPoint,
            size: brushSize,
            mode: .restore
        )

        let color = getPixelColor(from: restoredMask, at: brushPoint)

        XCTAssertNotNil(color, "ピクセルカラーが取得できるべき")
        if let color = color {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

            XCTAssertGreaterThan(red, 0.9, "復元モードで赤成分が十分に高いべき")
            XCTAssertGreaterThan(green, 0.9, "復元モードで緑成分が十分に高いべき")
            XCTAssertGreaterThan(blue, 0.9, "復元モードで青成分が十分に高いべき")
        }
    }

    // MARK: - drawLine テスト

    /// 線描画が正しく動作することを確認
    func testDrawLineEraseMode() {
        let initialMask = useCase.createInitialMask(for: testImage)
        let startPoint = CGPoint(x: 20, y: 50)
        let endPoint = CGPoint(x: 80, y: 50)
        let lineSize: CGFloat = 10

        let updatedMask = useCase.drawLine(
            on: initialMask,
            from: startPoint,
            to: endPoint,
            size: lineSize,
            mode: .erase
        )

        // 線の中央点のピクセルが黒になっていることを確認
        let midPoint = CGPoint(x: 50, y: 50)
        let color = getPixelColor(from: updatedMask, at: midPoint)

        XCTAssertNotNil(color, "ピクセルカラーが取得できるべき")
        if let color = color {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

            XCTAssertLessThan(red, 0.1, "線上のピクセルが黒に近いべき")
        }
    }

    /// 線描画が線外のピクセルに影響しないことを確認
    func testDrawLineDoesNotAffectOutsidePixels() {
        let initialMask = useCase.createInitialMask(for: testImage)
        let startPoint = CGPoint(x: 20, y: 50)
        let endPoint = CGPoint(x: 80, y: 50)
        let lineSize: CGFloat = 10

        let updatedMask = useCase.drawLine(
            on: initialMask,
            from: startPoint,
            to: endPoint,
            size: lineSize,
            mode: .erase
        )

        // 線から離れた位置のピクセルが白のままであることを確認
        let outsidePoint = CGPoint(x: 50, y: 10)
        let color = getPixelColor(from: updatedMask, at: outsidePoint)

        XCTAssertNotNil(color, "ピクセルカラーが取得できるべき")
        if let color = color {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

            XCTAssertGreaterThan(red, 0.9, "線外のピクセルは白のままであるべき")
        }
    }

    // MARK: - applyMask テスト

    /// マスク適用で透過処理が正しく行われることを確認
    func testApplyMaskCreatesTransparency() {
        // 中央を消去したマスクを作成
        let mask = useCase.createInitialMask(for: testImage)
        let erasedMask = useCase.drawBrush(
            on: mask,
            at: CGPoint(x: 50, y: 50),
            size: 30,
            mode: .erase
        )

        // マスクを適用
        let result = useCase.applyMask(erasedMask, to: testImage)

        XCTAssertNotNil(result, "マスク適用結果がnilでないべき")

        if let result = result {
            // 結果画像のサイズが元画像と一致することを確認
            XCTAssertEqual(result.size.width, testImage.size.width, accuracy: 0.01, "結果画像の幅が一致すべき")
            XCTAssertEqual(result.size.height, testImage.size.height, accuracy: 0.01, "結果画像の高さが一致すべき")

            // 中央のピクセルが透明になっていることを確認
            let centerColor = getPixelColor(from: result, at: CGPoint(x: 50, y: 50))
            if let color = centerColor {
                var alpha: CGFloat = 0
                color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
                XCTAssertLessThan(alpha, 0.2, "消去された部分は透明であるべき")
            }
        }
    }

    /// マスク適用で白い部分が保持されることを確認
    func testApplyMaskPreservesVisibleAreas() {
        // 全体が白いマスク（何も消去していない）
        let mask = useCase.createInitialMask(for: testImage)

        let result = useCase.applyMask(mask, to: testImage)

        XCTAssertNotNil(result, "マスク適用結果がnilでないべき")

        if let result = result {
            // 角のピクセルが不透明であることを確認
            let cornerColor = getPixelColor(from: result, at: CGPoint(x: 10, y: 10))
            if let color = cornerColor {
                var alpha: CGFloat = 0
                color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
                XCTAssertGreaterThan(alpha, 0.9, "表示部分は不透明であるべき")
            }
        }
    }

    // MARK: - ヘルパーメソッド

    /// 指定座標のピクセルカラーを取得
    private func getPixelColor(from image: UIImage, at point: CGPoint) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var rawData = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // UIKit座標系に合わせる（原点を左上に）
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 座標をスケールに合わせて調整
        let x = Int(point.x * image.scale)
        let y = Int(point.y * image.scale)

        guard x >= 0, x < width, y >= 0, y < height else { return nil }

        let pixelOffset = y * bytesPerRow + x * bytesPerPixel
        let r = CGFloat(rawData[pixelOffset]) / 255.0
        let g = CGFloat(rawData[pixelOffset + 1]) / 255.0
        let b = CGFloat(rawData[pixelOffset + 2]) / 255.0
        let a = CGFloat(rawData[pixelOffset + 3]) / 255.0

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
