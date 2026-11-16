// メモリ警告時に、要素別キャッシュと使用中の描画サービスのキャッシュを解放する。

import Foundation

/// 複数要素で同じサービスを共有していても、1回の呼び出しにつき一度だけ解放する。
/// 要素ごとのキャッシュの解放と描画サービスの引き当ては、エディタの管理役に求める。
/// 最初に、解放された要素のセッションを回収させる（非同期の処理が終わって解放された要素の分を、ここで捨てる）。
/// 削除したが履歴に残る要素の分は、従来どおり対象にしない（第22回で扱う）。
enum ImageCacheReleaseUseCase {
    /// - Parameters:
    ///   - elements: キャッシュを解放する要素
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
        var identifiers: Set<ObjectIdentifier> = [ObjectIdentifier(defaultService)]
        for case let image as ImageElement in elements {
            renderSessions.invalidate(.all, of: image)
            let service = renderSessions.previewService(of: image)
            if identifiers.insert(ObjectIdentifier(service)).inserted {
                services.append(service)
            }
        }
        for service in services {
            service.releaseMemory()
        }
    }
}
