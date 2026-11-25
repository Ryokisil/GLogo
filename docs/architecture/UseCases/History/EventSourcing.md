# 編集履歴と画面Eventの境界

この文書は、編集履歴（`GLogo/UseCases/History/`）と、ViewModel分割後も守る適用・取り消しの契約を記録します。調査日: 2026-10-18。2026-10-29 に非同期結果の照合に使う履歴移動の世代を追記しました。2026-11-05 の段階3・第8回で、使われていない処理を削除し、`EventSourcing.swift` を履歴管理と機能別のイベントのファイルへ分けました。

- 対象: [EditorEvent](../../../../GLogo/UseCases/History/EditorEvent.swift)、[EditorHistory](../../../../GLogo/UseCases/History/EditorHistory.swift)、[Events](../../../../GLogo/UseCases/History/Events)（機能別のイベント7ファイル）
- 全体方針: [比較と責務分離方針](../../README.md)
- 関連: [ElementViewModel](../../ViewModels/ElementViewModel.md)、[ImageElement](../../Models/ImageElement.md)

## 確認した現状

- `EditorEvent`は編集内容の適用・取り消しを表現します。
- `EditorHistory`は実行済み・取り消し済みのスタックを持ちます。
- `recordAndApply`はイベントを適用して履歴へ追加し、取り消し済み履歴を消去します。
- 履歴は既定で最大100件です。Undoは`revert`、Redoは`apply`を呼びます。
- `EditorViewModel`は履歴操作後に選択・変更フラグ・画面通知を調整します。
- 第8回で、境界の `EditorEvent`、履歴管理の `EditorHistory`、機能別のイベント（要素・テキスト・図形・画像の調整値・フレーム・画像の内容・プロジェクト）の7ファイルに分けました。イベントは57種類です。分ける前は、一つのファイル（2,704行）に履歴管理本体とすべてのイベント型がありました。
- 画像の Revert と差し替えのイベントは、編集値30項目を `ImageEditState` で記録します（第8回）。

## 非同期要求と履歴移動

`restorationRevision` は成功した Undo／Redo、`setProject`、`clearHistory` で増加し、以前の値へ戻しません。対象のない Undo／Redo と通常の `recordAndApply` では増加しません。別の要素の通常編集は保留中の AI を失効させず、履歴を移動した場合は対象画像の値が同じでも失効させる方針です。

[ImageEditTokenTests](../../../../GLogoTests/Unit/ImageEditTokenTests.swift) と [AIResultValidityIntegrationTests](../../../../GLogoTests/Integration/AIResultValidityIntegrationTests.swift) で世代の更新と古い完了結果の破棄を検証しています。既存の Revert・Undo・画像キャッシュの回帰テストも引き続き有効で、今回の関連67件の検証に含めました。履歴イベントの保存形式は変更していません。

## HandsPOSのEventとの違い

| 対象 | 役割 | 例 |
| --- | --- | --- |
| HandsPOSの画面Event | 単発の画面操作を通知する | 確認アラート、遷移、HUD操作 |
| GLogoの編集履歴Event | Modelの変更を適用・取り消しする | 明るさ変更、要素追加、文字色変更 |

GLogoで確認した中心機構は上限付きのUndo／Redoです。名前に反して、永続イベントログを唯一の正として復元するイベントソーシング基盤ではなく、変更前後の値を持つコマンド型の履歴です。履歴は保存しないため、第8回で使われていなかった `EditorEvent` の Codable 準拠と、各イベントの名前・日時を削除しました。写真ライブラリ保存や外部の決済を、編集Undoと同じように取り消せると考えないことも重要です。

## 評価と分離方針

### Warning

履歴上の値、画像キャッシュ、メタデータ、初期状態への復元、画面通知は同じ機能に関係しながら別の経路に分かれます。機能別ViewModelを増やすときに、それぞれが独自の確定・履歴スタックを持つと整合性を保ちにくくなります。

### Info

適用と取り消しをイベントごとに定義する構造は、編集アプリに適しています。操作途中のプレビューと確定履歴を分ける既存の仕組みを維持します。

ファイル整理は、まず`EditorHistory`の管理責務とイベント群を区別し、その後に責務単位でイベントを整理する方針でした。第8回でこの方針どおりに分け、関連する小さなイベント型は一型一ファイルにせず、責務ごとのファイルにまとめました。

## 確定変更の共通契約

1. 子ViewModelは操作途中の状態を持ち、確定内容を共通の編集適用口へ渡します。
2. 共通の適用口が一度だけ履歴へ記録し、必要なキャッシュ無効化・変更通知を整えます。正確な配置は既存イベントの副作用を確認して決めます。
3. プレビューで一時変更した値と、開始時の値を取り違えないようにします。
4. Undo／Redoはイベントを一つ戻す操作、Revertは初期状態へ戻す操作として別々に検証します。Revert自体の取り消し契約も維持します。
5. 新しい永続属性には、イベントの旧値・新値、コピー、Codable、初期スナップショット、メタデータ、描画キーへの影響を確認します。画像の編集値を追加するときは、`ImageEditState`（または構成する値型）、`ImageElement` の `editState`・`applyEditState`、初期スナップショットとの変換を更新します。Revert・差し替えのイベントと複製の処理は変更不要です。あわせて、テストの `ImageEditStateRecord` と、初期スナップショットのキー一覧（`RevertSnapshotRegressionTests`）にも項目を足します。足さないと、新しい項目の記録漏れをテストで検出できません。

## テストと完了条件

- [ImageUndoCacheInvalidationTests](../../../../GLogoTests/Unit/ImageUndoCacheInvalidationTests.swift): apply／revert時の値とキャッシュ無効化。第8回で、Revert・画像差し替えの Undo／Redo で古い描画キャッシュを使わないことを追加。
- [RevertUndoSequenceIntegrationTests](../../../../GLogoTests/Integration/RevertUndoSequenceIntegrationTests.swift): Revert後のUndoで直前状態（編集値30項目と色の値そのもの）へ戻ること。
- [RevertSnapshotRegressionTests](../../../../GLogoTests/Regression/RevertSnapshotRegressionTests.swift): 初期状態の保持・復元と、保存データの初期スナップショットのキー30個と値の表現（書き出しと、手書きの固定 JSON の読み込み）。
- [ImageContentReplacedEventTests](../../../../GLogoTests/Integration/ImageContentReplacedEventTests.swift): 画像差し替え（手動背景除去・高画質化）の Undo／Redo で、画像ソース・配置サイズ・編集値30項目が戻ること。
- [ImageEditStateTests](../../../../GLogoTests/Unit/ImageEditStateTests.swift): 編集値30項目の取り出しと反映に漏れがないこと。
- [TextSliderHistoryIntegrationTests](../../../../GLogoTests/Integration/TextSliderHistoryIntegrationTests.swift): テキスト編集と履歴。
- [FrameColorHistoryIntegrationTests](../../../../GLogoTests/Integration/FrameColorHistoryIntegrationTests.swift): 枠色編集と履歴。
- [NoOpGestureIntegrationTests](../../../../GLogoTests/Integration/NoOpGestureIntegrationTests.swift): 無変更操作の回帰確認先。

機能分割後は、一操作一履歴、無変更時の履歴、Undo後の新操作によるRedo破棄、選択変更と非同期完了を含めて確認します。既存テストが新しい属性や経路を実際に検証しているかも、回帰テストのレビューで確認します。2026-10-18 の調査時点ではテストを実行していません。後続の履歴世代追加に対する検証は上記に記録しています。第8回の検証は [ImageElement](../../Models/ImageElement.md) の第8回に記録しています。
