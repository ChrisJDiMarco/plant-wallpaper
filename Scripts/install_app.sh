#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Plant Wallpaper.app"
INSTALL_DIR="/Applications"
APP_DIR="$ROOT_DIR/.build/app/$APP_NAME"

if [[ "${1:-}" != "--skip-build" ]]; then
  build_log="$(mktemp)"
  trap 'rm -f "$build_log"' EXIT
  "$ROOT_DIR/Scripts/build_app.sh" 2>&1 | tee "$build_log"
  APP_DIR="$(tail -n 1 "$build_log")"
fi

if [[ ! -d "$APP_DIR" ]]; then
  echo "missing app bundle: $APP_DIR" >&2
  exit 1
fi
if [[ ! -f "$APP_DIR/Contents/Info.plist" || ! -x "$APP_DIR/Contents/MacOS/PlantWallpaper" ]]; then
  echo "incomplete app bundle: $APP_DIR" >&2
  exit 1
fi

osascript -e 'tell application id "com.chrisdimarco.wallpapergarden" to quit' >/dev/null 2>&1 || true
sleep 1

rm -rf "$INSTALL_DIR/$APP_NAME"
ditto "$APP_DIR" "$INSTALL_DIR/$APP_NAME"
open "$INSTALL_DIR/$APP_NAME"

echo "$INSTALL_DIR/$APP_NAME"
