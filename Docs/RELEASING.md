# Releasing Plant Wallpaper

How to ship a new version to GitHub Releases and itch.io. The whole thing is one command once the one-time setup is done.

## TL;DR — every release

```sh
./scripts/release.sh 0.2.0
```

That builds a signed + notarized DMG, commits + pushes the source, tags `v0.2.0`, and creates the GitHub release with the DMG attached. Then upload the same `.dmg` to itch.io (one manual step — see below).

Pass a notes file if you want custom release notes (otherwise notes are auto-generated from commits):

```sh
./scripts/release.sh 0.2.0 release-notes.md
```

## Versioning

- `0.1.0 → 0.1.1` for small fixes, `0.2.0` for new features, `1.0.0` when it's out of beta.
- The version you pass sets the DMG filename and the git tag.
- Note: the in-app "About" version is currently hardcoded in `scripts/build_app.sh` (`CFBundleShortVersionString`). If you later want in-app update checks, wire that to track `PLANT_WALLPAPER_VERSION`.

## itch.io (the one manual step)

`butler` (itch's uploader) couldn't be installed in this environment, so for now upload via the web:

1. itch.io → your project → **Edit game** → **Uploads** → **Upload files**
2. Pick the new `.build/dist/Plant-Wallpaper-<version>.dmg`, tag it **macOS**, and remove the old build.

(Later: install the itch desktop app or `butler` to push builds from the CLI.)

## One-time setup (already done on Chris's Mac — here for a fresh machine)

You need the **paid Apple Developer Program** ($99/yr).

1. **Developer ID Application certificate** — Xcode → Settings → Accounts → your team → Manage Certificates → `+` → *Developer ID Application*. Verify: `security find-identity -v -p codesigning` shows `Developer ID Application: <you> (TEAMID)`.
2. **Notary profile** — make an app-specific password at appleid.apple.com, then:
   ```sh
   xcrun notarytool store-credentials "wallpapergarden-notary" \
     --apple-id "you@example.com" --team-id "TEAMID" --password "xxxx-xxxx-xxxx-xxxx"
   ```
3. **Local config** — `cp scripts/.release.env.example scripts/.release.env` and fill in your identity, notary profile name, and `GH_REPO`. (`.release.env` is gitignored.)
4. **GitHub CLI** — `gh auth login` (needs `repo` scope).

## Verify a build before sharing

```sh
spctl -a -t exec -vv "/Applications/Plant Wallpaper.app"   # → accepted / source=Notarized Developer ID
```

## Why the build is shaped the way it is

Two non-obvious things make signing work (don't undo them):

- The resource bundle lives in `Contents/Resources/`, not the `.app` root (code signing forbids root-level items). `AppResourceBundle.swift` makes the app find it there.
- The app is signed **without** `--deep` (its resource bundle is data, not code).

See `scripts/package_release.sh` for the full build → sign → DMG → notarize → staple pipeline.
