# EditorViewModelの責務と分割候補

この文書は、編集全体を管理するViewModelの現状と、機能別ViewModelへ分ける境界を記録します。調査日: 2026-10-18。分割案は未実装です。

- 対象: [EditorViewModel.swift](../../../GLogo/ViewModels/EditorViewModel.swift)
- 全体方針: [比較と責務分離方針](../README.md)
- 関連: [ElementViewModel](ElementViewModel.md)、[保存Coordinator](../UseCases/SaveImage/SaveImageCoordinator.md)

## 確認した現状

- `@MainActor`の`ObservableObject`で、プロジェクト、選択、編集モード、変更フラグ、保存・AI処理の表示状態を保持します。
- 要素の追加・削除・順序変更、テキスト・図形・画像の変更、変形、履歴、画像保存、インポートなどの操作を持ちます。
- `EditorHistory`はこのViewModelが保持し、確定変更の適用に利用します。
- 保存Coordinatorや複数のUseCaseを内部で生成します。背景除去処理は初期化時に注入できます。
- Undo／Redoでは要素を更新したあと、選択の再設定と画面通知も行います。
- アプリ入口が`@StateObject`として生成し、`EditorView`へ渡します。`EditorView`は`ElementViewModel`を`@StateObject`として生成します。

参照: [アプリ入口](../../../GLogo/App/GameLogoMakerApp.swift)、[EditorView](../../../GLogo/Views/Editor/Screen/EditorView.swift)。

## 評価

### Warning

編集全体の窓口が一つである利点はありますが、保存・AI・各要素種別など、変更理由の異なる責務が集中しています。内部生成された依存は、ViewModelから外部処理までを代替実装で検証する際の制約になります。

`project`が`private(set)`でも、参照先のModel内部が不変になるわけではありません。別の参照から要素を書き換える経路と、通知・履歴の対応を確認する必要があります。

### Info

UseCaseとCoordinatorへの委譲はすでに存在します。すべてを新設せず、既存の処理を呼ぶ画面状態と操作受付を分離する方針が適しています。ファイルの行数より、状態所有と変更理由を分割の根拠にします。

## ViewModelの分割候補

以下の型名は候補です。ファイル名は、採用した主な型名に合わせます。

| 候補 | 所有する画面状態・操作 | 所有させない責務 |
| --- | --- | --- |
| `EditorViewModel`に残す範囲 | プロジェクト・選択の共通窓口、編集モード、機能間の調整 | 個別パネルの操作途中値、画像加工の実装 |
| `ImageSaveViewModel` | 保存要求、保存中、保存結果・エラーの表示状態 | 保存モード判定、画像合成、写真ライブラリへの書き込み |
| `AIToolsViewModel` | 背景除去・ぼかし・高画質化の要求、対象ID、処理中・エラー、操作の寿命 | AI推論、画像変換、確定変更の独立した履歴スタック |
| `ImageImportViewModel` | インポートの入力受付と表示状態。独立した状態が必要な場合に検討 | 画像の生成、初期配置計算、別のプロジェクト所有 |

インポートのように独立した画面状態が少ない処理は、既存`ImageImportCoordinator`への委譲を維持するだけで十分かを先に判断します。メソッドがあるという理由だけでViewModelを増やしません。

テキスト・図形・画像調整・ジェスチャーの候補は[ElementViewModelの文書](ElementViewModel.md)にまとめます。両ファイルに分かれている同じ機能の操作は、一緒に移動先を決めます。

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

一機能の移行ごとに、操作受付、表示更新、履歴、異常系、寿命を確認してから次へ進みます。今回の記録ではテストを実行していません。
