#!/bin/bash
# Pack the SPM debug binary into a tiny .app and open it via LaunchServices.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/.build/debug/AutoSmaart"
BUNDLE="$ROOT/.build/debug/AutoSmaart_AutoSmaartUI.bundle"
APP="$ROOT/.build/AutoSmaart.app"
if [[ ! -x "$BIN" ]]; then
  echo "missing $BIN — build with: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --product AutoSmaart" >&2
  exit 1
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Sources/AutoSmaartApp/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/AutoSmaart"
if [[ -d "$BUNDLE" ]]; then
  cp -R "$BUNDLE" "$APP/Contents/Resources/"
  cp -R "$BUNDLE" "$APP/Contents/MacOS/"
fi
pkill -x AutoSmaart 2>/dev/null || true
open "$APP"
