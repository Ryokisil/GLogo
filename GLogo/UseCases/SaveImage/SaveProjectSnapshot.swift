// 保存1件の範囲。保存要求時の要素と描画資源を編集中のプロジェクトから切り離して保持し、選定・加工・合成へ画像を渡す。

import UIKit

/// 保存1件に専有される描画入力と、その画像要素の描画のセッション。永続化・UI 用のプロジェクト複製ではない。
///
/// MainActor 上で全ての可変要素をコピーし、画像要素の元画像をエディタの管理役から受け取って固定した後、Coordinator の単一タスクへ渡す。
/// 管理役は受付の間だけ使い、保持しない（バックグラウンドの保存処理へ持ち込まない）。
/// 画像は自分の複製のものだけを返し、複製はインスタンスで引き当てる（複製は元の要素と同じ ID を持つため、ID では見分けない）。
/// 複製のセッションは、この範囲が複製の依存で作って持つ（第21回）。エディタの管理役の表には登録しない。
/// 受付でエディタから元画像を受け取るとき、エディタで未取得なら、エディタ側で取得とキャッシュが起きる（エディタの状態として残る）。
/// 受付のあとの保存処理は、自分のセッションだけを使い、エディタ側の状態を変えない。
/// 背景画像も受付で1回だけ取得して、この範囲に固定する（第26回で Model の固定から移した）。
/// 内部 Model は Sendable ではないため、引き渡した後は他の処理から読み書きしない。
final class SaveProjectSnapshot: SaveImageReading, @unchecked Sendable {
    let project: LogoProject

    /// 受付で取得して固定した背景画像。保存要求ごとに画像への参照を固定する。UIImage 自体は複製しない
    /// （取得先のキャッシュから、複数の保存が同じ UIImage を受け取ることはある）。
    /// nil（画像の背景でない・受付のときに取得できなかった）でも、あとで取り直さない。
    let backgroundImage: UIImage?

    /// 画像要素の複製と、そのセッション。
    private struct ImageCopy {
        let element: ImageElement
        let session: ImageRenderSession
    }

    /// 自分の画像要素の複製とセッションを、複製のインスタンスで引き当てる表。
    /// 複製を持ち続け、範囲の寿命のあいだ、識別子が別のインスタンスに使い回されないようにする。
    private let imageCopies: [ObjectIdentifier: ImageCopy]

    /// - Parameters:
    ///   - source: 編集中のプロジェクト
    ///   - renderSessions: エディタの管理役。画像要素の元画像を受け取るためだけに使い、保持しない
    ///   - backgroundImages: 背景画像の取得先。受付で1回だけ使い、保持しない
    @MainActor
    init(
        project source: LogoProject,
        renderSessions: any ImageRenderSessionReading,
        backgroundImages: any BackgroundImageLoading
    ) {
        let project = LogoProject(name: source.name, canvasSize: source.canvasSize)
        project.id = source.id
        project.backgroundSettings = source.backgroundSettings
        // 受付の時点で取得する。受付のあとのファイルの更新を、この保存へ持ち越さない。
        let backgroundImage = source.backgroundSettings.imageNameToDraw.flatMap(backgroundImages.loadBackgroundImage(named:))
        var imageCopies: [ObjectIdentifier: ImageCopy] = [:]
        project.elements = source.elements.map { element in
            let copy: LogoElement
            if let image = element as? ImageElement {
                let imageCopy = image.renderCopy()
                let session = ImageRenderSession(
                    sourceResolver: imageCopy.sourceResolver, previewService: imageCopy.previewService
                )
                // 属性を写したあとで元画像を受け取り、受付の時点の画像に固定する（UIImage は再圧縮・複製しない）。
                // 複製はソースの参照を持たないため、後のソースの差し替えや削除の影響を受けない。
                session.fixOriginalImage(renderSessions.originalImage(of: image))
                imageCopies[ObjectIdentifier(imageCopy)] = ImageCopy(element: imageCopy, session: session)
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
        self.backgroundImage = backgroundImage
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
        guard let copy = imageCopies[ObjectIdentifier(element)], copy.element === element else { return nil }
        return copy.session
    }
}
