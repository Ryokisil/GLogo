//
//  ImagePickerViewCallbackTests.swift
//  GLogoTests
//
//  概要:
//  ImagePickerView（PhotoPicker.Coordinator）の onSelect 呼び出し回数と
//  返却値の基本整合性を検証する単体テスト。
//

import XCTest
import UIKit
import PhotosUI
import UniformTypeIdentifiers
@testable import GLogo

@available(iOS 15.0, *)
final class ImagePickerViewCallbackTests: XCTestCase {
    /// 画像プロバイダ選択時に onSelect が1回だけ呼ばれることを確認
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testPhotoPickerCoordinator_ImageProvider_CallsOnSelectExactlyOnce() {
        let expectation = expectation(description: "onSelect called once for image provider")
        expectation.expectedFulfillmentCount = 1

        var received: [SelectedImageInfo] = []
        let picker = PhotoPicker { info in
            received.append(info)
            expectation.fulfill()
        }
        let coordinator = picker.makeCoordinator()
        let controller = PHPickerViewController(configuration: PHPickerConfiguration(photoLibrary: .shared()))

        let provider = NSItemProvider(object: makeSolidImage(color: .systemBlue))
        coordinator.handlePickedItemProvider(
            provider,
            assetIdentifier: nil,
            picker: controller
        )

        waitForExpectations(timeout: 3.0)
        XCTAssertEqual(received.count, 1)
        XCTAssertNotNil(received.first?.image)
    }

    /// 非対応プロバイダ選択時に image=nil で onSelect が1回だけ呼ばれることを確認
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testPhotoPickerCoordinator_UnsupportedProvider_CallsOnSelectExactlyOnceWithNilImage() {
        let expectation = expectation(description: "onSelect called once for unsupported provider")
        expectation.expectedFulfillmentCount = 1

        var received: [SelectedImageInfo] = []
        let picker = PhotoPicker { info in
            received.append(info)
            expectation.fulfill()
        }
        let coordinator = picker.makeCoordinator()
        let controller = PHPickerViewController(configuration: PHPickerConfiguration(photoLibrary: .shared()))

        let provider = NSItemProvider(item: "dummy-text" as NSString, typeIdentifier: UTType.plainText.identifier)
        coordinator.handlePickedItemProvider(
            provider,
            assetIdentifier: nil,
            picker: controller
        )

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(received.count, 1)
        XCTAssertNil(received.first?.image)
    }

    // MARK: - Helpers

    /// 単色のテスト画像を生成
    /// - Parameters:
    ///   - color: 塗りつぶし色
    /// - Returns: 16x16 の単色画像
    private func makeSolidImage(color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
    }
}
