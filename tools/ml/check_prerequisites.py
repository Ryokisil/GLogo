#!/usr/bin/env python3
#
# 概要:
# Real-ESRGAN 変換前に Python 依存とチェックポイント配置状況を確認する簡易診断スクリプトです。
# セットアップ不足を先に見つけ、変換処理の失敗原因を切り分けやすくします。
#

from __future__ import annotations

import importlib.util
from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[2]
CHECKPOINT = REPO_ROOT / "tools/ml/checkpoints/realesr-general-x4v3.pth"
REQUIRED_MODULES = [
    "torch",
    "torchvision",
    "coremltools",
    "basicsr",
    "realesrgan",
]


def module_available(name: str) -> bool:
    return importlib.util.find_spec(name) is not None


def main() -> int:
    has_error = False

    print("Python dependency check:")
    for module_name in REQUIRED_MODULES:
        available = module_available(module_name)
        marker = "OK" if available else "MISSING"
        print(f"  [{marker}] {module_name}")
        has_error |= not available

    print()
    print("Checkpoint check:")
    if CHECKPOINT.exists():
        print(f"  [OK] {CHECKPOINT}")
    else:
        print(f"  [MISSING] {CHECKPOINT}")
        has_error = True

    if has_error:
        print()
        print("不足があります。`tools/ml/setup_env.sh` とチェックポイント配置を確認してください。")
        return 1

    print()
    print("変換を開始できます。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
