// 保存要求時の要素と描画資源を、編集中のプロジェクトから切り離して保持する。

import Foundation

/// 保存1件に専有される描画入力。永続化・UI 用のプロジェクト複製ではない。
/// MainActor 上で全ての可変要素をコピーした後、Coordinator の単一タスクへ渡す。
/// 内部 Model は Sendable ではないため、引き渡した後は他の処理から読み書きしない。
final class SaveProjectSnapshot: @unchecked Sendable {
    let project: LogoProject

    @MainActor
    init(project source: LogoProject) {
        let project = LogoProject(name: source.name, canvasSize: source.canvasSize)
        project.id = source.id
        project.backgroundSettings = source.backgroundSettings.renderCopy()
        project.elements = source.elements.map { element in
            let copy = (element as? ImageElement)?.renderCopy() ?? element.copy()
            // 通常の copy() は UI 用の別要素を生成する。保存では元の識別子と順序を維持する。
            copy.id = element.id
            copy.name = element.name
            copy.zIndex = element.zIndex
            return copy
        }
        self.project = project
    }
}
