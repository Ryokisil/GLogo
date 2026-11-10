// 管理役（ImageRenderSessionReading）への問い合わせを記録する偽物。受け取る側の入口が管理役を通ることを確かめるテストで共有する。

import UIKit
@testable import GLogo

/// 問い合わせを順に記録し、決めておいた画像を返す。
/// 返す画像を要素自身のセッションの画像と別にしておくと、描かれた色や受け取った画像からも、管理役を通ったかを見分けられる
/// （第17回の時点では、管理役も要素のセッションを返すため、同じ画像が届くことだけでは接続漏れに気づけない）。
@MainActor
final class RenderSessionReadingSpy: ImageRenderSessionReading {
    /// 問い合わせの種類
    enum Kind: Equatable {
        case originalImage
        case displayImage
        case drawingImage
        case previewService
    }

    /// 問い合わせの種類と、対象の要素のインスタンス
    struct Request: Equatable {
        let kind: Kind
        let element: ObjectIdentifier

        init(_ kind: Kind, _ element: ImageElement) {
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
    /// 問い合わせを記録した直後に呼ぶ。問い合わせの時点の状態（削除の前か後かなど）を調べるのに使う。
    var onRequest: ((Request, ImageElement) -> Void)?

    private(set) var requests: [Request] = []

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

    /// 指定した種類の問い合わせの回数
    func count(of kind: Kind) -> Int {
        requests.filter { $0.kind == kind }.count
    }

    /// これまでの記録を消す。表示のための問い合わせと、確かめたい操作の問い合わせを分けるのに使う。
    func removeAllRequests() {
        requests.removeAll()
    }

    private func record(_ request: Request, _ element: ImageElement) {
        requests.append(request)
        onRequest?(request, element)
    }
}
