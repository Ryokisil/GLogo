//
//  ImageUndoCacheInvalidationTests.swift
//  GLogoTests
//
//  概要:
//  画像調整のアンドゥ/リドゥで描画キャッシュが無効化されることを検証するテスト。
//  第19回から、失効はイベントの中ではなく、イベントが示す範囲で履歴が管理役に求めるため、履歴を通して確かめる。
//

import XCTest
import UIKit
import Combine
@testable import GLogo

/// 画像調整イベントのキャッシュ無効化を検証するテスト
final class ImageUndoCacheInvalidationTests: XCTestCase {
    /// 単色画像を生成する
    /// - Parameters:
    ///   - color: 生成する画像の色
    ///   - size: 生成する画像サイズ
    /// - Returns: 指定色で塗りつぶされたUIImage
    private func makeSolidImage(color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// テスト用プロジェクトと画像要素を作成する
    /// - Returns: LogoProjectとImageElementのタプル
    private func makeProjectWithImageElement() -> (LogoProject, ImageElement) {
        let baseImage = makeSolidImage(color: .red, size: CGSize(width: 4, height: 4))
        let imageData = baseImage.pngData() ?? Data()
        let element = ImageElementFactory().makeElement(imageData: imageData, importOrder: 0)
        let project = LogoProject(name: "テスト", canvasSize: CGSize(width: 100, height: 100))
        project.addElement(element)
        return (project, element)
    }

    /// テスト用プロジェクトと2つの画像要素を作成する
    /// - Returns: LogoProjectと2つのImageElementのタプル
    private func makeProjectWithTwoImageElements() -> (LogoProject, ImageElement, ImageElement) {
        let firstImage = makeSolidImage(color: .red, size: CGSize(width: 4, height: 4))
        let secondImage = makeSolidImage(color: .blue, size: CGSize(width: 4, height: 4))

        let firstData = firstImage.pngData() ?? Data()
        let secondData = secondImage.pngData() ?? Data()

        let first = ImageElementFactory().makeElement(imageData: firstData, importOrder: 0)
        let second = ImageElementFactory().makeElement(imageData: secondData, importOrder: 1)
        let project = LogoProject(name: "テスト", canvasSize: CGSize(width: 100, height: 100))
        project.addElement(first)
        project.addElement(second)
        return (project, first, second)
    }

    /// メインループを短時間回してCombine通知を反映させる
    /// - Parameters: なし
    /// - Returns: なし
    private func flushMainRunLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }

    /// 画像調整イベントを履歴で適用・Undo したとき、キャッシュが無効化されることを確認
    @MainActor
    func testAdjustmentEventsInvalidateCache() {
        let (project, element) = makeProjectWithImageElement()
        // 履歴に渡した管理役と同じインスタンスで、キャッシュを観察する。
        let store = ImageRenderSessionStore()
        let history = EditorHistory(project: project, renderSessions: store)
        let cachedImage = makeSolidImage(color: .blue, size: CGSize(width: 4, height: 4))

        XCTContext.runActivity(named: "彩度") { _ in
            let event = ImageSaturationChangedEvent(
                elementId: element.id,
                oldSaturation: 1.0,
                newSaturation: 2.0
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.saturationAdjustment, 2.0, accuracy: 0.0001)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.saturationAdjustment, 1.0, accuracy: 0.0001)
        }

        XCTContext.runActivity(named: "明るさ") { _ in
            let event = ImageBrightnessChangedEvent(
                elementId: element.id,
                oldBrightness: 0.0,
                newBrightness: 0.5
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.brightnessAdjustment, 0.5, accuracy: 0.0001)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.brightnessAdjustment, 0.0, accuracy: 0.0001)
        }

        XCTContext.runActivity(named: "コントラスト") { _ in
            let event = ImageContrastChangedEvent(
                elementId: element.id,
                oldContrast: 1.0,
                newContrast: 1.8
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.contrastAdjustment, 1.8, accuracy: 0.0001)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.contrastAdjustment, 1.0, accuracy: 0.0001)
        }

        XCTContext.runActivity(named: "ハイライト") { _ in
            let event = ImageHighlightsChangedEvent(
                elementId: element.id,
                oldHighlights: 0.0,
                newHighlights: 0.3
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.highlightsAdjustment, 0.3, accuracy: 0.0001)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.highlightsAdjustment, 0.0, accuracy: 0.0001)
        }

        XCTContext.runActivity(named: "シャドウ") { _ in
            let event = ImageShadowsChangedEvent(
                elementId: element.id,
                oldShadows: 0.0,
                newShadows: 0.4
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.shadowsAdjustment, 0.4, accuracy: 0.0001)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.shadowsAdjustment, 0.0, accuracy: 0.0001)
        }

        XCTContext.runActivity(named: "色相") { _ in
            let event = ImageHueChangedEvent(
                elementId: element.id,
                oldHue: 0.0,
                newHue: 30.0
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.hueAdjustment, 30.0, accuracy: 0.0001)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.hueAdjustment, 0.0, accuracy: 0.0001)
        }

        XCTContext.runActivity(named: "シャープネス") { _ in
            let event = ImageSharpnessChangedEvent(
                elementId: element.id,
                oldSharpness: 0.0,
                newSharpness: 0.8
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.sharpnessAdjustment, 0.8, accuracy: 0.0001)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.sharpnessAdjustment, 0.0, accuracy: 0.0001)
        }

        XCTContext.runActivity(named: "ガウシアンぼかし") { _ in
            let event = ImageGaussianBlurChangedEvent(
                elementId: element.id,
                oldRadius: 0.0,
                newRadius: 5.0
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.gaussianBlurRadius, 5.0, accuracy: 0.0001)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.gaussianBlurRadius, 0.0, accuracy: 0.0001)
        }
    }

    /// 装飾系イベントを履歴で適用・Undo したとき、キャッシュが無効化されることを確認
    @MainActor
    func testDecorationEventsInvalidateCache() {
        let (project, element) = makeProjectWithImageElement()
        // 履歴に渡した管理役と同じインスタンスで、キャッシュを観察する。
        let store = ImageRenderSessionStore()
        let history = EditorHistory(project: project, renderSessions: store)
        let cachedImage = makeSolidImage(color: .green, size: CGSize(width: 4, height: 4))

        XCTContext.runActivity(named: "ティント") { _ in
            let event = ImageTintColorChangedEvent(
                elementId: element.id,
                oldColor: .red,
                newColor: .blue,
                oldIntensity: 0.2,
                newIntensity: 0.7
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.tintColor, UIColor.blue)
            XCTAssertEqual(element.tintIntensity, 0.7, accuracy: 0.0001)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.tintColor, UIColor.red)
            XCTAssertEqual(element.tintIntensity, 0.2, accuracy: 0.0001)
        }

        XCTContext.runActivity(named: "フレーム表示") { _ in
            let event = ImageShowFrameChangedEvent(
                elementId: element.id,
                oldValue: false,
                newValue: true
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertTrue(element.showFrame)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertFalse(element.showFrame)
        }

        XCTContext.runActivity(named: "フレーム色") { _ in
            let event = ImageFrameColorChangedEvent(
                elementId: element.id,
                oldColor: .black,
                newColor: .white
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.frameColor, UIColor.white)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.frameColor, UIColor.black)
        }

        XCTContext.runActivity(named: "フレーム幅") { _ in
            let event = ImageFrameWidthChangedEvent(
                elementId: element.id,
                oldWidth: 1.0,
                newWidth: 3.0
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.frameWidth, 3.0, accuracy: 0.0001)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.frameWidth, 1.0, accuracy: 0.0001)
        }

        XCTContext.runActivity(named: "フレームスタイル") { _ in
            let event = ImageFrameStyleChangedEvent(
                elementId: element.id,
                oldStyle: .simple,
                newStyle: .film
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.frameStyle, .film)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertEqual(element.frameStyle, .simple)
        }

        XCTContext.runActivity(named: "フレーム見た目複合変更") { _ in
            let event = ImageFrameAppearanceChangedEvent(
                elementId: element.id,
                oldShowFrame: false,
                newShowFrame: true,
                oldFrameStyle: .simple,
                newFrameStyle: .badge,
                oldFrameColor: .black,
                newFrameColor: .cyan
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertTrue(element.showFrame)
            XCTAssertEqual(element.frameStyle, .badge)
            XCTAssertEqual(element.frameColor.rgbaHexString, UIColor.cyan.rgbaHexString)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertFalse(element.showFrame)
            XCTAssertEqual(element.frameStyle, .simple)
            XCTAssertEqual(element.frameColor.rgbaHexString, UIColor.black.rgbaHexString)
        }

        XCTContext.runActivity(named: "角丸") { _ in
            let event = ImageRoundedCornersChangedEvent(
                elementId: element.id,
                wasRounded: false,
                isRounded: true,
                oldRadius: 0.0,
                newRadius: 12.0
            )
            store.storeRenderedImage(cachedImage, of: element)
            history.recordAndApply(event)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertTrue(element.roundedCorners)
            XCTAssertEqual(element.cornerRadius, 12.0, accuracy: 0.0001)

            store.storeRenderedImage(cachedImage, of: element)
            history.undo()
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertFalse(element.roundedCorners)
            XCTAssertEqual(element.cornerRadius, 0.0, accuracy: 0.0001)
        }
    }

    /// 要素切り替え時に画像調整の開始値キャッシュが持ち越されないことを確認
    @MainActor
    func testImageAdjustmentStartValueDoesNotLeakAcrossElements() {
        let (project, first, second) = makeProjectWithTwoImageElements()
        first.brightnessAdjustment = 0.7

        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        editorViewModel.selectElement(first)
        flushMainRunLoop()
        elementViewModel.imageAdjustment.beginImageAdjustmentEditing(.brightness)

        editorViewModel.selectElement(second)
        flushMainRunLoop()

        elementViewModel.imageAdjustment.beginImageAdjustmentEditing(.brightness)
        elementViewModel.imageAdjustment.updateImageAdjustment(.brightness, value: 0.25)
        elementViewModel.imageAdjustment.commitImageAdjustmentEditing(.brightness)

        XCTAssertEqual(second.brightnessAdjustment, 0.25, accuracy: 0.0001)

        editorViewModel.undo()
        XCTAssertEqual(second.brightnessAdjustment, 0.0, accuracy: 0.0001)
    }

    /// 非RenderScheduler項目のcommit時に選択要素更新が通知されることを確認
    @MainActor
    func testCommitImageAdjustmentEditingPublishesSelectionUpdateForNonSchedulerKey() {
        let (project, element) = makeProjectWithImageElement()
        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        editorViewModel.selectElement(element)
        flushMainRunLoop()

        var publishCount = 0
        var cancellables = Set<AnyCancellable>()
        editorViewModel.$selectedElement
            .dropFirst()
            .sink { _ in
                publishCount += 1
            }
            .store(in: &cancellables)

        elementViewModel.imageAdjustment.beginImageAdjustmentEditing(.brightness)
        elementViewModel.imageAdjustment.updateImageAdjustment(.brightness, value: 0.2)
        flushMainRunLoop()

        // commitによる通知を独立して検証するため、update時の通知カウントをリセット
        publishCount = 0
        elementViewModel.imageAdjustment.commitImageAdjustmentEditing(.brightness)
        flushMainRunLoop()

        XCTAssertGreaterThanOrEqual(publishCount, 1)
    }

    /// Revert と画像差し替えの Undo／Redo で、古い描画キャッシュを使い続けないことを確認
    @MainActor
    func test_revertAndReplaceHistory_dropStaleCache() {
        assertHistoryDropsStaleCache("Revert") { editorViewModel, _ in
            editorViewModel.revertSelectedImageToInitialState()
        }
        let replacement = makeSolidImage(color: .blue, size: CGSize(width: 4, height: 4))
        assertHistoryDropsStaleCache("差し替え") { editorViewModel, element in
            editorViewModel.imageEdits.applyManualBackgroundRemovalResult(replacement, to: element)
        }
    }

    /// 操作を履歴に積み、Undo／Redo のたびに描画キャッシュの目印が残らないことを確認する
    /// - Parameters:
    ///   - name: 失敗時に表示する操作名
    ///   - operate: 編集値を初期状態へ戻す操作（Revert・差し替え）
    @MainActor
    private func assertHistoryDropsStaleCache(
        _ name: String,
        operate: @MainActor (EditorViewModel, ImageElement) -> Void
    ) {
        let (project, element) = makeProjectWithImageElement()
        let editorViewModel = EditorViewModel(project: project)
        // エディタが持つ管理役と同じインスタンスで、キャッシュを観察する。
        guard let store = editorViewModel.managedRenderSessions as? ImageRenderSessionStore else {
            return XCTFail("エディタの管理役は、アプリと同じ具体型")
        }
        editorViewModel.selectElement(element)
        element.saturationAdjustment = 0.5
        operate(editorViewModel, element)
        let marker = makeSolidImage(color: .green, size: CGSize(width: 4, height: 4))

        store.storeRenderedImage(marker, of: element)
        editorViewModel.undo()
        XCTAssertEqual(element.saturationAdjustment, 0.5, accuracy: 0.0001, "\(name) の Undo")
        XCTAssertFalse(store.cachedRenderedImage(of: element) === marker, "\(name) の Undo")

        store.storeRenderedImage(marker, of: element)
        editorViewModel.redo()
        XCTAssertEqual(element.saturationAdjustment, 1.0, accuracy: 0.0001, "\(name) の Redo")
        XCTAssertFalse(store.cachedRenderedImage(of: element) === marker, "\(name) の Redo")
    }
}
