// 編集イベントの Undo／Redo スタックと、履歴の移動をまたぐ非同期要求を失効させる世代を管理する。

import Foundation

/// エディタの履歴を管理するクラス
///
/// イベントの適用・巻き戻しの直後に、イベントが示す描画キャッシュをエディタの管理役で失効させる。
/// 失効は同じ同期の呼び出しの中で行い、タスクなどへ遅らせない（次の描画より前に古い表示画像を消すため）。
/// 操作の最後には、解放された要素のセッションを管理役に回収させる。上限の切り捨てや Redo の履歴の破棄で要素が解放されたとき、
/// 描画を待たずに、その操作の中でキャッシュの画像まで解放するため（切り捨て・破棄より前に回収すると、まだ解放されていない）。
@MainActor
class EditorHistory {
    /// 履歴の移動をまたぐ非同期要求を失効させる。Undo／Redo しても巻き戻さない。
    private(set) var restorationRevision: UInt = 0

    /// 実行済みイベントのスタック
    private(set) var eventStack: [EditorEvent] = []

    /// 取り消されたイベントのスタック（リドゥ用）
    private var undoneEventStack: [EditorEvent] = []

    /// 履歴の最大数
    private let maxHistoryCount: Int

    /// プロジェクト参照
    private var project: LogoProject?

    /// 描画キャッシュを失効させるエディタの管理役。エディタが読み取りに使うものと同じインスタンス。
    private let renderSessions: any ImageRenderSessionControlling

    /// イニシャライザ
    init(project: LogoProject?, renderSessions: any ImageRenderSessionControlling, maxHistoryCount: Int = 100) {
        self.project = project
        self.renderSessions = renderSessions
        self.maxHistoryCount = maxHistoryCount
    }

    /// プロジェクト参照を更新
    func setProject(_ project: LogoProject) {
        restorationRevision &+= 1
        self.project = project
    }

    /// イベントを記録して適用
    func recordAndApply(_ event: EditorEvent) {
        guard let project = project else { return }

        // イベントをプロジェクトに適用
        event.apply(to: project)
        invalidateRenderCaches(event.renderInvalidationsAfterApply, in: project)

        // イベントスタックに追加
        eventStack.append(event)

        // 履歴の最大数を超えた場合、古いものから削除
        if eventStack.count > maxHistoryCount {
            eventStack.removeFirst()
        }

        // 取り消し履歴をクリア
        undoneEventStack.removeAll()
        renderSessions.reclaimReleasedSessions()
    }

    /// 最後のイベントを巻き戻す。
    /// - Returns: 巻き戻し対象が存在した場合は `true`。
    @discardableResult
    func undo() -> Bool {

        guard let project = project, let lastEvent = eventStack.popLast() else {
            return false
        }
        restorationRevision &+= 1

        // イベントの効果を元に戻す
        lastEvent.revert(from: project)
        invalidateRenderCaches(lastEvent.renderInvalidationsAfterRevert, in: project)

        // 取り消し履歴に追加
        undoneEventStack.append(lastEvent)
        renderSessions.reclaimReleasedSessions()

        return true
    }

    /// リドゥ操作
    @discardableResult
    func redo() -> Bool {
        guard let project = project, let lastUndoneEvent = undoneEventStack.popLast() else {
            return false
        }
        restorationRevision &+= 1

        // 取り消したイベントを再適用
        lastUndoneEvent.apply(to: project)
        invalidateRenderCaches(lastUndoneEvent.renderInvalidationsAfterApply, in: project)

        // イベント履歴に追加
        eventStack.append(lastUndoneEvent)
        renderSessions.reclaimReleasedSessions()

        return true
    }

    /// アンドゥ可能かどうか
    var canUndo: Bool {
        return !eventStack.isEmpty
    }

    /// リドゥ可能かどうか
    var canRedo: Bool {
        return !undoneEventStack.isEmpty
    }

    /// 履歴をクリア
    func clearHistory() {
        restorationRevision &+= 1
        eventStack.removeAll()
        undoneEventStack.removeAll()
        renderSessions.reclaimReleasedSessions()
    }

    /// アンドゥスタックの深さ（履歴の数）
    var undoCount: Int {
        return eventStack.count
    }

    /// リドゥスタックの深さ
    var redoCount: Int {
        return undoneEventStack.count
    }

    /// 履歴の説明を取得（UIに表示可能）
    func getHistoryDescriptions() -> [String] {
        return eventStack.map { $0.description }
    }

    /// イベントが示す失効を、適用したプロジェクトで要素のインスタンスへ解決して、管理役に求める。
    private func invalidateRenderCaches(_ invalidations: [ImageRenderInvalidation], in project: LogoProject) {
        for invalidation in invalidations {
            guard let element = project.element(for: invalidation.elementId, as: ImageElement.self) else { continue }
            switch invalidation.scope {
            case .cache(let scope):
                renderSessions.invalidate(scope, of: element)
            case .sourceChange:
                renderSessions.invalidateForSourceChange(of: element)
            }
        }
    }
}
