
// 画像インポートの入力元を表す型。
// UI画像/バイナリなど異なる入力を統一し、下流にDataとして渡すための変換を担当。
// UseCaseはこの型だけを扱い、UI側の入力形式を意識しない。

import UIKit

// MARK: - Image Import Source
enum ImageImportSource {
    case imageData(Data)
    case uiImage(UIImage)

    func resolveImageData() -> Data? {
        switch self {
        case .imageData(let data):
            return data
        case .uiImage(let image):
            return image.pngData()
        }
    }
}
