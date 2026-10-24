# ProjectStorageと永続化Modelの境界

この文書は、プロジェクトJSON保存の現状と、非同期保存・保存形式互換性の検証範囲を記録します。調査日: 2026-10-18。改善案は未実装です。

- 対象: [ProjectStorage.swift](../../../../GLogo/UseCases/Storage/ProjectStorage.swift)
- 関連Model: [LogoProject.swift](../../../../GLogo/Models/LogoProject.swift)、[LogoElement.swift](../../../../GLogo/Models/LogoElement.swift)
- 全体方針: [比較と責務分離方針](../../README.md)
- 別の保存経路: [写真ライブラリへの書き出し](../SaveImage/SaveImageCoordinator.md)

## 確認した現状

- `ProjectStorage.shared`がディレクトリ、JSON保存・読み込み、一覧・削除、画像アセットの操作を提供します。
- `saveProject`にはcompletion版とasync版があり、Modelをエンコードした`Data`のファイル書き込みをバックグラウンドへ渡します。
- 写真ライブラリ保存のCoordinatorと違い、この書き込み処理はプロジェクトを描画するものではありません。
- `LogoProject`自身がCodableを実装し、画像・テキスト・図形などの具体型を保持するラッパーと、旧形式の復元処理を持ちます。

## HandsPOSとの違いと評価

共有資料のHandsPOSには、業務EntityとRealm用オブジェクトをTransformerで変換する経路があります。GLogoはModel自身が保存形式を扱うため、構成が簡潔である反面、Modelの構造変更と保存互換性が結び付きます。

### Warning

複数の異なるプロジェクトが並行保存できることと、同じプロジェクトを連続保存して最新の内容が残ることは別の契約です。今回確認した並行保存テストだけでは、同一保存先の要求順・完了順や、書き込み中断時の復元を保証できません。

これは実際にデータ破損を確認した指摘ではありません。呼び出し側を含む保存順序と書き込み方式は、永続化を変更する前の検証対象です。

### Info

バックグラウンドの書き込み前にJSONデータを生成する分離と、旧形式の復元処理は既存の強みです。ただし、エンコード中に可変Modelへ別の変更が入らないかは、呼び出し側のActor・所有契約と合わせて確認します。

## 改善時の判断

- ViewModel分割と同時に保存形式を変えない方針とします。
- 保存・読み込みを代替実装で検証する必要がある呼び出し元には、必要な機能だけの注入境界を検討します。
- 同一プロジェクトの保存順序が必要な場合、プロジェクトID単位の直列化や世代管理など、要求する契約に応じた方式を選びます。
- 中断時の安全性を変更する場合、ファイル書き込み方式と復元手順を合わせて検証します。原子的書き込みだけで要求の新旧順も解決すると仮定しません。
- 保存専用DTOを導入するかは、互換性処理の規模と変更頻度から判断します。Domain分離という理由だけで一律に型を増やしません。

## テストと完了条件

- [ProjectStorageAsyncConcurrencyIntegrationTests](../../../../GLogoTests/Integration/ProjectStorageAsyncConcurrencyIntegrationTests.swift): async保存・読み込みの往復、異なる複数プロジェクトの並行保存・読み込み。
- [LogoProjectPolymorphicCodingRegressionTests](../../../../GLogoTests/Regression/LogoProjectPolymorphicCodingRegressionTests.swift): 新しいラッパー形式と旧形式からの具体型復元。
- [RevertSnapshotRegressionTests](../../../../GLogoTests/Regression/RevertSnapshotRegressionTests.swift): 復元基準や属性のCodable往復。

追加・再確認候補は、同一IDへの保存順序、書き込み失敗・中断、可変Modelをエンコードする間の更新制御、属性追加後の旧形式データです。今回の記録ではテストを実行していません。
