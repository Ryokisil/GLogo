#
# 概要:
# このディレクトリは Real-ESRGAN の変換ツール群を置くための作業領域です。
# Python 仮想環境、チェックポイント、Core ML 変換スクリプトをアプリ本体から分離して管理します。
#

# tools/ml

`tools/ml` は AI 高画質化用モデルの変換専用ディレクトリです。

## 役割

- Python 仮想環境の配置
- Real-ESRGAN チェックポイントの保管
- Core ML 変換スクリプトの実行

## 想定構成

```text
tools/ml/
  README.md
  requirements.txt
  convert_realesrgan.py
  checkpoints/
  artifacts/
```

## セットアップ

```bash
zsh tools/ml/setup_env.sh
```

依存確認だけ先に行いたい場合:

```bash
python3 tools/ml/check_prerequisites.py
```

## チェックポイントの置き場所

`realesr-general-x4v3.pth` を `tools/ml/checkpoints/` に置きます。

## 変換コマンド

```bash
source .venv-ai/bin/activate
python tools/ml/convert_realesrgan.py \
  --checkpoint tools/ml/checkpoints/realesr-general-x4v3.pth \
  --compiled-output-dir GLogo/Resources/MLModels
```

## 出力先

- 中間生成物: `tools/ml/artifacts/`
- アプリ組み込み先: `GLogo/Resources/MLModels/realesr-general-x4v3.mlmodelc`
