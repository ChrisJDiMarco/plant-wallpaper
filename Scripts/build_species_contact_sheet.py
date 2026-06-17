#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ASSET_DIR = ROOT / "Sources" / "PlantWallpaper" / "Resources" / "PlantAssets"
DEFAULT_OUTPUT_DIR = ROOT / "Generated" / "AIStageQA" / "ContactSheets"


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a contact sheet for one species' ten staged assets.")
    parser.add_argument("slug", help="Plant asset slug, e.g. japanese-maple")
    parser.add_argument("--asset-dir", type=Path, default=DEFAULT_ASSET_DIR)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    images = []
    for stage in range(10):
        path = args.asset_dir / f"{args.slug}-stage-{stage:02d}.png"
        if not path.exists():
            raise SystemExit(f"Missing staged asset: {path}")
        images.append(Image.open(path).convert("RGBA"))

    cell_width, cell_height = 184, 214
    sheet = Image.new("RGBA", (cell_width * 5, cell_height * 2), (246, 246, 241, 255))
    draw = ImageDraw.Draw(sheet)
    for stage, image in enumerate(images):
        thumb = image.copy()
        thumb.thumbnail((cell_width - 28, cell_height - 38), Image.Resampling.LANCZOS)
        left = (stage % 5) * cell_width + (cell_width - thumb.width) // 2
        top = (stage // 5) * cell_height + cell_height - thumb.height - 28
        sheet.alpha_composite(thumb, (left, top))
        draw.text(
            ((stage % 5) * cell_width + 10, (stage // 5) * cell_height + cell_height - 21),
            f"{args.slug} {stage:02d}",
            fill=(32, 32, 32, 255),
        )

    output = args.output_dir / f"{args.slug}-contact.png"
    sheet.convert("RGB").save(output)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
