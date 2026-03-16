# MLModels

このディレクトリは、GLogo が参照する Core ML モデルの配置先です。

## 高画質化で使うモデル

- 配置名: `realesr-general-x4v3.mlmodelc`
- 目的: AI 超解像による見た目改善

## 置き方

1. `realesr-general-x4v3` を Core ML へ変換します。
2. 生成された `realesr-general-x4v3.mlmodelc` をこのディレクトリへ配置します。
3. Xcode を再度開くか、プロジェクトを再読み込みします。

補足:

- アプリ側は `GLogo/Resources/MLModels` を優先探索します。
- モデルが無い場合、AI 高画質化ボタンは無効のままです。
