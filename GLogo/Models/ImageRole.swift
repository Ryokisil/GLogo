// 画像要素の役割（保存時の基準画像か、重ねる画像か）を表す。

import Foundation

/// 画像の役割定義
enum ImageRole: String, Codable, CaseIterable {
    case base = "base"           // ベース画像（保存時の基準画像）
    case overlay = "overlay"     // オーバーレイ画像（ベース画像の上に重ねる画像）

    /// 表示用の名称
    var displayName: String {
        switch self {
        case .base:
            return "ベース画像"
        case .overlay:
            return "オーバーレイ画像"
        }
    }
}
