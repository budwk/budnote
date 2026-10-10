#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.0.9}"
ARCH="${ARCH:-$(uname -m)}"
CONFIGURATION="${CONFIGURATION:-release}"
APP="$(pwd)/dist/BudNote.app"
if [[ "$ARCH" == universal ]]; then
    swift build -c "$CONFIGURATION" --arch arm64 --arch x86_64
    BIN="$(swift build -c "$CONFIGURATION" --arch arm64 --arch x86_64 --show-bin-path)/BudNote"
else
    swift build -c "$CONFIGURATION" --arch "$ARCH"
    BIN="$(swift build -c "$CONFIGURATION" --arch "$ARCH" --show-bin-path)/BudNote"
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/BudNote"
if [[ "$CONFIGURATION" == release ]]; then strip -x "$APP/Contents/MacOS/BudNote"; fi
python3 scripts/plist.py "$APP/Contents/Info.plist" "$VERSION"
if [[ ! -f dist/BudNote.icns || scripts/icon.swift -nt dist/BudNote.icns ]]; then
    swift scripts/icon.swift dist/BudNote.iconset
    iconutil -c icns dist/BudNote.iconset -o dist/BudNote.icns
fi
cp dist/BudNote.icns "$APP/Contents/Resources/BudNote.icns"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
    codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist"
printf '构建完成：%s\n' "$APP"
du -sh "$APP"
