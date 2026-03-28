//
//  ImageUpscaleRestrictionIntegrationTests.swift
//  GLogoTests
//
//  概要:
//  画像の高画質化を1回だけに制限する仕様が、履歴操作とガード条件で崩れないことを検証する結合テスト。
//

import XCTest
import UIKit
@testable import GLogo

/// 高画質化の再実行制限を検証する結合テスト
final class ImageUpscaleRestrictionIntegrationTests: XCTestCase {

    /// 高画質化適用後にUndo/Redoで適用済み状態が復元されることを検証
    @MainActor
    func testApplyUpscaledImageResult_UndoRedo_RestoresUpscaleRestriction() throws {
        let project = LogoProject(name: "upscale-restriction", canvasSize: CGSize(width: 1080, height: 1920))
        let viewModel = EditorViewModel(project: project)
        let imageElement = try makeImageElement(color: .white)

        viewModel.addElement(imageElement)
        XCTAssertFalse(imageElement.hasAppliedUpscale)

        viewModel.applyUpscaledImageResult(makeImage(color: .black), to: imageElement)

        let upscaledElement = try XCTUnwrap(project.elements.first as? ImageElement)
        XCTAssertTrue(upscaledElement.hasAppliedUpscale)

        viewModel.undo()
        let revertedElement = try XCTUnwrap(project.elements.first as? ImageElement)
        XCTAssertFalse(revertedElement.hasAppliedUpscale)

        viewModel.redo()
        let redoElement = try XCTUnwrap(project.elements.first as? ImageElement)
        XCTAssertTrue(redoElement.hasAppliedUpscale)
    }

    /// 既に高画質化済みの画像に対しては処理開始しないことを検証
    @MainActor
    func testRequestImageUpscale_WhenAlreadyApplied_DoesNotStartProcessing() throws {
        let project = LogoProject(name: "upscale-restriction-guard", canvasSize: CGSize(width: 1080, height: 1920))
        let viewModel = EditorViewModel(project: project)
        let imageElement = try makeImageElement(color: .white)
        imageElement.hasAppliedUpscale = true

        viewModel.requestImageUpscale(for: imageElement)

        XCTAssertFalse(viewModel.isProcessingUpscale)
        XCTAssertNil(viewModel.lastUpscaleErrorMessage)
    }

    // MARK: - Helpers

    /// テスト用の画像要素を生成
    /// - Parameters:
    ///   - color: 画像色
    /// - Returns: 生成したImageElement
    private func makeImageElement(color: UIColor) throws -> ImageElement {
        let data = try XCTUnwrap(makeImage(color: color).pngData())
        return ImageElement(imageData: data, importOrder: 0)
    }

    /// 単色画像を生成
    /// - Parameters:
    ///   - color: 画像色
    /// - Returns: 生成したUIImage
    private func makeImage(color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 64, height: 64)))
        }
    }
}
