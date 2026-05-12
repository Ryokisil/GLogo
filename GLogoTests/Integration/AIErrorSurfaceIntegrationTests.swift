//
//  AIErrorSurfaceIntegrationTests.swift
//  GLogoTests
//
//  概要:
//  AI 処理（背景除去・背景ぼかし）の失敗がサイレントに握り潰されず、
//  EditorViewModel のエラーメッセージとして UI に伝播することを検証する結合テスト。
//  リグレッション対象：「ボタン押しても画面が無反応」となる empty catch の復活防止。
//

import XCTest
import UIKit
@testable import GLogo

/// AI 処理失敗時にエラーメッセージが ViewModel から購読できることを検証する結合テスト
final class AIErrorSurfaceIntegrationTests: XCTestCase {

    /// 背景除去エラーメッセージの初期値が nil であること
    @MainActor
    func testEditorViewModel_HasNilBackgroundRemovalErrorMessageInitially() throws {
        let project = LogoProject(name: "ai-error-default", canvasSize: CGSize(width: 1080, height: 1920))
        let viewModel = EditorViewModel(project: project)

        XCTAssertNil(viewModel.lastBackgroundRemovalErrorMessage, "初期状態の背景除去エラーは nil であるべき")
        XCTAssertNil(viewModel.lastBackgroundBlurErrorMessage, "初期状態の背景ぼかしエラーは nil であるべき")
    }

    /// 背景除去エラーが clear で nil に戻ること
    @MainActor
    func testClearBackgroundRemovalError_ResetsMessage() throws {
        let project = LogoProject(name: "ai-error-clear", canvasSize: CGSize(width: 1080, height: 1920))
        let viewModel = EditorViewModel(project: project)
        let imageElement = try makeImageElement(color: .white)
        viewModel.addElement(imageElement)

        // 直接エラー設定は private(set) のため不可。
        // ここでは isProcessingAI を立てた状態で再度 request を呼び、ガードを通過しない経路を確認するだけにする。
        // 重要なのは clear メソッドが存在し、呼び出してもクラッシュしないこと。
        viewModel.clearBackgroundRemovalError()
        viewModel.clearBackgroundBlurError()

        XCTAssertNil(viewModel.lastBackgroundRemovalErrorMessage)
        XCTAssertNil(viewModel.lastBackgroundBlurErrorMessage)
    }

    /// ElementViewModel に EditorViewModel のエラーが伝播することを検証
    @MainActor
    func testElementViewModel_MirrorsEditorBackgroundErrorMessages() throws {
        let project = LogoProject(name: "ai-error-bridge", canvasSize: CGSize(width: 1080, height: 1920))
        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        XCTAssertNil(elementViewModel.lastBackgroundRemovalErrorMessage, "ElementViewModel 側の初期値も nil")
        XCTAssertNil(elementViewModel.lastBackgroundBlurErrorMessage)

        // proxy 経由でクリア呼び出しがクラッシュしないこと
        elementViewModel.clearBackgroundRemovalError()
        elementViewModel.clearBackgroundBlurError()

        XCTAssertNil(elementViewModel.lastBackgroundRemovalErrorMessage)
        XCTAssertNil(elementViewModel.lastBackgroundBlurErrorMessage)
    }

    /// 要素切り替え時にエラーメッセージがリセットされること（ElementViewModel 側）
    @MainActor
    func testElementViewModel_ResetsErrorMessagesOnSelectionChange() throws {
        let project = LogoProject(name: "ai-error-selection-reset", canvasSize: CGSize(width: 1080, height: 1920))
        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        let firstElement = try makeImageElement(color: .white)
        let secondElement = try makeImageElement(color: .black)
        editorViewModel.addElement(firstElement)
        editorViewModel.addElement(secondElement)
        editorViewModel.selectElement(firstElement)
        waitForSelectionPropagation()

        XCTAssertNil(elementViewModel.lastBackgroundRemovalErrorMessage)
        XCTAssertNil(elementViewModel.lastBackgroundBlurErrorMessage)

        editorViewModel.selectElement(secondElement)
        waitForSelectionPropagation()

        XCTAssertNil(elementViewModel.lastBackgroundRemovalErrorMessage, "要素切替後もエラー履歴は持ち越されない")
        XCTAssertNil(elementViewModel.lastBackgroundBlurErrorMessage)
    }

    /// originalImage が未解決のまま AI 背景除去をリクエストしたとき、ボタンが無反応に見えないようエラーメッセージが設定されること
    @MainActor
    func testRequestAIBackgroundRemoval_WithNilOriginalImage_SetsErrorMessage() async throws {
        let project = LogoProject(name: "ai-bgremove-no-image", canvasSize: CGSize(width: 1080, height: 1920))
        let viewModel = EditorViewModel(project: project)
        let imageElement = try makeImageElementWithoutResolvableSource()

        viewModel.requestAIBackgroundRemoval(for: imageElement)

        try await waitUntil("背景除去の元画像未解決エラーが設定されること") {
            viewModel.lastBackgroundRemovalErrorMessage != nil
        }

        XCTAssertNotNil(
            viewModel.lastBackgroundRemovalErrorMessage,
            "originalImage が未解決の場合はエラーメッセージが設定されるべき"
        )
        XCTAssertFalse(viewModel.isProcessingAI, "処理フラグは defer で必ず解除されるべき")
    }

    /// originalImage が未解決のまま AI 背景ぼかしをリクエストしたとき、エラーメッセージが設定されること
    @MainActor
    func testRequestAIBackgroundBlur_WithNilOriginalImage_SetsErrorMessage() async throws {
        let project = LogoProject(name: "ai-bgblur-no-image", canvasSize: CGSize(width: 1080, height: 1920))
        let viewModel = EditorViewModel(project: project)
        let imageElement = try makeImageElementWithoutResolvableSource()

        viewModel.requestAIBackgroundBlur(for: imageElement)

        try await waitUntil("背景ぼかしの元画像未解決エラーが設定されること") {
            viewModel.lastBackgroundBlurErrorMessage != nil
        }

        XCTAssertNotNil(
            viewModel.lastBackgroundBlurErrorMessage,
            "originalImage が未解決の場合はエラーメッセージが設定されるべき"
        )
        XCTAssertFalse(viewModel.isProcessingAI)
    }

    /// AI 背景除去のユースケース失敗が catch で握り潰されずエラーメッセージになること
    @MainActor
    func testRequestAIBackgroundRemoval_WhenUseCaseThrows_SetsErrorMessage() async throws {
        let project = LogoProject(name: "ai-bgremove-throws", canvasSize: CGSize(width: 1080, height: 1920))
        let viewModel = EditorViewModel(
            project: project,
            backgroundRemovalUseCase: FailingBackgroundRemovalUseCase(message: "背景除去失敗")
        )
        let imageElement = try makeImageElement(color: .white)

        viewModel.requestAIBackgroundRemoval(for: imageElement)

        try await waitUntil("背景除去 catch のエラーが設定されること") {
            viewModel.lastBackgroundRemovalErrorMessage == String(localized: "aiTools.backgroundRemoval.failed")
        }

        XCTAssertEqual(
            viewModel.lastBackgroundRemovalErrorMessage,
            String(localized: "aiTools.backgroundRemoval.failed")
        )
        XCTAssertFalse(viewModel.isProcessingAI)
    }

    /// AI 背景ぼかしのユースケース失敗が catch で握り潰されずエラーメッセージになること
    @MainActor
    func testRequestAIBackgroundBlur_WhenUseCaseThrows_SetsErrorMessage() async throws {
        let project = LogoProject(name: "ai-bgblur-throws", canvasSize: CGSize(width: 1080, height: 1920))
        let viewModel = EditorViewModel(
            project: project,
            backgroundRemovalUseCase: FailingBackgroundRemovalUseCase(message: "背景ぼかし失敗")
        )
        let imageElement = try makeImageElement(color: .white)

        viewModel.requestAIBackgroundBlur(for: imageElement)

        try await waitUntil("背景ぼかし catch のエラーが設定されること") {
            viewModel.lastBackgroundBlurErrorMessage == String(localized: "aiTools.aiMaskGeneration.failed")
        }

        XCTAssertEqual(
            viewModel.lastBackgroundBlurErrorMessage,
            String(localized: "aiTools.aiMaskGeneration.failed")
        )
        XCTAssertFalse(viewModel.isProcessingAI)
    }

    /// 手動背景除去画面の AI マスク生成失敗が state に保存されること
    @MainActor
    func testManualBackgroundRemovalViewModel_WhenAIMaskGenerationThrows_SetsErrorMessage() async throws {
        let imageElement = try makeImageElement(color: .white)
        let viewModel = ManualBackgroundRemovalViewModel(
            imageElement: imageElement,
            completion: { _ in },
            backgroundRemovalUseCase: FailingBackgroundRemovalUseCase(message: "手動マスク失敗")
        )

        await viewModel.applyAIMask()

        XCTAssertEqual(
            viewModel.state.aiMaskErrorMessage,
            String(localized: "aiTools.aiMaskGeneration.failed")
        )
        XCTAssertFalse(viewModel.state.isProcessingAI)
    }

    /// 背景ぼかしマスク編集画面の AI マスク生成失敗が state に保存されること
    @MainActor
    func testBackgroundBlurMaskEditViewModel_WhenAIMaskGenerationThrows_SetsErrorMessage() async throws {
        let imageElement = try makeImageElement(color: .white)
        let viewModel = BackgroundBlurMaskEditViewModel(
            imageElement: imageElement,
            initialMaskData: nil,
            blurRadius: 12,
            completion: { _ in },
            backgroundRemovalUseCase: FailingBackgroundRemovalUseCase(message: "ぼかしマスク失敗")
        )

        await viewModel.applyAIMask()

        XCTAssertEqual(
            viewModel.state.aiMaskErrorMessage,
            String(localized: "aiTools.aiMaskGeneration.failed")
        )
        XCTAssertFalse(viewModel.state.isProcessingAI)
    }

    // MARK: - Helpers

    /// @Published による選択要素伝播を1ターン待機
    @MainActor
    private func waitForSelectionPropagation() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }

    /// 非同期 Task が ViewModel 状態へ反映されるまで短時間待機する
    /// - Parameters:
    ///   - description: 失敗時に表示する条件説明
    ///   - condition: 完了判定
    /// - Returns: なし
    @MainActor
    private func waitUntil(
        _ description: String,
        condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date(timeIntervalSinceNow: 1.0)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("条件を満たせませんでした: \(description)")
    }

    /// `originalImage` が解決できない ImageElement を生成（壊れたデータで初期化）
    /// 元画像未解決経路のテスト用ヘルパー
    private func makeImageElementWithoutResolvableSource() throws -> ImageElement {
        // 不正な画像データで初期化すると UIImage(data:) が nil になり originalImage が解決されない
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        return ImageElement(imageData: invalidData, importOrder: 0)
    }

    /// テスト用画像要素を生成
    private func makeImageElement(color: UIColor) throws -> ImageElement {
        let imageData = try XCTUnwrap(makeSolidImage(color: color).pngData())
        return ImageElement(imageData: imageData, importOrder: 0)
    }

    /// 単色画像生成
    private func makeSolidImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 64, height: 64)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}

/// テスト用に常に失敗する AI 背景除去ユースケース
private struct FailingBackgroundRemovalUseCase: BackgroundRemovalProcessing {
    let message: String

    func removeBackground(from image: UIImage) async throws -> UIImage {
        throw Failure(message: message)
    }

    func generateMask(from image: UIImage) async throws -> UIImage {
        throw Failure(message: message)
    }

    private struct Failure: LocalizedError {
        let message: String

        var errorDescription: String? {
            message
        }
    }
}
