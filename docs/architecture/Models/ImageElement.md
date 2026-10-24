# ImageElementのデータと技術処理の境界

この文書は、画像要素Modelが担うデータ・描画・キャッシュ・永続化の境界を記録します。調査日: 2026-10-18。改善案は未実装です。

- 対象: [ImageElement.swift](../../../GLogo/Models/ImageElement.swift)
- 全体方針: [比較と責務分離方針](../README.md)

## 確認した現状

`ImageElement`は`LogoElement`を継承する可変な参照型です。画像参照、編集パラメータ、メタデータ、初期調整スナップショット、キャッシュを保持し、Codable、コピー、復元、画像取得、フィルター呼び出し、描画呼び出しを持ちます。

| 入口 | 確認した処理 |
| --- | --- |
| `originalImage` | Resolverで元画像を取得し、Model内へキャッシュ |
| `image` | 編集状態に応じてプレビューまたは高品質処理を呼び、必要に応じてキャッシュ更新 |
| `renderFullQualityImageAsync()` | 非同期の高品質フィルター処理を呼び出す |
| `draw(in:)` | 表示する画像を解決して`ImageElementRenderer`へ描画を委譲 |
| `imageSourceResolver`、`previewService` | 全画像要素で共有するstatic依存。ストアのアクセスはロックで保護 |

## 評価

### Warning

取得プロパティに処理負荷やキャッシュ更新が含まれるため、呼び出し側からコストと副作用を把握しにくい構造です。Modelが描画・取得の具体的な仕組みにも関わるため、純粋な編集データだけを扱うテストやバックグラウンドへの受け渡しが難しくなります。

staticな依存の差し替えは全要素へ影響します。依存ストアのロックは、テストごとの依存を分離したり、返したサービスとModel全体の並行利用を自動的に安全にしたりするものではありません。

### Info

ResolverとRendererへの抽出はすでに進んでいます。さらに分離する場合も既存実装を再利用します。`Payment`の残額計算のようなデータ固有の振る舞いと、画像I/O・描画・キャッシュ調整の責務を区別します。Apple画像型への依存をすべて除去すること自体を目的にしません。

## 責務の配置案

| 責務 | 方針 |
| --- | --- |
| 画像ソースの識別、編集値、初期状態 | Modelに保持。値のスナップショット化を検討 |
| 画像ソースの優先順位と取得 | [ImageSourceResolver](../../../GLogo/UseCases/Storage/ImageSourceResolver.swift)とRepositoryを利用 |
| フィルター、SDR／HDR経路、プレビュー | [ImagePreviewService](../../../GLogo/UseCases/Rendering/ImagePreviewService.swift)等を利用 |
| 画像要素の描画 | [ImageElementRenderer](../../../GLogo/UseCases/Rendering/ImageElementRenderer.swift)を維持 |
| キャッシュの保存場所・無効化・寿命 | 描画側で所有する案を検討。履歴や画像差し替えから無効化できる契約が必要 |
| Codableと旧形式復元 | 当面の保存互換性を維持し、データの移動とは別に扱う |

新しいViewModelへ画像取得・キャッシュ処理をそのまま移すと、別の場所に責務集中を作ります。画面状態と画像処理を分けて配置します。

## 横断するリスク

- プレビューと保存では、入力解像度・品質・色空間・描画範囲を確認します。共通Rendererがあることだけで一致を保証しません。
- Undo／Redo、画像差し替え、Revert、メモリ警告から、適切なキャッシュを無効化する必要があります。
- 属性を移す場合はCodable、コピー、初期スナップショット、メタデータ復元を一緒に確認します。
- バックグラウンドへ渡す入力を固定する場合、編集値だけでなく元画像の解決結果と寿命も確認します。
- 高解像度画像を無条件に複製するとメモリを圧迫します。必要な値と画像資源の保持方法を分けて設計します。

## 既存テストと追加候補

- [ImageSourceResolverTests](../../../GLogoTests/Unit/ImageSourceResolverTests.swift): 画像ソースの解決経路。
- [ImageAssetRepositoryRoutingTests](../../../GLogoTests/Unit/ImageAssetRepositoryRoutingTests.swift): 編集用画像の選択経路。
- [PreviewCacheRegressionTests](../../../GLogoTests/Regression/PreviewCacheRegressionTests.swift): キャッシュの回帰確認先。
- [ImageUndoCacheInvalidationTests](../../../GLogoTests/Unit/ImageUndoCacheInvalidationTests.swift): 履歴適用・取り消し時のキャッシュ無効化。
- [RevertSnapshotRegressionTests](../../../GLogoTests/Regression/RevertSnapshotRegressionTests.swift): 初期状態への復元とスナップショットの保持。
- [LogoProjectPolymorphicCodingRegressionTests](../../../GLogoTests/Regression/LogoProjectPolymorphicCodingRegressionTests.swift): 要素型と旧形式の復元。
- [ImagePreviewAsyncResponsivenessRegressionTests](../../../GLogoTests/Regression/ImagePreviewAsyncResponsivenessRegressionTests.swift): 非同期SDR／HDR処理中のメインキュー応答性。

追加候補は、セッションごとに異なる依存を同時利用した場合の独立性、画像差し替え後の古い描画結果の破棄、保存用入力の固定です。今回の記録ではテストを実行していません。
