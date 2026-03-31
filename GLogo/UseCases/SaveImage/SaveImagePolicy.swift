//
// 概要：保存モードの判定ロジック。
// 画像要素なし → failure、単画像のみでも renderer 依存の見た目があれば composite、
// それ以外の画像1枚のみ → individual、画像1枚＋他要素（画像/テキスト/図形）あり → composite。
//

import UIKit

struct SaveImagePolicy: Sendable {
    /// 要素構成から保存モードを決定（画像なし→失敗、画像1枚→通常、複数/他要素あり→合成）
    func resolveMode(elements: [LogoElement]) -> SaveImageMode {
        let imageElements = elements.compactMap { $0 as? ImageElement }
        let visibleImageElements = imageElements.filter(\.isVisible)
        guard !imageElements.isEmpty else {
            return .failure(.noImageElements)
        }

        let otherElements = elements.filter { element in
            if element is ImageElement { return false }
            return element.isVisible
        }

        if visibleImageElements.count >= 1 && (otherElements.count > 0 || visibleImageElements.count > 1) {
            return .composite
        }

        if let singleVisibleImageElement = visibleImageElements.first,
           requiresRenderedComposite(for: singleVisibleImageElement) {
            return .composite
        }

        return .individual
    }

    /// 単画像でも individual 保存では再現できない見た目を持つかを判定する
    private func requiresRenderedComposite(for imageElement: ImageElement) -> Bool {
        imageElement.showFrame ||
        imageElement.roundedCorners ||
        abs(imageElement.rotation) > .ulpOfOne ||
        imageElement.opacity < 0.999
    }
}

enum SaveImageMode: Sendable {
    case individual
    case composite
    case failure(SaveImageError)
}

enum SaveImageError: Error, Sendable {
    case noImageElements
    case encodingFailed
}
