// エディタの管理役（ImageRenderSessionReading・ImageRenderSessionControlling）への要求を記録する偽物。
// 受け取る側の入口・保存の受付・状態を変える側が、管理役を通ることを確かめるテストで共有する（第17回の RenderSessionReadingSpy を改名）。

import UIKit
@testable import GLogo

/// 要求を順に記録する管理役の偽物。
///
/// 読み取りは、決めておいた画像を返す。返す画像を要素自身のセッションの画像と別にしておくと、
/// 描かれた色や受け取った画像からも、管理役を通ったかを見分けられる
/// （今は管理役も要素のセッションを返すため、同じ画像が届くことだけでは接続漏れに気づけない）。
/// 状態の変更は、読み取りとは別に記録してから、アプリと同じ管理役へそのまま渡す（編集中の状態やキャッシュは、これまでどおり変わる）。
@MainActor
final class RenderSessionSpy: ImageRenderSessionReading, ImageRenderSessionControlling {
    /// 読み取りの種類
    enum Kind: Equatable {
        case originalImage
        case displayImage
        case drawingImage
        case previewService
    }

    /// 読み取りの種類と、対象の要素のインスタンス
    struct Request: Equatable {
        let kind: Kind
        let element: ObjectIdentifier

        init(_ kind: Kind, _ element: ImageElement) {
            self.kind = kind
            self.element = ObjectIdentifier(element)
        }
    }

    /// 状態の変更の種類
    enum ControlKind: Equatable {
        case startEditing
        case endEditing
        case invalidate(ImageRenderCache.Invalidation)
        case storeRenderedImage
        case fullQualityImage
    }

    /// 状態の変更の種類と、対象の要素のインスタンス
    struct Control: Equatable {
        let kind: ControlKind
        let element: ObjectIdentifier

        init(_ kind: ControlKind, _ element: ImageElement) {
            self.kind = kind
            self.element = ObjectIdentifier(element)
        }
    }

    /// 元画像として返す画像
    var original: UIImage?
    /// 表示画像として返す画像
    var display: UIImage?
    /// キャンバスに描く画像として返す画像
    var drawing: UIImage?
    /// 描画サービスとして返すもの
    var service: any ImagePreviewing
    /// 読み取りを記録した直後に呼ぶ。問い合わせの時点の状態（削除の前か後かなど）を調べるのに使う。
    var onRequest: ((Request, ImageElement) -> Void)?
    /// 状態の変更を記録した直後（アプリの管理役へ渡す前）に呼ぶ。変更の時点の要素の値を調べるのに使う。
    var onControl: ((Control, ImageElement) -> Void)?

    private(set) var requests: [Request] = []
    private(set) var controls: [Control] = []

    /// 状態の変更を渡す先。アプリと同じ実装（要素のセッションへ委譲する）。
    /// 今の管理役は状態を持たないため、別のインスタンスでも同じ要素のセッションに届く。所有を移す第20回で、この形を見直す。
    private let forwarding = ImageRenderSessionStore()

    init(
        original: UIImage? = nil,
        display: UIImage? = nil,
        drawing: UIImage? = nil,
        service: any ImagePreviewing = FixedPreviewService(output: snapshotImage(.white))
    ) {
        self.original = original
        self.display = display
        self.drawing = drawing
        self.service = service
    }

    // MARK: - 読み取り

    func originalImage(of element: ImageElement) -> UIImage? {
        record(Request(.originalImage, element), element)
        return original
    }

    func displayImage(of element: ImageElement) -> UIImage? {
        record(Request(.displayImage, element), element)
        return display
    }

    func drawingImage(of element: ImageElement) -> UIImage? {
        record(Request(.drawingImage, element), element)
        return drawing
    }

    func previewService(of element: ImageElement) -> any ImagePreviewing {
        record(Request(.previewService, element), element)
        return service
    }

    // MARK: - 状態の変更

    func startEditing(_ element: ImageElement) {
        record(Control(.startEditing, element), element)
        forwarding.startEditing(element)
    }

    func endEditing(_ element: ImageElement) {
        record(Control(.endEditing, element), element)
        forwarding.endEditing(element)
    }

    func invalidate(_ scope: ImageRenderCache.Invalidation, of element: ImageElement) {
        record(Control(.invalidate(scope), element), element)
        forwarding.invalidate(scope, of: element)
    }

    func storeRenderedImage(_ image: UIImage?, of element: ImageElement) {
        record(Control(.storeRenderedImage, element), element)
        forwarding.storeRenderedImage(image, of: element)
    }

    func fullQualityImage(of element: ImageElement) async -> UIImage? {
        record(Control(.fullQualityImage, element), element)
        return await forwarding.fullQualityImage(of: element)
    }

    // MARK: - 記録

    /// 指定した種類の読み取りの回数
    func count(of kind: Kind) -> Int {
        requests.filter { $0.kind == kind }.count
    }

    /// これまでの記録（読み取りと状態の変更）を消す。表示のための要求と、確かめたい操作の要求を分けるのに使う。
    func removeAllRequests() {
        requests.removeAll()
        controls.removeAll()
    }

    private func record(_ request: Request, _ element: ImageElement) {
        requests.append(request)
        onRequest?(request, element)
    }

    private func record(_ control: Control, _ element: ImageElement) {
        controls.append(control)
        onControl?(control, element)
    }
}
