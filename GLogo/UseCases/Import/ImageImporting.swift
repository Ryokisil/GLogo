// 画像生成・初期配置の依存を、編集セッションの状態更新から切り離す。

import UIKit

/// 入力とプロジェクトの既存画像数から画像要素を生成する。
/// プロジェクトへの追加・選択・履歴・画面通知は呼び出し側が担当する。
protocol ImageImporting {
    func importImage(
        source: ImageImportSource,
        project: LogoProject,
        viewportSize: CGSize,
        assetIdentifier: String?,
        canvasSize: CGSize?
    ) -> ImageImportResult?
}
