// インポート境界の入力、追加・選択・履歴・カメラ通知と、失敗時の状態保持を検証する。

import Combine
import UIKit
import XCTest
@testable import GLogo

final class EditorImageImportIntegrationTests: XCTestCase {
    @MainActor
    func test_importEntries_forwardSourceAndCurrentViewport() throws {
        let importer = ImporterSpy()
        var viewport = CGSize(width: 320, height: 640)
        let project = LogoProject(canvasSize: CGSize(width: 600, height: 400))
        let editor = EditorViewModel(project: project, imageImporter: importer, viewportSizeProvider: { viewport })
        let image = snapshotImage(.red)
        let data = try XCTUnwrap(image.pngData())
        editor.addImageElement(imageData: data, position: CGPoint(x: 99, y: 88), assetIdentifier: "original")
        viewport = CGSize(width: 640, height: 320)
        editor.addCroppedImageElement(image: image, assetIdentifier: "cropped")

        XCTAssertEqual(importer.calls.count, 2)
        let first = try XCTUnwrap(importer.calls.first)
        let second = try XCTUnwrap(importer.calls.last)
        guard case .imageData(let receivedData) = first.source,
              case .uiImage(let receivedImage) = second.source else {
            return XCTFail("元データとクロップ済み画像の入力形式を保つ")
        }
        XCTAssertEqual(receivedData, data)
        XCTAssertTrue(receivedImage === image)
        XCTAssertTrue(first.project === project)
        XCTAssertTrue(second.project === project)
        XCTAssertEqual(first.viewportSize, CGSize(width: 320, height: 640))
        XCTAssertEqual(second.viewportSize, viewport)
        XCTAssertNil(first.canvasSize)
        XCTAssertEqual(second.canvasSize, project.canvasSize)
        XCTAssertEqual(first.assetIdentifier, "original")
        XCTAssertEqual(second.assetIdentifier, "cropped")
    }

    @MainActor
    func test_importSuccess_preservesSelectionHistoryAndCamera() throws {
        for cropped in [false, true] {
            let element = ImageElementFactory().makeElement(imageData: snapshotImage(.blue).pngData()!)
            element.position = CGPoint(x: 20, y: 30)
            element.size = CGSize(width: 80, height: 40)
            let importer = ImporterSpy(result: ImageImportResult(element: element, assetIdentifier: nil))
            let editor = EditorViewModel(imageImporter: importer)
            let panel = ElementViewModel(editorViewModel: editor)
            var centers: [CGPoint] = []
            let observation = NotificationCenter.default.publisher(for: Notification.Name("CenterCameraOnPoint"))
                .sink { notification in
                    if let point = notification.object as? CGPoint { centers.append(point) }
                }
            if cropped {
                editor.addCroppedImageElement(image: snapshotImage(.red))
            } else {
                editor.addImageElement(imageData: Data([1]), position: .zero)
            }
            XCTAssertTrue(editor.project.elements.first === element)
            XCTAssertTrue(editor.selectedElement === element)
            XCTAssertTrue(panel.imageElement === element)
            XCTAssertEqual(element.zIndex, ElementPriority.image.rawValue)
            XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
            XCTAssertTrue(editor.isProjectModified)
            XCTAssertEqual(centers, [CGPoint(x: 60, y: 50)])
            editor.undo()
            XCTAssertTrue(editor.project.elements.isEmpty)
            XCTAssertNil(editor.selectedElement)
            editor.redo()
            XCTAssertTrue(editor.project.elements.first === element)
            XCTAssertFalse(editor.canRedo)
            XCTAssertEqual(centers.count, 1, "履歴移動ではインポート時のカメラ通知を再送しない")
            withExtendedLifetime(observation) {}
        }
    }

    @MainActor
    func test_importFailure_preservesProjectAndRedo() {
        let importer = ImporterSpy()
        let text = TextElement(text: "Original")
        let project = LogoProject()
        project.addElement(text)
        let editor = EditorViewModel(project: project, imageImporter: importer)
        editor.selectElement(text)
        editor.updateProjectName("Changed")
        editor.undo()
        let history = editor.getHistoryDescriptions()
        let modified = editor.isProjectModified
        var cameraNotifications = 0
        let observation = NotificationCenter.default.publisher(for: Notification.Name("CenterCameraOnPoint"))
            .sink { _ in cameraNotifications += 1 }
        editor.addImageElement(imageData: Data(), position: .zero)
        editor.addCroppedImageElement(image: UIImage())
        XCTAssertEqual(importer.calls.count, 2)
        XCTAssertEqual(project.elements.map(\.id), [text.id])
        XCTAssertTrue(editor.selectedElement === text)
        XCTAssertEqual(editor.getHistoryDescriptions(), history)
        XCTAssertEqual(editor.isProjectModified, modified)
        XCTAssertTrue(editor.canRedo)
        XCTAssertEqual(cameraNotifications, 0)
        editor.redo()
        XCTAssertEqual(project.name, "Changed")
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_defaultImporter_preservesRolesAndPlacement() throws {
        let project = LogoProject(canvasSize: CGSize(width: 600, height: 400))
        project.addElement(TextElement(text: "Not an image"))
        let viewport = CGSize(width: 320, height: 640)
        let editor = EditorViewModel(project: project, viewportSizeProvider: { viewport })
        let image = snapshotImage(.red)
        editor.addImageElement(imageData: try XCTUnwrap(image.pngData()), position: .zero, assetIdentifier: "first")
        let first = try XCTUnwrap(editor.selectedImageElement)
        editor.addCroppedImageElement(image: image, assetIdentifier: "second")
        let second = try XCTUnwrap(editor.selectedImageElement)
        XCTAssertEqual(first.originalImportOrder, 1)
        XCTAssertEqual(second.originalImportOrder, 2)
        XCTAssertEqual(first.imageRole, .base)
        XCTAssertEqual(second.imageRole, .overlay)
        XCTAssertEqual(first.originalImageIdentifier, "first")
        XCTAssertEqual(second.originalImageIdentifier, "second")
        XCTAssertEqual(first.zIndex, 100)
        XCTAssertEqual(second.zIndex, 101)
        for element in [first, second] {
            XCTAssertNotNil(editor.sessionStore.originalImage(of: element))
            XCTAssertEqual(element.position.x + element.size.width / 2, 160, accuracy: 0.001)
            XCTAssertEqual(element.position.y + element.size.height / 2, 160, accuracy: 0.001)
        }
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2)
        editor.undo()
        XCTAssertEqual(project.elements.compactMap { $0 as? ImageElement }.map(\.id), [first.id])
        editor.redo()
        XCTAssertEqual(project.elements.compactMap { $0 as? ImageElement }.map(\.id), [first.id, second.id])
    }
}

/// 同期のインポート呼び出しだけを記録し、生成結果を制御する。
private final class ImporterSpy: ImageImporting {
    struct Call {
        let source: ImageImportSource
        let project: LogoProject
        let viewportSize: CGSize
        let assetIdentifier: String?
        let canvasSize: CGSize?
    }
    private(set) var calls: [Call] = []
    private let result: ImageImportResult?

    init(result: ImageImportResult? = nil) { self.result = result }

    func importImage(source: ImageImportSource, project: LogoProject, viewportSize: CGSize,
                     assetIdentifier: String?, canvasSize: CGSize?) -> ImageImportResult? {
        calls.append(Call(source: source, project: project, viewportSize: viewportSize,
                          assetIdentifier: assetIdentifier, canvasSize: canvasSize))
        return result
    }
}
