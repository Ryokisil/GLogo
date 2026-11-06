// 編集イベントの Undo／Redo スタックと、履歴の移動をまたぐ非同期要求を失効させる世代を管理する。

import Foundation

/// エディタの履歴を管理するクラス
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

    /// イニシャライザ
    init(project: LogoProject?, maxHistoryCount: Int = 100) {
        self.project = project
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

        // イベントスタックに追加
        eventStack.append(event)

        // 履歴の最大数を超えた場合、古いものから削除
        if eventStack.count > maxHistoryCount {
            eventStack.removeFirst()
        }

        // 取り消し履歴をクリア
        undoneEventStack.removeAll()
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

        // 取り消し履歴に追加
        undoneEventStack.append(lastEvent)

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

        // イベント履歴に追加
        eventStack.append(lastUndoneEvent)

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
}
