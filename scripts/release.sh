#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export VERSION="${VERSION:-1.0.9}"
export ARCH="${ARCH:-universal}"
if [[ -n "${NOTARY_PROFILE:-}" && -z "${SIGN_IDENTITY:-}" ]]; then
    printf '公证需要 SIGN_IDENTITY（Developer ID Application）。\n' >&2; exit 1
fi
./scripts/build.sh
NAME="BudNote-${VERSION}-${ARCH}"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/budnote-release.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto dist/BudNote.app "$STAGE/BudNote.app"
ln -s /Applications "$STAGE/Applications"
cp Resources/安装说明.txt "$STAGE/安装说明.txt"
hdiutil create -volname "BudNote" -srcfolder "$STAGE" -ov -format UDZO "dist/$NAME.dmg"
ditto -c -k --sequesterRsrc --keepParent dist/BudNote.app "dist/$NAME.zip"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "dist/$NAME.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple dist/BudNote.app
    xcrun stapler staple "dist/$NAME.dmg"
    ditto -c -k --sequesterRsrc --keepParent dist/BudNote.app "dist/$NAME.zip"
fi
shasum -a 256 "dist/$NAME.dmg" "dist/$NAME.zip" > "dist/$NAME.sha256"
printf '发布文件：dist/%s.{dmg,zip,sha256}\n' "$NAME"
