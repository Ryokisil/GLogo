# ElementViewModelの責務と分割候補

この文書は、選択要素の編集ViewModelを、操作と画面状態のまとまりごとに分ける候補を記録します。調査日: 2026-10-18。テキスト・画像フレーム・AI・変形に続き、2026-10-27 に図形編集、画像調整、フィルターを分離しました。

- 対象: [ElementViewModel.swift](../../../GLogo/ViewModels/ElementViewModel.swift)
- 全体方針: [比較と責務分離方針](../README.md)
- 関連: [EditorViewModel](EditorViewModel.md)、[編集履歴](../UseCases/History/EventSourcing.md)

## 確認した現状

- `@MainActor`の`ObservableObject`で、`EditorViewModel`をweak参照し、選択をCombineで購読します。AI は親と同じ `AIToolsViewModel` を保持し、状態を複製せず通知だけを転送します。
- 共通属性と AI 操作の入口、各子 ViewModel の組み立てを持ちます。テキスト・効果は `textEditing`、図形は `shapeEditing`、フレームは `imageFrame`、画像調整は `imageAdjustment`、フィルターは `filters`、変形は共有の `transform` へ分離しています。
- 操作開始値や選択変更時の破棄は各子が担当します。画像調整とフィルターは同じ `ImageRenderRefreshUseCase` を共有し、予約と実行中描画の世代を一元管理します。
- 画像調整の確定イベント生成・メタデータ記録と、プリセットの適用計画は既存 UseCase を使い、共通の編集適用先へ届きます。
- プリセットは即時プレビューを先に出します。高品質描画の前後で世代を確認し、有効な結果だけをキャッシュと表示へ反映します。

## 評価

### Warning

今回の分離による新たな指摘はありません。後続の段階1で保存入力を固定し、AI・Undo・削除をまたぐ高品質描画と調整の遅延通知にも対象照合を追加しました。後続で Task の取消伝達と工程境界での終了も実装済みです。実機の負荷・取消応答測定は残件です。実装・検証範囲は末尾を参照してください。

### Info

開始・プレビュー・確定の段階を分ける構造と、世代番号による古い描画結果の破棄は維持すべき強みです。UseCaseへ移っている判断を、新しいViewModelへ戻さないようにします。

## 責務別の分割候補

| ViewModel候補 | 移す状態・操作 | 主な接続先 |
| --- | --- | --- |
| `TextEditingViewModel`（実装済み） | 内容、フォント、行間・文字間隔、効果の編集と操作開始値 | Textパネル、`TextEditApplying` |
| `ShapeEditingViewModel`（実装済み） | 図形の選択参照、形状、塗り、線、角丸、多角形などの編集 | `ShapeEditorPanel`、`ShapeEditUseCase` |
| `ImageAdjustmentViewModel`（実装済み） | 調整スライダー・トーンカーブの入力と編集セッション | 既存の調整・セッション・描画更新UseCase |
| `ImageFrameViewModel`（実装済み） | 枠の色・種類・幅・角丸と操作途中の状態 | Frameパネル、`ImageFrameEditApplying`、既存の調整・メタデータUseCase |
| `FilterPanelViewModel`（実装済み） | プリセット選択、プレビュー要求と選択参照 | `FilterPresetUseCase`、共有の `ImageRenderRefreshUseCase` |
| `ElementTransformViewModel`（実装済み） | 移動・拡縮・回転の基準値と同時ジェスチャーの状態 | Canvas、`ElementTransformState`、`ElementTransformUseCase`、既存の描画 UseCase |

AIの表示状態は共有の `AIToolsViewModel` に集約済みです。既存パネルは `ElementViewModel` の計算プロパティと操作入口を通じて子を参照し、子の `objectWillChange` は同期転送します。選択変更時のエラークリアも子が担当します。詳細と検証は [EditorViewModel の記録](EditorViewModel.md)を参照してください。共通属性の操作は現在の `ElementViewModel` に残しています。

候補は全部を一度に導入する一覧ではありません。例えばテキスト編集だけを切り出し、状態とテストの境界が成立することを確認してから、次の機能へ進みます。

### テキスト編集の分離（2026-10-25）

- `ElementViewModel` が `TextEditingViewModel` を一度生成・保持し、`TextPropertyPanelView` と従来の `TextEditorPanel` は子を直接 `@ObservedObject` として購読します。親には同じテキスト状態や操作メソッドを残していません。
- 子は `EditorViewModel.$selectedElement` の現在値と変更を同期購読します。MainActor 上で選択を即座に反映し、RunLoop 待ちの間に旧要素へ確定されることを防ぎます。別 ID・非テキスト・未選択への切り替えで開始値を破棄し、同じ ID のプレビュー通知では開始値を維持します。
- 子からは `TextEditApplying` のテキスト操作だけを呼びます。`TextEditUseCase` がこれを実装し、確定変更は `ElementEditApplying` を介して従来どおり共通の `EditorHistory` に届きます。子に独立した履歴はありません。
- プレビューはテキスト参照の変更を子から通知し、`updateTextElement` を通して共通の変更フラグを更新します。イベントを作る確定操作と、履歴を積まない既存のプレビュー・整列・効果追加削除の区別を維持しています。
- 子は UseCase を保持し、UseCase が共通の編集適用先を弱参照します。選択の購読は子を弱参照し、子の破棄で購読が解除されます。子だけを保持しても親やエディタを延命しません。
- 保存、レンダラー、Codable、メタデータ、画像 Revert は変更していません。既存テストの履歴の期待値を維持し、呼び出し先だけを `elementViewModel.textEditing` に移しました。

回帰テストの確認:

- `TextSliderHistoryIntegrationTests` の6件は引き続き有効です。フォント・行間・文字間隔・シャドウ・ストローク・グローの一操作一履歴と Undo を保護します。
- [TextEditingViewModelTests](../../../GLogoTests/Integration/TextEditingViewModelTests.swift) に、8種類の開始値破棄、非テキスト／未選択、通知、無変更操作、グラデーションの Undo／Redo、即時確定、参照寿命を追加しました。
- `EditorPanelUITests` の主要タブ表示を維持し、サイズスライダーの変更が同じパネルの値表示に届く UI テストを追加しました。

検証結果（2026-10-25）:

- iPhone 17 Pro／iOS 26.1 で `xcodebuild test` を2回実行し、計27件が成功しました。
  - `TextSliderHistoryIntegrationTests` 6件、`NoOpGestureIntegrationTests` 7件、`ViewModelMemoryLeakTests` 3件。
  - `TextEditingViewModelTests` 9件、`EditorPanelUITests` の `testEditor_TextPropertyPanel_ShowsPrimaryTabs` と `test_textSize_slider_updatesValue` の2件。
- 両実行の共通引数は `-project GLogo.xcodeproj -scheme GLogo -configuration Debug -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18'`。上記対象をそれぞれ `-only-testing:` で指定しました。
- 移した操作本体を旧実装と照合し、委譲先の名前変更以外に差がないことを確認しました。`git diff --check` も成功しました。
- `swiftformat GLogo/ --lint` は実行を試みましたが、未インストールのため検証できませんでした。全スイート・実機・保存画像の比較は、今回変更したテキスト状態と接続の検証範囲には含めていません。
- 変更後レビューでは差分に Critical／Warning の指摘はありません。選択 Publisher が MainActor で同期通知される契約を、生成箇所と初期化時の DocC に明記しています。

### 画像フレーム編集の分離（2026-10-25）

- `ElementViewModel.imageFrame` が子を保持し、`FramePanelView` と従来の画像パネル内の `ImageFrameControlsView` が直接購読します。画像選択の正は引き続き `EditorViewModel` に置き、子はその参照を表示に使います。
- フレームの表示・色・スタイル・角丸設定は子へ移し、`ImageFrameEditApplying` を実装する `ImageEditUseCase` を通して共通の履歴と変更フラグへ反映します。子が UseCase を保持し、UseCase は編集適用先を弱参照します。移動した操作本体は委譲先の名前変更以外、旧実装と一致します。
- 幅と角丸半径には専用の `Adjustment` を使います。子の `ImageAdjustmentUseCase` が開始値を保持し、既存の descriptor でイベントを生成します。他の画像調整の開始値とは別に管理します。
- `ImageEditingSessionUseCase`、`ImageRenderRefreshUseCase`、`ImageMetadataEditUseCase` を再利用し、プレビュー → 履歴確定 → メタデータ記録 → 表示更新の順序を維持します。幅と角丸半径は従来どおり遅延描画を使いません。
- MainActor 上の同期選択通知で色・幅・半径の開始値を破棄し、旧画像の編集状態を終了します。同じ画像のプレビュー通知では開始値を保ちます。
- 保存・レンダラー・Codable・Revert の実装や形式は変更していません。親の汎用画像調整 API は他のパネル用に残り、フレーム UI の幅・半径の呼び出しは子へ移行済みです。

回帰テストの確認:

- `FrameColorHistoryIntegrationTests` は引き続き有効で、期待値を維持し呼び出し先だけを変更しました。
- `SaveCoordinatorRegressionTests` はフレーム付き画像の保存、`RevertSnapshotRegressionTests` と `RevertUndoSequenceIntegrationTests` は復元と履歴の契約を引き続き保護します。
- [ImageFrameViewModelTests](../../../GLogoTests/Integration/ImageFrameViewModelTests.swift) に、幅・半径とスタイルの履歴、選択境界、非画像選択、通知、フレーム変更後の Revert／Undo、メタデータ記録、参照寿命を追加しました。
- `EditorPanelUITests` の既存フレーム2件に加え、幅スライダーの表示更新と削除後の操作抑止を確認するテストを追加しました。

検証結果（2026-10-25）:

- iPhone 17 Pro／iOS 26.1 で `xcodebuild test` を2回実行し、計26件が成功しました。
  - `FrameColorHistoryIntegrationTests` 2件、`SaveCoordinatorRegressionTests` 6件、`RevertSnapshotRegressionTests` 6件、`RevertUndoSequenceIntegrationTests` 1件。
  - `ImageFrameViewModelTests` 8件、`EditorPanelUITests` の `testEditor_FramePanel_ShowsPresets`、`testEditor_FramePanel_SelectsPreset`、`test_frameWidth_slider_updatesValue` の3件。
- 共通引数は `-project GLogo.xcodeproj -scheme GLogo -configuration Debug -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18'`。上記対象を `-only-testing:` で指定しました。
- 移動した操作本体の照合と `git diff --check` は成功しました。変更後レビューでは今回の差分に Critical／Warning の指摘はありません。
- `swiftformat GLogo/ --lint` は未インストールのため実行できませんでした。全スイート・実機・従来の画像パネルのUI操作は未検証です。従来パネルはビルドと接続のソース確認を行いました。

テキスト・図形・画像属性のイベント生成を親から UseCase へ移した時点の検証は、[EditorViewModel の記録](EditorViewModel.md)を参照してください。後続の図形操作・状態の分離は以下に記録します。

### 図形編集の分離（2026-10-27）

- [ShapeEditingViewModel](../../../GLogo/ViewModels/ShapeEditingViewModel.swift) が図形参照と11個の操作を所有し、`ElementViewModel.shapeEditing` が一度生成・保持します。親の `shapeElement` と図形操作は削除し、`ShapeEditorPanel` は子を直接購読します。`ToolPanelView` の生成箇所も子へ接続しました。
- 選択は MainActor 上で同期購読し、初期値・別図形・非図形・未選択を即座に反映します。確定変更と Undo／Redo では共通の選択通知を受け、同じ図形参照のプロパティ変更もパネルへ通知します。
- 子は既存 `ShapeEditUseCase` を保持し、UseCase は共通適用先を弱参照します。親・エディタを延命する参照や独立した履歴スタックは追加していません。
- カスタム頂点の更新は `ShapeEditUseCase.updateCustomPoints` に委譲し、従来どおり履歴なしで変更フラグと選択を更新します。その他10操作の無変更判定とイベント生成・適用は維持しました。スライダーの履歴粒度、保存形式・Codable・描画・メタデータも変更していません。
- `ElementViewModel.swift` は 598 → 508 行、`EditorViewModel.swift` は 813 行のままです。

回帰テストの棚卸し:

- 引き続き有効: `ShapeEditUseCaseTests` の図形10操作と復元、`ElementEditIntegrationTests` の共通履歴と選択、`ViewModelMemoryLeakTests`。図形パネルの接続テストは子への呼び出しへ変更し、期待値を維持しました。
- 追加: [ShapeEditingViewModelTests](../../../GLogoTests/Integration/ShapeEditingViewModelTests.swift) の6件で、同期選択、非図形・未選択、10操作の無変更判定、Undo／Redo通知、カスタム頂点の既存契約、親子の寿命を検証します。
- 共通親から図形状態を除いた影響として、`ElementTransformViewModelTests` の選択・保存・Canvas・描画終了も再確認します。

検証結果（2026-10-27）:

- iPhone 17 Pro／iOS 26.1 で22件成功、失敗・スキップなしを xcresult で確認しました。対象は `ShapeEditUseCaseTests` 1件（10操作）、`ElementEditIntegrationTests` 3件、`ViewModelMemoryLeakTests` 3件、`ShapeEditingViewModelTests` 6件、`ElementTransformViewModelTests` 9件です。
- 実行は `xcodebuild -project GLogo.xcodeproj -scheme GLogo -configuration Debug -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18'` に対象を `-only-testing:` で指定した `test`。パネルの型・生成箇所を含めてビルドしました。
- 変更後レビュー: 新規 Critical／Warning なし。状態の単一所有、MainActor の同期通知、UseCase から親への弱参照、共通の履歴、無変更操作、カスタム頂点の履歴なし反映を確認しました。操作本体は委譲先の変更以外、移動前と一致しました。
- `git diff --check`、新規 Swift ファイルの空白検査、更新文書の相対リンク確認は成功しました。
- 未実施: `swiftformat GLogo/ --lint` は未インストールのため実行不可。全スイート・実機・図形パネルの UI 操作・保存画像比較は未実施です。今回のパネル接続は既存 `ToolPanelView` 内を変更しており、現在の主画面の下部ツールへ図形パネルを追加する変更はしていません。パネル通知の検証と UI の実操作検証は区別しています。

## ViewModelへ移さない処理

| 処理 | 維持・検討する層 |
| --- | --- |
| 開始値と確定値からイベントを作る | `TextEditUseCase`、`ShapeEditUseCase`、`ImageEditUseCase`、`ImageAdjustmentUseCase`等 |
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

編集中の選択切り替え・同一画像への再選択・描画待機中の所有者解放は、下記の追加テストで確認しました。Undo 後の古い描画完了は後続の競合テストで検証しました。パネル切り替えをまたぐ連続操作と子 ViewModel の再生成は追加検証の候補です。

移行完了はファイルが小さくなったことではなく、対象機能が限定された依存で検証でき、親に同じ状態・処理が残っていないことで判断します。2026-10-18 の調査時点ではテストを実行していません。テキスト分離後の検証結果は上記に記録しています。

### 画像調整・フィルターの分離（2026-10-27）

- `ElementViewModel.imageAdjustment` と `.filters` が子を保持します。Adjust・Effects は前者、Filters の SDR／HDR は後者を直接購読します。AI パネルと従来の画像パネルも、調整値について前者を直接購読します。
- 選択参照は `EditorViewModel.$selectedElement` を MainActor で同期購読します。別 ID・非画像・未選択で編集状態、開始値、描画予約を破棄し、同じ ID のプレビュー通知では継続します。親の遅延購読から編集状態を終了する処理は取り除きました。
- スライダーの一操作一履歴、確定時のメタデータ記録、プリセットと手動値の分離を維持します。トーンカーブは従来どおり履歴を追加しません。ティントは既存のイベントとメタデータ契約を使います。保存形式・調整 descriptor・フィルター計算式は変更していません。
- 再描画の順序は共有の `ImageRenderRefreshUseCase` が所有します。スケジューラから届く古いコールバックと、既に開始した高品質描画の古い完了を世代で破棄します。手動値変更・選択変更・次のフィルター要求で無効化され、同じ画像への再選択でも旧要求は復活しません。
- 高品質描画の待機中は ViewModel／UseCase を強参照しません。実行中の画像計算自体は中断せず、古い結果の適用を止めます。保存・AI・Undo・画像ソース置換との全体的な競合制御は段階1の残件です。
- `ElementViewModel.swift` は 508 → 246 行、`EditorViewModel.swift` は 813 行のままです。

回帰テストの棚卸し:

- `FilterAdjustSeparationTests` と `ImageUndoCacheInvalidationTests` は引き続き有効です。呼び出し先のみ子へ変更し、既存の期待値は維持しました。
- フレーム・保存・Revert・メタデータ復元の既存テストも契約が変わらず有効です。保存形式の追加はありません。
- Filters の既存 UI テストは対象指定が一部古く、接頭辞検索で `original.favorite` を選んでいました。適用ボタンを `natural` に一意化し、右上のお気に入り領域を避けてカード本体を押す操作に修正しました。適用後のリセット有効化という期待値は維持し、リセット後の無効化も確認します。
- 新しい [ImageRenderRefreshUseCaseTests](../../../GLogoTests/Unit/ImageRenderRefreshUseCaseTests.swift) と [ImageAdjustmentViewModelTests](../../../GLogoTests/Integration/ImageAdjustmentViewModelTests.swift) は、完了順逆転、取消後の通知、手動調整と描画の競合、即時選択切り替え、同一画像への再選択、描画待機中の所有者解放、確定時の履歴・メタデータを保護します。

既存仕様の注意点:

- **Warning（既存）**: 明るさのメタデータキーは `brigthtnessAdjustment` です。今回の新規テストで `brightnessAdjustment` を期待して失敗し、descriptor と書き込み実装から既存の綴りを確認しました。キーの移行は保存互換性を伴う別作業です。
- **Info（既存）**: 開始値のない再確定は共通編集履歴に追加されませんが、メタデータ履歴は同値でも追加されます。新規テストでは初回の記録内容と再確定時の両履歴を分けて確認し、既存挙動を固定しました。
- **Warning（既存）**: SDR プリセットの72ptカードに重ねた40ptのお気に入り領域が、中央タップを受け取ります。失敗時の UI 記録で `natural.favorite` が「お気に入りから削除」に変わり、プリセット未適用のままであることを確認しました。今回の ViewModel 分離ではレイアウトを変えていません。タップ領域の見直しは別作業です。

検証結果（2026-10-28、停止後の再開を含む）:

- 単体・統合57件と UI 5件、計62件の成功を確認しました。再実行した同じテストは重複して数えていません。
  - 単体・統合: `ImageRenderRefreshUseCaseTests` 3件、`ImageAdjustmentViewModelTests` 5件、`FilterAdjustSeparationTests` 10件、`ImageUndoCacheInvalidationTests` 4件、`ElementTransformViewModelTests` 9件、`ViewModelMemoryLeakTests` 3件、`ImageFrameViewModelTests` 8件、`SaveCoordinatorRegressionTests` 6件、`RevertSnapshotRegressionTests` 6件、`RevertUndoSequenceIntegrationTests` 1件、`ImageElementMetadataRevertUseCaseRegressionTests` 2件。
  - UI: `EditorPanelUITests` の Adjust 値更新・リセット、Effects 値更新、AI Enhance 表示、Filters プリセット適用・リセット。
- 共通コマンドは `xcodebuild -project GLogo.xcodeproj -scheme GLogo -configuration Debug -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18'` に対象ごとの `-only-testing:` と `test` を指定しました。Filters 最終再実行は `-parallel-testing-enabled NO` を追加しました。
- 最初の57件実行は新規メタデータテスト1件が上記の保存キーの前提違いで失敗しました。その5件のスイートを修正後に再実行し全件成功しました。UI は4件成功後、Filters の対象とタップ位置を修正して1件を再実行し成功しました。各 xcresult の件数とスキップ0件を確認しています。
- `git diff --check`、新規ファイルの行末空白、更新した文書の相対リンクを確認しました。`swiftformat GLogo/ --lint` は未インストールで実行できません。全スイート・実機・HDR 表示の見た目比較・保存出力の目視比較は未実施です。

変更後レビュー:

- **Critical**: 指摘なし。
- **Warning**: 上記2件は既存の保存キーとタップ領域の問題です。今回の責務分離で追加した境界違反・所有者の循環参照は見つかりませんでした。
- **Info**: トーンカーブの履歴なし、同値確定のメタデータ記録は従来の契約を維持します。
- **Assumptions**: 選択 Publisher は MainActor で同期通知されます。共通履歴とプロジェクトの所有者は EditorViewModel のままです。
- **Test Coverage**: 既存の保存・Undo・Revert と追加の描画完了順・寿命を確認しました。保存／AI／Undo をまたぐ実行中描画の競合は段階1で扱います。
- **Verification**: 上記の対象テストと差分確認を実行しました。未実施の検証と理由も上記に記載しています。


### 描画結果・遅延通知の競合対策（2026-10-29）

- [ImageRenderRefreshUseCase](../../../GLogo/UseCases/Rendering/ImageRenderRefreshUseCase.swift) は予約時に `ImageEditUseCase` から対象の `ImageEditToken` を取得します。既存の予約世代に加え、画像属性・履歴移動の世代とプロジェクトへの所属を照合し、描画開始前と完了後に失効した結果を破棄します。キャッシュ書き込み・編集終了・画面通知は、有効な完了だけで実行します。
- ガウスぼかし・トーンカーブの遅延通知も同じ照合を使います。ガウスぼかしの確定イベントは同値を書き込んでも世代を進めるため、確定後の状態で予約を置き換えます。確定後の表示更新が一度だけ届き、一操作一履歴を維持することを検証しました。
- `ImageAdjustmentViewModel` と `FilterPanelViewModel` は、選択変更を UUID だけでなくインスタンスの同一性で判定します。同じ ID の別実体へ置き換わった場合も、旧実体の編集状態・開始値・予約を引き継ぎません。
- 古い描画を捨てるだけではプレビュー状態が残るため、Editor は Undo／Redo・Revert・加工結果確定時に対象のプレビューを終了します。古い完了時に一律で終了すると、新しい手動調整まで終了してしまうため、編集操作の確定側で行います。
- フィルターの計算式、SDR／HDR の経路、履歴イベントの内容、メタデータ・Codable・保存形式は変更していません。描画入力の画像とパラメータは既存の MainActor 経路で await 前に取得します。保存は専用スナップショットを使い、編集プレビューの状態には依存しません。
- これは結果の採否の制御で、開始済みの推論・画像計算そのものは中断しません。手動マスク編集画面の戻り経路、サムネイル表示など、全非同期処理への適用完了を意味しません。

変更後レビュー:

- **Critical**: 指摘なし。
- **Warning**: 今回の変更による新規指摘なし。確定品質への切り替えを含む実機の負荷は未測定です。
- **Info**: 対象照合は前回の AI と共通で、描画側に別の画像変更番号を追加していません。待機中の描画は調整・フィルターの ViewModel や Editor を延命しません。保持する編集 UseCase の適用先は弱参照です。
- **Assumptions**: 選択通知・対象照合・キャッシュ適用は MainActor 上で行います。描画クロージャは画像を返すだけで、モデルのキャッシュへ書き込みません。
- **Test Coverage**: 既存の描画順序・寿命・手動調整・保存・Undo・Revert・フレームのテストは引き続き有効です。`ImageRenderRefreshUseCaseTests` は所属照合のため Editor と対象画像の準備を追加し、期待値を維持しました。部分的に古くなった期待値や意味を失ったテストはありません。不足していた経路は [ImageRenderValidityIntegrationTests](../../../GLogoTests/Integration/ImageRenderValidityIntegrationTests.swift) の7件で補いました。
- **Verification**: iPhone 17 Pro／iOS 26.1 Simulator で関連19スイート・93件成功、失敗・スキップ0件です。全スイート・UI 手動操作・実機・4K／8K 負荷は未実施です。`swiftformat GLogo/ --lint` は未インストールで実行できませんでした。

検証範囲:

- 新規7件: 実行中描画と開始前予約に対する12種類の変更、ガウスぼかし／トーンカーブそれぞれの遅延通知、有効な描画と無関係な変更、ガウスぼかし確定、同じ ID の別実体での開始値リセット、履歴・加工確定後のプレビュー終了。
- 描画・画像調整・履歴関連: `ImageRenderRefreshUseCaseTests` 3件、`ImageAdjustmentViewModelTests` 5件、`FilterAdjustSeparationTests` 10件、`ImageUndoCacheInvalidationTests` 4件、`ImageFrameViewModelTests` 8件、`ElementTransformViewModelTests` 9件、`ImagePreviewAsyncResponsivenessRegressionTests` 2件。
- AI・対象照合: `AIResultValidityIntegrationTests` 6件、`AIToolsViewModelTests` 5件、`AIErrorSurfaceIntegrationTests` 4件、`ImageUpscaleRestrictionIntegrationTests` 3件、`ImageEditTokenTests` 3件。
- 保存・復元: `SaveSnapshotIntegrationTests` 4件、`SaveProjectSnapshotTests` 5件、`SaveCoordinatorRegressionTests` 6件、`RevertSnapshotRegressionTests` 6件、`RevertUndoSequenceIntegrationTests` 1件、`ImageElementMetadataRevertUseCaseRegressionTests` 2件。

実行コマンドは `xcodebuild -project GLogo.xcodeproj -scheme GLogo -configuration Debug -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18'` に上記19スイートの `-only-testing:GLogoTests/<Suite>` と `test` を指定しました。結果: `Test-GLogo-2026.10.29_20-57-21-+0900.xcresult`。


### 協調的キャンセルの追加（2026-10-29）

Task の取消を下位処理へ伝え、不要な描画キューの計算と推論の後工程を省くようにしました。処理中表示は実際の終了まで維持し、正常な加工結果と履歴の契約は維持します。変更後レビュー、機能107件と測定4件の検証、実機測定の残件は [キャンセルと測定](../AsyncCancellation.md) を参照してください。


### 共通属性の補強と選択反映の同期化（2026-11-01）

親の選択購読に残っていた `.receive(on: RunLoop.main)` を除去しました。EditorはMainActor上で選択を発行するため、受信を次のRunLoopへ遅延させず、子ViewModelと同時に要素・種別・画像参照を更新します。これにより選択切り替え・解除・削除直後の共通属性操作が旧要素を変更する問題を修正しました。共通属性の履歴を積まない契約と、画像の計算式・保存・履歴イベントは維持しています。

新規 `ElementViewModelTests` 6件と、図形パネルの変更・Undo／Redo等4件を追加しました。修正前の再現4件を含む関連59件とUI14件、計73件が成功しています。今回の対象実行で親の行カバレッジは81.9%、図形子は100%でした。全スイートの再計測値ではありません。レビュー・残件・実行条件は [補強第2回](../TestCoverage.md) を参照してください。

## 依存の受け取り（段階3・第10回、2026-11-06）

`ElementViewModel` は、調整・フィルターで共有する `ImageRenderRefreshUseCase`、フレーム用の `ImageRenderRefreshUseCase`、メタデータの保存先を初期化で受け取るようになりました。`EditorView` が `@StateObject` の生成時に、Composition Root から渡されたエディタの依存で作ります。共有関係（調整とフィルターは同じもの、フレームは別のもの）と作る回数は従来と同じです。詳細と検証は [EditorViewModel](EditorViewModel.md) の第10回を参照してください。
