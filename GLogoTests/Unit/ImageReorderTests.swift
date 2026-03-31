//
//  ImageReorderTests.swift
//  GLogoTests
//
//  概要:
//  画像一覧レールの並べ替えロジックとイベントソーシングのテスト。
//

import XCTest
import UIKit
@testable import GLogo

@MainActor
final class ImageReorderTests: XCTestCase {

    // MARK: - Helpers

    private func makeImage(size: CGSize = CGSize(width: 100, height: 100)) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData() ?? Data()
    }

    private func makeViewModel(imageCount: Int) -> EditorViewModel {
        let vm = EditorViewModel()
        for _ in 0..<imageCount {
            let element = ImageElement(imageData: makeImage())
            vm.addElement(element)
        }
        return vm
    }

    // MARK: - imageElements の順序確認

    func testImageElements_sortedByZIndexDescending() {
        let vm = makeViewModel(imageCount: 3)
        let images = vm.imageElements

        // 降順（前面→背面）であること
        for i in 0..<(images.count - 1) {
            XCTAssertGreaterThanOrEqual(images[i].zIndex, images[i + 1].zIndex,
                "imageElements は zIndex 降順であるべき")
        }
    }

    // MARK: - 並べ替えテスト

    func testReorderImageElements_changesZIndex() {
        let vm = makeViewModel(imageCount: 3)
        let before = vm.imageElements
        let topId = before[0].id // 最前面

        // 最前面を最背面に移動 (index 0 → index 3 は末尾)
        vm.reorderImageElements(from: IndexSet(integer: 0), to: 3)

        let after = vm.imageElements
        // 最前面だった要素が最背面に移動
        XCTAssertEqual(after.last?.id, topId, "最前面の画像が最背面に移動するべき")
    }

    func testReorderImageElement_movesDraggedImageAfterLowerTarget() {
        let vm = makeViewModel(imageCount: 4)
        let before = vm.imageElements
        let draggedId = before[0].id
        let targetId = before[2].id

        vm.reorderImageElement(draggedImageID: draggedId, to: targetId)

        let after = vm.imageElements.map(\.id)
        XCTAssertEqual(after, [before[1].id, before[2].id, draggedId, before[3].id],
            "上から下へ移動した場合はターゲットの後ろへ入るべき")
    }

    func testReorderImageElement_movesDraggedImageBeforeUpperTarget() {
        let vm = makeViewModel(imageCount: 4)
        let before = vm.imageElements
        let draggedId = before[3].id
        let targetId = before[1].id

        vm.reorderImageElement(draggedImageID: draggedId, to: targetId)

        let after = vm.imageElements.map(\.id)
        XCTAssertEqual(after, [before[0].id, draggedId, before[1].id, before[2].id],
            "下から上へ移動した場合はターゲットの前へ入るべき")
    }

    // MARK: - base image 不変テスト

    func testReorderImageElements_doesNotChangeBaseRole() {
        let vm = makeViewModel(imageCount: 3)

        // 最初の画像をベースに設定
        if let first = vm.project.elements.compactMap({ $0 as? ImageElement }).first {
            vm.toggleImageRole(first)
        }

        let baseId = vm.project.elements
            .compactMap { $0 as? ImageElement }
            .first { $0.isBaseImage }?.id

        XCTAssertNotNil(baseId, "ベース画像が存在するべき")

        // 並べ替え実行
        vm.reorderImageElements(from: IndexSet(integer: 0), to: 2)

        // ベース画像の role が変わっていないこと
        let baseAfter = vm.project.elements
            .compactMap { $0 as? ImageElement }
            .first { $0.id == baseId }
        XCTAssertEqual(baseAfter?.imageRole, .base, "並べ替えでベース画像の role が変わってはいけない")
    }

    // MARK: - text/shape 優先度帯の不変テスト

    func testReorderImageElements_doesNotAffectTextShapeZIndex() {
        let vm = EditorViewModel()

        // 画像2枚追加
        let img1 = ImageElement(imageData: makeImage())
        let img2 = ImageElement(imageData: makeImage())
        vm.addElement(img1)
        vm.addElement(img2)

        // テキスト要素追加
        vm.addTextElement(text: "Hello", position: .zero)
        let textElement = vm.project.elements.first { $0 is TextElement }
        let textZIndexBefore = textElement?.zIndex

        // 画像を並べ替え
        vm.reorderImageElements(from: IndexSet(integer: 0), to: 2)

        // テキストのzIndexが変わっていないこと
        XCTAssertEqual(textElement?.zIndex, textZIndexBefore,
            "画像並べ替えでテキスト要素の zIndex が変わってはいけない")
    }

    // MARK: - undo/redo テスト

    func testReorderImageElements_undoRestoresOrder() {
        let vm = makeViewModel(imageCount: 3)
        let originalOrder = vm.imageElements.map(\.id)

        // 並べ替え
        vm.reorderImageElements(from: IndexSet(integer: 0), to: 3)
        let reorderedOrder = vm.imageElements.map(\.id)
        XCTAssertNotEqual(originalOrder, reorderedOrder, "並べ替え後は順序が変わるべき")

        // undo
        vm.undo()
        let undoneOrder = vm.imageElements.map(\.id)
        XCTAssertEqual(originalOrder, undoneOrder, "undo 後は元の順序に戻るべき")

        // redo
        vm.redo()
        let redoneOrder = vm.imageElements.map(\.id)
        XCTAssertEqual(reorderedOrder, redoneOrder, "redo 後は並べ替え後の順序に戻るべき")
    }

    // MARK: - ImageOrderChangedEvent 直接テスト

    func testImageOrderChangedEvent_applyAndRevert() {
        let project = LogoProject()
        let img1 = ImageElement(imageData: makeImage())
        img1.zIndex = 110
        let img2 = ImageElement(imageData: makeImage())
        img2.zIndex = 111

        project.elements.append(img1)
        project.elements.append(img2)

        let event = ImageOrderChangedEvent(changes: [
            (elementId: img1.id, oldZIndex: 110, newZIndex: 111),
            (elementId: img2.id, oldZIndex: 111, newZIndex: 110),
        ])

        event.apply(to: project)
        XCTAssertEqual(img1.zIndex, 111)
        XCTAssertEqual(img2.zIndex, 110)

        event.revert(from: project)
        XCTAssertEqual(img1.zIndex, 110)
        XCTAssertEqual(img2.zIndex, 111)
    }
}
