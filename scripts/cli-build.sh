#!/usr/bin/env bash
set -euo pipefail

# 概要:
# GLogo を CLI から安定してビルドするためのヘルパースクリプト。
# 署名を無効化し、DerivedData 出力先を /tmp 配下に固定する。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${PROJECT:-GLogo.xcodeproj}"
SCHEME="${SCHEME:-GLogo}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/GLogoDerivedData}"

xcodebuild \
  -project "${ROOT_DIR}/${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_PREVIEWS=NO \
  build
