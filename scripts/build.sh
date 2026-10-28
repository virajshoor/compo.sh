#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Packaging only: never launches the app or registers a login item.
swift build -c release --arch arm64 --arch x86_64 -debug-info-format none
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 -debug-info-format none --show-bin-path)"
APP="dist/compo.sh.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/compo" "$APP/Contents/MacOS/compo"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/compo.sh-guide.pdf "$APP/Contents/Resources/compo.sh-guide.pdf"
swift scripts/Icon.swift dist/AppIcon.iconset "$APP/Contents/Resources/AppIcon.icns"

# Set COMPO_SIGN_IDENTITY to a Developer ID identity for a stable permission identity.
codesign --force --options runtime --timestamp --sign "${COMPO_SIGN_IDENTITY:--}" "$APP"
printf 'Built %s. App has NOT been launched.\n' "$APP"
