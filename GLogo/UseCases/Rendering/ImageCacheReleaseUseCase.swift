// メモリ警告時に、要素別キャッシュと使用中の描画サービスのキャッシュを解放する。

import Foundation

/// 複数要素で同じサービスを共有していても、1回の呼び出しにつき一度だけ解放する。
enum ImageCacheReleaseUseCase {
    /// - Parameters:
    ///   - elements: キャッシュを解放する要素
    ///   - defaultService: 画像がない場合も解放する既定の描画サービス
    static func releaseCaches(
        in elements: [LogoElement],
        defaultService: any ImagePreviewing = ImagePreviewService.shared
    ) {
        // 画像のないプロジェクトでも、従来どおり既定サービスを解放する。
        var services: [any ImagePreviewing] = [defaultService]
        var identifiers: Set<ObjectIdentifier> = [ObjectIdentifier(defaultService)]
        for case let image as ImageElement in elements {
            image.handleMemoryWarning()
            let service = image.previewService
            if identifiers.insert(ObjectIdentifier(service)).inserted {
                services.append(service)
            }
        }
        for service in services {
            service.releaseMemory()
        }
    }
}
