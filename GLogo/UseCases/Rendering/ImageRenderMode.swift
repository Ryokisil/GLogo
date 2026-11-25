// SDR／HDRのどちらの描画経路を使うかを表す。

import Foundation

/// レンダリング経路の種別
enum ImageRenderMode: Equatable {
    /// SDR向け経路
    case sdr
    /// HDR向け経路
    case hdr

    /// プリセットIDからレンダリング経路を判定
    /// - Parameters:
    ///   - presetId: 適用中プリセットID
    /// - Returns: 判定したレンダリング経路
    static func fromPresetId(_ presetId: String?) -> ImageRenderMode {
        guard let presetId, presetId.hasPrefix("hdr_") else {
            return .sdr
        }
        return .hdr
    }
}
