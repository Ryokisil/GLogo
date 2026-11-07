# EditorViewModelの責務と分割候補

この文書は、編集全体を管理するViewModelの現状と、機能別ViewModelへ分ける境界を記録します。調査日: 2026-10-18。2026-10-25 に保存状態と要素別イベント生成、2026-10-26 に AI・変形操作の状態と受付を分離しました。2026-11-06 の段階3・第9回で、依存を Composition Root から受け取る形にしました。

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

参照: [アプリ入口](../../../GLogo/App/GLogoApp.swift)、[EditorView](../../../GLogo/Views/Editor/Screen/EditorView.swift)。

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

- [TextEditUseCase](../../../GLogo/UseCases/Editing/Text/TextEditUseCase.swift)、[ShapeEditUseCase](../../../GLogo/UseCases/Editing/Shape/ShapeEditUseCase.swift)、[ImageEditUseCase](../../../GLogo/UseCases/Editing/Image/ImageEditUseCase.swift) に確定操作を移しました。`EditorViewModel.swift` は 1,703 行から 1,213 行になりました。
- UseCase は変更値から既存イベントを生成し、[ElementEditApplying](../../../GLogo/UseCases/Editing/Session/ElementEditApplying.swift) の3操作へ渡します。履歴なしのプレビュー、イベントと選択の更新、選択通知を伴わないイベント適用を区別します。プロジェクト・選択・履歴スタックの所有者は引き続き `EditorViewModel` です。
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
- 推論は既存の `BackgroundRemovalProcessing` と `ImageUpscaleUseCase` を使用します。背景処理の注入は親の初期化 API を維持し、子は高画質化 UseCase も注入できます。加工結果は [AIImageEditApplying](../../../GLogo/UseCases/Editing/Image/AIImageEditApplying.swift) を実装する `ImageEditUseCase` へ渡します。
- 画像差し替えイベントの生成と、既存 `BackgroundBlurUseCase` の計画適用を `ImageEditUseCase` へ移しました。[ImageEditCommitting](../../../GLogo/UseCases/Editing/Session/ImageEditCommitting.swift) は全イベントの適用後に選択・変更フラグ・通知を更新します。差し替え時は結果を選択し、ぼかし時は別の選択を維持する既存の違いを残しています。
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

- [ElementTransformViewModel](../../../GLogo/ViewModels/ElementTransformViewModel.swift) が座標操作の開始点・変形値、同時ジェスチャーごとの基準値と進行状態を所有します。親と `ElementViewModel.transform` は同じ子を共有し、Canvas のコールバックは子へ直接接続します。親は子の通知を転送します。（第12回で、アプリから呼ばれていなかった Canvas の操作コールバックと座標操作を削除しました）
- [ElementTransformState](../../../GLogo/Models/ElementTransformState.swift) は位置・サイズ・回転だけを保持し、座標入力の変形計算を行います（第12回で変形計算を削除し、ジェスチャーの開始値の保持だけが残っています）。開始時に画像を含む要素全体を深いコピーする処理を廃止しました。[ElementTransformUseCase](../../../GLogo/UseCases/Editing/Transform/ElementTransformUseCase.swift) は変化した属性のイベントと回転リセットのイベントを生成します。
- 子は [ElementTransformApplying](../../../GLogo/UseCases/Editing/Session/ElementTransformApplying.swift) を弱参照し、共通のプレビュー・履歴・変更フラグ・保存ロックへ接続します。プロジェクトと履歴の正は親に残ります。
- 選択通知は同期で受け、別 ID・未選択への変更で両入力の開始値を破棄します。同じ ID のプレビュー更新では基準値を維持します。`ElementViewModel` の遅れた選択通知が、再選択済みの画像の新しい変形を終了させない条件も追加しました。（第11回で変更：ジェスチャーは、切り替え前の差分を前の要素の履歴1件として確定し、続きの通知を終了まで無視します）
- `prepareForImageSave` は子の両入力を停止してから、従来どおり全画像の編集用描画を終了します。保存中は座標入力・SwiftUI ジェスチャー・直接変形・回転リセットを共通で抑止します。プレビュー値を巻き戻したり、保存開始で履歴を追加したりはしません。（第11回で変更：保存の受付で、未確定のジェスチャーの差分を履歴1件として確定します。座標入力は従来どおり開始値だけを破棄します）
- 高解像度画像の準備・終了は既存 `ManipulationRenderingUseCase`、同時ジェスチャーの描画切り替えは既存 `ImageEditingSessionUseCase` を再利用します。準備したプロジェクトは弱参照で、選択変更・保存時も描画状態を終了します。（第12回で `ManipulationRenderingUseCase` を削除しました。呼び出し元は座標操作の経路だけでした）
- 履歴仕様の前提: 座標操作は終了時に一つの `ElementTransformedEvent`、回転リセットは `ElementRotatedEvent` を記録します。現在の SwiftUI オーバーレイは従来どおりプレビューと変更フラグのみで、ジェスチャー自体の確定履歴は追加していません。この2経路の履歴方針統合は別の変更として扱います。保存形式・Codable・イベント定義・メタデータ・画像合成は変更していません。（第11回で変更：ジェスチャーも1回の操作を1件として記録します。座標操作の経路は 2025-12-22 以降アプリから呼ばれていないことが分かり、次の回で削除します）
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

## 段階3・第9回：Composition Root と入口の依存（2026-11-06）

### 計画と確認した経路

UseCases に11型、ViewModels に4型、初期化引数の既定値に Infrastructure の具体型が残っていました。アプリの入口は `EditorViewModel()` を引数なしで作り、既定値の連鎖で Infrastructure まで届いていました。依存の通り道で2回に分け、第9回は入口から EditorViewModel が受け取る依存と、そこから開く2つの編集画面（手動背景除去・背景ぼかしマスク）を扱いました。編集パネル側（メタデータの保存先・描画の間引き・プレビューサービス）は第10回です。計画は Codex のレビューで補正しました。

| 仮説・リスク | 確認・対応 |
| --- | --- |
| 生成の場所を移すと、生成の単位やタイミングも変わる | 単位とタイミングは変えない。エディタで共有するものは値、画面ごとに作るものは「作る関数」で渡す |
| 画面用の「作る関数」が SwiftUI の再描画のたびに呼ばれる | StateObject が ViewModel を作る式の中でだけ呼ぶ。実際に表示して、再描画では作らず、開き直すと作ることをテストで確認 |
| `ImageSourceResolver` の既定値を外すと Model に波及する | Model（`ImageElement`）の Decoder が `ImageSourceResolver()` を呼ぶため、今回は既定値を残した。Decoder の依存注入を扱う回で外す |
| 既定値を外すとテストの生成箇所（EditorViewModel と ImageElementFactory で約200か所）が壊れる | テストターゲットの専用ファイル [LiveDependencyDefaults](../../../GLogoTests/Unit/LiveDependencyDefaults.swift) に生成口を置き、既存の呼び出しを保った。明示した偽物はそのまま渡る |

### 変更した境界

- [AppComposition](../../../GLogo/App/AppComposition.swift)（Composition Root）：第9回で移行した依存（入口・保存・インポート・AI・2つの編集画面）を組み立てる場所です。編集パネル側の依存（第10回の対象）と Model 側の参照は、まだここを通りません。アプリの入口（`GLogoApp`）とプレビューはここからエディタを作ります。
- [EditorDependencies](../../../GLogo/ViewModels/EditorDependencies.swift)：エディタ1つ分の依存です。境界の Protocol と UseCase だけを持ち、Infrastructure の具体型は含めません。
- `EditorViewModel` は `init(project:dependencies:viewportSizeProvider:)` だけになりました。UI テストの起動用データで使う Factory は、入口から関数で受け取ります。
- `AIToolsViewModel`・`ImageSaveViewModel`・2つの編集画面の ViewModel、`SaveImageCoordinator`（保存処理・写真への書き込み）・`ImageUpscaleUseCase`・インポートの3型・`ImageElementFactory`・`ManualBackgroundBlurUseCase` から、Infrastructure を指す既定値を外しました。インポートの Builder は要素の Factory を受け取る形にしました。
- 2つの編集画面は、依存一式ではなく、それぞれが必要な「作る関数」だけを `EditorView` から受け取ります。
- UI テスト用に、AI ツールの2つのボタンと、2つの画面のキャンセルボタンへ識別子を付けました（見た目と動作は変えていません）。

**生成の単位とタイミング（変えていません）**

| 実装 | 単位 |
| --- | --- |
| 背景除去 | エディタの初期化時に1つ作り、AI ツールと共有。編集画面を開くたびにも1つ作る |
| 編集用画像の取得・手動の背景ぼかし | 編集画面を開くたびに作る |
| 高画質化 | エディタごとに1組を作り、AI ツールと共有。Core ML のモデルは最初の高画質化で読み込んで保持 |
| 保存・インポート | エディタごとに1つ。描画サービスとアセットの読み込みは共有インスタンスを渡す |

アプリから見た挙動、保存形式、履歴、キャッシュの無効化範囲は変えていません。

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。
- **Info**: `EditorViewModel.dependencies` を内部公開にしたため、エディタを持つ側から依存を参照できます。今は `EditorView` が2つの画面用の「作る関数」を読むだけです。子が必要な依存を自由に取り出す使い方は避け、受け取るものは初期化で明示します。
- **Info**: View からアプリの組み立て（`AppComposition`）を使うのは、プレビューだけです。
- **Info**: テスト側の生成口は以前の初期化と同じ呼び方なので、本番に既定値が残っているように見えます。ファイル冒頭に理由を書きました。今回追加したテストは、本番の初期化 `EditorViewModel(dependencies:)` を直接使います。
- **Test Coverage**: [EditorDependenciesTests](../../../GLogoTests/Integration/EditorDependenciesTests.swift) 5件で、注入した保存・インポート・背景除去・高画質化が実際の操作から呼ばれること、初期化時に作るのはエディタで共有する背景除去だけであること、2回の高画質化が同じ実行器へ届くことを確認しました。[AppCompositionTests](../../../GLogoTests/Integration/AppCompositionTests.swift) 2件で、アプリと同じ組み立てのインポートが共有の描画サービスを渡すことと、画面用の依存を呼ぶたびに作ることを確認しました。[MaskEditingScreenDependencyTests](../../../GLogoTests/Integration/MaskEditingScreenDependencyTests.swift) 2件は、2つの画面を実際に表示し、画面の値を作るだけでは依存を作らず、表示で1回、再描画では作らず、開き直すと作ることを確認します。UI テストに、2つの画面を2回ずつ開いてキャンセルで閉じる2件を追加しました。
- **回帰テスト棚卸し**: 既存テストの期待値は変えていません。既定値に頼っていた数か所（保存処理の省略4か所、背景除去などの省略4か所、インポートの Builder 2か所）は、以前の既定値と同じ実装を明示する形にしました。偽物を渡すテストは、そのまま偽物が届きます。
- **Verification**: GLogoTests 387件中384件成功（失敗1件は既知の `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用）。UI テストは起動（表示条件4通り）・画面の基本表示・AI ツール・追加した2件の計8件が成功しました。`rg` で、ViewModels に Infrastructure の型名がなく、UseCases に残るのは第10回の5型と `ImageSourceResolver` の既定値だけであることを確認しました。変更したファイルからの新しいビルド警告はありません（`ImageSourceIsolationTests` の既存の Sendable 警告は残っています）。`git diff --check`（新規ファイルを含む）と文書の相対リンクも確認しました。iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormatは未導入のため実行できません。Codegraph は未接続のため、参照の確認は `rg` とコンパイラで行いました。

### 残り

- 第10回：編集パネル側の依存（`ImageMetadataEditUseCase`・`ImageElementMetadataRevertUseCase` のメタデータの保存先、`ImageRenderRefreshUseCase` の描画の間引き、`FilterPreviewUseCase`・`ImageCacheReleaseUseCase` のプレビューサービス）と、Revert イベントの中での生成。
- `ImageSourceResolver` の既定値（`ImageAssetRepository.shared`）は、Model の Decoder の依存注入を扱う回まで残る例外です。第10回のあとも残っていれば、初期化引数の既定値の問題を「すべて解消」とは扱いません。
- Model から Infrastructure への参照（描画、`copy()` などでの読み込み、Decoder の既定値、背景設定のアセット読み込み）は、段階3の描画・キャッシュの移動とあわせて扱います。

## 段階3・第10回：編集パネル側の依存（2026-11-06）

### 計画と確認した経路

第9回の続きとして、UseCases の初期化引数に残っていた Infrastructure を指す既定値（5型）を外しました。計画は Codex のレビューで補正し、次の3点を実装と検証の条件にしました。

| 条件 | 対応 |
| --- | --- |
| Revert の Undo で保存先への操作を増やさない | Revert イベントは保存先を受け取り、適用（Redo を含む）のたびに UseCase を作ります。Undo は従来どおり編集値の復元と表示の失効だけです |
| 描画の更新は、作る回数と共有関係の両方を保つ | 調整とフィルターは予約の取り消しを共有するため1つを共有し、フレームは別の1つを使います。描画の間引き（`RenderScheduler`）も、その単位で分かれます |
| 注入した描画サービスをメモリ解放の既定対象にする | 画像ごとの別の描画サービスも引き続き解放し、同じサービスは1回だけ解放します。フィルターのサムネイルは従来どおり、選んだ画像の描画サービスを使います |

### 変更した境界

- [EditorDependencies](../../../GLogo/ViewModels/EditorDependencies.swift) に、メタデータの保存先・描画サービス（どちらも共有インスタンス）と、描画の更新を作る関数を加えました。
- `ImageMetadataEditUseCase`・`ImageElementMetadataRevertUseCase`（保存先）、`ImageRenderRefreshUseCase`（描画の間引き）、`FilterPreviewUseCase`・`ImageCacheReleaseUseCase`（描画サービス）から、Infrastructure を指す既定値を外しました。
- `ElementViewModel` は、調整・フィルターで共有する描画の更新、フレーム用の描画の更新、メタデータの保存先を初期化で受け取ります。`EditorView` が `@StateObject` の生成時に、エディタの依存から作って渡します。フレームと調整の ViewModel は、描画の更新とメタデータ編集の UseCase を初期化で受け取ります。
- 共有関係をテストで照合するため、3つのパネルの ViewModel が持つ描画の更新を内部公開にしました（読み取りのみ）。

**生成の単位とタイミング（変えていません）**

| 実装 | 単位 |
| --- | --- |
| メタデータの保存先・描画サービス | アプリ全体で共有インスタンス1つ |
| メタデータ編集の UseCase | フレーム用と調整用に1つずつ（パネルの生成時） |
| Revert の UseCase | エディタに1つ（Revert できるかの判定用）。Revert イベントでは適用のたびに作る |
| 描画の更新 | パネルの生成時に2つ（調整・フィルターの共有分、フレーム用）。それぞれ描画の間引きを持つ |

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。
- **Info**: 共有関係をテストで照合するため、3つのパネルの ViewModel が持つ描画の更新を内部公開にしました。読み取りだけで、差し替えはできません。
- **Info**: Revert イベントはメタデータの保存先への参照を持ちます。保存先はアプリ全体の共有インスタンスなので、履歴（最大100件）に残っても寿命は変わりません。
- **Test Coverage**:
  - [EditorDependenciesTests](../../../GLogoTests/Integration/EditorDependenciesTests.swift) に3件を追加しました。Revert の適用・Undo・Redo で保存先を操作する範囲（Undo では操作しない）、フレームと調整のメタデータ記録の届き先、調整とフィルターが同じ描画の更新を共有しフレームは別であることを確認します。初期化のテストには、描画の更新をエディタの初期化では作らないことを加えました。
  - [AppCompositionTests](../../../GLogoTests/Integration/AppCompositionTests.swift) 1件は、描画の更新ごとに描画の間引きが分かれていること（一方の取り消しが他方の予約を消さない）を確認します。
  - [ImagePreviewDependencyTests](../../../GLogoTests/Integration/ImagePreviewDependencyTests.swift) 2件は、メモリ警告で注入した描画サービスを既定の解放対象にし、画像と同じサービスは1回だけ、画像ごとの別のサービスも解放し、画像がなくても解放することを確認します。サムネイルが選んだ画像の描画サービスを使うことは、同じファイルの既存テストが引き続き確認しています。
  - [EditorViewDependencyTests](../../../GLogoTests/Integration/EditorViewDependencyTests.swift) 1件はエディタ画面を実際に表示し、描画の更新を2つだけ作り、再描画では作らないことを確認します。組み立てだけのテストへの切り替えは不要でした。
- **回帰テスト棚卸し**: 既存テストの期待値は変えていません。既定値に頼っていた数か所（フレームの ViewModel の生成1か所、描画の更新の既定値1か所、Revert の UseCase の既定値1か所、キャッシュ解放2か所）は、以前と同じ実装を明示する形にしました。`ElementViewModel` の44か所は、テスト側の生成口でエディタの依存から組み立てます。
- **Verification**: GLogoTests 394件中391件成功（失敗1件は既知の `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用）。UI テストはパネル16件（調整・エフェクト・フィルター・フレーム・AI ツール・テキストと、第9回の2画面）・起動（表示条件4通り）・画面の基本表示の計21件が成功しました。`rg` で、ViewModels に Infrastructure の型名がなく、UseCases に残るのは `ImageSourceResolver` の既定値1か所だけであることを確認しました。変更したファイルからの新しいビルド警告はありません（既存の weak 変数の警告は残っています）。`git diff --check`（新規ファイルを含む）と文書の相対リンクも確認しました。iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormatは未導入のため実行できません。Codegraph は未接続のため、参照の確認は `rg` とコンパイラで行いました。

### 残り

- `ImageSourceResolver` の既定値（`ImageAssetRepository.shared`）は、Model の Decoder の依存注入を扱う回まで残る例外です。初期化引数の既定値の問題は、この例外を除いて解消しましたが、「すべて解消」とは扱いません。
- Model から Infrastructure への参照（描画、`copy()` などでの読み込み、Decoder の既定値、背景設定のアセット読み込み）は、段階3の描画・キャッシュの移動とあわせて扱います。

## 段階3・第11回：ジェスチャーの変形の履歴（2026-11-07）

### 計画と確認した経路

キャンバス上の移動・拡大縮小・回転（SwiftUI の選択枠のジェスチャー）は履歴に積まれず、Undo できませんでした。UIKit キャンバスの座標操作の経路（終了時に1件を記録する）は、2025-12-22 の `d1895f9` 以降アプリから呼ばれておらず、アプリで履歴に積まれる変形はダブルタップの回転リセットだけでした（README の残件）。

計画の前に、確認用の UI テスト（XCTest の非公開 API で指ごとの経路を合成。一時的なもので、コミットしない）で、実際の通知の順を確認しました。iPhone 17 Pro／iOS 26.1 Simulator です。

| 操作 | 観測した通知 |
| --- | --- |
| 1本のドラッグ | 移動の変化のあと、指を離すと終了 |
| 2本のピンチ・回転（同時に置く） | 移動は始まらない。拡大縮小・回転が最後の指を離したときにそろって終了 |
| ピンチ中に片方の指を離して残りの指で動かす | 拡大縮小・回転が残りの指で続き、その指を離したときに終了 |
| 1本でドラッグ中に2本目の指を置く | 移動が終了通知なしでやり直し、2本目の指を追う。2本目を離すと終了し、そのあとの1本目の動きは通知されない |
| 操作中の2本目の指のタップ | 選択の切り替え・解除、Undo、保存の受付、回転リセットが起きる。選択の切り替え・保存のあとも続きの通知が届き、新しい要素や保存後の要素が古い操作の移動量だけ動く。選択が外れて選択枠が消えると、終了通知は届かない |

計画は Codex のレビューで補正し、次の条件を実装と検証に含めました。

| 条件 | 対応 |
| --- | --- |
| 1件にまとめる区間を正確にする | 下の「区間の定義」。指の本数ではなく通知の届いた種類で判定し、上の観測で1件に収まることを確認した |
| 保存・選択の切り替えでは途中までを確定する | 保存の受付（保存入力の取得前）と、選択の通知の時点で1件にする。「保存開始では履歴を追加しない」という取り決めを変更した（ユーザー了承） |
| 中断後の古い通知を新しい要素へ適用しない | 割り込みの後は、古い操作がすべて終わるまで、どの種類の変化も適用しない（あとから始まった種類も含む） |
| 終了通知は保存中でも処理する | 終了通知の処理を、保存中かどうかの判定より前に置いた |
| 古い選択枠の消滅が新しい操作を確定・解除しない | 選択枠の消滅は、選択中の要素（または未選択）を表示していた場合だけ処理する |
| Undo／Redo は表示と実行の両方で止める | `canUndo`／`canRedo` と `undo()`／`redo()` の両方で判定する |
| UI テストで位置・サイズの復元を確かめる | DEBUG ビルドで選択枠が要素の値（キャンバス座標の位置・サイズと回転）を公開し、操作前後と Undo／Redo 後の値を比べる。識別子の frame は要素ではなくキャンバス全体を返すため、操作する位置は frame の原点に値を足して求め、ピンチの前には、ピンチの中心（frame の中心）が要素の内側にあることを確かめる |

### 変更した境界

**区間の定義**: 選択中の要素に、移動・拡大縮小・回転のどれかでしきい値（0.5pt、倍率 0.001、0.001rad）を超える変化が初めて届いた時点から、通知が届いた種類（しきい値未満を含む）がすべて終了を通知するまでを1回の操作とし、`ElementTransformedEvent` 1件にします。開始値は最初の変化の直前の値で、要素の ID と一緒に保持します。記録する属性は、区間中に動かした種類の属性だけです（移動→位置、拡大縮小→サイズ、回転→角度）。変化がなければ記録しません。

| 境界 | 扱い |
| --- | --- |
| 保存の受付 | `prepareForImageSave`（`isSaving` を立てる前）で未確定の差分を1件にし、古い操作の続きを終了まで無視します。保存中に始まった操作も終了まで無視します。保存される内容は画面の値のままです |
| 選択の切り替え・解除 | 選択の通知（変更前に届く）で、切り替え前の要素の差分を1件にし、続きを終了まで無視します |
| 削除 | 削除の記録より前に1件にします。Undo で削除・変形の順に戻ります |
| 選択枠の消滅（未選択・テキスト編集の開始・モードの切り替え） | `onDisappear` で、表示していた要素の差分を1件にし、進行状態と無視の印を消します |
| Undo／Redo | 未確定の変形があるあいだは受け付けません（ボタン・キーボードショートカット・直接の呼び出し） |
| 回転リセット | 未確定の変形があるあいだと、割り込み後の古い操作が続くあいだは受け付けません |

- [ElementTransformViewModel](../../../GLogo/ViewModels/ElementTransformViewModel.swift): 区間の開始値・動かした種類、通知の届いた種類、無視している種類を持ちます。保存・選択・削除の境界は `interruptManipulation()`、選択枠の消滅は `endGesturesForRemovedOverlay(showing:)` です。座標操作（UIKit の経路）は従来どおり開始値だけを破棄し、次の回（第12回の候補）で削除します（第12回で削除済み）。
- [ElementTransformUseCase](../../../GLogo/UseCases/Editing/Transform/ElementTransformUseCase.swift): 動かした種類の属性だけを含める `commitEvent(from:to:limitedTo:)` を加えました（中は既存の `commitEvent`）。イベントの定義・保存形式・描画は変えていません。
- [EditorViewModel](../../../GLogo/ViewModels/EditorViewModel.swift): 保存の準備・削除から境界の処理を呼び、`canUndo`／`canRedo` と `undo()`／`redo()` で未確定の変形を判定します。UI テスト用の fixture `onScreenImage`（DEBUG）を加えました。
- View: [EditorCanvasContainerView](../../../GLogo/Views/Editor/Canvas/EditorCanvasContainerView.swift) が選択枠の消滅を伝えます。[ElementSelectionView](../../../GLogo/Views/Editor/Canvas/ElementSelectionView.swift) は DEBUG ビルドだけ、UI テスト用の識別子と要素の値を公開します。Undo／Redo ボタンに識別子を付けました。

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。
- **Info**: 操作中は Undo／Redo ボタンが無効になります（ジェスチャーのたびに表示が切り替わります）。1回の操作ごとに履歴1件を使うため、上限（100件）に早く達します。上限は今回は変えないと合意しました。
- **Info**: 選択枠の消滅の扱いは、選択を切り替えても選択枠が作り直されない（SwiftUI の同じ表示として残る）ことを前提にしています。確認用テストで、切り替えでは消滅の通知が来ないことを確かめました。選択枠に `.id` を付けるなどで作り直すようにした場合は、この前提を見直します。
- **Info**: システムによる取り消しなどで終了通知が届かない場合は、未確定の操作や無視の印が、同じ種類の次の操作が終わるまで残る可能性があります（未観測）。README の残件に記録しました。
- **Info**: `test_restartedDrag_staysInOneEntry` は、2本目の指でドラッグがやり直しになったときに最初の基準値を使う既存の挙動（要素が飛ぶ不具合）も確かめています。その不具合を直す回で期待値を見直します。
- **Test Coverage**:
  - [ElementTransformViewModelTests](../../../GLogoTests/Integration/ElementTransformViewModelTests.swift) に15件を追加しました（9件から24件）。1回の操作で1件、同時の操作で1件、ドラッグのやり直しでも1件、変化なしは記録しない、終了通知の重複、操作中の Undo／Redo（表示と実行、変化なしで終わったときの復帰）、回転リセットの抑止、選択枠の消滅（表示中の要素だけを確定し、古い選択枠の通知では新しい操作を確定・解除しない）、動かした属性だけの記録、選択の切り替え後に古い操作全体を無視、保存中の終了通知の処理、削除の前の確定、選択の解除後の無視の印の解除、古い操作が続くあいだの回転リセットの抑止です。
  - [ElementTransformUseCaseTests](../../../GLogoTests/Unit/ElementTransformUseCaseTests.swift) 2件は、動かした種類の属性だけを含め、ほかの属性の変化だけでは履歴を作らないことを確認します。
  - [EditorGestureUndoUITests](../../../GLogoUITests/EditorGestureUndoUITests.swift) 2件は、実際のドラッグ・ピンチの前後と Undo／Redo の後で、要素の位置・サイズの値を比べます。
  - 実際の2本指の割り込み（選択の切り替え・解除、Undo、画像一覧からの選択、保存）は、確認用 UI テスト（一時的なもの）6件で、実装後にも確かめました。どれも想定どおりで、操作中の Undo は呼ばれず（ボタンが無効）、保存後に要素が飛ぶこともありませんでした。非公開 API を使うため、テストとしては残していません。
- **回帰テスト棚卸し**: 期待値を変えたのは3件です。同時のジェスチャーの終了後に履歴1件（`test_concurrentGestures_finishRenderingAfterLastEnd`）、保存の受付で1件・保存後の続きは無視（`test_save_commitsGestureAndBlocksMutations` に改名）、選択の切り替え後の続きは無視（`NoOpGestureIntegrationTests.testRotationGesture_ClearsBaseStateWhenSelectionChanges`）。座標操作の経路のテスト（`test_manipulations_preserveUndoRedo`・`test_canvasCallbacks_useSharedTransform` など）は、アプリから呼ばれない経路を守っているだけなので、次の回で経路と一緒に整理します。保存スタブに、保存入力を受け取った時点のフック（`onSave`）を加えました。
- **Verification**: GLogoTests 411件中407件成功（失敗2件は性能テスト：既知の `testPreviewLatencySDR_4K_P95` と、まれに上限を超える `testPreviewLatencyHDR_4K_P95`。性能テストだけを再実行すると HDR 側は成功し、失敗は SDR 側1件だけ。スキップ2件は実機専用）。その前の全体実行は 411件中408件成功（失敗は SDR 側1件）。UI テストは GLogoUITests 全体の30件が成功しました（パネル16件、画面の基本表示4件、削除の流れ3件、追加したジェスチャーの Undo 2件、起動（表示条件4通りを1件と数える）、起動性能2件、既定のテスト2件）。1つ目のコミット単独の状態でも、関連の38件（UI 2件を含む）が成功しました。確認用 UI テスト（非公開 API、一時的なもの）は、計画の前に14件、実装後に6件を実行しました。変更したファイルからの新しいビルド警告はありません。`git diff --check`（新規ファイルを含む）と文書の相対リンクも確認しました。iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です（2本目のタップで2回呼ばれる現象の実機確認は任意）。SwiftFormat は未導入のため実行できません。Codegraph は未接続のため、参照の確認は `rg` とコンパイラで行いました。

### 残り

- 使われていない UIKit キャンバスの座標操作の経路（次の回で削除）。
- 2本目の指でドラッグがやり直しになり要素が飛ぶ不具合、システムによる取り消しで終了通知が届かない場合の扱い（どちらも、選択枠からジェスチャーの終了・やり直しを伝える仕組みで扱う）。
- 2本目のタップで動作が2回呼ばれる現象は、非公開 API の合成で観測したものとして記録だけ残します。

## 段階3・第12回：使われていない UIKit キャンバスの座標操作の経路の削除（2026-11-07）

### 計画と確認した経路

第11回の計画で見つけた、アプリから呼ばれていない UIKit キャンバスの座標操作の経路と、それを消すと連鎖して使われなくなる型・関数を削除しました。挙動を変えないリファクタリングです。参照元は `rg` とコンパイラで確認し、Codex は Serena でも確認しました。

計画は Codex のレビューで補正し、次の条件を実装と検証に含めました。

| 条件 | 対応 |
| --- | --- |
| 比較元は第11回完了後のコードにし、同じ fixture・シミュレーターで削除前後を比べる | 確認用 UI テスト（v3、14件）を、第11回のコミット（`a4711b5`）と削除後のコードで実行し、要素の値・Undo／Redo・履歴の並びと件数・割り込み後の再開・節目の回数を突き合わせた |
| 通常のタップとダブルタップも確認する | 選択中の要素のタップで履歴が増えないこと、別の要素・空き領域のタップでの選択と解除、ダブルタップの回転リセットと Undo／Redo を比較に含めた。`SelectionBorder` の `contentShape` と位置の指定は残した |
| 書き直すテストは、現在の契約に合わせる | 描画のテストは「選択中の画像の操作中描画が、選択の変更で終わること」だけを守る（全画像の準備・終了は削除対象）。保存のテストは、保存完了後も古い操作が終わるまでは無視し、その後の新しい操作は受け付ける第11回の契約を保った |

### 変更した範囲

| 層 | 削除したもの |
| --- | --- |
| View | `CanvasView` の操作コールバック3つと Coordinator での接続、`isReducingQualityDuringManipulation`（常に false）、`highResolutionThreshold`、選択枠・ハンドル・ロックの描画（`drawSelectionHandles`・`drawHandle`・`drawLockIcon`）と、そこでだけ使う定数5つ |
| View | `ElementSelectionView` の `HandleType`・`SelectionHandle`・`getHandleTypes`、使われていないプロパティ3つ、枠ドラッグ用の引数3つ。`SelectionBorder` のドラッグのコールバックとドラッグのジェスチャー（枠の描画・`contentShape`・位置の指定は残す）。`EditorCanvasContainerView` が渡していた `nil` の引数3つ |
| ViewModel | `ElementTransformViewModel` の `startManipulation`／`continueManipulation`／`endManipulation`、`manipulationType`、開始点・開始値、描画の準備・終了（`prepareImageRenderingForManipulation`／`finishImageRenderingAfterManipulation`）、`updatePosition`／`updateSize`／`updateRotation` |
| Model | `ElementTransformState.applying` と `ElementManipulationType`。`ElementTransformState` 本体（ジェスチャーの開始値）と `ElementGestureTransformKind` は残す |
| UseCase | `ManipulationRenderingUseCase`（ファイルごと）。高解像度画像の操作中に描画を軽くする仕組みだったが、呼び出し元は上の描画の準備・終了だけだった。いまのジェスチャーの経路では、`ImageEditingSessionUseCase` が選択中の画像の描画を切り替える |

行数は、`CanvasView` 592→421、`ElementSelectionView` 338→154、`ElementTransformViewModel` 295→223、`ElementTransformState` 49→21 です（差分全体で 75行追加・672行削除）。

### 検証と変更後レビュー

**削除の前後の比較（確認用 UI テスト v3）**: 同じ fixture（要素2つ）・同じシミュレーター・同じ指の合成で、第11回のコミット（`a4711b5`）と削除後のコードを実行し、結果を突き合わせました。確認用 UI テストは非公開 API を使う一時的なもので、テストとしては残していません。

| 分類 | シナリオ | 結果 |
| --- | --- | --- |
| 基準の操作 | ドラッグ、2本のピンチ、ピンチ中に片指を離して移動、ドラッグ中に2本目を置く、回転とピンチ、ずらして離す | 6件とも、最終の位置・サイズ・角度、Undo／Redo の後の値とボタンの状態、履歴の並びと件数、終了などの節目の回数が一致 |
| 割り込み | 空き領域のタップで選択を解除、別の要素のタップで切り替え、操作中の Undo、画像一覧からの選択、保存 | 5件とも、要素の値・履歴・割り込み後の新しいドラッグによる再開が一致。保存の1件だけ、無視した通知の回数が37回と36回で異なったが、変化の通知の回数（61回と60回）と同じく指の合成のタイミングによる揺れで、値と履歴は一致 |
| タップ | 選択中の要素のタップ、別の要素・空き領域・元の要素の順のタップ、回転後のダブルタップ（2回目は角度0の状態） | 3件とも一致。タップで履歴は増えず、選択と解除、ダブルタップの回転リセットとその Undo／Redo は従来どおり |

- **Critical／Warning**: 指摘なし。
- **Info**: `ManipulationRenderingUseCase` の削除で、高解像度画像の操作中に描画を軽くする仕組み（使われていなかった）がなくなりました。ジェスチャーの操作中に高解像度画像の描画が重くなる場合は、ジェスチャーの経路に合わせて別に設計します。
- **Info**: `SelectionBorder` からドラッグのジェスチャーを取り除いたため、同じ枠に付く移動・拡大縮小・回転のジェスチャーの組み合わせが変わりました。上の比較で、通知の順と結果が変わらないことを確かめました。実機では確かめていません。
- **Test Coverage**:
  - 削除: 座標操作の経路のテスト4件（`test_manipulations_preserveUndoRedo`・`test_selection_discardsPendingManipulationImmediately`・`test_canvasCallbacks_useSharedTransform`・`test_noChange_doesNotRecordHistory`）。同じ趣旨はジェスチャーのテストが第11回から確かめています。
  - 書き直し（現在の契約に合わせる）: `test_save_commitsGestureAndBlocksMutations`（座標操作の部分を外し、保存中に始まった操作も終わるまで適用しないことを加えた）、`test_selection_endsGesturePreview`（旧 `test_selection_finishesPreparedRendering`。選択中の画像の操作中描画が、選択の変更で終わること。全画像の準備・終了は削除した仕組みのため確かめない）、`test_sharedChild_notifiesAndDoesNotRetainEditor`（ジェスチャーで通知と解放後の入力を確かめる）、`EditorImageSaveIntegrationTests.test_save_gestureStopsUntilCompletion`（旧 `test_save_manipulation_stopsUntilCompletion`。保存完了後も古い操作が終わるまでは無視し、その後の新しい操作は受け付ける）、`OperationMemoryLeakTests.testManipulationDoesNotLeak`（ジェスチャーで確かめる）。
- **回帰テスト棚卸し**: 第11回の記録で「次の回で経路と一緒に整理する」とした座標操作の経路のテストを、上のとおり整理しました。第11回の契約の期待値は変えていません。
- **Verification**: GLogoTests 407件中404件成功（失敗1件は既知の `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用。削除したテスト4件の分だけ件数が減った）。UI テストは GLogoUITests 全体の30件が成功しました。変更したファイルからの新しいビルド警告はありません。`rg` で削除した名前の参照がないこと（トリミング画面の同名の別のコールバックを除く）、`git diff --check`、文書の相対リンクを確認しました。iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormat は未導入のため実行できません。参照の確認は `rg` とコンパイラで行いました（Codex は Serena でも確認）。

### 残り

- 撤廃したズーム・パンの名残（`viewTransform` と、呼び出し元のない変換関数）と、描画に使われていない `CanvasView.selectedElement`（README の残件）。
- 2本目の指でドラッグがやり直しになり要素が飛ぶ不具合と、システムによる取り消しの扱い（第11回からの残件）。

## 段階3・第13回：ジェスチャーのやり直しとアプリの中断（2026-11-07）

### 計画と確認した経路

第11回の残件のうち、2本目の指でドラッグがやり直しになり要素が飛ぶ不具合と、システムによる取り消しの扱いを対象にしました。計画の前に、確認用の UI テスト（XCTest の非公開 API で指ごとの経路を合成。中断は確認用ビルドでアプリを裏に回して再現。一時的なもので、コミットしない）で、第12回のコードの実際の通知を確かめました。

| 操作 | 観測した通知 |
| --- | --- |
| 1本でドラッグ中に2本目の指を置く | 移動が終了通知なしでやり直し、2本目の指を追う。やり直しの最初の通知（移動量 0）で区間の始点（`startLocation`）が変わり、`GestureState` のリセットより先に届く。古い基準を使うため要素が飛んでいた（60→70） |
| ピンチ中に片方の指を離して置き直す、3本目の指を置く | 拡大縮小・回転は続くが、値が不連続に跳ねる（倍率 2.0→0.2、回転 0→0.785rad）。やり直しを示す信号は出ない |
| 操作中にアプリが裏に回る | 非アクティブになったあとも、指を離すまでジェスチャーは続き、終了通知も届く。Undo の抑止や無視の印は残らない。ただし裏に回るアニメーションで座標がずれ、跳ねた値で1件が確定していた（移動 (30,0)→(-8,-24)、倍率 1.8→3.3） |

計画は Codex のレビューで補正し、次の条件を実装と検証に含めました。

| 条件 | 対応 |
| --- | --- |
| やり直しは直前の位置から滑らかに続け、履歴は操作全体で1件 | 区間の始点が変わったら、位置の計算の基準だけを現在の位置に置き換える。Undo 用の操作の開始値は変えない |
| ドラッグ側の判定の順序 | 保存中・中断後の抑止の判定を先に行い、移動量のしきい値の判定より前に始点の変化を扱う（移動量 0 でも基準を置き換える） |
| 新しく持つ始点の片付け | 通常の終了・割り込み・選択枠の消滅で、始点も片付ける |
| 中断の通知は同期で確定する | 既存のメモリ警告の監視（`Task` で遅らせる形）は流用しない。通知を受けたメインスレッドで、その場で `interruptManipulation()` を呼ぶ |
| 中断のテスト | 通知を送った直後（待機なし）に確定済みであること、保存の受付のあとの通知、通知の重複で履歴が増えないことを確かめる |
| ピンチ・回転の跳ね、終了通知が届かない取り消し | 今回は扱わず、残件として分ける |

### 変更した境界

- **やり直し**: [ElementSelectionView](../../../GLogo/Views/Editor/Canvas/ElementSelectionView.swift) が移動の通知に区間の始点を添え、[EditorCanvasContainerView](../../../GLogo/Views/Editor/Canvas/EditorCanvasContainerView.swift) が `applyGestureTransform(…, moveStart:, …)` へ渡します。[ElementTransformViewModel](../../../GLogo/ViewModels/ElementTransformViewModel.swift) は移動の区間の始点を持ち、変わったら位置の基準を現在の位置に置き換えます。割り込みの後（無視している間）のやり直しは、古い操作の続きとして無視し続けます。
- **アプリの中断**: [EditorViewModel](../../../GLogo/ViewModels/EditorViewModel.swift) が `UIApplication.willResignActiveNotification` を `queue: nil` で受け、`MainActor.assumeIsolated` でその場で `transform.interruptManipulation()` を呼びます（第11回の保存・選択の切り替えと同じ割り込みの扱い）。非アクティブになった時点の値で1件確定し、Undo の抑止と操作中の描画を終え、ずれた続きの通知は終了まで無視します。前面に戻った時点では無視の印を外しません（指が置かれたまま戻った場合に、ずれた続きが反映されないように）。
- 変えないもの: イベントの定義、保存形式、描画、履歴の上限。

### 検証と変更後レビュー

**実装後の確認（確認用 UI テスト）**: 第12回のコードと第13回のコードで、同じ fixture・シミュレーター・指の合成を使って比べました。

| シナリオ | 第12回 | 第13回 |
| --- | --- | --- |
| ドラッグ中に2本目の指を置く | 70（飛ぶ） | 100（60 から、新しい指の 40 だけ続く） |
| ドラッグ中にアプリが裏に回る | (21.15, 95.43) で確定（ずれた値） | (56, 120) で確定。続くずれた移動の通知8回は無視 |
| ピンチ中にアプリが裏に回る | 幅 563.89 で確定（ずれた値） | 幅 287.87 で確定 |
| 古い操作を無視している間にアプリが裏に回る | 変化なし | 変化なし |
| ピンチ中の指の組み合わせの変化 | 跳ねる | 跳ねる（残件） |

中断の後は、どのシナリオでも新しいドラッグが効き、Undo も使えました。アプリ側の記録では、非アクティブの通知を受けたその場で確定し、その後の移動の通知はすべて無視していました。第12回との比較（14件）では、意図どおり「ドラッグ中に2本目を置く」の1件だけ値が変わり（70→100）、ほかは要素の値・Undo／Redo・履歴が一致しました（無視した通知の回数だけは、指の合成のタイミングで揺れる）。

- **Critical／Warning**: 指摘なし。
- **Info**: 非アクティブの通知は `MainActor.assumeIsolated` で受けるため、メインスレッド以外から送られると停止します。UIKit はメインスレッドで送り、テストも MainActor 上から送ります。
- **Info**: 前面に戻った時点では無視の印を外しません。終了通知が届かない取り消し（未観測）では、同じ種類の次の操作が終わるまで印が残る可能性があります（README の残件のまま）。
- **Info**: やり直しを検出するのは移動だけです。拡大縮小・回転の跳ね（指の組み合わせの変化）は残件です。
- **Info**: テストで送る非アクティブの通知は、テストを動かしているアプリの中のほかの受け口にも届きます。アプリにほかの受け口がないことを確かめました。
- **Test Coverage**:
  - [ElementTransformViewModelTests](../../../GLogoTests/Integration/ElementTransformViewModelTests.swift) は20件から28件になりました。やり直しは `test_restartedDrag_continuesFromCurrentPosition`（旧 `test_restartedDrag_staysInOneEntry`。飛ぶ挙動を前提にしていた期待値を、滑らかに続く形に変えた）、`test_restartBeforeMovement_startsFromCurrentPosition`、`test_sameMoveStart_keepsBase`、`test_restartWhileSuppressed_staysIgnored`。中断は `test_resignActive_commitsPendingGestureImmediately`（通知を送った直後に待たずに確定済みで、ずれた続きを無視する）、`test_resignActive_endsImagePreview`、`test_resignActive_duplicateNotificationsRecordOnce`、`test_saveThenResignActive_recordsOnce`、`test_resignActive_withoutGesture_changesNothing`。
  - 新しい受け口で循環参照が増えていないことを、ViewModelMemoryLeakTests 3件で確かめました。
  - 実際の2本指の操作とアプリの中断は、確認用 UI テスト（一時的なもの）で確かめました。
- **回帰テスト棚卸し**: 期待値を変えたのは、やり直しの1件だけです（第11回で、要素が飛ぶ既存の挙動を記録していたもの）。
- **Verification**: GLogoTests 415件中412件成功（失敗1件は既知の `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用）。UI テストは GLogoUITests 全体の30件が成功しました。1つ目のコミット単独の状態でも、関連の41件と UI テスト2件が成功しました。変更したファイルからの新しいビルド警告はありません。`git diff --check` と文書の相対リンクを確認しました。iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormat は未導入のため実行できません。

### 残り

- ピンチ中の指の組み合わせの変化による跳ね（信頼できる検出方法を調べてから扱う）。
- 終了通知が届かない取り消し（未観測）。
- 次の候補は、ズーム・パンの名残と `CanvasView.selectedElement` の整理、続いて Model の Decoder の依存注入（ユーザー・Codex 合意の順）。
