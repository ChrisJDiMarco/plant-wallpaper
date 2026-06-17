#!/usr/bin/env python3
from __future__ import annotations

import plistlib
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify_screensaver_bundle.py <Plant Wallpaper.saver>")

    saver_dir = Path(sys.argv[1])
    if not saver_dir.exists():
        raise SystemExit(f"Missing screensaver bundle: {saver_dir}")

    info_path = saver_dir / "Contents" / "Info.plist"
    executable_path = saver_dir / "Contents" / "MacOS" / "PlantWallpaperScreenSaver"
    plant_assets_dir = saver_dir / "Contents" / "Resources" / "PlantAssets"
    scene_assets_dir = saver_dir / "Contents" / "Resources" / "SceneAssets"

    if not info_path.exists():
        raise SystemExit(f"Missing Info.plist: {info_path}")
    if not executable_path.exists():
        raise SystemExit(f"Missing executable: {executable_path}")
    if not plant_assets_dir.is_dir():
        raise SystemExit(f"Missing plant assets directory: {plant_assets_dir}")
    if not scene_assets_dir.is_dir():
        raise SystemExit(f"Missing scene assets directory: {scene_assets_dir}")

    with info_path.open("rb") as handle:
        info = plistlib.load(handle)

    expected = {
        "CFBundlePackageType": "BNDL",
        "CFBundleExecutable": "PlantWallpaperScreenSaver",
        "CFBundleIdentifier": "com.chrisdimarco.wallpapergarden.screensaver",
        "NSPrincipalClass": "PlantWallpaperScreenSaverView",
    }
    for key, value in expected.items():
        if info.get(key) != value:
            raise SystemExit(f"Info.plist {key} was {info.get(key)!r}, expected {value!r}")

    staged_assets = sorted(plant_assets_dir.glob("*-stage-*.png"))
    scene_assets = sorted(scene_assets_dir.glob("*.png"))
    if len(staged_assets) < 1:
        raise SystemExit("Screensaver bundle has no staged plant PNG assets")
    if len(scene_assets) < 8:
        raise SystemExit(f"Screensaver bundle has too few scene assets: {len(scene_assets)}")

    print(f"Verified screensaver bundle: {saver_dir}")
    print(f"  staged plant assets: {len(staged_assets)}")
    print(f"  scene assets: {len(scene_assets)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
