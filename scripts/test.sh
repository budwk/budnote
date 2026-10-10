#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift test
swift build -c debug
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/budnote-test.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/BudNote.app"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c debug --show-bin-path)/BudNote" "$APP/Contents/MacOS/BudNote"
python3 scripts/plist.py "$APP/Contents/Info.plist" "1.0.0"
BUDNOTE_TEST_DEFAULTS_SUITE="com.budnote.tests.$(uuidgen)" "$APP/Contents/MacOS/BudNote" --smoke-test
