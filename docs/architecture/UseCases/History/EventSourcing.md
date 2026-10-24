# 編集履歴と画面Eventの境界

この文書は、`EventSourcing.swift`が担う編集履歴と、ViewModel分割後も守る適用・取り消しの契約を記録します。調査日: 2026-10-18。改善案は未実装です。

- 対象: [EventSourcing.swift](../../../../GLogo/UseCases/History/EventSourcing.swift)
- 全体方針: [比較と責務分離方針](../../README.md)
- 関連: [ElementViewModel](../../ViewModels/ElementViewModel.md)、[ImageElement](../../Models/ImageElement.md)

## 確認した現状

- `EditorEvent`は編集内容の適用・取り消しを表現します。
- `EditorHistory`は実行済み・取り消し済みのスタックを持ちます。
- `recordAndApply`はイベントを適用して履歴へ追加し、取り消し済み履歴を消去します。
- 履歴は既定で最大100件です。Undoは`revert`、Redoは`apply`を呼びます。
- `EditorViewModel`は履歴操作後に選択・変更フラグ・画面通知を調整します。
- 一つのファイルに履歴管理本体と多数の編集イベント型があります。

## HandsPOSのEventとの違い

| 対象 | 役割 | 例 |
| --- | --- | --- |
| HandsPOSの画面Event | 単発の画面操作を通知する | 確認アラート、遷移、HUD操作 |
| GLogoの編集履歴Event | Modelの変更を適用・取り消しする | 明るさ変更、要素追加、文字色変更 |

GLogoで確認した中心機構は上限付きのUndo／Redoです。`EditorEvent`がCodableであることだけをもって、永続イベントログを唯一の正として復元するイベントソーシング基盤とは扱いません。写真ライブラリ保存や外部の決済を、編集Undoと同じように取り消せると考えないことも重要です。

## 評価と分離方針

### Warning

履歴上の値、画像キャッシュ、メタデータ、初期状態への復元、画面通知は同じ機能に関係しながら別の経路に分かれます。機能別ViewModelを増やすときに、それぞれが独自の確定・履歴スタックを持つと整合性を保ちにくくなります。

### Info

適用と取り消しをイベントごとに定義する構造は、編集アプリに適しています。操作途中のプレビューと確定履歴を分ける既存の仕組みを維持します。

ファイル整理が必要な場合は、まず`EditorHistory`の管理責務とイベント群を区別します。その後、画像調整、テキスト、図形、プロジェクト操作などの責務単位でイベントを整理する案を検討します。関連する小さなイベント型まで機械的に一型一ファイルへ分ける必要はありません。

## 確定変更の共通契約

1. 子ViewModelは操作途中の状態を持ち、確定内容を共通の編集適用口へ渡します。
2. 共通の適用口が一度だけ履歴へ記録し、必要なキャッシュ無効化・変更通知を整えます。正確な配置は既存イベントの副作用を確認して決めます。
3. プレビューで一時変更した値と、開始時の値を取り違えないようにします。
4. Undo／Redoはイベントを一つ戻す操作、Revertは初期状態へ戻す操作として別々に検証します。Revert自体の取り消し契約も維持します。
5. 新しい永続属性には、イベントの旧値・新値、コピー、Codable、初期スナップショット、メタデータ、描画キーへの影響を確認します。

## テストと完了条件

- [ImageUndoCacheInvalidationTests](../../../../GLogoTests/Unit/ImageUndoCacheInvalidationTests.swift): apply／revert時の値とキャッシュ無効化。
- [RevertUndoSequenceIntegrationTests](../../../../GLogoTests/Integration/RevertUndoSequenceIntegrationTests.swift): Revert後のUndoで直前状態へ戻ること。
- [RevertSnapshotRegressionTests](../../../../GLogoTests/Regression/RevertSnapshotRegressionTests.swift): 初期状態の保持・復元。
- [TextSliderHistoryIntegrationTests](../../../../GLogoTests/Integration/TextSliderHistoryIntegrationTests.swift): テキスト編集と履歴。
- [FrameColorHistoryIntegrationTests](../../../../GLogoTests/Integration/FrameColorHistoryIntegrationTests.swift): 枠色編集と履歴。
- [NoOpGestureIntegrationTests](../../../../GLogoTests/Integration/NoOpGestureIntegrationTests.swift): 無変更操作の回帰確認先。

機能分割後は、一操作一履歴、無変更時の履歴、Undo後の新操作によるRedo破棄、選択変更と非同期完了を含めて確認します。既存テストが新しい属性や経路を実際に検証しているかも、回帰テストのレビューで確認します。今回の記録ではテストを実行していません。
