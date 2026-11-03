// メタデータ履歴の巻き戻し後に、追加情報からフレーム・角丸の値を戻す規則を検証する。

import UIKit
import XCTest
@testable import GLogo

final class ImageElementMetadataRevertUseCaseTests: XCTestCase {
    func test_revert_appliesFramePropertiesFromMetadata() throws {
        let store = MetadataStoreSpy()
        store.revertResult = .success
        store.storedMetadata = ImageMetadata(additionalMetadata: [
            "frameWidth": "12.5", "frameStyle": ImageFrameStyle.polaroid.rawValue,
            "roundedCorners": "true", "cornerRadius": "24", "showFrame": "true",
            "frameColor": UIColor.red.rgbaHexString
        ])
        let element = try makeElement(identifier: "image-1")

        let result = ImageElementMetadataRevertUseCase(store: store).revertToInitialState(element)

        guard case .success = result else { return XCTFail("巻き戻し結果を返すべき") }
        XCTAssertEqual(element.frameWidth, 12.5)
        XCTAssertEqual(element.frameStyle, .polaroid)
        XCTAssertTrue(element.roundedCorners)
        XCTAssertEqual(element.cornerRadius, 24)
        XCTAssertTrue(element.showFrame)
        XCTAssertEqual(element.frameColor.rgbaHexString, UIColor.red.rgbaHexString)
        XCTAssertNotNil(element.metadata)
    }

    func test_revert_withoutHistory_keepsFrameDefaults() throws {
        let store = MetadataStoreSpy()
        store.storedMetadata = ImageMetadata(additionalMetadata: ["frameWidth": "99"])
        let element = try makeElement(identifier: "image-1")

        let result = ImageElementMetadataRevertUseCase(store: store).revertToInitialState(element)

        guard case .noChanges = result else { return XCTFail("履歴がない場合は変更なしを返すべき") }
        XCTAssertEqual(element.frameWidth, 4.0)
        XCTAssertNil(element.metadata)
    }

    private func makeElement(identifier: String?) throws -> ImageElement {
        let data = try XCTUnwrap(snapshotImage(.white).pngData())
        let element = ImageElement(imageData: data)
        element.originalImageIdentifier = identifier
        return element
    }
}
