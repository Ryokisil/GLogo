//
//  ImageMetadataManagerConsistencyRegressionTests.swift
//  GLogoTests
//
//  概要:
//  ImageMetadataManager の履歴/メタデータ整合性を検証する回帰テスト。
//  Swift 6 移行後の並行実行でも履歴欠落や読み取り不能が起きないことを確認する。
//

import XCTest
import CryptoKit
@testable import GLogo

/// ImageMetadataManager の整合性回帰テスト
final class ImageMetadataManagerConsistencyRegressionTests: XCTestCase {
    private let manager = ImageMetadataManager.shared
    private let fileStore = MetadataFileStore()
    private var cleanupIdentifiers: [String] = []

    override func tearDownWithError() throws {
        for identifier in cleanupIdentifiers {
            removePersistedMetadataFiles(for: identifier)
        }
        cleanupIdentifiers.removeAll()
        try super.tearDownWithError()
    }

    /// 履歴追加を並行実行してもメモリ上の履歴件数が欠落しないことを確認
    /// - Parameters: なし
    /// - Returns: なし
    func testAddToEditHistory_ConcurrentWrites_PreservesAllInMemoryOperations() async {
        let manager = self.manager
        let identifier = makeIdentifier(prefix: "history_concurrent")
        cleanupIdentifiers.append(identifier)
        let operationCount = 30

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<operationCount {
                group.addTask {
                    let operation = MetadataEditOperation(
                        type: .edit,
                        fieldKey: "field_\(index)",
                        oldValue: nil,
                        newValue: "value_\(index)"
                    )
                    manager.addToEditHistory(identifier: identifier, operation: operation)
                }
            }
            await group.waitForAll()
        }

        let history = manager.getEditHistory(for: identifier)
        XCTAssertEqual(history.count, operationCount)
        XCTAssertTrue(manager.hasEditHistory(for: identifier))
    }

    /// 履歴追加後にファイルストアから読み戻せることを確認
    /// - Parameters: なし
    /// - Returns: なし
    func testAddToEditHistory_PersistsToMetadataFileStore() {
        let identifier = makeIdentifier(prefix: "history_persist")
        cleanupIdentifiers.append(identifier)

        manager.addToEditHistory(
            identifier: identifier,
            operation: MetadataEditOperation(type: .edit, fieldKey: "title", oldValue: nil, newValue: "A")
        )
        manager.addToEditHistory(
            identifier: identifier,
            operation: MetadataEditOperation(type: .update, fieldKey: "author", oldValue: nil, newValue: "B")
        )
        manager.addToEditHistory(
            identifier: identifier,
            operation: MetadataEditOperation(type: .delete, fieldKey: "copyright", oldValue: "C", newValue: nil)
        )

        let history = fileStore.loadEditHistory(for: identifier)
        XCTAssertEqual(history?.count, 3)
        XCTAssertEqual(history?.map(\.fieldKey), ["title", "author", "copyright"])
    }

    /// メタデータ保存を並行実行してもキャッシュ/ディスクから読み取り可能であることを確認
    /// - Parameters: なし
    /// - Returns: なし
    func testSaveMetadata_ConcurrentWrites_RemainsReadableFromCacheAndDisk() async {
        let manager = self.manager
        let identifier = makeIdentifier(prefix: "metadata_concurrent")
        cleanupIdentifiers.append(identifier)

        let titles = (0..<20).map { "title_\($0)" }
        await withTaskGroup(of: Void.self) { group in
            for title in titles {
                group.addTask {
                    var metadata = ImageMetadata()
                    metadata.title = title
                    _ = manager.saveMetadata(metadata, for: identifier)
                }
            }
            await group.waitForAll()
        }

        let cached = manager.getMetadata(for: identifier)
        let persisted = fileStore.loadMetadata(for: identifier)

        XCTAssertNotNil(cached)
        XCTAssertNotNil(persisted)
        XCTAssertTrue(titles.contains(cached?.title ?? ""))
        XCTAssertTrue(titles.contains(persisted?.title ?? ""))
    }

    /// 識別子に `/` を含んでも安全な保存キーへ変換して永続化できることを確認
    /// - Parameters: なし
    /// - Returns: なし
    func testSaveMetadata_IdentifierContainingSlash_PersistsUsingSafeStorageKey() {
        let identifier = "metadata_slash/\(UUID().uuidString)"
        cleanupIdentifiers.append(identifier)

        var metadata = ImageMetadata()
        metadata.title = "slash-path"

        let saveResult = fileStore.saveMetadata(metadata, for: identifier)
        let persisted = fileStore.loadMetadata(for: identifier)

        XCTAssertTrue(saveResult)
        XCTAssertEqual(persisted?.title, "slash-path")
    }

    /// 識別子に `/` を含んでも履歴JSONを永続化できることを確認
    /// - Parameters: なし
    /// - Returns: なし
    func testSaveEditHistory_IdentifierContainingSlash_PersistsUsingSafeStorageKey() {
        let identifier = "history_slash/\(UUID().uuidString)"
        cleanupIdentifiers.append(identifier)

        let operations = [
            MetadataEditOperation(type: .edit, fieldKey: "title", oldValue: nil, newValue: "A"),
            MetadataEditOperation(type: .update, fieldKey: "author", oldValue: nil, newValue: "B")
        ]

        let saveResult = fileStore.saveEditHistory(operations, for: identifier)
        let persisted = fileStore.loadEditHistory(for: identifier)

        XCTAssertTrue(saveResult)
        XCTAssertEqual(persisted?.count, operations.count)
        XCTAssertEqual(persisted?.map(\.fieldKey), operations.map(\.fieldKey))
    }

    /// 旧形式ファイル名で保存されたメタデータも読み込み互換を維持することを確認
    /// - Parameters: なし
    /// - Returns: なし
    func testLoadMetadata_LegacyRawIdentifierFile_RemainsReadable() throws {
        let identifier = makeIdentifier(prefix: "legacy_metadata")
        cleanupIdentifiers.append(identifier)

        var metadata = ImageMetadata()
        metadata.author = "legacy-author"

        let legacyURL = try makeLegacyMetadataFileURL(for: identifier)
        try FileManager.default.createDirectory(
            at: legacyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(metadata).write(to: legacyURL)

        let loaded = fileStore.loadMetadata(for: identifier)
        XCTAssertEqual(loaded?.author, "legacy-author")
    }

    // MARK: - Helpers

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
        let legacyMetadataURL = documentsDirectory
            .appendingPathComponent("GLogo/Metadata")
            .appendingPathComponent("metadata_\(identifier).json")
        let legacyHistoryURL = documentsDirectory
            .appendingPathComponent("GLogo/History")
            .appendingPathComponent("history_\(identifier).json")

        if FileManager.default.fileExists(atPath: metadataURL.path) {
            try? FileManager.default.removeItem(at: metadataURL)
        }
        if FileManager.default.fileExists(atPath: historyURL.path) {
            try? FileManager.default.removeItem(at: historyURL)
        }
        if FileManager.default.fileExists(atPath: legacyMetadataURL.path) {
            try? FileManager.default.removeItem(at: legacyMetadataURL)
        }
        if FileManager.default.fileExists(atPath: legacyHistoryURL.path) {
            try? FileManager.default.removeItem(at: legacyHistoryURL)
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

    /// 旧形式のメタデータ保存先URLを生成する
    /// - Parameters:
    ///   - identifier: 画像識別子
    /// - Returns: 旧形式の保存先URL
    private func makeLegacyMetadataFileURL(for identifier: String) throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw XCTSkip("Documents directory unavailable")
        }
        return documentsDirectory
            .appendingPathComponent("GLogo/Metadata")
            .appendingPathComponent("metadata_\(identifier).json")
    }
}
