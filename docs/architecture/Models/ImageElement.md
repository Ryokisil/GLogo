# ImageElementのデータと技術処理の境界

この文書は、画像要素Modelが担うデータ・描画・キャッシュ・永続化の境界を記録します。調査日: 2026-10-18。2026-10-28 に保存専用の描画コピーを追加し、2026-10-29 に AI 完了結果の照合に使う世代番号を記録しました。2026-11-01 に段階3の第1回として、画像取得Resolverを共有可変依存から要素ごとの依存へ変更しました。同日の第2回で初期化時の読み込み・メタデータ抽出とサイズ計算を分離しました。同日の第3回で要素別キャッシュの保持・無効化ルールを分離しました。2026-11-03の第4回で描画サービスの全体差し替えを廃止し、生成時の依存へ変更しました。同日の第5回でフィルターパラメータの合成規則をModel外へ一本化し、第7回で初期化の入口をUseCasesのFactoryへ移しました。キャッシュ保持と描画要求の組み立てを担当するModelの責務は残っています。

- 対象: [ImageElement.swift](../../../GLogo/Models/ImageElement.swift)
- 全体方針: [比較と責務分離方針](../README.md)

## 確認した現状

`ImageElement`は`LogoElement`を継承する可変な参照型です。画像参照、編集パラメータ、メタデータ、初期調整スナップショット、キャッシュを保持し、Codable、コピー、復元、画像取得、フィルター呼び出し、描画呼び出しを持ちます。

| 入口 | 確認した処理 |
| --- | --- |
| コンストラクター | 読み込み済みの値（ソース・配置サイズ・キャンバス）を受け取るだけでI/Oを行わない。画像データからの生成は `ImageElementFactory` が寸法の読み取りと配置サイズの計算を担当 |
| `originalImage` | Resolverで元画像を取得し、要素が保持する `ImageRenderCache` へキャッシュ |
| `image` | 編集状態に応じてプレビューまたは高品質処理を呼び、必要に応じてキャッシュ更新 |
| `renderFullQualityImageAsync()` | 非同期の高品質フィルター処理を呼び出す |
| `renderCopy()` | 保存用に描画属性をコピーし、要求時の元画像を保持。編集用キャッシュや外部ファイル参照は持ち越さない |
| `draw(in:)` | 表示する画像を解決して`ImageElementRenderer`へ描画を委譲 |
| `sourceResolver` | 要素の生成時・デコード時に固定する実行時依存。コピーも取得先を引き継ぐ |
| `previewService` | 生成・デコード時に固定するSendableな参照。既定は差し替え不能な共有サービス。コピーとサムネイルも同じ依存を使用 |
| `renderCache` | 要素ごとの値型。描画結果・元画像・プロキシ・プレビュー元画像と、操作別の無効化を管理 |

## 実行時の編集世代

`editRevision` は画像ソース、調整、フィルター、マスク、枠属性の書き込みで増加します。同値の代入も失効境界とし、画像 Data の比較やハッシュ計算は行いません。配置・選択・キャッシュ更新は含めません。属性を追加するときは、この対象と [ImageEditTokenTests](../../../GLogoTests/Unit/ImageEditTokenTests.swift) の検証範囲も確認します。

世代は永続化も履歴復元もしません。Undo で画像値が戻っても、以前の非同期要求を有効に戻さないためです。コピーへ元の番号を引き継がず、対象インスタンスの同一性と組み合わせて使います。この番号はスレッド同期の仕組みではなく、編集側の照合・適用は MainActor 上で行います。

## 評価

保存側の入力固定と検証結果は [SaveImageCoordinator](../UseCases/SaveImage/SaveImageCoordinator.md) に記録しています。UI 用の `copy()` は新しい ID を作る従来の契約を維持し、画像属性のコピー処理だけを共通化しました。保存用コピーは画像資源をメモリ上で保持するため、永続化用として使いません。

### Warning

取得プロパティに処理負荷やキャッシュ更新が含まれるため、呼び出し側からコストと副作用を把握しにくい構造です。Modelが描画・取得の具体的な仕組みにも関わるため、純粋な編集データだけを扱うテストやバックグラウンドへの受け渡しが難しくなります。

画像取得Resolverと描画サービスのstatic差し替えは廃止しました。既定のRepositoryと描画サービス自体は共有します。描画サービスにはSendable契約を設けましたが、可変なImageElement全体の並行利用を安全にする変更ではありません。

### Info

ResolverとRendererへの抽出はすでに進んでいます。さらに分離する場合も既存実装を再利用します。`Payment`の残額計算のようなデータ固有の振る舞いと、画像I/O・描画・キャッシュ調整の責務を区別します。Apple画像型への依存をすべて除去すること自体を目的にしません。

## 責務の配置案

| 責務 | 方針 |
| --- | --- |
| 画像ソースの識別、編集値、初期状態 | Modelに保持。値のスナップショット化を検討 |
| 初期化時の読み込み・配置サイズの決定 | [ImageElementFactory](../../../GLogo/UseCases/Import/ImageElementFactory.swift)が境界 `ImageInitializationLoading` 経由で担当。`copy()` のURL読み直しと `replaceImageSource` の寸法取得は、Modelから [ImageInitializationLoader](../../../GLogo/Infrastructure/Import/ImageInitializationLoader.swift) を直接呼ぶ |
| 配置サイズの計算 | [ImageSizeCalculator](../../../GLogo/Models/ImageSizeCalculator.swift)で純粋な計算として共有 |
| 画像ソースの優先順位と取得 | [ImageSourceResolver](../../../GLogo/UseCases/Storage/ImageSourceResolver.swift)とRepositoryを利用 |
| フィルター、SDR／HDR経路、プレビュー | [ImagePreviewService](../../../GLogo/Infrastructure/Rendering/ImagePreviewService.swift)等を利用 |
| 画像要素の描画 | [ImageElementRenderer](../../../GLogo/Infrastructure/Rendering/ImageElementRenderer.swift)を維持 |
| キャッシュの保存場所・無効化・寿命 | [ImageRenderCache](../../../GLogo/UseCases/Rendering/ImageRenderCache.swift)に要素別の保持・無効化ルールを分離済み。保持元のModelと共有サービス側キャッシュの境界は引き続き整理 |
| Codableと旧形式復元 | 当面の保存互換性を維持し、データの移動とは別に扱う |

新しいViewModelへ画像取得・キャッシュ処理をそのまま移すと、別の場所に責務集中を作ります。画面状態と画像処理を分けて配置します。

## 横断するリスク

- プレビューと保存では、入力解像度・品質・色空間・描画範囲を確認します。共通Rendererがあることだけで一致を保証しません。
- Undo／Redo、画像差し替え、Revert、メモリ警告から、適切なキャッシュを無効化する必要があります。
- 属性を移す場合はCodable、コピー、初期スナップショット、メタデータ復元を一緒に確認します。
- バックグラウンドへ渡す入力を固定する場合、編集値だけでなく元画像の解決結果と寿命も確認します。
- 高解像度画像を無条件に複製するとメモリを圧迫します。必要な値と画像資源の保持方法を分けて設計します。

## 既存テストと追加候補（初回調査時点）

- [ImageSourceResolverTests](../../../GLogoTests/Unit/ImageSourceResolverTests.swift): 画像ソースの解決経路。
- [ImageAssetRepositoryRoutingTests](../../../GLogoTests/Unit/ImageAssetRepositoryRoutingTests.swift): 編集用画像の選択経路。
- [PreviewCacheRegressionTests](../../../GLogoTests/Regression/PreviewCacheRegressionTests.swift): キャッシュの回帰確認先。
- [ImageUndoCacheInvalidationTests](../../../GLogoTests/Unit/ImageUndoCacheInvalidationTests.swift): 履歴適用・取り消し時のキャッシュ無効化。
- [RevertSnapshotRegressionTests](../../../GLogoTests/Regression/RevertSnapshotRegressionTests.swift): 初期状態への復元とスナップショットの保持。
- [LogoProjectPolymorphicCodingRegressionTests](../../../GLogoTests/Regression/LogoProjectPolymorphicCodingRegressionTests.swift): 要素型と旧形式の復元。
- [ImagePreviewAsyncResponsivenessRegressionTests](../../../GLogoTests/Regression/ImagePreviewAsyncResponsivenessRegressionTests.swift): 非同期SDR／HDR処理中のメインキュー応答性。

追加候補は、セッションごとに異なる依存を同時利用した場合の独立性、画像差し替え後の古い描画結果の破棄、保存用入力の固定です。今回の記録ではテストを実行していません。


## 段階3・第1回：画像取得依存の分離（2026-11-01）

### 処理経路と方針

Codegraphの結果には旧ファイル名が含まれていたため、現行の `ImageSourceResolver.swift`、Model、インポートBuilder、保存コピー、履歴復元、テストを `rg` とソースで照合しました。Serenaは利用できませんでした。

| 仮説 | 確認・対応 |
| --- | --- |
| staticなResolver差し替えが別要素の取得先にも影響する | 参照はModelの元画像・プロキシ・ソース復元とテスト2か所。要素ごとの不変な依存に変更し、2要素の取得・キャッシュを交互に検証 |
| コピーやデコード時に依存が既定値へ戻る | 全生成入口、`copy()`、`renderCopy()`、Decoderと子Decoderを確認。生成引数と `Decoder.userInfo` で引き継ぎを明示 |
| 取得先変更が保存・復元・キャッシュを変える | 保存画像固定、元画像とプロキシのキャッシュ、メモリ警告・Revert・ソース復元、旧形式、描画競合の既存テストと追加テストで確認 |

### 変更した境界

- `ImageElement` は `sourceResolver` を生成時に固定します。既定は従来と同じ `ImageSourceResolver`。元画像、編集用プロキシ、ソース復元がこの取得先を使います。
- `ImageImportElementBuilder` からもResolverを注入できます。前段で作ったImporterの注入経路を通して、同じ編集セッションの生成画像へ取得先を渡せます。
- `copy()` は新しいIDと独立したModel内キャッシュを保ち、取得先を引き継ぎます。`renderCopy()` は従来どおり受付時のUIImageを保持し、通常の保存描画で再解決しません。
- `JSONDecoder.userInfo[.imageSourceResolver]` から、プロジェクト内の画像要素へ取得先を渡せます。未指定時は標準Resolverです。キーはデコーダー用の実行時設定で、保存JSONのキー追加ではありません。
- 共有依存ストアからResolverだけを除去しました。プレビューサービスのロック・共有方式は維持しています。

今回の変更は取得先の束縛範囲を変えるものです。ファイルパス→URL→アセット名→Dataの優先順位、非ファイルURLの扱い、nil時のフォールバック、キャッシュを消すタイミングは維持します。Codableの保存フィールドも変更していません。

### 検証とレビュー

新規 [ImageSourceIsolationTests](../../../GLogoTests/Unit/ImageSourceIsolationTests.swift) 7件で、独立した取得・プロキシキャッシュ、全初期化入口とコピー、ソース復元・Revertの再取得、保存コピーの画像固定、2つのデコーダーと保存形式、インポートからの注入を検証しました。既存のResolverキャッシュと保存画像の向き・色空間テストは、期待値を維持してstatic差し替えをインスタンス注入に置き換えました。

- **Critical**: 指摘なし。
- **Warning**: 今回の変更に新規指摘なし。プレビューサービスのstatic依存と標準Repositoryの共有、初期化時の直接画像読み込み、Model内キャッシュ所有は未解消です。要素の依存を分けても、注入したResolverや可変Model自体のスレッド安全性を保証するものではありません。
- **Info**: UIへ取得ルールを移さず、既存Resolver／Repositoryを再利用しました。保存・描画式・履歴イベント・メタデータ形式に変更はありません。
- **Assumptions**: Resolverの寿命は要素が保持します。状態を持つ独自Resolverを複数の実行コンテキストへ渡す場合の排他は、その実装が担当します。既定Resolverは従来と同じ共有Repositoryを利用します。
- **Test Coverage**: Resolver・Repository、保存入力固定・保存出力、Undo・Revert・旧形式・破損入力、インポート、プレビューキャッシュ、AI／描画の古い結果抑止を検証しました。既存テストの期待値は緩和していません。
- **Verification**: 関連16スイート・**79件成功、失敗0件・スキップ0件・xcresult実行時警告0件**。差分の空白・文書リンクも確認しました。全スイート・UI・実機・性能再計測は未実施です。取得先の変更を対象テストで検証し、速度改善は主張しません。SwiftFormatは未導入のため実行不可です。

実行: iPhone 17 Pro／iOS 26.1 Simulator、Debug、`-enableCodeCoverage YES -parallel-testing-enabled NO`。
対象: `ImageSourceIsolationTests`、`ImageSourceResolverTests`、`ImageAssetRepositoryRoutingTests`、`SaveProjectSnapshotTests`、`SaveSnapshotIntegrationTests`、`SavePipelineRegressionTests`、`ImageUndoCacheInvalidationTests`、`RevertSnapshotRegressionTests`、`LogoProjectPolymorphicCodingRegressionTests`、`ImageElementCorruptedDataTests`、`ImageElementMetadataRevertUseCaseRegressionTests`、`EditorImageImportIntegrationTests`、`ImageImportCoordinatorTests`、`PreviewCacheRegressionTests`、`AIResultValidityIntegrationTests`、`ImageRenderValidityIntegrationTests`。
結果: `/tmp/glogo-stage3-source-20261101.xcresult`。ログ: `/tmp/glogo-stage3-source-20261101.log`。

### 第1回終了時の次の範囲

段階3は進行中です。次はコンストラクターに残る画像読み込み・サイズ決定・メタデータ抽出の境界を整理します。注入したResolverは今回、元画像・編集用画像・復元時の取得に適用しており、初期化時の直接読み込みすべてを置換したものではありません。その後、描画サービスとキャッシュの所有・無効化・寿命を段階的に分離します。


## 段階3・第2回：初期化の読み込みとサイズ計算の分離（2026-11-01）

### 計画と処理経路

CodegraphでModelとインポートBuilderの入口を確認し、ソースで全初期化入口、`copy()`、画像差し替え、履歴復元、メタデータの橋渡し拡張を照合しました。Serenaは利用できませんでした。

| 仮説 | 検証と対応 |
| --- | --- |
| 入力形式を一括してResolverへ置き換えると既存の抽出条件が変わる | Data・URL・パス・アセット名の各初期化を比較。URLはData保持とデコード非依存の抽出が必要なため、初期化専用Loaderへ既存分岐を移動 |
| サイズ計算が初期化以外の履歴・加工にも影響する | 差し替え・復元の呼び出しを確認。キャンバス短辺の15%、アスペクト比、各辺の最小1、固定サイズ指定を変更前のテストで固定 |
| Model経由のメタデータ抽出を外すと復元や保存に影響する | 抽出器は既存Managerを継続利用。編集履歴の記録・Revert・Codableの処理を変えず、保存と復元の既存テストを実行 |

### 変更した境界

- UseCaseの [ImageInitializationLoader](../../../GLogo/Infrastructure/Import/ImageInitializationLoader.swift) に、初期化用の画像読み込みとメタデータ抽出条件を集約しました。返すのは寸法・入力Data・メタデータで、デコードしたUIImageは保持しません。
- Modelの [ImageSizeCalculator](../../../GLogo/Models/ImageSizeCalculator.swift) に、I/Oに依存しないサイズ計算を移しました。初期化・差し替え・復元で同じ計算を使用します。
- `ImageElement` はソース・サイズ・メタデータの代入を担当します。直接の `UIImage(data:)`、`UIImage(named:)`、`UIImage(contentsOfFile:)`、`Data(contentsOf:)` を除去しました。
- 呼び出しがなくなった `ImageElement.extractMetadataFromImageData` の橋渡しを削除しました。メタデータ編集と履歴記録の拡張は維持しています。

URLの同期読み込みは維持しています。URLが読めれば破損データも保持し、画像デコード失敗時にもメタデータ抽出を試します。Data＋metadata初期化は指定値を優先し、未指定かつデコード成功時だけ抽出します。Dataのみ・キャンバス指定・固定サイズ指定・パス・アセット名の入口では抽出しません。表示時の元画像Resolverは引き続き非ファイルURLを解決しません。

保存キー、世代番号を進める代入、初期調整スナップショット、キャッシュを消すタイミングは変えていません。初期化で取得したUIImageを元画像キャッシュへ先取りする変更もありません。`ImageElement.swift` は今回 **1,535 → 1,495行** です。

### テストと回帰テスト棚卸し

新規 [ImageElementInitializationTests](../../../GLogoTests/Unit/ImageElementInitializationTests.swift) 7件を変更前に実行しました。当初、破損URLのメタデータをnilと想定した新規テストが失敗し、現行抽出器が空のメタデータを返すことを確認しました。既存動作に合わせた期待値で、分離前・分離後とも7件成功しています。既存テストの期待値は変更していません。

- 新規: 縦横・正方形・細長い画像、最小寸法、固定サイズ、指定キャンバス、差し替えと復元、指定メタデータ優先、入口別の抽出条件、ファイル参照とURLのData保持、URLコピー、破損・存在しないファイル。
- 引き続き有効: Resolverの取得優先順位・独立性、Undoのキャッシュ無効化、Revertとメタデータ復元、旧形式と多態Codable、保存画像の向き・配置・非破壊性、クロップ、インポート、古いAI／描画結果の破棄。今回の責務移動によって保護対象を失った回帰テストはありません。
- 未検証: 実ネットワーク経由のURL読み込み、実機・UI・性能の再測定。既存の同期URL読み込みはソース比較で保持を確認し、通信成功は主張しません。

### 変更後レビュー

- **Critical**: 指摘なし。
- **Warning**: 今回の変更に新規指摘なし。Modelが具体的な初期化UseCaseを生成する依存と、共有MetadataManager／Repository／プレビューサービス、Model内キャッシュ所有は残ります。全Modelの技術依存を除去した段階ではありません。既存テストにはSendable・MainActor・弱参照宣言などのビルド警告があり、今回変更したSwiftファイルからの警告はありません。
- **Info**: I/Oとメタデータ抽出はUseCaseへ、純粋な計算はModelへ配置しました。View／ViewModelへ責務を移していません。再圧縮・追加キャッシュ・非同期化・新しい保存属性は導入していません。
- **Assumptions**: 初期化の公開入口と同期動作を保ち、初期化用Loaderは状態を持たない具体型として利用します。既存のメタデータ抽出器の抽出精度を改善する変更は含みません。
- **Test Coverage**: 関連19スイート・**90件成功、失敗0件・スキップ0件・実行時警告0件**。追加Loaderの行カバレッジは25/25、サイズ計算は12/12です。これは対象テストでの行実行率であり、全分岐やアプリ全体の十分性を保証しません。
- **Verification**: iPhone 17 Pro／iOS 26.1 Simulator、Debug、`-enableCodeCoverage YES -parallel-testing-enabled NO` で実行。`git diff --check`、変更前ソースとの差分、削除した抽出メソッドの参照なしを確認。SwiftFormatは未導入のため実行不可。全スイート・UI・実機は今回未実施です。

対象: `ImageElementInitializationTests`、`ImageSourceIsolationTests`、`ImageSourceResolverTests`、`ImageAssetRepositoryRoutingTests`、`SaveProjectSnapshotTests`、`SaveSnapshotIntegrationTests`、`SavePipelineRegressionTests`、`ImageUndoCacheInvalidationTests`、`RevertSnapshotRegressionTests`、`LogoProjectPolymorphicCodingRegressionTests`、`ImageElementCorruptedDataTests`、`ImageElementMetadataRevertUseCaseRegressionTests`、`EditorImageImportIntegrationTests`、`ImageImportCoordinatorTests`、`PreviewCacheRegressionTests`、`AIResultValidityIntegrationTests`、`ImageRenderValidityIntegrationTests`、`ImageCropTests`、`RevertUndoSequenceIntegrationTests`。
結果: `/tmp/glogo-stage3-init-after-20261101.xcresult`。ログ: `/tmp/glogo-stage3-init-after-20261101.log`。変更前の成功結果: `/tmp/glogo-stage3-init-baseline-20261101.xcresult`。

### 第2回終了時の次の範囲

段階3の第2回まで完了しました。次は描画サービスとキャッシュの所有・無効化・寿命を整理します。初期化の公開入口をModel外のFactoryへ移すかどうかも、呼び出し互換性と生成時依存の境界として残ります。共有サービスを利用するModel全体がスレッド安全になったとは扱いません。


## 段階3・第3回：要素別キャッシュの保持と無効化の分離（2026-11-01）

### 計画と影響範囲

Codegraphで描画・非同期プレビュー・関連回帰テストを確認し、`rg`と現行ソースでModel内の4種類のキャッシュ、Editorのメモリ警告、FilterPreviewUseCase、描画完了、コピー、保存スナップショット、Undo／Revertを照合しました。Serenaは利用できませんでした。

| 仮説 | 検証と最小変更 |
| --- | --- |
| 各所のnil代入を一律の全消去に変えると、必要な再利用まで失われる | 公開操作から再取得・生成回数を観測する8件を変更前に追加し、全件成功を確認。4つの無効化範囲をそのまま移動 |
| キャッシュをまとめる際に、コピー間の共有や画像資源の保持が変わる | 値型 `ImageRenderCache` を要素ごとに新規生成。通常コピー・保存コピーの独立性と、弱参照によるUIImageの解放を検証 |
| `cachedImage` の保持先変更が履歴・非同期反映・永続化に波及する | 読み書き可能な既存プロパティを維持。世代判定、保存キー、イベント処理を変更せず、関連テストで確認 |

今回の実装対象はModelと [ImageRenderCache](../../../GLogo/UseCases/Rendering/ImageRenderCache.swift) です。キャッシュの実装はRendering側に配置し、Modelは従来の入口から委譲します。描画サービスのDI変更や全処理の移動を同時に行っていません。

### 維持した無効化ルール

| 操作 | 描画結果 | 元画像 | プロキシ | プレビュー元画像 | 共有サービスのリセット |
| --- | --- | --- | --- | --- | --- |
| 描画無効化・編集開始・編集記録 | 消去 | 保持 | 保持 | 保持 | なし |
| `resetToOriginal()` | 消去 | 保持 | 保持 | 消去 | なし |
| `clearRevertImageCaches()` | 消去 | 消去 | 保持 | 保持 | なし |
| 画像ソース差し替え・復元 | 消去 | 消去 | 消去 | 消去 | あり |
| 要素のメモリ警告 | 消去 | 消去 | 消去 | 消去 | 要素では行わず、Editorが従来どおり担当 |

`resetAdjustmentsToInitialState()` は調整リセットとRevert用消去を順に呼ぶため、描画結果・元画像・プレビュー元画像を消し、プロキシを保持します。生成失敗のnilを負のキャッシュとして固定する変更はありません。

通常の `copy()` とDecoderは空のキャッシュで始まります。`renderCopy()` は独立した保持領域へ受付時の元画像だけを固定します。UIImageの再圧縮・複製は追加していません。`cachedImage` は互換プロパティとして保持領域へ読み書きを委譲し、世代番号を進めたり保存内容を変えたりしません。`ImageElement.swift` は **1,495 → 1,484行** です。

### テストと変更後レビュー

- **Critical**: 指摘なし。
- **Warning**: 今回の変更に新規指摘なし。キャッシュの保持元はModelのままで、共有プレビューサービス・Repositoryの依存も残ります。値型の採用はModel自体やUIImageの並行利用を安全にするものではありません。既存テスト由来のビルド警告は残っていますが、今回変更したSwiftファイルからの警告はありません。
- **Info**: 画像の取得順、フィルター計算、SDR／HDR選択、非同期結果の採用条件、履歴と保存形式は維持しました。無効化ルールと画像資源の保持を一か所で確認できるようにしています。
- **Assumptions**: 描画サービスの共有方式と既存の実行コンテキストを維持します。共有サービスを差し替える新規テストは必ず復元し、今回の実行は並列化を無効にしています。
- **Test Coverage**: 新規 [ImageElementCacheTests](../../../GLogoTests/Unit/ImageElementCacheTests.swift) 8件を分離前後で実行。新規 [ImageRenderCacheTests](../../../GLogoTests/Unit/ImageRenderCacheTests.swift) 1件で部分消去・全消去によるUIImageの解放を確認。関連21スイート・**104件成功、失敗0件・スキップ0件・実行時警告0件**。新しいキャッシュ型の行実行率は17/17ですが、これをアプリ全体の十分なカバレッジとは扱いません。
- **Verification**: iPhone 17 Pro／iOS 26.1 Simulator、Debug、`-enableCodeCoverage YES -parallel-testing-enabled NO`。変更前ソースとの差分と `git diff --check` を確認。全スイート・UI・実機・性能再測定は今回未実施です。SwiftFormatは未導入のため実行できません。

回帰テスト棚卸しでは、既存の元画像・プロキシ独立性、Undoキャッシュ無効化、Revert、保存入力固定・保存出力、旧形式・多態Codable、異なる画像のプレビュー、古い非同期結果の破棄は引き続き有効です。既存テストの期待値は変更していません。不足していた操作ごとの保持範囲と実際の画像解放を新規テストで補いました。

対象: `ImageElementCacheTests`、`ImageRenderCacheTests`、`ImageSourceIsolationTests`、`ImageSourceResolverTests`、`SaveProjectSnapshotTests`、`SaveSnapshotIntegrationTests`、`SavePipelineRegressionTests`、`ImageUndoCacheInvalidationTests`、`RevertSnapshotRegressionTests`、`RevertUndoSequenceIntegrationTests`、`LogoProjectPolymorphicCodingRegressionTests`、`ImageElementCorruptedDataTests`、`ImageElementMetadataRevertUseCaseRegressionTests`、`PreviewCacheRegressionTests`、`AIResultValidityIntegrationTests`、`ImageRenderValidityIntegrationTests`、`ImageRenderRefreshUseCaseTests`、`FilterAdjustSeparationTests`、`ImageAdjustmentViewModelTests`、`ImagePreviewAsyncResponsivenessRegressionTests`、`SaturationBoundaryIntegrationTests`。
結果: `/tmp/glogo-stage3-cache-after-20261101.xcresult`。ログ: `/tmp/glogo-stage3-cache-after-20261101.log`。変更前: `/tmp/glogo-stage3-cache-before-20261101.xcresult`。

### 第3回終了時の次の範囲

段階3の第3回まで完了しました。次は描画サービスの共有依存と描画呼び出し境界を整理します。要素・フィルターサムネイル・Editorのメモリ警告から同じ共有サービスを使っているため、サービスの生成数やキャッシュ寿命を増やさない方針を先に確認します。キャッシュを保持するModelの責務と、初期化Factory・履歴周辺の境界も残件です。


## 段階3・第4回：描画依存の固定と呼び出し境界（2026-11-03）

### 計画と確認した経路

Codegraphと現行ソースで、Modelの同期／非同期描画、FilterPanelViewModel→FilterPreviewUseCase、Editorのメモリ警告、インポートBuilder、通常コピー／保存コピー、子Decoderへの依存引き継ぎを確認しました。Serenaは利用できませんでした。

| 仮説 | 確認・対応 |
| --- | --- |
| Modelのstatic差し替えが全要素の描画先を変える | 本体・サムネイル・メモリ警告・テストの参照を照合。要素の生成時に不変の依存を束縛し、既存のテスト差し替えをインスタンス注入へ変更 |
| 要素ごとのサービス新規生成がパイプラインとキャッシュを増やす | 既定は `ImagePreviewService.shared` 1個を維持。複数要素・通常デコードで同じ参照を使うことを検証 |
| コピー・サムネイル・メモリ警告で別のサービスへ戻る | 全生成入口・コピー・子Decoder・インポートへ依存を引き継ぎ、選択画像と同じ描画先をサムネイルへ渡す。使用中のサービスを同一性で重複排除して解放 |

### 変更した境界

- `ImageElement.previewService` はインスタンスの `let` になりました。全7種類の初期化入口から注入でき、`copy()` と `renderCopy()` も同じ依存を保持します。Model内の共有可変依存ストアは削除しました。
- [ImagePreviewService](../../../GLogo/Infrastructure/Rendering/ImagePreviewService.swift) は不変の `static let shared` を既定値として提供します。`ImagePreviewing` は参照同一性と非同期共有のために `AnyObject & Sendable` を要求します。ファサードの依存は不変のSendable参照で、ファサードへの新しい `@unchecked Sendable` は不要です。
- 既存のSDR／HDR実装は従来の `@unchecked Sendable` と、非同期パイプライン・PreviewCacheのロックを維持します。パイプラインの計算式・実行キュー・並列数は変えていません。テスト用サービスの可変観測値と応答キューはロックで保護しました。
- `Decoder.userInfo[.imagePreviewService]` で子Decoderへ依存を渡せます。未指定時は共有サービスです。保存キー追加ではなく、同じプロジェクトを異なる依存で復元しても再エンコード結果は一致します。
- [ImageImportElementBuilder](../../../GLogo/UseCases/Import/ImageImportElementBuilder.swift) が描画依存を受け取り、キャンバス指定の有無にかかわらず生成要素へ渡します。
- [FilterPreviewUseCase](../../../GLogo/UseCases/Editing/Image/Filters/FilterPreviewUseCase.swift) は描画依存を引数で受け取り、Modelのstaticプロパティに依存しません。FilterPanelViewModelは選択画像の依存を渡します。
- [ImageCacheReleaseUseCase](../../../GLogo/UseCases/Rendering/ImageCacheReleaseUseCase.swift) は要素別キャッシュを消した後、既定サービスと要素が利用するサービスをそれぞれ一度だけリセットします。画像がない場合も既定サービスを解放します。Editorの通知経路とToneCurveFilterの解放は維持しています。

既定経路のサービス数・取得順・画質指定・SDR／HDR選択・フィルター計算・保存形式・履歴イベント・要素別キャッシュ無効化範囲は維持します。注入したサービスがある場合は、そのサービスへ描画とソース変更時のリセットを限定し、Editorのメモリ警告でも解放対象に含めます。これが今回明示的に変えた依存の適用範囲です。

### 検証と変更後レビュー

- **Critical**: 指摘なし。
- **Warning**: 今回の変更に新規指摘なし。既定サービス・Repositoryは共有し、描画要求の組み立てとキャッシュ保持はModelに残ります。ImageElementをSendableにしたわけではありません。既存テストのビルド警告は残っています。
- **Info**: Modelの全体差し替え口を除去し、UseCaseとViewModelは明示された描画依存へ接続しました。描画サービスのSwift 6並行処理契約を明示し、既存のチェック省略ストアは不要になりました。
- **Assumptions**: 独自の描画サービスもSendable契約に従い、内部の可変状態を同期します。Modelの編集は既存のMainActor経路、保存側は固定済みコピーの所有ルールを継続します。
- **Test Coverage**: 新規 [ImagePreviewDependencyTests](../../../GLogoTests/Integration/ImagePreviewDependencyTests.swift) 9件で、既定共有、同期・非同期の依存独立性、全初期化入口とコピー、子Decoderと保存形式、インポート、選択変更後のサムネイル、サービス解放の重複排除、Editorのメモリ警告通知を検証しました。
- **Verification**: 関連25スイート・**126件成功、失敗0件・スキップ0件・実行時警告0件**。iPhone 17 Pro／iOS 26.1 Simulator、Debug、`-enableCodeCoverage YES -parallel-testing-enabled NO`。ImagePreviewServiceは77/77行、ImageCacheReleaseUseCaseは16/16行を実行しました。行実行率はアプリ全体の十分性を保証しません。

初回ビルドではMainActorから非同期サムネイルへ非Sendableなサービスを渡す箇所で失敗しました。サービス契約とテスト用実装を修正して再実行し、上記の結果を確認しています。`ImageElement.swift` は **1,484 → 1,466行**、`EditorViewModel.swift` は **824 → 821行** です。

変更後レビューでは保存画像の固定・出力、キャッシュ無効化、Undo／Revert、旧形式・多態Codable、非同期の古い結果抑止、SDR／HDRの応答性を確認しました。回帰テスト棚卸しでは既存の期待値を維持し、共有依存の差し替えだけを注入へ変更しました。描画先とライフサイクルの引き継ぎを新規テストで補っています。

`git diff --check`、変更前ソースとの比較、`ImageElement.previewService` のstatic参照が残っていないことを確認しました。全スイート・UI・実機・性能再測定は未実施です。SwiftFormatは未導入のため実行できません。

対象: `ImagePreviewDependencyTests`、`ImageElementCacheTests`、`ImageRenderCacheTests`、`ImageSourceIsolationTests`、`ImageSourceResolverTests`、`SaveProjectSnapshotTests`、`SaveSnapshotIntegrationTests`、`SavePipelineRegressionTests`、`ImageUndoCacheInvalidationTests`、`RevertSnapshotRegressionTests`、`RevertUndoSequenceIntegrationTests`、`LogoProjectPolymorphicCodingRegressionTests`、`ImageElementCorruptedDataTests`、`ImageElementMetadataRevertUseCaseRegressionTests`、`PreviewCacheRegressionTests`、`AIResultValidityIntegrationTests`、`ImageRenderValidityIntegrationTests`、`ImageRenderRefreshUseCaseTests`、`FilterAdjustSeparationTests`、`ImageAdjustmentViewModelTests`、`ImagePreviewAsyncResponsivenessRegressionTests`、`SaturationBoundaryIntegrationTests`、`EditorImageImportIntegrationTests`、`ImageImportCoordinatorTests`、`ImageElementInitializationTests`。
結果: `/tmp/glogo-stage3-preview-checked-20261103.xcresult`。ログ: `/tmp/glogo-stage3-preview-checked-20261103.log`。

### 次の範囲

段階3の第4回まで完了しました。次はフィルターパラメータ合成と描画要求の組み立てをModelから分離します。キャッシュ保持元、初期化Factory、履歴周辺の境界整理は引き続き残件です。


## 段階3・第5回：フィルターパラメータ合成の一本化（2026-11-03）

### 計画と確認した経路

Serenaの参照検索で `ImageFilterParams` の生成元を確認し、合成処理は `ImageElement.currentFilterParams()` と `FilterPreviewUseCase.makePreviewParams` の2か所だけと特定しました。サムネイルの呼び出し元は `FilterPanelViewModel` だけで、SDR／HDRのフィルターパネルはそこを経由します。

| 仮説 | 確認・対応 |
| --- | --- |
| 合成規則が2か所に重複し、結果がずれている | サムネイル側にビネット・ブルーム・グレイン・フェード・色収差がなく、`ImageFilterParams` の既定値0で補われていた。最後のコミット時点から存在する既存不具合 |
| 合成をModel外へ移しても実際の描画結果は変わらない | 全項目に異なる値を設定し、描画サービスへ届くパラメータが手動値と一致することをテストで確認 |
| サムネイルの変更はフィルターパネルにだけ影響する | 呼び出し元を照合。ユーザー確認のうえ、サムネイルを適用後の見た目と一致させる |

### 変更した境界

- [ImageAdjustmentValues](../../../GLogo/Models/ImageAdjustmentValues.swift)：プリセット合成前の手動調整値をまとめた値型。メモリ上の受け渡し専用で、保存形式は変えていません。
- [ImageFilterParamsComposer](../../../GLogo/UseCases/Rendering/ImageFilterParamsComposer.swift)：乗算・加算・手動値のみ・ティント置き換えの合成規則の唯一の入口。既定引数に頼らず全項目を明示します。
- `ImageElement.adjustmentValues` を読み取り専用で追加し、`currentFilterParams()` は合成を委譲するだけにしました。
- `FilterPreviewUseCase.generatePreview` は約20個の調整値引数を `adjustments` 1つに置き換え、重複していた `makePreviewParams` を削除しました。

描画モードの判定は既に `ImageRenderMode.fromPresetId` に一本化されていたため対象外です。調整値を追加するときは、`ImageAdjustmentValues` と Composer を更新すれば描画とサムネイルの両方に反映されます。Codable・履歴イベント・Revertスナップショットへの追加は引き続き個別に必要です。

### 検証と変更後レビュー

- **Critical**: 指摘なし。
- **Warning**: 今回の変更に新規指摘なし。サムネイルに効果系の処理が加わるため、生成負荷はわずかに増えます（72pt表示・縮小後画像に対する処理）。性能は未計測です。
- **Info**: Modelが参照するUseCases層の型に `ImageFilterParamsComposer` が加わりました。`ImageFilterParams` がUseCases層にあるための一時的な形で、描画要求の組み立てをModel外へ移す次回に解消を検討します。
- **Assumptions**: `ImageContentReplacedEvent` と `RevertAdjustmentSnapshot` は履歴・保存形式の契約に関わるため、今回は変更していません。
- **Test Coverage**: 新規 [ImageFilterParamsComposerTests](../../../GLogoTests/Unit/ImageFilterParamsComposerTests.swift) 5件で、合成規則の全項目、要素から描画サービスへの全項目の受け渡し、サムネイルと適用後の合成結果の一致を検証しました。合成から効果値を落とす変更を一時的に加えると5件中4件が失敗し、回帰を検出できることを確認しています。
- **Verification**: 関連26スイート・**131件成功、失敗0件**。iPhone 17 Pro／iOS 26.1 Simulator、Debug、`-parallel-testing-enabled NO`。変更したファイルからのビルド警告なし。`git diff --check` 問題なし。全スイート・UI・実機・性能再測定は未実施です。SwiftFormatは未導入のため実行できません。

`ImageElement.swift` は **1,466 → 1,437行** です。

対象: 第4回の25スイートに `ImageFilterParamsComposerTests` を追加。

### 次の範囲

段階3の第5回まで完了しました。次は描画要求の組み立てとキャッシュ保持をModelから移し、`image` の読み取りで同期描画が走る構造を解消します。`ImageAdjustmentValues` を履歴イベント・Revertスナップショットへ適用する整理（保存形式は維持）、初期化Factory、履歴周辺の境界整理も残件です。


## 段階3の進め方：責務の一覧（2026-11-03）

段階3は明確な完了条件を置かず、ImageElement が抱える責務を一覧にして「Modelに残すもの／外へ出すもの」を一つずつ分離します。高リスクのもの（描画・キャッシュ）は後に回し、軽いものから完了させます。

| 区分 | 責務 | 状態 |
| --- | --- | --- |
| Modelに残す | 画像ソースの参照と優先順位、編集値（調整・フレーム・フィルター）、役割・順序・メタデータ、`editRevision`、Revertの初期スナップショット、Codableと旧形式互換、`copy()`・`renderCopy()` | 維持 |
| 外へ出す① | 読み取り時の描画：`image` が同期でフル品質描画し、編集中は即時プレビューへ切り替える | 未着手（高リスク） |
| 外へ出す② | キャンバス描画：`draw(in:)` が表示画像を選んで描画する | 未着手（高リスク） |
| 外へ出す③ | 画像取得：`originalImage`・編集用プロキシを読み取り時に読み込みキャッシュする | 未着手（高リスク） |
| 外へ出す④ | キャッシュの持ち主：`renderCache`・`cachedImage`・無効化。履歴イベントから57か所で無効化を呼ぶ | 未着手（高リスク）。`editRevision` による自動失効を検討 |
| 外へ出す⑤ | 編集中の状態：`isCurrentlyEditing`・`startEditing`／`endEditing` | 未着手（①と一緒に扱う） |
| 外へ出す⑥ | 初期化時の読み込み：7つの初期化入口が画像を読み込みサイズを決める | **第7回で完了**。`copy()` のURL読み直しと画像差し替え時の寸法取得はModelに残る |
| 外へ出す⑦ | メタデータからフレーム値を戻す規則 | **第6回で完了** |

## 段階3・第6回：使われていない処理の削除と型の分離（2026-11-03）

- 削除：`getCanvasSize`・`resizeToFit`（呼び出し元なし）、`getImageAsync`・`recordEdit`・`shouldUseInstantPreviewForManipulation`（テストからのみ）、`ElementViewModel.renderedPreviewImage`。テストはこれらのAPI自体の確認だけを外し、各テストの本来の目的（束縛した描画サービスの利用、編集開始時のキャッシュ範囲など）は維持しました。常に `true` を返すことだけを確認していたテスト1件は削除しました。
- `captureCurrentAdjustmentAsInitialSnapshot` はテストからのみ使われますが、Revert回帰テストの初期状態を作る手段のため残しました。
- `editHistory` は保存データの読み込み互換のため残しました。アプリから追記する経路はなくなっています。
- 同居していた `ImageRole`・`ImageFrameStyle`・`ImageEditOperation`・`ImageMetadata` を Models の個別ファイルへ移しました。
- ⑦の `applyMetadataToImageProperties` を唯一の呼び出し元 [ImageElementMetadataRevertUseCase](../../../GLogo/UseCases/Metadata/ImageElementMetadataRevertUseCase.swift) の非公開メソッドへ移しました。解釈規則は変えていません。

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。挙動・保存形式・履歴の変更はありません。
- **Info**: `ImageElement.swift` は **1,437 → 1,211行**。
- **Verification**: GLogoTests 361件中358件成功。失敗1件は既知の `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用。変更したファイルからのビルド警告なし。iPhone 17 Pro／iOS 26.1 Simulator。UI・実機は未実施です。

## 段階3・第7回：初期化Factory（2026-11-03）

### 計画と確認した経路

Serenaの参照検索とソースで、7つの初期化入口の呼び出し元を確認しました。アプリから呼ばれるのは、Data＋キャンバス指定（インポート・DEBUG用fixture）とDataのみ（インポート・Preview・`copy()`）です。URL・パス・アセット名の入口は `copy()` からだけ、メタデータ指定と `isDynamicSizing: false` の入口はテストからだけ使われていました。

| 仮説 | 確認・対応 |
| --- | --- |
| 入口ごとの規則（URLのData保持・メタデータ抽出・破損時の既定サイズ）がずれる | 変更前に `copy()` の結果をソース種別ごとに固定するテスト6件を追加し、既存の初期化テスト7件と合わせて成功を確認してから移行 |
| `canvasSize` を渡し忘れると、差し替え後のサイズが変わる | Modelのinitで保持。生成時キャンバスでの差し替え・復元と、複製が既定キャンバスに戻ることをテストで確認 |
| 代入順の変更で `editRevision` の初期値が変わる | 参照は `ImageEditToken` の相対比較だけで、絶対値に依存する箇所はない |

### 変更した境界

- `ImageElement`：7つのconvenience initと共通initを、読み込み済みの値（ソース・配置サイズ・キャンバス・インポート順・依存）を受け取るinit 1つに置き換えました。I/Oを行わず、依存の既定値も持ちません。`ImageSource` を内部公開し、既定キャンバス `defaultCanvasSize` を追加しました。
- [ImageElementFactory](../../../GLogo/UseCases/Import/ImageElementFactory.swift)：画像データの寸法を境界 [ImageInitializationLoading](../../../GLogo/UseCases/Import/ImageInitializationLoading.swift) で読み取り、`ImageSizeCalculator` で配置サイズを決めてModelを作ります。メタデータは抽出しません。
- [ImageInitializationLoader](../../../GLogo/Infrastructure/Import/ImageInitializationLoader.swift)：境界に準拠。使われなくなったアセット名・パスの寸法取得と、メタデータ指定付きの読み込みを削除し、URL読み込みの戻り値から寸法を外しました。
- `ImageImportElementBuilder`・DEBUG用fixture・PreviewはFactoryを使います。Builderのinit引数は変えていません。
- `copy()`：結果を変えずに新しいinitを使う形にしました。URLソースのときだけ、従来どおりファイルを読み直してDataとメタデータを持たせます。生成時に計算して直後に上書きしていた配置サイズの計算（画像のデコード）はなくなりました。
- テストからのみ使われていたメタデータ指定の入口と `isDynamicSizing: false` の入口は、ユーザー確認のうえ削除しました。

アプリから見た挙動、保存形式、履歴イベント、キャッシュの無効化範囲は変えていません。インポートで作る要素は、従来どおりメタデータを持ちません。

### 検証と変更後レビュー

- **Critical**: 指摘なし。
- **Warning**: Factoryの初期化引数の既定値に、Infrastructureの具体型（`ImageInitializationLoader`・`ImagePreviewService.shared`）が入りました。Modelからの直接参照を減らした代わりで、Composition Rootの整備（残件③）でまとめて解消します。
- **Info**: ModelからInfrastructureへの参照は、初期化引数の既定値16か所とLoaderの呼び出し7か所から、Decoderの既定値2か所とLoaderの呼び出し2か所（`copy()` のURL読み直し・`replaceImageSource` の寸法取得）に減りました。`ImageElement.swift` は **1,175 → 1,054行** です。
- **Test Coverage**: 新規 [ImageElementCopyTests](../../../GLogoTests/Unit/ImageElementCopyTests.swift) 7件で、ソース種別ごとの複製結果（引き継ぐ値・作り直す値・URLの読み直し）を固定しました。`ImageElementInitializationTests` は [ImageElementFactoryTests](../../../GLogoTests/Unit/ImageElementFactoryTests.swift) 6件へ置き換え、境界の注入とインポート順・役割の確認を加えました。`ImageSourceResolverTests` にファイル由来ソースの取得1件を追加しました。テストの生成箇所（36ファイル・75か所ほか）はFactoryの呼び出しへ置き換え、期待値は変えていません。
- **回帰テスト棚卸し**: 削除した2入口の確認だけを外しました。旧URL・パス・アセット名の入口の確認は、本番で同じ規則を使う `copy()` のテストとResolverのテストへ移しました。パス・アセット名から生成時に配置サイズを求める規則は、本番で通る経路がなくなったため確認対象から外しました。
- **Verification**: GLogoTests 372件中369件成功。失敗1件は既知の `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用です。変更したファイルからの新しいビルド警告はありません（既存のweak変数・Sendable警告は残っています）。`git diff --check` 問題なし。iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。UI・実機は未実施です。SwiftFormatは未導入のため実行できません。

### 次の範囲

段階3の第7回まで完了しました。次の候補は、履歴イベントとRevertへの調整値型の適用（EventSourcing.swiftの分割を含む）と、Composition Rootの整備です。描画・画像取得・キャッシュ保持のModel外への移動は、引き続き後に回します。
