# 非同期加工・描画のキャンセルと保存入力の測定

2026-10-29。段階1の古い結果の抑止に続き、不要な計算を安全な区切りで終了する処理を追加しました。画像の計算式、色空間、品質設定、履歴イベント、保存形式は変更していません。

## 調査と変更方針

Codegraph で高画質化・タイル処理・描画の入口と影響を確認し、`rg` とソースで Task、OperationQueue、選択通知、履歴の経路を照合しました。Serena は利用できませんでした。

| 仮説 | 確認方法・結果 | 変更範囲 |
| --- | --- | --- |
| 結果の失効判定だけでは実計算へ中止が届かない | AI と描画の Task ハンドルが保持されておらず、終了時だけ対象を照合していた | ViewModel／描画 UseCase が Task の寿命を管理 |
| 描画キュー上の待機を省ける | SDR／HDR は同じ構造のキュー・排他ロック・同期計算を持つ | 共通の `ImageRenderOperation` でキュー待機・ロック待機後に取消を照合 |
| 同期推論は区切りで終了できる | Vision、Core ML、Core Image の同期呼び出しとタイルループを確認 | パイプライン開始前、推論後、タイル間に取消チェックを追加 |

Swift のキャンセルは協調的で、`cancel()` 自体が実行中の関数を強制終了するものではありません。この契約に従い、途中の同期演算の終了を待って次工程を省きます。[Swift Task.cancel の公式説明](https://developer.apple.com/documentation/swift/task/cancel%28%29)

## 実装した境界

- [AIToolsViewModel](../../GLogo/ViewModels/AIToolsViewModel.swift) が AI と高画質化の Task をそれぞれ保持します。Editor の選択通知と変更通知から既存の画像トークンを再照合し、失効した要求をキャンセルします。変更前通知では MainActor の現在の更新が終わってから照合します。単なる選択変更では有効な AI 要求を止めません。
- AI 所有者の解放時にも Task をキャンセルします。Task は await をまたいで所有者を強参照しません。処理中フラグはキャンセル要求時に解除せず、処理が復帰するまで維持します。キャンセルはエラー表示・履歴追加・部分結果の適用を行いません。
- [ImageRenderRefreshUseCase](../../GLogo/UseCases/Rendering/ImageRenderRefreshUseCase.swift) は描画 Task を保持し、次の予約・明示的な取消・所有者解放でキャンセルします。FilterPanel の選択通知で画像・履歴の失効も検知します。取消を無視する代替実装に対しても、以前の世代・トークン照合を維持します。
- [ImageRenderOperation](../../GLogo/Infrastructure/Rendering/ImageRenderOperation.swift) は SDR／HDR 共通で Task の取消をロック保護したフラグへ渡します。未実行の計算と、パイプラインのロック待機中に失効した計算を省きます。実行中の描画は完了を待ち、その結果を返しません。従来の同時実行数とパイプラインの排他は維持します。
- Operation 自体は取り消しません。ブロックごと実行されなくなると continuation が未再開になるため、必ずキューから一度だけ復帰する構造です。取消直後の入力メモリ解放は保証せず、キューから取り出されるまで保持する場合があります。
- [BackgroundRemovalUseCase](../../GLogo/Infrastructure/BackgroundRemoval/VisionBackgroundRemover.swift) は Vision 推論、マスク生成、画像変換の境界で確認します。[CoreMLUpscaler](../../GLogo/Infrastructure/Upscaling/CoreMLUpscaler.swift) と [UpscaleTileProcessor](../../GLogo/Infrastructure/Upscaling/UpscaleTileProcessor.swift) は推論前後・タイル間で確認します。Lanczos と高画質化入口も、開始前と結果返却前に確認します。

実行中の Vision `perform`、Core ML `prediction`、Core Image の1回の描画を強制中断する実装ではありません。モデル読み込みや同期演算中に取消された場合も、その呼び出しが戻ってから終了します。画像値の直接変更だけで Editor の通知がない場合は中止の即時伝達を保証しませんが、結果適用時のトークン照合は働きます。写真ライブラリへの保存処理は今回の取消対象にしていません。

## 機能検証と回帰テスト

iPhone 17 Pro／iOS 26.1 Simulator、Debug 構成。関連24スイート・107件成功、失敗・スキップ0件、xcresult の実行時警告0件です。

- [AICancellationIntegrationTests](../../GLogoTests/Integration/AICancellationIntegrationTests.swift) 3件: 背景除去・ぼかし・高画質化への取消伝達、終了前の重複要求抑止、終了後の再実行、取消エラー非表示、選択だけでは取消さないこと、所有者解放。
- [ImageRenderOperationTests](../../GLogoTests/Unit/ImageRenderOperationTests.swift) 4件: キュー上の取消、実行中の同期描画からの復帰と次要求、取消済みパイプライン6経路、4タイル中1タイルの実行後に残り3タイルを省くこと。
- [ImageRenderValidityIntegrationTests](../../GLogoTests/Integration/ImageRenderValidityIntegrationTests.swift) は既存7件の期待値を維持し、Undo・選択解除・手動調整から描画への取消伝達を1件追加しました。
- 既存の AI 結果鮮度、描画順序・寿命、画像調整、フレーム、変形、保存スナップショット、保存出力、Undo／Revert、SDR／HDR の MainActor 応答性、タイルの画素配置、高画質化の同時要求、ViewModel 寿命の各テストは有効です。期待値の緩和や削除はしていません。

結果: `Test-GLogo-2026.10.29_21-14-32-+0900.xcresult`。同じテストを再実行した件数は重複して数えていません。

## 保存入力固定の測定

[SaveSnapshotPerformanceTests](../../GLogoTests/Integration/SaveSnapshotPerformanceTests.swift) は、生成した JPEG の画像要素1個を MainActor 上で `SaveProjectSnapshot` に固定する区間を測ります。4K は 3840×2160、8K は 7680×4320、scale 1／standard range。画像生成、JPEG エンコード、測定準備、結果のアサーションは測定区間外です。

元画像キャッシュあり／なしを分け、XCTest のウォームアップ後の各3回を採用しました。「なし」は要素のキャッシュを解放した状態で、OS のディスクキャッシュを排除する意味ではありません。UIImage の遅延デコード全体やフィルター描画・書き出しまでの時間も含みません。

| 条件 | 平均時間（ms） | 最小〜最大（ms） | テストプロセスの最大物理メモリ（MB） |
| --- | ---: | ---: | ---: |
| 4K・キャッシュあり | 0.0119 | 0.0109〜0.0131 | 42.67 |
| 4K・キャッシュなし | 0.0872 | 0.0738〜0.0969 | 43.55 |
| 8K・キャッシュあり | 0.0090 | 0.0079〜0.0106 | 44.19 |
| 8K・キャッシュなし | 0.0783 | 0.0690〜0.0926 | 44.29 |

これは Mac 上の Simulator の参考値で、iPhone の実機値ではありません。メモリは snapshot の専有量ではなく測定区間のプロセス全体のピークです。極めて短い区間・3標本のため、解像度間の速度順位や変更前後の高速化を示すものではありません。各試行の物理メモリ増分は0〜16.384 kBでしたが、計測粒度・遅延デコード・既存アロケーションを含むため「追加メモリ不要」とは判断しません。

測定コマンド:

```sh
xcodebuild -project GLogo.xcodeproj -scheme GLogo -configuration Debug \
  -destination 'platform=iOS Simulator,id=C5F557FE-C239-408E-BF00-D2A49E76ED18' \
  -parallel-testing-enabled NO \
  -only-testing:GLogoTests/SaveSnapshotPerformanceTests test
```

修正後の測定4件が成功し、失敗・スキップ0件です。結果: `Test-GLogo-2026.10.29_21-17-08-+0900.xcresult`。初回は測定テストの `.manuallyStop` 指定不足で4件とも失敗したため、指定を補って再実行しました。機能テスト107件とは分けて集計しています。

## 変更後レビューと残件（2026-10-29 時点）

- **Critical**: 指摘なし。
- **Warning**: 実機での取消応答時間、Vision／Core ML 実モデルの負荷、保存入力固定時の時間・メモリは未確認です。`xcrun xctrace list devices` では登録済み iPhone がオフラインでした。
- **Info**: 取消を確認する区切りの追加で、不要な後工程を省くことはテストで確認しました。速度・電力・メモリの改善率はまだ測定していません。View に処理判断を追加せず、実計算は既存 UseCase／Service に保っています。
- **Assumptions**: Editor の変更・選択通知は MainActor 上で届きます。注入する AI 実装が取消に反応しなくても、既存の結果照合と処理中ガードで整合性を維持します。
- **Test Coverage**: 部分的に古くなった期待値・意味を失ったテストはありません。実モデルでの取消、写真ライブラリへの実機保存、多数画像、ファイル／アセットからの取得、HDR 実機表示は未検証です。
- **Verification**: 機能107件と測定4件、差分の空白、文書リンクを確認。全スイート・UI 手動操作は未実施です。`swiftformat GLogo/ --lint` は未インストールで実行できませんでした。

上記時点で残していた実機測定は、2026-10-31 に以下の代表条件で実施しました。多画像・高解像度の実推論などへの検証拡張は、今回の測定範囲と区別します。

## 実機測定（2026-10-31）

iPhone 16／iOS 26.6.2（23G90）、Xcode 27.1（27A9275）、Debug 構成で実施しました。初めは端末ロックによる起動待ちでしたが、ユーザーのロック解除後に測定を完了しました。

[DeviceCancellationPerformanceTests](../../GLogoTests/Integration/DeviceCancellationPerformanceTests.swift) に、Vision 背景除去と同梱 Real-ESRGAN の実処理を対象にした2件を追加しました。512×512・scale 1 の生成画像を使い、写真ライブラリや個人画像にはアクセスしません。Vision は要求受付から5ms後、Core ML は50ms後に取消し、取消要求から処理の復帰までの時間・プロセス物理メモリを、ウォームアップ後3回測定します。同期演算内部に到達したことやモデル読み込み完了は保証せず、開始時点・入力条件を限定した測定です。

取消以外の失敗は失敗として報告し、取消より先に正常完了した試行があれば、そのテストをスキップして取消応答の値としては採用しません。取消が成立した後は再実行して画像を生成できることも確認します。Simulator では実機向け2件をスキップします。正常な処理が速いことを回帰不具合として扱わないための判定で、以前の107件の期待値を変更するものではありません。

保存入力4件に加え、実モデルの取消・再実行2件を実行しました。以下はビルド後の実行コマンドです。ソースを変更した場合は先に `build-for-testing` を実行するか、末尾を `test` に変更します。

```sh
xcodebuild -project GLogo.xcodeproj -scheme GLogo -configuration Debug \
  -destination 'platform=iOS,id=<接続した実機ID>' \
  -derivedDataPath /tmp/glogo-device-measurement \
  -parallel-testing-enabled NO \
  -only-testing:GLogoTests/DeviceCancellationPerformanceTests test-without-building
```

今回の変更後レビュー:

- **Critical**: 指摘なし。
- **Warning**: 今回の追加変更に新規指摘なし。以下の代表条件以外の負荷・操作は未検証で、性能の上限保証はしていません。
- **Info**: アプリの処理ロジック・保存形式・履歴は変更していません。追加は測定用テストと進捗文書です。
- **Assumptions**: 実機がロック解除され、接続を維持していること。同梱 Core ML モデルが利用可能であることをテストで確認します。
- **Test Coverage**: 既存の回帰テストは有効で、期待値は維持しています。実モデル・実機の取消応答を追加測定の対象としました。
- **Verification**: 実機向けビルド、保存入力測定4件、実モデルの取消・再実行2件が成功しました。Vision の最初の50ms条件は先に正常完了したため1回スキップし、5ms条件で再測定して成功しました。アプリ実装は変更せず、全スイートは再実行していません。


### 実機で採用した測定値

各条件3標本。ピーク物理メモリは測定区間のテストプロセス全体で、画像・モデルの専有量や GPU／別プロセスの総使用量ではありません。初期化・モデル読み込み・結果生成の全区間を通した最大値でもありません。

| 保存入力固定の条件 | 平均（ms） | 最小〜最大（ms） | プロセス最大物理メモリ（MB） |
| --- | ---: | ---: | ---: |
| 4K・キャッシュあり | 0.0081 | 0.0066〜0.0098 | 42.66 |
| 4K・キャッシュなし | 0.0658 | 0.0604〜0.0737 | 58.30 |
| 8K・キャッシュあり | 0.0065 | 0.0060〜0.0069 | 58.30 |
| 8K・キャッシュなし | 0.0570 | 0.0539〜0.0614 | 58.30 |

入力・測定区間は Simulator の表と同じです。保存受付の入力固定のみを測定し、JPEG の全画素デコード、フィルター描画、写真ライブラリ書き込みは含みません。非常に短い区間なので、4K／8K や Simulator／実機の速度順位を評価する用途には使いません。

| 実モデル・取消条件 | 取消要求から復帰の平均（ms） | 最小〜最大（ms） | プロセス最大物理メモリ（MB） | 取消後の再実行 |
| --- | ---: | ---: | ---: | --- |
| Vision 背景除去・受付5ms後に取消 | 8.929 | 7.504〜11.571 | 76.43 | 画像生成成功 |
| Real-ESRGAN・受付50ms後に取消 | 274.154 | 269.122〜280.056 | 65.44 | 画像生成成功 |

Vision の初回50ms条件では正常完了が先行し、取消の試行が成立しませんでした。その測定値は採用せず、テストの取消要求時点を5msに変更して Vision のみ再実行しました。これはアプリのキャンセル条件や画像処理の変更ではありません。Core ML の50ms条件は維持しています。異なる要求時点・処理方式の比較なので、両者の平均値を処理速度の比較には使いません。

結果ファイル:

- 保存入力4件: `Test-GLogo-2026.10.31_14-26-49-+0900.xcresult`（成功4、失敗0、スキップ0）。
- 実モデル初回: `Test-GLogo-2026.10.31_14-31-23-+0900.xcresult`（Core ML成功1、Visionスキップ1、失敗0）。
- Vision 再測定: `Test-GLogo-2026.10.31_14-31-59-+0900.xcresult`（成功1、失敗0、スキップ0）。

これにより、段階1の主要対策と代表条件の実機検証まで完了しました。未検証範囲は、複数画像、4K／8K の実モデル推論、ファイル／写真アセット読み込み、HDR の実機表示、写真ライブラリへの実保存、熱状態や低メモリ条件での長時間操作です。現在の測定をそれらへ一般化しません。


同じ実機で `AICancellationIntegrationTests` 3件と `ImageRenderOperationTests` 4件も成功しました（失敗・スキップ0件）。前者は代替処理を使って Editor の変更通知からの取消・終了前の重複要求抑止・再実行・所有者解放を確認し、実モデルの測定2件とは役割を分けています。結果: `Test-GLogo-2026.10.31_14-32-55-+0900.xcresult`。今回の実機検証は、測定6件と機能7件の計13件が成功しました。初回 Vision の不成立条件でのスキップ1件は別途上記に記録しています。
