// メモリ警告時に、要素別キャッシュと使用中の描画サービスのキャッシュを解放する。

import Foundation

/// 複数要素で同じサービスを共有していても、1回の呼び出しにつき一度だけ解放する。
/// 要素ごとのキャッシュの解放と描画サービスの引き当ては、エディタの管理役に求める。
/// 最初に、解放された要素のセッションを回収させる（非同期の処理が終わって解放された要素の分を、ここで捨てる）。
///
/// プロジェクトにある要素は、すべてのキャッシュを消す（次の描画で取り直す）。
/// プロジェクトにないが生きている要素（削除して履歴が持つ要素・Redo の履歴が持つ要素・非同期の処理だけが持つ要素）も
/// 対象にする（第22回）。こちらは取り直しが後の Undo になり、その間に参照先のファイルが変わりうるため、
/// 取り直して同じ画像に戻ると言える場合だけ元画像とプロキシも消す（`detachedScope(of:renderSessions:)`）。
enum ImageCacheReleaseUseCase {
    /// - Parameters:
    ///   - elements: プロジェクトにある要素
    ///   - defaultService: 画像がない場合も解放する既定の描画サービス
    ///   - renderSessions: エディタの管理役
    @MainActor
    static func releaseCaches(
        in elements: [LogoElement],
        defaultService: any ImagePreviewing,
        renderSessions: any ImageRenderSessionManaging
    ) {
        renderSessions.reclaimReleasedSessions()
        // 画像のないプロジェクトでも、従来どおり既定サービスを解放する。
        var services: [any ImagePreviewing] = [defaultService]
        var serviceIdentifiers: Set<ObjectIdentifier> = [ObjectIdentifier(defaultService)]
        func addService(of image: ImageElement) {
            let service = renderSessions.previewService(of: image)
            if serviceIdentifiers.insert(ObjectIdentifier(service)).inserted {
                services.append(service)
            }
        }

        var projectImages: Set<ObjectIdentifier> = []
        for case let image as ImageElement in elements {
            projectImages.insert(ObjectIdentifier(image))
            renderSessions.invalidate(.all, of: image)
            addService(of: image)
        }
        // プロジェクトにあるかは ID ではなくインスタンスで見分ける（同じ ID の別のインスタンスを、プロジェクトの要素と取り違えない）。
        for image in renderSessions.registeredElements where !projectImages.contains(ObjectIdentifier(image)) {
            renderSessions.invalidate(detachedScope(of: image, renderSessions: renderSessions), of: image)
            addService(of: image)
        }
        // 描画サービスは、要素のキャッシュをすべて消したあとで解放する。
        for service in services {
            service.releaseMemory()
        }
    }

    /// プロジェクトにない要素で消す範囲。
    ///
    /// データだけを持つ要素で、元画像がキャッシュにあるときだけ、元画像とプロキシも消す（`.all`）。
    /// データは読み直しても同じ画像になり、元画像が取れる間のプロキシは、取得先が元画像から作るため。
    /// それ以外は、編集値から作り直せる表示画像とプレビュー元画像だけを消す（`.adjustments`）。
    /// - パス・URL・ファイル名を持つ要素：取得先はファイルを読み直す（ファイル名にも絶対パスが入りうる）。取得先の優先順位では、
    ///   これらはデータより先に使われる。
    /// - 元画像がキャッシュにない要素：取れたプロキシは、取得先が外部のプロキシのファイルから読んだものかもしれない。
    /// 判定のために元画像を取得・デコードはしない（メモリ警告の処理の中で、メモリを使わないため）。
    @MainActor
    private static func detachedScope(
        of image: ImageElement,
        renderSessions: any ImageRenderSessionControlling
    ) -> ImageRenderCache.Invalidation {
        let readsFile = image.originalImagePath != nil || image.originalImageURL != nil || image.imageFileName != nil
        guard !readsFile, image.imageData != nil, renderSessions.hasCachedOriginalImage(of: image) else {
            return .adjustments
        }
        return .all
    }
}
