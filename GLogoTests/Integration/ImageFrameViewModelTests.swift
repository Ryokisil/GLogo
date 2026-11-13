// フレームの選択境界、履歴、メタデータと画面通知を検証する。

import Combine
import CryptoKit
import UIKit
import XCTest
@testable import GLogo

final class ImageFrameViewModelTests: XCTestCase {
    @MainActor
    private func makeImage() throws -> ImageElement {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        return ImageElementFactory().makeElement(imageData: try XCTUnwrap(image.pngData()))
    }

    @MainActor
    private func makeContext() throws -> (EditorViewModel, ImageFrameViewModel, ImageElement) {
        let image = try makeImage()
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project)
        editor.selectElement(image)
        let frame = ImageFrameViewModel(
            editor: editor.imageEdits,
            refresh: editor.dependencies.makeImageRenderRefresh(),
            renderSessions: editor.managedRenderSessions,
            metadataEdits: ImageMetadataEditUseCase(store: editor.dependencies.metadataStore),
            selection: editor.$selectedElement.eraseToAnyPublisher()
        )
        return (editor, frame, image)
    }

    @MainActor
    func test_adjustment_commit_preservesUndoRedo() throws {
        for adjustment in ImageFrameViewModel.Adjustment.allCases {
            let (editor, frame, image) = try makeContext()
            let keyPath: ReferenceWritableKeyPath<ImageElement, CGFloat> = adjustment == .frameWidth
                ? \.frameWidth : \.cornerRadius
            let initial = image[keyPath: keyPath]

            frame.beginAdjustmentEditing(adjustment)
            frame.updateAdjustment(adjustment, value: initial + 2)
            // 同じ画像の通知や begin の再送で、最初の開始値を失わない。
            frame.beginAdjustmentEditing(adjustment)
            frame.updateAdjustment(adjustment, value: initial + 4)
            XCTAssertFalse(editor.canUndo)
            frame.commitAdjustmentEditing(adjustment)
            frame.commitAdjustmentEditing(adjustment)
            XCTAssertEqual(editor.getHistoryDescriptions().count, 1)

            editor.undo()
            XCTAssertEqual(image[keyPath: keyPath], initial)
            editor.redo()
            XCTAssertEqual(image[keyPath: keyPath], initial + 4)
            XCTAssertTrue(frame.imageElement === image)
        }
    }

    @MainActor
    func test_styleChange_recordsSingleHistory() throws {
        let (editor, frame, image) = try makeContext()
        let oldStyle = image.frameStyle
        let oldColor = image.frameColor.rgbaHexString
        let oldShow = image.showFrame
        frame.updateFrameStyle(.double)
        XCTAssertTrue(image.showFrame)
        XCTAssertEqual(image.frameStyle, .double)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        frame.updateFrameStyle(.double)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)

        editor.undo()
        XCTAssertEqual(image.frameStyle, oldStyle)
        XCTAssertEqual(image.frameColor.rgbaHexString, oldColor)
        XCTAssertEqual(image.showFrame, oldShow)
        editor.redo()
        XCTAssertEqual(frame.imageElement?.frameStyle, .double)
        XCTAssertTrue(image.showFrame)
    }

    @MainActor
    func test_selectionChange_discardsAllStartValues() throws {
        let (editor, frame, first) = try makeContext()
        let second = try makeImage()
        second.frameColor = .blue
        second.frameWidth = 20
        second.cornerRadius = 40
        editor.project.addElement(second)

        frame.beginFrameColorEditing()
        frame.previewFrameColor(.red)
        frame.beginAdjustmentEditing(.frameWidth)
        frame.updateAdjustment(.frameWidth, value: 12)
        frame.beginAdjustmentEditing(.cornerRadius)
        frame.updateAdjustment(.cornerRadius, value: 30)

        // RunLoop を進めずに選択・確定し、旧画像の開始値が使われないことを確認する。
        editor.selectElement(second)
        XCTAssertTrue(frame.imageElement === second)
        frame.commitFrameColorEditing()
        frame.commitAdjustmentEditing(.frameWidth)
        frame.commitAdjustmentEditing(.cornerRadius)
        XCTAssertFalse(editor.canUndo)
        XCTAssertEqual(second.frameColor.rgbaHexString, UIColor.blue.rgbaHexString)
        XCTAssertEqual(second.frameWidth, 20)
        XCTAssertEqual(second.cornerRadius, 40)

        editor.clearSelection()
        editor.selectElement(first)
        frame.commitFrameColorEditing()
        frame.commitAdjustmentEditing(.frameWidth)
        frame.commitAdjustmentEditing(.cornerRadius)
        XCTAssertFalse(editor.canUndo)
    }

    @MainActor
    func test_nonImageSelection_ignoresFrameEdits() throws {
        let (editor, frame, image) = try makeContext()
        editor.addTextElement(position: .zero)
        XCTAssertNil(frame.imageElement)
        let historyCount = editor.getHistoryDescriptions().count
        let initialWidth = image.frameWidth
        frame.updateFrameStyle(.double)
        frame.updateShowFrame(true)
        frame.updateFrameColor(.red)
        frame.updateRoundedCorners(true, radius: 30)
        frame.beginFrameColorEditing()
        frame.previewFrameColor(.blue)
        frame.commitFrameColorEditing()
        frame.beginAdjustmentEditing(.frameWidth)
        frame.updateAdjustment(.frameWidth, value: 20)
        frame.commitAdjustmentEditing(.frameWidth)
        XCTAssertEqual(editor.getHistoryDescriptions().count, historyCount)
        XCTAssertEqual(image.frameWidth, initialWidth)
        editor.clearSelection()
        XCTAssertNil(frame.imageElement)
    }

    @MainActor
    func test_frameChanges_notifyPanel() throws {
        let (editor, frame, image) = try makeContext()
        var notifications = 0
        let observation = frame.objectWillChange.sink { notifications += 1 }
        frame.beginFrameColorEditing()
        frame.previewFrameColor(.red)
        XCTAssertGreaterThan(notifications, 0)
        frame.commitFrameColorEditing()
        notifications = 0
        editor.undo()
        XCTAssertGreaterThan(notifications, 0)
        notifications = 0
        editor.redo()
        XCTAssertGreaterThan(notifications, 0)
        XCTAssertEqual(frame.imageElement?.frameColor.rgbaHexString, UIColor.red.rgbaHexString)

        notifications = 0
        frame.beginAdjustmentEditing(.frameWidth)
        frame.updateAdjustment(.frameWidth, value: image.frameWidth + 2)
        XCTAssertGreaterThan(notifications, 0)
        frame.commitAdjustmentEditing(.frameWidth)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_frameRevert_undoRestoresEdits() throws {
        let (editor, frame, image) = try makeContext()
        let initialWidth = image.frameWidth
        frame.updateFrameStyle(.double)
        frame.updateRoundedCorners(true, radius: 30)
        frame.beginAdjustmentEditing(.frameWidth)
        frame.updateAdjustment(.frameWidth, value: 18)
        frame.commitAdjustmentEditing(.frameWidth)

        editor.revertSelectedImageToInitialState()
        XCTAssertEqual(frame.imageElement?.frameWidth, initialWidth)
        editor.undo()
        XCTAssertEqual(frame.imageElement?.frameWidth, 18)
        XCTAssertEqual(frame.imageElement?.cornerRadius, 30)
        XCTAssertEqual(frame.imageElement?.frameStyle, .double)
    }

    @MainActor
    func test_frameEdits_recordMetadataOnCommit() throws {
        let (editor, frame, image) = try makeContext()
        let identifier = "image_frame_test_\(UUID().uuidString)"
        image.originalImageIdentifier = identifier
        // テスト専用の識別子に対応する保存ファイルだけを片付ける。
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let storageKey = SHA256.hash(data: Data(identifier.utf8)).map { String(format: "%02x", $0) }.joined()
        defer {
            for path in ["GLogo/Metadata/metadata_\(storageKey).json", "GLogo/History/history_\(storageKey).json"] {
                try? FileManager.default.removeItem(at: documents.appendingPathComponent(path))
            }
        }

        frame.beginFrameColorEditing()
        frame.previewFrameColor(.red)
        frame.beginAdjustmentEditing(.frameWidth)
        frame.updateAdjustment(.frameWidth, value: 18)
        XCTAssertFalse(ImageMetadataManager.shared.hasEditHistory(for: identifier))
        frame.commitFrameColorEditing()
        frame.commitAdjustmentEditing(.frameWidth)
        frame.updateRoundedCorners(true, radius: 30)
        frame.updateFrameStyle(.double)
        frame.updateShowFrame(false)

        let metadata = try XCTUnwrap(image.metadata?.additionalMetadata)
        XCTAssertEqual(metadata["frameColor"], UIColor.red.rgbaHexString)
        XCTAssertEqual(metadata["frameWidth"], "18.0")
        XCTAssertEqual(metadata["cornerRadius"], "30.0")
        XCTAssertEqual(metadata["roundedCorners"], "true")
        XCTAssertEqual(metadata["frameStyle"], ImageFrameStyle.double.rawValue)
        XCTAssertEqual(metadata["showFrame"], "false")
        let operations = ImageMetadataManager.shared.getEditHistory(for: identifier)
        XCTAssertEqual(operations.filter { $0.fieldKey == "frameColor" }.count, 1)
        XCTAssertEqual(operations.filter { $0.fieldKey == "frameWidth" }.count, 1)
        withExtendedLifetime(editor) {}
    }

    @MainActor
    func test_frameLifetime_doesNotRetainOwners() {
        var editor: EditorViewModel? = EditorViewModel()
        var parent: ElementViewModel? = ElementViewModel(editorViewModel: editor!)
        var frame: ImageFrameViewModel? = parent!.imageFrame
        weak var weakEditor = editor
        weak var weakParent = parent
        weak var weakFrame = frame
        parent = nil
        editor = nil
        XCTAssertNil(weakParent)
        XCTAssertNil(weakEditor)
        XCTAssertNotNil(weakFrame)
        frame = nil
        XCTAssertNil(weakFrame)
    }
}
