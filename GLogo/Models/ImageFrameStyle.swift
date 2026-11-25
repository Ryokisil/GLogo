// 画像フレームのプリセット種別と、旧形式の値からの復元規則を表す。

import Foundation

/// 画像フレームのプリセット種別
enum ImageFrameStyle: String, Codable, CaseIterable {
    case simple
    case double
    case cornerAccent
    case polaroid
    case film
    case neon
    case badge
    case stamp
    case softWhite
    case glassWhite
    case editorialWhite

    /// 永続化データからフレーム種別を復元する
    /// - Parameters:
    ///   - decoder: デコーダー
    /// - Returns: なし
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        if rawValue == "softOverlay" {
            self = .simple
            return
        }

        guard let style = ImageFrameStyle(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown ImageFrameStyle rawValue: \(rawValue)"
            )
        }

        self = style
    }

    /// フレーム種別を永続化向けにエンコードする
    /// - Parameters:
    ///   - encoder: エンコーダー
    /// - Returns: なし
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
