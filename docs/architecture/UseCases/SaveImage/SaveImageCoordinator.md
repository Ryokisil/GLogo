# SaveImageCoordinatorの保存境界と非同期所有

この文書は、写真ライブラリへ保存する処理のDIと、保存対象の状態を固定するための検討事項を記録します。調査日: 2026-10-18。改善案は未実装です。

- 対象: [SaveImageCoordinator.swift](../../../../GLogo/UseCases/SaveImage/SaveImageCoordinator.swift)
- 全体方針: [比較と責務分離方針](../../README.md)
- 関連: [EditorViewModel](../../ViewModels/EditorViewModel.md)、[ImageElement](../../Models/ImageElement.md)、[プロジェクト永続化](../Storage/ProjectStorage.md)

## 確認した処理の流れ

1. `EditorViewModel.performPhotoLibrarySave`が編集中状態の準備と保存中フラグの更新を行います。
2. Coordinatorが保存モードを判定し、写真ライブラリ権限を確認します。
3. バックグラウンドで対象画像を選び、フィルター適用または合成を行います。
4. Writerが画像を書き込み、結果をMainActor上のcompletionへ返します。
5. ViewModelが保存中フラグと失敗理由を更新し、画面へ結果を伝えます。

これは写真ライブラリへの画像書き出しです。`ProjectStorage`による編集可能なプロジェクトのJSON保存とは別の経路です。

## 良い境界

| 依存 | 責務 |
| --- | --- |
| `SaveImagePolicy` | 保存モードの判定 |
| `ImageSelecting` | 保存対象・ベース画像の選定 |
| `ImageProcessing` | フィルター適用・合成 |
| `PhotoLibraryWriting` | 権限確認と写真ライブラリへの書き込み |

依存は初期化時に注入でき、異常系を代替実装で再現できます。合成失敗を元画像の保存成功に置き換えず、`PhotoLibrarySaveFailure`で分類する契約もあります。

## Warning: 保存入力の所有

`DetachedProjectBox: @unchecked Sendable`は、渡された`LogoProject`への参照を保持します。`Task.detached`はそのプロジェクトと要素を読み取ります。保存専用の独立したスナップショットを作る実装ではありません。

UIには保存中の操作抑止がありますが、次は別に確認する必要があります。

- 保存開始前に起動したAI・描画処理が、保存中に同じ要素を書き換える可能性。
- 権限ダイアログを待つ間の変更と、保存モード判定時・描画時の状態の一致。
- ViewModel以外の入口からCoordinatorを使う場合の入力の扱い。
- 完了時点で画面・編集対象が変わっている場合の表示更新。

今回、競合を再現したものではありません。`@unchecked Sendable`だけでは状態の安全性は保証されず、実装側の同期・所有契約が必要です。[SwiftのSendableドキュメント](https://docs.swift.org/latest/documentation/swift/sendable/)

## 最小変更の検討案

1. 保存対象を固定する時点を定義します。保存ボタン押下時か、権限取得後かを決め、モード判定と描画入力を揃えます。
2. 編集値、要素順、対象画像など、保存に必要な入力を編集状態から切り離す案を検討します。単に同じ参照を別の箱へ入れるだけでは解決しません。
3. 画像資源はメモリ負荷と寿命を考慮して保持します。可変なModelグラフの全面コピーを無条件に採用しません。
4. AI・描画の完了結果が編集中Modelへ反映される条件を明確にし、保存入力への影響を分離します。
5. 画面側を`ImageSaveViewModel`へ分ける場合も、選定・加工・書き込みの責務はCoordinator以下に残します。

`Task.detached`を除去すること自体は目的ではありません。高負荷処理をUIから分離しつつ、安全に渡せる入力と結果反映の所有者を設計します。

## 変更範囲と影響

候補はCoordinator、そのProtocol境界、`ImageProcessingService`、呼び出し元のViewModel、保存入力用の値型です。実際のファイル追加・API変更は、入力固定方式を決めてから最小範囲を確定します。

- 画像の色空間、解像度、向き、透明度、フレーム、テキスト・図形の合成を維持する必要があります。
- 保存準備で編集中状態を終了する処理と、確定履歴の順序を確認します。
- 保存用入力は実行時のデータとして設計し、プロジェクトのCodable形式変更とは分けます。
- 子ViewModelの解放・画面終了時に、画像書き込みとUI通知をどう扱うかを定義します。書き込みを開始した処理のキャンセル可否を仮定しません。

## テストと完了条件

既存の関連テスト:

- [SaveCoordinatorRegressionTests](../../../../GLogoTests/Regression/SaveCoordinatorRegressionTests.swift): モード判定、合成失敗、ベース画像や枠の保存結果。
- [SaveCoordinatorMainActorCompletionRegressionTests](../../../../GLogoTests/Regression/SaveCoordinatorMainActorCompletionRegressionTests.swift): 権限処理後のMainActor上の完了通知。
- [SavePipelineRegressionTests](../../../../GLogoTests/Regression/SavePipelineRegressionTests.swift): 保存画像の回帰確認先。
- [PhotoLibrarySaveIntegrationTests](../../../../GLogoTests/Integration/PhotoLibrarySaveIntegrationTests.swift): 保存経路の結合確認先。

追加・再確認候補:

- 権限待ち・加工待ちの間に編集側が変更されても、定義した時点の内容で保存されること。
- AI完了、Undo、要素削除と保存が重なる場合の契約。
- 書き込み失敗・連打・所有者の終了後に保存中表示や結果通知が不整合にならないこと。
- 入力固定による4K／8K画像のメモリ・保存時間への影響。

完了順を制御する代替実装で検証し、実際の写真ライブラリ検証とは分けます。今回の記録ではテストを実行していません。
