// メタデータ編集の記録規則（操作種別・追加情報の更新・保存先への書き込み）を、保存先を差し替えて検証する。

import UIKit
import XCTest
@testable import GLogo

final class ImageMetadataEditUseCaseTests: XCTestCase {
    func test_recordEdit_withoutIdentifier_writesNothing() throws {
        let store = MetadataStoreSpy()
        let element = try makeElement(identifier: nil)
        ImageMetadataEditUseCase(store: store).recordEditIfNeeded(
            for: element, fieldKey: "frameWidth", oldValue: 4.0, newValue: 8.0
        )
        XCTAssertNil(element.metadata)
        XCTAssertTrue(store.operations.isEmpty)
        XCTAssertTrue(store.saved.isEmpty)
    }

    func test_recordEdit_mapsOperationTypeAndUpdatesMetadata() throws {
        let store = MetadataStoreSpy()
        let element = try makeElement(identifier: "image-1")
        let useCase = ImageMetadataEditUseCase(store: store)

        useCase.recordEditIfNeeded(for: element, fieldKey: "showFrame", oldValue: nil, newValue: true)
        useCase.recordEditIfNeeded(for: element, fieldKey: "frameWidth", oldValue: 4.0, newValue: 8.0)
        useCase.recordEditIfNeeded(for: element, fieldKey: "showFrame", oldValue: true, newValue: nil)

        XCTAssertEqual(store.operations.map(\.type), [.restore, .edit, .delete])
        XCTAssertEqual(store.operations.map(\.fieldKey), ["showFrame", "frameWidth", "showFrame"])
        XCTAssertEqual(store.operations[1].oldValue, "4.0")
        XCTAssertEqual(store.operations[1].newValue, "8.0")
        // 値の削除は追加情報からキーを取り除き、保存先には毎回最新の内容を書き込む。
        XCTAssertEqual(element.metadata?.additionalMetadata, ["frameWidth": "8.0"])
        XCTAssertEqual(store.saved.count, 3)
        XCTAssertEqual(store.saved.last?.identifier, "image-1")
        XCTAssertEqual(store.saved.last?.metadata.additionalMetadata, ["frameWidth": "8.0"])
    }

    private func makeElement(identifier: String?) throws -> ImageElement {
        let data = try XCTUnwrap(snapshotImage(.white).pngData())
        let element = ImageElementFactory().makeElement(imageData: data)
        element.originalImageIdentifier = identifier
        return element
    }
}

/// 保存先への書き込みを記録し、巻き戻し結果と復元後のメタデータを指定できる。
final class MetadataStoreSpy: ImageMetadataStoring {
    var operations: [MetadataEditOperation] = []
    var saved: [(metadata: ImageMetadata, identifier: String)] = []
    var storedMetadata: ImageMetadata?
    var revertResult: MetadataOperationResult = .noChanges
    var history = false

    func getMetadata(for identifier: String) -> ImageMetadata? { storedMetadata }

    func saveMetadata(_ metadata: ImageMetadata, for identifier: String) -> Bool {
        saved.append((metadata, identifier))
        return true
    }

    func hasEditHistory(for identifier: String) -> Bool { history }

    func addToEditHistory(identifier: String, operation: MetadataEditOperation) {
        operations.append(operation)
    }

    func revertMetadata(for identifier: String, to operationId: UUID?) -> MetadataOperationResult {
        revertResult
    }
}
