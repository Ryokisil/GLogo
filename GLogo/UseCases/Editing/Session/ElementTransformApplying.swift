// 変形から共通の編集状態へ渡せる操作と、保存中の入力ロックを定義する。

/// 変形状態を所有せず、履歴・選択・変更フラグを共通の編集セッションへ反映する。
@MainActor
protocol ElementTransformApplying: ElementEditApplying {
    var isSavingImage: Bool { get }
    func markProjectModified()
}
