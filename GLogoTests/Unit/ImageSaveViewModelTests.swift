// 保存要求の状態遷移、重複抑止と非同期完了時の寿命を検証する。

import XCTest
@testable import GLogo

/// 完了のタイミングをテスト側で制御し、写真ライブラリへの書き込みを避ける。
@MainActor
final class PhotoLibrarySavingStub: PhotoLibrarySaving {
    private(set) var projects: [LogoProject] = []
    private(set) var compositeCount = 0
    var immediateResult: PhotoLibrarySaveResult?
    /// 保存入力を受け取った時点で呼ぶ。準備処理との前後関係を確かめるテストで使う。
    var onSave: (() -> Void)?
    private var completion: (@MainActor @Sendable (PhotoLibrarySaveResult) -> Void)?

    func save(
        project: LogoProject,
        completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void
    ) {
        onSave?()
        projects.append(project)
        self.completion = completion
        if let immediateResult {
            finish(immediateResult)
        }
    }

    func saveComposite(
        project: LogoProject,
        completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void
    ) {
        compositeCount += 1
        save(project: project, completion: completion)
    }

    func finish(_ result: PhotoLibrarySaveResult) {
        let callback = completion
        completion = nil
        callback?(result)
    }
}

final class ImageSaveViewModelTests: XCTestCase {
    @MainActor
    func test_save_success_unlocksBeforeCompletion() {
        let saver = PhotoLibrarySavingStub()
        let viewModel = ImageSaveViewModel(saver: saver)
        let project = LogoProject()
        var didPrepare = false
        var didComplete = false

        viewModel.save(project: project, prepare: {
            XCTAssertTrue(saver.projects.isEmpty)
            didPrepare = true
        }) { result in
            XCTAssertFalse(viewModel.isSaving)
            XCTAssertNil(viewModel.lastFailure)
            if case .failure = result { XCTFail("保存が成功するべき") }
            didComplete = true
        }

        XCTAssertTrue(didPrepare)
        XCTAssertTrue(viewModel.isSaving)
        XCTAssertFalse(didComplete)
        XCTAssertTrue(saver.projects.first === project)

        saver.finish(.success(()))
        XCTAssertTrue(didComplete)
    }

    @MainActor
    func test_save_failure_clearsOnRetry() {
        let saver = PhotoLibrarySavingStub()
        let viewModel = ImageSaveViewModel(saver: saver)
        let project = LogoProject()

        viewModel.save(project: project, prepare: {}) { result in
            XCTAssertFalse(viewModel.isSaving)
            XCTAssertEqual(viewModel.lastFailure, .writeFailed)
            guard case .failure(.writeFailed) = result else {
                return XCTFail("失敗理由をそのまま通知するべき")
            }
        }
        saver.finish(.failure(.writeFailed))

        XCTAssertEqual(viewModel.lastFailure, .writeFailed)
        viewModel.save(project: project, prepare: {}) { _ in }
        XCTAssertTrue(viewModel.isSaving)
        XCTAssertNil(viewModel.lastFailure)
        saver.finish(.success(()))
        XCTAssertFalse(viewModel.isSaving)
    }

    @MainActor
    func test_save_overlappingRequests_ignoresPreparation() {
        let saver = PhotoLibrarySavingStub()
        let viewModel = ImageSaveViewModel(saver: saver)
        let project = LogoProject()

        viewModel.saveComposite(project: project, prepare: {}) { _ in }
        viewModel.save(project: project, prepare: {
            XCTFail("重複要求で編集状態を変更してはいけない")
        }) { _ in XCTFail("無視した要求の完了を呼んではいけない") }
        viewModel.saveComposite(project: project, prepare: {
            XCTFail("合成保存も重複を抑止するべき")
        }) { _ in XCTFail("無視した要求の完了を呼んではいけない") }

        XCTAssertEqual(saver.projects.count, 1)
        XCTAssertEqual(saver.compositeCount, 1)
        saver.finish(.success(()))
        XCTAssertFalse(viewModel.isSaving)
    }

    @MainActor
    func test_save_synchronousCompletion_unlocks() {
        let saver = PhotoLibrarySavingStub()
        saver.immediateResult = .success(())
        let viewModel = ImageSaveViewModel(saver: saver)
        var didComplete = false

        viewModel.save(project: LogoProject(), prepare: {}) { _ in
            XCTAssertFalse(viewModel.isSaving)
            didComplete = true
        }

        XCTAssertTrue(didComplete)
        XCTAssertFalse(viewModel.isSaving)
    }

    @MainActor
    func test_save_releasedViewModel_ignoresCompletion() {
        let saver = PhotoLibrarySavingStub()
        var viewModel: ImageSaveViewModel? = ImageSaveViewModel(saver: saver)
        weak var weakViewModel = viewModel

        viewModel?.save(project: LogoProject(), prepare: {}) { _ in
            XCTFail("解放後に画面へ通知してはいけない")
        }
        viewModel = nil

        XCTAssertNil(weakViewModel)
        saver.finish(.success(()))
    }
}
