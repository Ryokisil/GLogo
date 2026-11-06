// 編集画面（EditorViewModel）と、そこから開く画面が使う外部の処理をまとめて受け渡す。
// 実装の組み立ては Composition Root（App/AppComposition）が行い、ここでは具体型を知らない。

import Foundation

/// エディタ1つ分の依存。境界の Protocol と UseCase だけを持ち、Infrastructure の具体型は含めない。
/// 生成の単位を保つため、エディタで共有するものは値で持ち、使う側ごとに作るものは「作る関数」で持つ。
struct EditorDependencies {
    // MARK: - エディタで共有する（Composition Root がエディタごとに作る）

    /// 写真ライブラリへの保存
    let photoLibrarySaver: any PhotoLibrarySaving

    /// 写真からのインポート
    let imageImporter: any ImageImporting

    /// 高画質化。エディタと AI ツールで同じものを使い、Core ML のモデルは最初の実行時に読み込んで保持する
    let imageUpscaleUseCase: ImageUpscaleUseCase

    // MARK: - 使う側ごとに作る（呼ぶたびに新しく作る）
    // エディタの初期化と、画面の ViewModel を作るとき（いずれもメインスレッド）にだけ呼ぶ。

    /// AI 背景除去。エディタの初期化時に1つ作って AI ツールと共有し、編集画面を開くたびにも1つ作る
    let makeBackgroundRemover: @MainActor () -> any BackgroundRemovalProcessing

    /// 編集用画像の取得。手動背景除去・背景ぼかしマスクの画面を開くたびに作る
    let makeImageSourceResolver: @MainActor () -> any ImageSourceResolving

    /// 手動の背景ぼかし。背景ぼかしマスクの画面を開くたびに作る
    let makeManualBackgroundBlurUseCase: @MainActor () -> ManualBackgroundBlurUseCase
}
