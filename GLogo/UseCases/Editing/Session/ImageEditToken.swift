// 非同期画像加工が開始時の編集対象へ適用できるかを照合する実行時トークン。

import Foundation

/// 値を元に戻しても変更番号は戻さず、古い要求を復活させない。永続化はしない。
struct ImageEditToken: Equatable {
    let element: ObjectIdentifier
    let imageRevision: UInt
    let historyRestorationRevision: UInt
}
