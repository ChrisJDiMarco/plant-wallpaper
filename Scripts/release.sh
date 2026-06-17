#!/usr/bin/env bash
#
# One-command release: build a signed + notarized DMG, push the source, and cut
# a GitHub release with the DMG attached.
#
#   ./scripts/release.sh <version> [notes-file]
#   ./scripts/release.sh 0.2.0
#   ./scripts/release.sh 0.2.0 release-notes.md
#
# Then upload the same DMG to itch.io (web upload — see docs/RELEASING.md).
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-}"
NOTES_FILE="${2:-}"
if [[ -z "$VERSION" ]]; then
  echo "usage: scripts/release.sh <version> [notes-file]   e.g. scripts/release.sh 0.2.0" >&2
  exit 1
fi

# Signing config. The actual signing key + notary password live in your macOS
# Keychain; these are just identifiers. Put them in scripts/.release.env
# (gitignored) or export them before running.
if [[ -f "$ROOT_DIR/scripts/.release.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT_DIR/scripts/.release.env"
fi
: "${DEVELOPER_ID_APPLICATION:?set DEVELOPER_ID_APPLICATION (copy scripts/.release.env.example to scripts/.release.env)}"
: "${NOTARYTOOL_PROFILE:?set NOTARYTOOL_PROFILE (copy scripts/.release.env.example to scripts/.release.env)}"
GH_REPO="${GH_REPO:-ChrisJDiMarco/plant-wallpaper}"

DMG=".build/dist/Plant-Wallpaper-$VERSION.dmg"

echo "==> [1/4] Building signed + notarized DMG (v$VERSION) — this includes the Apple notarization wait…"
DEVELOPER_ID_APPLICATION="$DEVELOPER_ID_APPLICATION" \
NOTARYTOOL_PROFILE="$NOTARYTOOL_PROFILE" \
PLANT_WALLPAPER_VERSION="$VERSION" \
  ./scripts/package_release.sh

if [[ ! -f "$DMG" ]]; then
  echo "ERROR: expected $DMG was not produced." >&2
  exit 1
fi

echo "==> [2/4] Committing + pushing source…"
git add -A
git commit -m "release: v$VERSION" || echo "    (nothing new to commit)"
git push origin HEAD

echo "==> [3/4] Tagging v$VERSION…"
git tag -a "v$VERSION" -m "Plant Wallpaper $VERSION" 2>/dev/null || echo "    (tag v$VERSION already exists)"
git push origin "v$VERSION"

echo "==> [4/4] Creating GitHub release…"
if [[ -n "$NOTES_FILE" && -f "$NOTES_FILE" ]]; then
  gh release create "v$VERSION" --repo "$GH_REPO" --title "Plant Wallpaper $VERSION" --notes-file "$NOTES_FILE" "$DMG"
else
  gh release create "v$VERSION" --repo "$GH_REPO" --title "Plant Wallpaper $VERSION" --generate-notes "$DMG"
fi

echo ""
echo "✅ Released v$VERSION → https://github.com/$GH_REPO/releases/tag/v$VERSION"
echo "   DMG: $ROOT_DIR/$DMG"
echo ""
echo "👉 Last step (manual): upload that .dmg to your itch.io page → Edit game → Upload files."
