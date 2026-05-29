//
//  ImageElementMetadataRevertUseCaseRegressionTests.swift
//  GLogoTests
//
//  概要:
//  ImageElement の初期状態リバート時にメタデータ履歴が UseCase 経由で復元されることを検証します。
//

import XCTest
import UIKit
import CryptoKit
@testable import GLogo

/// 画像要素メタデータリバートユースケースの回帰テスト
final class ImageElementMetadataRevertUseCaseRegressionTests: XCTestCase {
    private let manager = ImageMetadataManager.shared
    private var cleanupIdentifiers: [String] = []

    override func tearDownWithError() throws {
        for identifier in cleanupIdentifiers {
            removePersistedMetadataFiles(for: identifier)
        }
        cleanupIdentifiers.removeAll()
        try super.tearDownWithError()
    }

    /// UseCase経由のリバートでメタデータ履歴と画像プロパティが復元されることを検証
    /// - Parameters: なし
    /// - Returns: なし
    func testRevertToInitialState_RevertsMetadataAndAppliesImageProperties() throws {
        let identifier = makeIdentifier(prefix: "image_element_metadata_revert")
        cleanupIdentifiers.append(identifier)

        let imageElement = try makeImageElement()
        imageElement.originalImageIdentifier = identifier
        imageElement.frameWidth = 12.0

        var currentMetadata = ImageMetadata()
        currentMetadata.additionalMetadata["frameWidth"] = "12.0"
        XCTAssertTrue(manager.saveMetadata(currentMetadata, for: identifier))
        manager.addToEditHistory(
            identifier: identifier,
            operation: MetadataEditOperation(
                type: .edit,
                fieldKey: "frameWidth",
                oldValue: "7.5",
                newValue: "12.0"
            )
        )

        ImageElementMetadataRevertUseCase(metadataManager: manager)
            .revertToInitialState(imageElement)

        XCTAssertEqual(imageElement.frameWidth, 7.5, accuracy: 0.0001)
        XCTAssertEqual(imageElement.metadata?.additionalMetadata["frameWidth"], "7.5")
        XCTAssertFalse(manager.hasEditHistory(for: identifier))
    }

    /// ViewModelのRevert経路でもUseCase経由でメタデータが復元されることを検証
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testViewModelRevertSelectedImageToInitialState_UsesMetadataRevertUseCase() throws {
        let identifier = makeIdentifier(prefix: "event_sourcing_metadata_revert")
        cleanupIdentifiers.append(identifier)

        let project = LogoProject(name: "metadata-revert", canvasSize: CGSize(width: 1080, height: 1920))
        let viewModel = EditorViewModel(project: project)
        let imageElement = try makeImageElement()
        imageElement.originalImageIdentifier = identifier
        imageElement.frameWidth = 12.0

        var currentMetadata = ImageMetadata()
        currentMetadata.additionalMetadata["frameWidth"] = "12.0"
        XCTAssertTrue(manager.saveMetadata(currentMetadata, for: identifier))
        manager.addToEditHistory(
            identifier: identifier,
            operation: MetadataEditOperation(
                type: .edit,
                fieldKey: "frameWidth",
                oldValue: "7.5",
                newValue: "12.0"
            )
        )

        viewModel.addElement(imageElement)
        viewModel.revertSelectedImageToInitialState()

        XCTAssertEqual(imageElement.frameWidth, 7.5, accuracy: 0.0001)
        XCTAssertEqual(imageElement.metadata?.additionalMetadata["frameWidth"], "7.5")
        XCTAssertFalse(manager.hasEditHistory(for: identifier))
    }

    // MARK: - Helpers

    /// テスト用の画像要素を生成
    /// - Parameters: なし
    /// - Returns: 生成した画像要素
    private func makeImageElement() throws -> ImageElement {
        let image = makeSolidImage(size: CGSize(width: 64, height: 64), color: .white)
        let data = try XCTUnwrap(image.pngData())
        return ImageElement(imageData: data, importOrder: 0)
    }

    /// 単色画像を生成する
    /// - Parameters:
    ///   - size: 画像サイズ
    ///   - color: 塗りつぶし色
    /// - Returns: 生成した画像
    private func makeSolidImage(size: CGSize, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// テスト用の一意な識別子を生成
    /// - Parameters:
    ///   - prefix: 識別子プレフィックス
    /// - Returns: 一意な識別子
    private func makeIdentifier(prefix: String) -> String {
        "\(prefix)_\(UUID().uuidString)"
    }

    /// メタデータ/履歴の保存ファイルを削除
    /// - Parameters:
    ///   - identifier: 画像識別子
    /// - Returns: なし
    private func removePersistedMetadataFiles(for identifier: String) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let safeKey = makeSafeStorageKey(identifier)
        let metadataURL = documentsDirectory
            .appendingPathComponent("GLogo/Metadata")
            .appendingPathComponent("metadata_\(safeKey).json")
        let historyURL = documentsDirectory
            .appendingPathComponent("GLogo/History")
            .appendingPathComponent("history_\(safeKey).json")

        if FileManager.default.fileExists(atPath: metadataURL.path) {
            try? FileManager.default.removeItem(at: metadataURL)
        }
        if FileManager.default.fileExists(atPath: historyURL.path) {
            try? FileManager.default.removeItem(at: historyURL)
        }
    }

    /// `MetadataFileStore` と同じ安全キーをテスト側で計算する
    /// - Parameters:
    ///   - identifier: 元の画像識別子
    /// - Returns: ファイル名安全な保存キー
    private func makeSafeStorageKey(_ identifier: String) -> String {
        let digest = SHA256.hash(data: Data(identifier.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
