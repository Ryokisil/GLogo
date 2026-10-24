# ElementViewModelの責務と分割候補

この文書は、選択要素の編集ViewModelを、操作と画面状態のまとまりごとに分ける候補を記録します。調査日: 2026-10-18。分割案は未実装です。

- 対象: [ElementViewModel.swift](../../../GLogo/ViewModels/ElementViewModel.swift)
- 全体方針: [比較と責務分離方針](../README.md)
- 関連: [EditorViewModel](EditorViewModel.md)、[編集履歴](../UseCases/History/EventSourcing.md)

## 確認した現状

- `@MainActor`の`ObservableObject`で、`EditorViewModel`をweak参照し、選択やAI処理・エラー状態をCombineで購読します。
- 共通属性・ジェスチャー、テキスト・効果、図形、画像調整、フレーム、フィルター、AI操作の入口を持ちます。
- スライダーや効果の操作開始値、ジェスチャーの基準状態、プリセット描画の世代番号を保持します。
- `ImageAdjustmentUseCase`等を呼び、確定イベントを親へ渡し、メタデータ記録も呼び出します。
- プリセット適用では即時プレビューを先に出し、高品質描画の完了時に世代番号と選択対象を確認します。

## 評価

### Warning

テキスト、図形、画像処理、変形は変更理由が異なり、不要な状態や依存まで同じ型に集まっています。親のAI状態を複製して購読する部分もあり、分割で同期先を増やすと状態管理がさらに複雑になります。

### Info

開始・プレビュー・確定の段階を分ける構造と、世代番号による古い描画結果の破棄は維持すべき強みです。UseCaseへ移っている判断を、新しいViewModelへ戻さないようにします。

## 責務別の分割候補

| ViewModel候補 | 移す状態・操作 | 主な接続先 |
| --- | --- | --- |
| `TextEditingViewModel` | 内容、フォント、行間・文字間隔、効果の編集と操作開始値 | Textパネル、共通の編集適用口 |
| `ShapeEditingViewModel` | 形状、塗り、線、角丸、多角形などの編集 | 図形表示、共通の編集適用口 |
| `ImageAdjustmentViewModel` | 調整スライダー・トーンカーブの入力と編集セッション | 既存の調整・セッション・描画更新UseCase |
| `ImageFrameViewModel` | 枠の色・種類・角丸と操作途中の状態 | Frameパネル、共通の編集適用口 |
| `FilterPanelViewModel` | プリセット選択、プレビュー要求、要求の世代と寿命 | `FilterPresetUseCase`、描画サービス |
| `ElementTransformViewModel` | 移動・拡縮・回転の基準値と同時ジェスチャーの状態 | Canvas、変形計算・編集確定処理 |

AIの表示状態は[EditorViewModel側の候補](EditorViewModel.md)に集約し、各子へ同じフラグとエラーを複製しません。共通属性の操作を既存`ElementViewModel`に残すか、選択要素の窓口にまとめるかは、最初の移行対象で決めます。

候補は全部を一度に導入する一覧ではありません。例えばテキスト編集だけを切り出し、状態とテストの境界が成立することを確認してから、次の機能へ進みます。

## ViewModelへ移さない処理

| 処理 | 維持・検討する層 |
| --- | --- |
| 開始値と確定値からイベントを作る | `ImageAdjustmentUseCase`等 |
| 画像フィルターの計算、レンダリング | 描画UseCase／Service／Renderer |
| メタデータの保存条件と永続化 | メタデータUseCase／保存サービス |
| Undo／Redoスタックと確定イベント適用 | 履歴UseCaseと共通の編集適用口 |
| 再利用できる座標・変形の純粋計算 | Model／計算用の既存型 |

## 移行時に守る契約

1. 選択要素の正は共通の所有者に置き、各子は対象IDと必要な状態を参照します。
2. 操作開始時の値は、操作開始時の対象に結び付けます。途中の選択変更で別要素へ確定しないようにします。
3. スライダー途中の一時変更と確定履歴を分け、一操作につき履歴を一度だけ作ります。無変更操作は既存の契約を維持します。
4. 複数ジェスチャーが重なった場合の基準値と終了条件を維持します。
5. 世代番号、スケジューラ、Taskを同じ操作所有者のもとで管理します。遅延実行のキャンセルだけで実行中の結果が無効になると仮定しません。
6. 親子間の全状態の転送を増やさず、Viewは必要な機能別状態を購読する配線を検討します。
7. `@StateObject`等による寿命管理と、選択がない状態・対象種別が異なる状態の表示を確認します。

## 影響するファイル境界

- 元の`ElementViewModel`だけでなく、`EditorViewModel`にある同じ機能の確定処理も確認します。
- `Views/Editor/BottomToolStrip`以下のパネル、`EditorBottomPanelHostView`、Canvas側の操作入口の受け渡しが変わります。
- `ImageAdjustmentUseCase`、`ImageEditingSessionUseCase`、`ImageRenderRefreshUseCase`、`FilterPresetUseCase`の所有者と寿命が変わる可能性があります。
- 確定イベントとメタデータ記録の順序を変える場合、保存・Revert・Undoを合わせて検証します。

## テストと完了条件

既存の関連テスト:

- [TextSliderHistoryIntegrationTests](../../../GLogoTests/Integration/TextSliderHistoryIntegrationTests.swift)
- [FrameColorHistoryIntegrationTests](../../../GLogoTests/Integration/FrameColorHistoryIntegrationTests.swift)
- [NoOpGestureIntegrationTests](../../../GLogoTests/Integration/NoOpGestureIntegrationTests.swift)
- [FilterAdjustSeparationTests](../../../GLogoTests/Unit/FilterAdjustSeparationTests.swift)
- [ImageUndoCacheInvalidationTests](../../../GLogoTests/Unit/ImageUndoCacheInvalidationTests.swift)
- [EditorPanelUITests](../../../GLogoUITests/EditorPanelUITests.swift)

`FilterAdjustSeparationTests`には、即時プレビューを先に表示することと、古い非同期描画が新しいプリセット状態へ反映されないことを検証するテストがあります。

追加・再確認候補は、編集中の選択切り替え、パネル切り替え、子ViewModelの再生成、Undo後の古い描画完了です。実時間の待機に頼りすぎず、完了順を制御できる代替実装を使うテストを検討します。

移行完了はファイルが小さくなったことではなく、対象機能が限定された依存で検証でき、親に同じ状態・処理が残っていないことで判断します。今回の記録ではテストを実行していません。
