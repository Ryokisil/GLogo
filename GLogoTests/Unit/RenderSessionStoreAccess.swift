// テストで、エディタが持つ管理役を、同じインスタンスのまま具体型として取り出す。
// キャッシュを見るだけの口などの観察用のメソッドは具体型にだけあり、観察は、コードが使うのと同じ管理役で行う必要があるため。

@testable import GLogo

extension EditorViewModel {
    /// エディタが持つ管理役（アプリと同じ具体型・同じインスタンス）。
    /// 偽物の管理役を渡したエディタでは使わない（観察先が注入先と違うことを、黙って見逃さないよう止める）。
    var sessionStore: ImageRenderSessionStore {
        guard let store = managedRenderSessions as? ImageRenderSessionStore else {
            preconditionFailure("エディタの管理役が ImageRenderSessionStore ではない。偽物を渡したテストでは、偽物の記録で確かめる")
        }
        return store
    }
}
