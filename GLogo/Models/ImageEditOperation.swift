// 画像要素に保存される編集操作の記録。旧データの読み込み互換のために保持する。

import Foundation

/// 画像編集操作を表す構造体
struct ImageEditOperation: Codable {
    enum OperationType: String, Codable {
        case adjustSaturation
        case adjustBrightness
        case adjustContrast
        case adjustHighlights
        case adjustShadows
        case applyTint
        case changeFrame
        case changeCornerRadius
    }

    let type: OperationType
    let timestamp: Date
    let parameters: [String: Double]

    init(type: OperationType, parameters: [String: Double] = [:]) {
        self.type = type
        self.timestamp = Date()
        self.parameters = parameters
    }
}
