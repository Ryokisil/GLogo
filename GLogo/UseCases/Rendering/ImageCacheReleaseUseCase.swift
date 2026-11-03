// メモリ警告時に、要素別キャッシュと使用中の描画サービスのキャッシュを解放する。

import Foundation

/// 複数要素で同じサービスを共有していても、1回の呼び出しにつき一度だけ解放する。
enum ImageCacheReleaseUseCase {
    static func releaseCaches(in elements: [LogoElement]) {
        // 画像のないプロジェクトでも、従来どおり既定サービスを解放する。
        let sharedService = ImagePreviewService.shared
        var services: [any ImagePreviewing] = [sharedService]
        var identifiers: Set<ObjectIdentifier> = [ObjectIdentifier(sharedService)]
        for case let image as ImageElement in elements {
            image.handleMemoryWarning()
            let service = image.previewService
            if identifiers.insert(ObjectIdentifier(service)).inserted {
                services.append(service)
            }
        }
        for service in services {
            service.resetCache()
        }
    }
}
