// 画像属性の変更世代と履歴移動が、非同期加工のトークンを失効させる契約を検証する。

import XCTest
@testable import GLogo

final class ImageEditTokenTests: XCTestCase {
    @MainActor
    func test_adjustments_invalidateEvenAfterRestoration() throws {
        let image = ImageElementFactory().makeElement(imageData: snapshotImage(.red).pngData()!)
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project)
        for descriptor in ImageAdjustmentDescriptor.all.values {
            let token = try XCTUnwrap(editor.imageEdits.imageEditToken(for: image))
            let old = image[keyPath: descriptor.keyPath]
            image[keyPath: descriptor.keyPath] = old + 0.1
            image[keyPath: descriptor.keyPath] = old
            XCTAssertFalse(editor.imageEdits.isImageEditCurrent(token, for: image), "\(descriptor.key)")
        }
        let changes: [(ImageElement) -> Void] = [
            { let data = $0.imageData; $0.imageData = data }, { $0.imageFileName = "changed" },
            { $0.originalImageURL = URL(fileURLWithPath: "/test") }, { $0.originalImagePath = "/test" },
            { $0.originalImageIdentifier = "changed" }, { $0.hasAppliedUpscale = true },
            { $0.toneCurveData.rgbPoints[1].output = 0.7 }, { $0.tintColor = .green },
            { $0.appliedFilterRecipe = FilterCatalog.vintageWarm.recipe },
            { $0.appliedFilterPresetId = FilterCatalog.vintageWarm.id },
            { $0.backgroundBlurMaskData = Data([1]) }, { $0.showFrame = true },
            { $0.frameColor = .blue }, { $0.frameStyle = .double }, { $0.roundedCorners = true }
        ]
        for change in changes {
            let token = try XCTUnwrap(editor.imageEdits.imageEditToken(for: image))
            change(image)
            XCTAssertFalse(editor.imageEdits.isImageEditCurrent(token, for: image))
        }
    }

    func test_historyRevision_movesOnlyAcrossRestoration() {
        let project = LogoProject()
        let history = EditorHistory(project: project)
        let start = history.restorationRevision
        XCTAssertFalse(history.undo())
        XCTAssertFalse(history.redo())
        XCTAssertEqual(history.restorationRevision, start)
        history.recordAndApply(ElementAddedEvent(element: TextElement(text: "A")))
        XCTAssertEqual(history.restorationRevision, start)
        XCTAssertTrue(history.undo())
        XCTAssertTrue(history.redo())
        XCTAssertEqual(history.restorationRevision, start + 2)
        history.clearHistory()
        history.setProject(LogoProject())
        XCTAssertEqual(history.restorationRevision, start + 4)
    }

    func test_revision_isNotPersisted() throws {
        let image = ImageElementFactory().makeElement(imageData: snapshotImage(.red).pngData()!)
        image.brightnessAdjustment = 0.4
        let data = try JSONEncoder().encode(image)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["editRevision"])
        let restored = try JSONDecoder.live().decode(ImageElement.self, from: data)
        XCTAssertEqual(restored.brightnessAdjustment, 0.4)
        let before = restored.editRevision
        restored.brightnessAdjustment = 0
        XCTAssertGreaterThan(restored.editRevision, before)
    }
}
