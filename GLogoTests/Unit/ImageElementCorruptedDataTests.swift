//
//  ImageElementCorruptedDataTests.swift
//  GLogoTests
//
//  概要:
//  破損した画像データ入力時の ImageElement 振る舞いを確認する単体テスト。
//

import XCTest
@testable import GLogo

final class ImageElementCorruptedDataTests: XCTestCase {

    func testCorruptedImageDataReturnsNilImage() {
        // 不完全なPNGヘッダのみを持つ破損データ
        let corruptedData = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x00, 0x00, 0x00])

        let element = ImageElement(imageData: corruptedData)

        XCTAssertNil(element.originalImage, "破損データの場合、originalImageはnilであるべき")
        XCTAssertNil(element.getFilteredImageForce(), "破損データはフィルター適用に失敗すべき")
    }
}
