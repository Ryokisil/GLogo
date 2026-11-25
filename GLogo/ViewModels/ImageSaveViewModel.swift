// 写真ライブラリ保存の要求受付と表示状態を管理する。

import Combine

/// 保存状態の唯一の所有者。保存方法の判断と実行は UseCase に委譲する。
@MainActor
final class ImageSaveViewModel: ObservableObject {
    @Published private(set) var isSaving = false
    @Published private(set) var lastFailure: PhotoLibrarySaveFailure?

    private let saver: any PhotoLibrarySaving

    init(saver: any PhotoLibrarySaving) {
        self.saver = saver
    }

    /// - Parameters:
    ///   - renderSessions: エディタの管理役。保存の受付で元画像を受け取るために渡し、ここでは保持しない
    func save(
        project: LogoProject,
        renderSessions: any ImageRenderSessionReading,
        prepare: () -> Void,
        completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void
    ) {
        performSave(prepare: prepare, operation: { done in
            saver.save(project: project, renderSessions: renderSessions, completion: done)
        }, completion: completion)
    }

    func saveComposite(
        project: LogoProject,
        renderSessions: any ImageRenderSessionReading,
        prepare: () -> Void,
        completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void
    ) {
        performSave(prepare: prepare, operation: { done in
            saver.saveComposite(project: project, renderSessions: renderSessions, completion: done)
        }, completion: completion)
    }

    /// 重複要求は準備処理も実行せず無視し、完了通知の前に表示状態を確定する。
    private func performSave(
        prepare: () -> Void,
        operation: (@escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void) -> Void,
        completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void
    ) {
        guard !isSaving else { return }

        prepare()
        isSaving = true
        lastFailure = nil

        operation { [weak self] result in
            guard let self else { return }
            self.isSaving = false
            if case .failure(let failure) = result {
                self.lastFailure = failure
            }
            completion(result)
        }
    }
}
