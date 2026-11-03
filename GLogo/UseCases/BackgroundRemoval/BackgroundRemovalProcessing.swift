// AI背景除去とマスク生成の境界を定義する。

import UIKit

/// AI 背景除去処理の抽象インターフェース
protocol BackgroundRemovalProcessing: Sendable {
    /// 背景除去済み画像を生成する
    /// - Parameter image: 背景除去対象の画像
    /// - Returns: 背景除去済み画像
    func removeBackground(from image: UIImage) async throws -> UIImage

    /// 前景マスク画像を生成する
    /// - Parameter image: マスク生成対象の画像
    /// - Returns: 前景マスク画像
    func generateMask(from image: UIImage) async throws -> UIImage
}
