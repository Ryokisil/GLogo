#!/usr/bin/env bash
set -euo pipefail

# 概要:
# GLogo のテストを CLI から実行するためのヘルパースクリプト。
# 環境変数 ONLY_TESTING を指定すると対象テストを絞り込める。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${PROJECT:-GLogo.xcodeproj}"
SCHEME="${SCHEME:-GLogo}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/GLogoDerivedData}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro}"
ONLY_TESTING="${ONLY_TESTING:-}"

CMD=(
  xcodebuild
  -project "${ROOT_DIR}/${PROJECT}"
  -scheme "${SCHEME}"
  -destination "${DESTINATION}"
  -derivedDataPath "${DERIVED_DATA_PATH}"
  CODE_SIGNING_ALLOWED=NO
  ENABLE_PREVIEWS=NO
)

if [[ -n "${ONLY_TESTING}" ]]; then
  CMD+=("-only-testing:${ONLY_TESTING}")
fi

CMD+=(test)
"${CMD[@]}"
