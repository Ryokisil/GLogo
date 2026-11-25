# 全スイートと行カバレッジの確認

全スイート実行日: 2026-10-31。結果の集計・性能再確認日: 2026-11-01。
対象は `ref/ViewModel` の未コミット変更を含む作業ツリー。今回アプリ実装・テストの期待値・性能しきい値は変更していません。

## 判定とレビュー

- **Critical**: この実行から重大な機能不具合は確認されませんでした。網羅性や無欠陥を保証するものではありません。
- **Warning**: `NFRPerformanceTests.testPreviewLatencySDR_4K_P95` が上限100msを超過しました。全スイートでは110ms、カバレッジ無効の単独再実行でも148msで失敗したため、計測負荷だけが原因とは判断できません。変更前との比較と実機での同条件測定は未実施で、リファクタリングによる退行かは未判定です。
- **Warning**: `PhotoLibrarySaveTests.testSaveFailsWhenNoImageElements` が Simulator の写真追加権限ダイアログで待機しました。許可操作後に成功しましたが、未許可の環境では無人実行が止まるため、権限依存の分離が補強候補です。
- **Info**: アプリ本体の行カバレッジは **41.5%（16,225 / 39,098行）**。保存入力・取消・描画更新の主要な分離先は高い一方、親ViewModelやテキスト効果などに未実行経路があります。

## 実行条件と結果

- Xcode 27.1（27A9275）、Debug、iPhone 17 Pro／iOS 26.1 Simulator（23B86）。
- `GLogoTests` と `GLogoUITests` の両ターゲットを、対象の除外なし・並列実行なしで実行しました。Scheme の既存環境設定 `PERF_RUN_8K=1` も維持しています。
- xcresult のテスト定義単位の集計: **327件中、成功324件・失敗1件・スキップ2件**。実行時警告は0件です。
- 内訳: `GLogoTests` は成功298件・失敗1件・スキップ2件、`GLogoUITests` は26定義すべて成功。UI のパラメーター別実行は29回で、定義数と実行回数を混同しません。
- スキップは `DeviceCancellationPerformanceTests` の Vision／Core ML の2件です。実機専用のためで、先行する実機での成功結果は [キャンセルと測定](AsyncCancellation.md) に記録しています。今回のSimulatorカバレッジには統合していません。
- 全スイートは性能1件の失敗により `TEST FAILED`。後続のUIテストとカバレッジ収集は完了しています。

```sh
xcodebuild -project GLogo.xcodeproj -scheme GLogo -configuration Debug \
  -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18' \
  -enableCodeCoverage YES -parallel-testing-enabled NO \
  -resultBundlePath /tmp/glogo-full-coverage-20261031.xcresult test
```

## アプリ本体の行カバレッジ

`xccov` の `GLogo.app` ターゲットを使用し、テストコードを分母・分子に含めていません。行カバレッジは「その行を実行したか」であり、全分岐・組み合わせ・期待値の妥当性まで保証しません。

| 対象 | 実行行 / 計測対象行 | 行カバレッジ |
| --- | ---: | ---: |
| [EditorViewModel.swift](../../GLogo/ViewModels/EditorViewModel.swift) | 365 / 600 | 60.8% |
| [ElementViewModel.swift](../../GLogo/ViewModels/ElementViewModel.swift) | 75 / 150 | 50.0% |
| [ImageSaveViewModel.swift](../../GLogo/ViewModels/ImageSaveViewModel.swift) | 44 / 44 | 100.0% |
| [SaveProjectSnapshot.swift](../../GLogo/UseCases/SaveImage/SaveProjectSnapshot.swift) | 23 / 23 | 100.0% |
| [SaveImageCoordinator.swift](../../GLogo/UseCases/SaveImage/SaveImageCoordinator.swift) | 202 / 239 | 84.5% |
| [AIToolsViewModel.swift](../../GLogo/ViewModels/AIToolsViewModel.swift) | 224 / 239 | 93.7% |
| [ImageAdjustmentViewModel.swift](../../GLogo/ViewModels/ImageAdjustmentViewModel.swift) | 166 / 169 | 98.2% |
| [FilterPanelViewModel.swift](../../GLogo/ViewModels/FilterPanelViewModel.swift) | 82 / 83 | 98.8% |
| [ImageRenderRefreshUseCase.swift](../../GLogo/UseCases/Rendering/ImageRenderRefreshUseCase.swift) | 126 / 127 | 99.2% |
| [ImageRenderOperation.swift](../../GLogo/Infrastructure/Rendering/ImageRenderOperation.swift) | 85 / 85 | 100.0% |
| [TextEditingViewModel.swift](../../GLogo/ViewModels/TextEditingViewModel.swift) | 326 / 436 | 74.8% |
| [ImageFrameViewModel.swift](../../GLogo/ViewModels/ImageFrameViewModel.swift) | 196 / 212 | 92.5% |
| [ElementTransformViewModel.swift](../../GLogo/ViewModels/ElementTransformViewModel.swift) | 187 / 208 | 89.9% |
| [ShapeEditingViewModel.swift](../../GLogo/ViewModels/ShapeEditingViewModel.swift) | 50 / 70 | 71.4% |
| [ImageElement.swift](../../GLogo/Models/ImageElement.swift) | 842 / 1006 | 83.7% |

レイヤー別では Views 27.9%、Models 71.1%、ViewModels 61.0%、UseCases 59.5%、Utils 16.0%、App 52.5%です。数値が低いだけで不要・不具合とは判断しません。`ImageEditToken` のようにレポートに独立したファイル項目がない型は、0%とは扱いません。

## 補強の優先候補

1. **実行環境への依存**: 写真権限ダイアログを必要とする既存テストに、許可済みのWriterを注入し、画像なしの結果を決定的に検証する。権限拒否・許可の契約は既存Coordinatorテストで別途保護する。
2. **テキスト効果の確定経路**: `TextEditingViewModel` のグラデーション色変更、角度／不透明度の即時確定、行間変更が未実行。既存統合テストに、値と履歴、Undo／Redo、同値操作時の履歴抑止を追加する候補です。
3. **親に残る要素操作**: `EditorViewModel` の複製・最前面／最背面移動、`ElementViewModel` の名前・不透明度・可視性等の更新が未実行。選択参照と履歴を含む確認を優先します。
4. **図形パネルからの委譲**: `ShapeEditUseCase` は100%でも、`ShapeEditingViewModel` は71.4%。グラデーション色や一部属性は入口のガードのみ実行され、実変更経路を通っていません。下位UseCaseのテストとパネル入口のテストは役割を分けます。

これらは今回の計測とソース照合から得た候補で、テストや製品の修正はこの作業では実施していません。既存の競合・保存・履歴テストを保持し、重要な未実行経路を追加する方針です。

## 性能テストの切り分け

| 条件 | P95 | 平均 | 上限 | 結果 |
| --- | ---: | ---: | ---: | --- |
| 全スイート・カバレッジ有効 | 110ms | 100ms | 100ms | 失敗 |
| 単独再実行・カバレッジ無効 | 148ms | 115ms | 100ms | 失敗 |

各10標本。実行日・実行順・ホストの状態が異なるので、差分をカバレッジによる速度差とは解釈しません。

```sh
xcodebuild -project GLogo.xcodeproj -scheme GLogo -configuration Debug \
  -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18' \
  -enableCodeCoverage NO -parallel-testing-enabled NO \
  -only-testing:GLogoTests/NFRPerformanceTests/testPreviewLatencySDR_4K_P95 \
  -resultBundlePath /tmp/glogo-sdr-perf-recheck-20261101.xcresult test
```

## 成果物と検証範囲

- 全スイート: `/tmp/glogo-full-coverage-20261031.xcresult`
- 実行ログ: `/tmp/glogo-full-coverage-20261031.log`
- `xccov` JSON: `/tmp/glogo-full-coverage.json`
- テスト一覧／集計: `/tmp/glogo-full-tests.json`、`/tmp/glogo-full-summary.json`
- 性能再確認: `/tmp/glogo-sdr-perf-recheck-20261101.xcresult`、同名の `.log`

`/tmp` の成果物は永続保存ではありません。本書に主要数値と再実行コマンドを残します。

今回の作業は実行・集計・文書化のみで、MVVM／Clean境界、保存形式、描画式、履歴、キャッシュの製品実装は変更していません。既存テストの期待値も維持しています。集計は xcresult のサマリーとテストツリー、xccov のアプリターゲットを照合しました。全体の行カバレッジと、重要な契約を守るテストの充実度は分けて判断します。


## 段階3前の補強・第1回（2026-11-01）

### 方針と確認した経路

機能の責務分離とテストの補強は別の作業です。段階3の `ImageElement` 分離に先立ち、今回の計測で判明した重要な未実行経路から補強しました。

| 仮説 | 確認方法 | 対応 |
| --- | --- | --- |
| テキスト効果はスライダー経路に偏り、即時確定の履歴が未検証 | 子ViewModel → TextEditUseCase → EventSourcing の値変更と復元を照合 | 色・角度・不透明度・行間・文字間隔の即時操作、Undo／Redo、同値／無効対象を追加検証 |
| 複製時の選択・参照型効果・履歴が未検証 | Editor → TextElement.copy → ElementAddedEvent → Undo／Redo を照合 | 別ID・位置・効果の独立性・パネル選択・削除と再追加を検証 |
| 保存テストの権限依存が無人実行を止める | Editor → Coordinator → PhotoLibraryWriting と既存権限テストを照合 | 許可済みWriterを注入し、権限要求・実書き込みを禁止。タイムアウト付き完了待ちへ変更 |

Codegraph とソースで入口・履歴イベント・呼び出し候補を確認しました。Serena は利用できないため、詳細は `rg` とソース・テストで補っています。アプリ実装、保存形式、描画式、履歴イベントは変更していません。

### 実施した補強

- [TextEditingViewModelTests](../../GLogoTests/Integration/TextEditingViewModelTests.swift): 5件追加。グラデーション色の対象インデックス、角度／不透明度の即時確定、行間／文字間隔、同値操作後のRedo保持、非グラデーション・範囲外インデックス・選択解除を検証。
- [ElementEditIntegrationTests](../../GLogoTests/Integration/ElementEditIntegrationTests.swift): 2件追加。テキスト複製の別IDと効果の独立性、パネル選択、Undo／Redo、未選択時のRedo保持を検証。画像・図形の複製全体を網羅した結果ではありません。
- [PhotoLibrarySaveIntegrationTests](../../GLogoTests/Integration/PhotoLibrarySaveIntegrationTests.swift): 既存の画像なし失敗テストを維持し、Writerだけ差し替え。Coordinatorを含む実経路の `.noImageElements` と保存中フラグ解除を検証。

関連7スイート・**42件成功、失敗0件、スキップ0件、xcresult実行時警告0件**。追加7件と既存35件です。既存のスライダー履歴とCoordinatorの権限拒否・許可テストも成功しました。

```sh
xcodebuild -project GLogo.xcodeproj -scheme GLogo -configuration Debug \
  -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18' \
  -enableCodeCoverage YES -parallel-testing-enabled NO \
  -only-testing:GLogoTests/TextEditingViewModelTests \
  -only-testing:GLogoTests/TextSliderHistoryIntegrationTests \
  -only-testing:GLogoTests/TextEditUseCaseTests \
  -only-testing:GLogoTests/ElementEditIntegrationTests \
  -only-testing:GLogoTests/PhotoLibrarySaveTests \
  -only-testing:GLogoTests/SaveCoordinatorRegressionTests \
  -only-testing:GLogoTests/SaveCoordinatorMainActorCompletionRegressionTests \
  -resultBundlePath /tmp/glogo-coverage-strengthening-20261101.xcresult test
```

今回の対象スイートだけで `TextEditingViewModel` は399 / 436行（91.5%）を実行しました。先の全スイートでは326 / 436行（74.8%）でした。以前未実行だった即時操作5メソッドと複製メソッドは、今回それぞれ全行を実行しています。全体の41.5%を再測定・更新した結果ではなく、先の全スイートとのカバレッジ統合も行っていません。

### 変更後レビューと残件

- **Critical**: 今回のテスト変更に指摘なし。
- **Warning（既存実装・静的確認）**: `EditorViewModel.sendSelectedElementToBack` はコピーを直接挿入し、削除だけを履歴に記録します。Undoで元要素を戻してもコピーが残る構造です。`bringSelectedElementToFront` は削除・追加を2イベントで記録します。通常の呼び出し元はCodegraphとソース検索では特定できず、動作再現・仕様判断・修正は未実施です。正しい履歴契約を決める前に現状を固定する期待値は追加していません。
- **Warning（継続）**: 4K SDR の性能超過は未解決。今回のテスト補強では再測定していません。
- **Info**: 製品レイヤーの変更はなく、MVVM／Clean境界、保存・描画・履歴の既存契約は維持。テストはMainActorで選択と履歴を操作し、写真への実書き込みは行いません。
- **Assumptions**: 即時確定は1操作1履歴、同値操作はRedoを破棄しない、複製した参照型効果は元と独立する、という既存契約を検証しました。
- **Test Coverage**: 既存テストの期待値を緩和・削除せず拡張しました。写真保存テストは有効ですが環境依存があったため修正しました。意味を失ったテストは今回の確認対象にはありません。図形パネルの実変更経路、親の共通属性、画像・図形複製、前後移動の履歴は残件です。
- **Verification**: 上記42件、行カバレッジ、差分の空白、文書リンクを確認。テストと文書だけの変更なので全スイート・UI・実機の再実行は行っていません。SwiftFormatは未導入のため実行できませんでした。

結果: `/tmp/glogo-coverage-strengthening-20261101.xcresult`。ログは同名の `.log`、カバレッジJSONは `/tmp/glogo-strengthening-coverage.json`。


## 段階3前の補強・第2回（2026-11-01）

### 調査と最小修正

図形パネルの実変更経路と共通属性の選択境界を補強しました。Codegraph で親・子ViewModel、Editor、UseCase、履歴イベントの経路を確認し、`rg` とソースで照合しました。Serena は利用できませんでした。

| 仮説 | 検証 | 結果／対応 |
| --- | --- | --- |
| 図形パネルからの変更・復元が未検証 | 塗り・線・形状の変更、Undo／Redo、片側だけのグラデーション色変更を検証 | 製品修正なしで成功。既存スイートに4件追加 |
| 親の遅延購読が旧選択を保持する | 初期選択、切り替え、解除、削除直後にRunLoopを進めず共通属性を操作 | 修正前に4件失敗。`ElementViewModel` の `.receive(on: RunLoop.main)` を外して同期反映 |
| 共通属性の更新で履歴や通知が変わる | テキスト・図形・画像で属性と選択を確認し、Redo保持・変更通知を検証 | 既存の履歴を積まない更新を維持。画像参照解除を含め6件の新規スイートで保護 |

選択の通知元 `EditorViewModel` と受信側は `@MainActor` です。受信した値を親の参照・種別へ反映するだけで、その購読からEditorを書き換えません。子ViewModelは従来から同期購読しており、親も同じタイミングに揃えました。選択直後に前の要素へ書き込む不具合を修正したもので、計算式・保存形式・履歴イベントの変更ではありません。

### テスト結果

- 修正前: `/tmp/glogo-selection-before-20261101.xcresult`。15件中11件成功・4件失敗。初期選択、切り替え直後の更新、解除直後の更新、削除直後の更新で問題を再現しました。
- 修正後: `/tmp/glogo-selection-after-20261101.xcresult`。**73件成功、失敗0件・スキップ0件・xcresult実行時警告0件**。単体・統合59件と `EditorPanelUITests` 14件です。
- 新規10件: [ElementViewModelTests](../../GLogoTests/Integration/ElementViewModelTests.swift) 6件、[ShapeEditingViewModelTests](../../GLogoTests/Integration/ShapeEditingViewModelTests.swift) 4件。既存のテスト期待値は変更していません。
- 追加の関連スイート: `ShapeEditUseCaseTests`、`ElementEditIntegrationTests`、`TextEditingViewModelTests`、`AIErrorSurfaceIntegrationTests`、`ImageUpscaleRestrictionIntegrationTests`、`ImageRenderValidityIntegrationTests`、`ImageAdjustmentViewModelTests`、`ViewModelMemoryLeakTests`。
- UIでは文字・フレームのスライダー、調整・エフェクト、フィルター、AIボタン等の既存契約を確認しました。

実行は共通の `xcodebuild -project GLogo.xcodeproj -scheme GLogo -configuration Debug -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18' -enableCodeCoverage YES -parallel-testing-enabled NO` に、上記10個のGLogoTestsスイートと `GLogoUITests/EditorPanelUITests` を `-only-testing:` で指定し、`-resultBundlePath /tmp/glogo-selection-after-20261101.xcresult test` を付けています。

今回の対象実行の行カバレッジは `ShapeEditingViewModel` が70 / 70行（100%）、`ElementViewModel` が122 / 149行（81.9%）です。初回全スイートではそれぞれ71.4%、50.0%でした。対象スイート・コードが異なるため、アプリ全体の41.5%を更新する測定としては扱いません。行の実行だけで全分岐を保証するものでもありません。

### 変更後レビュー

- **Critical**: 修正後の変更に指摘なし。
- **Warning**: 今回の変更に新規指摘なし。既存の前後移動の履歴問題と4K SDR性能超過は未解決です。
- **Info**: 製品変更は親の選択購読1か所と説明コメント。弱参照を維持し、Viewへ判断を移さず、選択状態の同期をViewModel内で修正しています。保存・描画・Codable・Revert・履歴イベントの実装は変更していません。
- **Assumptions**: 選択変更はEditorのMainActor上で発行されます。共通属性の操作は既存どおり履歴を積みません。前後移動の履歴や共通属性のUndo仕様を新たに設計した変更ではありません。
- **Test Coverage**: 既存の図形・履歴・寿命・AI・UIテストは引き続き有効です。失敗した新規テストは期待値を緩和せず、選択反映を修正して成功を確認しました。画像・図形の複製や前後移動の履歴修正は残件です。
- **Verification**: 上記73件、カバレッジ、差分の空白、更新文書のリンクを確認しました。影響範囲を対象に検証したため全スイートと実機の再実行は行っていません。SwiftFormatは未導入で実行不可です。

段階2の補強第2回まで完了。段階3の `ImageElement` の画像取得・描画・キャッシュ分離は未着手です。
