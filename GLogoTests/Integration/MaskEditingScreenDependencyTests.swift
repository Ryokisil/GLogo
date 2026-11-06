// 手動背景除去と背景ぼかしマスクの画面が、依存を画面を開くたびに1回だけ作り、再描画では作り直さないことを確かめる。
// 作る関数は StateObject が ViewModel を作る式の中でだけ呼ばれる、という前提を実際の表示で確認する。

import SwiftUI
import XCTest
@testable import GLogo

final class MaskEditingScreenDependencyTests: XCTestCase {
    @MainActor
    func test_manualRemovalScreen_createsDependenciesPerOpen() throws {
        let counter = ScreenFactoryCounter()
        let element = try makeElement()

        try assertCreatesPerOpen(counter: counter, perOpen: Counts(removers: 1, resolvers: 1, blurUseCases: 0)) {
            ManualBackgroundRemovalView(
                imageElement: element,
                makeBackgroundRemover: counter.makeBackgroundRemover,
                makeImageSourceResolver: counter.makeImageSourceResolver
            )
        }
    }

    @MainActor
    func test_blurMaskScreen_createsDependenciesPerOpen() throws {
        let counter = ScreenFactoryCounter()
        let element = try makeElement()

        try assertCreatesPerOpen(counter: counter, perOpen: Counts(removers: 1, resolvers: 1, blurUseCases: 1)) {
            BackgroundBlurMaskEditView(
                imageElement: element,
                initialMaskData: nil,
                blurRadius: 6,
                makeManualBackgroundBlurUseCase: counter.makeManualBackgroundBlurUseCase,
                makeBackgroundRemover: counter.makeBackgroundRemover,
                makeImageSourceResolver: counter.makeImageSourceResolver,
                onComplete: { _ in }
            )
        }
    }

    // MARK: - 検証

    @MainActor
    private func assertCreatesPerOpen<Screen: View>(
        counter: ScreenFactoryCounter,
        perOpen: Counts,
        makeScreen: () -> Screen,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        var windows: [UIWindow] = []
        defer { windows.forEach { $0.isHidden = true } }

        _ = makeScreen()
        XCTAssertEqual(counter.counts, Counts(), "画面の値を作るだけでは作らない", file: file, line: line)

        let host = show(makeScreen(), in: &windows)
        XCTAssertEqual(counter.counts, perOpen, "開いたときに1回だけ作る", file: file, line: line)

        // 親の再描画で画面の値が作り直されても、保持中の ViewModel の依存は作り直さない。
        host.rootView = makeScreen()
        settle(host.view)
        XCTAssertEqual(counter.counts, perOpen, "再描画では作り直さない", file: file, line: line)

        // 閉じて開き直すと、新しい画面の分を作る。
        _ = show(makeScreen(), in: &windows)
        XCTAssertEqual(counter.counts, perOpen.doubled, "開き直すと新しく作る", file: file, line: line)
    }

    @MainActor
    private func show<Screen: View>(_ screen: Screen, in windows: inout [UIWindow]) -> UIHostingController<Screen> {
        let host = UIHostingController(rootView: screen)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        windows.append(window)
        settle(host.view)
        return host
    }

    /// 表示の更新を反映させる。
    @MainActor
    private func settle(_ view: UIView) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    private func makeElement() throws -> ImageElement {
        ImageElementFactory().makeElement(imageData: try XCTUnwrap(snapshotImage(.red).pngData()))
    }
}

// MARK: - 記録用

private struct Counts: Equatable {
    var removers = 0
    var resolvers = 0
    var blurUseCases = 0

    var doubled: Counts {
        Counts(removers: removers * 2, resolvers: resolvers * 2, blurUseCases: blurUseCases * 2)
    }
}

/// 画面用の「作る関数」が呼ばれた回数を数える。
@MainActor
private final class ScreenFactoryCounter {
    private(set) var counts = Counts()

    func makeBackgroundRemover() -> any BackgroundRemovalProcessing {
        counts.removers += 1
        return AppComposition.makeBackgroundRemover()
    }

    func makeImageSourceResolver() -> any ImageSourceResolving {
        counts.resolvers += 1
        return OriginalImageResolver()
    }

    func makeManualBackgroundBlurUseCase() -> ManualBackgroundBlurUseCase {
        counts.blurUseCases += 1
        return AppComposition.makeManualBackgroundBlurUseCase()
    }
}

/// 編集用画像として元画像をそのまま返す。アセットの読み込みやキャッシュに触れない。
private struct OriginalImageResolver: ImageSourceResolving {
    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        imageData.flatMap(UIImage.init(data:))
    }

    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? {
        originalImageProvider()
    }
}
