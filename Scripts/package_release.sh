#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/app/Plant Wallpaper.app"
SAVER_DIR="$ROOT_DIR/.build/screensaver/Plant Wallpaper.saver"
DIST_DIR="$ROOT_DIR/.build/dist"
STAGING_DIR="$DIST_DIR/Plant Wallpaper"
VERSION="${PLANT_WALLPAPER_VERSION:-1.0.0}"
DMG_PATH="$DIST_DIR/Plant-Wallpaper-$VERSION.dmg"
SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-}"
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
PLANT_WALLPAPER_DISTRIBUTION_CHANNEL="$DISTRIBUTION_CHANNEL" \
PLANT_WALLPAPER_PAID_VALIDATION_PROVIDER="$PAID_VALIDATION_PROVIDER" \
PLANT_WALLPAPER_PAID_VALIDATION_CONFIGURED="$PAID_VALIDATION_CONFIGURED" \
  "$ROOT_DIR/Scripts/build_app.sh" >/dev/null

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
ditto "$APP_DIR" "$STAGING_DIR/Plant Wallpaper.app"
if [[ -d "$SAVER_DIR" ]]; then
  ditto "$SAVER_DIR" "$STAGING_DIR/Plant Wallpaper.saver"
fi

cat > "$STAGING_DIR/INSTALL_README.txt" <<'README'
Plant Wallpaper

Install:
1. Drag Plant Wallpaper.app to Applications.
2. Optional: double-click Plant Wallpaper.saver to install the matching screen saver.
3. Launch the app from Applications.

Recommended macOS setting:
System Settings > Desktop & Dock > Click wallpaper to show desktop > Only in Stage Manager.

Permissions:
- Input Monitoring enables desktop planting, dragging, and cat/cursor interactions.
- Location is optional and only powers local weather effects.
- Microphone is only used when Miso voice mode is started.
- Network is used for radio streams, weather, AI generation, and license/update checks.

Storefront:
This public package should be stamped as a direct-download build. Paid unlocks should be
validated by Stripe or a custom license endpoint. Mac App Store builds must be built
separately with StoreKit/In-App Purchase and App Sandbox enabled.

Uninstall:
Quit Plant Wallpaper, delete the app, remove Plant Wallpaper.saver from ~/Library/Screen Savers,
and use Help & Data > Uninstall & Cleanup Guide if you also want to remove local gardens/assets.
README

if [[ -n "$SIGN_IDENTITY" ]]; then
  # No --deep on the app: its resource bundle (WallpaperGarden_PlantWallpaper.bundle
  # in Contents/Resources) is data, not code — --deep would try to sign it as a
  # nested code bundle and fail ("bundle format unrecognized"). Without --deep it
  # is sealed as a normal resource.
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$STAGING_DIR/Plant Wallpaper.app"
  if [[ -d "$STAGING_DIR/Plant Wallpaper.saver" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$STAGING_DIR/Plant Wallpaper.saver"
  fi
else
  echo "warning: DEVELOPER_ID_APPLICATION not set; creating an unsigned local-test DMG." >&2
fi

hdiutil create \
  -volname "Plant Wallpaper" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
else
  echo "warning: NOTARYTOOL_PROFILE not set; skipping notarization/stapling." >&2
fi

cat > "$DIST_DIR/release-readiness-$VERSION.json" <<MANIFEST
{
  "app": "Plant Wallpaper",
  "version": "$VERSION",
  "distributionChannel": "$DISTRIBUTION_CHANNEL",
  "paidValidationProvider": "$PAID_VALIDATION_PROVIDER",
  "paidValidationConfigured": $PAID_VALIDATION_CONFIGURED,
  "developerIdSigned": $(if [[ -n "$SIGN_IDENTITY" ]]; then echo true; else echo false; fi),
  "notarizedAndStapled": $(if [[ -n "$NOTARY_PROFILE" ]]; then echo true; else echo false; fi),
  "dmgPath": "$DMG_PATH"
}
MANIFEST

echo "$DMG_PATH"
