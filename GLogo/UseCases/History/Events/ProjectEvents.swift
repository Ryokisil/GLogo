// プロジェクト名とキャンバスサイズの変更を記録する履歴イベント。

import Foundation

/// プロジェクト名変更イベント
struct ProjectNameChangedEvent: EditorEvent {
    let oldName: String
    let newName: String

    var description: String {
        return "プロジェクト名を「\(newName)」に変更しました"
    }

    func apply(to project: LogoProject) {
        project.name = newName
    }

    func revert(from project: LogoProject) {
        project.name = oldName
    }
}

/// キャンバスサイズ変更イベント
struct CanvasSizeChangedEvent: EditorEvent {
    let oldSize: CGSize
    let newSize: CGSize

    var description: String {
        return "キャンバスサイズを変更しました"
    }

    func apply(to project: LogoProject) {
        project.canvasSize = newSize
    }

    func revert(from project: LogoProject) {
        project.canvasSize = oldSize
    }
}
