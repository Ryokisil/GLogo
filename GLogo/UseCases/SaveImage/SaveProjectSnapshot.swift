// 保存1件の範囲。保存要求時の要素と描画資源を編集中のプロジェクトから切り離して保持し、選定・加工・合成へ画像を渡す。

import UIKit

/// 保存1件に専有される描画入力と、その画像要素の描画のセッション。永続化・UI 用のプロジェクト複製ではない。
///
/// MainActor 上で全ての可変要素をコピーし、画像要素の元画像をエディタの管理役から受け取って固定した後、Coordinator の単一タスクへ渡す。
/// 管理役は受付の間だけ使い、保持しない（バックグラウンドの保存処理へ持ち込まない）。
/// 画像は自分の複製のものだけを返し、複製はインスタンスで引き当てる（複製は元の要素と同じ ID を持つため、ID では見分けない）。
/// 第18回の中間段階として、セッションはまだ複製（`ImageElement`）が持つ（所有を移すのは第19回）。
/// 内部 Model は Sendable ではないため、引き渡した後は他の処理から読み書きしない。
final class SaveProjectSnapshot: SaveImageReading, @unchecked Sendable {
    let project: LogoProject

    /// 自分の画像要素の複製を、インスタンスで引き当てる表。
    /// 複製を持ち続け、範囲の寿命のあいだ、識別子が別のインスタンスに使い回されないようにする。
    private let imageCopies: [ObjectIdentifier: ImageElement]

    /// - Parameters:
    ///   - source: 編集中のプロジェクト
    ///   - renderSessions: エディタの管理役。画像要素の元画像を受け取るためだけに使い、保持しない
    @MainActor
    init(project source: LogoProject, renderSessions: any ImageRenderSessionReading) {
        let project = LogoProject(name: source.name, canvasSize: source.canvasSize)
        project.id = source.id
        project.backgroundSettings = source.backgroundSettings.renderCopy()
        var imageCopies: [ObjectIdentifier: ImageElement] = [:]
        project.elements = source.elements.map { element in
            let copy: LogoElement
            if let image = element as? ImageElement {
                let imageCopy = image.renderCopy()
                // 属性を写したあとで元画像を受け取り、受付の時点の画像に固定する（UIImage は再圧縮・複製しない）。
                // 複製はソースの参照を持たないため、後のソースの差し替えや削除の影響を受けない。
                imageCopy.renderSession.fixOriginalImage(renderSessions.originalImage(of: image))
                imageCopies[ObjectIdentifier(imageCopy)] = imageCopy
                copy = imageCopy
            } else {
                copy = element.copy()
            }
            // 通常の copy() は UI 用の別要素を生成する。保存では元の識別子と順序を維持する。
            copy.id = element.id
            copy.name = element.name
            copy.zIndex = element.zIndex
            return copy
        }
        self.project = project
        self.imageCopies = imageCopies
    }

    func originalImage(of element: ImageElement) -> UIImage? {
        session(of: element)?.originalImage(of: element)
    }

    func filteredImage(of element: ImageElement) -> UIImage? {
        session(of: element)?.filteredImage(of: element)
    }

    func drawingImage(of element: ImageElement) -> UIImage? {
        session(of: element)?.drawingImage(of: element)
    }

    /// 自分の複製のセッション。範囲に含まれない要素には nil を返す（同じ ID でも、インスタンスが違えば含めない）。
    private func session(of element: ImageElement) -> ImageRenderSession? {
        imageCopies[ObjectIdentifier(element)]?.renderSession
    }
}
