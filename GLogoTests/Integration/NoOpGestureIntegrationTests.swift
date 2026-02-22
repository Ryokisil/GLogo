//
//  NoOpGestureIntegrationTests.swift
//  GLogoTests
//
//  概要:
//  実質ゼロ移動のジェスチャー入力（タップ誤検知）が
//  編集状態や変更フラグに副作用を与えないことを検証する。
//

import XCTest
import UIKit
@testable import GLogo

/// ゼロ移動ジェスチャーの副作用を検証する結合テスト
final class NoOpGestureIntegrationTests: XCTestCase {

    /// 実質ゼロ移動の開始/終了イベントでは project modified が立たないことを検証
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testNoOpMoveGesture_DoesNotMarkProjectModified() throws {
        let project = LogoProject(name: "noop-gesture", canvasSize: CGSize(width: 1080, height: 1920))
        let imageData = try XCTUnwrap(makeSolidImage(color: .systemTeal, size: CGSize(width: 64, height: 64)).pngData())
        let imageElement = ImageElement(imageData: imageData, importOrder: 0)
        project.addElement(imageElement)

        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        editorViewModel.selectElement(imageElement)
        // @Published伝播を1ターン待機
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))

        XCTAssertFalse(editorViewModel.isProjectModified, "初期状態では未変更であるべき")

        // タップ誤検知相当（translationがゼロ）
        elementViewModel.applyGestureTransform(
            translation: .zero,
            scale: nil,
            rotation: nil,
            ended: false
        )
        elementViewModel.applyGestureTransform(
            translation: nil,
            scale: nil,
            rotation: nil,
            ended: true
        )

        XCTAssertFalse(
            editorViewModel.isProjectModified,
            "ゼロ移動ジェスチャーで変更フラグが立つべきではない"
        )
    }

    /// 調整変更の有無でドラッグ中プレビュー経路の切替条件が変わることを検証
    /// - Parameters: なし
    /// - Returns: なし
    func testManipulationPreviewSwitching_FollowsAdjustmentState() throws {
        let imageData = try XCTUnwrap(makeSolidImage(color: .systemBlue, size: CGSize(width: 32, height: 32)).pngData())
        let imageElement = ImageElement(imageData: imageData, importOrder: 0)

        XCTAssertTrue(
            imageElement.shouldUseInstantPreviewForManipulation,
            "デフォルト状態は即時プレビュー経路を利用するべき"
        )

        imageElement.saturationAdjustment = 1.2
        XCTAssertFalse(
            imageElement.shouldUseInstantPreviewForManipulation,
            "調整変更ありでは即時プレビュー経路を避けるべき"
        )
    }

    /// 画像調整キーごとの編集中プレビュー方針が想定どおりであることを検証
    /// - Parameters: なし
    /// - Returns: なし
    func testImageAdjustmentPreviewPolicy_ColorAndBlur_AreRealtimePreview() throws {
        let saturation = try XCTUnwrap(ImageAdjustmentDescriptor.all[.saturation])
        let temperature = try XCTUnwrap(ImageAdjustmentDescriptor.all[.temperature])
        let gaussianBlur = try XCTUnwrap(ImageAdjustmentDescriptor.all[.gaussianBlur])
        let backgroundBlur = try XCTUnwrap(ImageAdjustmentDescriptor.all[.backgroundBlurRadius])

        XCTAssertTrue(saturation.usesInstantPreviewWhileEditing, "彩度はリアルタイムプレビューを維持するべき")
        XCTAssertTrue(temperature.usesInstantPreviewWhileEditing, "色温度はリアルタイムプレビューを維持するべき")
        XCTAssertTrue(gaussianBlur.usesInstantPreviewWhileEditing, "ガウシアンぼかしは編集中プレビューを許可するべき")
        XCTAssertTrue(backgroundBlur.usesInstantPreviewWhileEditing, "背景ぼかしは編集中プレビューを許可するべき")
    }

    // MARK: - Helpers

    /// 単色画像を生成
    /// - Parameters:
    ///   - color: 塗りつぶし色
    ///   - size: 画像サイズ
    /// - Returns: 生成したUIImage
    private func makeSolidImage(color: UIColor, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
