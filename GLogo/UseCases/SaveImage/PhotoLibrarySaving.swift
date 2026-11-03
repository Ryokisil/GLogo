// 写真ライブラリ保存の要求境界と、結果・失敗理由の型を定義する。

import Foundation

/// 写真ライブラリ保存の失敗理由
enum PhotoLibrarySaveFailure: Error, Sendable, Equatable {
    case permissionDenied
    case noImageElements
    case imageSelectionFailed
    case filterApplicationFailed
    case compositeGenerationFailed
    case writeFailed
}

/// 写真ライブラリ保存結果
typealias PhotoLibrarySaveResult = Result<Void, PhotoLibrarySaveFailure>

/// 保存要求の境界。完了は MainActor 上で一度だけ通知する。
protocol PhotoLibrarySaving {
    @MainActor
    func save(
        project: LogoProject,
        completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void
    )

    @MainActor
    func saveComposite(
        project: LogoProject,
        completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void
    )
}
