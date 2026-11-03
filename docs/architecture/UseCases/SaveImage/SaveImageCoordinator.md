# SaveImageCoordinatorの保存境界と非同期所有

この文書は、写真ライブラリへの保存境界と入力の所有契約を記録します。2026-10-25 に保存要求の Protocol 境界と画面状態を分離し、2026-10-28 に保存受付時の入力固定を実装しました。

- 対象: [SaveImageCoordinator.swift](../../../../GLogo/UseCases/SaveImage/SaveImageCoordinator.swift)
- 全体方針: [比較と責務分離方針](../../README.md)
- 関連: [EditorViewModel](../../ViewModels/EditorViewModel.md)、[ImageElement](../../Models/ImageElement.md)、[プロジェクト永続化](../Storage/ProjectStorage.md)

## 確認した処理の流れ

1. `EditorViewModel` が `ImageSaveViewModel` へ要求を渡します。子は重複要求を除外し、親の `prepareForImageSave` を呼んでから保存中フラグを更新します。
2. Coordinator が MainActor 上で `SaveProjectSnapshot` を作り、その要素構成で保存モードを判定してから写真ライブラリ権限を確認します。
3. バックグラウンドの単一タスクで保存専用の要素から画像を選び、既存のフィルター適用または合成を行います。
4. Writerが画像を書き込み、結果をMainActor上のcompletionへ返します。
5. `ImageSaveViewModel` が保存中フラグと失敗理由を更新し、画面へ結果を伝えます。親は状態を参照し、子の変更通知を転送します。

これは写真ライブラリへの画像書き出しです。`ProjectStorage`による編集可能なプロジェクトのJSON保存とは別の経路です。

## 良い境界

| 依存 | 責務 |
| --- | --- |
| `SaveImagePolicy` | 保存モードの判定 |
| `ImageSelecting` | 保存対象・ベース画像の選定 |
| `ImageProcessing` | フィルター適用・合成 |
| `PhotoLibraryWriting` | 権限確認と写真ライブラリへの書き込み |

依存は初期化時に注入でき、異常系を代替実装で再現できます。合成失敗を元画像の保存成功に置き換えず、`PhotoLibrarySaveFailure`で分類する契約もあります。

ViewModel 側には `PhotoLibrarySaving` を注入でき、既定の実装は `SaveImageCoordinator` です。要求受付から非同期完了までの表示状態は [ImageSaveViewModelTests](../../../../GLogoTests/Unit/ImageSaveViewModelTests.swift) と [EditorImageSaveIntegrationTests](../../../../GLogoTests/Integration/EditorImageSaveIntegrationTests.swift) で検証します。

## 保存入力の固定（2026-10-28）

以前の `DetachedProjectBox` は編集中のプロジェクトをそのまま保持していました。現在は [SaveProjectSnapshot](../../../../GLogo/UseCases/SaveImage/SaveProjectSnapshot.swift) が保存専用の独立した要素を作ります。`save` と `saveComposite` のどちらも権限待ちの前に固定し、UI を経由しない直接呼び出しにも同じ契約を適用します。

- 画像は `ImageElement.renderCopy()` で調整値、フレーム、マスク、フィルターレシピ、元画像を固定します。ID・役割・インポート順・zIndex も維持します。表示用キャッシュ、編集中フラグ、メタデータ履歴は持ち越しません。
- 文字と図形は既存のコピー処理を使い、ID・名前・zIndex を保存用に維持します。文字効果は深いコピー、配列・Data は値として独立します。
- 元画像の UIImage は再エンコードせず保持します。向き・scale・色空間を変えず、編集側のソース差し替えや元ファイル削除から独立します。
- `BackgroundSettings.renderCopy()` も背景画像を保持します。設定値だけでなく、権限待ち中の同名背景アセットの更新からも切り離します。保持情報は実行時だけで、Codable キーは追加していません。
- スナップショット内の可変 Model は保存1件の単一タスクが専有します。`@unchecked Sendable` はこの所有契約に依存します。任意の複数タスクで共有できる不変データ型への置き換えではありません。

## 残る競合と負荷の確認

- 保存中の AI 完了は編集側へ従来どおり適用されますが、固定済みの保存入力には届きません。削除・Undo・別加工後の古い AI 結果の抑止も実装済みです。判定条件と検証は [EditorViewModel](../../ViewModels/EditorViewModel.md) の競合対策を参照してください。保存受付自体は AI 要求を失効させません。
- cold 状態では元画像・背景画像の取得が MainActor 上の受付処理に含まれます。再圧縮とフィルター計算はここで行いませんが、大量画像・4K／8K の受付遅延とメモリピークは実機で未測定です。
- 画像資源は権限待ちから保存完了まで保持します。編集側で不要になっても保存中は解放されません。所有者の画面が消えても、受付済みの保存は継続します。

## 責務と変更範囲

保存の受付と表示状態は `ImageSaveViewModel`、固定時点と保存フローは Coordinator、描画入力の組み立ては `SaveProjectSnapshot` が担当します。各 Model のコピー処理は属性と画像資源の独立化を担当します。選定・加工・書き込みの実装と、編集履歴・Revert・プロジェクト永続化の形式は変更していません。

`Task.detached`を除去すること自体は目的ではありません。高負荷処理をUIから分離しつつ、安全に渡せる入力と結果反映の所有者を設計します。

## 変更範囲と影響

実装ファイルは Coordinator、新規の `SaveProjectSnapshot`、`ImageElement`、`BackgroundSettings` です。`ImageProcessingService`、保存の Protocol、ViewModel は既存の入口を維持しています。

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

追加済みの検証:

- [SaveProjectSnapshotTests](../../../../GLogoTests/Unit/SaveProjectSnapshotTests.swift) 5件: 描画属性と編集状態の分離、文字効果・図形・背景の独立性、元ファイル削除、UIImage の同一性と向き・scale・色空間、同名背景アセットの更新とJSON契約。
- [SaveSnapshotIntegrationTests](../../../../GLogoTests/Integration/SaveSnapshotIntegrationTests.swift) 4件: 両保存入口の権限待ち、加工待ち中の構成変更、実際の AI 結果適用と Undo／Redo・削除、元プロジェクト解放後の保存継続。生成画像の比較と待機を制御する代替実装を使います。

検証結果（2026-10-28）:

- `xcodebuild -project GLogo.xcodeproj -scheme GLogo -configuration Debug -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18'` に対象ごとの `-only-testing:` と `test` を指定し、54件成功・失敗0・スキップ0を xcresult で確認しました。
- 対象は追加9件に加え、`SaveCoordinatorRegressionTests` 6件、`SaveCoordinatorMainActorCompletionRegressionTests` 2件、`SavePipelineRegressionTests` 18件、`ImageSaveViewModelTests` 5件、`EditorImageSaveIntegrationTests` 3件、`RevertSnapshotRegressionTests` 6件、`AIToolsViewModelTests` 5件です。
- 初回ビルドでは追加テストの保存状態名を誤って参照していたため修正しました。既存テストの期待値は変更していません。
- `git diff --check` と追加ファイル・文書リンクを確認。SwiftFormat は未インストールのため実行できません。全スイート、実機での写真ライブラリ保存、HDR 実機表示、4K／8K の時間・メモリ測定は未実施です。

変更後レビュー:

- **Critical**: 指摘なし。
- **Warning**: cold 画像の取得を含む受付処理の負荷は実機で未測定です。大量画像では MainActor の受付時間と保持メモリを確認する必要があります。
- **Info**: Model の技術依存・共有 static サービスの再構成は段階3に残ります。今回のスナップショットは保存専有の入力であり、永続化や編集用コピーには利用しません。
- **Assumptions**: 編集 Model の更新と保存受付は MainActor 上で行い、固定後のスナップショットは単一保存タスクへ渡します。
- **Test Coverage**: 既存の保存・描画・履歴・Revert のテストは引き続き有効です。新規テストは時間待ちの長さではなく、権限・加工・AI 完了順を制御して競合を検証します。
- **Verification**: 上記54件と差分を確認しました。未実施の実機・負荷検証は上記の残件です。


## 保存入力固定の負荷測定（2026-10-29）

4K／8K、元画像キャッシュあり／なしの計測テスト4件を追加し、Simulator で成功しました。MainActor 上の入力固定だけを測り、フィルター描画や全体の保存時間は含めません。測定条件・値・初回テスト設定の修正・実機の残件は [キャンセルと測定](../../AsyncCancellation.md) を参照してください。今回のキャンセル対応は編集側の AI・プレビュー描画に限定し、写真ライブラリへの保存は中止しません。


2026-10-31 に iPhone 16／iOS 26.6.2 でも保存入力測定4件が成功しました。元画像キャッシュなしの入力固定は今回の条件で平均0.1ms未満ですが、全画素デコードや描画・写真ライブラリ書き込みの時間ではありません。数値・測定条件は [実機測定](../../AsyncCancellation.md) に記録しています。
