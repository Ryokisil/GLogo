//
//  PhotoLibrarySelectionTests.swift
//  GLogoTests
//
//  概要:
//  写真保存用の画像選択ロジック（最高解像度選択）の単体テスト。
//

import XCTest
import UIKit
@testable import GLogo

final class PhotoLibrarySelectionTests: XCTestCase {

    func testSelectHighestResolutionImageElement_prefersLargestPixelCount() {
        // 低・中・高解像度の画像データを用意
        let lowResElement = ImageElement(imageData: makeImage(size: CGSize(width: 200, height: 200)))
        let midResElement = ImageElement(imageData: makeImage(size: CGSize(width: 800, height: 600)))
        let highResElement = ImageElement(imageData: makeImage(size: CGSize(width: 1920, height: 1080)))

        let elements = [midResElement, lowResElement, highResElement]

        // 幅×高さで最大のものが選択されることを確認
        let selectionService = ImageSelectionService()
        let selected = selectionService.selectHighestResolutionImageElement(from: elements)
        XCTAssertEqual(selected?.id, highResElement.id)
    }

    // MARK: - Helpers

    private func makeImage(size: CGSize) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData() ?? Data()
    }
}
