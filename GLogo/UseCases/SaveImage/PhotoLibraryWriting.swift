// 写真ライブラリの権限確認と書き込みの境界を定義する。

import Photos
import UIKit

/// 写真ライブラリ権限確認・書き込みの抽象
protocol PhotoLibraryWriting: Sendable {
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus
    func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping @Sendable (PHAuthorizationStatus) -> Void)
    func performSave(of image: UIImage, format: SaveImageFormat) async throws
}
