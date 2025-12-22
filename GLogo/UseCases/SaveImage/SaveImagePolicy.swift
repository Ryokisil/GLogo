//
// 概要：保存モードの判定ロジック。
// 画像要素なし → failure、画像1枚のみ → individual、画像1枚＋他要素（画像/テキスト/図形）あり → composite。
//

import UIKit

struct SaveImagePolicy {
    /// 要素構成から保存モードを決定（画像なし→失敗、画像1枚→通常、複数/他要素あり→合成）
    func resolveMode(elements: [LogoElement]) -> SaveImageMode {
        let imageElements = elements.compactMap { $0 as? ImageElement }
        guard !imageElements.isEmpty else {
            return .failure(.noImageElements)
        }

        let otherElements = elements.filter { element in
            if element is ImageElement { return false }
            return element.isVisible
        }

        if imageElements.count >= 1 && (otherElements.count > 0 || imageElements.count > 1) {
            return .composite
        }

        return .individual
    }
}

enum SaveImageMode {
    case individual
    case composite
    case failure(SaveImageError)
}

enum SaveImageError: Error {
    case noImageElements
    case encodingFailed
}
