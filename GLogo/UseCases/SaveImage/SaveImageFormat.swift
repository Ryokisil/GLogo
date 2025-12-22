
// 保存時の画像フォーマットを表す。
// 保存ポリシーから決定され、PhotoLibraryWriterでデータ化に使う。

import UniformTypeIdentifiers

enum SaveImageFormat {
    case heic
    case png

    var utType: UTType {
        switch self {
        case .heic:
            return .heic
        case .png:
            return .png
        }
    }
}
