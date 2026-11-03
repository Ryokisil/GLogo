# EditorViewModelの責務と分割候補

この文書は、編集全体を管理するViewModelの現状と、機能別ViewModelへ分ける境界を記録します。調査日: 2026-10-18。2026-10-25 に保存状態と要素別イベント生成、2026-10-26 に AI・変形操作の状態と受付を分離しました。

- 対象: [EditorViewModel.swift](../../../GLogo/ViewModels/EditorViewModel.swift)
- 全体方針: [比較と責務分離方針](../README.md)
- 関連: [ElementViewModel](ElementViewModel.md)、[保存Coordinator](../UseCases/SaveImage/SaveImageCoordinator.md)

## 確認した現状

2026-10-28 に Coordinator 側で保存受付時の入力固定を実装しました。保存中の AI 完了・Undo／Redo・削除が書き出し内容を変えないことを確認済みです。下記の過去の分離記録とは別に、現在の保存境界は [保存Coordinator](../UseCases/SaveImage/SaveImageCoordinator.md) を参照してください。続いて背景除去・背景ぼかし・高画質化の古い完了結果を抑止しました。フィルター描画と調整の遅延通知にも同じ対象照合を追加済みです。後続で Task の取消伝達と安全な工程境界での終了も実装しました。2026-10-31 に代表条件の実機測定を完了しました。条件と未検証範囲は [キャンセルと測定](../AsyncCancellation.md) を参照してください。詳細は末尾と [ElementViewModel](ElementViewModel.md) の描画競合対策を参照してください。

- `@MainActor`の`ObservableObject`で、プロジェクト、選択、編集モード、変更フラグを保持します。保存状態は `ImageSaveViewModel`、AI 操作・表示状態・マスク編集への遷移は `AIToolsViewModel` が所有します。
- 要素の追加・削除・順序変更、履歴、画像保存、インポートなどの操作を持ちます。テキスト・図形・画像のイベント生成は `textEdits`・`shapeEdits`・`imageEdits`、変形の開始値と入力受付は共有の `transform` へ分離しています。
- `EditorHistory`はこのViewModelが保持し、確定変更の適用に利用します。
- 複数のUseCaseを内部で生成します。背景除去・写真保存に加え、2026-11-01 からインポート処理（`ImageImporting`）・取り込み時の表示サイズ・高画質化UseCaseも初期化時に注入できます。
- Undo／Redoでは要素を更新したあと、選択の再設定と画面通知も行います。
- アプリ入口が`@StateObject`として生成し、`EditorView`へ渡します。`EditorView`は`ElementViewModel`を`@StateObject`として生成します。

参照: [アプリ入口](../../../GLogo/App/GameLogoMakerApp.swift)、[EditorView](../../../GLogo/Views/Editor/Screen/EditorView.swift)。

## 評価

### Warning

保存・AI・変形の状態と要素別イベント生成は分離済みですが、要素構成・インポートなどの操作は引き続き共通の窓口に残っています。インポートと高画質化の入口の差し替え制約は2026-11-01に解消しました。Modelが持つ画像取得・描画・メタデータの共有依存は段階3で扱います。

`project`が`private(set)`でも、参照先のModel内部が不変になるわけではありません。別の参照から要素を書き換える経路と、通知・履歴の対応を確認する必要があります。

### Info

UseCaseとCoordinatorへの委譲はすでに存在します。すべてを新設せず、既存の処理を呼ぶ画面状態と操作受付を分離する方針が適しています。ファイルの行数より、状態所有と変更理由を分割の根拠にします。

## ViewModelの分割候補

以下の型名は候補です。ファイル名は、採用した主な型名に合わせます。

| 候補 | 所有する画面状態・操作 | 所有させない責務 |
| --- | --- | --- |
| `EditorViewModel`に残す範囲 | プロジェクト・選択の共通窓口、編集モード、機能間の調整 | 個別パネルの操作途中値、画像加工の実装 |
| `ImageSaveViewModel`（実装済み） | 保存要求、重複要求の抑止、保存中・失敗理由の状態 | 保存モード判定、画像合成、写真ライブラリへの書き込み |
| `AIToolsViewModel`（実装済み） | 背景除去・ぼかし・高画質化の要求、処理中・エラー、マスク編集への遷移、操作の寿命 | AI推論、画像変換、確定変更の独立した履歴スタック |
| `ImageImportViewModel`（新設しないと判断） | インポートの入力受付と表示状態。独立した状態が必要な場合に検討 | 画像の生成、初期配置計算、別のプロジェクト所有 |

インポートのように独立した画面状態が少ない処理は、既存`ImageImportCoordinator`への委譲を維持するだけで十分かを先に判断します。メソッドがあるという理由だけでViewModelを増やしません。

### 保存状態の分離（2026-10-25）

- `EditorViewModel.saveToPhotoLibrary`／`saveCompositeToPhotoLibrary` → `ImageSaveViewModel` → `PhotoLibrarySaving`（既定は `SaveImageCoordinator`）の順で要求を渡します。
- 保存前に操作状態を整理する `prepareForImageSave` は、編集状態の所有者である親に残します。子は重複要求を除外してから準備クロージャを呼び、保存を開始します。
- 親の `isSavingImage` と `lastPhotoLibrarySaveFailure` は計算プロパティです。同じ状態を複製せず、子の `objectWillChange` を親へ同期転送し、既存画面の購読と編集入力ロックを維持します。旧プロパティの `$` Publisher を使う呼び出し元はありません。
- 完了時はロック解除と失敗理由の更新を行ってから画面へ通知します。子を弱参照するため、所有者の解放後に遅延完了が届いても画面へ通知しません。
- 保存対象のスナップショット化や AI 完了との競合制御は別の課題です。保存 Coordinator に渡すプロジェクト参照、描画処理、履歴、永続化形式は今回変更していません。
- [ImageSaveViewModelTests](../../../GLogoTests/Unit/ImageSaveViewModelTests.swift) で成功・失敗・再試行・重複・同期完了・寿命を、[EditorImageSaveIntegrationTests](../../../GLogoTests/Integration/EditorImageSaveIntegrationTests.swift) で親への通知・入力ロック・解放を検証します。既存の保存 Coordinator 回帰テストは引き続き有効です。

検証結果（2026-10-25）:

- `xcodebuild -project GLogo.xcodeproj -scheme GLogo -configuration Debug -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18' -only-testing:GLogoTests/ImageSaveViewModelTests -only-testing:GLogoTests/EditorImageSaveIntegrationTests -only-testing:GLogoTests/ViewModelMemoryLeakTests -only-testing:GLogoTests/SaveCoordinatorRegressionTests -only-testing:GLogoTests/SaveCoordinatorMainActorCompletionRegressionTests test` が成功。iPhone 17 Pro／iOS 26.1 で追加8件と既存11件、計19件が通過しました。
- `git diff --check` は成功。`swiftformat GLogo/ --lint` は実行を試みましたが、コマンド未インストールのため検証できませんでした。
- 変更後レビューでは今回の差分に Critical／Warning の指摘はありません。既存の `UIColor+Extensions.swift` の再帰警告と `ProjectStorage.swift` の Sendable 警告はビルド時に出ています。
- 保存状態と依存境界の変更に合わせて対象スイートを実行しました。全テスト・UI 操作・実際の写真ライブラリへの書き込みは未検証です。

テキスト・図形・画像調整・ジェスチャーの候補は[ElementViewModelの文書](ElementViewModel.md)にまとめます。両ファイルに分かれている同じ機能の操作は、一緒に移動先を決めます。

### 要素別イベント生成の分離（2026-10-25）

- [TextEditUseCase](../../../GLogo/UseCases/Editing/TextEditUseCase.swift)、[ShapeEditUseCase](../../../GLogo/UseCases/Editing/ShapeEditUseCase.swift)、[ImageEditUseCase](../../../GLogo/UseCases/Editing/ImageEditUseCase.swift) に確定操作を移しました。`EditorViewModel.swift` は 1,703 行から 1,213 行になりました。
- UseCase は変更値から既存イベントを生成し、[ElementEditApplying](../../../GLogo/UseCases/Editing/ElementEditApplying.swift) の3操作へ渡します。履歴なしのプレビュー、イベントと選択の更新、選択通知を伴わないイベント適用を区別します。プロジェクト・選択・履歴スタックの所有者は引き続き `EditorViewModel` です。
- テキストとフレームの子 ViewModel は UseCase を強参照し、UseCase は共通の適用先を弱参照します。`TextEditApplying` と `ImageFrameEditApplying` は UseCases 層へ移し、UseCase が ViewModels 層に依存しない構造にしました。
- このイベント生成分離の時点では、図形とティントの操作は `ElementViewModel` から対応する UseCase を呼びます。Canvas のテキスト入力は既存の `EditorViewModel.updateTextContent` を入口に残し、内部で委譲します。後続の 2026-10-27 に図形の操作受付を `ShapeEditingViewModel` へ移しました。詳細は [ElementViewModel の記録](ElementViewModel.md)を参照してください。
- イベント生成本体は委譲先の変更以外、移動前と一致します。無変更判定、旧値、フレーム調整の履歴 → メタデータ → 表示更新の順序を維持し、イベント定義・Codable・レンダラー・保存形式は変更していません。

回帰テストの確認:

- 既存のテキスト／フレームの履歴・開始値・通知・寿命のテストは、UseCase への接続後も同じ契約を検証します。期待値は変更していません。
- `TextEditUseCaseTests`・`ShapeEditUseCaseTests`・`ImageEditUseCaseTests` で、適用前にモデルを変更しないこと、旧値の復元、図形10操作、複合フレームイベント、通知境界を検証します。
- `ElementEditIntegrationTests` で共通履歴の Undo／Redo、非選択要素の編集時の選択維持、図形パネルからの接続、UseCase を保持した状態でのエディタ解放を検証します。

検証結果（2026-10-25）:

- iPhone 17 Pro／iOS 26.1 で `xcodebuild test` を2回実行し、計43件が成功しました。
  - 既存30件: `TextSliderHistoryIntegrationTests` 6件、`TextEditingViewModelTests` 9件、`FrameColorHistoryIntegrationTests` 2件、`ImageFrameViewModelTests` 8件、`ViewModelMemoryLeakTests` 3件、`OperationMemoryLeakTests` 2件。
  - 新規11件: `TextEditUseCaseTests` 4件、`ShapeEditUseCaseTests` 1件（10操作）、`ImageEditUseCaseTests` 3件、`ElementEditIntegrationTests` 3件。
  - UI 2件: `EditorPanelUITests/test_textSize_slider_updatesValue`、`EditorPanelUITests/test_frameWidth_slider_updatesValue`。
- 共通引数は `-project GLogo.xcodeproj -scheme GLogo -configuration Debug -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18'`。上記対象を `-only-testing:` で指定しました。新規・UI の13件は xcresult の集計でも成功・スキップなしを確認しました。
- 移動前との操作本体の照合、`git diff --check`、新規 Swift ファイルの空白検査、更新文書の相対リンク検査は成功しました。
- 変更後レビューで今回の差分に Critical／Warning の新規指摘はありません。MainActor、共通履歴、選択通知、参照寿命とメタデータ記録順を確認しました。
- `swiftformat GLogo/ --lint` は実行を試みましたが、未インストールのため検証できませんでした。全スイート・実機・保存画像の比較は未実施です。今回変更していない保存・描画・イベント定義の回帰テストは契約上引き続き有効と判断し、この段階では再実行していません。

### AI 操作・表示状態の分離（2026-10-26）

- [AIToolsViewModel](../../../GLogo/ViewModels/AIToolsViewModel.swift) が背景除去・背景ぼかし・高画質化の要求と処理中／エラー、マスク編集の遷移先を所有します。`EditorViewModel` は `aiTools` を一度生成し、遷移を描画する `EditorView` へ子の変更通知だけを転送します。親に同じ AI 状態は残していません。
- `ElementViewModel.aiTools` は同じインスタンスです。パネル向けのプロパティは計算プロパティで、従来の5つの状態コピーと非同期購読を廃止しました。選択 ID の変更でエラーを同期クリアし、同じ ID のプレビュー通知ではエラーを維持します。
- 推論は既存の `BackgroundRemovalProcessing` と `ImageUpscaleUseCase` を使用します。背景処理の注入は親の初期化 API を維持し、子は高画質化 UseCase も注入できます。加工結果は [AIImageEditApplying](../../../GLogo/UseCases/Editing/AIImageEditApplying.swift) を実装する `ImageEditUseCase` へ渡します。
- 画像差し替えイベントの生成と、既存 `BackgroundBlurUseCase` の計画適用を `ImageEditUseCase` へ移しました。[ImageEditCommitting](../../../GLogo/UseCases/Editing/ImageEditCommitting.swift) は全イベントの適用後に選択・変更フラグ・通知を更新します。差し替え時は結果を選択し、ぼかし時は別の選択を維持する既存の違いを残しています。
- マスク → 必要な半径の順に履歴を積む仕様を維持しています。イベント定義、画像調整のリセット／復元、Codable、メタデータ、レンダラー、保存形式は変更していません。
- Task は await をまたいで子を強参照しません。子の解放後は結果を適用せず、子を保持するパネルだけが残っても UseCase がエディタを延命しません。推論そのもののキャンセルや、削除・Undo・別加工・保存中の完了結果の無効化は未実装です。AI と高画質化の別々の重複ガードも従来どおりで、両者の同時実行を一括制御する変更はしていません。
- この AI 分離時点で `EditorViewModel.swift` は 1,213 → 951 行、`ElementViewModel.swift` は 803 → 754 行になりました。後続の変形分離は下記を参照してください。

回帰テストの棚卸し:

- 引き続き有効: `ImageUpscaleRestrictionIntegrationTests` の再適用制限・重複要求・Undo／Redo、フレームの既存テスト、`RevertSnapshotRegressionTests`、`RevertUndoSequenceIntegrationTests`、`ImageUndoCacheInvalidationTests`。高画質化テストは呼び出し先だけを変更し、期待値を維持しました。
- 補強済み: `AIErrorSurfaceIntegrationTests` は初期値や nil のクリアだけでは失敗伝播を保護できていませんでした。失敗する処理を注入し、実際のエラー・親とパネルの通知・クリア・選択 ID 変更を検証する4件に更新しました。
- 追加: [AIToolsViewModelTests](../../../GLogoTests/Integration/AIToolsViewModelTests.swift) の5件で、完了を制御した重複要求、画像差し替えの Undo／Redo、マスクと半径の履歴・通知順序、非選択対象の維持、処理待ち中の所有者解放、マスク編集の遷移・取消、高画質化の失敗を検証します。
- 残り: 保存中の AI 完了、削除・Undo・別加工後の古い結果、推論のキャンセルは段階1で追加検証します。今回の寿命テストだけで競合対策済みとは判断しません。

検証結果（2026-10-26）:

- 最終差分の `xcodebuild test` で42件成功、失敗・スキップなしを xcresult で確認しました。iPhone 17 Pro／iOS 26.1、共通引数は `-project GLogo.xcodeproj -scheme GLogo -configuration Debug -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18'`、下記を `-only-testing:` で指定しました。
  - `AIErrorSurfaceIntegrationTests` 4件、`AIToolsViewModelTests` 5件、`ImageUpscaleRestrictionIntegrationTests` 3件、`ViewModelMemoryLeakTests` 3件。
  - `ImageFrameViewModelTests` 8件、`ImageEditUseCaseTests` 3件、`ElementEditIntegrationTests` 3件、`RevertSnapshotRegressionTests` 6件、`RevertUndoSequenceIntegrationTests` 1件、`ImageUndoCacheInvalidationTests` 4件。
  - `EditorPanelUITests` の `testEditor_AIToolsPanel_ShowsEnhanceForSelectedImage` と `testEditor_EnhancedImage_DisablesEnhanceButton` の2件。
- `ImageContentReplacedEvent` の全引数が移動前と一致すること、`git diff --check`、新規 Swift ファイルの空白、更新文書の相対リンクを確認しました。
- 変更後レビュー: 今回の差分に Critical／Warning の新規指摘なし。MainActor、層の依存、共通履歴、複数イベント適用後の通知、選択変更時のエラークリア、Task と親子の参照寿命を確認しました。
- 前提: 既存の加工・履歴・選択方針を維持し、AI 状態を一か所へ集約します。競合制御は段階1として残します。
- 未実施: `swiftformat GLogo/ --lint` はコマンド未インストールで実行できませんでした。全テスト、実機の AI 推論、保存画像の比較、マスク編集画面内の手動操作は今回の検証対象外です。高画質化は既存 Lanczos パイプラインで完了を検証し、AI は制御可能な代替実装で要求・失敗・寿命を検証しました。

### 変形操作の分離（2026-10-26）

- [ElementTransformViewModel](../../../GLogo/ViewModels/ElementTransformViewModel.swift) が座標操作の開始点・変形値、同時ジェスチャーごとの基準値と進行状態を所有します。親と `ElementViewModel.transform` は同じ子を共有し、Canvas のコールバックは子へ直接接続します。親は子の通知を転送します。
- [ElementTransformState](../../../GLogo/Models/ElementTransformState.swift) は位置・サイズ・回転だけを保持し、座標入力の変形計算を行います。開始時に画像を含む要素全体を深いコピーする処理を廃止しました。[ElementTransformUseCase](../../../GLogo/UseCases/Editing/ElementTransformUseCase.swift) は変化した属性のイベントと回転リセットのイベントを生成します。
- 子は [ElementTransformApplying](../../../GLogo/UseCases/Editing/ElementTransformApplying.swift) を弱参照し、共通のプレビュー・履歴・変更フラグ・保存ロックへ接続します。プロジェクトと履歴の正は親に残ります。
- 選択通知は同期で受け、別 ID・未選択への変更で両入力の開始値を破棄します。同じ ID のプレビュー更新では基準値を維持します。`ElementViewModel` の遅れた選択通知が、再選択済みの画像の新しい変形を終了させない条件も追加しました。
- `prepareForImageSave` は子の両入力を停止してから、従来どおり全画像の編集用描画を終了します。保存中は座標入力・SwiftUI ジェスチャー・直接変形・回転リセットを共通で抑止します。プレビュー値を巻き戻したり、保存開始で履歴を追加したりはしません。
- 高解像度画像の準備・終了は既存 `ManipulationRenderingUseCase`、同時ジェスチャーの描画切り替えは既存 `ImageEditingSessionUseCase` を再利用します。準備したプロジェクトは弱参照で、選択変更・保存時も描画状態を終了します。
- 履歴仕様の前提: 座標操作は終了時に一つの `ElementTransformedEvent`、回転リセットは `ElementRotatedEvent` を記録します。現在の SwiftUI オーバーレイは従来どおりプレビューと変更フラグのみで、ジェスチャー自体の確定履歴は追加していません。この2経路の履歴方針統合は別の変更として扱います。保存形式・Codable・イベント定義・メタデータ・画像合成は変更していません。
- `EditorViewModel.swift` は 951 → 813 行、`ElementViewModel.swift` は 754 → 598 行です。

回帰テストの棚卸し:

- 引き続き有効: `NoOpGestureIntegrationTests` のゼロ移動・同時ジェスチャー・基準値・回転リセット、`EditorImageSaveIntegrationTests` の保存ロック、メモリ解放・画像キャッシュ・保存 Coordinator の既存テスト。入口だけを子へ変更し、期待値は維持しました。
- 追加: [ElementTransformViewModelTests](../../../GLogoTests/Integration/ElementTransformViewModelTests.swift) の9件で、移動／最小サイズ／回転の Undo・Redo、無変更、即時選択切り替え、再選択時の遅れた通知、複数入力の保存停止、最後のジェスチャー終了までの描画、Canvas コールバック、共有と参照寿命を検証します。

検証結果（2026-10-26）:

- iPhone 17 Pro／iOS 26.1 で関連43件（重複除外、UI 1件を含む）が成功しました。初回34件に続き、再選択の通知対策後に影響する31件を実行し、両 xcresult で失敗・スキップなしを確認しました。
  - 初回: `NoOpGestureIntegrationTests` 7件、`EditorImageSaveIntegrationTests` 3件、`OperationMemoryLeakTests` 2件、`ViewModelMemoryLeakTests` 3件、`ImageUndoCacheInvalidationTests` 4件、追加時点の `ElementTransformViewModelTests` 8件、`SaveCoordinatorRegressionTests` 6件、`EditorDeleteFlowUITests/testEditor_DeleteFlow_ConfirmRemovesSelectedImage` 1件。
  - 再選択対策後: `ElementTransformViewModelTests` 9件、`NoOpGestureIntegrationTests` 7件、`EditorImageSaveIntegrationTests` 3件、`ImageUndoCacheInvalidationTests` 4件、`ImageFrameViewModelTests` 8件。
- 共通引数は `xcodebuild -project GLogo.xcodeproj -scheme GLogo -configuration Debug -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18'`。上記対象を `-only-testing:` で指定して `test` を実行しました。
- 変更後レビュー: 新規の Critical／Warning なし。Info として、SwiftUI と座標入力で異なる既存の履歴仕様を上記に記録しました。親と子の状態重複、MainActor、弱参照、保存ロック、遅れた通知、描画終了、無変更時の履歴を確認しました。
- ジェスチャー本体は保存ガードと委譲先の変更以外、移動前と一致することを照合しました。`git diff --check`、新規 Swift ファイルの空白、更新文書の相対リンクも確認済みです。
- 未実施: `swiftformat GLogo/ --lint` はコマンド未インストールのため実行不可。全スイート、実機マルチタッチ、保存画像のピクセル比較は未実施です。Canvas の接続はコールバック結合テストと削除 UI テストで確認し、実際の複数指操作の網羅検証とは区別します。

## 状態と依存の境界

1. 初期段階ではプロジェクトと選択の正をここに残し、子へプロジェクト全体の自由な変更権限を配らない設計を検討します。
2. 子には対象ID、必要な状態、共通の編集適用操作を渡します。Protocolやクロージャは、実際に必要な境界だけを表現します。
3. 保存中・AI処理中などの状態を子へ移した場合、親の同名状態を独立して更新する構造を残しません。
4. 履歴の記録・変更フラグ・キャッシュ無効化を伴う確定処理は、共通の編集入口へ集めます。履歴処理そのものはUseCase側の責務です。
5. 子の`ObservableObject`を親が保持するだけで必要なViewへ通知が届く、と仮定しません。Viewによる直接購読か、限定した状態伝播を設計します。
6. `@MainActor`は非同期要求の完了順を保証しません。対象ID、世代、キャンセル、画面・機能終了時の適用可否を明示します。

## 直接・間接の影響範囲

| 対象 | 確認する契約 |
| --- | --- |
| `EditorView`と各パネル | ViewModelの生成・保持、Binding、エラー表示、保存中の操作抑止 |
| `ElementViewModel`と分割後の子 | 選択変更の伝播、状態の重複、購読解除、親子の参照寿命 |
| `EditorHistory` | 一操作一履歴、Undo／Redo後の選択と通知 |
| 保存・AI・インポートのUseCase | 完了結果の対象、失敗時の表示、キャンセルと適用条件 |
| `ImageElement`とメタデータ | 確定時のキャッシュ無効化、Revertの基準、属性の保持 |

ViewModel分割だけでは保存形式を変更しません。状態を別のModelへ移す必要が生じた場合は、Codableと旧形式復元への影響を別に計画します。

## テストと完了条件

既存の関連テスト:

- [AIErrorSurfaceIntegrationTests](../../../GLogoTests/Integration/AIErrorSurfaceIntegrationTests.swift): AIエラー表示状態と伝播。
- [ViewModelMemoryLeakTests](../../../GLogoTests/Unit/ViewModelMemoryLeakTests.swift): ViewModelの寿命に関する確認先。
- [RevertUndoSequenceIntegrationTests](../../../GLogoTests/Integration/RevertUndoSequenceIntegrationTests.swift): Revert後のUndo。
- [EditorDeleteFlowUITests](../../../GLogoUITests/EditorDeleteFlowUITests.swift): 削除操作のUI回帰確認先。

追加・再確認候補:

- 子の状態変更が対象パネルへ反映され、無関係な状態を複製しないこと。
- 要素変更・削除・Undo後に古いAI結果が不適切に適用されないこと。
- 保存中のAI完了と、機能終了後の非同期完了の扱い。
- 子の再生成・解放でTaskや購読が重複・残留しないこと。

一機能の移行ごとに、操作受付、表示更新、履歴、異常系、寿命を確認してから次へ進みます。2026-10-18 の調査時点ではテストを実行していません。保存状態の分離に対する検証範囲は上記に記載しています。


## AI 完了結果の競合対策（2026-10-29）

- `ImageEditToken` は対象インスタンス、画像属性の書き込み世代、履歴移動の世代を保持します。`EditorViewModel` が現在のプロジェクトへの所属を照合し、`ImageEditUseCase` を通じて子へ判定を提供します。View に判定や履歴操作は追加していません。
- `AIToolsViewModel` は背景除去・背景ぼかし・高画質化の要求受付時に元画像とトークンを固定し、処理開始前と完了後に照合します。確認から適用までは MainActor 上で await を挟みません。失効した結果は履歴・選択・変更フラグを更新しません。
- 削除、同じ ID の別インスタンスへの置換、画像属性の変更、Undo／Redo、履歴クリア、プロジェクト差し替えで失効します。値を変更して元へ戻しても古い要求は復活しません。画像に無関係な通常の履歴追加、配置、キャッシュ更新、選択変更だけでは成功結果を失効させません。
- 選択を離れて戻った後に古い失敗メッセージを表示しません。背景除去と高画質化が同時に走った場合、最初に適用された有効な結果が対象の世代を進め、後の結果は破棄されます。
- トークンと世代番号は永続化せず、Codable・メタデータ形式は維持します。推論自体は中止せず、失効した処理が終了すると処理中状態を解除します。手動マスク編集画面の戻り経路はこの AI 対策の対象外です。フィルターの高品質描画と調整の遅延通知への適用拡張は、後続の描画競合対策で実装しました。

レビュー結果:

- **Critical / Warning**: 今回の変更範囲で新たな指摘なし。
- **Info**: この AI 対策後の描画競合対策は実装済みです。実推論・描画自体のキャンセル、実機の負荷測定は残件です。画像属性の追加時は書き込み世代の対象に含めるか確認が必要です。
- **Assumptions**: 編集用 Model の変更と要求の照合・適用は MainActor 上で行います。保存は別途固定した入力を使用します。
- **Test Coverage**: 既存の Revert・Undo・キャッシュ・保存のテストは有効です。`AIToolsViewModelTests` の失敗テストは、現在のプロジェクトに属する対象を用意するよう補正し、失敗伝播の期待値は維持しました。意味を失った回帰テストはありません。
- **Verification**: iPhone 17 Pro／iOS 26.1 Simulator で関連14スイート・67件が成功、失敗・スキップ0件（実行日 2026-10-28）。新規の [AIResultValidityIntegrationTests](../../../GLogoTests/Integration/AIResultValidityIntegrationTests.swift) 6件と [ImageEditTokenTests](../../../GLogoTests/Unit/ImageEditTokenTests.swift) 3件で、3種類の処理×7種類の変更、同時要求の完了順、古いエラー、再実行、実行時世代の非永続化を検証しました。全スイート・UI 操作・実機推論は今回は未実施です。`swiftformat GLogo/ --lint` は未インストールのため実行できませんでした。


## 描画失効時のプレビュー終了（2026-10-29）

Undo／Redo、Revert、`applyImageEvents` での加工結果確定時に、対象画像の編集プレビューを終了します。古い描画を破棄した後もプレビュー品質の状態が残ることを防ぎ、既存の画像取得経路で確定品質を表示します。履歴の内容・粒度、画像の計算式、保存形式は変更しません。

画像調整・フィルター側のトークン照合と検証93件の内訳は [ElementViewModel](ElementViewModel.md) の「描画結果・遅延通知の競合対策」を参照してください。`EditorViewModel.swift` はこの処理を加えて 820 → 826 行です。


### 協調的キャンセルの追加（2026-10-29）

Task の取消を下位処理へ伝え、不要な描画キューの計算と推論の後工程を省くようにしました。処理中表示は実際の終了まで維持し、正常な加工結果と履歴の契約は維持します。変更後レビュー、機能107件と測定4件の検証、実機測定の残件は [キャンセルと測定](../AsyncCancellation.md) を参照してください。


## 段階2の残件判断と入口DI（2026-11-01）

### 調査・変更範囲

Codegraphで `EditorViewModel → ImageImportCoordinator → ImageImportUseCase → Builder／PlacementCalculator` と、画像追加・選択・履歴・カメラ通知の経路を確認しました。`rg`とソースで通常取り込み、クロップ完了コールバック、既存テストを照合しました。Serenaは利用できませんでした。

| 仮説 | 確認 | 判断・対応 |
| --- | --- | --- |
| インポートにも子ViewModelが必要 | 生成・配置は既存UseCaseに分離済み。独立した進捗やエラー等の表示状態を所有していない | 新設しない。Editorは追加・選択・履歴・カメラ通知の調停を継続 |
| Editor内部で生成する依存が統合テストを制約する | ImportCoordinatorは固定生成、高画質化は子の既定値が使われ、親から差し替え不可 | `ImageImporting`、表示サイズProvider、`ImageUpscaleUseCase`をEditorの初期化引数に追加 |
| メタデータや描画の共有依存も同時に外す必要がある | Revertは共有Manager、編集セッション・変形・フレームはModelの描画／記録メソッドを利用する | Modelの技術依存として段階3へ。形式だけの引数追加で解消済みとはしない |

### 確定した依存の扱い

| 依存 | 段階2での扱い |
| --- | --- |
| インポートの生成・初期配置 | [ImageImporting](../../../GLogo/UseCases/Import/ImageImporting.swift)経由で注入。既定は既存Coordinator |
| 取り込み時の表示サイズ | MainActorのProviderを注入。既定は従来どおり `UIScreen.main.bounds.size`。取り込みの都度取得 |
| 高画質化 | 既存の `ImageUpscaleUseCase` を注入し、Editorと画面が共有する `aiTools` へ渡す。推論方式・倍率・シャープ化の既定値は維持 |
| 背景除去・写真保存・画像調整／フィルターの描画更新 | 既存の注入境界を維持 |
| 要素別イベント生成、役割判定、フィルター適用ルール、変形値計算 | 共通編集先や対象を受け取る既存境界を維持。状態を持たない処理すべてをprotocol化しない |
| Model経由の取得・描画・編集中モード・キャッシュ・メタデータ記録／復元 | 段階3の範囲。フレームの描画更新や共有MetadataManagerも含め、Model側の実依存と一緒に整理する |

製品の変更は `EditorViewModel`、`ImageImportCoordinator`、新規 `ImageImporting` の3ファイルです。使われていなかったインポート戻り値の表示サイズタプルを除去しました。既存の `addImageElement` の引数と通常／クロップの入力形式は維持しています。生成、配置、画像の役割、追加時のZ順、履歴イベント、保存形式、画像処理式は変更していません。専用ViewModelや新しい表示状態も追加していません。

### 検証と変更後レビュー

- **Critical**: 指摘なし。
- **Warning**: 今回の変更に新規指摘なし。前後移動の履歴問題、画像・図形複製の検証拡張、4K SDR性能超過は別の未解決項目です。
- **Info**: 生成・配置はUseCase、追加・選択・履歴・表示通知はEditorの境界を維持しました。入力の検証ルールを変更したものではありません。
- **Assumptions**: 取り込みは同期処理で、画面からの呼び出しはMainActor上です。Importerはプロジェクトを参照して要素を生成し、追加はEditorが担当します。
- **Test Coverage**: 新規7件。`EditorImageImportIntegrationTests` 4件は入力・都度の表示サイズ・追加と履歴とカメラ通知・失敗時のRedo保持・標準Importerの画像役割と配置を検証。`ImageImportCoordinatorTests` 2件はプロジェクト非変更と画像数・入力変換失敗を検証。`AIToolsViewModelTests` 1件は親から注入した高画質化が共有AI子へ届き、結果・Undo／Redoを維持することを検証しました。
- **Verification**: 関連11スイート・**47件成功、失敗0件・スキップ0件・xcresult実行時警告0件**。AI結果の失効・取消、保存入力固定、Revert、画像順序、選択境界、ViewModel寿命の既存テストも成功。期待値の緩和・削除はありません。差分の空白と文書リンクも確認しました。
- **未実施**: 全スイート・UI・実機は再実行していません。Viewや画面遷移を変えず、同期の取り込み入口と共有AI境界を対象テストで確認しました。SwiftFormatは未導入のため実行不可です。

実行条件: iPhone 17 Pro／iOS 26.1 Simulator、Debug、`-enableCodeCoverage YES -parallel-testing-enabled NO`。
対象: `EditorImageImportIntegrationTests`、`ImageImportCoordinatorTests`、`AIToolsViewModelTests`、`AIResultValidityIntegrationTests`、`AICancellationIntegrationTests`、`ImageUpscaleRestrictionIntegrationTests`、`ImageElementMetadataRevertUseCaseRegressionTests`、`SaveSnapshotIntegrationTests`、`ImageReorderTests`、`ViewModelMemoryLeakTests`、`ElementViewModelTests`。
結果: `/tmp/glogo-stage2-di-20261101.xcresult`、ログ: `/tmp/glogo-stage2-di-20261101.log`。今回の対象実行ではCoordinator・ImportUseCase・配置計算は各100%、Builderは22 / 23行（95.7%）を実行しています。全体カバレッジの再測定ではありません。

**段階2は、計画した機能別ViewModel分離と入口DIの範囲で完了**です。すべての内部依存や既存不具合が解消した意味ではありません。次の着手は段階3の `ImageElement` の画像取得依存です。
