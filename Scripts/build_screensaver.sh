#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/screensaver"
SAVER_DIR="$BUILD_DIR/Plant Wallpaper.saver"
EXECUTABLE="$SAVER_DIR/Contents/MacOS/PlantWallpaperScreenSaver"
INSTALL=0

if [[ "${1:-}" == "--install" ]]; then
  INSTALL=1
fi

cd "$ROOT_DIR"

python3 "$ROOT_DIR/Scripts/verify_stage_assets.py" "$ROOT_DIR/Sources/PlantWallpaper/Resources/PlantAssets" >/dev/null

rm -rf "$SAVER_DIR"
mkdir -p "$SAVER_DIR/Contents/MacOS" "$SAVER_DIR/Contents/Resources"

CORE_SOURCES=()
while IFS= read -r source_file; do
  CORE_SOURCES+=("$source_file")
done < <(find "$ROOT_DIR/Sources/PlantGardenCore" -name "*.swift" -type f | sort)

SAVER_SOURCES=()
while IFS= read -r source_file; do
  SAVER_SOURCES+=("$source_file")
done < <(find "$ROOT_DIR/Sources/PlantWallpaperScreenSaver" -name "*.swift" -type f | sort)

xcrun swiftc \
  -parse-as-library \
  -O \
  -module-name PlantWallpaperScreenSaver \
  -emit-library \
  -o "$EXECUTABLE" \
  "${CORE_SOURCES[@]}" \
  "${SAVER_SOURCES[@]}" \
  -framework AppKit \
  -framework ScreenSaver \
  -framework WebKit

chmod +x "$EXECUTABLE"

cp -R "$ROOT_DIR/Sources/PlantWallpaper/Resources/PlantAssets" "$SAVER_DIR/Contents/Resources/"
cp -R "$ROOT_DIR/Sources/PlantWallpaper/Resources/AlienPlantAssets" "$SAVER_DIR/Contents/Resources/"
cp -R "$ROOT_DIR/Sources/PlantWallpaper/Resources/SceneAssets" "$SAVER_DIR/Contents/Resources/"
cp -R "$ROOT_DIR/Sources/PlantWallpaper/WebAssets" "$SAVER_DIR/Contents/Resources/"

cat > "$SAVER_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>PlantWallpaperScreenSaver</string>
  <key>CFBundleIdentifier</key>
  <string>com.chrisdimarco.wallpapergarden.screensaver</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Plant Wallpaper</string>
  <key>CFBundleDisplayName</key>
  <string>Plant Wallpaper</string>
  <key>CFBundlePackageType</key>
  <string>BNDL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.2</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>CFBundleVersion</key>
  <string>3</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>PlantWallpaperScreenSaverView</string>
</dict>
</plist>
PLIST

plutil -lint "$SAVER_DIR/Contents/Info.plist" >/dev/null
python3 "$ROOT_DIR/Scripts/verify_stage_assets.py" "$SAVER_DIR/Contents/Resources/PlantAssets" >/dev/null
python3 "$ROOT_DIR/Scripts/verify_screensaver_bundle.py" "$SAVER_DIR" >/dev/null

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$SAVER_DIR" >/dev/null 2>&1 || true
fi

if [[ "$INSTALL" == "1" ]]; then
  INSTALL_DIR="$HOME/Library/Screen Savers"
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALL_DIR/Plant Wallpaper.saver"
  cp -R "$SAVER_DIR" "$INSTALL_DIR/"
  echo "$INSTALL_DIR/Plant Wallpaper.saver"
else
  echo "$SAVER_DIR"
fi
