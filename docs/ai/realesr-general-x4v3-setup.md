# `realesr-general-x4v3` 導入メモ

## 目的

GLogo の `Enhance` 機能を、`realesr-general-x4v3` ベースの AI 超解像で動かすための導入手順をまとめる。

## 現在の前提

- アプリ側は `realesr-general-x4v3.mlmodelc` を優先的に読み込む
- 探索先は `GLogo/Resources/MLModels`
- モデル未配置時は UI 側で機能を無効化する

## 必要なもの

- Real-ESRGAN 公式の `realesr-general-x4v3` 重み
- PyTorch から Core ML へ変換する環境
- 変換後の `realesr-general-x4v3.mlmodelc`

## 導入フロー

1. 公式重みを取得する
2. `tools/ml/requirements.txt` で変換環境を作る
3. `tools/ml/convert_realesrgan.py` で Core ML へ変換する
3. `realesr-general-x4v3.mlmodelc` を `GLogo/Resources/MLModels` に配置する
4. `xcodebuild -project GLogo.xcodeproj -scheme GLogo build` でビルド確認する

## 注意

- このリポジトリには、重みファイルや変換済みモデルは同梱していない
- 変換ツール群はこの環境に未インストール
- 実際のモデル導入には外部ダウンロードと変換作業が別途必要
- 詳細なコマンドは `tools/ml/README.md` を参照する
