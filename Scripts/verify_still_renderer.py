#!/usr/bin/env python3
"""Fail packaging if time-driven plant motion hooks return to the renderer."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

FORBIDDEN_PATTERNS = {
    "Sources/PlantWallpaper/GardenCanvasPalette.swift": [
        "animationTime",
        "timeIntervalSinceReferenceDate",
    ],
    "Sources/PlantWallpaper/GardenCanvasView.swift": [
        "drawFloatingPollen",
        "drawBloomAndNewGrowth",
        "drawCompanionPlantingCue",
        "drawDewOnPlant",
        "drawDewOnGroundBed",
        "drawGrowthMilestoneCue",
        "drawBiodiversityBackdrop",
        "drawBiodiversityForeground",
        "drawPondCorner",
        "drawFish(",
        "drawMoth(",
        "drawDragonfly(",
        "drawLadybug(",
        "drawBeetle(",
        "drawMantis(",
        "drawSnail(",
        "drawFrog(",
        "drawGecko(",
        "drawBird(",
        "drawNest(",
        "drawSquirrel(",
        "let bedRects = [",
        "bedFillColor(",
        "drawSeasonalGroundDetail(",
        "drawNutrientProfileCue",
        "drawPetalRing",
        "drawSeasonalAssetTreatment",
        "drawSpecularRim",
        "drawStarBloomSignature",
        "drawStressTint",
        "drawTendingEffects(for: plant",
        "drawLayeredPetalSignature",
        "drawEmergentPlant",
        "animationTime",
        "drift =",
        "plantSway(",
        "windResponse(",
        "sideDrift = sway",
        "drawRealisticAssetWithMotion",
        "realisticSwayFactor",
        "breathe",
    ],
    "Sources/PlantWallpaper/AppDelegate.swift": [
        "1.0 / 30.0",
    ],
}


def main() -> int:
    failures: list[str] = []
    for relative_path, patterns in FORBIDDEN_PATTERNS.items():
        path = ROOT / relative_path
        if not path.exists():
            failures.append(f"Missing expected source file: {relative_path}")
            continue

        text = path.read_text(encoding="utf-8")
        for pattern in patterns:
            if pattern in text:
                failures.append(f"{relative_path} contains forbidden stillness pattern: {pattern!r}")

    if failures:
        print("Renderer stillness verification failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Renderer stillness verification passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
