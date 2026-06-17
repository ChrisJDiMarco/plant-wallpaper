#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/app/Plant Wallpaper.app"
DISTRIBUTION_CHANNEL="${PLANT_WALLPAPER_DISTRIBUTION_CHANNEL:-direct-download}"
PAID_VALIDATION_PROVIDER="${PLANT_WALLPAPER_PAID_VALIDATION_PROVIDER:-none}"
if [[ -n "${PLANT_WALLPAPER_PAID_VALIDATION_CONFIGURED:-}" ]]; then
  PAID_VALIDATION_CONFIGURED="$PLANT_WALLPAPER_PAID_VALIDATION_CONFIGURED"
elif [[ "$PAID_VALIDATION_PROVIDER" != "none" ]]; then
  PAID_VALIDATION_CONFIGURED="true"
else
  PAID_VALIDATION_CONFIGURED="false"
fi

cd "$ROOT_DIR"
python3 "$ROOT_DIR/Scripts/verify_still_renderer.py"
find "$ROOT_DIR/.build" -name "WallpaperGarden_PlantWallpaper.bundle" -type d -prune -exec rm -rf {} +
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE="$BUILD_DIR/PlantWallpaper"
RESOURCE_BUNDLE="$BUILD_DIR/WallpaperGarden_PlantWallpaper.bundle"
APP_ICON="$ROOT_DIR/Sources/PlantWallpaper/Resources/AppIcon.icns"

"$EXECUTABLE" --interaction-self-test
python3 "$ROOT_DIR/Scripts/verify_stage_assets.py" "$ROOT_DIR/Sources/PlantWallpaper/Resources/PlantAssets"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/PlantWallpaper"
chmod +x "$APP_DIR/Contents/MacOS/PlantWallpaper"

if [[ -f "$APP_ICON" ]]; then
  cp "$APP_ICON" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# The resource bundle must live in Contents/Resources/ (not the .app root) so
# the app can be code-signed — code signing rejects any item at the bundle root.
# Bundle.appResources (AppResourceBundle.swift) looks here first.
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
  python3 "$ROOT_DIR/Scripts/verify_stage_assets.py" "$APP_DIR/Contents/Resources/$(basename "$RESOURCE_BUNDLE")"
fi

"$ROOT_DIR/Scripts/build_screensaver.sh" >/dev/null

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>PlantWallpaper</string>
  <key>CFBundleIdentifier</key>
  <string>com.chrisdimarco.wallpapergarden</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Plant Wallpaper</string>
  <key>CFBundleDisplayName</key>
  <string>Plant Wallpaper</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.lifestyle</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Plant Wallpaper uses approximate location only for local weather via Open-Meteo. Rain can water your plants, fog can drift in, and snow can slow growth.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Plant Wallpaper uses the microphone only when you start Miso voice mode, so you can talk to the cat companion.</string>
  <key>PlantWallpaperDistributionChannel</key>
  <string>__PLANT_WALLPAPER_DISTRIBUTION_CHANNEL__</string>
  <key>PlantWallpaperPaidValidationConfigured</key>
  <__PLANT_WALLPAPER_PAID_VALIDATION_CONFIGURED__/>
  <key>PlantWallpaperPaidValidationProvider</key>
  <string>__PLANT_WALLPAPER_PAID_VALIDATION_PROVIDER__</string>
</dict>
</plist>
PLIST

/usr/bin/sed -i '' \
  -e "s/__PLANT_WALLPAPER_DISTRIBUTION_CHANNEL__/$DISTRIBUTION_CHANNEL/g" \
  -e "s/__PLANT_WALLPAPER_PAID_VALIDATION_PROVIDER__/$PAID_VALIDATION_PROVIDER/g" \
  -e "s/__PLANT_WALLPAPER_PAID_VALIDATION_CONFIGURED__/$PAID_VALIDATION_CONFIGURED/g" \
  "$APP_DIR/Contents/Info.plist"

echo "$APP_DIR"
