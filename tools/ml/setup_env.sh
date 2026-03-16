#!/bin/zsh
#
# 概要:
# Real-ESRGAN 変換用の Python 仮想環境を作成し、
# 必要な依存をまとめてインストールするセットアップスクリプトです。
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VENV_DIR="$REPO_ROOT/.venv-ai"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 が見つかりません。" >&2
  exit 1
fi

PYTHON_VERSION="$(python3 --version | awk '{print $2}')"
echo "Using python3 $PYTHON_VERSION"

python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

python -m pip install --upgrade pip
pip install -r "$REPO_ROOT/tools/ml/requirements.txt"

echo
echo "セットアップ完了:"
echo "  source $VENV_DIR/bin/activate"
echo "  python $REPO_ROOT/tools/ml/convert_realesrgan.py --help"
