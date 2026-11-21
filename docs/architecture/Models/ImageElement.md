# ImageElementのデータと技術処理の境界

この文書は、画像要素Modelが担うデータ・描画・キャッシュ・永続化の境界を記録します。調査日: 2026-10-18。2026-10-28 に保存専用の描画コピーを追加し、2026-10-29 に AI 完了結果の照合に使う世代番号を記録しました。2026-11-01 に段階3の第1回として、画像取得Resolverを共有可変依存から要素ごとの依存へ変更しました。同日の第2回で初期化時の読み込み・メタデータ抽出とサイズ計算を分離しました。同日の第3回で要素別キャッシュの保持・無効化ルールを分離しました。2026-11-03の第4回で描画サービスの全体差し替えを廃止し、生成時の依存へ変更しました。同日の第5回でフィルターパラメータの合成規則をModel外へ一本化し、第7回で初期化の入口をUseCasesのFactoryへ移しました。2026-11-05の第8回で、編集値30項目をまとめた `ImageEditState` を Revert・画像差し替えの Undo・複製に適用しました。キャッシュ保持と描画要求の組み立てを担当するModelの責務は残っています。

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
| `draw(in:image:)` | 受け取った画像で [ImageElementRenderer](../../../GLogo/Models/ImageElementRenderer.swift) へ描画を委譲（第21回で画像を受け取る形にし、第24回で描画を Models へ移した） |
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
| 初期化時の読み込み・配置サイズの決定 | [ImageElementFactory](../../../GLogo/UseCases/Import/ImageElementFactory.swift)が境界 `ImageInitializationLoading` 経由で担当。`copy()` のURL読み直しは、Modelから [ImageInitializationLoader](../../../GLogo/Infrastructure/Import/ImageInitializationLoader.swift) を直接呼ぶ。差し替え・復元は配置サイズを変えない（第23回で寸法の取得を外した） |
| 配置サイズの計算 | [ImageSizeCalculator](../../../GLogo/Models/ImageSizeCalculator.swift)で純粋な計算として共有 |
| 画像ソースの優先順位と取得 | [ImageSourceResolver](../../../GLogo/UseCases/Storage/ImageSourceResolver.swift)とRepositoryを利用 |
| フィルター、SDR／HDR経路、プレビュー | [ImagePreviewService](../../../GLogo/Infrastructure/Rendering/ImagePreviewService.swift)等を利用 |
| 画像要素の描画 | [ImageElementRenderer](../../../GLogo/Models/ImageElementRenderer.swift)を維持。第24回で Models へ移した（UIKit の現在の描画先に依存するため、純粋な計算とは扱わない） |
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
- `JSONDecoder.userInfo[.imageSourceResolver]` から、プロジェクト内の画像要素へ取得先を渡せます。未指定時は標準Resolverです（第15回で既定値を外し、未指定は `MissingDecodingDependencyError` で失敗する形にした）。キーはデコーダー用の実行時設定で、保存JSONのキー追加ではありません。
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

新規 [ImageElementInitializationTests](../../../GLogoTests/Unit/ImageElementFactoryTests.swift)（第7回で `ImageElementFactoryTests` へ置き換え）7件を変更前に実行しました。当初、破損URLのメタデータをnilと想定した新規テストが失敗し、現行抽出器が空のメタデータを返すことを確認しました。既存動作に合わせた期待値で、分離前・分離後とも7件成功しています。既存テストの期待値は変更していません。

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
- `Decoder.userInfo[.imagePreviewService]` で子Decoderへ依存を渡せます。未指定時は共有サービスです（第15回で既定値を外し、必須にした）。保存キー追加ではなく、同じプロジェクトを異なる依存で復元しても再エンコード結果は一致します。
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
| Modelに残す | 画像ソースの参照と優先順位、編集値（調整・フレーム・フィルター）、役割・順序・メタデータ、`editRevision`、Revertの初期スナップショット、Codableと旧形式互換、`copy()`・`renderCopy()` | 維持。第8回で編集値を `ImageEditState` として一括で取り出し・反映できるようにした。第15回で Decoder の実行時の依存を必須にした（既定値で補わない）。第18回で `renderCopy()` は属性だけを写す形にした（元画像の固定は保存の範囲へ移した） |
| 外へ出す① | 読み取り時の描画：`image` が同期でフル品質描画し、編集中は即時プレビューへ切り替える | 第16回で処理を `ImageRenderSession` へ抽出（中間段階。Model が所有して委譲し、所有の場所と依存の向きの整理は残る。同期の描画も変えていない）。第17回で、受け取る側の入口は、エディタの管理役（`ImageRenderSessionStore`）から受け取る形にした（所有は第21回）。第20回で Model の `image` を外した。**第21回でセッションの所有を管理役へ移した**（要素は依存だけを持つ） |
| 外へ出す② | キャンバス描画：`draw(in:)` が表示画像を選んで描画する | 第16回で描く画像の選択を `ImageRenderSession` へ委譲。第17回でキャンバスと削除エフェクトは、管理役から受け取った画像で描く形にした（`drawOnCanvas` → `draw(in:image:)`）。`ImageElementRenderer` の呼び出しは Model に残る。第18回で保存の合成も、保存の範囲から受け取った画像で描く形にし、Model の `draw(in:)` の本番の呼び出し元はなくなった（テストの観察だけ）。**第21回で基底の `LogoElement.draw(in:)` と画像要素の上書きを外した**（テキストと図形だけが `ContextDrawable` を採用し、画像は受け取った画像で描く）。**第24回で `ImageElementRenderer` を Models へ移し**、Model から Infrastructure の描画を参照しなくなった |
| 外へ出す③ | 画像取得：`originalImage`・編集用プロキシを読み取り時に読み込みキャッシュする | 第16回で処理を `ImageRenderSession` へ抽出（中間段階。①と同じ）。第17回で画像一覧・AI・編集画面・フィルターのサムネイルは、管理役から受け取る形にした。第18回で保存も、受付は管理役から、選定・加工・合成は保存の範囲（`SaveProjectSnapshot`）から受け取る形にした（Model の `originalImage`・`getFilteredImageForce()` の本番の呼び出し元はなくなった）。第20回でこれらを Model から外した。**第21回で、取得の結果を持つセッションは管理役と保存の範囲が持つ形にした** |
| 外へ出す④ | キャッシュの持ち主：`renderCache`・`cachedImage`・無効化。履歴イベントから55か所で無効化を呼ぶ（第8回で数え直し。以前の「57か所」は誤り） | 第16回でキャッシュの保持と無効化を `ImageRenderSession` へ抽出（中間段階。①と同じ）。第19回で外からの失効と書き込みを管理役経由にし、履歴イベントの55か所は、失効させる範囲を返して履歴が管理役で失効させる形にした（Model の中の失効は第20回まで残る）。第20回で差し替え・復元・初期値への戻しの失効もイベントの範囲へ移し、`cachedImage` と失効の各メソッドを Model から外した。**第21回でキャッシュの持ち主を管理役（保存用の複製は保存の範囲）へ移した**。**第22回で、メモリ警告のときにプロジェクトにない要素（削除して履歴が持つ要素など）のキャッシュも消す形にした**（取り直して同じ画像に戻らない元画像・プロキシは残す）。`editRevision` による自動失効は別に判断する |
| 外へ出す⑤ | 編集中の状態：`isCurrentlyEditing`・`startEditing`／`endEditing` | 第16回で `ImageRenderSession` へ抽出（中間段階。①と同じ）。第19回で、編集中の切り替えは管理役経由にした。第20回で `startEditing`／`endEditing` を Model から外した。**第21回で、編集中の状態も管理役が持つセッションに移った** |
| 外へ出す⑥ | 初期化時の読み込み：7つの初期化入口が画像を読み込みサイズを決める | **第7回で完了**。`copy()` のURL読み直しはModelに残る。画像差し替え・復元の寸法の計算は、**第23回で外した**（差し替え・復元は配置サイズを変えない） |
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
- **Info**: Modelから外側の層（UseCases・Infrastructure）への参照は、初期化引数の既定値16か所とLoaderの呼び出し7か所から、Decoderの既定値2か所とLoaderの呼び出し2か所（`copy()` のURL読み直し・`replaceImageSource` の寸法取得）に減りました。既定値の内訳は、UseCases層の `ImageSourceResolver()` とInfrastructure層の `ImagePreviewService.shared` が各8か所です（第8回で訂正。当初は「Infrastructureへの参照」と書いていました）。`ImageElement.swift` は **1,175 → 1,054行** です。
- **Test Coverage**: 新規 [ImageElementCopyTests](../../../GLogoTests/Unit/ImageElementCopyTests.swift) 7件で、ソース種別ごとの複製結果（引き継ぐ値・作り直す値・URLの読み直し）を固定しました。`ImageElementInitializationTests` は [ImageElementFactoryTests](../../../GLogoTests/Unit/ImageElementFactoryTests.swift) 6件へ置き換え、境界の注入とインポート順・役割の確認を加えました。`ImageSourceResolverTests` にファイル由来ソースの取得1件を追加しました。テストの生成箇所（36ファイル・75か所ほか）はFactoryの呼び出しへ置き換え、期待値は変えていません。
- **回帰テスト棚卸し**: 削除した2入口の確認だけを外しました。旧URL・パス・アセット名の入口の確認は、本番で同じ規則を使う `copy()` のテストとResolverのテストへ移しました。パス・アセット名から生成時に配置サイズを求める規則は、本番で通る経路がなくなったため確認対象から外しました。
- **Verification**: GLogoTests 372件中369件成功。失敗1件は既知の `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用です。変更したファイルからの新しいビルド警告はありません（既存のweak変数・Sendable警告は残っています）。`git diff --check` 問題なし。iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。UI・実機は未実施です。SwiftFormatは未導入のため実行できません。

### 次の範囲

段階3の第7回まで完了しました。次の候補は、履歴イベントとRevertへの調整値型の適用（EventSourcing.swiftの分割を含む）と、Composition Rootの整備です。描画・画像取得・キャッシュ保持のModel外への移動は、引き続き後に回します。

## 段階3・第8回：履歴イベントの整理と編集値の型（2026-11-05）

### 計画と確認した経路

「変更前と変更後の値を記録して Undo する」方式は変えずに、履歴まわりの書き方を整理しました。プロジェクトの保存形式は変えていません。作業は、未使用の削除 → 固定テスト → 編集値の型の適用 → 差し替え Undo の修正 → ファイル分割の順に分け、それぞれ別のコミットにしました。

| 仮説・リスク | 確認・対応 |
| --- | --- |
| 履歴は保存されておらず、`EditorEvent` の Codable は使われていない | アプリ・テストのどちらにもイベントのエンコード・デコードがないことを確認し、Codable 準拠、9つのイベントの独自エンコード処理、`eventName`・`timestamp`・`getEventNames`、`undo()` 内の空の要素数チェック、未使用のイベント3つ（移動・サイズ変更・Z順）を削除 |
| 初期スナップショットの保存形式を壊すと、既存プロジェクトの Revert 基準を読めなくなる | 移行前に、`initialAdjustmentSnapshot` のキー30個と値の表現（書き出し）と、既存ファイルの書式で手書きした固定 JSON の読み込みを固定するテストを追加。型 `RevertAdjustmentSnapshot` とプロパティ名は残した |
| 差し替えの Undo がフレームと背景ぼかしを戻さない | 確認用テストで再現。編集値の型の適用では現行の挙動を保ったままテストで固定し、ユーザー確認のうえ別のコミットで修正 |
| Revert の Undo で描画キャッシュの無効化を落とす | 無効化の呼び出しを、削除した履歴用スナップショットからイベント側へ移した。Revert・差し替えの Undo／Redo で古い描画キャッシュを使わないことを、固定テストに加えた |

### 変更した境界

- [ImageEditState](../../../GLogo/Models/ImageEditState.swift)：調整値（既存の `ImageAdjustmentValues`）・フィルター（レシピとプリセットID）・フレーム設定（新しい [ImageFrameSettings](../../../GLogo/Models/ImageFrameSettings.swift)）をまとめた値型。メモリ上の受け渡し専用で、保存しません。
- `ImageElement`：現在の編集値を取り出す `editState` と、まとめて反映する `applyEditState(_:)` を追加しました。`copyAppearance` の30項目の代入と、初期スナップショットの作成・反映はこれを使います。描画キャッシュの無効化は、従来どおり呼び出し側が経路ごとに行います。
- `RevertAdjustmentSnapshot`：保存キーと色の RGBA 表現は変えず、`ImageEditState` との変換だけを受け持たせました。ティントとフレームで既存の色の変換方法が異なるため、保存値を変えないよう両方を残しています。
- Revert のイベント：履歴用の `ImageRevertStateSnapshot` を削除し、`ImageEditState` を記録します。
- 差し替えのイベント：34項目の記録を「差し替え前の画像ソース」と「`ImageEditState`」の2つにまとめ、要素から自分で記録する形にしました。作成側（`ImageEditUseCase`）で30行並んでいた引数もなくなりました。
- 履歴のファイル：`EventSourcing.swift`（作業前2,704行）を、`EditorEvent`・`EditorHistory` と、`UseCases/History/Events/` の機能別7ファイルに分けました（合計1,760行）。中身は変えずに移し、移動前後で宣言部分の行（1,434行）が一致することを機械的に確認しました。
- `AppDelegate`：中身が空の `saveUnsavedData()` と、それだけを呼んでいた `applicationWillTerminate` を削除しました（別のコミット）。

これで、画像の編集値を1つ追加するときに直すのは Model の中（プロパティ・値型・保存キー・初期スナップショットの変換）だけになり、Revert・差し替えのイベントと複製の処理は直さなくてよくなりました。

### 挙動の変更

- Revert を Undo したとき、ティントとフレームの色を RGBA へ変換し直さず、Revert 前の UIColor をそのまま戻します（計画どおり。RGB で表せる色なら見た目は同じ）。
- 画像の差し替え（手動背景除去・高画質化）を Undo したとき、フレーム6項目と背景ぼかし2項目も差し替え前の値へ戻ります（不具合の修正。別のコミット）。差し替えのイベントは背景ぼかしのマスクも保持するようになりました。

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。
- **Info**: 色を RGBA 成分へ変換する処理が、Model の初期スナップショット（ティント）と履歴の `RGBAColorSnapshot`（フレーム見た目のイベント）の2か所に残っています。後者は Codable の名残で、README の残件に記録しました。
- **Info**: 画像の編集値を追加したときは、テスト用の記録型 `ImageEditStateRecord` と、初期スナップショットのキー一覧のテストにも項目を足す必要があります。手順は [EventSourcing](../UseCases/History/EventSourcing.md) の共通契約に書きました。
- **Info**: `ImageElement.swift` は **1,054 → 1,078行** です（`copyAppearance` は短くなり、編集値との変換を追加）。
- **Test Coverage**: 編集値の型の適用前に、固定テスト5件を追加しました（[RevertSnapshotRegressionTests](../../../GLogoTests/Regression/RevertSnapshotRegressionTests.swift) の保存キーの書き出しと、手書きの固定 JSON の読み込み、[RevertUndoSequenceIntegrationTests](../../../GLogoTests/Integration/RevertUndoSequenceIntegrationTests.swift) の30項目、[ImageContentReplacedEventTests](../../../GLogoTests/Integration/ImageContentReplacedEventTests.swift)、[ImageUndoCacheInvalidationTests](../../../GLogoTests/Unit/ImageUndoCacheInvalidationTests.swift) の Revert・差し替えのキャッシュ）。5件とも、変更前のコードで成功することを一時 worktree で確認しました。あわせて、取り出しと反映の項目漏れを確かめる [ImageEditStateTests](../../../GLogoTests/Unit/ImageEditStateTests.swift) と、Revert の Undo で色の値そのものを戻す確認を追加しました。読み込みテストは当初、値を今の書き出しの結果から作っていましたが、書き出しと読み込みを同時に変えたときの互換切れに気づけないという Codex のレビューを受けて、手書きの固定 JSON に改めました。固定したのは初期スナップショットの部分で、要素全体の旧形式の固定 JSON はまだありません（第15回で、プロジェクト全体の新旧形式の固定 JSON を追加した）。
- **回帰テスト棚卸し**: 意味を失ったテストはありません（履歴の Codable やイベント名を確かめるテストはなかった）。初期スナップショットの往復テストと Revert → Undo の既存テストは彩度だけを見ていたため、キー30個と30項目の確認で補強しました。キャッシュ無効化・高画質化の制限・枠色の履歴・複製・保存用コピーの既存テストは、そのまま有効です。
- **Verification**: 各ステップのあとでビルドと GLogoTests 全体を実行しました。最終状態は378件中375件成功で、失敗1件は既知の `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用です。途中の全体実行で `testPreviewLatencyHDR_4K_P95` が1回だけ超過しましたが、性能テストだけの再実行2回では成功しました（固定パラメータでプレビューを測るテストで、今回の変更とは経路が無関係）。変更したファイルからのビルド警告はなく、`git diff --check`（新規ファイルを含む）と、更新した文書の相対リンクも確認しました。iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。UI・実機は未実施です。SwiftFormatは未導入のため実行できません。Codegraph は未接続で、参照の確認は `rg` とコンパイラで行いました。

### 次の範囲

段階3の第8回まで完了しました。次の候補は Composition Root の整備です。その後に、SwiftUI オーバーレイのジェスチャー変形を履歴に積む案（README の残件）を扱います。描画・画像取得・キャッシュ保持のModel外への移動は、引き続き後に回します。

## 段階3・第15回：Decoder の依存注入（2026-11-08）

第9回〜第14回は [EditorViewModel](../ViewModels/EditorViewModel.md) に記録しました。今回は Model の Decoder が対象のため、こちらに記録します。

### 計画と確認した経路

`ImageElement` の Decoder は、userInfo に依存がないとき、取得先（`ImageSourceResolver()`）と描画サービス（`ImagePreviewService.shared`）を自分で作っていました。これを外して復元する側が渡す形にし、あわせて `ImageSourceResolver` の初期化引数の既定値（`ImageAssetRepository.shared`）も外しました。README の「描画・キャッシュの移動とあわせて検討する」は、同じ回で実装するという意味には取らず、分けて進められることを確かめてから進めました（ユーザー・Codex 合意）。参照は `rg`・Serena・ソースで確認し、Codex は Codegraph でも確認しました。

| 確認したこと | 結果 |
| --- | --- |
| 描画・キャッシュの移動と分けられるか | 復元の経路で外側の層を参照していたのは、Decoder の既定値2つだけだった。Model に残る具体型の参照（`ImageInitializationLoader` の寸法の取得・URL の読み直し、`ImageElementRenderer` の描画、`BackgroundSettings` から `AssetManager` の背景画像）は、どれも `init(from:)` から呼ばれない。描画を Model の外へ移して描画依存が要らなくなっても、userInfo のキーを1つ外すだけで済む |
| 読み込みの経路 | `ProjectStorage` の読み込み4つ（単体・一覧の completion 版と async 版）は、アプリから呼ばれていない（エディタの読み込みは `0525c3d`・2025-09-10 で削除）。アプリが触れるのは起動時のディレクトリ作成だけで、テストから呼ぶのは async の単体読み込みだけだった。今回の変更で、アプリの実行時の挙動が変わる経路はない |
| 依存がないときの扱い | 既定値で補わず、`MissingDecodingDependencyError` で失敗させる。依存の設定不足を、保存データの不正（`DecodingError`）と区別するため。旧形式への切り替えの条件は `type` の `keyNotFound` だけで、このエラーは切り替えに使われない。画像を含まないプロジェクトは依存を使わないため、素の Decoder でも復元できる |
| 共有と並行処理 | 取得先は、要素ごとに作る形から、1回の読み込みで復元した画像要素が共有する形になる。Resolver は状態を持たず（共有の Repository への不変の参照だけ）、取得の結果は変わらない。エディタの `ImageElementFactory` も1つの Resolver を要素で共有している。描画サービスは前後とも共有インスタンス。Decoder は読み込みごと（一覧ならファイルごと）に作る今の形を保つ |
| Sendable | この SDK では `JSONDecoder.userInfo` が `[CodingUserInfoKey : any Sendable]` で、Sendable でない取得先を入れると警告になる（既存のテストで2か所出ていた）。取得の境界 `ImageSourceResolving`・`EditingImageLoading` を Sendable にし、すでに Sendable な `ImagePreviewing` にそろえた |

計画は Codex のレビューで補正し、次の条件を実装と検証に含めました。

| 条件 | 対応 |
| --- | --- |
| 状態を持つ偽物の `@unchecked Sendable` に根拠を書く | 既存の4つ（`SourceResolverSpy`・`CacheSourceSpy`・`CountingImageSourceResolver`・`RecordingImageAssetRepository`）は、どれもテストのスレッドから同期にだけ呼ばれることを確かめ（使うテストに非同期の経路がない）、その前提をコメントに書いた。並行に読み込むテストには、不変の値だけを持つ偽物（検査付きの Sendable）を使う |
| 残す読み込み経路のすべてで、依存が届くことを確かめる | 4経路とも、実際の保存と読み込みで確かめる。一覧は失敗したファイルを `try?` で黙って飛ばすため、保存した画像入りのプロジェクトの ID が結果に含まれることまで確かめる |
| 独自エラーの理由を正確に書く | 「依存の設定不足を、保存データの不正と区別する」とした |
| `rg` の確認範囲 | Decoder の既定値2つと、初期化引数の既定値に絞る。Model に残る具体型の参照は残件のまま |
| 判断待ちの2点 | 呼ばれていない読み込み3つは残して依存の引数を足す（削除は永続化の整理で判断）。依存不足のエラーは画像要素で出す |

### 変更した境界

- [ProjectDecodingDependencies](../../../GLogo/UseCases/Storage/ProjectDecodingDependencies.swift)（新規）：取得先と描画サービスを持つ Sendable な値型と、userInfo に設定した Decoder を作る `makeDecoder()`。依存が欠けたときの `MissingDecodingDependencyError` も同じファイルに置きました。
- `ImageElement`：Decoder は userInfo の2つのキーを必須にし、欠けていればエラーにします。保存形式は変えていません。
- [ImageSourceResolver](../../../GLogo/UseCases/Storage/ImageSourceResolver.swift)：初期化引数の既定値を外しました。取得の境界 [ImageSourceResolving](../../../GLogo/UseCases/Storage/ImageSourceResolving.swift) と [EditingImageLoading](../../../GLogo/UseCases/Storage/EditingImageLoading.swift) は Sendable にしました（本番の実装は変更なしで条件を満たします）。
- [ProjectStorage](../../../GLogo/Infrastructure/Storage/ProjectStorage.swift)：読み込み4つが `dependencies` を必須の引数で受け取り、読み込みごと（一覧ならファイルごと）に `makeDecoder()` で Decoder を作ります。
- [AppComposition](../../../GLogo/App/AppComposition.swift)：読み込みがアプリから呼ばれていないため、依存の生成関数は置きません（読み込みの経路を戻すときに足します）。テストは [LiveDependencyDefaults](../../../GLogoTests/Unit/LiveDependencyDefaults.swift) で、アプリと同じ実装から組み立てます。
- 変えないもの：保存形式、描画、履歴、取得のキャッシュ（共有の Repository）、描画サービスの共有。

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。
- **Info**: 素の `JSONDecoder()` では、画像を含むプロジェクトを復元できなくなりました（契約の変更）。アプリに該当する経路はなく、テストはアプリと同じ依存を設定した Decoder に置き換えました。
- **Info**: 一覧の読み込みは、依存が欠けたファイルも壊れたファイルと同じく黙って飛ばします（既存の挙動）。引数が必須のため、通常の使い方では欠けません。
- **Info**: Model に残る具体型の参照（寸法の取得・URL の読み直し・描画・背景画像）は、描画・キャッシュの移動で扱います。以前からある警告 `ProjectStorage.swift:92`（保存の完了通知で `LogoProject` を渡す）は残っています。
- **Test Coverage**:
  - 追加：[LogoProjectPolymorphicCodingRegressionTests](../../../GLogoTests/Regression/LogoProjectPolymorphicCodingRegressionTests.swift) に4件（新旧形式の固定 JSON での要素の型・値と、入れ子の画像要素への依存の受け渡し、依存が欠けたときのエラー、画像を含まないプロジェクトの復元）。[ProjectStorageLoadTests](../../../GLogoTests/Integration/ProjectStorageLoadTests.swift) に5件（読み込み4経路と並行読み込み）。並行のテストで使う不変の偽物は [FixedDecodingDependencies](../../../GLogoTests/Unit/FixedDecodingDependencies.swift) に置きました。
  - 置き換え：素の Decoder で画像を復元していた7ファイル13か所を、アプリと同じ依存を設定した Decoder に置き換えました。期待値は変えていません。
  - テストが失敗を検出できることも、一時的な書き換えで確かめました。`ProjectStorage` の内部で素の Decoder に戻すと、読み込みのテスト5件がすべて失敗します。Model を既定値で補う形に戻すと、依存が欠けたときのテストが新旧両方の形式で失敗します。書き換えたファイルを元に戻したことは、ハッシュで確認しました。
- **回帰テスト棚卸し**: 期待値を変えたテストはありません。素の Decoder が既定の依存で補うことを前提にしていた13か所は置き換え、素の Decoder では失敗することを新しいテストで固定しました。第8回で残っていた「要素全体の旧形式の固定 JSON」も、今回のテストで埋まりました。
- **Verification**: GLogoTests 425件中422件成功（失敗1件は既知の `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用。追加したテスト9件の分だけ件数が増えた）。UI テストは GLogoUITests 全体の30件が成功しました（起動テストが UI の構成ごとに4回動くため、実行は33回）。最初からのビルドで警告を比べ、消えたのは `ImageSourceIsolationTests` の `SourceResolverSpy` の警告（2か所）だけで、増えた警告はありません。`rg` で、Decoder の既定値2つと `ImageSourceResolver` の初期化引数の既定値が、アプリのコードに残っていないことを確かめました。`git diff --check`（新規ファイルを含む）と、更新した文書の相対リンクを確認しました。iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormat は未導入のため実行できません。

### 次の範囲

段階3の第15回まで完了しました。合意した順の次は、描画・画像取得・キャッシュ保持のModel外への移動（責務一覧の①〜⑤。高リスク）です。保存・読み込みの経路をアプリに戻すかどうかと、呼ばれていない読み込みを削除するかは、永続化の整理で決めます。

## 段階3・第16回：画像の取得・描画・キャッシュ・編集中の状態の処理の抽出（2026-11-08）

### 計画と確認した経路

責務一覧の①〜⑤（読み取り時の描画・キャンバス描画・画像取得・キャッシュ・編集中の状態）の関係を調べ、最初の1回として、持ち主と寿命を変えずに①③④⑤の処理とキャッシュを1つの型へ移しました（ユーザー・Codex 合意）。分離の中間段階で、①〜⑤を「分離完了」とはしません。所有の移動、`editRevision` による自動失効、非同期化は、処理のタイミングや無効化の規則が変わるため、別の回で判断します。

| 経路 | 必要な画像と品質 |
| --- | --- |
| キャンバス（`draw(in:)`）と削除のエフェクト（`renderSnapshot()`） | 通常はフル品質で加工した表示画像（同期で作って保持）。編集中は即時プレビュー（なければプレビュー品質の加工、なければプロキシか元画像） |
| 編集の確定（`ImageRenderRefreshUseCase`） | フル品質・非同期。採用の判定と、表示画像のキャッシュへの書き込みは呼び出し側 |
| 保存（`SaveProjectSnapshot` → `ImageProcessingService`。`Task.detached` の中） | 保存用の複製に固定した元画像へ、フル品質・同期で加工。表示画像のキャッシュは使わないが、元画像のキャッシュ（受付時に固定した元画像）は使う |
| 画像一覧・フィルターのサムネイル、AI、手動背景除去・ぼかしマスクの編集 | 未加工の元画像（`originalImage`）。手動背景除去とぼかしマスクの編集は、Resolver を直接呼んでプロキシを作る |

| 状態 | 持ち主と寿命 | 複製 | Undo／Redo | 画像差し替え | メモリ警告 |
| --- | --- | --- | --- | --- | --- |
| 要素ごとのキャッシュ（表示画像・元画像・プロキシ・プレビュー元画像） | 要素と同じ | `copy()`・Decoder は空から始まる。`renderCopy()` は元画像だけを固定 | 履歴イベントが表示画像を55か所で無効化し、差し替え・復元の2か所は4つとも消す | 4つと、共有の描画サービスのキャッシュを消す | 4つを消す（今のプロジェクトの要素だけ） |
| 編集中の状態 | 要素と同じ | 編集中でない状態から始まる | エディタが選択中の画像の編集を終える | 適用時にエディタが終える | 変えない |
| 共有キャッシュ（SDR／HDR のプレビュー、トーンカーブ） | 描画サービス（アプリ全体） | 共有 | — | どの要素の差し替えでもリセット | 解放 |

①③④⑤は同じキャッシュの4つの欄を読み書きするため、一部だけを移すとキャッシュの持ち主が2つに分かれます。そのため、キャッシュに触れる処理をまとめて移し、持ち主（要素）は変えない形を最初の1回にしました。プロキシ用の Repository はキャッシュを持たず、プロキシを保持するのは要素ごとのキャッシュだけです。計画の段階で書いた「無効化は57か所」は、差し替え・復元の2か所を含めた数え方でした（表示画像の無効化は55か所で、責務一覧の値と同じ）。

計画は Codex のレビューで補正し、次の条件を実装と検証に含めました。

| 条件 | 対応 |
| --- | --- |
| 型の名前と説明 | `ImageRenderSession`。要素ごとの取得・描画・キャッシュの管理を担い、要素と同じ寿命を持ち、編集の終了では破棄しない |
| 今回は分離の中間段階 | Model が型を所有して委譲するため、Model から UseCases の具体型への依存は残る。①③④⑤は「処理を抽出済み」とし、所有と依存の向きの整理は残すと記録する |
| キャッシュの説明 | 保存（`getFilteredImageForce()`）と非同期の確定も元画像のキャッシュは使い、使わないのは加工済みの表示画像のキャッシュ。初期化・Decoder・`copy()`・`renderCopy()` は、それぞれ別のインスタンスを持つ（保存用の複製は、元の要素と同じ ID でも別の状態） |
| 評価の順序と実行場所 | 委譲のために引数を先に組み立てない（要素を渡し、元と同じ時点で値を読む）。編集中にフォールバック候補を先に取得する順序も、短絡評価に変えない。型全体を MainActor にせず、非同期の入口だけ従来どおり MainActor にする。結果の採用判定と書き込みは `ImageRenderRefreshUseCase` に残す |
| 描画のテスト | 画像と品質ごとに異なる単色を返す偽物で、`draw(in:)` と `renderSnapshot()` の出力を確かめる。フォールバックは、プロキシだけ・元画像だけ・すべて取得不能を区別する |
| 残件 | 計画で見つけた3つは記録だけにし、処理の抽出に集中する（README の残件） |

### 変更した範囲

- [ImageRenderSession](../../../GLogo/UseCases/Rendering/ImageRenderSession.swift)（新規）：取得先・描画サービス・キャッシュ・編集中の状態を持ち、元画像とプロキシの取得、表示画像、キャンバスに描く画像、即時プレビュー、フル品質の加工（同期・非同期）、無効化、編集の開始と終了を担います。処理は元のコードと同じ順序のまま移し、要素の値（画像の参照・フィルターの値・描画経路）は、元と同じ時点で要素から読みます。
- `ImageElement`：初期化と Decoder のたびに `ImageRenderSession` を1つ作って持ち、既存の API（`originalImage`・`image`・`cachedImage`・`getFilteredImageForce()`・`renderFullQualityImageAsync()`・`getInstantPreview()`・`startEditing()`／`endEditing()`・無効化の各メソッド・`draw(in:)`）から委譲します。`previewService` はセッションの依存を返します。フィルターの値と描画経路の計算（`currentFilterParams()`・`currentRenderMode()`）は、セッションが読むため internal にしました。`ImageElementRenderer` の呼び出しは、UseCases から Infrastructure の具体型を呼ばないよう Model に残しました。
- 変えないもの：持ち主と寿命、キャッシュの確認と書き込みの順序、無効化の範囲、同期と非同期の区別、実行場所、取得先と描画サービスの呼び出し回数、呼び出し側とテスト。

`ImageElement.swift` は **1,086 → 960行** です。

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。
- **Info**: Model がセッションを所有して委譲するため、Model から UseCases の具体型への依存は残ります（中間段階）。AGENTS.md の「移行中の例外」にも書き足しました。
- **Info**: フィルターの値と描画経路の計算を internal にしたため、Model の公開範囲が少し広がりました。セッションが描画の時点で読むためで、計算自体は Model のデータの計算です。
- **Info**: セッションを直接確かめる単体テストは足していません。今回は既存の API をそのまま守るため、Model の API から確かめています。所有を移す回で、セッションを直接確かめるテストを足します。
- **Test Coverage**:
  - 追加（抽出の前に、変更前のコードで成功することを確認）：[ImageElementDrawingTests](../../../GLogoTests/Unit/ImageElementDrawingTests.swift) 6件（通常のフル品質、編集中の即時プレビュー、プレビュー品質の加工、プロキシだけ・元画像だけ・すべて取得不能のフォールバックを、`draw(in:)` と `renderSnapshot()` で描かれた色で確かめる）。[ImageElementCacheTests](../../../GLogoTests/Unit/ImageElementCacheTests.swift) 2件（表示画像のキャッシュがあれば元画像を取得しない、編集中は即時プレビューがあってもフォールバック候補の元画像を先に取得する）。描画のテストで使う偽物は不変の値だけを持ち、元になる画像がなければプレビューを作らない（実際のサービスと同じ）。
  - 既存の回帰テスト（操作ごとの無効化の範囲、Undo の無効化、保存時の固定、依存の独立性、確定の描画、AI の結果など）は、変更なしで成功しました。
  - 呼び出し回数：コミットしない確認用テストで、12の場面（通常・編集中の描画、即時プレビューなし、プロキシだけ、元画像だけ、取得不能、保存の加工、非同期の確定、保存用の複製、Revert 後の編集、画像の差し替え、削除のエフェクト）について、抽出の前（1つ目のコミットの状態）と後の、取得先と描画サービスの呼び出し回数を比べ、すべて一致しました。編集中の描画1回につき即時プレビューを2回求めることと、取得できない画像を覚えずに取得をやり直すこと（第3回から変えていない挙動）も、回数で確かめました。
- **回帰テスト棚卸し**: 期待値を変えたテストはありません。キャンバスの描画を直接確かめるテストがなかったため、描かれた色で確かめるテストを足しました。
- **Verification**: GLogoTests は最終の全体実行で433件中429件成功（失敗2件は性能テストの `testPreviewLatencySDR_4K_P95` と `testPreviewLatencyHDR_4K_P95`。性能テストだけの再実行2回では、既知の SDR の1件だけが失敗。HDR のテストは描画サービスを直接測り、今回の変更とは経路が無関係。スキップ2件は実機専用。追加したテスト8件の分だけ件数が増えた）。UI テストは GLogoUITests 全体の30件が成功しました（実行は33回）。最初からのビルドで、第15回と比べて警告の増減はありません。`git diff --check`（新規ファイルを含む）と、更新した文書の相対リンクを確認しました。iPhone 17 Pro／iOS 26.1 Simulator（抽出前の確認用テストは iPhone 17 Pro Max）、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormat は未導入のため実行できません。

### 残り

- 所有の移動（エディタ側で要素の ID ごとに持つ）：削除した要素・Undo で戻る要素・保存用の複製・メモリ警告の扱いと、キャンバスの描画の入口（`LogoElement.draw(in:)`）の変更を設計する。移せれば、Model から UseCases の具体型への依存もなくなる。
- `editRevision` による自動失効と、表示の非同期化は、それぞれ別に判断する。
- 計画で見つけた3つ（README の残件）：削除した画像要素のキャッシュが履歴に残る、画像一覧のサムネイル、編集中の即時プレビューの2回の要求。

## 段階3・第17回：受け取る側の入口を、エディタの管理役経由に付け替え（2026-11-10）

### 計画と確認した経路

セッションの所有をエディタ側へ移す作業は、呼び出し元が広いため（本番コードで約20ファイル、テストで最大47ファイル）、4回に分けました（ユーザー・Codex 合意）。

| 回 | 内容 | 挙動 |
| --- | --- | --- |
| 第17回（今回） | 管理役を作り、受け取る側の入口を付け替える。所有は移さず、管理役は要素のセッションを返す。今の寿命をテストで固定する | 変えない |
| 第18回 | 保存の範囲を分ける（保存用の複製のセッションを、スナップショットが持つ） | 変えない |
| 第19回 | 所有を移し、状態を変える側も管理役経由にする。失効の経路は、実装の前の計画で決める | 解放された要素の分を捨てる時点の差だけ |
| 第20回 | 削除した要素のキャッシュを解放する時点を変える | 変える |

先に決めた4点は次のとおりです。

| 論点 | 決めたこと |
| --- | --- |
| 管理する場所 | `UseCases/Rendering` の `ImageRenderSessionStore`（MainActor）。`EditorViewModel` が1つ持ち、寿命はエディタと同じ。受け取る側は、読み取り用の Protocol `ImageRenderSessionReading` を通して使う（状態を変える操作は含めない）。`ImageRenderSession` は保存がバックグラウンドで使うため、MainActor にしない |
| 要素の識別 | ID ではなくインスタンス。保存用の複製は元の要素と同じ ID を持ち、`id` は書き換えられる。Undo で戻るのは同じインスタンスなので、今と同じセッションを使える。保存用の複製は管理役を通さず、保存の範囲で扱う（第18回） |
| 寿命と解放 | 構造を移す回（第17回〜第19回）は、今の寿命を保つ。解放の時点の変更は、挙動の変更として第20回に分ける。削除エフェクトが削除の直前に画像を受け取る順序は保つ |
| 描画・取得の入口 | 下の表のとおり、Model の取得・描画の API を通さずに、管理役から受け取る |

| 入口 | 今回の受け取り方 |
| --- | --- |
| キャンバス（`CanvasView`） | `CanvasViewRepresentable` が設定した管理役から画像要素の描く画像を受け取り、`ImageElement.draw(in:image:)` で描く（共通の描き方 `drawOnCanvas`）。テキストと図形は従来の `draw(in:)` |
| 削除エフェクト（ツールバー・キャンバスの削除モード） | キャンバスと同じ `drawOnCanvas` でスナップショットを作る（`renderSnapshot(renderSessions:)`）。削除の直前に作る順序は変えない |
| 画像一覧のサムネイル | `EditorViewModel.renderSessions` から元画像 |
| AI（背景除去・背景ぼかし・高画質化） | 要求を受けた時点で、その場で管理役から元画像 |
| フィルターのサムネイル | 管理役から元画像と描画サービス |
| 手動背景除去・ぼかしマスクの編集 | 画面に管理役を渡し、StateObject が ViewModel を作る式の中（ViewModel の初期化）で受け取る。手動背景除去の「元画像 ?? 表示画像」の順序は変えない |
| 保存 | 変えない（第18回で扱う） |

今の寿命は、計画のときにコミットしない確認用テストで確かめ、今回 [ImageRenderSessionLifetimeTests](../../../GLogoTests/Integration/ImageRenderSessionLifetimeTests.swift) で固定しました。

| 場面 | 要素 | キャッシュ |
| --- | --- | --- |
| 削除 | 削除のイベント（`ElementRemovedEvent`）が持つ | 残る |
| 削除の Undo | 同じインスタンスが戻る | 残っていた分を使う |
| メモリ警告 | — | プロジェクトにある要素の分だけ消える。削除した要素の分は残る（第20回で変える予定） |
| 追加の Undo のあと新しい操作 | Redo の履歴が消えた時点で解放 | 要素と一緒に解放 |
| 履歴の上限（100件） | 削除のイベントが押し出された時点で解放 | 要素と一緒に解放 |
| 編集中に削除して Undo | 編集中の状態は、削除では終わらない（画面では、選択の解除を受けた編集パネルが終える） | 戻した要素は編集中のまま |

計画は Codex のレビューで補正しました。

| 補正 | 対応 |
| --- | --- |
| 編集画面の画像の取得も、遅延したままにする | `EditorView` や画面の初期化では取得せず、StateObject が ViewModel を作る式の中で受け取る。[MaskEditingScreenDependencyTests](../../../GLogoTests/Integration/MaskEditingScreenDependencyTests.swift) に、画像の受け取り回数（画面の値を作るだけなら0回、表示で1回、再描画では増えない、開き直すと増える）を足した。推奨の「取得する関数を渡す」形ではなく、取得の関数をまとめた読み取り用の Protocol を渡す形にした。「元画像 ?? 表示画像」の規則と順序を ViewModel の中に残せて、ほかの入口と同じ型・同じ偽物で記録できるため |
| 管理役を通ったことを、同じ画像が返ることとは別に確かめる | 問い合わせを記録し、要素自身のセッションと別の画像を返す偽物の管理役（`RenderSessionReadingSpy`）を渡して確かめた。確かめた範囲は入口ごとに違う。実際のエディタ画面の中のキャンバスは、問い合わせの記録と描かれた色。キャンバスの削除モードは、問い合わせの記録と、削除より前に問い合わせたこと（スナップショットの色は見ていない）。ツールバーの削除は、それらに加えてスナップショットの色。画像一覧は、問い合わせの記録だけ。AI とフィルターのサムネイルは、問い合わせの記録と、加工に渡った画像・使われた描画サービスが偽物の返したものであること。編集画面は、ViewModel で問い合わせの記録（順序）と編集に使う画像、画面の表示で受け取りの回数 |
| 第19回の掃除を、次の描画だけに頼らない | 第19回の計画で確かめる（下の「残り」）。「解放は描画1回分遅れる程度」とは判断しない |
| 第20回の「Undo の表示には影響しない」は未確定にする | 第20回で判断する（下の「残り」） |

### 変更した範囲

- [ImageRenderSessionReading](../../../GLogo/UseCases/Rendering/ImageRenderSessionReading.swift)（新規）：受け取る側の読み取り用の Protocol。元画像・表示画像・キャンバスに描く画像・描画サービスを返す。
- [ImageRenderSessionStore](../../../GLogo/UseCases/Rendering/ImageRenderSessionStore.swift)（新規）：上の Protocol を実装する管理役。今は要素のセッション（`ImageElement.renderSession`）を返すだけにした。
- `ImageElement`：`renderSession` を internal にした（管理役だけが読む中間段階）。受け取った画像で描く `draw(in:image:)` を足し、`draw(in:)` はそこへ委譲する。
- `EditorViewModel`：`renderSessions` を持ち、AI とフィルターのパネル（`ElementViewModel` 経由）へ渡す。初期化の引数で受け取り、既定は新しい管理役（テストでは偽物を渡せる）。
- View：`CanvasView`（受け取り先を持ち、設定されるまでは要素を描かない）、`CanvasViewRepresentable`（`updateUIView` で設定、削除モードの処理）、[LogoElement+CanvasDrawing](../../../GLogo/Views/Editor/Canvas/LogoElement+CanvasDrawing.swift)（新規。キャンバスと削除エフェクトで共通の描き方）、`DeleteFadeEffect` の `renderSnapshot(renderSessions:)`、`EditorOverlayToolbarView`（削除ボタンの処理を `requestDelete()` に出した）、`ImageListRailView`、`EditorView` と2つの編集画面。
- ViewModel：`AIToolsViewModel`・`FilterPanelViewModel`・`ManualBackgroundRemovalViewModel`・`BackgroundBlurMaskEditViewModel`。
- 変えないもの：状態を変える側（編集中の切り替え・キャッシュの書き込み・失効・メモリ警告）、保存、履歴、Model の既存の API、取得と加工の時点と回数、評価の順序。

`ImageElement.swift` は **960 → 970行**、`EditorViewModel.swift` は **780 → 787行** です。

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。
- **Info**: View（キャンバス・削除エフェクト・画像一覧）が、エディタから受け取った UseCases の読み取り用 Protocol を直接呼びます。以前は Model の API を呼んでいました。状態を変える操作を含まない Protocol に限り、受け取り先はエディタが渡すものだけにしています。
- **Info**: `ImageElement.renderSession` が internal になり、管理役以外からも呼べます。第19回で要素から外すまでの中間段階で、説明に「管理役のほかは使わない」と書きました。AGENTS.md の「移行中の例外」にも書き足しました。
- **Info**: `CanvasView` は、受け取り先が設定されるまで要素を描きません（以前の経路へ戻すと、設定漏れに気づけないため）。アプリでは `updateUIView` が最初の描画より前に設定します。
- **Info**: 削除ボタンの処理（`requestDelete()`）は、テストから呼ぶため private にしていません。テストの表示の補助と色の比較は、今回足したテストでも各ファイルに持たせています（重複の整理は別に判断）。
- **Test Coverage**:
  - 追加18件：[ImageRenderSessionStoreTests](../../../GLogoTests/Unit/ImageRenderSessionStoreTests.swift) 4件（要素のセッションと同じ画像を返しキャッシュと編集中の状態を共有する、Model の経路と取得先・描画サービスの呼び出し回数が手順ごとに同じ、保存用の複製は同じ ID でも別のセッション）。[ImageRenderSessionRouteTests](../../../GLogoTests/Integration/ImageRenderSessionRouteTests.swift) 9件（キャンバス、キャンバスの削除モードとツールバーの削除が削除の前に管理役から受け取る、画像一覧、AI の3つの要求、フィルターのサムネイル、手動背景除去の「元画像 ?? 表示画像」の順序、ぼかしマスク）。ImageRenderSessionLifetimeTests 5件（上の寿命の表）。
  - 変更：MaskEditingScreenDependencyTests 2件に画像の受け取り回数を足した。[ImageElementDrawingTests](../../../GLogoTests/Unit/ImageElementDrawingTests.swift) 6件は、キャンバスの描き方・削除エフェクト（どちらも管理役経由）・Model の `draw(in:)`（保存の合成が使う）の3つで、描かれた色を確かめる形にした。AI の3ファイルと手動背景除去・ぼかしマスクの座標のテストは、組み立ての引数だけを足した。
  - 接続漏れを検出できること：コミットしない確認として、各入口を一時的に以前の経路（Model の API、または別の管理役）へ戻すと、キャンバスの描画、キャンバスの削除モードとツールバーの削除、画像一覧、AI、フィルターのサムネイル、手動背景除去（ViewModel と画面）のテストが失敗し、戻さなかったぼかしマスクのテストは成功のままであることを確かめてから、元に戻しました。
- **回帰テスト棚卸し**: 既存のテストの期待値は変えていません。ImageElementDrawingTests は、削除エフェクトの入口の引数が変わったため、確かめる経路を3つに広げました（6場面と期待する色は同じ）。
- **Verification**: GLogoTests は451件中448件成功（失敗1件は既知の性能テスト `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用。追加した18件の分だけ件数が増えた）。UI テストは GLogoUITests 全体の30件が成功しました（実行は33回）。`git diff --check`（新規ファイルを含む）と、更新した文書の相対リンクを確認しました。 アプリのビルドで、変更したファイルに警告はありません。Xcode 27.1、iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormat は未導入のため実行できません。

### 残り

- **第18回**：保存の範囲を分ける。保存用の複製のセッションをスナップショットが持ち、選定と加工に、複製の画像の受け取り口を渡す。
- **第19回**：所有を管理役へ移し、状態を変える側（編集中の切り替え・キャッシュの書き込み・失効・メモリ警告）も管理役経由にする。失効の経路は、実装の前の計画で決める（Model が通知する形か、履歴イベントが範囲を示す形か。`editRevision` による自動失効は混ぜない）。解放された要素の分を捨てる時点は、次の描画だけに頼らない。最後の画像を取り除いた場合などは、以後問い合わせが来ないことがあるため、履歴の上限による破棄と Redo の履歴の破棄のあと、問い合わせがなくても不要なキャッシュを回収できるかを確かめる。寿命のテストのこの2件は、要素の解放を弱参照で確かめているだけなので、所有を移したあとの「要素は消えたが、管理役にキャッシュが残る」は検出できない。第19回で、キャッシュに入れた画像への弱参照などで、キャッシュ自体の解放も直接確かめるテストを足す（Codex のレビュー）。
- **第20回**：メモリ警告のとき、削除した要素（プロジェクトにない要素）のキャッシュも解放の対象にする方向（ユーザー・Codex 合意）。ただし、元画像まで消すと再取得が必要になる。`ImageSourceResolver` は、パスや URL を参照する要素ではファイルを読み直すため（`resolveOriginalImage`）、そのファイルが変更・削除されていれば同じ画像には戻らない。「Undo の表示には影響しない」とはまだ言えないため、元画像も解放できる条件と、加工済みのキャッシュだけを解放する場合を、第20回で判断する。解放より前に削除エフェクトのスナップショットを作ることも、そのときに削除の流れの中で保証する。
- 保留（Codex 合意）：表示の非同期化、サムネイル専用の画像、即時プレビューの重複した要求。`editRevision` による自動失効は、構造の変更に混ぜず別に判断する。

## 段階3・第18回：保存の範囲を分ける（2026-11-11）

### 計画と確認した経路

保存の経路で画像を受け取る場所は、受付の1か所と、バックグラウンドの5か所でした。今回は所有を移さず（保存用の複製のセッションは、まだ複製が持つ）、画像を受け取る場所だけを付け替えました。

| 段階 | 実行場所 | 第17回までの受け取り方 | 第18回の受け取り方 |
| --- | --- | --- | --- |
| 受付（`SaveImageCoordinator` の `save`・`saveComposite` → `SaveProjectSnapshot`） | MainActor、権限待ちより前 | `renderCopy()` が、編集元の要素の `originalImage`（Model の API）を読んで、複製のセッションに固定する | スナップショットが、エディタの管理役から元画像を受け取って固定する。`renderCopy()` は属性だけを写す |
| モード判定（`SaveImagePolicy`） | 同上 | 画像は読まない（属性だけ） | 変えない |
| 選定（`ImageSelectionService`） | `Task.detached` の中 | 複製の `originalImage` | 保存の範囲の `originalImage(of:)` |
| 単独の加工（`ImageProcessingService.applyFilters`） | 同上 | 複製の `getFilteredImageForce()` | 範囲の `filteredImage(of:)` |
| 合成（`ImageProcessingService.makeCompositeImage`） | 同上 | ベースと可視の画像要素の `getFilteredImageForce()`。得られなかった画像要素は `draw(in:)` | 範囲の `filteredImage(of:)`。得られなかった画像要素は、範囲の `drawingImage(of:)` で描く |

Codex の3条件は、次の形で守ります。

| 条件 | 守り方 | 確かめるテスト |
| --- | --- | --- |
| 元画像と編集値を、権限待ちより前の保存受付時に固定する | 受付（MainActor）でスナップショットを作り、元画像は管理役から受け取って固定する。編集値と属性は、従来どおり `renderCopy()` が写す | 既存の [SaveSnapshotIntegrationTests](../../../GLogoTests/Integration/SaveSnapshotIntegrationTests.swift) の権限待ち・加工待ち・AI 完了と Undo の3件。追加した `test_acceptance_readsStoreOnlyWhileSaving`（両方の入口で、`save` の呼び出しの中で画像要素ごとに1回だけ問い合わせ、完了まで増えない。保存した画像は、管理役が返した画像から作られる） |
| セッションを保存1件ごとに専有し、エディタや別の保存要求と共有しない | スナップショットは自分の複製をインスタンスで引き当て、自分の複製にだけ画像を返す。独立させるのはセッションとキャッシュの状態で、同じ内容を続けて受け付けた2件が同じ元画像（UIImage）を参照するのは構わない（バッファは複製しない） | [SaveProjectSnapshotTests](../../../GLogoTests/Unit/SaveProjectSnapshotTests.swift) の `test_snapshot_servesOnlyOwnCopies`（編集元と、同じ ID を持つ別のスナップショットの複製には返さない）と `test_snapshots_keepIndependentCaches`（片方のキャッシュの書き込み・消去が、もう片方にも編集元にも届かない） |
| バックグラウンドの保存処理へ、MainActor のエディタ用管理役を持ち込まない | 管理役はスナップショットの初期化でだけ使い、保持しない。権限待ちのクロージャと保存のタスクは、スナップショットだけを持つ。範囲の Protocol（`SaveImageReading`）は MainActor にせず、管理役の Protocol とは別にした | 追加した `test_pendingSave_doesNotRetainStore`（両方の入口で、権限待ちの間に偽物の管理役への弱参照が nil になり、そのあとも受付で固定した画像で保存できる）と、上の「完了まで問い合わせが増えない」。管理役をバックグラウンドへ持ち込むこと自体はコンパイルが通り、同期の呼び出しだけがコンパイルエラーになる（計画のときに確認用のコードで確かめた）ため、テストで防ぐ |

計画は Codex のレビューで補正しました。

| 補正 | 対応 |
| --- | --- |
| 「共有しない」の意味を、セッションとキャッシュの状態の独立に直す | 画像自体を共有しないことは求めず、片方のキャッシュの変更がもう片方に届かないことを確かめた。元画像の UIImage を複製しない既存の取り決め（`test_snapshot_preservesImageAppearance`）はそのまま。範囲外の判定には、編集元に加えて、同じ ID を持つ別のスナップショットの複製も含めた |
| 問い合わせの回数に加え、管理役を保持していないことも確かめる | Coordinator を直接呼び、権限待ちの間に管理役への弱参照が nil になることと、そのあとも保存できることを確かめた（プロジェクトを保持しないことを確かめる既存のテストと同じ形） |
| 加工の失敗の比較で、ベースと重ねる画像を分ける | ベースの1回目の加工に失敗すると、合成を終える。2回目（可視の画像要素をまとめて解決するとき）に失敗したベースと、加工に失敗した重ねる画像は、描画用の画像（表示画像の加工を試し直したもの）で描く。変更の前後の比較（下の検証）に、ベースの1回目の失敗、ベースの2回目の失敗と描き直しの成功・失敗、重ねる画像の失敗と描き直しの成功・失敗を含め、回数と出力が同じことを確かめた。コミットするテストでも、問い合わせの順序と出力で固定した |
| テスト側の互換の入口で、余分な取得や複製をしない | 互換の入口は引数を補うだけにした（スナップショットは本体の入口で1つだけ作り、要素に注入した偽物もそのまま通る）。新しい範囲を確かめるテストは、管理役と範囲を明示して渡す |

### 変更した範囲

- [SaveImageReading](../../../GLogo/UseCases/SaveImage/SaveImageReading.swift)（新規）：保存の範囲の読み取り用の Protocol。元画像・フル品質で加工した画像・描画用の画像を返す。MainActor にしない。
- [SaveProjectSnapshot](../../../GLogo/UseCases/SaveImage/SaveProjectSnapshot.swift)：保存1件の範囲として、上の Protocol を実装する。初期化（MainActor）で管理役から元画像を受け取って複製のセッションへ固定し、管理役は保持しない。複製はインスタンスで引き当て（範囲の寿命のあいだ複製を持ち続け、識別子が使い回されないようにする）、範囲に含まれない要素には nil を返す。セッションはまだ複製が持つ（所有の移動は第19回）。
- `ImageElement`：`renderCopy()` は属性だけを写す（元画像の固定はスナップショットへ移した）。`renderSession` の説明を「管理役と保存の範囲のほかは使わない」に直した（AGENTS.md の「移行中の例外」も同じ）。
- 選定（`ImageSelecting`・`ImageSelectionService`）と加工（`ImageProcessing`・`ImageProcessingService`）：範囲を引数（`images:`）で受け取り、画像はそこから受け取る。手順・回数・失敗の扱いは変えていない。
- `SaveImageCoordinator`：受付で管理役をスナップショットへ渡し、選定と加工にはスナップショットを渡す。
- 保存の要求の境界（`PhotoLibrarySaving`）・`ImageSaveViewModel`・`EditorViewModel`：保存の要求に管理役（`renderSessions:`）を渡す。エディタは自分の管理役を渡す。
- 変えないもの：モード判定、選定の規則、加工・合成の手順と回数、失敗時の結果、保存形式、完了の通知、権限の扱い、受付の読み取りの順序（要素の順に、属性を写したあとで元画像）、元画像の UIImage を複製しないこと。

これで保存の経路も Model の取得・描画の API を使わなくなり、`originalImage`・`getFilteredImageForce()`・`draw(in:)` の本番の呼び出し元はなくなりました（Serena で確認。`draw(in:)` は基底クラスの `draw(in:)` からも呼ばれうるが、本番で基底の `draw(in:)` を呼ぶ2か所は、どちらも画像要素を先に分けて描く）。テストが観察に使っているため今回は残し、外すかは第19回で判断します。

`ImageElement.swift` は **970行** のまま、`EditorViewModel.swift` は **787 → 790行** です。

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。
- **Info**: Model の取得・描画の API（`originalImage`・`getFilteredImageForce()`・`draw(in:)`）は本番の呼び出し元がなくなり、テストの観察だけが使います（上の段落）。
- **Info**: テスト側の互換の入口（`ElementSessionImages`）は、以前の合成の `draw(in:)` と同じ画像を返すため、`renderSession` を直接使います。本番で `renderSession` を使うのは、管理役と保存の範囲だけです。
- **Info**: スナップショットの `project` の要素は書き換えられます。範囲外の要素には画像を返さず、保存失敗や一部画像の省略につながります（合成の重ねる画像なら、その画像を描かずに保存が成功する場合がある）。本番ではスナップショットの要素だけを渡し、引き渡した後は読み書きしない取り決めです（型の説明に書いた）。
- **Info**: 計画外の発見（合成でベースの加工が2回走る）は、記録だけにしました（[README](../README.md) の「計画外の対応と残件」）。
- **Test Coverage**:
  - 追加14件：SaveProjectSnapshotTests 3件（受付で要素ごとに1回だけ管理役から元画像を受け取って固定する、自分の複製にだけ返す、2件のキャッシュの独立）。SaveSnapshotIntegrationTests 2件（上の条件1・3）。[SaveImageReadingRouteTests](../../../GLogoTests/Unit/SaveImageReadingRouteTests.swift)（新規）8件（選定は範囲の元画像で比べ、ベースの役割があれば問い合わせない。単独の加工。合成で、ベースに2回・重ねる画像に1回、範囲へ加工済みの画像を求めること、重ねる画像の加工の失敗と描き直しの成功・失敗、ベースの2回目の失敗と描き直し、ベースの1回目の失敗で終えること。どれも問い合わせの順序と出力の色で確かめる）。[EditorImageSaveIntegrationTests](../../../GLogoTests/Integration/EditorImageSaveIntegrationTests.swift) 1件（エディタが両方の入口で自分の管理役を渡す）。
  - 変更：保存の偽物7つ（選定・加工の5つ、保存の要求の2つ）の引数。`renderCopy()` の固定に頼っていた3件（ImageSourceIsolationTests の `test_saveSnapshot_pinsResolvedImage`（名前を変えた）、ImageElementCacheTests の `test_copies_keepIndependentCaches`、SaveProjectSnapshotTests の `test_snapshot_preservesOrientationAndColorSpace`）は、スナップショットを通す形にした。SaveProjectSnapshotTests と SaveSnapshotPerformanceTests は、スナップショットに管理役を明示して渡す。
  - 既存の呼び出し45か所（合成22・単独の加工4・選定2・Coordinator の保存9・保存の画面の ViewModel 8）は、テスト側の互換の入口 [SaveScopeDefaults](../../../GLogoTests/Unit/SaveScopeDefaults.swift)（新規）で変えずに通す。選定と加工には、要素自身のセッションから返す `ElementSessionImages`（以前の Model の API と同じ取得・加工）を渡し、保存の要求にはアプリと同じ管理役を渡す。
  - 変更の前後の比較：コミットしない確認用テストで、12場面（単独、単独の加工の失敗、非表示の大きい画像を含む単独、権限待ちの間の編集、合成、ベースの1回目の失敗、ベースの2回目の失敗と描き直しの成功・失敗、重ねる画像の失敗と描き直しの成功・失敗、ベースの役割のない合成、強制の合成）の結果・書き込みの回数・出力（PNG のハッシュ）・受付の時点と完了の時点の取得の回数・入力ごとのフル品質の加工の回数を記録し、変更の前後ですべて一致することを確かめた。
  - 接続漏れを検出できること：コミットしない確認として、9か所を一時的に以前の形へ戻すと（選定・単独の加工・ベース・可視の画像要素の解決・描き直しを Model の API へ、受付の固定を Model の API へ、Coordinator が管理役を持つ、範囲が ID で引き当てる、エディタが別の管理役を渡す）、それぞれ対応するテストが失敗することを確かめてから元に戻した（4回に分けて実行）。
- **回帰テスト棚卸し**: 既存のテストの期待値は変えていません。`renderCopy()` の固定に頼っていた3件は、確かめる取り決め（保存用の複製は受付時の元画像を使う）は同じで、固定する場所に合わせて経路を変えました。[ImageElementDrawingTests](../../../GLogoTests/Unit/ImageElementDrawingTests.swift) の説明にあった「Model の `draw(in:)` は保存の合成が使う」は今回から当たらないため、説明を直しました（確かめる内容は同じ）。
- **Verification**: GLogoTests は465件中462件成功（失敗1件は既知の性能テスト `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用。追加した14件の分だけ件数が増えた）。UI テストは GLogoUITests 全体の30件が成功しました（実行は33回）。全体の実行のあとに直したのはテストの説明の2か所だけで、その2スイート14件を再実行して成功しました。`git diff --check`（新規ファイルを含む）と、更新した文書の相対リンクを確認しました。アプリのビルドで、変更したファイルに警告はありません。Xcode 27.1、iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormat は未導入のため実行できません。

### 残り

- **第19回**：所有を管理役へ移し、状態を変える側も管理役経由にする（第17回の「残り」のとおり。失効の経路は実装の前の計画で決め、解放された要素の分の回収は次の描画だけに頼らず、キャッシュ自体の解放も直接確かめる）。保存用の複製のセッションも、スナップショットが作って持つ形にする（今は複製が持ち、スナップショットは複製を通して引き当てる）。本番の呼び出し元がなくなった Model の取得・描画の API（`originalImage`・`getFilteredImageForce()`・`draw(in:)`）は、要素から外すか、テストの観察の場所を移すかを決める。
- **第20回**：第17回の「残り」のとおり（削除した要素のキャッシュを解放する時点と、元画像も解放できる条件）。
- 記録のみ：合成でベースの加工が2回走ること（[README](../README.md) の「計画外の対応と残件」）。
- 保留（Codex 合意）：第17回の「残り」のとおり。

## 段階3・第19回：状態を変える側を、エディタの管理役経由に付け替え（2026-11-14）

### 計画と確認した経路

所有の移動と状態を変える側の付け替えを1回で行うと、要素の API を使うテストが大量に変わり（`cachedImage` 116か所、`originalImage` 91か所など）、変更の前後の比較で変わった点を見分けにくくなります。そのため、第17回（受け取る側）・第18回（保存）と同じく、経路の付け替えと所有の移動を分けました（ユーザー・Codex 合意）。回の番号は1つずつ繰り下げます（第17回・第18回の「残り」の第19回・第20回は、それぞれ第20回・第21回にあたる）。

| 回 | 内容 | 挙動 |
| --- | --- | --- |
| 第19回（今回） | 状態を変える側（編集中の切り替え・キャッシュの失効と書き込み・確定の加工・メモリ警告）の外からの呼び出しを、管理役経由に付け替える。失効の経路を決める。所有は移さない | 変えない |
| 第20回 | 所有を移す。Model の中の失効を呼び出し側へ移し、Model の取得・描画・キャッシュの API を外す。保存の範囲が複製のセッションを作る。回収を次の描画に頼らない形と、キャッシュ自体の解放を確かめる | 解放された要素の分を捨てる時点の差だけ |
| 第21回 | 削除した要素のキャッシュを解放する時点を変える（以前の予定の第20回） | 変える |

外から状態を変えていた呼び出しは、次の9経路でした。

| 呼び出し元 | 第18回まで | 第19回 |
| --- | --- | --- |
| 履歴イベント 27種（調整21・フレーム6）と、Revert の巻き戻し | apply／revert の最後の文で `invalidateRenderedImageCache()`（55か所） | 失効させる範囲を返し、履歴が適用・巻き戻しの直後に管理役で失効させる |
| Revert の適用（`ImageElementMetadataRevertUseCase`） | Model の中の失効に加え、`clearRevertImageCaches()` を明示的に呼ぶ（中と重複） | 明示の呼び出しは、イベントの範囲（`.revert`）へ移した |
| フィルターのプリセット（`FilterPresetUseCase`） | `invalidateRenderedImageCache()` 2か所 | 管理役 |
| 編集中の切り替え（`ImageEditingSessionUseCase`。4つの ViewModel が使う） | `startEditing`・`endEditing` | 管理役 |
| エディタ（Revert・AI の結果の適用・Undo・Redo・保存の準備） | `endEditing` 5か所 | 管理役 |
| 描画の更新（`ImageRenderRefreshUseCase`） | 非同期のフル品質の加工、表示画像の書き込み、`endEditing`、トーンカーブの `cachedImage = nil` | 管理役（呼び出しごとに受け取る） |
| 画像調整のパネル（`ImageAdjustmentViewModel`） | 確定の再描画で `cachedImage = nil` | 管理役 |
| メモリ警告（`ImageCacheReleaseUseCase`） | `handleMemoryWarning()`・`previewService` | 管理役 |
| 画像の差し替え・復元・初期値への戻し（Model の中） | `replaceImageSource`・`restoreImageSource`・`resetToOriginal` の中で失効 | 変えない（第20回で呼び出し側へ移す） |

失効の経路は、候補の2つ（Model が通知する形・履歴イベントが範囲を示す形）から、**履歴イベントが範囲を示す形**にしました（ユーザー・Codex 合意）。Model に失効の語彙と管理役への逆向きの参照を残さず、範囲をイベントごとにテストで確かめられるためです。失効の時点は、apply の最後の文から「apply が返った直後」に変わりますが、どちらも同じ同期の呼び出しの中で、描画より前です。27種の失効が最後の文で、あとに読み取りがないことを確認しました。

計画は Codex のレビューで補正しました。

| 補正 | 対応 |
| --- | --- |
| 読み取りと書き込みは、同じ管理役のインスタンスを使う | エディタは両方の Protocol に準拠する1つの値（`ImageRenderSessionManaging`）を受け取り、履歴・編集パネル・ジェスチャー・描画の更新・メモリ警告にその同じ値を渡す。View へ公開する `renderSessions` は読み取り用の型にした。描画の更新は編集パネルより先に作られるため、管理役を持たせず、呼び出しごとに受け取る形にした（別の管理役を作らないため）。テスト側にも、別の管理役を作る互換の入口は足していない |
| Revert の適用・Undo で、失効の範囲を分ける | 適用（Redo を含む）は `.revert`、Undo は `.rendered`。Model の中の失効は残す。履歴の失効はタスクへ遅らせず、適用・巻き戻しの直後に同期で行う。イベントの ID は、履歴が適用したプロジェクトで要素のインスタンスへ解決してから、管理役へ渡す |
| 非同期の描画は、採用の判定と書き込みを分けたままにする | 管理役のフル品質の加工は画像を返すだけにし、キャンセル・世代・編集対象の照合は `ImageRenderRefreshUseCase` に残した。採用すると判定したあとで、書き込みと編集中の終了を管理役に求める。古い結果（新しい予約・描画中の編集）では、どちらも求めないことをテストで確かめた |
| 失効のテストは、27種を網羅する | 27種すべてについて、適用・Undo・Redo のたびに、対象の要素の表示画像だけを失効させることを確かめる（空の既定に落ちたイベントを検出する）。Revert は、範囲の違いと、残すべきキャッシュが残ることを別に確かめる |
| 元画像が nil の保存（第18回の補強） | 最初に、今の振る舞いを固定するテストを足した（単独保存の選定の失敗、強制の合成の失敗、正常なベースと取得できない重ねる画像なら、その画像を描かずに成功） |

### 変更した範囲

- [ImageRenderSessionControlling](../../../GLogo/UseCases/Rendering/ImageRenderSessionControlling.swift)（新規）：状態を変える側の Protocol（MainActor）。編集中の開始・終了、範囲を指定した失効、表示画像の書き込み、フル品質の加工（画像を返すだけ）。読み取り用と合わせた型 `ImageRenderSessionManaging` も置いた。
- `ImageRenderSessionStore`：上の Protocol も実装し、今は要素のセッションへ委譲する。
- 履歴：[ImageRenderInvalidation](../../../GLogo/UseCases/History/ImageRenderInvalidation.swift)（新規。要素の ID と範囲）と、`EditorEvent` の範囲を返す要件（画像の見た目を変えないイベントは空の既定）。[ImageAppearanceEvent](../../../GLogo/UseCases/History/ImageAppearanceEvent.swift)（新規）に27種が準拠し、適用・巻き戻しとも `.rendered` を返す。Revert のイベントは適用が `.revert`、巻き戻しが `.rendered`。差し替えのイベントは、今は Model の中で失効させるため範囲を返さない（第20回で移す）。`EditorHistory` は MainActor になり、管理役を受け取って、適用・巻き戻しの直後に失効させる。
- 呼び出し元：`ImageEditingSessionUseCase`・`FilterPresetUseCase`（管理役を初期化で受け取る）、`ImageRenderRefreshUseCase`（呼び出しごとに受け取る。テスト用のフル品質の加工の差し替えは残した）、`ImageCacheReleaseUseCase`、`ImageElementMetadataRevertUseCase`（明示の失効を外した）、`ImageAdjustmentViewModel`・`ImageFrameViewModel`・`FilterPanelViewModel`・`ElementTransformViewModel`（管理役を受け取る）、`ElementViewModel`（エディタの同じ管理役を渡す）、`EditorViewModel`。
- 変えないもの：Model の中の失効（差し替え・復元・初期値への戻し）、要素の API（テストが観察に使う）、取得と加工の時点と回数、編集中の切り替えの順序、保存、描画の更新の生成（`makeImageRenderRefresh`）。

これで、要素の状態を変える API（`startEditing`・`endEditing`・`cachedImage`・失効の各メソッド・`handleMemoryWarning`・`renderFullQualityImageAsync`）の本番の呼び出し元は、管理役から要素のセッションへの委譲と Model の中だけになりました（Serena と rg で確認）。

`EditorViewModel.swift` は **790 → 807行** です（`ImageElement.swift` は変えていない）。

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。
- **Info**: 失効の範囲を返し忘れた新しい画像のイベントは、空の既定に落ちて、表示画像が古いまま残ります。今の27種と Revert はテストで守り、`EditorEvent` の説明に要件を書きました。
- **Info**: 第19回のあいだ、失効の経路は2つあります（外からの呼び出しは管理役、Model の中の失効は要素自身）。第20回で1つにします。
- **Info**: `EditorViewModel.managedRenderSessions` は、ViewModel が子へ渡すための internal のプロパティで、View からも参照できてしまいます。View は読み取り用の `renderSessions` を使う取り決めで、今の View は使っていません（rg で確認）。
- **Info**: テスト用の偽物の管理役（`RenderSessionSpy`。第17回の `RenderSessionReadingSpy` を改名）は、状態の変更を記録してから、アプリと同じ実装の別のインスタンスへ渡します。今の管理役は状態を持たないため同じ要素のセッションに届きますが、所有を移す第20回で見直します。
- **Info**: `EditorHistory`・`ImageEditingSessionUseCase`・`FilterPresetUseCase`・`ImageCacheReleaseUseCase.releaseCaches` は MainActor になりました（呼び出し元は、すべて MainActor）。
- **Test Coverage**:
  - 最初に足したテスト（今のコードで成功を確かめてから付け替えた）：[SaveSnapshotIntegrationTests](../../../GLogoTests/Integration/SaveSnapshotIntegrationTests.swift) 3件。元画像が nil の要素を、Coordinator 経由で保存したときの結果（単独保存は選定の失敗、強制の合成はベースの加工の失敗、正常なベースと取得できない重ねる画像なら、その画像を描かずに成功）と、取得の回数を固定した。
  - 追加：[ImageRenderInvalidationHistoryTests](../../../GLogoTests/Unit/ImageRenderInvalidationHistoryTests.swift) 4件（27種の適用・Undo・Redo、適用のあとの同期の失効、要素が見つからなければ何もしない、画像以外のイベントは失効させない）。[ImageRenderSessionControlRouteTests](../../../GLogoTests/Integration/ImageRenderSessionControlRouteTests.swift) 9件（ジェスチャー、スライダー、トーンカーブ、フィルターのプリセットのフル品質の確定の順序、古い結果は書き込みも編集中の終了も求めない、Revert の範囲と残すキャッシュ、AI の結果などのイベントの適用、保存の準備、メモリ警告）。
  - 変更：[ImageUndoCacheInvalidationTests](../../../GLogoTests/Unit/ImageUndoCacheInvalidationTests.swift) 2件は、同じイベントと期待値のまま、履歴を通す形にした。組み立ての引数（ImageFrameViewModelTests・ImageEditTokenTests・ImagePreviewDependencyTests・ImageRenderRefreshUseCaseTests）。偽物の管理役を改名し、状態の変更の記録を足した。回の番号の付け替えに合わせて、テストの説明を直した。
  - 変更の前後の比較：コミットしない確認用テストで、22の手順（スライダーの開始・変更・確定、確定の再描画の予約、トーンカーブ、フィルターのプリセットの非同期の確定、Undo・Redo、Revert とその Undo・Redo、ジェスチャー、保存の準備、メモリ警告）について、取得先と描画サービスの呼び出し回数、表示画像のキャッシュの有無、描かれた画像を記録し、変更の前後ですべて一致することを確かめた。
  - 接続漏れを検出できること：コミットしない確認として、15か所を一時的に以前の形へ戻すと（ジェスチャーとスライダーの編集中、トーンカーブの失効、フル品質の加工、確定の書き込みと編集中の終了、プリセットの失効、フィルターのイベントを空の既定へ、Revert の範囲、Undo のあとの編集中の終了、イベントの適用のあとの編集中の終了、保存の準備、メモリ警告、履歴の失効をしない・タスクへ遅らせる、編集パネルへ別の管理役を渡す）、それぞれ対応するテストが失敗することを確かめてから元に戻した。
- **回帰テスト棚卸し**: 期待値を変えたテストはありません。ImageUndoCacheInvalidationTests は、失効をイベントの中から履歴へ移したため、確かめる経路を履歴に変えました（取り決めは「適用・Undo で表示画像が消える」のまま）。
- **Verification**: GLogoTests は481件中478件成功（失敗1件は既知の性能テスト `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用。追加した16件の分だけ件数が増えた）。UI テストは GLogoUITests 全体の30件が成功しました（実行は33回。そのあとの変更は、コメントの回の番号とテスト1件の追加だけ）。`git diff --check`（新規ファイルを含む）と、更新した文書の相対リンクを確認しました。アプリのビルドで、変更したファイルに警告はありません。Xcode 27.1、iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormat は未導入のため実行できません。

### 残り

- **第20回**：所有を管理役へ移す。Model の中の失効（差し替え・復元・初期値への戻し）を、呼び出し側（差し替えのイベント・Revert）の範囲へ移す。Model の取得・描画・キャッシュの API を外し、テストの観察の場所を管理役へ移す。保存の範囲が、複製のセッションを作って持つ。回収の方式（管理役の表と履歴の破棄の直後の回収、要素の解放に合わせた回収など）は、その回の計画で確認用テストを使って決め、次の描画だけに頼らないこと、キャッシュ自体の解放（キャッシュに入れた画像への弱参照など）を直接確かめる。テスト用の偽物の管理役が状態の変更を別の管理役へ渡している形も、そのときに見直す。
- **第21回**：削除した要素のキャッシュを解放する時点（第17回の「残り」の第20回の内容）。
- 保留（Codex 合意）：第17回の「残り」のとおり。

## 段階3・第20回：Model の中の失効の移動と、Model の取得・描画・キャッシュの API の削除（2026-11-15）

### 計画と確認した経路

所有の移動も、テストへの影響の大きさから2回に分けました（ユーザー・Codex 合意）。要素の API を使うテストは約280か所（約35ファイル）あり、この機械的な置き換えと、寿命・回収の変更を混ぜると、変更の前後の比較で変わった点を見分けにくくなるためです。回の番号は、もう1つ繰り下げます。

| 回 | 内容 | 挙動 |
| --- | --- | --- |
| 第20回（今回） | Model の中の失効を、履歴イベントが示す範囲へ移す。Model の取得・描画・キャッシュの API を外し、テストの観察を管理役へ移す。所有は移さない | 変えない |
| 第21回 | 所有を移す（管理役がセッションを作って持つ）。回収の契機、保存の範囲がセッションを作ること、テストの偽物の見直し、基底の描画の入口から画像要素を外すこと | 解放された要素の分を捨てる時点の差だけ |
| 第22回 | 削除した要素のキャッシュを解放する時点を変える（以前の予定の第21回） | 変える |

第21回のセッションの生成と寿命は、計画のときに次の形にすると決めました（実施は第21回）。

| 経路 | 依存を渡す人 | 今 | 移したあと |
| --- | --- | --- | --- |
| 新規（インポート） | Composition Root → `ImageElementFactory` → 要素の初期化 | 要素が初期化でセッションを作って持つ | 要素は依存（取得先・描画サービス）だけを持つ。エディタの管理役が、最初に求められたときに要素の依存でセッションを作り、表で持つ |
| 復元（Decoder） | `ProjectDecodingDependencies` | 同上 | 同上 |
| 複製（`copy()`） | 複製元の依存を引き継ぐ | 新しい空のセッション | 依存だけを引き継ぎ、管理役が最初の要求で空のセッションを作る |
| 保存（`renderCopy()` とスナップショット） | 複製元の依存を引き継ぐ | 複製がセッションを持つ | スナップショットが複製ごとにセッションを作って持ち、元画像を固定する |

管理役の表は、要素のインスタンスをキーにし、要素への弱い参照とセッションを持つ形にします。回収の契機（履歴の操作のたび・メモリ警告）は検証前の候補で、第21回の計画で、履歴の破棄のあとに AI の処理が終わる順序も確かめてから決めます。今の回収の時点は、コミットしない確認用テストで確かめました。履歴の上限と Redo の履歴の破棄の直後に、描画なしで、要素・表示画像・元画像が同期で解放されます。

今回移した失効は、次のとおりです。

| 操作 | 第19回まで（Model の中、この順） | 第20回 |
| --- | --- | --- |
| 差し替え（背景除去・高画質化の適用） | 値の差し替え → 初期値への戻し（`.adjustments`）→ `.all` と共有の描画サービスのリセット | Model は値と配置サイズだけを変える。差し替えのイベントが「ソースの変更」を返し、履歴が適用の直後に `.all` と共有のリセットを1回行う |
| 復元（差し替えの Undo） | 値を戻す → 取得先で元画像を読み直して寸法を計算（キャッシュは使わない）→ `.all` とリセット | 同上（巻き戻しで「ソースの変更」） |
| 初期値への戻し（Revert の適用・Redo） | 値を戻す → `.adjustments` → `.revert`（第19回の `.revert` と重複） | イベントが `.adjustments` と `.revert` を返す（消える範囲の合計は同じ。プロキシは残す） |

値の変更と失効の間にキャッシュを読む処理はありません（差し替えの寸法はローダー、復元の寸法は取得先を直接使う）。共有の描画サービスのリセットは、差し替え・復元1回につき1回のままです。

計画は Codex のレビューで補正しました。

| 補正 | 対応 |
| --- | --- |
| Model を直接呼ぶテストを、一律に履歴経由へ変えない | サイズの計算・ソースの優先順位・編集値の初期化は、Model のテストのまま残した（`ImageElementCopyTests` の差し替え後のサイズなど）。キャッシュの失効を確かめる部分は、管理役のテスト（同じ管理役で範囲の失効を呼ぶ）と、履歴・イベントのテストへ移した。単独の `.adjustments` と、Revert の `.adjustments` と `.revert` は分けて確かめる |
| 保存用の複製は、エディタの管理役で観察しない | スナップショット自体を持ち続け、その範囲から画像を受け取る形にした。観察用のメソッドは具体型だけに足したため、エディタのテストは、エディタが持つ管理役を同じインスタンスのまま具体型として取り出す補助（`sessionStore`。偽物を渡したエディタでは止まる）を使う |
| `draw(in:)` を空にしない | 今の上書きを残した。第21回で、基底の描画の入口から画像要素を外し、画像を受け取らずに描こうとするとコンパイルエラーになる形にする |
| 境界を明記する | 差し替え（キャッシュが空・あり、データが壊れている、Undo で元ファイルを取得できない）、Revert（メタデータの識別子なし・履歴なし・巻き戻しの失敗・見つからない）、共有の描画サービス（自分のサービスだけ、ほかの要素のキャッシュは消さない）、保存（受付のあとのメモリ警告）、回収（上限の直前・Redo できる間は保持、破棄の直後に4種類の画像まで解放）のテストを、変更の前に足して、今のコードで成功することを確かめた。非同期の描画は、既存の `ImageRenderValidityIntegrationTests` が差し替え・Undo・削除のあとの古い結果を確かめているため、同じ管理役で観察する形に移した |
| 「順序」の変異は、失効の時点の値で確かめる | 失効を求めた時点のソースと編集値を記録するテストを足した（差し替え・Undo・Redo、Revert の適用・Undo）。最終の画像が同じかどうかでは判断しない |
| 変異は4種類を毎回検討する | 下の検証に、種類ごとの変異と結果、扱わなかった変異と理由を書いた |

### 変更した範囲

- [ImageRenderInvalidation](../../../GLogo/UseCases/History/ImageRenderInvalidation.swift)：範囲を `Scope`（要素のキャッシュの範囲 `.cache(...)` と、ソースの変更 `.sourceChange`）にした。
- [ImageRenderSessionControlling](../../../GLogo/UseCases/Rendering/ImageRenderSessionControlling.swift)：ソースの変更の失効（`invalidateForSourceChange(of:)`）を足した。`EditorHistory` は範囲の種類で呼び分ける。
- 履歴イベント：差し替えのイベントは適用・巻き戻しとも「ソースの変更」、Revert のイベントの適用は `.adjustments` と `.revert` を返す。`ImageElementMetadataRevertUseCase` は値だけを戻す。
- `ImageElement`：差し替え・復元・初期値への戻しは値と配置サイズだけを変える。`originalImage`・`image`・`cachedImage`・`getFilteredImageForce()`・`renderFullQualityImageAsync()`・`getInstantPreview()`・`startEditing()`／`endEditing()`・`invalidateRenderedImageCache()`・`handleMemoryWarning()`・`clearRevertImageCaches()` を外した。`renderSession`（管理役・保存の範囲・`draw(in:)` が使う）と、依存の `previewService` は第21回まで残る。
- `ImageRenderSessionStore`：テストの観察用に、表示画像のキャッシュを見るだけの口・即時プレビュー・フル品質の加工を足した（Protocol には含めない）。
- 変えないもの：取得・生成・加工の時点と回数、共有の描画サービスのリセットの回数、消える範囲の合計、保存、所有と寿命。

`ImageElement.swift` は **970 → 889行** です。

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。
- **Info**: 管理役（具体型）の観察用のメソッド（表示画像のキャッシュを見るだけの口・即時プレビュー・フル品質の加工）は、本番では使いません。Protocol には含めず、テストはコードと同じインスタンスで呼びます。
- **Info**: テストの互換の入口（`ElementSessionImages`）と `FixedDecodingDependencies.isUsed` は、Model の API を外したため、要素のセッションを直接使います。所有を移す第21回で見直します。
- **Info**: Model の差し替え・復元・初期値への戻しは、キャッシュに触れなくなりました。本番の呼び出し元は履歴イベントだけで、イベントが範囲を示します。履歴を通さずに Model のこれらを呼ぶ新しいコードは、失効も自分で求める必要があります（各メソッドの説明に書いた）。
- **Test Coverage**:
  - 変更の前に足したテスト（今のコードで成功を確かめてから移した）11件のうち9件：[ImageRenderSessionReclamationTests](../../../GLogoTests/Integration/ImageRenderSessionReclamationTests.swift) 2件（上限の直前・Redo できる間は保持し、破棄の直後に要素と4種類のキャッシュの画像が解放される。事前に4種類がキャッシュにあることも確かめ、描画を挟まない）。[ImageSourceChangeEdgeTests](../../../GLogoTests/Integration/ImageSourceChangeEdgeTests.swift) 6件（差し替え・Undo・Redo でキャッシュが空・ありのどちらも以前の画像を残さず、リセットは1回ずつ。壊れたデータ。Undo で元ファイルを取得できない。自分の描画サービスだけをリセットし、ほかの要素のキャッシュは消さない。Revert はメタデータの識別子なし・履歴なし・巻き戻しの失敗・見つからないでも失効し、プロキシと共有の描画サービスのキャッシュは残す。Revert の適用・Undo・Redo のどれでも、共有の描画サービスをリセットしない）。SaveSnapshotIntegrationTests 1件（受付のあとのメモリ警告でも、固定した画像で保存する）。
  - 変更と同時に足したテスト2件：[ImageRenderInvalidationHistoryTests](../../../GLogoTests/Unit/ImageRenderInvalidationHistoryTests.swift)（差し替えのイベントは適用・Undo・Redo の直後にソースの変更を1回だけ求め、その時点でソースと編集値はもう変わっている。Revert の適用・Undo・Redo の範囲と、その時点の編集値）。
  - 移行：33ファイルのテストを、コードと同じ管理役（エディタのテストは `sessionStore`、単独の要素のテストはテストごとに1つ、偽物を使うテストは偽物の中の管理役）で観察する形にした。保存用の複製は、スナップショットの範囲から観察する。期待値を変えたのは、Revert の経路のテストの「適用・Redo で求める失効」（`.revert` だけ → `.adjustments` と `.revert`。合意した範囲の移動による）だけ。
  - 変更の前後の比較：コミットしない確認用テストで、9つの手順（差し替えとその Undo・Redo、Revert とその Undo・Redo、2回目の差し替え、Undo を2回）について、取得・生成・加工・共有のリセットの回数と、対象とほかの要素の表示画像のキャッシュの有無を記録し、すべて一致した。
  - 変異確認（自分で実行し、13件すべて検出）：抜け（差し替えの適用で失効を示さない・巻き戻しで示さない、Revert で `.adjustments` を示さない）、消し過ぎ（Revert を `.all` に広げる、ソースの変更でリセットを2回、Revert でも共有をリセット、プロジェクトのすべての画像要素を失効）、取り違え（ID ではなく最後の画像要素を失効）、順序（適用の前に失効）の9件と、下の補強のあとに当てた4件。どれも、狙った振る舞いの違い（期待した失効・回数・失効の時点の値）でテストが失敗することをログで確かめた。
  - 実装レビューでの補強（Codex、2026-11-15）：最初の9件のあと、Codex の確認で、履歴が Revert の失効（`.revert`）を解決するときに、共有の描画サービスのリセットだけを足す変異（プロキシは消さない）が、関連9スイート72件をすべて通ることが分かった。上の「Revert でも共有をリセット」が検出されたのは、プロキシが消えるのを見ていたためで、リセットの回数を見ていたためではなかった。そこで、Revert の境界のテストにリセットが0回のままであることの確認を足し、Revert の適用・Undo・Redo を履歴で通すテストを足した（どちらも、変更の前のコードで成功することを、別のディレクトリに展開したテストのツリーで確かめた）。補強のあとに当てた変異（関連10スイート77件）：

    | 変異 | 種類 | 検出したテスト |
    | --- | --- | --- |
    | 履歴が `.revert` を解決するときに、共有だけをリセット（Codex の変異と同じ層） | 消し過ぎ | 今回足した確認だけ（境界の4条件と、適用・Undo・Redo の3段階）。補強の前は生き残っていた |
    | セッションの `.revert` の失効で、共有もリセット | 消し過ぎ | 今回足した確認と、管理役の単体テスト（`ImageElementCacheTests` の Revert の失効） |
    | Revert の Undo で、ソースの変更まで求める | 消し過ぎ | 今回足したテスト（Undo・Redo）と、履歴・経路のテスト（求める範囲と、元画像・プロキシ・プレビュー元画像の再取得の回数） |
    | 表示画像だけの失効（Revert の Undo など）で、共有もリセット | 消し過ぎ | 今回足したテスト（Undo・Redo）と、`ImageElementCacheTests` の表示画像の失効 |

    扱わなかった変異：保存用の画像をエディタの管理役から受け取る（MainActor の管理役は保存のタスクから同期に呼べず、コンパイルで防がれる）、観察先を別の管理役にする（今の管理役は状態を持たず、挙動が変わらない。第21回で検出できることを確かめる）。
- **回帰テスト棚卸し**: ImageElementCacheTests の差し替え・復元・初期値への戻しは「Model は値だけを変え、キャッシュには触れない」ことと、管理役で範囲を失効させたあとの再取得に分けました（回数の期待値は同じ）。SaveProjectSnapshotTests の2件の独立は、複製の表示画像のキャッシュの有無を加工の回数で見分ける形にしました。複製へメモリ警告の失効をかける確認は、本番にない操作で、外した Model の API でしかできなかったため外しました（書き込みの独立と、固定した元画像の同一性は確かめ続ける）。ImageRenderSessionStoreTests は、Model の API と比べる部分を外し、Model の `draw(in:)`（第21回まで残る）との回数の比較だけを残しました。同じファイルで保存用の複製をエディタの管理役で観察していたテストは、同じ ID を持つ別の通常の要素のキャッシュを取り違えないことの確認に置き換えました（Codex の実装レビューの Info。保存用の複製の独立は、保存の範囲を通した `SaveProjectSnapshotTests` の2件で確かめる）。
- **Verification**: GLogoTests は492件中488件成功（スキップ2件は実機専用。追加した11件の分だけ件数が増えた）。失敗2件は性能テストで、性能テストだけを再実行すると、失敗は既知の `testPreviewLatencySDR_4K_P95` の1件だけでした（HDR のプレビューは再実行で成功）。UI テストは GLogoUITests 全体の30件が成功しました（実行は33回。実装レビューでの補強はテストと文書だけで、アプリのコードは UI テストを回したときから変えていないため、補強のあとには回していない）。アプリのビルドとテストのビルドで、今回変えたファイルに警告はありません。`git diff --check`（新規ファイルを含む）と、更新した文書の相対リンクを確認しました。Xcode 27.1、iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormat は未導入のため実行できません。

### 残り

- **第21回**：所有を管理役へ移す（上の表）。回収の契機は、履歴の破棄のあとに AI の処理が終わる順序と、次の操作が来ない場合の保持の期間を確認用テストで確かめてから決める。保存の範囲が複製のセッションを作る。テストの偽物（`RenderSessionSpy`）を、エディタに渡す唯一の管理役の包みにする。基底の描画の入口から画像要素を外す（`draw(in:)` の上書きを外す）。テストの互換の入口（`ElementSessionImages`）と `FixedDecodingDependencies.isUsed` が要素のセッションを直接使っている形を見直す。第20回で挙動が変わらなかった変異（観察先を別の管理役にする）を、所有を移したあとで検出できることを確かめる。
- **第22回**：削除した要素のキャッシュを解放する時点（第17回の「残り」の第20回の内容）。
- 保留（Codex 合意）：第17回の「残り」のとおり。

## 段階3・第21回：描画のセッションの所有の移動（2026-11-15）

### 計画と確認した寿命

描画のセッション（取得・描画・キャッシュ・編集中の状態）を、要素が持つ形から、エディタの管理役（`ImageRenderSessionStore`）が要素ごとに作って持つ形へ移しました。保存用の複製のセッションは、保存の範囲（`SaveProjectSnapshot`）が作って持ちます。要素は取得先と描画サービスの依存だけを持ちます。挙動の差は「解放された要素のキャッシュを捨てる時点」だけです（前の計画で合意した範囲）。

回収の契機は、計画の段階で3つの案を比べ、案1にしました（ユーザー・Codex 合意）。

| 案 | 内容 | 判断 |
| --- | --- | --- |
| 1 | 管理役の表（要素のインスタンスがキー。要素は弱く持つ）と、履歴の操作の最後・メモリ警告での回収 | 採用 |
| 2 | 1 に加えて、AI の要求の終わりでも回収する | 採らない。AI のほかにも要素を持つ処理があり（下の表）、AI だけでは差が消えない |
| 3 | 要素に中身の見えない置き場を持たせ、寿命を要素に結びつける | 採らない。Model がキャッシュの置き場を持ち続け、管理役ごとの独立も、削除した要素の分の扱い（第22回）もできない |

コミットしない確認用テストで、今の（移す前の）寿命を確かめました。どの経路も、削除が履歴の上限で押し出されたあと、処理が要素を持つあいだは要素と4種類のキャッシュの画像が生きていて、処理の終わりに、履歴の操作なしで解放されました。

| 経路 | 押し出したあと | 解放される時点 |
| --- | --- | --- |
| AI（背景除去・高画質化） | 生きている（タスクと `aiRequest` が要素を持つ） | 処理のタスクが閉じた直後（処理中を示すフラグが下りた瞬間は、まだ生きている） |
| フル品質の描画（取り消し後も） | 生きている（実行中のタスクが要素を持つ） | 描画が戻った直後 |
| 間引きの予約（取り消し後も） | 生きている（取り消した予約も、期限まで列に残る） | 予約の期限のあと |
| フィルターのサムネイルの生成 | 生きている（生成の待ちのあいだ） | 生成が戻った直後 |

案1では、これらの処理が終わって要素が解放されても、セッションとキャッシュの画像は、次の回収の契機（履歴の操作・メモリ警告）まで残ります。**時間の上限はありません**（操作もメモリ警告も来なければ残り続ける）。履歴の上限による押し出し・Redo の履歴の破棄・全消去では、今と同じく、その操作の中で同期に解放されます。

計画は Codex のレビューで補正しました。

| 補正 | 対応 |
| --- | --- |
| 遅れて解放される経路を AI 以外にも広げて確かめる | フル品質の描画・間引きの予約・サムネイルの生成も確認用テストで確かめ（上の表）、時間の上限がないことを記録した。4つの経路とも、終わったあとの次の契機（履歴の操作・メモリ警告）の直後に4種類の画像まで解放されることを、移す前に足したテストで確かめる（終わってから契機までの間は固定しない） |
| 「保存で管理役の表もキャッシュも変わらない」を限定する | 契約を3つに分けた。受付では、エディタで未取得の元画像の取得とキャッシュ（と、その要素のセッションの登録）を認める。保存用の複製はエディタの表に登録しない。受付のあとの保存処理はエディタ側の取得・表示画像のキャッシュ・編集中の状態を変えない。未取得・取得済み・編集中の3つの状態で確かめた |
| Protocol の採用漏れで「何も描かれない」のを防ぐ | キャンバスの描き方と、本番と同じ保存の範囲を通した合成で、テキストと図形がそれぞれ枠の中に描かれることを確かめるテストを、移す前に足した。採用を片方ずつ外す変異で、両方の経路で検出されることを確かめた |
| 回収の観察で不具合を隠さない | 件数と有無の確認は、回収もセッションの生成もしない口（`registeredSessionCount`・`hasSession(for:)`）で行う。履歴の上限・Redo の破棄に加え、全消去と管理役（エディタ）自身の解放も確かめた。テストの補助で管理役を渡し直す箇所は、取得の回数だけでなく、キャッシュ済みの画像や編集中の状態に頼っていないかも確かめた（下の検証） |

### 変更した範囲

- [ImageRenderSessionStore](../../../GLogo/UseCases/Rendering/ImageRenderSessionStore.swift)：要素のインスタンスをキーにした表（要素の弱い参照とセッション）。引くときは、弱い参照が同じ要素を指すかを確かめる（解放された要素の識別子が別のインスタンスに使い回されても、古いセッションを返さない）。回収（`reclaimReleasedSessions()`）と、テスト用の観察の口（件数・有無。回収も生成もしない）。描画サービスの引き当ては、要素の依存を返し、セッションを作らない。
- [ImageRenderSessionControlling](../../../GLogo/UseCases/Rendering/ImageRenderSessionControlling.swift)：回収のメソッドを足した。
- [EditorHistory](../../../GLogo/UseCases/History/EditorHistory.swift)：適用・Undo・Redo・全消去の最後に回収を求める（上限の切り捨てと Redo の履歴の破棄のあと）。
- [ImageCacheReleaseUseCase](../../../GLogo/UseCases/Rendering/ImageCacheReleaseUseCase.swift)：メモリ警告の最初に回収を求める。削除したが履歴に残る要素の分は、従来どおり対象にしない（第22回）。
- [SaveProjectSnapshot](../../../GLogo/UseCases/SaveImage/SaveProjectSnapshot.swift)：複製ごとにセッションを作って持ち、元画像を固定する。複製はエディタの表に登録しない。
- [ImageElement](../../../GLogo/Models/ImageElement.swift)：`renderSession` を外し、取得先と描画サービスを自分で持つ。`draw(in:)` の上書きを外した（画像は `draw(in:image:)` で、受け取った画像で描く）。
- [ContextDrawable](../../../GLogo/Models/ContextDrawable.swift)（新規）：自分の値で描ける要素の描画の入口。`TextElement`・`ShapeElement` が採用し、基底の `LogoElement.draw(in:)`（未実装なら止まる）を外した。呼び出し元（保存の合成・キャンバスの描き方）は型を確かめてから呼ぶ。
- テストの補助：`ElementSessionImages` は補助の中で要素ごとにセッションを作る（呼び出しごとに作るため、キャッシュは呼び出しをまたがない）。`FixedDecodingDependencies.isUsed` は使い捨てのセッションで取得する。`RenderSessionSpy` は、中に持つ唯一の管理役（`forwarding`）へ状態の変更と回収を渡し、回収の回数を記録する。
- 変えないもの：取得・生成・加工の時点と回数、失効の範囲、共有の描画サービスのリセットの回数、保存の受付と保存処理、履歴の操作での解放の時点、メモリ警告で消す範囲。

`ImageElement.swift` は **889 → 882行** です。

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。
- **Info**: 上の「時間の上限がない」保持は、合意した挙動の差として記録した（下の「残り」）。
- **Info**: 既存の保存の回帰テスト（`SavePipelineRegressionTests` の `testMakeCompositeImage_CropsToBaseImageBoundsAndDrawsOverlay`）は、テキストの採用を外す変異でも成功した。合成の画素がベース画像と違うことしか見ておらず、ベース画像の加工だけでも違いが出るため。テキストと図形の描画は、今回足した `TextShapeDrawingTests` で守る（既存のテストは変えていない）。
- **Info**: `LogoElement` の未知のサブクラスは、以前は基底の `draw(in:)` で止まり、今は描かれない。今あるサブクラスは画像・テキスト・図形の3つだけ。
- **Test Coverage**:
  - 変更の前に足したテスト（今のコードで成功を確かめてから移した）7件：[ImageRenderSessionReclamationTests](../../../GLogoTests/Integration/ImageRenderSessionReclamationTests.swift) 4件（AI の3種類・フル品質の描画・間引きの予約・サムネイルの生成の途中で削除が押し出されても処理が終わるまでは持ち、終わったあとの次の契機の直後に4種類の画像まで解放する。契機は、新しい操作・Undo・Redo・メモリ警告を1つずつ試す。Undo・Redo では新しい操作を記録せず、Redo の準備の Undo は処理が終わる前に済ませる。メモリ警告は、エディタの既定の描画サービスの解放（回収と要素のキャッシュの解放のあと）を待ってから確かめる）。[TextShapeDrawingTests](../../../GLogoTests/Unit/TextShapeDrawingTests.swift) 2件（キャンバスと保存の合成で、テキストと図形が描かれる）。[SaveProjectSnapshotTests](../../../GLogoTests/Unit/SaveProjectSnapshotTests.swift) 1件（受付と保存処理の契約。未取得・取得済み・編集中）。
  - 変更と同時に足したテスト5件：[ImageRenderSessionStoreTests](../../../GLogoTests/Unit/ImageRenderSessionStoreTests.swift) 3件（別の管理役とは取得・キャッシュ・編集中の状態を共有しない、回収は解放された要素の分だけを画像ごと捨てる、管理役の解放でキャッシュの画像も解放される）。ImageRenderSessionReclamationTests 2件（履歴の全消去、エディタの解放）。既存の回収のテスト2件と、非同期の4経路の契機の直後、保存の契約のテストに、表の件数・有無の確認（回収も生成もしない口）を足した。
  - 外したテスト1件：`ImageRenderSessionStoreTests` の Model の `draw(in:)` との回数の比較（比べる相手を外したため）。`ImageElementDrawingTests` の Model の経路の確認も外した（キャンバスの描き方と削除エフェクトの確認は残る）。
  - 管理役を渡し直すテストの確認（補正4）：保存の互換の入口（新しい管理役を渡す4つ）と SaveSnapshotIntegrationTests の2か所、`ElementSessionImages` を使う6ファイル、AI・履歴のテストで別の管理役を渡す2か所、使い捨ての管理役で1回だけ問い合わせる4か所を読み、どれも、エディタ側のキャッシュ済みの画像や編集中の状態に頼っていないことを確かめた。偽物の管理役を使うテストは、キャッシュを偽物の中の管理役で観察している。所有だけを移した段階の全体テストでも、期待値を変える必要のあるテストはなかった。
  - 変異確認（自分で実行し、13件すべて検出。Undo・Redo の2件は下の補強のあとに当てた）：

    | 変異 | 種類 | 検出したテスト |
    | --- | --- | --- |
    | テキストの `ContextDrawable` の採用を外す | 抜け | TextShapeDrawingTests の2件（キャンバス・保存の合成）だけ |
    | 図形の採用を外す | 抜け | 同上 |
    | 履歴の適用の最後で回収しない | 抜け | 回収のテスト（上限・Redo の破棄・非同期の4経路の「新しい操作」） |
    | Undo の最後で回収しない | 抜け | 非同期の4経路の「Undo」だけ（補強の前は生き残っていた） |
    | Redo の最後で回収しない | 抜け | 非同期の4経路の「Redo」だけ（同上） |
    | メモリ警告で回収しない | 抜け | 非同期の4経路の「メモリ警告」（補強のあとの待ち方でも検出） |
    | 保存の範囲が受付で元画像を固定しない | 抜け | 保存の範囲・保存の結合テストなど12件 |
    | 回収で生きている要素の分も捨てる | 消し過ぎ | 回収・寿命・経路のテストなど12件 |
    | 表を要素の ID で引く | 取り違え | 同じ ID の別の要素のテストと、復元の独立のテスト |
    | 引くときに同じ要素かを確かめない | 取り違え | `ImageSourceIsolationTests` の2件（ループの中で作っては解放する複製が識別子を使い回し、前の複製のキャッシュを返した） |
    | 保存用の複製をエディタの表に登録する | 取り違え | 保存の契約のテスト（表の有無・件数）と、受付の問い合わせの回数のテストなど8件 |
    | 上限の切り捨て・Redo の破棄より前に回収する | 順序 | 上限・Redo の破棄の回収のテスト |
    | 履歴の失効と回収を、エディタとは別の管理役へ求める（第20回で検出できなかった観察先の取り違え） | 取り違え | 経路・回収・画像ソースの変更のテストなど12件 |

    どれも、狙った振る舞いの違い（解放の有無・表の件数・取得の回数・描かれた画素）でテストが失敗することをログで確かめた。
  - 実装レビューでの補強（Codex、2026-11-16）：Codex の確認で、履歴の Undo・Redo の最後の回収の呼び出し2か所を外す変異が、関連9スイート59件をすべて通ることが分かった。非同期の4経路のテストの「履歴の操作」の契機が新しい操作の記録だけで、その最後の回収が Undo・Redo の抜けを隠していたため。そこで契機を新しい操作・Undo・Redo・メモリ警告の4つに分けて1つずつ試し、Undo・Redo では新しい操作を記録しない形にした（Redo の準備の Undo は、処理が終わる前に済ませる。この Undo の回収では、要素がまだ処理に持たれているため何も解放されない）。所有を移すコミットでは、契機の直後に表の項目が消えていることも確かめる（件数の口は所有の移動で足したため、テストを先に足すコミットには含めない）。メモリ警告は、決まった回数だけ譲って待っていた形を、エディタの既定の描画サービスの解放（回収と要素のキャッシュの解放のあとに呼ばれる）を待つ形にした（Codex の Info。不安定な失敗は観測していない）。テストを先に足すコミットの版は、変更の前のコードと、描画の入口を整理した段階で成功することを、別のディレクトリに展開したツリーで確かめた。補強のあとに当てた変異（関連4スイート28件）では、Undo の回収を外す・Redo の回収を外す・メモリ警告で回収しない変異が、それぞれ該当する契機の6回の試行（AI の3種類・フル品質の描画・間引きの予約・サムネイルの生成）だけで、4種類の画像と表の項目が残って失敗した。両方を外す変異（Codex の変異と同じ）は、Undo と Redo の12回で失敗した。
- **Verification**: GLogoTests は503件中500件成功（失敗1件は既知の性能テスト `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用）。UI テストは GLogoUITests 全体の30件が成功しました（実行は33回）。実装レビューの補強（2026-11-16）のあとも GLogoTests 全体を再実行し、同じ結果でした（UI テストは、補強がテストだけの変更のため再実行していない）。アプリのビルドとテストのビルドで、今回変えたファイルに警告はありません。Xcode 27.1、iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormat は未導入のため実行できません。

### 残り

- **第22回**：削除した要素のキャッシュを解放する時点（第17回の「残り」の第20回の内容）。管理役が表で全要素のセッションを持つようになったため、メモリ警告のとき、プロジェクトにない要素（履歴が持つ要素）の分も対象にできる。元画像まで消すと再取得が必要になる条件は、そのときに判断する。→ 第22回で扱った（下の節）。
- 非同期の処理が終わって解放された要素のセッションは、次の回収の契機まで残り、時間の上限がない（上の表）。上限を設けるか（回収の契機を足すか）は、第22回で、削除した要素の扱いとあわせて判断する。→ 第22回で、上限は設けないと判断した（下の節）。
- Model に残る具体型の参照（寸法の取得・URL の読み直し・`ImageElementRenderer` による描画・背景画像）と、要素が持つ依存の型（UseCases の Protocol）は残る。
- 保留（Codex 合意）：第17回の「残り」のとおり。

## 段階3・第22回：メモリ警告での、プロジェクトにない要素のキャッシュの解放（2026-11-16）

### 計画と判断

第16回の計画で見つけた「削除した画像要素のキャッシュ（フル解像度の画像を含む）が、履歴に残るあいだ解放されず、メモリ警告でも対象にならない」を扱いました。第21回で管理役が要素ごとのセッションを表で持つようになったため、メモリ警告のときに、表にある生きている要素のうちプロジェクトにない要素（削除して履歴が持つ要素・Redo の履歴が持つ要素・非同期の処理だけが持つ要素）も解放の対象にしました。

| 判断 | 内容 |
| --- | --- |
| いつ解放するか | メモリ警告のときだけ（2026-11-10 にユーザー・Codex と合意した方向）。削除・Undo の時点ですぐ解放する案は、削除の Undo のたびに元画像のデコード・プロキシの生成・加工をやり直すことになるため採らない |
| どこまで解放するか | 下の表。取り直して同じ画像に戻ると言えるかで分ける |
| 非同期の処理のあとの保持の上限 | 設けない（ユーザー・Codex 合意）。ただし、メモリ不足のときに安全だとは保証しない（下の「残り」） |

| 要素 | 消す範囲 | 理由 |
| --- | --- | --- |
| プロジェクトにある要素 | 4種類すべて（`.all`。今までどおり） | 次の描画で取り直す |
| プロジェクトにない要素で、データだけを持ち、元画像がキャッシュにある | 4種類すべて（`.all`） | データは読み直しても同じ画像になる。元画像が取れる間のプロキシは、取得先が元画像から作る |
| プロジェクトにない要素で、パス・URL・ファイル名を持つ（データも持つ場合を含む） | 表示画像とプレビュー元画像だけ（`.adjustments`）。元画像とプロキシは残す | 取得先はファイルを読み直し、これらをデータより先に使う。ファイル名にも絶対パスが入りうる（`UIImage(named:)` は絶対パスも読む）。後の Undo までにファイルが変わる・消えると、同じ画像に戻らない |
| プロジェクトにない要素で、元画像がキャッシュにない | 同上 | 取れたプロキシは、取得先が外部のプロキシのファイル（識別子・ファイル名・パスから引く）から読んだものかもしれない |

アプリの取り込み・切り抜き・AI の結果での差し替えは、どれもデータを持つ要素を作ります。パス・URL・ファイル名の要素は保存データの復元（Decoder）でしか作られず、復元は今のアプリから呼ばれていません。判定のために元画像を取得・デコードはしません（メモリ警告の処理の中でメモリを使わないため、取得もセッションの生成もしない口を足した）。削除エフェクトは、削除の直前に要素を独立した画像へ描き出して持つため、あとでキャッシュを消しても影響しません。

計画は Codex のレビューで補正しました。

| 補正 | 対応 |
| --- | --- |
| ファイル名は同梱の画像に限らない（既存の `ImageSourceResolverTests` は、ファイル名に一時ファイルの絶対パスを渡して読む） | ファイル名のソースも、元画像とプロキシを残す範囲にした。絶対パスのファイル名で、ファイルを変更・削除してから Undo するテストを足した |
| 元画像がなくプロキシだけ取れる場合を分ける | 元画像がキャッシュにない要素は、データを持っていてもプロキシを残す。判定は、取得・生成をしない口（`hasCachedOriginalImage(of:)`）で行う |
| 処理の途中の警告を試す | 処理の開始 → 削除と履歴からの押し出し → メモリ警告 → 処理の完了 の順で、AI の3種類・フル品質の描画・間引きの予約・サムネイルの生成を確かめた。警告の直後に管理役のキャッシュが空になり、完了した古い結果を書き戻さない。処理自身が持つ画像と区別するため、弱参照ではなく管理役のキャッシュの中身で見る |
| 「残るのはメモリに余裕がある間だけ」とは言えない | 確かめたのは「警告を受けたら回収し、プロジェクトにない要素のキャッシュも消す」ことまで。Codex が示した Apple の説明のとおり、急なメモリの要求では、警告が届く前にアプリが終了されることがある。上限なしを選び、警告の前のメモリ不足まで防ぐ保証はないと記録した（下の「残り」と README の残件） |

### 変更した範囲

- [ImageCacheReleaseUseCase](../../../GLogo/UseCases/Rendering/ImageCacheReleaseUseCase.swift)：回収 → プロジェクトの要素（`.all`）→ 表にあるプロジェクトにない要素（範囲は上の表）→ 描画サービス（プロジェクトにない要素のものも重複なく）の順にした。プロジェクトにあるかは ID ではなくインスタンスで見分ける。
- [ImageRenderSessionControlling](../../../GLogo/UseCases/Rendering/ImageRenderSessionControlling.swift)：`registeredElements`（セッションを持つ生きている要素。順序は決まっていない）と `hasCachedOriginalImage(of:)` を足した。どちらも取得・生成・回収をしない。
- [ImageRenderSessionStore](../../../GLogo/UseCases/Rendering/ImageRenderSessionStore.swift)：上の2つと、テストの観察の口 `cachedImages(of:)`（キャッシュの中身。セッションがなければ nil）。表を引くだけの内部の口を分けた。
- [ImageRenderSession](../../../GLogo/UseCases/Rendering/ImageRenderSession.swift)：キャッシュの中身を返す `cachedImages`（取得も生成もしない）。
- [ImageSourceResolving](../../../GLogo/UseCases/Storage/ImageSourceResolving.swift)：編集用画像は、元画像が取れるときはそこから作る、という前提を説明に書いた（解放の判定がこれに頼るため）。
- テストの補助：`MemoryWarningSignal` を回収のテストから共通のファイルへ移し、警告を送って処理の終わりまで待つ口を持たせた。`RenderSessionSpy` は、表の要素を中の管理役から返し、元画像の有無の問い合わせを記録して中の管理役へ渡す。
- 変えないもの：プロジェクトの要素の解放の範囲、履歴の操作での回収、削除エフェクト、保存。

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。
- **Info**: プロジェクトにない要素のうち、パス・URL・ファイル名を持つものと、元画像がキャッシュにないものは、メモリ警告でも元画像とプロキシが残る（同じ画像に戻ることを優先した）。ファイルを参照する要素は、アプリの操作では生まれない（保存データの復元でだけ作られ、復元は今のアプリから呼ばれていない）。元画像がキャッシュにない状態は、データの要素でも、メモリ警告や Revert（元画像を失効させる）のあとに生じる。そのときは、キャッシュにあるプロキシを残す。
- **Info**: 判定は、取得先が「元画像が取れるときは編集用画像をそこから作る」ことに頼る（今の取得先は `ImageAssetRepository` を通してそうなっている）。別の取得先を作るときは、この判定を見直す。
- **Info**: メモリ警告のあとの削除の Undo は、データの要素では元画像のデコード・プロキシの生成・加工をやり直す（プロジェクトにある要素がメモリ警告のあとに受けているのと同じ）。
- **Test Coverage**:
  - 変更の前に足したテスト（今のコードで成功を確かめてから変えた）3件：[ImageRenderSessionLifetimeTests](../../../GLogoTests/Integration/ImageRenderSessionLifetimeTests.swift)。データの要素は、削除 → メモリ警告 → Undo のあとも同じ色で表示する。パス・ファイル URL・絶対パスのファイル名の要素（データを持たない・持つの両方）は、メモリ警告のあとにファイルを変更・削除しても、Undo では削除の前の元画像で表示する（12通り）。元画像がなくプロキシだけ取れる要素は、Undo でプロキシを取り直さない。
  - 変更と同時に足したテスト13件：[ImageCacheReleaseUseCaseTests](../../../GLogoTests/Unit/ImageCacheReleaseUseCaseTests.swift) 6件（データの要素は4種類とも消す、ファイルを参照する要素は元画像とプロキシを残す（4種類の参照 × データの有無）、元画像がない要素はプロキシを残す、プロジェクトの要素はソースによらず4種類とも消す、同じ ID の別のインスタンスはプロジェクトにない要素として扱う、プロジェクトにない要素の描画サービスも1回だけ解放する）。[ImageRenderSessionStoreTests](../../../GLogoTests/Unit/ImageRenderSessionStoreTests.swift) 2件（列挙は生きている要素だけを返し、回収も生成もしない。元画像の有無は取得も生成もせずに答える）。[ImageRenderSessionReclamationTests](../../../GLogoTests/Integration/ImageRenderSessionReclamationTests.swift) 4件（非同期の4経路の途中の警告）。[ImageRenderSessionControlRouteTests](../../../GLogoTests/Integration/ImageRenderSessionControlRouteTests.swift) 1件（プロジェクトにない要素も管理役を通して範囲を決める）。
  - 期待値を変えたテスト：`ImageRenderSessionLifetimeTests` のメモリ警告のテストを、削除した要素のキャッシュも消える形にした（`test_memoryWarning_keepsDeletedElementCache` → `test_memoryWarning_releasesDeletedElementCache`。警告の前に4種類がキャッシュにあることも確かめる）。`ImagePreviewDependencyTests` の `test_cacheRelease_resetsEachUsedServiceOnce` の後半（要素を渡さない解放は要素のサービスを解放しない）は、表に残る生きている要素がプロジェクトにない要素として対象になったため、表が空の管理役で確かめる形にした。
  - 変異確認（自分で実行。11件のうち10件を検出、1件は観察できない）：

    | 変異 | 種類 | 検出したテスト |
    | --- | --- | --- |
    | プロジェクトにない要素を失効させない | 抜け | 解放の UseCase・寿命・回収（非同期の4経路の途中の警告）・経路のテストなど10件 |
    | プロジェクトにない要素の描画サービスを解放しない | 抜け | 解放の UseCase のサービスのテストと、経路のテスト |
    | パス・URL を持つ要素も元画像まで消す | 消し過ぎ | 解放の UseCase のファイル参照のテスト（データあり）と、寿命のテストのパス・ファイル URL（データあり）の変更・削除 |
    | ファイル名（絶対パスが入りうる）を同梱の画像とみなして元画像まで消す（Codex の補正1） | 消し過ぎ | 解放の UseCase のファイル参照のテスト（データあり）。寿命のテストでは違いが出ない（下の注） |
    | 元画像がキャッシュにない（プロキシだけ）状態も消す（Codex の補正2） | 消し過ぎ | 解放の UseCase の元画像がないテスト、寿命のプロキシだけのテスト、経路のテスト |
    | データの要素も表示画像とプレビュー元画像だけにする | 取り違え（消し足りない） | 解放の UseCase・寿命・回収（4経路）・経路のテスト |
    | プロジェクトにあるかを ID で見分ける | 取り違え | 解放の UseCase の同じ ID のテスト |
    | プロジェクトの要素にも、プロジェクトにない要素の範囲を使う | 取り違え | 解放の UseCase のテスト2件（プロジェクトの要素・同じ ID）と、経路のテスト2件 |
    | 判定のために元画像を取得する | 取り違え | 管理役の元画像の有無のテスト（取得の回数） |
    | 列挙で、解放された要素の分を回収する | 取り違え | 管理役の列挙のテスト（表の件数） |
    | 回収を、プロジェクトにない要素の失効のあとにする | 順序 | 観察できない（列挙は生きている要素だけを返し、同じ同期の呼び出しの中なので、範囲を決める要素が変わらない） |

    「パス・URL」と「ファイル名」の2件は、最初のテストでは生き残った。テストの要素がファイルの参照だけでデータを持たず、判定の「データを持つ」の条件で先に残す側に落ちていたため。データとファイルの参照の両方を持つ要素（保存データの復元では両方のキーが入りうる）を足して検出できるようにした。あわせて、寿命のテストが1つの組み合わせの失敗で止まり、後の組み合わせを試していなかったため、表示の確認は失敗を記録して次へ進む形にした。寿命のテストの絶対パスのファイル名の組み合わせは、`UIImage(named:)` がシステムのキャッシュから前の画像を返すため、元画像まで消しても違いが出ない。判定は解放の UseCase のテストで守る。どれも、狙った振る舞いの違い（残す・消すキャッシュ、取得の回数、表示の色、表の件数）でテストが失敗することをログで確かめた。
- **Verification**: GLogoTests は519件中516件成功（失敗1件は既知の性能テスト `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用）。 UI テストは GLogoUITests 全体の30件が成功しました（実行は33回）。 テスト先行のツリーは、別のディレクトリに展開して、変更の前のコードで寿命と回収のテストが成功することを確かめた。アプリのビルドとテストのビルドで、今回変えたファイルに警告はありません。Xcode 27.1、iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormat は未導入のため実行できません。

### 残り

- 非同期の処理のあとの保持に上限を設けないことを選んだ。メモリ警告では、解放された要素の分を最初に回収し、生きているプロジェクトにない要素のキャッシュも消す。ただし、確かめたのは警告を受けたときの動きまでで、急なメモリの要求で警告が届く前にアプリが終了される場合までは防げない（保証しない）。
- プロジェクトにない要素のうち、ファイルを参照するものと元画像がキャッシュにないものは、メモリ警告でも元画像とプロキシを残す。プロジェクトにある要素は、ファイルを参照していても今までどおり元画像まで消す（次の描画で読み直す）。復元をアプリから使うようにするときに、あわせて見直す。
- Model に残る具体型の参照（寸法の取得・URL の読み直し・`ImageElementRenderer` による描画・背景画像）と、要素が持つ依存の型（UseCases の Protocol）は残る。→ 寸法の取得は第23回で外し、描画は第24回で Models へ移した（下の節）。
- 保留（Codex 合意）：第17回の「残り」のとおり（`editRevision` による自動失効、表示の非同期化など）。

## 段階3・第23回：差し替え・復元の配置サイズの計算の削除（2026-11-20）

### 計画と確認した経路

Model に残る具体型の参照（README の残件①）を、呼び出し経路・同期と非同期・保存と複製への影響で調べ、1つずつ分けて扱うことにしました（2026-11-20 ユーザー・Codex 合意）。Infrastructure で宣言された37の型名で層ごとに数えると、内側の層からの参照は Model の4か所だけでした（UseCases・ViewModels・Views・Utils は0件）。

| 参照 | 本番の経路 | アプリで通るか | 扱い |
| --- | --- | --- | --- |
| 寸法の取得（`replaceImageSource`） | 差し替えのイベント（背景除去・高画質化の適用と Redo）だけ。イベントが直後に元の配置サイズへ戻していた。Undo の復元も、取得先から元画像を取り直してサイズを計算し、イベントが戻していた | 通るが、結果は毎回捨てられる | 第23回（この節） |
| 描画（`ImageElementRenderer`） | キャンバスと削除エフェクト（`drawOnCanvas`）。保存の合成は Infrastructure から直接呼び、`Task.detached` の中で描く（描画は隔離なしのまま保つ必要がある） | 通る | 第24回の候補。置き場所はその計画で判断する |
| URL の読み直し（`copy()`） | UI から呼ばれない複製（`duplicateSelectedElement`）と、呼び出し元のない `LogoProject.duplicate` だけ。URL のソースは Decoder だけが作る | 通らない | 第25回の候補。仕様はその計画で判断する |
| 背景画像（`BackgroundSettings` → `AssetManager`） | キャンバスの描画と、保存の受付の固定（`renderCopy()`） | 通らない（`.image` の背景を作る経路がない） | 第25回のあとで判断する |

第23回では、差し替え（`replaceImageSource`）と復元（`restoreImageSource`）を、ソースの値（と、差し替えで指定したときの編集値の初期化）だけを変える形にしました。

| 確かめたこと | 根拠 |
| --- | --- |
| 計算の結果は本番で使われていない | 本番の呼び出し元は差し替えのイベントだけで、直後に元の配置サイズへ戻していた（Serena の参照検索とソース） |
| 要素の `canvasSize` はサイズの計算にだけ使う | private で、使うのは計算だけ。保存せず、複製にも写していなかった |
| 復元の中の取り直しを外しても、今のアプリの経路で表示する画像は変わらない | 取り直しはセッションのキャッシュを通らず、結果は捨てていた。履歴は巻き戻しの直後にソースの変更の失効を求め、次の表示で取り直す。データとパスのソースで、Undo のあとの表示をテストで確かめた（外部のファイルが変わる場合は、下の「挙動の範囲」） |

計画は Codex のレビューで補いました。

| 補足 | 対応 |
| --- | --- |
| 既存のテストは、Redo のあとの配置サイズを確かめていなかった（編集値だけ） | 2つの入口で、適用・Undo・Redo それぞれの直前に配置サイズを変え、その値が残ることを確かめる形にした。保つのはイベントを作った時点の値ではなく、各操作の直前の値 |
| `resetAdjustments: false` で編集値を残すことを確かめていなかった | Model のテストで、変更済みの30項目が残ることも確かめ、「指定によらず初期化する」変異を足した |
| 復元のテストが、古い値の残りを見ていなかった | 4つのソース・識別子・高画質化済みの値を入れた状態から始め、「ソースなし・識別子 nil・高画質化 false」への復元と、パスなし・パスと URL なしの優先順位も試す |
| 「挙動は変わらない」の範囲 | 下の「挙動の範囲」に分けて書いた |

### 挙動の範囲

- 変わらないもの：今のアプリの経路（背景除去・高画質化の適用と、その Undo・Redo）での配置サイズと、表示する画像。保存・書き出し（受付の時点の配置サイズを使う）、永続化（`canvasSize` は保存していない）、複製（配置サイズは複製元の値を写す）、Revert。
- 変わるもの：Model を直接呼んだときの契約（差し替え・復元は配置サイズを変えない。以前は画像に合わせて計算していた）。元画像の取得の回数と時点（Undo の中の取り直しがなくなり、次の表示の1回になる）。適用・Redo の中の、差し替えデータからの寸法の読み取り（`UIImage(data:)`）もなくなった。
- 確かめていないもの：ファイルを参照するソースでは、ファイルを読む時点が Undo から次の表示へ遅れる。そのあいだに外部のファイルが変わった場合や、ファイル名のソースで `UIImage(named:)` のシステムのキャッシュの状態が変わる場合まで含めて、表示が以前と同じとは確かめていない（どちらも、アプリの操作では作られないソース）。

### 変更した範囲

- [ImageElement](../../../GLogo/Models/ImageElement.swift)：差し替えと復元から配置サイズの計算を外した（`ImageInitializationLoader` の寸法の取得と、復元の中の元画像の取得がなくなった）。使われなくなった `canvasSize`（初期化の引数を含む）と `updateSize(for:)` を消した。説明に、配置サイズは変えないこと、画像に合わせて配置し直すときは呼び出し側が計算することを書いた。
- [ImageContentEvents](../../../GLogo/UseCases/History/Events/ImageContentEvents.swift)：差し替えのイベントの、適用・巻き戻しの前後で配置サイズを覚えて戻す処理（`preservedSize`）を消した。サイズを変えない約束は Model に置き、イベントを通したテストでも確かめる。
- [ImageElementFactory](../../../GLogo/UseCases/Import/ImageElementFactory.swift)：既定のキャンバス（`defaultCanvasSize`）を `ImageElement` から移し、要素へキャンバスを渡すのをやめた（最初の配置サイズの計算にだけ使う）。[ImageImportElementBuilder](../../../GLogo/UseCases/Import/ImageImportElementBuilder.swift) は参照先と説明を直した。
- 変えないもの：`ImageInitializationLoader.imageSize`（Factory が境界を通して使う）。`ImageSizeCalculator`（Factory だけが使うようになったが、UseCases から Models への参照は向きが正しいため動かさない）。差し替えの `resetAdjustments` の説明（「フィルター調整値」とあるが、実際は30項目を戻す。README の 2026-11-05 の残件のまま）。

### 検証と変更後レビュー

- **Critical／Warning**: 指摘なし。
- **Info**: 差し替え・復元を直接呼ぶ呼び出し元は、配置サイズが変わらなくなった。今後、画像に合わせて配置し直したい呼び出し元が出たら、その呼び出し元が `ImageSizeCalculator` で計算する。
- **Info**: Model に残る具体型の参照は3つ（URL の読み直し・描画・背景画像）。`ImageElement.swift` は 882 → 856 行。
- **Test Coverage**:
  - 変更の前に足したテスト（今のコードで成功を確かめてから変えた）：[ImageContentReplacedEventTests](../../../GLogoTests/Integration/ImageContentReplacedEventTests.swift)（2つの入口で、Redo のあとの配置サイズも確かめ、各操作の直前の値が残ることを見る形にした）と、[ImageSourceChangeEdgeTests](../../../GLogoTests/Integration/ImageSourceChangeEdgeTests.swift) 1件（差し替え前のソースが、データ・パス・ファイル URL・ファイル名・なしの5通り）。変更の前のコードで、イベントの戻しを外す変異と、イベントを作った時点の値へ戻す変異を入れると、どちらのテストも失敗することを確かめた。
  - 変更と同時に足したテスト4件：[ImageElementSourceTests](../../../GLogoTests/Unit/ImageElementSourceTests.swift) 3件（差し替えは、縦横比の違う画像・デコードできないデータ・空のデータ × 編集値を戻す/残す で配置サイズを変えず、残す指定では変更済みの30項目が残る。識別子を渡さない差し替えは新しい識別子を作る。復元は取得先を呼ばず配置サイズを変えず、優先順位の1つだけを残して古いソース・識別子・高画質化済みの値を残さない（9通り × 高画質化済みの値の2通り））と、`ImageSourceChangeEdgeTests` 1件（差し替えの Undo 自体では元画像を取得せず、次の表示の1回で取得する。データとパスの2通り）。
  - 期待値を変えたテスト：[ImageSourceIsolationTests](../../../GLogoTests/Unit/ImageSourceIsolationTests.swift) と [ImageElementCacheTests](../../../GLogoTests/Unit/ImageElementCacheTests.swift)（復元のあとの取得の回数を1つ減らす。パスの優先は、失効のあとの最初の取得で確かめる）。[ImageElementFactoryTests](../../../GLogoTests/Unit/ImageElementFactoryTests.swift)（`test_canvasSize_drivesLaterResizing` → `test_canvasSize_drivesInitialSize`。差し替え・復元の部分を外した）。[ImageElementCopyTests](../../../GLogoTests/Unit/ImageElementCopyTests.swift)（「複製のキャンバス」の前提がなくなった `test_copy_replacementUsesDefaultCanvas` を削除し、生成の補助のキャンバスを既定に戻した）。
  - 変異確認（自分で実行。対象の6スイートで、13件すべてを検出）：

    | 変異 | 種類 | 検出したテスト |
    | --- | --- | --- |
    | S1：差し替えで、画像の寸法から配置サイズを決め直す | 抜け | `ImageElementSourceTests` の差し替え2件・`ImageContentReplacedEventTests`（2つの入口）・`ImageSourceChangeEdgeTests` のソースの種類ごとのテスト |
    | S2：復元で取得先を呼ぶ（結果は捨てる） | 抜け | `ImageElementSourceTests` の復元・Undo のあとの取得のテスト・`ImageSourceIsolationTests`・`ImageElementCacheTests`（取得の回数） |
    | S3：復元で、取得した画像の寸法から配置サイズを決め直す | 抜け | S2 の4件と、`ImageContentReplacedEventTests`・ソースの種類ごとのテスト（Undo の配置サイズ） |
    | S4：復元でソースを設定しない | 消し過ぎ | 9件（Model の復元、イベント、ソースの変更の境界5件、取得先の分離、ソースのない複製） |
    | S5a：復元で識別子を設定しない | 消し過ぎ | Model の復元・`ImageContentReplacedEventTests`・`ImageSourceIsolationTests` |
    | S5b：復元で高画質化済みの値を設定しない | 消し過ぎ | Model の復元・`ImageSourceIsolationTests` |
    | S6：差し替えで編集値を戻さない | 消し過ぎ | Model の差し替え・`ImageContentReplacedEventTests` |
    | S7：差し替えで、渡された識別子を使わず新しく作る | 取り違え | Model の差し替えだけ（イベントのテストは「前と違う」ことしか見ない） |
    | S8a：ソースの優先順位で、データをパスより先にする | 取り違え | Model の復元・`ImageSourceIsolationTests`・`ImageElementCopyTests`（URL の複製） |
    | S8b：下位のソース同士で、ファイル名を URL より先にする | 取り違え | Model の復元だけ（パスなしの組み合わせ。Codex の補足） |
    | S8c：下位のソース同士で、データをファイル名より先にする | 取り違え | Model の復元だけ（パスと URL なしの組み合わせ。Codex の補足） |
    | S9：差し替えで、指定によらず常に編集値を初期化する | 消し過ぎ | Model の差し替えだけ（編集値を残す指定。Codex の補足） |
    | S10：イベントが、作った時点の配置サイズへ戻す | 取り違え | `ImageContentReplacedEventTests`・ソースの種類ごとのテスト（各操作の直前の値。Codex の補足） |

    どれも、狙った振る舞いの違い（配置サイズ・取得の回数・ソース・識別子・高画質化済みの値・編集値）でテストが失敗することをログで確かめた。順序の変異は、この変更では代入の並びに意味がないため、取得の時点（復元の中か、次の表示か）で確かめた（S2）。イベントのサイズの保持を戻す変異は、Model がサイズを変えなくなったため観察できない（等価）。
- **Verification**: GLogoTests は523件中520件成功（失敗1件は既知の性能テスト `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用。足した5件と削除した1件の分だけ件数が増えた）。UI テストは GLogoUITests 全体の30件が成功しました（実行は33回）。変更の前に足したテストは、本番のコードを変える前の作業ツリー（テスト先行のツリーと同じ内容）で、対象の2スイート8件が成功することを確かめた。アプリのビルドとテストのビルドで、今回変えたファイルに警告はありません。Model に残る Infrastructure の型の参照が3か所になったことを `rg` で確かめた。Xcode 27.1、iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormat は未導入のため実行できません。

### 残り

- Model に残る具体型の参照は3つ（URL の読み直し・描画・背景画像）。描画は第24回の候補、URL の読み直しは第25回の候補、背景画像は第25回のあとで判断する（どれも、配置と仕様は各回の計画で判断する）。要素が持つ依存の型（UseCases の Protocol）も残る。→ 描画は第24回で Models へ移した（下の節）。
- 差し替えの `resetAdjustments` が30項目を戻すことの是非（説明は「フィルター調整値」のまま）は、README の 2026-11-05 の残件のまま。
- 保留（Codex 合意）：第17回の「残り」のとおり（`editRevision` による自動失効、表示の非同期化など）。

## 段階3・第24回：画像要素の描画の Models への移動（2026-11-21）

### 計画と確認した経路

Model に残る具体型の参照（README の残件①）のうち、2つ目として描画（`ImageElementRenderer`）を扱いました（2026-11-20 ユーザー・Codex 合意の順）。`ImageElementRenderer` は、2026-11-03 の Infrastructure の新設のときに `UseCases/Rendering/` からフォルダごと移ったもので（中身は変えていない）、Infrastructure に置く根拠（Core Image・Core ML・Vision・Photos・ImageIO・ファイル I/O）は使っていませんでした。呼び出し元は、Model の `draw(in:image:)`（キャンバスと削除エフェクト）と、保存の合成（`ImageProcessingService`）の2か所です（`rg` と Serena で確認）。

描画の契約は、呼び出し側の条件まで含めて次のとおりです（Codex の指摘で、「要素と画像だけで描く」とは書かない）。

| 描画が使うもの | 内容 |
| --- | --- |
| 要素の値 | 表示・透明度・位置・サイズ・回転と、フレームの表示・種類・色・幅・角丸・半径の11個。読むだけで書かない |
| 渡された画像 | nil なら何も描かない（フレームも描かない） |
| 渡された context | 座標変換・透明度・切り抜きを設定し、線と塗りを描く |
| UIKit の現在の描画先 | 画像本体（`UIImage.draw(in:)`）と白系3種の塗り（`UIBezierPath.fill()`）を描く。渡された context と一致することが、呼び出し側の条件。違うと、画像本体と白系の塗りだけが別の描画先へ行き、座標変換も切り抜きもかからない |

今の3つの入口は、どれもこの条件を満たしています。移動では、この前提と実行スレッドを変えていません。

| 入口 | 渡す context と、現在の描画先と一致する理由 | スレッド |
| --- | --- | --- |
| キャンバス | `CanvasView.draw(_:)` の `UIGraphicsGetCurrentContext()`。UIKit が設定した描画先をそのまま渡す | メイン（`drawOnCanvas` は `@MainActor`） |
| 削除エフェクト | `renderSnapshot` の `UIGraphicsImageRenderer` の `cgContext`。描画ブロックの間は、レンダラーの context が現在の描画先 | メイン（`@MainActor`） |
| 保存の合成 | `makeCompositeImage` の `UIGraphicsImageRenderer` の `cgContext`。上と同じで、メインの外でも成り立つ | メインの外（`SaveImageCoordinator` の `Task.detached`） |

置き場所は Models の直下にし、型名を保ちました（ユーザー・Codex 了承）。テキスト・図形も Models で描いており、配置がそろいます。ただし UIKit の現在の描画先に依存するため、純粋な計算としては扱いません（Codex）。比べたほかの案は次のとおりです。

| 案 | 採らなかった理由 |
| --- | --- |
| UseCases（元の場所） | Model から参照できないため、`draw(in:image:)` を外してキャンバスの描き方から直接呼ぶ付け替えが要り、画像だけ入口が分かれる |
| Infrastructure のまま | 描画の境界と注入の配線が、キャンバス・削除エフェクト・テストまで増える。Infrastructure の技術を使っていない |
| Utils | 汎用の補助と純粋な計算の置き場で、`ImageElement` 専用の描画とは合わない |
| `ImageElement` の拡張への統合 | 570行の書き換えになり、移動として追えなくなる |

計画と実装は Codex のレビューで補いました。

| 補足 | 対応 |
| --- | --- |
| 現在の描画先への依存を、呼び出し側の条件も含めて明記する | 型の説明と、この節の表に書いた |
| 移動では前提と実行スレッドを変えない。描画先を明示する改善は別の変更 | 移動と説明だけにした。描画先を引数で明示する改善は、README の残件に記録した |
| 前提を破った結果は固定しない | 固定しない。正しい前提で、各入口に画像本体と白系の塗りが出ることを確かめる |
| `drawRect(for:)` の削除は、移動と別のコミット | 別のコミットにした（参照は `rg`・Serena とも0件） |
| 入口と直接の描画の比較だけでは、同じ欠落が両方に出ると成功する | 入口でも、画像本体・白系の塗り・回した台紙を、テストの中で計算した色と比べる。期待値は本番の描画処理から作らず、輪郭のアンチエイリアスを避けた点で見る |
| 描画状態は「呼び出す前の状態」に戻ることを確かめる | 呼び出す前に拡大・平行移動・切り抜き・透明度を設定し、描いたあとも保たれることを確かめる（保存の合成は、呼び出す側が変換と切り抜きを設定している） |
| T2 は合成の中で実行スレッドを記録し、T1 のコンパイル拒否は分けて報告する | 本物の合成を呼ぶ包みの中で記録した。T1 は下の変異の表で分けた |
| Coordinator 経由の確認は、既存の保存の統合テストへ足す | `SaveSnapshotIntegrationTests` に足した（描画そのものと保存の実行経路で、失敗したときに調べる場所が違うため） |
| 指定したフレームの色を無視して描く不具合を検出できない（実装レビューの Warning） | 赤のほかに緑でも確かめるテストを足した（下の「実装レビューの補強：フレームの色」） |

### 計画外の発見：画像本体に透明度がかからない

描画は最初に `context.setAlpha(element.opacity)` で透明度を設定しますが、画像本体を描く `UIImage.draw(in:)` は、描画先の透明度によらず不透明度1で描きます。透明度がかかるのは、線・台・白系3種の塗りです。期待値を描画の式から計算したテストが失敗して分かりました。今の UI に要素の透明度を変える操作は見当たらず（`rg`）、保存データの値だけで生じます。第24回では直さず、今の挙動を [ImageElementRendererTests](../../../GLogoTests/Unit/ImageElementRendererTests.swift) で固定し、README の残件に記録しました。描画先を明示する描き方に変えると、この結果も変わりえます。

### 変更の前の既存テストと変異

描画を通る12スイート78件で、変更の前のコードに変異を1件ずつ入れて実行しました（GLogoTests 全体では試していない）。19件中9件を検出し、10件が生き残りました。

| 変異 | 結果 | 検出したテスト（入口・見ている内容） |
| --- | --- | --- |
| D1 Model の描画が何もしない | 検出 | キャンバス（`CanvasView.draw`）の画素、キャンバスの描き方と削除エフェクトで選ぶ画像（`ImageElementDrawingTests` 5件）、ツールバーからの削除の画素 |
| D1b 削除エフェクトだけ描かない | 検出 | 上の削除側の6件と、キャンバスの削除モード（問い合わせの回数だけで、描画内容は見ない） |
| D1c キャンバスだけ描かない | 検出 | キャンバスの画素の1件だけ |
| D2 保存の合成で描かない | 検出 | 直接の合成（メイン）17件：位置・切り抜き・重なり順・向き・解像度・選ぶ画像・ぼかしの位置。Coordinator 経由（メインの外）4件 |
| D3 画像本体を描かない | 検出 | D1・D2 を検出した28件 |
| D4 前面のフレームを描かない／O2 前面を画像より先に描く | 検出 | フレーム付きの自動保存（メインの外、`.simple`）の1件だけ |
| O3 描画状態を戻さない | 検出 | 複数の要素を重ねる直接の合成の8件だけ（キャンバスと削除エフェクトでは検出なし） |
| E3 フレームなしでも前面を描く | 検出（偶然） | 選ぶ画像を見る合成の3件。8×8 の重ねる画像が、既定の幅4の白い線で覆われたためで、フレームを見るテストではない |
| D5 背面のフレーム・O1 背面の順序・S1 余白・W1 白系の塗り・W1b glassWhite・D6 透明度・D7 回転・D8 角丸・E1 非表示・E2 画像なしのフレーム | 生存 | フレームを画素で見るテストは `.simple` だけで、白系・透明度・回転・角丸・非表示・画像なしのフレームを画素で見るテストはなかった |

### 変更した範囲

- 先行テスト（今のコードで成功）
  - [ImageElementRendererTests](../../../GLogoTests/Unit/ImageElementRendererTests.swift)：11件。描画の中身（配置・透明度の今の挙動・回転・角丸・フレーム11種とその色・非表示と画像なし・描画状態の戻し）と、3つの入口（キャンバスの描き方・削除エフェクト・保存の合成）。入口は直接の描画と画素で一致することに加え、画像本体と白系の塗りを単独でも確かめる。
  - [SaveSnapshotIntegrationTests](../../../GLogoTests/Integration/SaveSnapshotIntegrationTests.swift)：1件。合成の保存が、本物の合成をメインスレッドの外で呼び（包みの中で記録）、保存した画像に画像本体と白系の塗りが出る。補助の `makeImage` に、加工の結果の画像を渡す引数を足した（既定は今までの緑）。
- 移動：[ImageElementRenderer](../../../GLogo/Models/ImageElementRenderer.swift) を `Infrastructure/Rendering/` から `Models/` へ移し、型の説明に契約（要素の値と画像で描く・現在の描画先の条件・画像本体に透明度がかからない・隔離なしのまま保つ）を足した。メソッドの本体と呼び出し元は変えていない（移動の前後の差分は説明の10行だけ）。
- `drawRect(for:)` の削除（別のコミット）：fitMode の撤廃のあと使われていなかった。
- 文書：この節と README。AGENTS.md の「移行中の例外」も更新した（無視ファイルのため手元だけ）。

### 検証と変更後レビュー

- **Critical / Warning**：変更後レビューではなし。Codex の実装レビューで Warning が1件あり、下の「実装レビューの補強：フレームの色」で対応した。
- **Info**：
  - 画像本体に透明度がかからない（上の節）。直さずに、今の挙動を固定した。
  - キャンバスの削除モードのテスト（`test_canvasDelete_snapshotsBeforeDeletion`）は、問い合わせしか見ない。削除エフェクトの描画内容は、今回の入口のテストとツールバーからの削除のテストが守る（どちらも同じ `renderSnapshot` を通る）。
  - 新しい入口のテストは `drawOnCanvas` を直接呼ぶ。`CanvasView` の繰り返しで画像要素だけを飛ばす変異（D1c）は、既存のキャンバスのテストだけが検出する。
  - T1 のコンパイルの誤りは、保存の合成の呼び出し（`ImageProcessingService.swift:89`）で出た2件だけだった。Model の `draw(in:image:)` の呼び出しで誤りが出なかった理由（ビルドが先に止まったためかどうか）は確かめていない。
- **変異**：最終のコードに22件を1件ずつ入れ、描画を通る13スイート（新しいテストを含む89件。フレームの色のテストを足す前）で実行した。21件を実行時のテストで検出し、T1 はコンパイルで拒否された。変更の前のコードでも、代表3件（D6・D7・W1）を新しいテストが検出した。

    | 変異 | 種類 | 検出したテスト |
    | --- | --- | --- |
    | D1 Model の描画が何もしない | 抜け | 既存の7件、キャンバスの描き方と削除エフェクトの入口 |
    | D1b 削除エフェクトだけ描かない | 抜け | 既存の7件（キャンバスの削除モードは問い合わせ）、削除エフェクトの入口 |
    | D1c キャンバスだけ描かない | 抜け | 既存のキャンバスの1件だけ |
    | D2 保存の合成で描かない | 抜け | 既存の21件、保存の合成の入口、Coordinator 経由のスレッドのテスト |
    | D3 画像本体を描かない | 抜け | 描画の中身・3つの入口・Coordinator 経由・既存の28件（計37件） |
    | D4 前面のフレームを描かない | 抜け | フレーム11種・透明度・3つの入口・Coordinator 経由・既存の自動保存 |
    | D5 背面のフレームを描かない | 抜け | フレーム11種・3つの入口 |
    | D6 透明度を設定しない | 抜け | 透明度・3つの入口（回した台紙） |
    | D7 回転しない | 抜け | 回転だけ |
    | D8 角丸で切り抜かない | 抜け | 角丸だけ |
    | W1 白系の塗りを描かない | 抜け | フレーム11種・透明度・3つの入口・Coordinator 経由 |
    | S1 フレームの余白をなくす | 取り違え | フレーム11種・3つの入口 |
    | W1b glassWhite だけ前面を描かない | 取り違え | フレーム11種・3つの入口 |
    | E1 非表示も描く | 消し過ぎ | 非表示と画像なしのテストだけ（キャンバスと保存は呼ぶ前に除く） |
    | E2 画像なしでもフレームを描く | 消し過ぎ | 非表示と画像なしのテストだけ |
    | E3 フレームなしでも前面を描く | 消し過ぎ | フレーム11種・角丸・既存の3件（偶然） |
    | O1 背面を画像より後に描く | 順序 | フレーム11種・3つの入口 |
    | O2 前面を画像より先に描く | 順序 | フレーム11種・透明度・3つの入口・Coordinator 経由・既存の自動保存 |
    | O3 描画状態を戻さない | 順序 | 描画状態の戻し・既存の8件 |
    | O4 中心へ移す前に回す | 順序 | 回転・3つの入口 |
    | T2 保存の処理をメインで行う | スレッド | Coordinator 経由のスレッドのテスト、既存の加工待ちのテスト |
    | T1 描画を `@MainActor` にする | 隔離 | 実行時のテストではなく、コンパイルで拒否（上の Info） |

- **Verification**：GLogoTests は、フレームの色のテストを足したあとの全体実行で535件中532件成功（失敗1件は既知の性能テスト `testPreviewLatencySDR_4K_P95`、スキップ2件は実機専用。足した12件の分だけ件数が増えた）。UI テストは GLogoUITests 全体の30件が成功しました（実行は33回。フレームの色のテストを足す前に実行し、アプリのコードはそのあと変えていない）。先行テストは、本番のコードを変える前の作業ツリー（先行テストのツリーと同じ内容）で、新しいファイルの10件と `SaveSnapshotIntegrationTests` の11件が成功することを確かめた（フレームの色のテストを足す前。足したあとの確認は「実装レビューの補強：フレームの色」）。移動の前後の差分が型の説明の10行だけであることと、Model から Infrastructure の型への参照が2か所（`AssetManager`・`ImageInitializationLoader`）になったことを確かめた。アプリのビルドは成功し、今回変えたファイルに警告はありません。今回触っていない `ProjectStorage.swift:92` に Sendable の捕捉の警告が2件出た。このファイルは第15回から変えておらず、Models のファイルの移動で再コンパイルの範囲が広がって表に出たと考えられる（第23回のコードで同じ範囲をビルドして確かめてはいない）。Xcode 27.1、iPhone 17 Pro／iOS 26.1 Simulator、`-parallel-testing-enabled NO`。実機は未実施です。SwiftFormat は未導入のため実行できません。

### 実装レビューの補強：フレームの色

Codex の実装レビューで、Warning が1件ありました。フレーム11種のテスト（[ImageElementRendererTests](../../../GLogoTests/Unit/ImageElementRendererTests.swift) の `test_draw_frameStyles_drawFrameLayers`）はフレームの色を赤に固定しており、ほかの期待値も赤に偏っていました。そのため、指定したフレームの色を無視する不具合を検出できませんでした。Codex は別のコピーで、描画の中の `element.frameColor` 13か所をすべて `UIColor.red` に置き換え、GLogoTests を実行しました（既知の SDR の性能テストを除く533件）。結果は529件成功・4件スキップで、失敗はありませんでした（スキップは、実機専用の2件と、環境変数を設定していない 8K の性能テスト2件）。

調べると、13か所のうち3か所（double の内側の線・neon の発光の影・stamp の前面の線）は、赤でも画素を見ていませんでした。画素でフレームを見るほかのテストも、すべて赤のフレームで描きます（`SaveSnapshotIntegrationTests` の合成の保存、`SaveCoordinatorRegressionTests` のフレーム付きの自動保存）。シアンや青など赤以外の色を使うテストは、属性・複製・保存データの値を見るだけです。

`test_draw_frameStyles_useFrameColor` を足しました。色を使う10種（film は色を使わない）を緑のフレームで描き、13か所それぞれが出る点を確かめます。

- 期待する色は、フレーム11種のテストと同じく、描画の式からテストの中で計算した値にした（緑を白へ 92% 寄せた台紙など）。計算した値は、作業用の一時的なテスト（コミットしない・削除済み）で測った値と一致した。
- 白系3種は、フレームの色の不透明度を、塗りの不透明度に使う（0.08〜0.92 に収める。編集パネルの「不透明度」で変えられる）。そのため、不透明度 0.5 の緑で確かめる。
- neon の発光の影は、ぼかしの強さを式から求めにくいため、強さは見ない。要素の外の灰色の背景の上で、緑だけが明るくなり、赤と青が同じだけ暗くなる（緑を灰色に重ねた色の並び）ことを確かめる。明るさの差の下限（15）は、測った差（約28）より小さくとった。
- stamp の前面の線は揺れていて、上に黒の破線を重ねる。y = 50 での線の中心（x ≈ 3.2）を式から求め、破線を避けた x = 5 で見る。
- double の内側の線・neon の発光の影・stamp の前面の線は、緑だけで確かめる（赤のテストには、これらの点がない）。

13か所を1か所ずつ赤にする変異（C1〜C13）と、Codex の変異（C0）を、最終のコードに1件ずつ入れました。描画の13スイート（90件）で実行すると、14件すべてを新しいテストが検出し、ほかのテストはどれも検出しませんでした。C0 は GLogoTests 全体（535件）でも試し、失敗したのは新しいテストと、既知の SDR の性能テストだけでした。

| 変異 | 赤にする場所 | 新しいテストで失敗した確かめ |
| --- | --- | --- |
| C0 13か所すべて（Codex の変異） | 描画の中の `element.frameColor` すべて | 10種すべて（13点の色と、発光の影の3つの確かめの計16件） |
| C1 | polaroid の台紙 | polaroid の台紙の余白 |
| C2 | badge の台 | badge の台の余白 |
| C3 | stamp の台紙 | stamp の台紙の余白 |
| C4 | simple の線 | simple の前面の線 |
| C5 | double の外側の線 | double の外側の線 |
| C6 | double の内側の線 | double の内側の線 |
| C7 | cornerAccent の線 | cornerAccent の角の線 |
| C8 | neon の発光の影 | neon の発光の影の3つすべて（実際は赤の影の [156, 99, 99]） |
| C9 | neon の線 | neon の発光の線だけ（影は緑のままで、影の確かめは成功） |
| C10 | badge の前面の線 | badge の前面の線 |
| C11 | stamp の前面の線 | stamp の前面の線 |
| C12 | 白系の塗りの不透明度 | 白系3種の塗り（不透明度が 0.92 になる） |
| C13 | 白系の塗りの色 | 白系3種の塗り |

先行テストのツリー（移動の前のコード）と移動のツリーの状態でも、描画の13スイート90件が成功しました。先行テストのツリーの状態で C0 を入れると、新しいテストが同じ16件で失敗しました（新しいテストの2スイート22件で実行）。どちらも、作業ツリーのコードとテストを一時的に各ツリーと同じにして確かめ、最終の状態へ戻しました。

### 残り

- Model に残る具体型の参照は2つ（URL の読み直し・背景画像）。URL の読み直しは第25回の候補、背景画像は第25回のあとで判断する（配置と仕様は各回の計画で判断する）。要素が持つ依存の型（UseCases の Protocol）も残る。
- 画像本体に透明度がかからないことと、描画が UIKit の現在の描画先に依存することは、README の残件（記録のみ）。描画先を明示する改善は、別の変更として判断する。
- 保留（Codex 合意）：第17回の「残り」のとおり（`editRevision` による自動失効、表示の非同期化など）。
